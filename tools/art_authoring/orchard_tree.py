"""EVERBLOOM original orchard tree authoring source (Blender 4.x).
Run: blender -b --python tools/art_authoring/orchard_tree.py
Creates a rights-clean, editable Blender scene and glTF binary under art_exports/.
This is a reproducible authored starting asset, NOT verified final production art.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

SEED = 20261103
rng = random.Random(SEED)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def material(name, color, roughness):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return m

bark = material("bark_warm_umber", (0.19, 0.105, 0.061), 0.91)
# Original fine bark relief: anisotropic procedural height rather than a flat
# color swap. Bake this node network before mobile glTF delivery; glTF does
# not preserve arbitrary Blender procedural nodes.
nodes = bark.node_tree.nodes
links = bark.node_tree.links
bark_bsdf = nodes.get("Principled BSDF")
texcoord = nodes.new("ShaderNodeTexCoord")
mapping = nodes.new("ShaderNodeVectorMath")
mapping.operation = "MULTIPLY"
mapping.inputs[1].default_value = (5.5, 5.5, 0.65)
links.new(texcoord.outputs["Generated"], mapping.inputs[0])
grain = nodes.new("ShaderNodeTexNoise")
grain.inputs["Scale"].default_value = 9.0
grain.inputs["Detail"].default_value = 3.0
grain.inputs["Roughness"].default_value = 0.72
links.new(mapping.outputs["Vector"], grain.inputs["Vector"])
relief = nodes.new("ShaderNodeBump")
relief.inputs["Strength"].default_value = 0.22
relief.inputs["Distance"].default_value = 0.035
links.new(grain.outputs["Fac"], relief.inputs["Height"])
links.new(relief.outputs["Normal"], bark_bsdf.inputs["Normal"])
leaf_mats = [
    material("leaf_sage", (0.19, 0.35, 0.16), 0.82),
    material("leaf_olive", (0.27, 0.39, 0.14), 0.83),
    material("leaf_sunlit", (0.38, 0.49, 0.19), 0.78),
]
twig_mat = material("twig", (0.25, 0.14, 0.08), 0.9)

def tapered_tube(name, points, radii, sides=9, mat=bark):
    """Continuous rings, bent silhouette, capped ends, explicit outward normals."""
    vertices, faces = [], []
    for i, p in enumerate(points):
        tangent = (Vector(points[min(i+1, len(points)-1)]) -
                   Vector(points[max(0, i-1)])).normalized()
        reference = Vector((0, 1, 0)) if abs(tangent.y) < 0.9 else Vector((1, 0, 0))
        axis_a = tangent.cross(reference).normalized()
        axis_b = tangent.cross(axis_a).normalized()
        for j in range(sides):
            theta = 2 * math.pi * j / sides
            # Continuous angular ridges, subtly irregular but never random rings.
            # Preserve the same ridge phase across sections to avoid flicker.
            ridge = 1.0 + (0.045 if mat == bark else 0.012) * math.sin(7 * theta + 0.3)
            v = Vector(p) + radii[i] * ridge * (math.cos(theta)*axis_a + math.sin(theta)*axis_b)
            vertices.append(tuple(v))
    for i in range(len(points)-1):
        for j in range(sides):
            a = i*sides+j
            b = i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(tuple(range(sides)))),
                  tuple((len(points)-1)*sides+j for j in range(sides))])
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    return obj

def leaf(name, origin, length, width, direction, mat):
    """Connected, watertight lanceolate leaf with a raised midrib and thickness.

    The previous leaf builder used a triangle fan with overlapping and missing
    spans; several vertices were disconnected. This version uses indexed
    transverse rings, two skins and a closed perimeter.
    """
    direction = Vector(direction).normalized()
    lateral = direction.cross(Vector((0, 0, 1)))
    if lateral.length < 0.05:
        lateral = direction.cross(Vector((0, 1, 0)))
    lateral.normalize()
    normal = lateral.cross(direction).normalized()
    base = Vector(origin)
    # Five cross-sections. Narrow endpoints avoid zero-area triangles.
    stations = (0.0, 0.20, 0.43, 0.68, 0.86, 1.0)
    verts = []
    for t in stations:
        span = max(0.008, math.sin(math.pi * t)) * width
        mid = base + direction * (length * t)
        # Original blade camber: a shallow, asymmetric arch that remains
        # visible in silhouette and exports as real geometry to glTF.
        mid += normal * (0.18 * length * math.sin(math.pi * t))
        mid += lateral * (0.09 * length * t * t)
        # The central ridge gives the blade a convincing crease in grazing light.
        for skin in (1.0, -1.0):
            for across in (-1.0, 0.0, 1.0):
                ridge = (1.0 - abs(across)) * 0.14 * width
                thickness = skin * 0.012 * width
                point = mid + lateral * (span * across)
                point += normal * (ridge + thickness)
                verts.append(tuple(point))
    faces = []
    stride = 6
    for k in range(len(stations) - 1):
        a, b = k * stride, (k + 1) * stride
        for j in range(2):
            faces.extend(((a+j, b+j, b+j+1),
                          (a+j, b+j+1, a+j+1)))
            # Reverse winding for the underside.
            faces.extend(((a+3+j, b+3+j+1, b+3+j),
                          (a+3+j, a+3+j+1, b+3+j+1)))
    for k in range(len(stations) - 1):
        a, b = k * stride, (k + 1) * stride
        faces.extend(((a, a+3, b+3), (a, b+3, b)))
        faces.extend(((a+2, b+2, b+5), (a+2, b+5, a+5)))
    first, last = 0, (len(stations)-1)*stride
    faces.extend(((first, first+1, first+4), (first, first+4, first+3),
                  (first+1, first+2, first+5), (first+1, first+5, first+4),
                  (last, last+3, last+4), (last, last+4, last+1),
                  (last+1, last+4, last+5), (last+1, last+5, last+2)))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj

trunk = [(0,0,0),(.05,0,0.55),(.09,-.02,1.25),(.16,.02,2.05),
         (.22,.08,2.82),(.26,.10,3.5)]
tapered_tube("orchard_trunk", trunk, [.33,.29,.23,.17,.11,.065], 13)
for b in range(11):
    angle = 2.39996*b
    height = 1.65 + .16*b
    reach = 1.35 + .22*(b%3)
    direction = Vector((math.cos(angle), math.sin(angle), .48)).normalized()
    # Anchor each branch to the actual bent trunk centerline at its height.
    # The former constant (.11, .03) origin left upper branches detached
    # from the trunk silhouette as the trunk bends toward (+X, +Y).
    trunk_center = Vector(trunk[-1])
    for segment in range(len(trunk) - 1):
        lower, upper = Vector(trunk[segment]), Vector(trunk[segment + 1])
        if lower.z <= height <= upper.z:
            alpha = (height - lower.z) / (upper.z - lower.z)
            trunk_center = lower.lerp(upper, alpha)
            break
    # Start inside the trunk so that no daylight gap appears at the junction.
    start = trunk_center + Vector((direction.x, direction.y, 0)) * .035
    points = [start,
              start+direction*reach*.38+Vector((0,0,.12)),
              start+direction*reach*.76+Vector((0,0,.22)),
              start+direction*reach+Vector((0,0,.31))]
    tapered_tube("branch_%02d"%b, points, [.105,.072,.039,.008], 7, twig_mat)
    for k in range(13):
        t = .40 + .55*rng.random()
        anchor = points[0].lerp(points[3],t)
        az = angle + rng.uniform(-1.5,1.5)
        v = Vector((math.cos(az),math.sin(az),rng.uniform(-.22,.7)))
        # Each leaf is attached by a visible curved petiole instead of
        # floating directly at a randomly interpolated branch location.
        petiole_end = anchor + v.normalized() * rng.uniform(.075, .13)
        tapered_tube("petiole_%02d_%02d"%(b,k),
                     [anchor, anchor.lerp(petiole_end, .55) + Vector((0,0,.018)), petiole_end],
                     [.012, .009, .004], 5, twig_mat)
        leaf("leaf_%02d_%02d"%(b,k),petiole_end,
             rng.uniform(.32,.56),rng.uniform(.07,.12),v,
             leaf_mats[rng.randrange(len(leaf_mats))])

# Batch the existing authored leaf and petiole meshes by material. Each leaf
# previously exported as a separate glTF node/mesh, multiplying draw calls
# across an orchard. This preserves the exact authored vertex positions and
# material assignments; it does not generate placeholder foliage or LODs.
# Blender source remains editable at the grouped-mesh level.
def batch_material_meshes(prefix, materials):
    for mat in materials:
        group = [obj for obj in bpy.context.scene.objects
                 if obj.type == "MESH" and obj.name.startswith(prefix)
                 and len(obj.data.materials) == 1 and obj.data.materials[0] == mat]
        if len(group) < 2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        merged = bpy.context.view_layer.objects.active
        merged.name = "orchard_batched_%s_%s" % (prefix.rstrip("_"), mat.name)
        assert len(merged.data.materials) == 1
        assert merged.data.materials[0] == mat
        assert len(merged.data.vertices) > 0
        merged.select_set(False)

batch_material_meshes("leaf_", leaf_mats)
batch_material_meshes("petiole_", [twig_mat])
# Trunk and branch objects remain separate for selective collision and
# eventual LOD authoring. Mesh batching is not a measured FPS improvement.

# Keep explicit geometry; do not generate collision or claim canopy occlusion tests.
out = Path(bpy.path.abspath("//art_exports"))
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"orchard_tree_source.blend"))
bpy.ops.export_scene.gltf(filepath=str(out/"orchard_tree.glb"),
                          export_format="GLB", export_apply=True)
print("EVERBLOOM ORIGINAL ASSET: exported orchard_tree.glb; native Godot import/render unverified")
