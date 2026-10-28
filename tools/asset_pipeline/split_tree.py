# Splits a KayKit tree into stump + trunk at a cut height, caps the cut with a wood-rings material.
import bpy, bmesh, sys, json, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
src, out_dir, name, cut_h, scale, rings = argv[0], argv[1], argv[2], float(argv[3]), float(argv[4]), argv[5]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
obj.scale = (scale,)*3
bpy.context.view_layer.objects.active = obj; obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

cut_mat = bpy.data.materials.new("WoodCut"); cut_mat.use_nodes = True
img = bpy.data.images.load(rings)
bsdf = cut_mat.node_tree.nodes["Principled BSDF"]; tex = cut_mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = img
cut_mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"]); bsdf.inputs["Roughness"].default_value = 0.9

def make_part(keep_above):
    o = obj.copy(); o.data = obj.data.copy(); bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0,0,cut_h), plane_no=(0,0,1), clear_inner=keep_above, clear_outer=not keep_above)
    cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    # Only cap the trunk loop: the largest connected loop crossing the plane near the axis.
    fill = bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    faces = fill["faces"]
    if not faces:
        faces = bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=cut_edges)["geom"]
        faces = [f for f in faces if isinstance(f, bmesh.types.BMFace)]
    print("CAPFACES", len(faces), "cut_edges", len(cut_edges))
    o.data.materials.append(cut_mat); mi = len(o.data.materials)-1
    uv = bm.loops.layers.uv.active
    vs = {v for f in faces for v in f.verts}
    cx = sum(v.co.x for v in vs)/max(len(vs),1); cy = sum(v.co.y for v in vs)/max(len(vs),1)
    R = max((math.hypot(v.co.x-cx, v.co.y-cy) for v in vs), default=0.1)
    for f in faces:
        f.material_index = mi; f.smooth = False
        for l in f.loops:
            l[uv].uv = ((l.vert.co.x-cx)/(2*R)+0.5, (l.vert.co.y-cy)/(2*R)+0.5)
    bmesh.ops.triangulate(bm, faces=faces)
    bm.to_mesh(o.data); bm.free()
    return o, cx, cy, R

stump, cx, cy, R = make_part(False)
trunk, _, _, _ = make_part(True)
bpy.data.objects.remove(obj)
stump.name = name + "_stump"; trunk.name = name + "_trunk"
# trunk origin at the hinge (cut centre)
bpy.context.scene.cursor.location = (cx, cy, cut_h)
for o in bpy.context.scene.objects: o.select_set(False)
trunk.select_set(True); bpy.context.view_layer.objects.active = trunk
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
top = max((trunk.matrix_world @ v.co).z for v in trunk.data.vertices)
# foliage centre of mass approx (for physics feel): average of all verts
com = sum(((trunk.matrix_world @ v.co) for v in trunk.data.vertices), Vector()) / len(trunk.data.vertices)
for o, fn in ((stump, "stump"), (trunk, "trunk")):
    for x in bpy.context.scene.objects: x.select_set(False)
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f"{out_dir}/{name}_{fn}.glb", use_selection=True, export_format='GLB', export_yup=True)
# Godot coords: x = bx, y = bz, z = -by
info = {"name": name, "cut_height": cut_h, "hinge": [cx, cut_h, -cy], "trunk_radius": R, "top_height": top, "trunk_com": [com.x, com.z, -com.y]}
print("INFO", json.dumps(info))
