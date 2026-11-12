extends SceneTree
# Bâtiment de camp : chantier fantôme (vert, intangible) jusqu'au premier coup, étapes de construction, points de vie, dégâts, réparation, destruction, reconstruction ; tour de guet qui tire ; hôtel de ville qui passe au palier 2 ; dépôt possible de tous les côtés.
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/building_test.gd -- prefixe
var out := ""
var world: Node3D
func _init() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "_" + name + ".png")
func make(kind: String, team: int, at: Vector3, built: bool) -> CampBuilding:
	var building: CampBuilding = load("res://scenes/camp/building.tscn").instantiate()
	building.kind = kind; building.team = team; building.starts_built = built; building.position = at
	world.add_child(building)
	return building
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
	var player: Player = load("res://scenes/player/player.tscn").instantiate(); world.add_child(player)
	world.add_child(load("res://scenes/ui/hud.tscn").instantiate())
	player.global_position = Vector3(0, 0, 30)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cam := Camera3D.new(); world.add_child(cam); cam.fov = 55
	cam.global_position = Vector3(16, 10, 16); cam.look_at(Vector3(0, 2.5, -4)); cam.current = true
	var site := make("barracks", 0, Vector3(0, 0, -6), false)
	var lodge := make("war_lodge", 0, Vector3(-16, 0, -10), true)
	var tower := make("watch_tower", 0, Vector3(12, 0, -8), true)
	await frames(20)
	print("fantôme : état=%d fantôme=%s ciblable=%s collision coupée=%s PV=%.0f" % [site.state, site.ghost, site.is_targetable(), site._collision.disabled, site.health])
	await shot("ghost")
	site.auto_build = true; site.build_time = 6.0
	await frames(30); await shot("stage_a")
	print("après le premier coup : fantôme=%s étape=%d ciblable=%s" % [site.ghost, site._stage, site.is_targetable()])
	await frames(180); await shot("stage_c"); print("à 3,5 s : avancement=%.2f PV=%.0f étape=%d" % [site.build_progress, site.health, site._stage])
	await frames(190)
	print("construit : état=%d PV=%.0f/%.0f" % [site.state, site.health, site.max_health]); await shot("built")
	print("ignore la hache du joueur : %s" % (not site.has_method("take_hit")))
	site.take_damage(500.0); await frames(5); print("après 500 dégâts : PV=%.0f abîmé=%s" % [site.health, site.is_damaged()]); await shot("damaged")
	site.repair(200.0); print("après réparation de 200 : PV=%.0f" % site.health)
	site.take_damage(5000.0); await frames(60); print("détruit : état=%d ciblable=%s" % [site.state, site.is_targetable()]); await shot("ruins")
	site.take_damage(100.0); print("dégâts sur des ruines sans effet : état=%d" % site.state)
	site.begin_construction(); await frames(5); print("reconstruction commandée : état=%d fantôme=%s" % [site.state, site.ghost])
	# Tour de guet contre un ennemi.
	var foe := Unit.create("bruiser", 1); foe.position = Vector3(12, 0, 2); world.add_child(foe)
	await frames(150)
	print("tour de guet : PV de l'ennemi à portée %.0f / %.0f" % [foe.health, foe.max_health])
	foe.take_damage(9999.0)
	# Hôtel de ville : palier suivant.
	print("loge : %s palier %d nourriture %d dépôt=%s" % [lodge.building_name, lodge.tier, lodge.food(), lodge.is_dropoff()])
	lodge.start_upgrade(); lodge.upgrade_time_left = 1.0; await frames(90)
	print("après amélioration : %s palier %d nourriture %d PV max %.0f" % [lodge.building_name, lodge.tier, lodge.food(), lodge.max_health])
	# Dépôt possible depuis les quatre côtés.
	for i in 3:
		var l: WoodLog = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(l); l.global_position = Vector3(40, 0.3, 40); player.carrier.pick_up(l)
	var sides: Array[String] = []
	for direction: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		var spot := lodge.global_position + direction * (lodge.get_target_radius() + 2.0)
		player.global_position = Vector3(spot.x, 0.05, spot.z); await frames(8)
		sides.append(player.carrier._prompt)
	print("invite de dépôt des quatre côtés de la loge : %s" % str(sides))
	await shot("tier2")
	quit()
