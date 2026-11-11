extends SceneTree
# Ramassage des bûches (E) : disparition en fumée (vue subjective et de l'extérieur), pile 1 -> 10, ralentissement, charge pleine.
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/pickup_test.gd -- prefixe
var out := ""
func _init() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "_" + name + ".png")
## Oriente le joueur (lacet) et son regard (tangage) vers `target`.
func aim(player: Player, target: Vector3) -> void:
	var cam := player.camera.global_position
	var d := target - cam
	player.rotation.y = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
func press_interact() -> void:
	Input.action_press("interact"); await physics_frame; await physics_frame; Input.action_release("interact")
## Captures à quelques instants après l'appui sur E (nuage de fumée).
func film(prefix: String) -> void:
	var t := 0.0; var k := 0
	var marks := [0.03, 0.1, 0.2, 0.35, 0.55, 0.85]
	while k < marks.size():
		await physics_frame; t += 1.0 / 60.0
		if t >= marks[k]:
			await shot("%s_%02d" % [prefix, int(marks[k] * 100)]); k += 1
	await frames(10)
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var world := Node3D.new(); get_root().add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-65, 160, 0); sun.shadow_enabled = true; world.add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100, 1, 100)
	gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(100, 100); gm.mesh = pm; ground.add_child(gm); world.add_child(ground)
	var player: Player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	world.add_child(load("res://scenes/ui/hud.tscn").instantiate())
	var logs: Array[RigidBody3D] = []
	for i in 11:
		var l: RigidBody3D = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(l)
		l.global_position = Vector3((i % 4) * 1.4 - 2.1, 0.2, -1.6 - (i / 4) * 1.3)
		l.rotation.y = i * 0.7
		logs.append(l)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(60)
	player.global_position = Vector3(0, 0, 0)
	aim(player, logs[1].global_position); await frames(5)
	await shot("aim")
	print("invite : '", player.carrier._prompt, "'")
	await press_interact()
	await film("pick")
	player._pitch = 0.0; await frames(5); await shot("carry1")
	print("après 1 ramassage : bûches=", player.carrier.count, " bûches physiques restantes=", world.get_tree().get_nodes_in_group("wood_logs").size())
	# 2e ramassage filmé de l'extérieur.
	player.global_position = logs[0].global_position + Vector3(0.3, 0, 1.3); player.global_position.y = 0
	await frames(3); aim(player, logs[0].global_position); await frames(3)
	var tp_cam := Camera3D.new(); world.add_child(tp_cam); tp_cam.fov = 55
	tp_cam.global_position = player.global_position + player.global_basis * Vector3(1.9, 1.5, -1.2)
	tp_cam.look_at(player.global_position + Vector3(0, 0.9, 0) - player.global_basis.z * 0.4); tp_cam.current = true
	await press_interact()
	await film("tp")
	player.camera.current = true
	for i in [0, 2, 3, 4, 5, 6, 7, 8, 9]:
		if not is_instance_valid(logs[i]): continue
		player.global_position = logs[i].global_position + Vector3(0, 0, 1.3); player.global_position.y = 0
		await frames(3)
		aim(player, logs[i].global_position); await frames(3)
		await press_interact(); await frames(2)
	await frames(10)
	print("pile : ", player.carrier.count, "/", GameConfig.BASE_WOOD_CAPACITY, "  multiplicateur de vitesse=", player.get_carry_speed_multiplier())
	player.global_position = logs[10].global_position + Vector3(0, 0, 1.3); player.global_position.y = 0
	await frames(3); aim(player, logs[10].global_position); await frames(3)
	print("invite à 10/10 : '", player.carrier._prompt, "'")
	await press_interact(); await frames(5)
	print("ramassage refusé à 10/10 : ", is_instance_valid(logs[10]) and player.carrier.count == 10, " (bûches=", player.carrier.count, ")")
	player._pitch = 0.0; await frames(5); await shot("carry10")
	player.rotation.y += deg_to_rad(40); await frames(3); await shot("carry10_left")
	player._pitch = deg_to_rad(-45); await frames(5); await shot("carry10_down")
	Input.action_press("move_forward"); await frames(60)
	print("vitesse en marchant chargé : %.2f (attendu %.2f)" % [Vector2(player.velocity.x, player.velocity.z).length(), GameConfig.WALK_SPEED * player.get_carry_speed_multiplier()])
	Input.action_release("move_forward")
	var cam := Camera3D.new(); world.add_child(cam); cam.global_position = player.global_position + player.global_basis * Vector3(-2.2, 1.7, -1.4); cam.look_at(player.global_position + Vector3(0, 1.4, 0)); cam.current = true
	await frames(3); await shot("tp")
	quit()
