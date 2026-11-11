extends SceneTree
# Dépôt au camp (§3.3) : invite dans la zone, E décharge la pile (vol des rondins), stock global, pile qui grandit, vitesse retrouvée.
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/deposit_test.gd -- prefixe
var out := ""
var world: Node3D
var player: Player
func _init() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "_" + name + ".png")
func aim(target: Vector3) -> void:
	var d := target - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
func press_interact() -> void:
	Input.action_press("interact"); await physics_frame; await physics_frame; Input.action_release("interact")
## Donne `n` bûches au joueur en passant par le vrai ramassage.
func give(n: int) -> void:
	for i in n:
		var l: WoodLog = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(l)
		l.global_position = Vector3(30, 0.2, 30)
		player.carrier.pick_up(l)
	await frames(15)
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var economy := CampEconomy.instance
	world = Node3D.new(); get_root().add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-65, 160, 0); sun.shadow_enabled = true; world.add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100, 1, 100)
	gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(100, 100); gm.mesh = pm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.4, 0.3); gm.material_override = mat
	ground.add_child(gm); world.add_child(ground)
	player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	world.add_child(load("res://scenes/ui/hud.tscn").instantiate())
	var pile: WoodStockpile = load("res://scenes/camp/wood_stockpile.tscn").instantiate(); world.add_child(pile)
	pile.global_position = Vector3(0, 0, -8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(60)
	await give(10)
	# Hors zone : E ne fait rien.
	aim(pile.global_position + Vector3(0, 0.5, 0)); await frames(5)
	await shot("far")
	await press_interact(); await frames(10)
	print("hors zone : invite='", player.carrier._prompt, "' bûches=", player.carrier.count, " stock=", economy.wood, " (attendu '', 10, 0)")
	# On marche jusqu'à la zone.
	Input.action_press("move_forward")
	var guard := 0
	while player.carrier._stockpile == null and guard < 600:
		await physics_frame; guard += 1
	Input.action_release("move_forward"); await frames(20)
	print("entré dans la zone après ", guard, " images, z=%.2f" % player.global_position.z, " invite='", player.carrier._prompt, "'")
	aim(pile.global_position + Vector3(0, 0.4, 0)); await frames(5)
	await shot("zone")
	await press_interact()
	await frames(8); await shot("unload_a")
	await frames(14); await shot("unload_b")
	await frames(25); await shot("unload_c")
	await frames(60)
	print("après dépôt : bûches=", player.carrier.count, " stock=", economy.wood, " posées=", pile.landed, " multiplicateur=", player.get_carry_speed_multiplier(), " invite='", player.carrier._prompt, "' (attendu 0, 10, 10, 1.0, '')")
	await shot("pile10")
	# Deuxième et troisième voyages : la pile grandit.
	for trip in 3:
		await give(10); await press_interact(); await frames(110)
	print("après 4 voyages : stock=", economy.wood, " posées=", pile.landed, " (attendu 40, 40)")
	await shot("pile40")
	# Sortir de la zone pendant le déchargement : le reste est gardé.
	await give(10); await press_interact(); await frames(12)
	player.global_position = Vector3(0, 0, 10); await frames(60)
	print("sortie en cours de dépôt : bûches gardées=", player.carrier.count, " stock=", economy.wood, " posées=", pile.landed, " (somme attendue 50 : ", player.carrier.count + economy.wood, ")")
	# Pile au maximum visible, vue de l'extérieur.
	player.global_position = Vector3(0, 0, -5); await frames(10)
	while pile.landed < WoodStockpile.max_visible_logs() + 6:
		if player.carrier.count == 0: await give(10)
		await press_interact(); await frames(110)
	print("pile pleine : stock=", economy.wood, " posées=", pile.landed, " visibles=", pile._multimesh.visible_instance_count, "/", WoodStockpile.max_visible_logs())
	# La pile est solide : marcher dessus ne la traverse pas.
	player.global_position = Vector3(0, 0, -5.5); aim(pile.global_position + Vector3(0, 1.6, 0)); await frames(5)
	Input.action_press("move_forward"); await frames(120); Input.action_release("move_forward")
	print("bloqué par la pile : z=%.2f (la pile est en z=-8, demi-largeur ~0.9)" % player.global_position.z)
	await shot("pile_full_fp")
	var cam := Camera3D.new(); world.add_child(cam); cam.fov = 55
	cam.global_position = Vector3(4.5, 3.0, -3.5); cam.look_at(Vector3(0, 0.7, -7.6)); cam.current = true
	await frames(5); await shot("pile_full_tp")
	quit()
