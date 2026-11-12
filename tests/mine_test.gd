extends SceneTree
# Mine d'or (§5.1) : entrer dans la mine, pioche en main, 1 or par coup sur une veine jusqu'à 10, veine qui s'épuise, bois et or exclusifs, charge lâchée au sol à la mort puis ramassée.
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/mine_test.gd -- prefixe
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
## Donne `n` coups d'outil en visant `target`.
func swings(n: int, target: Vector3) -> void:
	for i in n:
		aim(target); player.axe.request_swing()
		await frames(int(GameConfig.AXE_SWING_DURATION * 60) + 4)
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	world = Node3D.new(); get_root().add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 150, 0); sun.shadow_enabled = true; world.add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(200, 1, 200)
	gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); gm.mesh = pm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.4, 0.3); gm.material_override = mat
	ground.add_child(gm); world.add_child(ground)
	player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	world.add_child(load("res://scenes/ui/hud.tscn").instantiate())
	var mine: GoldMine = load("res://scenes/world/gold_mine.tscn").instantiate(); world.add_child(mine)
	mine.global_position = Vector3(0, 0, -30)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cam := Camera3D.new(); world.add_child(cam); cam.fov = 55
	cam.global_position = Vector3(17, 10, -6); cam.look_at(Vector3(0, 3, -29)); cam.current = true
	player.global_position = Vector3(0, 0, -14); player.rotation.y = 0
	await frames(40); await shot("outside_tp")
	player.camera.current = true; await frames(3); await shot("outside_fp")
	# On marche jusque dans la mine.
	Input.action_press("move_forward")
	var guard := 0
	while player.carrier._mine == null and guard < 600: await physics_frame; guard += 1
	await frames(60); Input.action_release("move_forward"); await frames(20)
	print("entré dans la mine après ", guard, " images : z=%.1f pioche en main=" % player.global_position.z, player.body._tool_attachments[0].get_child(0).find_children("*", "MeshInstance3D", true, false)[0].name, " invite='", player.carrier._prompt, "'")
	await shot("inside")
	var vein: GoldVein = get_nodes_in_group("gold_veins")[4]
	var front := vein.global_position - vein.global_basis.z * 1.7
	player.global_position = Vector3(front.x, 0, front.z); await frames(5); aim(vein.global_position); await frames(10)
	await shot("vein")
	player.axe.request_swing(); await frames(27); await shot("strike"); await frames(30)
	print("après 1 coup : or=", player.carrier.gold, " veine=", vein.gold_left, "/", GameConfig.VEIN_GOLD)
	await swings(9, vein.global_position)
	print("après 10 coups : or=", player.carrier.gold, " multiplicateur de vitesse=", player.get_carry_speed_multiplier(), " invite='", player.carrier._prompt, "'")
	await swings(2, vein.global_position)
	print("coups en trop : or=", player.carrier.gold, " veine=", vein.gold_left, " (attendu 10, 30)")
	# Veine qui s'épuise.
	vein.extract(26); await frames(5); await shot("vein_low")
	print("veine presque vide : reste=", vein.gold_left, " pépites visibles=", vein._nuggets.filter(func(n: MeshInstance3D) -> bool: return n.visible).size(), "/", GoldVein.NUGGETS)
	# Bois et or exclusifs.
	var wood: WoodLog = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(wood)
	wood.global_position = player.global_position - player.global_basis.z * 1.2 + Vector3(0, 0.2, 0); await frames(40)
	aim(wood.global_position); await frames(5)
	print("bûche visée avec de l'or : invite='", player.carrier._prompt, "'"); await press_interact(); await frames(5)
	print("  bois porté=", player.carrier.count, " (attendu 0)")
	# Mort : le sac tombe au sol ; on revient le ramasser.
	var death_spot := player.global_position
	player.take_damage(999.0); await frames(20)
	print("mort : or porté=", player.carrier.gold, " sacs au sol=", get_nodes_in_group("gold_sacks").size(), " contenu=", (get_nodes_in_group("gold_sacks")[0] as GoldSack).amount)
	await frames(int(GameConfig.PLAYER_RESPAWN_TIME * 60) + 10)
	wood.queue_free()
	var sack: GoldSack = get_nodes_in_group("gold_sacks")[0]
	player.global_position = Vector3(sack.global_position.x, 0, sack.global_position.z + 0.9); await frames(10); aim(sack.global_position + Vector3(0, 0.15, 0)); await frames(5)
	print("sac visé : invite='", player.carrier._prompt, "'"); await shot("sack")
	await press_interact(); await frames(5)
	print("sac ramassé : or=", player.carrier.gold, " sacs au sol=", get_nodes_in_group("gold_sacks").size())
	# Avec du bois, la veine ne donne rien.
	player.carrier._set_gold(0)
	var l2: WoodLog = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(l2); player.carrier.pick_up(l2); await frames(10)
	player.global_position = Vector3(front.x, 0, front.z); await frames(5)
	await swings(2, vein.global_position)
	print("coups avec du bois : or=", player.carrier.gold, " invite='", player.carrier._prompt, "'")
	# Sortie : on reprend la hache. Vue de dos pour le sac à dos.
	player.carrier.drop_on_ground(); await frames(5); for l in get_nodes_in_group("wood_logs"): l.queue_free()
	player.carrier._set_gold(10)
	player.global_position = Vector3(0, 0, -12); player.rotation.y = PI; player._pitch = 0; await frames(20)
	print("dehors : outil=", player.body._tool_attachments[0].get_child(0).find_children("*", "MeshInstance3D", true, false)[0].name, " dans une mine=", player.carrier._mine != null)
	cam.global_position = player.global_position + player.global_basis * Vector3(1.0, 1.9, 2.6); cam.look_at(player.global_position + Vector3(0, 1.2, 0)); cam.current = true
	await frames(5); await shot("backpack")
	quit()
