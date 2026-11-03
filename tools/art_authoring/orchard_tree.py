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
            v = Vector(p) + radii[i] * (math.cos(theta)*axis_a + math.sin(theta)*axis_b)
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
    """Double-sided sculpted lanceolate blade with midrib ridge and pointed tip."""
    direction = Vector(direction).normalized()
    lateral = direction.cross(Vector((0,0,1)))
    if lateral.length < 0.05:
        lateral = direction.cross(Vector((0,1,0)))
    lateral.normalize()
    normal = lateral.cross(direction).normalized()
    base = Vector(origin)
    verts = [tuple(base)]
    for t in (0.24, 0.50, 0.76):
        center = base + direction * length * t + normal * (0.12*width*math.sin(math.pi*t))
        spread = width * math.sin(math.pi*t)
        verts.extend([tuple(center-lateral*spread), tuple(center+normal*width*0.10),
                      tuple(center+lateral*spread)])
    verts.append(tuple(base+direction*length))
    faces = []
    for k in range(3):
        prev = 0 if k == 0 else 1+(k-1)*3+1
        left, mid, right = 1+k*3, 2+k*3, 3+k*3
        faces.extend([(prev,left,mid), (prev,mid,right)])
        if k:
            pl, pr = 1+(k-1)*3, 3+(k-1)*3
            faces.extend([(pl,left,mid),(pr,mid,right)])
    tip = len(verts)-1
    faces.extend([(7,tip,8),(8,tip,9)])
    mesh = bpy.data.meshes.new(name+"_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

trunk = [(0,0,0),(.05,0,0.55),(.09,-.02,1.25),(.16,.02,2.05),
         (.22,.08,2.82),(.26,.10,3.5)]
tapered_tube("orchard_trunk", trunk, [.33,.29,.23,.17,.11,.065], 13)
for b in range(11):
    angle = 2.39996*b
    height = 1.65 + .16*b
    reach = 1.35 + .22*(b%3)
    direction = Vector((math.cos(angle), math.sin(angle), .48)).normalized()
    start = Vector((.11,.03,height))
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
        leaf("leaf_%02d_%02d"%(b,k),anchor,
             rng.uniform(.32,.56),rng.uniform(.07,.12),v,
             leaf_mats[rng.randrange(len(leaf_mats))])

# Keep explicit geometry; do not generate collision or claim canopy occlusion tests.
out = Path(bpy.path.abspath("//art_exports"))
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"orchard_tree_source.blend"))
bpy.ops.export_scene.gltf(filepath=str(out/"orchard_tree.glb"),
                          export_format="GLB", export_apply=True)
print("EVERBLOOM ORIGINAL ASSET: exported orchard_tree.glb; native Godot import/render unverified")
