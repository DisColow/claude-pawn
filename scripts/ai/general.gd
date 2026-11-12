class_name General
extends Node
## Le Général : l'IA qui joue toute la partie stratégique de son camp (§6 et §10 du cahier des charges).
## Il gère l'économie (péons), suit un plan de construction, améliore l'hôtel de ville, entraîne
## l'armée, recrute et soigne un héros, colonise une mine et lance des assauts sur la base ennemie.
## Il n'est ni omniscient ni optimal : il commet régulièrement des ERREURS (`mistakes`) tirées du
## catalogue du §6.3, que le joueur peut repérer et corriger par ses suggestions (`evaluate` / `apply_suggestion`).
## Il y a un Général par camp ; celui du joueur (camp 0) porte en plus les ordres au péon (`WorkerOrders`).
##
## La carte lui fournit : un hôtel de ville (groupe `town_hall_<camp>`), des emplacements de
## construction (enfants de `Slots<camp>`), des points de récolte (groupes `mine_point_<camp>` et
## `wood_point_<camp>`), un point de ralliement (`rally_<camp>`) et des mines à coloniser (`expansion_points`).

## Phrase adressée au péon (camp du joueur seulement).
signal message(text: String)

enum Army { RALLY, ASSAULT }

const BUILDING_SCENE := preload("res://scenes/camp/building.tscn")
## Catalogue d'erreurs (§6.3).
const MISTAKES := ["forget_gold", "forget_wood", "no_colonize", "idle_units", "no_warriors", "no_food", "no_hero", "no_heal"]

@export var team := 0
## Clé de `GameConfig.DIFFICULTIES`.
@export var difficulty := "ally"

var camp: CampEconomy
var settings: Dictionary
## Erreurs en cours : nom → secondes restantes.
var mistakes: Dictionary = {}
var army_state := Army.RALLY
var under_attack := false
## Part des péons envoyés à l'or (le reste coupe du bois).
var gold_focus := 0.5
## Mine colonisée : son entrepôt (null tant qu'il n'est pas commandé) et son point de minage.
var expansion_building: CampBuilding
var orders: WorkerOrders

var _plan: Array[Dictionary] = []
var _spare_slots: Array[Node3D] = []
var _think_timer := 0.0
var _elapsed := 0.0
var _mistake_timer := GameConfig.GENERAL_MISTAKE_INTERVAL * 0.5
## Entraînement en cours : {kind, time, building}.
var _training: Dictionary = {}
var _train_boost := 0.0
## Recherche de forge en cours : {what, time}.
var _research: Dictionary = {}
var _assault_strength := 0
var _hold_time := 0.0
var _militia_cooldown := 0.0
var _hero_resting := false
var _expansion_marker: Node3D
var _force_expand := false


func _ready() -> void:
	add_to_group("generals")
	add_to_group("general_%d" % team)
	if team == 0:
		add_to_group("general")
	settings = GameConfig.DIFFICULTIES[difficulty]
	camp = CampEconomy.of(team)
	if camp == null:
		camp = CampEconomy.new()
		camp.team = team
		camp.name = "Camp%d" % team
		add_child(camp)
	camp.reset()
	var slots: Array[Node] = get_node("../Slots%d" % team).get_children() if has_node("../Slots%d" % team) else []
	var next_slot := 0
	for kind: String in GameConfig.GENERAL_BUILD_ORDER:
		var entry := {"kind": kind, "slot": null, "building": null}
		if kind != "tier_up" and next_slot < slots.size():
			entry["slot"] = slots[next_slot]
			next_slot += 1
		if kind == "tier_up" or entry["slot"] != null:
			_plan.append(entry)
	for index in range(next_slot, slots.size()):
		_spare_slots.append(slots[index] as Node3D)
	if team == 0:
		orders = WorkerOrders.new()
		orders.name = "WorkerOrders"
		orders.general = self
		add_child(orders)
	_spawn_start_peons.call_deferred()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	var step := GameConfig.GENERAL_THINK_INTERVAL
	_think_timer = step
	var lodge := town_hall()
	if lodge == null or lodge.state == CampBuilding.State.DESTROYED:
		return
	_update_mistakes(step)
	under_attack = _threat_position(lodge) != Vector3.INF
	_manage_construction()
	_manage_peons(lodge)
	_manage_forge(step)
	_manage_training(step, lodge)
	_manage_hero(step)
	_manage_expansion()
	_manage_army(step, lodge)


# --- Accès utiles (ordres au joueur, HUD, tests) -------------------------------------------------

func town_hall() -> CampBuilding:
	return get_tree().get_first_node_in_group("town_hall_%d" % team) as CampBuilding


func enemy_town_hall() -> CampBuilding:
	return get_tree().get_first_node_in_group("town_hall_%d" % (1 - team)) as CampBuilding


## Chantier en cours du camp (null s'il n'y en a pas).
func current_site() -> CampBuilding:
	for node in get_tree().get_nodes_in_group("buildings_%d" % team):
		var building := node as CampBuilding
		if building.state == CampBuilding.State.UNDER_CONSTRUCTION:
			return building
	return null


func built(kind: String) -> CampBuilding:
	for node in get_tree().get_nodes_in_group("buildings_%d" % team):
		var building := node as CampBuilding
		if building.kind == kind and building.is_built():
			return building
	return null


func army() -> Array[Unit]:
	var units: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("army_%d" % team):
		var unit := node as Unit
		if unit.hunt_target == null:
			units.append(unit)
	return units


## Force de l'armée, en nourriture.
func army_strength() -> int:
	var total := 0
	for unit in army():
		total += unit.food()
	return total


func hero() -> Unit:
	return get_tree().get_first_node_in_group("heroes_%d" % team) as Unit


func peons() -> Array[Unit]:
	var units: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("workers_%d" % team):
		units.append(node as Unit)
	return units


## Prochain bâtiment que le Général veut (pour l'affichage et les suggestions) : {kind, wood, gold} ou {}.
func next_goal() -> Dictionary:
	var tier_ups := 0
	for entry in _plan:
		var kind: String = entry["kind"]
		if kind == "tier_up":
			tier_ups += 1
			if camp.tier > tier_ups:
				continue
			var next: Dictionary = GameConfig.TOWN_HALL_TIERS[camp.tier]
			return {"kind": "tier_up", "name": next["name"], "wood": next["wood"], "gold": next["gold"]}
		var building := entry["building"] as CampBuilding
		if building and building.state != CampBuilding.State.DESTROYED:
			continue
		var config: Dictionary = GameConfig.BUILDINGS[kind]
		return {"kind": kind, "name": config["name"], "wood": config["wood"], "gold": config["gold"]}
	return {}


# --- Erreurs volontaires (§6.3) ---------------------------------------------------------------------

func _update_mistakes(step: float) -> void:
	for mistake: String in mistakes.keys():
		mistakes[mistake] -= step
		if mistakes[mistake] <= 0.0:
			mistakes.erase(mistake)
	_mistake_timer -= step
	if _mistake_timer <= 0.0:
		_mistake_timer = GameConfig.GENERAL_MISTAKE_INTERVAL
		if randf() < float(settings["error_rate"]):
			make_mistake(MISTAKES.pick_random())


## Fait commettre une erreur donnée au Général (aussi utilisé par les tests).
func make_mistake(mistake: String) -> void:
	mistakes[mistake] = GameConfig.GENERAL_MISTAKE_DURATION


func _has(mistake: String) -> bool:
	return mistakes.has(mistake)


# --- Construction --------------------------------------------------------------------------------------

func _manage_construction() -> void:
	if current_site() != null:
		return
	# Urgence nourriture : un terrier de plus si le plafond bloque la production.
	if camp.food_used() + 3 > camp.food_cap() and camp.food_cap() < GameConfig.FOOD_CAP and not _has("no_food") and not _spare_slots.is_empty():
		var burrow: Dictionary = GameConfig.BUILDINGS["burrow"]
		if camp.spend(burrow["wood"], burrow["gold"]):
			_place("burrow", _spare_slots.pop_front())
		return
	var tier_ups := 0
	for entry in _plan:
		var kind: String = entry["kind"]
		if kind == "tier_up":
			tier_ups += 1
			if camp.tier > tier_ups:
				continue
			var lodge := town_hall()
			if lodge.upgrade_time_left > 0.0:
				continue
			var next: Dictionary = GameConfig.TOWN_HALL_TIERS[camp.tier]
			if camp.spend(next["wood"], next["gold"]):
				lodge.start_upgrade()
				_say("J'agrandis notre loge : bientôt %s." % next["name"])
			return
		var building := entry["building"] as CampBuilding
		if building and building.state == CampBuilding.State.BUILT:
			continue
		var config: Dictionary = GameConfig.BUILDINGS[kind]
		if int(config["tier"]) > camp.tier:
			return
		if kind == "burrow" and _has("no_food"):
			continue
		if not camp.spend(config["wood"], config["gold"]):
			return
		if building:
			building.begin_construction()
		else:
			entry["building"] = _place(kind, entry["slot"])
		_say("Chantier : %s. Au travail !" % config["name"])
		return


func _place(kind: String, slot: Node3D) -> CampBuilding:
	var building: CampBuilding = BUILDING_SCENE.instantiate()
	building.kind = kind
	building.team = team
	building.starts_built = false
	building.transform = slot.global_transform
	get_parent().add_child(building)
	return building


# --- Péons ----------------------------------------------------------------------------------------------

func _spawn_start_peons() -> void:
	var lodge := town_hall()
	if lodge == null:
		return
	for index in GameConfig.START_PEONS:
		_spawn("peon", lodge)


func _manage_peons(lodge: CampBuilding) -> void:
	var workers := peons()
	if workers.is_empty():
		return
	# L'or ou le bois d'abord, selon ce qui manque pour le prochain objectif.
	var goal := next_goal()
	if not goal.is_empty():
		var need_gold := maxi(int(goal["gold"]) - camp.gold, 0)
		var need_wood := maxi(int(goal["wood"]) - camp.wood, 0)
		gold_focus = 0.5 if need_gold == need_wood else (0.7 if need_gold > need_wood else 0.3)
	var gold_share := gold_focus
	if _has("forget_gold"):
		gold_share = 0.0
	elif _has("forget_wood"):
		gold_share = 1.0
	var site := current_site()
	var builders := 0
	var gold_count := roundi(workers.size() * gold_share)
	var mine_points := get_tree().get_nodes_in_group("mine_point_%d" % team)
	var wood_points := get_tree().get_nodes_in_group("wood_point_%d" % team)
	var colony := expansion_building if expansion_building and is_instance_valid(expansion_building) and expansion_building.is_built() else null
	for index in workers.size():
		var worker := workers[index]
		worker.income_scale = settings["income"]
		worker.command_point = lodge.get_front_point(5.0)
		if site and builders < GameConfig.GENERAL_BUILDERS:
			builders += 1
			worker.assign("build", site.global_position, site)
			continue
		if index < gold_count and not mine_points.is_empty():
			# Deux mineurs partent à la mine colonisée dès qu'elle a son entrepôt.
			if colony and index < 2:
				worker.dropoff_point = colony.get_front_point()
				worker.assign("gold", _expansion_marker.get_meta("mine_point"))
			else:
				worker.dropoff_point = lodge.get_front_point()
				worker.assign("gold", (mine_points[0] as Node3D).global_position)
		elif not wood_points.is_empty():
			worker.dropoff_point = lodge.get_front_point()
			worker.assign("wood", (wood_points[index % wood_points.size()] as Node3D).global_position)


# --- Production -------------------------------------------------------------------------------------------

func _manage_training(step: float, lodge: CampBuilding) -> void:
	_train_boost = maxf(_train_boost - step, 0.0)
	if not _training.is_empty():
		_training["time"] -= step * float(settings["train"]) * (1.5 if _train_boost > 0.0 else 1.0)
		if _training["time"] <= 0.0:
			var source := _training["building"] as CampBuilding
			if is_instance_valid(source) and source.is_built():
				_spawn(_training["kind"], source)
			_training = {}
		return
	var wanted_peons := GameConfig.GENERAL_PEON_TARGET + (2 if expansion_building else 0)
	if peons().size() < GameConfig.GENERAL_MIN_PEONS:
		# Plus (ou presque plus) de péons : la loge en forme sans attendre l'or, sinon le camp est condamné.
		_training = {"kind": "peon", "time": float(GameConfig.UNITS["peon"]["train_time"]), "building": lodge}
		return
	if peons().size() < wanted_peons:
		_train("peon", lodge)
		return
	if _has("no_warriors"):
		return
	# Une fois une garde minimale levée, l'or du prochain bâtiment du plan est mis de côté.
	var goal := next_goal()
	if not goal.is_empty() and army_strength() >= GameConfig.GENERAL_MIN_GUARD and camp.gold < int(goal["gold"]) + 40:
		return
	# Unité la plus en retard sur la composition visée, parmi celles qu'on sait produire.
	var counts: Dictionary = {}
	for unit in army():
		counts[unit.kind] = int(counts.get(unit.kind, 0)) + 1
	var best_kind := ""
	var best_score := INF
	var best_building: CampBuilding = null
	for node in get_tree().get_nodes_in_group("buildings_%d" % team):
		var building := node as CampBuilding
		if not building.is_built() or building.kind == "war_lodge":
			continue
		for kind: String in GameConfig.BUILDINGS[building.kind].get("trains", []):
			# Seulement ce qu'on peut payer et nourrir tout de suite : pas d'attente sur une unité chère.
			var unit: Dictionary = GameConfig.UNITS[kind]
			if not camp.can_afford(unit["wood"], unit["gold"]) or camp.food_used() + int(unit["food"]) > camp.food_cap():
				continue
			var score := float(counts.get(kind, 0)) / float(GameConfig.GENERAL_ARMY_WEIGHTS[kind])
			if score < best_score:
				best_score = score
				best_kind = kind
				best_building = building
	if best_kind != "":
		_train(best_kind, best_building)


func _train(kind: String, building: CampBuilding) -> bool:
	var config: Dictionary = GameConfig.UNITS[kind]
	if camp.food_used() + int(config["food"]) > camp.food_cap():
		return false
	if not camp.spend(config["wood"], config["gold"]):
		return false
	_training = {"kind": kind, "time": float(config["train_time"]), "building": building}
	return true


func _spawn(kind: String, building: CampBuilding) -> Unit:
	var unit := Unit.create(kind, team)
	unit.position = building.get_front_point(3.0) + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-1.5, 1.5))
	get_parent().add_child(unit)
	unit.command_point = rally_point()
	return unit


func _manage_forge(step: float) -> void:
	if built("forge") == null:
		return
	if not _research.is_empty():
		_research["time"] -= step
		if _research["time"] <= 0.0:
			if _research["what"] == "weapons":
				camp.weapon_level += 1
			else:
				camp.armor_level += 1
			_say("La forge a fini : %s améliorées." % ("armes" if _research["what"] == "weapons" else "armures"))
			_research = {}
		return
	var what := "weapons" if camp.weapon_level <= camp.armor_level else "armor"
	var level := camp.weapon_level if what == "weapons" else camp.armor_level
	var cost: Dictionary = GameConfig.FORGE_UPGRADE_COST
	# La forge passe après les bâtiments : on garde de quoi payer le prochain.
	if level < GameConfig.FORGE_MAX_LEVEL and camp.gold >= int(cost["gold"]) + 60 and camp.wood >= int(cost["wood"]) + 40:
		camp.spend(cost["wood"], cost["gold"])
		_research = {"what": what, "time": GameConfig.FORGE_UPGRADE_TIME}


# --- Héros (§10.5) --------------------------------------------------------------------------------------------

func _manage_hero(step: float) -> void:
	var shrine := built("ancestor_shrine")
	if shrine == null:
		return
	var champion := hero()
	if champion == null:
		if not _has("no_hero") and _training.is_empty():
			_train(GameConfig.HEROES.pick_random(), shrine)
		return
	var ratio := champion.health / champion.max_health
	if not _hero_resting and ratio < GameConfig.HERO_HEAL_THRESHOLD and not _has("no_heal"):
		_hero_resting = true
	if _hero_resting:
		champion.set_command(Unit.Mode.GUARD, shrine.get_front_point())
		if champion.global_position.distance_to(shrine.global_position) < shrine.get_target_radius() + 9.0:
			champion.heal(GameConfig.HERO_HEAL_RATE * step)
		if ratio > 0.9:
			_hero_resting = false


# --- Colonisation d'une mine (§10.7) ------------------------------------------------------------------------------

func _manage_expansion() -> void:
	if expansion_building != null and is_instance_valid(expansion_building):
		if expansion_building.state == CampBuilding.State.DESTROYED and camp.spend(GameConfig.BUILDINGS["stockpile"]["wood"], 0):
			expansion_building.begin_construction()
		return
	if _has("no_colonize") or (_elapsed < GameConfig.GENERAL_EXPAND_TIME and not _force_expand) or current_site() != null:
		return
	var marker := free_expansion()
	if marker == null:
		return
	var config: Dictionary = GameConfig.BUILDINGS["stockpile"]
	if camp.spend(config["wood"], config["gold"]):
		marker.set_meta("claimed_by", team)
		_expansion_marker = marker
		expansion_building = _place("stockpile", marker)
		_force_expand = false
		_say("Je colonise une nouvelle mine. Il faut y bâtir un entrepôt.")


## Mine à coloniser libre la plus proche de notre base (null s'il n'y en a plus).
func free_expansion() -> Node3D:
	var lodge := town_hall()
	var best: Node3D = null
	for node in get_tree().get_nodes_in_group("expansion_points"):
		var marker := node as Node3D
		if marker.has_meta("claimed_by"):
			continue
		if best == null or marker.global_position.distance_to(lodge.global_position) < best.global_position.distance_to(lodge.global_position):
			best = marker
	return best


# --- Armée ----------------------------------------------------------------------------------------------------------

func rally_point() -> Vector3:
	var marker := get_tree().get_first_node_in_group("rally_%d" % team) as Node3D
	if marker:
		return marker.global_position
	var lodge := town_hall()
	return lodge.get_front_point(9.0) if lodge else Vector3.ZERO


## Position de l'ennemi le plus proche de notre hôtel de ville, s'il est dans le périmètre (sinon INF).
func _threat_position(lodge: CampBuilding) -> Vector3:
	var best := Vector3.INF
	var best_distance := GameConfig.GENERAL_DEFENSE_RADIUS
	for node in get_tree().get_nodes_in_group("units_%d" % (1 - team)):
		var distance := (node as Node3D).global_position.distance_to(lodge.global_position)
		if distance < best_distance:
			best_distance = distance
			best = (node as Node3D).global_position
	return best


func _manage_army(step: float, lodge: CampBuilding) -> void:
	_militia_cooldown = maxf(_militia_cooldown - step, 0.0)
	_hold_time = maxf(_hold_time - step, 0.0)
	var strength := army_strength()
	var target := enemy_town_hall()
	var threat := _threat_position(lodge)
	if threat != Vector3.INF:
		# Base attaquée : tout le monde rentre, et les péons prennent les armes si l'armée ne suffit pas.
		army_state = Army.RALLY
		var attackers := 0
		for node in get_tree().get_nodes_in_group("units_%d" % (1 - team)):
			if (node as Node3D).global_position.distance_to(lodge.global_position) < GameConfig.GENERAL_DEFENSE_RADIUS:
				attackers += (node as Unit).food()
		if attackers > strength and _militia_cooldown <= 0.0:
			_militia_cooldown = GameConfig.MILITIA_DURATION * 3.0
			for worker in peons():
				worker.call_to_arms()
			if orders:
				orders.call_to_arms()
			_say("AUX ARMES ! Tous les péons défendent la loge !")
	elif army_state == Army.ASSAULT:
		if target == null or target.state == CampBuilding.State.DESTROYED or strength <= int(_assault_strength * GameConfig.GENERAL_RETREAT_RATIO):
			army_state = Army.RALLY
			_say("Repli ! L'armée rentre au camp.")
	elif _hold_time <= 0.0 and strength >= int(settings["attack_size"]) and not _has("idle_units") and target != null:
		start_assault()
	for unit in army():
		if unit == hero() and _hero_resting:
			continue
		if threat != Vector3.INF:
			unit.set_command(Unit.Mode.GUARD, threat)
		elif army_state == Army.ASSAULT and target != null:
			unit.set_command(Unit.Mode.ASSAULT, target.global_position)
		else:
			unit.set_command(Unit.Mode.GUARD, rally_point())


func start_assault() -> void:
	army_state = Army.ASSAULT
	_assault_strength = army_strength()
	_say("À l'assaut ! L'armée marche sur la base ennemie.")


# --- Traître (§6.5) -----------------------------------------------------------------------------------------------------

## Envoie une escouade exécuter le péon déloyal. Renvoie les exécuteurs.
func send_executioners(victim: Node3D) -> Array[Unit]:
	var squad: Array[Unit] = []
	var source := built("barracks")
	if source == null:
		source = town_hall()
	for index in GameConfig.TRAITOR_SQUAD:
		var unit := _spawn("bruiser", source)
		unit.hunt_target = victim
		squad.append(unit)
	return squad


# --- Influence du joueur (§7) ----------------------------------------------------------------------------------------------

## La suggestion est-elle une bonne idée, là, maintenant ?
func evaluate(option: String) -> bool:
	var strength := army_strength()
	match option:
		"attack":
			return army_state != Army.ASSAULT and not under_attack and strength >= int(float(settings["attack_size"]) * 0.7)
		"defend":
			return under_attack or (army_state == Army.ASSAULT and strength < int(_assault_strength * 0.6))
		"retreat":
			return army_state == Army.ASSAULT and strength < int(_assault_strength * 0.6)
		"colonize":
			return expansion_building == null and free_expansion() != null and camp.can_afford(GameConfig.BUILDINGS["stockpile"]["wood"], 0)
		"build":
			if current_site() != null:
				return false
			if _has("no_food") and camp.food_used() + 3 > camp.food_cap():
				return true
			var goal := next_goal()
			return not goal.is_empty() and camp.can_afford(goal["wood"], goal["gold"])
		"train":
			return _has("no_warriors") or (strength < int(settings["attack_size"]) and built("barracks") != null and camp.gold >= 35)
		"hero":
			var champion := hero()
			if built("ancestor_shrine") == null:
				return false
			return (champion == null and _has("no_hero")) or (champion != null and champion.health < champion.max_health * 0.5)
		"economy":
			return _has("forget_gold") or _has("forget_wood") or camp.gold * 4 < camp.wood or camp.wood * 4 < camp.gold
	return false


## Applique une suggestion acceptée et renvoie la réponse du Général.
func apply_suggestion(option: String) -> String:
	match option:
		"attack":
			mistakes.erase("idle_units")
			_hold_time = 0.0
			if enemy_town_hall() != null:
				start_assault()
			return "Soit. On attaque."
		"defend":
			army_state = Army.RALLY
			_hold_time = 45.0
			return "L'armée tient la base."
		"retreat":
			army_state = Army.RALLY
			_hold_time = 30.0
			return "Repli. Tu as peut-être raison."
		"colonize":
			mistakes.erase("no_colonize")
			_force_expand = true
			return "Une nouvelle mine... Bien vu, péon."
		"build":
			mistakes.erase("no_food")
			return "On bâtit. Prépare ton marteau."
		"train":
			mistakes.erase("no_warriors")
			_train_boost = 60.0
			return "Plus de guerriers. Entendu."
		"hero":
			mistakes.erase("no_hero")
			mistakes.erase("no_heal")
			return "Le héros... oui. Je m'en occupe."
		"economy":
			mistakes.erase("forget_gold")
			mistakes.erase("forget_wood")
			gold_focus = 0.7 if camp.gold < camp.wood else 0.3
			return "Je réorganise les péons."
	return ""


func _say(text: String) -> void:
	if team == 0:
		message.emit(text)
