#!/usr/bin/env python3
"""EVERBLOOM Village: fail-closed, dependency-free GLB character admission.

This is an *asset import gate*, not a generator or a visual-quality certificate.
Usage: python tools/validate_village_character.py asset.glb provenance.json
The manifest must contain sha256, license, creator, source, and permission.
"""
import hashlib
import json
import pathlib
import struct
import sys

ALLOWED_LICENSES = {"CC0-1.0", "CC-BY-4.0", "ORIGINAL-OWNED"}
MAX_BYTES = 30 * 1024 * 1024
MAX_VERTICES = 100_000
MAX_JOINTS = 128


def validate(glb_path, manifest_path):
    errors = []
    raw = pathlib.Path(glb_path).read_bytes()
    provenance = json.loads(pathlib.Path(manifest_path).read_text(encoding="utf-8"))
    for field in ("creator", "source", "permission", "sha256", "license"):
        if not isinstance(provenance.get(field), str) or not provenance[field].strip():
            errors.append("missing provenance field: " + field)
    if provenance.get("license") not in ALLOWED_LICENSES:
        errors.append("unapproved license")
    if provenance.get("sha256", "").lower() != hashlib.sha256(raw).hexdigest():
        errors.append("asset SHA-256 mismatch")
    if len(raw) > MAX_BYTES:
        errors.append("GLB exceeds 30 MiB")
    if len(raw) < 20 or raw[:4] != b"glTF":
        return errors + ["not a binary glTF 2.0 file"]
    magic, version, length = struct.unpack_from("<4sII", raw)
    if version != 2 or length != len(raw):
        return errors + ["invalid GLB version or declared length"]
    chunk_length, chunk_type = struct.unpack_from("<I4s", raw, 12)
    if chunk_type != b"JSON" or chunk_length > len(raw) - 20:
        return errors + ["missing or truncated JSON chunk"]
    try:
        doc = json.loads(raw[20:20 + chunk_length].decode("utf-8"))
    except (UnicodeError, ValueError):
        return errors + ["invalid glTF JSON"]
    if doc.get("asset", {}).get("version") != "2.0":
        errors.append("asset version must be glTF 2.0")
    meshes = doc.get("meshes", [])
    skins = doc.get("skins", [])
    animations = doc.get("animations", [])
    materials = doc.get("materials", [])
    accessors = doc.get("accessors", [])
    nodes = doc.get("nodes", [])
    if not meshes or not skins or not animations:
        errors.append("requires skinned mesh and authored animation")
    if not materials:
        errors.append("requires PBR materials")
    for material in materials:
        pbr = material.get("pbrMetallicRoughness", {})
        if "baseColorTexture" not in pbr or "metallicRoughnessTexture" not in pbr:
            errors.append("PBR base-color and metallic-roughness maps required")
        if "normalTexture" not in material:
            errors.append("normal map required")
    for skin in skins:
        joints = skin.get("joints", [])
        if not joints or len(joints) > MAX_JOINTS or any(
            not isinstance(j, int) or j < 0 or j >= len(nodes) for j in joints
        ):
            errors.append("invalid skeleton joint set")
    vertex_count = 0
    for mesh in meshes:
        for primitive in mesh.get("primitives", []):
            attrs = primitive.get("attributes", {})
            for attr in ("POSITION", "NORMAL", "JOINTS_0", "WEIGHTS_0"):
                if attr not in attrs:
                    errors.append("skinned primitive missing " + attr)
            idx = attrs.get("POSITION")
            if isinstance(idx, int) and 0 <= idx < len(accessors):
                vertex_count += int(accessors[idx].get("count", 0))
            else:
                errors.append("invalid position accessor")
            if primitive.get("material", -1) not in range(len(materials)):
                errors.append("primitive lacks valid material")
    if vertex_count <= 0 or vertex_count > MAX_VERTICES:
        errors.append("character vertex budget violated")
    if not doc.get("images") or not doc.get("textures"):
        errors.append("texture image data missing")
    if not any(node.get("skin") is not None and node.get("mesh") is not None for node in nodes):
        errors.append("no node binds a mesh to a skeleton")
    if not any(animation.get("channels") for animation in animations):
        errors.append("animation has no channels")
    # Reject dangling texture and animation references; structural admission only.
    for material in materials:
        pbr = material.get("pbrMetallicRoughness", {})
        for ref in (pbr.get("baseColorTexture"), pbr.get("metallicRoughnessTexture"), material.get("normalTexture")):
            if isinstance(ref, dict):
                idx = ref.get("index")
                if not isinstance(idx, int) or not 0 <= idx < len(doc.get("textures", [])):
                    errors.append("material references missing texture")
    for texture in doc.get("textures", []):
        idx = texture.get("source")
        if not isinstance(idx, int) or not 0 <= idx < len(doc.get("images", [])):
            errors.append("texture references missing image")
    for image in doc.get("images", []):
        uri = image.get("uri")
        if isinstance(uri, str) and not uri.startswith("data:"):
            errors.append("external image URI forbidden in self-contained GLB")
    for animation in animations:
        samplers = animation.get("samplers", [])
        for channel in animation.get("channels", []):
            idx = channel.get("sampler")
            if not isinstance(idx, int) or not 0 <= idx < len(samplers):
                errors.append("animation channel references missing sampler")
            target = channel.get("target", {})
            node = target.get("node")
            if not isinstance(node, int) or not 0 <= node < len(nodes):
                errors.append("animation channel targets missing node")
            if target.get("path") not in ("translation", "rotation", "scale", "weights"):
                errors.append("animation channel has invalid target path")
        for sampler in samplers:
            for key in ("input", "output"):
                idx = sampler.get(key)
                if not isinstance(idx, int) or not 0 <= idx < len(accessors):
                    errors.append("animation sampler has invalid " + key + " accessor")
    return sorted(set(errors))


def main(argv):
    if len(argv) != 3:
        print("usage: validate_village_character.py character.glb provenance.json")
        return 2
    try:
        errors = validate(argv[1], argv[2])
    except (OSError, ValueError, TypeError, KeyError, struct.error) as exc:
        print("FAIL: malformed or unreadable asset: " + str(exc))
        return 1
    if errors:
        for error in errors:
            print("FAIL: " + error)
        return 1
    print("PASS: structural/provenance admission only; visual quality, rig deformation, collision and FPS UNVERIFIED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
