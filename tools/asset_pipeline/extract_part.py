# Extrait une pièce d'un modèle (îlots de faces d'un objet), la met à l'échelle et place son origine.
# usage : blender -b -P extract_part.py -- source.glb sortie.glb <matériau> <nb_îlots> <taille_m> <origine: center|xmax>
# Exemples (orc) :
#   crocs   : ... DIENTES_ORC.glb orc_tusks.glb colmillos 2 0.075 center
#   oreille : ... NiehausJ_Elf_Ear.glb orc_ear.glb initialShadingGroup 1 0.12 xmax
import bpy, bmesh, sys
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, out, material, n_islands, size, origin_mode = a[0], a[1], a[2], int(a[3]), float(a[4]), a[5]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == 'MESH' and any(m and m.name == material for m in o.data.materials)][0]
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.objects.active = obj; obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Garde les n plus grands îlots.
bm = bmesh.new(); bm.from_mesh(obj.data)
islands, seen = [], set()
for v in bm.verts:
    if v in seen: continue
    stack, isl = [v], []
    seen.add(v)
    while stack:
        x = stack.pop(); isl.append(x)
        for e in x.link_edges:
            y = e.other_vert(x)
            if y not in seen: seen.add(y); stack.append(y)
    islands.append(isl)
islands.sort(key=len, reverse=True)
keep = {v for isl in islands[:n_islands] for v in isl}
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in keep], context='VERTS')
bm.to_mesh(obj.data); bm.free()

co = [v.co.copy() for v in obj.data.vertices]
mn = Vector([min(c[i] for c in co) for i in range(3)]); mx = Vector([max(c[i] for c in co) for i in range(3)])
scale = size / max(mx - mn)
if origin_mode == "xmax":   # base de l'oreille : extrémité +X
    base = [c for c in co if c.x > mx.x - (mx.x - mn.x) * 0.1]
    origin = sum(base, Vector()) / len(base)
else:
    origin = (mn + mx) / 2
for v in obj.data.vertices:
    v.co = (v.co - origin) * scale
print("PART", out, "bounds", tuple(round(x, 3) for x in (mx - mn) * scale))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
