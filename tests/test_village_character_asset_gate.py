"""Offline negative/positive fixtures for Village character import admission."""
import hashlib
import json
import pathlib
import struct
import tempfile
import unittest
from tools.validate_village_character import validate


def glb(doc):
    payload = json.dumps(doc).encode()
    payload += b" " * ((-len(payload)) % 4)
    binary = bytes(16384)
    return struct.pack("<4sII", b"glTF", 2, 28 + len(payload) + len(binary)) + struct.pack("<I4s", len(payload), b"JSON") + payload + struct.pack("<I4s", len(binary), b"BIN\x00") + binary


def valid_doc():
    return {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": 16384}],
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 16384}],
        "accessors": [{"count": 1200, "bufferView": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 0, "JOINTS_0": 0, "WEIGHTS_0": 0}, "material": 0}]}],
        "nodes": [{"mesh": 0, "skin": 0}, {}],
        "skins": [{"joints": [1]}],
        "animations": [{"samplers": [{"input": 0, "output": 0}], "channels": [{"sampler": 0, "target": {"node": 1, "path": "rotation"}}]}],
        "materials": [{"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicRoughnessTexture": {"index": 0}}, "normalTexture": {"index": 0}}],
        "images": [{"uri": "data:image/png;base64,AA=="}],
        "textures": [{"source": 0}],
    }


class VillageAssetGateTests(unittest.TestCase):
    def check(self, doc, override=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            raw = glb(doc)
            asset = root / "resident.glb"
            asset.write_bytes(raw)
            manifest = {"creator": "Everbloom original art", "source": "in-house", "permission": "owned", "license": "ORIGINAL-OWNED", "sha256": hashlib.sha256(raw).hexdigest()}
            if override:
                manifest.update(override)
            info = root / "provenance.json"
            info.write_text(json.dumps(manifest))
            return validate(asset, info)

    def test_valid_structural_fixture(self):
        self.assertEqual(self.check(valid_doc()), [])

    def test_reject_missing_binary_backing(self):
        doc = valid_doc()
        doc["buffers"] = []
        self.assertIn("invalid embedded buffer declaration", self.check(doc))

    def test_reject_non_object_buffer_without_crashing(self):
        doc = valid_doc()
        doc["buffers"] = [None]
        self.assertIn("invalid embedded buffer declaration", self.check(doc))

    def test_reject_out_of_range_buffer_view(self):
        doc = valid_doc()
        doc["bufferViews"][0]["byteLength"] = 999999
        self.assertIn("buffer view exceeds embedded binary data", self.check(doc))

    def test_reject_dangling_accessor_view(self):
        doc = valid_doc()
        doc["accessors"][0]["bufferView"] = 9
        self.assertIn("invalid accessor backing view", self.check(doc))

    def test_reject_dangling_mesh_binding(self):
        doc = valid_doc()
        doc["nodes"][0]["mesh"] = 999
        self.assertIn("no node binds a mesh to a skeleton", self.check(doc))

    def test_reject_dangling_skin_binding(self):
        doc = valid_doc()
        doc["nodes"][0]["skin"] = 999
        self.assertIn("no node binds a mesh to a skeleton", self.check(doc))

    def test_reject_boolean_mesh_binding(self):
        doc = valid_doc()
        doc["nodes"][0]["mesh"] = True
        self.assertIn("no node binds a mesh to a skeleton", self.check(doc))

    def test_reject_unlicensed(self):
        self.assertIn("unapproved license", self.check(valid_doc(), {"license": "unknown"}))

    def test_reject_wrong_hash(self):
        self.assertIn("asset SHA-256 mismatch", self.check(valid_doc(), {"sha256": "0" * 64}))

    def test_reject_primitive_unrigged(self):
        doc = valid_doc()
        doc["skins"] = []
        self.assertTrue(any("skinned mesh" in e for e in self.check(doc)))

    def test_reject_missing_normal_map(self):
        doc = valid_doc()
        del doc["materials"][0]["normalTexture"]
        self.assertIn("normal map required", self.check(doc))


    def test_reject_dangling_texture_reference(self):
        doc = valid_doc()
        doc["materials"][0]["normalTexture"]["index"] = 9
        self.assertIn("material references missing texture", self.check(doc))

    def test_reject_dangling_image_reference(self):
        doc = valid_doc()
        doc["textures"][0]["source"] = 9
        self.assertIn("texture references missing image", self.check(doc))

    def test_reject_missing_animation_sampler(self):
        doc = valid_doc()
        doc["animations"][0]["samplers"] = []
        self.assertIn("animation channel references missing sampler", self.check(doc))

    def test_reject_external_image_uri(self):
        doc = valid_doc()
        doc["images"][0]["uri"] = "https://example.invalid/skin.png"
        self.assertIn("external image URI forbidden in self-contained GLB", self.check(doc))


if __name__ == "__main__":
    unittest.main()
