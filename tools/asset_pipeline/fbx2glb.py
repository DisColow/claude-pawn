import bpy, sys
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=argv[0])
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in bpy.context.scene.objects: o.select_set(o.type=='MESH')
bpy.context.view_layer.objects.active=ms[0]
if len(ms)>1: bpy.ops.object.join()
o=bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mn=Vector((min(v.co[i] for v in o.data.vertices) for i in range(3))); mx=Vector((max(v.co[i] for v in o.data.vertices) for i in range(3)))
print("BOUNDS", tuple(round(x,3) for x in mn), tuple(round(x,3) for x in mx), "mats", [m.name for m in o.data.materials], [tuple(round(c,2) for c in m.diffuse_color) for m in o.data.materials])
for m in o.data.materials:
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                for l in list(n.inputs['Alpha'].links): m.node_tree.links.remove(l)
                n.inputs['Alpha'].default_value = 1.0
    if m:
        m.diffuse_color[3] = 1.0
        if hasattr(m, 'surface_render_method'): m.surface_render_method = 'DITHERED'
        m.use_backface_culling = True
if len(argv)>1:
    s=float(argv[2]); o.scale=(s,s,s); bpy.ops.object.transform_apply(scale=True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format='GLB', use_selection=True)
