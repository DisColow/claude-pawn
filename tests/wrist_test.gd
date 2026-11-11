extends SceneTree
# Angle du poignet droit (avant-bras / main) pendant le ramassage, pour plusieurs orientations de bûche.
# Un poignet réel plie confortablement jusqu'à ~45-60° ; au-delà, l'angle est jugé impossible.
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/wrist_test.gd -- prefixe
var max_angle := 0.0
var last_angle := 0.0
var player_ref: Player
var phase_max := {}
const PHASES := ["rangement", "descente", "montée", "reprise", "garde"]
var skeleton: Skeleton3D
func _init() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func _on_skeleton_updated() -> void:
	var lower := skeleton.get_bone_global_pose(skeleton.find_bone("lowerarm_r"))
	var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))
	var forearm := (hand.origin - lower.origin).normalized()
	last_angle = rad_to_deg(forearm.angle_to(hand.basis.y.normalized()))
	max_angle = maxf(max_angle, last_angle)
	if player_ref and player_ref.carrier.is_busy():
		var t: float = player_ref.carrier._time
		var bounds := [GameConfig.PICKUP_STOW_TIME, GameConfig.PICKUP_GRAB_TIME, GameConfig.PICKUP_PLACE_TIME, GameConfig.PICKUP_DRAW_TIME, 99.0]
		if OS.get_environment("TRACE") != "" and t > GameConfig.PICKUP_PLACE_TIME - 0.1 and t < GameConfig.PICKUP_DURATION:
			print("  t=%.2f poignet=%.0f°" % [t, last_angle])
		for i in bounds.size():
			if t < bounds[i]:
				phase_max[PHASES[i]] = maxf(phase_max.get(PHASES[i], 0.0), last_angle)
				break
func run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var world := Node3D.new(); get_root().add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-65, 160, 0); world.add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100, 1, 100)
	gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(100, 100); gm.mesh = pm; ground.add_child(gm); world.add_child(ground)
	var player: Player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(5)
	skeleton = player.body.skeleton
	player_ref = player
	skeleton.skeleton_updated.connect(_on_skeleton_updated)
	var rest_lower := skeleton.get_bone_global_rest(skeleton.find_bone("lowerarm_r"))
	var rest_hand := skeleton.get_bone_global_rest(skeleton.find_bone("hand_r"))
	print("repos (T-pose) : %.0f°" % rad_to_deg((rest_hand.origin - rest_lower.origin).normalized().angle_to(rest_hand.basis.y.normalized())))
	max_angle = 0.0
	await frames(60)
	print("hache en garde : %.0f° (max %.0f°)" % [last_angle, max_angle])
	for yaw_deg in [90, 45, 0, -45]:
		var wood_log: RigidBody3D = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(wood_log)
		wood_log.global_position = Vector3(0, 0.15, -1.6)
		wood_log.rotation.y = deg_to_rad(yaw_deg)  # 90° : la bûche pointe droit devant le joueur
		await frames(40)
		player.global_position = Vector3.ZERO; player.rotation.y = 0.0
		var d := wood_log.global_position - player.camera.global_position
		player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await frames(5)
		max_angle = 0.0
		phase_max = {}
		Input.action_press("interact"); await frames(2); Input.action_release("interact")
		var shot_taken := false
		while player.carrier.is_busy():
			await physics_frame
			if not shot_taken and player.carrier._time >= GameConfig.PICKUP_GRAB_TIME:
				shot_taken = true
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png(out + "_yaw%d.png" % yaw_deg)
		var detail := PHASES.filter(func(p): return phase_max.has(p)).map(func(p): return "%s %.0f°" % [p, phase_max[p]])
		print("bûche à %+d° : angle de poignet max = %.0f°  (%s)" % [yaw_deg, max_angle, ", ".join(detail)])
	quit()
