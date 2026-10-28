import bpy, bmesh, sys, math, random
argv = sys.argv[sys.argv.index("--")+1:]
atlas, rings, out = argv[0], argv[1], argv[2]
R, L, N = 0.13, 1.0, 10
random.seed(3)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name, img_path):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]; t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(img_path)
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"]); b.inputs["Roughness"].default_value = 0.9
    return m
bark, cut = mat("Bark", atlas), mat("WoodCut", rings)
me = bpy.data.meshes.new("WoodLog"); o = bpy.data.objects.new("WoodLog", me); bpy.context.scene.collection.objects.link(o)
me.materials.append(bark); me.materials.append(cut)
bm = bmesh.new(); uv = bm.loops.layers.uv.new()
rad = [R*(1+random.uniform(-0.07,0.07)) for _ in range(N)]
ring = lambda x: [bm.verts.new((x, rad[i]*math.cos(2*math.pi*i/N), rad[i]*math.sin(2*math.pi*i/N))) for i in range(N)]
segs = [ring(-L/2), ring(0.0), ring(L/2)]
# slight bend in the middle ring for organic look
for v in segs[1]: v.co.z += 0.015
for a, b in zip(segs, segs[1:]):
    for i in range(N):
        j = (i+1) % N
        f = bm.faces.new((a[i], a[j], b[j], b[i])); f.material_index = 0; f.smooth = True
        for l in f.loops:
            # bark band of the KayKit atlas: u in [0,0.12], v (blender, bottom-up) in [0.53,0.73]
            k = (i if l.vert in (a[i], b[i]) else i+1)
            l[uv].uv = (0.03 + 0.06*(k/N), 0.56 + 0.14*(0.5+0.5*math.sin(k)))
for ends, flip in ((segs[0], True), (segs[-1], False)):
    vs = list(reversed(ends)) if flip else ends
    f = bm.faces.new(vs); f.material_index = 1; f.smooth = False
    for l in f.loops:
        l[uv].uv = (l.vert.co.y/(2*R)+0.5, l.vert.co.z/(2*R)+0.5)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
bm.to_mesh(me); bm.free()
o.select_set(True); bpy.context.view_layer.objects.active = o
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print("LOG OK")
