import bpy, sys
argv = sys.argv[sys.argv.index("--")+1:]
char, ual, texdir, out = argv[0], argv[1], argv[2], argv[3]
KEEP = ["Idle_Loop","Walk_Loop","Jog_Fwd_Loop","Sprint_Loop","Jump_Start","Jump_Loop","Jump_Land","Sword_Attack","Sword_Idle","PickUp_Table","Interact"]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=char)
char_objs = set(bpy.context.scene.objects)
arm = [o for o in char_objs if o.type == 'ARMATURE'][0]
for o in list(char_objs):
    if o.type == 'MESH':
        mats = [m.name for m in o.data.materials if m]
        print("MESH", o.name, mats)
        if any("Hair" in m for m in mats) or not mats: bpy.data.objects.remove(o)
mat = bpy.data.materials["MI_Superhero_Male"]
for n in mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and n.image:
        nm = n.image.name
        for key, f in (("Dark", "T_Orc_BaseColor.png"), ("Normal", "T_Orc_Normal.png"), ("Roughness", "T_Orc_Roughness.png")):
            if key in nm: n.image = bpy.data.images.load(f"{texdir}/{f}"); print("swap", nm, "->", f)
before = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=ual)
for o in set(bpy.context.scene.objects) - char_objs: bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a.name in KEEP: a.use_fake_user = True
    else: bpy.data.actions.remove(a)
arm.name = "OrcRig"
arm.animation_data_create()
# push every action into its own NLA track so the exporter picks them all
for a in bpy.data.actions:
    tr = arm.animation_data.nla_tracks.new(); tr.name = a.name
    st = tr.strips.new(a.name, int(a.frame_range[0]), a); st.name = a.name
    if hasattr(st, "action_slot") and a.slots: st.action_slot = a.slots[0]
arm.animation_data.action = None
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animation_mode='NLA_TRACKS', export_image_format='AUTO')
print("ORC OK", [a.name for a in bpy.data.actions])
