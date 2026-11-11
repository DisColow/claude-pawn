extends SceneTree
# Scierie (bâtiment du camp) : chantier par étapes, points de vie qui montent, dépôt refusé hors « debout », dégâts, destruction, reconstruction.
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/building_test.gd -- prefixe
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
func press_interact() -> void:
	Input.action_press("interact"); await physics_frame; await physics_frame; Input.action_release("interact")
func give(n: int) -> void:
	for i in n:
		var l: WoodLog = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(l)
		l.global_position = Vector3(30, 0.2, 30)
		player.carrier.pick_up(l)
	await frames(15)
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	world = Node3D.new(); get_root().add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 150, 0); sun.shadow_enabled = true; world.add_child(sun)
	var ground := StaticBody3D.new(); var gs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100, 1, 100)
	gs.shape = box; gs.position.y = -0.5; ground.add_child(gs)
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(100, 100); gm.mesh = pm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.4, 0.3); gm.material_override = mat
	ground.add_child(gm); world.add_child(ground)
	player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	world.add_child(load("res://scenes/ui/hud.tscn").instantiate())
	var mill: LumberMill = load("res://scenes/camp/lumber_mill.tscn").instantiate()
	mill.starts_built = false
	world.add_child(mill)
	mill.global_position = Vector3(0, 0, -12)
	mill.build_time = 6.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cam := Camera3D.new(); world.add_child(cam); cam.fov = 55
	cam.global_position = Vector3(9, 5.5, 1); cam.look_at(Vector3(0, 2.5, -10)); cam.current = true
	# Le joueur attend dans la cour, chargé : pas de dépôt tant que la scierie est en chantier.
	player.global_position = mill.global_position + Vector3(2.6, 0, 5.2); player.rotation.y = PI * 0.5
	await frames(20)
	await give(5)
	print("chantier : état=", mill.state, " PV=%.0f/%.0f" % [mill.health, mill.max_health], " invite='", player.carrier._prompt, "' (attendu état 0, ~10 % des PV, '')")
	await press_interact(); await frames(5)
	print("E en chantier : bûches=", player.carrier.count, " stock=", CampEconomy.instance.wood, " (attendu 5, 0)")
	await shot("stage_a")
	await frames(120); await shot("stage_b"); print("à 2 s : avancement=%.2f PV=%.0f étape=%d" % [mill.build_progress, mill.health, mill._stage])
	await frames(130); await shot("stage_c"); print("à 4 s : avancement=%.2f PV=%.0f étape=%d" % [mill.build_progress, mill.health, mill._stage])
	await frames(140)
	print("construite : état=", mill.state, " PV=%.0f" % mill.health, " invite='", player.carrier._prompt, "' (attendu état 1, 1200, '[E] Déposer le bois (5)')")
	await shot("built")
	await press_interact(); await frames(90)
	print("dépôt : bûches=", player.carrier.count, " stock=", CampEconomy.instance.wood, " (attendu 0, 5)")
	# La hache du joueur ne l'abîme pas ; les dégâts ennemis (take_damage) si.
	print("la scierie ignore la hache : ", not mill.has_method("take_hit"))
	mill.take_damage(500.0); await frames(10)
	print("après 500 dégâts : PV=%.0f état=%d" % [mill.health, mill.state]); await shot("damaged")
	mill.repair(200.0); print("après réparation de 200 : PV=%.0f" % mill.health)
	await give(4)
	mill.take_damage(2000.0); await frames(12); await shot("collapse")
	await frames(120)
	print("détruite : état=", mill.state, " PV=%.0f" % mill.health, " invite='", player.carrier._prompt, "' stock conservé=", CampEconomy.instance.wood, " (attendu état 2, 0, '', 5)")
	await press_interact(); await frames(10)
	print("E sur les ruines : bûches=", player.carrier.count, " (attendu 4)")
	await shot("ruins")
	mill.take_damage(100.0); print("dégâts sur des ruines : sans effet, état=", mill.state)
	# Le joueur ne traverse pas le bâtiment.
	mill.begin_construction(); mill.build_time = 2.0; await frames(140)
	print("reconstruite : état=", mill.state, " PV=%.0f" % mill.health, " invite='", player.carrier._prompt, "'")
	player.global_position = mill.global_position + Vector3(0, 0, -9); player.rotation.y = PI; await frames(5)
	Input.action_press("move_forward"); await frames(150); Input.action_release("move_forward")
	print("bloqué par le bâtiment : distance au centre=%.2f m" % (player.global_position - mill.global_position).length())
	# Chantier détruit avant la fin.
	mill.begin_construction(); await frames(20); mill.take_damage(500.0); await frames(5)
	print("chantier détruit : état=", mill.state, " (attendu 2)")
	mill.begin_construction(); mill.build_time = 1.0; await frames(80)
	player.camera.current = true
	player.global_position = mill.global_position + Vector3(4.5, 0, 9); await frames(3)
	var d := mill.global_position + Vector3(0, 3.0, 0) - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z); player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	mill.take_damage(300.0); await frames(10); await shot("fp")
	quit()
