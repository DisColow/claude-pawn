"""Fabrique la pioche du péon (assets/models/props/pickaxe.glb) : manche en bois, fer à deux pointes
légèrement courbé. Mêmes conventions que la hache (axe.glb) pour qu'elle se tienne pareil en main :
manche le long de +Y, prise près de l'origine, fer dans le plan XY (export sans conversion Y-up).

Usage : blender -b -P tools/asset_pipeline/make_pickaxe.py -- assets/models/props/pickaxe.glb
"""
import math
import sys

import bmesh
import bpy

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


wood = material("Handle", (0.36, 0.22, 0.12), 0.85)
iron = material("Iron", (0.42, 0.45, 0.5), 0.45, 0.6)

mesh = bpy.data.meshes.new("Pickaxe")
obj = bpy.data.objects.new("Pickaxe", mesh)
bpy.context.scene.collection.objects.link(obj)
mesh.materials.append(wood)
mesh.materials.append(iron)
bm = bmesh.new()


def tube(points, radii, sides, mat_index, squash=1.0):
    """Tube à facettes passant par `points` (x, y), de rayon `radii` ; `squash` aplatit selon Z."""
    rings = []
    for k, ((x, y), radius) in enumerate(zip(points, radii)):
        nxt = points[min(k + 1, len(points) - 1)]
        prv = points[max(k - 1, 0)]
        angle = math.atan2(nxt[1] - prv[1], nxt[0] - prv[0])
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            # Section perpendiculaire à la direction du tube, dans le plan (normale 2D, Z).
            off = math.cos(a) * radius
            ring.append(bm.verts.new((x - math.sin(angle) * off, y + math.cos(angle) * off, math.sin(a) * radius * squash)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            face = bm.faces.new((a[i], a[j], b[j], b[i]))
            face.material_index = mat_index
    for ring in (rings[0], rings[-1]):
        face = bm.faces.new(ring)
        face.material_index = mat_index


# Manche : de -0,19 à 0,58 m, un peu plus épais vers le fer.
tube([(0.0, -0.19), (0.0, 0.2), (0.0, 0.58)], [0.024, 0.024, 0.03], 6, 0)
# Fer : arc de 0,52 m de large dont les pointes retombent, épais au centre, effilé aux bouts.
head = [(x, 0.54 - 0.5 * x * x) for x in (-0.26, -0.2, -0.1, 0.0, 0.1, 0.2, 0.26)]
tube(head, [0.006, 0.024, 0.038, 0.048, 0.038, 0.024, 0.006], 6, 1, squash=0.75)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
bm.to_mesh(mesh)
bm.free()
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=False)
print("PICKAXE OK")
