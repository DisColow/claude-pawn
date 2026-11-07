extends SceneTree
# Scénarios dans la clairière de test, captures en vue joueur.
# Modes : chop (4 coups sur Tree01, ou TREE=TreeNN), look (regard 0/-35/-70/+30°, OPEN=1 en terrain dégagé), tp (vues 3e personne).
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/play_test.gd -- prefixe chop

var out := ""
func _init() -> void:
	run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "_" + name + ".png")
	print("shot ", name)
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var mode := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "chop"
	var world: Node = load("res://scenes/world/test_forest.tscn").instantiate()
	get_root().add_child(world)
	await frames(5)
	var player: Player = world.get_node("Player")
	var tree: ChoppableTree = world.get_node("Trees/" + (OS.get_environment("TREE") if OS.get_environment("TREE") != "" else "Tree01"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tp := tree.global_position
	player.global_position = tp + Vector3(0, 0, 1.25) if OS.get_environment("OPEN") == "" else Vector3(14, 0, 16)
	player.rotation.y = 0.0
	await frames(30)
	if mode == "tp":
		player.global_position = Vector3(20, 0, 20)
		await frames(20)
		var cam := Camera3D.new(); world.add_child(cam)
		var views: Array[Vector3] = [Vector3(1.8, 1.9, -2.2), Vector3(2.2, 1.6, 0.8), Vector3(-0.3, 2.6, -0.6)]
		var axe_node: Node3D = player.body.find_children("Axe", "", true, false)[0]
		print("skel scale=", player.body.skeleton.global_basis.get_scale(), " axe scale=", axe_node.global_basis.get_scale(), " axe vis=", axe_node.is_visible_in_tree(), " meshes=", axe_node.find_children("*", "MeshInstance3D", true, false).map(func(m): return [m.name, m.get_aabb().size, m.global_basis.get_scale()]))
		print("axe global=", axe_node.global_position, " hand target=", player.body._hand_target.global_position, " shoulder=", player.body.get_shoulder_position(), " cam=", player.camera.global_position, " arm_len=", player.body.arm_length)
		for i in views.size():
			cam.global_position = player.global_position + views[i]; cam.look_at(player.global_position + Vector3(0, 1.3, 0)); cam.current = true
			await frames(3); await shot("tp%d" % i)
		player.camera.current = true
		for p in [0.0, -60.0]:
			player._pitch = deg_to_rad(p); player.head.rotation.x = player._pitch
			await frames(5); await shot("tpfp%d" % int(p))
		var vis := []
		for m in player.body.find_children("*", "GeometryInstance3D", true, false):
			vis.append([m.name, m.cast_shadow, m.is_visible_in_tree(), m.layers])
		print("geoms=", vis)
		print("cam layers=", player.camera.cull_mask, " near=", player.camera.near)
		cam.current = true
		player.axe.request_swing()
		for i in 4:
			await frames(9); cam.global_position = player.global_position + views[0]; cam.look_at(player.global_position + Vector3(0, 1.3, 0))
			await shot("tpswing%d" % i)
		quit(); return
	if mode == "look":
		for p in [0.0, -35.0, -70.0, 30.0]:
			player._pitch = deg_to_rad(p); player.head.rotation.x = player._pitch
			await frames(10); await shot("pitch%d" % int(p))
		quit(); return
	await shot("ready")
	var swing := 0
	while tree.state == ChoppableTree.State.STANDING and swing < 6:
		player.axe.request_swing(); swing += 1
		var t := 0.0
		var taken := []
		while player.axe.is_swinging():
			await physics_frame; t += 1.0 / 60.0
			if swing == 1:
				for mark in [0.15, 0.27, 0.35, 0.42, 0.47, 0.52, 0.6]:
					if t >= mark and not taken.has(mark):
						taken.append(mark); await shot("swing_%03d" % int(mark * 100))
		print("swing ", swing, " tree health=", tree.health, " state=", tree.state)
	await frames(30); await shot("falling")
	await frames(60); await shot("landed")
	await frames(90); await shot("after")
	# La souche ne doit plus bloquer : on marche droit dessus.
	var z0 := player.global_position.z
	Input.action_press("move_forward"); await frames(45); Input.action_release("move_forward")
	print("traversée de la souche : z %.2f -> %.2f (souche à z=%.2f)" % [z0, player.global_position.z, tree.global_position.z])
	quit()
