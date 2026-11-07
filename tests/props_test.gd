extends SceneTree
# Décor : le joueur doit buter contre un rocher et traverser un buisson en le faisant froisser.
# usage : xvfb-run -a godot --path . -s res://tests/props_test.gd -- prefixe
func _init() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func walk_towards(player: Player, target_z: float, max_frames: int) -> void:
	Input.action_press("move_forward")
	for i in max_frames:
		await physics_frame
		if player.global_position.z <= target_z: break
	Input.action_release("move_forward")
func run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var world := Node3D.new(); get_root().add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 35, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100, 1, 100)
	gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(100, 100); gm.mesh = pm; ground.add_child(gm); world.add_child(ground)
	var rock: Node3D = load("res://scenes/props/rock_1_a.tscn").instantiate(); world.add_child(rock); rock.position = Vector3(0, 0, -4)
	var bush: RustlingBush = load("res://scenes/props/bush_1_a.tscn").instantiate(); world.add_child(bush); bush.position = Vector3(6, 0, -4)
	var player: Player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(5)
	player.global_position = Vector3(0, 0, 0)
	await walk_towards(player, -8.0, 120)
	print("rocher : le joueur s'arrête à z=%.2f (rocher à z=-4, %s)" % [player.global_position.z, "BLOQUÉ" if player.global_position.z > -5.0 else "TRAVERSÉ"])
	player.global_position = Vector3(6, 0, 0); player.velocity = Vector3.ZERO
	await frames(5)
	var audio: AudioStreamPlayer3D = bush.get_node("RustleAudio")
	var rustles := 0
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
		if audio.playing and audio.get_playback_position() < 0.02: rustles += 1
		if i == 50:
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(out + "_bush.png")
	Input.action_release("move_forward")
	print("buisson : joueur à z=%.2f (%s), froissements déclenchés : %d" % [player.global_position.z, "TRAVERSÉ" if player.global_position.z < -6.0 else "BLOQUÉ", rustles])
	quit()
