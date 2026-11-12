extends SceneTree
# Partie jouée par script sur la carte « La Vallée » : dépôt direct dans la loge, chantier fantôme puis construction au marteau, ordres et loyauté, roue de communication et confiance, XP et talents, traître, mort et nouveau péon, assaut ennemi et appel aux armes, victoire et Renom.
# usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1280x720 -s res://tests/match_test.gd -- prefixe
var out := ""
var world: Node
var player: Player
var general: General
var orders: WorkerOrders
var director: GameDirector
var cam: Camera3D
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
func stand_near(building: CampBuilding, direction: Vector3, gap: float) -> void:
	var spot := building.global_position + direction.normalized() * (building.get_target_radius() + gap)
	player.global_position = Vector3(spot.x, 0.05, spot.z)
	look_at_point(building.global_position + Vector3(0, 2, 0))
func press_interact() -> void:
	Input.action_press("interact"); await physics_frame; await physics_frame; Input.action_release("interact")
func give_wood(n: int) -> void:
	for i in n:
		var l: WoodLog = load("res://scenes/props/wood_log.tscn").instantiate(); world.add_child(l)
		l.global_position = Vector3(0, 0.3, 60); player.carrier.pick_up(l)
	await frames(10)
func order_texts() -> Array:
	return orders.active.map(func(o: Dictionary) -> String: return o["text"])
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	MetaProgress.instance.pending = {"map": "valley", "difficulty": "normal", "mission": -1}
	MetaProgress.instance.upgrades = {}
	world = load("res://scenes/world/map_valley.tscn").instantiate(); get_root().add_child(world)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player = world.get_node("Player"); general = world.get_node("General0"); director = world.get_node("GameDirector")
	cam = Camera3D.new(); world.add_child(cam); cam.fov = 60; cam.far = 600
	await frames(120)
	orders = general.orders
	var lodge := general.town_hall()
	player.camera.current = true; await shot("spawn")
	print("départ : stock=%d/%d péons du Général=%d loyauté=%.0f confiance=%.0f ordres=%s" % [general.camp.wood, general.camp.gold, general.peons().size(), orders.loyalty, orders.trust, str(order_texts())])
	# --- Chantier fantôme (le Général commande un terrier avec le stock de départ)
	var site := general.current_site()
	print("chantier : %s fantôme=%s ciblable=%s collision coupée=%s" % [site.building_name, site.ghost, site.is_targetable(), site._collision.disabled])
	for peon in general.peons(): peon.assign("wood", peon.global_position)
	general.set_physics_process(false)  # le joueur construit seul, pour le test
	stand_near(site, lodge.global_position - site.global_position, 6.0); await frames(10); await shot("ghost")
	stand_near(site, lodge.global_position - site.global_position, 1.5); await frames(20)
	print("  devant le chantier : invite='%s' outil=%s" % [player.carrier._prompt, player.carrier._tool])
	Input.action_press("interact"); await frames(14)
	print("  marteau levé (avant le 1er coup) : fantôme=%s" % site.ghost)
	await frames(30)
	print("  après le 1er coup : fantôme=%s avancement=%.2f collision coupée=%s" % [site.ghost, site.build_progress, site._collision.disabled]); await shot("hammer")
	var guard := 0
	while site.state == CampBuilding.State.UNDER_CONSTRUCTION and guard < 900: await physics_frame; guard += 1
	Input.action_release("interact"); await frames(5)
	print("  bâti en %.1f s : état=%d PV=%.0f travail du joueur=%.1f s outil=%s niveau=%d xp=%d" % [guard / 60.0, site.state, site.health, site.player_work, player.carrier._tool, player.progress.level, player.progress.xp])
	general.set_physics_process(true); await frames(90)
	print("  ordres=%s loyauté=%.1f" % [str(order_texts()), orders.loyalty])
	# --- Dépôt direct dans la loge, par derrière
	await give_wood(10)
	stand_near(lodge, Vector3(0.3, 0, -1), 2.0); await frames(10)
	print("dépôt par l'arrière de la loge : invite='%s' stock bois avant=%d" % [player.carrier._prompt, general.camp.wood])
	var before := general.camp.wood
	await press_interact(); await frames(20); await shot("deposit"); await frames(80)
	print("  bois porté=%d crédité=%d loyauté=%.1f xp=%d" % [player.carrier.count, general.camp.wood - before, orders.loyalty, player.progress.xp])
	# --- XP, niveaux, talents
	player.progress.add_xp(400)
	print("talents : niveau=%d points=%d capacité bois=%d PV max=%.0f" % [player.progress.level, player.progress.points, player.wood_capacity(), player.max_health()])
	for talent in ["efficient_swings", "efficient_swings", "strong_back", "thick_skin"]: player.progress.spend(talent)
	print("  après dépense : rangs=%s points=%d capacité bois=%d PV max=%.0f vitesse d'outil=%.2f | palier 3 sans les points requis : %s" % [
		str(player.progress.ranks), player.progress.points, player.wood_capacity(), player.max_health(), player.swing_speed(), player.progress.can_spend("light_load")])
	var screen: TalentScreen = world.get_node("HUD/Root").get_children().filter(func(n: Node) -> bool: return n is TalentScreen)[0]
	screen.toggle(); await process_frame; await process_frame; await shot("talents")
	print("  écran ouvert, partie en pause=%s" % paused)
	screen.toggle(); await frames(5)
	print("  écran fermé, partie en pause=%s" % paused)
	# --- Roue de communication et confiance
	general.make_mistake("no_warriors"); orders.trust = 90.0
	Input.action_press("comm_wheel"); await frames(5); await shot("wheel"); Input.action_release("comm_wheel"); await frames(3)
	var result := orders.suggest("train")
	print("conseil juste, confiance 90 : %s | erreur corrigée=%s confiance=%.0f xp=%d" % [str(result), not general.mistakes.has("no_warriors"), orders.trust, player.progress.xp])
	print("  second conseil trop tôt : %s" % str(orders.suggest("attack")))
	orders.influence_cooldown = 0.0; orders.trust = 0.0
	var refused := 0
	for i in 8:
		orders.influence_cooldown = 0.0
		if not orders.suggest("retreat")["accepted"]: refused += 1
	print("  conseil absurde, confiance 0 : refusé %d fois sur 8, confiance=%.0f" % [refused, orders.trust])
	# --- Traître
	orders.add_loyalty(-200.0); await frames(30)
	var hunters := get_nodes_in_group("army_0").filter(func(u: Unit) -> bool: return u.hunt_target == player)
	print("loyauté 0 : traître=%s exécuteurs=%d ordres=%s" % [orders.traitor, hunters.size(), str(order_texts())])
	orders.add_loyalty(20.0); await frames(30)
	print("  loyauté remontée : traître=%s exécuteurs restants=%d" % [orders.traitor, get_nodes_in_group("army_0").filter(func(u: Unit) -> bool: return u.hunt_target == player).size()])
	# --- Assaut ennemi : défense, appel aux armes, mort et nouveau péon
	for i in 5:
		var foe := Unit.create("bruiser", 1); foe.position = lodge.global_position + Vector3(-6 + i * 3, 0, -26); world.add_child(foe)
	player.global_position = lodge.global_position + Vector3(4, 0.05, -14); await frames(150)
	view(lodge.global_position + Vector3(16, 12, -30), lodge.global_position + Vector3(0, 1, -12)); await frames(3); await shot("assault")
	print("assaut ennemi : attaqué=%s ordres=%s milice joueur=%s péons en milice=%d" % [general.under_attack, str(order_texts()), player.is_militia(), general.peons().filter(func(u: Unit) -> bool: return u.is_militia()).size()])
	var level_before := player.progress.level
	player.take_damage(9999.0); await frames(20)
	print("mort : niveau %d -> %d rangs=%s statut='%s'" % [level_before, player.progress.level, str(player.progress.ranks), director.respawn_status()])
	for node in get_nodes_in_group("units_1"): (node as Unit).take_damage(9999.0)
	general.camp.add_gold(60)
	var wait := 0
	while player.is_dead() and wait < 2400: await physics_frame; wait += 1
	print("  nouveau péon après %.1f s : vivant=%s or du camp=%d distance à la loge=%.1f" % [wait / 60.0, not player.is_dead(), general.camp.gold, player.global_position.distance_to(lodge.global_position)])
	# --- Victoire
	player.camera.current = true
	var enemy_lodge := general.enemy_town_hall()
	enemy_lodge.take_damage(99999.0); await frames(30)
	print("loge ennemie détruite : fin=%s victoire=%s Renom=%d %s" % [director.ended, director.victory, director.renown_earned, str(director.renown_breakdown)])
	await shot("victory")
	quit()
func view(from: Vector3, target: Vector3) -> void:
	cam.global_position = from; cam.look_at(target); cam.current = true
