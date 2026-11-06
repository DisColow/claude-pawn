extends SceneTree
# Locomotion : marche, sprint/endurance, saut, marche arrière ; affiche les vitesses mesurées.
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
	var world: Node = load("res://scenes/world/test_forest.tscn").instantiate()
	get_root().add_child(world)
	var player: Player = world.get_node("Player")
	await frames(5)
	player.global_position = Vector3(14, 0, 18); player.rotation.y = 0.0
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
