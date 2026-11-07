extends SceneTree
# Frappe un arbre 4 fois (attaquant à angle_deg autour de lui), captures avant/pendant/après l'explosion.
# usage : xvfb-run -a godot --path . -s res://tests/tree_test.gd -- prefixe res://scenes/trees/tree_2_c.tscn [angle_deg] [yaw_arbre]
func _init() -> void:
	run.call_deferred()
func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)
func run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var root := Node3D.new(); get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6,0.6,0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 35, 0); sun.shadow_enabled = true; root.add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(60, 1, 60); gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60,60); gm.mesh = pm; ground.add_child(gm); root.add_child(ground)
	var tree: ChoppableTree = load(args[1]).instantiate(); root.add_child(tree)
	tree.rotation.y = float(args[3]) if args.size() > 3 else 0.0
	var cam := Camera3D.new(); root.add_child(cam); cam.position = Vector3(7, 3.0, 4.5); cam.look_at(Vector3(0, 1.5, -2.5))
	for i in 3: await process_frame
	print("hinge=", tree.get_node("TrunkPivot").position, " len=", tree._trunk_length)
	var ang := deg_to_rad(float(args[2]) if args.size() > 2 else 0.0)
	var attacker := Vector3(sin(ang) * 2.0, 1.6, cos(ang) * 2.0)
	print("attaquant ", attacker, " -> chute attendue vers ", -Vector3(attacker.x, 0, attacker.z).normalized())
	for i in 4:
		var hp := Vector3(attacker.x, 0, attacker.z).normalized() * 0.25 + Vector3(0, 1.2, 0)
		tree.take_hit(GameConfig.AXE_DAMAGE, hp, Vector3(attacker.x, 0, attacker.z).normalized(), attacker)
		print("hit ", i, " health=", tree.health, " state=", tree.state)
		for f in 6: await physics_frame
		if i == 0: await shot(out + "_hit.png")
		for f in 30: await physics_frame
	var t := 0.0
	var shots := [0.05, 0.3, 0.8]
	var k := 0
	while t < 6.0:
		await physics_frame
		t += 1.0 / 60.0
		if k < shots.size() and t >= shots[k]:
			await shot(out + "_fall%d.png" % k); k += 1
		if k >= shots.size(): break
	for f in 20: await physics_frame
	await shot(out + "_landed.png")
	for f in 120: await physics_frame
	await shot(out + "_after.png")
	print("collisions après explosion : tronc désactivé=", tree.get_node("TrunkCollision").disabled, " souche désactivée=", tree.get_node("StumpCollision").disabled)
	var probe := PhysicsRayQueryParameters3D.create(tree.global_position + Vector3(0, 0.25, 2.0), tree.global_position + Vector3(0, 0.25, -2.0), 4)
	print("rayon à travers la souche (couche arbres) touche quelque chose : ", not tree.get_world_3d().direct_space_state.intersect_ray(probe).is_empty())
	print("logs: ", get_nodes_in_group("wood_logs").map(func(l): return l.global_position))
	quit()
