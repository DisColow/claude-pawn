extends SceneTree
# Simulation accélérée d'une partie sans rendu : les deux Généraux jouent seuls (le joueur reste immobile). Affiche l'état des camps toutes les 30 s de jeu jusqu'à la chute d'une loge.
# usage : godot --headless --path . -s res://tests/sim_test.gd -- [carte=valley] [difficulté=normal] [durée max en s=1200] [vitesse=10]
func _init() -> void:
	run.call_deferred()
func camp_line(team: int) -> String:
	var general := get_first_node_in_group("general_%d" % team) as General
	var camp := general.camp
	var kinds: Dictionary = {}
	for unit in general.army(): kinds[unit.kind] = int(kinds.get(unit.kind, 0)) + 1
	var built := 0; var total := 0
	for node in get_nodes_in_group("buildings_%d" % team):
		total += 1
		if (node as CampBuilding).is_built(): built += 1
	var lodge := general.town_hall()
	return "camp %d : bois=%d or=%d nourriture=%d/%d palier=%d forge=%d/%d bâtiments=%d/%d péons=%d armée=%d %s %s loge=%d%s%s%s" % [
		team, camp.wood, camp.gold, camp.food_used(), camp.food_cap(), camp.tier, camp.weapon_level, camp.armor_level, built, total,
		general.peons().size(), general.army_strength(), str(kinds), "ASSAUT" if general.army_state == General.Army.ASSAULT else "ralliement",
		int(lodge.health) if lodge else -1, " ATTAQUÉ" if general.under_attack else "",
		" erreurs=" + str(general.mistakes.keys()) if not general.mistakes.is_empty() else "",
		" colonie=" + str(general.expansion_building.state) if general.expansion_building else ""]
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var map_name: String = args[0] if args.size() > 0 else "valley"
	MetaProgress.instance.pending = {"map": map_name, "difficulty": args[1] if args.size() > 1 else "normal", "mission": -1}
	var limit := float(args[2]) if args.size() > 2 else 1200.0
	Engine.time_scale = float(args[3]) if args.size() > 3 else 10.0
	Engine.max_physics_steps_per_frame = 200
	var world: Node = (load(GameConfig.MAPS[map_name]["scene"]) as PackedScene).instantiate()
	get_root().add_child(world)
	var director: GameDirector = world.get_node("GameDirector")
	var next_report := 0.0
	while not director.ended and director.elapsed < limit:
		await physics_frame
		if director.elapsed >= next_report:
			next_report += 30.0
			print("t=%4d s | %s" % [int(director.elapsed), camp_line(0)])
			print("         | %s" % camp_line(1))
	var orders := get_first_node_in_group("worker_orders") as WorkerOrders
	print("fin à %d s : ended=%s victoire=%s | joueur : morts=%d loyauté=%.0f confiance=%.0f | Renom=%d %s" % [
		int(director.elapsed), director.ended, director.victory, director.deaths, orders.loyalty, orders.trust, director.renown_earned, str(director.renown_breakdown)])
	quit()
