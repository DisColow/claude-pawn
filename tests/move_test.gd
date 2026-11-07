extends SceneTree
# Locomotion : marche, sprint/endurance, saut, marche arrière ; affiche les vitesses mesurées.
# Terrain plat dédié (la forêt de test est trop dense pour courir 45 m en ligne droite).
# usage : xvfb-run -a godot --path . -s res://tests/move_test.gd -- prefixe
var out := ""
func _init() -> void:
	run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "_" + name + ".png")
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var world := Node3D.new(); get_root().add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 35, 0); sun.shadow_enabled = true; world.add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(200, 1, 200)
	gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); gm.mesh = pm; ground.add_child(gm); world.add_child(ground)
	var player: Player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	world.add_child(load("res://scenes/ui/hud.tscn").instantiate())
	await frames(5)
	player.global_position = Vector3(0, 0, 40); player.rotation.y = 0.0
	player._pitch = deg_to_rad(-45); player.head.rotation.x = player._pitch
	await frames(10)
	var p0 := player.global_position
	Input.action_press("move_forward")
	await frames(60)
	print("walk speed=", Vector2(player.velocity.x, player.velocity.z).length(), " (attendu ", GameConfig.WALK_SPEED, ")")
	await shot("walk")
	Input.action_press("sprint")
	await frames(90)
	print("sprint speed=", Vector2(player.velocity.x, player.velocity.z).length(), " stamina=", player.stamina)
	await shot("sprint")
	await frames(240)
	print("after 5.5s sprint: speed=", Vector2(player.velocity.x, player.velocity.z).length(), " stamina=", player.stamina)
	Input.action_release("sprint"); Input.action_release("move_forward")
	player.carried_logs = 10
	print("carry multiplier at 10 logs=", player.get_carry_speed_multiplier())
	player.carried_logs = 0
	Input.action_press("jump"); await frames(2); Input.action_release("jump")
	await frames(12)
	print("jump: y=", player.global_position.y, " on_floor=", player.is_on_floor())
	await shot("jump")
	await frames(60)
	print("landed y=", player.global_position.y, " moved=", player.global_position.distance_to(p0))
	Input.action_press("move_back"); await frames(40)
	print("back speed=", Vector2(player.velocity.x, player.velocity.z).length())
	await shot("back")
	quit()
