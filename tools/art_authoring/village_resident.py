"""Original EVERBLOOM resident sculpt blockout. Blender 4.x, no external assets.
Run: blender -b --python tools/art_authoring/village_resident.py
Outputs assets/village/characters/resident_artisan.glb (not production approved).
The authored surface is an anatomical starting mesh, not a primitive-stack NPC.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
OUT = Path(__file__).resolve().parents[2] / "assets/village/characters/resident_artisan.glb"
OUT.parent.mkdir(parents=True, exist_ok=True)

def material(name, color, roughness):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = roughness
    return m

skin = material("warm skin | sculpt reference", (0.55,0.29,0.20), 0.65)
linen = material("indigo work linen | sculpt reference", (0.13,0.20,0.33), 0.84)
leather = material("oxblood work boots | sculpt reference", (0.17,0.075,0.055), 0.72)
hair = material("dark chestnut hair | sculpt reference", (0.095,0.044,0.026), 0.78)

def loft(name, sections, mat, sides=20, phase=0.0):
    """Smoothly interpolated anatomical contours; one connected surface per region."""
    vertices, faces = [], []
    for z, cx, cy, rx, ry in sections:
        for j in range(sides):
            a = 2 * math.pi * j / sides + phase
            vertices.append((cx + rx*math.cos(a), cy + ry*math.sin(a), z))
    for i in range(len(sections)-1):
        for j in range(sides):
            a=i*sides+j
            b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(sections)-1)*sides+j for j in range(sides)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth=True
    return obj

# Contoured jacket: waist, ribcage, shoulder slope and neck aperture.
torso=loft("tailored jacket silhouette",[
    (0.89,0,0,0.22,0.135),(1.01,0,0,0.26,0.15),
    (1.20,0,0,0.245,0.16),(1.38,0,0,0.31,0.175),
    (1.49,0,0,0.325,0.16),(1.58,0,0,0.23,0.13),
    (1.63,0,0,0.105,0.10)],linen)
neck=loft("neck anatomy",[(1.55,0,0,0.092,0.084),(1.67,0,0,0.085,0.077)],skin)
# Skull silhouette includes jaw taper, cheek volume, temples and cranial vault.
head=loft("jaw cheek cranium",[
    (1.64,0,-0.012,0.075,0.075),(1.69,0,-0.016,0.112,0.105),
    (1.75,0,-0.006,0.138,0.125),(1.83,0,0,0.146,0.139),
    (1.92,0,0.009,0.143,0.132),(2.00,0,0.012,0.114,0.114),
    (2.045,0,0.014,0.058,0.065)],skin)
# Facial structure, original geometry rather than texture-only facial features.
for side in (-1,1):
    cheek=loft("cheek volume "+str(side),[
        (1.77,side*0.095,-0.105,0.032,0.023),
        (1.82,side*0.103,-0.116,0.037,0.023),
        (1.86,side*0.099,-0.105,0.020,0.015)],skin,12)
nose=loft("nasal bridge and tip",[
    (1.76,0,-0.129,0.026,0.024),
    (1.82,0,-0.156,0.021,0.033),
    (1.88,0,-0.132,0.021,0.019)],skin,12)
# Longitudinal limbs with changing radius and anatomical bends.
for side in (-1,1):
    x=side
    loft("arm sleeve "+str(side),[
        (0.99,x*0.405,0.005,0.076,0.074),
        (1.11,x*0.421,-0.018,0.084,0.081),
        (1.28,x*0.390,-0.006,0.090,0.091),
        (1.43,x*0.348,0,0.112,0.109),
        (1.51,x*0.287,0,0.116,0.110)],linen)
    loft("hand "+str(side),[
        (0.84,x*0.415,-0.006,0.053,0.036),
        (0.92,x*0.410,-0.002,0.063,0.047),
        (1.00,x*0.405,0.005,0.061,0.055)],skin,16)
    loft("trouser leg "+str(side),[
        (0.14,x*0.143,0.006,0.095,0.092),
        (0.42,x*0.139,0.012,0.104,0.105),
        (0.65,x*0.130,-0.008,0.111,0.113),
        (0.88,x*0.126,0,0.136,0.128),
        (0.99,x*0.118,0,0.137,0.132)],linen)
    loft("boot upper "+str(side),[
        (0.045,x*0.145,-0.037,0.116,0.167),
        (0.105,x*0.145,-0.017,0.108,0.142),
        (0.205,x*0.145,0.011,0.102,0.100)],leather)
# Layered asymmetrical hair, with directional silhouette; refine by hand before acceptance.
for i in range(7):
    a=(i-3)*0.35
    loft("swept hair lock %02d"%i,[
        (1.89,0.12*math.sin(a),0.106*math.cos(a)+0.022,0.026,0.034),
        (1.99,0.12*math.sin(a+0.10),0.103*math.cos(a+0.10)+0.018,0.043,0.042),
        (2.07,0.105*math.sin(a+0.19),0.085*math.cos(a+0.19),0.023,0.025)],hair,10)

# A deform armature is included for future weight painting and animation.
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
rig=bpy.context.object
rig.name="ResidentRig_WIP"
arm=rig.data
arm.edit_bones.remove(arm.edit_bones[0])
def bone(name, head, tail, parent=None):
    b=arm.edit_bones.new(name)
    b.head=head
    b.tail=tail
    if parent: b.parent=arm.edit_bones[parent]
    return b
bone("hips",(0,0,0.93),(0,0,1.10))
bone("spine",(0,0,1.10),(0,0,1.49),"hips")
bone("neck",(0,0,1.49),(0,0,1.69),"spine")
bone("head",(0,0,1.69),(0,0,1.99),"neck")
for side, suffix in [(-1,"L"),(1,"R")]:
    bone("upper_arm_"+suffix,(side*0.29,0,1.47),(side*0.39,0,1.24),"spine")
    bone("forearm_"+suffix,(side*0.39,0,1.24),(side*0.41,0,1.02),"upper_arm_"+suffix)
    bone("thigh_"+suffix,(side*0.12,0,0.95),(side*0.14,0,0.53),"hips")
    bone("shin_"+suffix,(side*0.14,0,0.53),(side*0.145,0,0.13),"thigh_"+suffix)
bpy.ops.object.mode_set(mode='OBJECT')
# WIP: unweighted mesh is intentionally NOT claimed to be skinned or animated.
# A later pass must retopologize joints, weight paint, add facial topology and validate deformation.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=False)
print("WIP original sculpt exported:", OUT)
