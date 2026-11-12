extends SceneTree
# Partie complète dans la forêt : ordres du Général, mine d'or (veines à la pioche), construction par le péon, grunts, vague de squelettes, tours, combat et mort du joueur, défaite (ou victoire avec l'argument "victory").
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 960x540 -s res://tests/game_test.gd -- prefixe [victory]
var out := ""
var world: Node
var player: Player
var general: General
var director: GameDirector
var overview: Camera3D
func _init() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "_" + name + ".png")
func look_at_point(target: Vector3) -> void:
	var d := target - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
func view(from: Vector3, target: Vector3) -> void:
	overview.global_position = from; overview.look_at(target); overview.current = true
## Commande le bâtiment `index` du plan (ressources données au camp), puis le péon le construit.
func build(index: int, wood: int, gold: int, capture: String = "") -> void:
	CampEconomy.instance.add_wood(wood); CampEconomy.instance.add_gold(gold)
	await frames(70)
	var site := general.get_building(index)
	print("  ordre : ", general.order, " | chantier posé=", site != null, " stock=", CampEconomy.instance.wood, "/", CampEconomy.instance.gold)
	site.build_time = 2.0
	var toward_center := (Vector3.ZERO - site.global_position).normalized()
	player.global_position = site.global_position + toward_center * (site.get_target_radius() + 1.5); player.global_position.y = 0
	look_at_point(site.global_position + Vector3(0, 2, 0)); await frames(10)
	print("  invite : '", player.carrier._prompt, "'")
	Input.action_press("interact"); await frames(50)
	if capture != "":
		player.camera.current = true; await shot(capture)
	var guard := 0
	while site.state == CampBuilding.State.UNDER_CONSTRUCTION and guard < 400:
		await physics_frame; guard += 1
	Input.action_release("interact"); await frames(5)
	print("  ", site.building_name, " : état=", site.state, " PV=%.0f/%.0f" % [site.health, site.max_health])
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var victory_mode := OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "victory"
	world = load("res://scenes/world/test_forest.tscn").instantiate(); get_root().add_child(world)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player = world.get_node("Player"); general = world.get_node("General"); director = world.get_node("GameDirector")
	overview = Camera3D.new(); world.add_child(overview); overview.fov = 60; overview.far = 300
	await frames(90)
	if victory_mode:
		director.wave = GameConfig.WAVE_COUNT; await frames(10)
		print("victoire : ended=", director.ended, " victory=", director.victory); await shot("victory"); quit(); return
	player.camera.current = true; await shot("spawn")
	view(Vector3(8, 55, 30), Vector3(8, 0, -6)); await frames(5); await shot("overview")
	print("ordre initial : ", general.order, " | vague dans %.0f s" % director.time_to_next)
	# --- Mine d'or -> bastion
	var mine: Node3D = world.get_node("GoldMine")
	player.camera.current = true
	var mouth := mine.global_position + mine.global_basis.z * 13.0
	player.global_position = Vector3(mouth.x, 0, mouth.z); look_at_point(mine.global_position + Vector3(0, 2, 0)); await frames(20)
	await shot("mine")
	var vein: GoldVein = get_nodes_in_group("gold_veins")[4]
	var front := vein.global_position - vein.global_basis.z * 1.7
	player.global_position = Vector3(front.x, 0, front.z); await frames(20)
	print("mine : invite='", player.carrier._prompt, "'")
	for i in GameConfig.BASE_GOLD_CAPACITY:
		look_at_point(vein.global_position); player.axe.request_swing()
		await frames(int(GameConfig.AXE_SWING_DURATION * 60) + 4)
		if i == 4: await shot("mining")
	print("mine : or porté=", player.carrier.gold, " invite='", player.carrier._prompt, "'")
	player.global_position = Vector3(1.5, 0, 3.0); look_at_point(Vector3(0, 4, -6)); await frames(20)
	print("bastion : invite='", player.carrier._prompt, "'"); await shot("bastion")
	Input.action_press("interact"); await frames(3); Input.action_release("interact"); await frames(5)
	print("bastion : or du camp=", CampEconomy.instance.gold, " or porté=", player.carrier.gold)
	# --- Plan du Général
	print("scierie :"); await build(0, 30, 0, "build_fp")
	print("tour 1 :"); await build(1, 30, 10)
	print("caserne :"); await build(2, 50, 40)
	print("tour 2 :"); await build(3, 30, 20)
	CampEconomy.instance.add_gold(50); await frames(80)
	print("grunts : ", get_nodes_in_group("orc_units").size(), " | ordre : ", general.order, " | or restant=", CampEconomy.instance.gold)
	view(Vector3(20, 9, 16), Vector3(9, 1.5, 6)); await frames(5); await shot("camp")
	# --- Vague
	director.start_next_wave(); director.start_next_wave(); director.start_next_wave()
	print("vague ", director.wave, " : à faire apparaître=", director.get_pending_spawns())
	await frames(240)
	view(Vector3(9, 14, -8), Vector3(0, 1, -24)); await frames(3); await shot("wave_road")
	var t := 0
	while (get_nodes_in_group("undead_units").size() > 0 or director.get_pending_spawns() > 0) and t < 3000:
		await physics_frame; t += 1
		if t == 420: view(Vector3(14, 16, 2), Vector3(0, 1, -14)); await shot("wave_fight")
	print("vague repoussée en %.0f s : squelettes restants=" % (t / 60.0), get_nodes_in_group("undead_units").size(), " grunts vivants=", get_nodes_in_group("orc_units").size())
	for b in get_nodes_in_group("camp_buildings"): print("  ", b.building_name, " PV=%.0f/%.0f" % [b.health, b.max_health])
	# --- Le joueur se bat
	player.global_position = Vector3(-6, 0, 12); player.rotation.y = 0; player._pitch = 0; await frames(10)
	var foe: Unit = load("res://scenes/units/skeleton_minion.tscn").instantiate(); foe.position = Vector3(-6, 0, 6); world.add_child(foe)
	player.camera.current = true
	var k := 0
	while player.health >= GameConfig.PLAYER_MAX_HEALTH and k < 600: await physics_frame; k += 1
	await shot("fight_fp")
	print("le squelette frappe le joueur : PV=%.0f après %.1f s" % [player.health, k / 60.0])
	k = 0
	while not foe.is_dead() and k < 900:
		look_at_point(foe.global_position + Vector3(0, 1.0, 0)); player.axe.request_swing(); await physics_frame; k += 1
	print("le joueur tue le squelette : mort=", foe.is_dead(), " en %.1f s, PV joueur=%.0f" % [k / 60.0, player.health])
	# --- Mort et réapparition
	player.take_damage(500.0); await frames(30); await shot("dead")
	print("mort : ", player.is_dead(), " réapparition dans %.1f s" % player.get_respawn_time())
	await frames(int(GameConfig.PLAYER_RESPAWN_TIME * 60) + 10)
	print("réapparu : mort=", player.is_dead(), " PV=%.0f position=" % player.health, player.global_position.snapped(Vector3.ONE * 0.1))
	# --- Défaite
	var bastion: CampBuilding = world.get_node("Bastion")
	view(Vector3(14, 10, 14), Vector3(0, 4, -5)); bastion.take_damage(99999.0); await frames(40)
	print("bastion détruit : ended=", director.ended, " victory=", director.victory); await shot("defeat")
	quit()
