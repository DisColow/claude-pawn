class_name WorkerOrders
extends Node
## Relation entre le Général et le péon du joueur (§6.2, §6.5, §6.6, §7) :
##  - ORDRES : quelques ordres actifs (récolter, bâtir, réparer, défendre, attaquer, coloniser),
##    jamais obligatoires. Les accomplir fait monter la loyauté, les ignorer la fait baisser.
##  - LOYAUTÉ (0-100) : « est-ce que j'obéis ? ». À 0, le Général déclare le péon traître et envoie
##    une escouade le tuer ; remonter au-dessus de 0 avant qu'elle n'arrive vaut un sursis.
##  - CONFIANCE (0-100) : « m'écoute-t-il ? ». Elle monte avec les exploits et les bons conseils,
##    et décide si les suggestions de la roue de communication sont acceptées.

signal orders_changed
signal loyalty_changed(value: float)
signal trust_changed(value: float)
## Le Général désigne un endroit (minimap et marqueur dans le monde).
signal ping(position: Vector3)

const ORDER_TEXT := {
	"gather_gold": "Rapporte %d or",
	"gather_wood": "Rapporte %d bois",
	"build": "Construis : %s",
	"colonize": "Colonise la mine : bâtis %s",
	"repair": "Répare : %s",
	"defend": "Défends la loge !",
	"attack": "Marche avec l'armée sur la base ennemie",
}
const BEAM_COLOR := Color(1.0, 0.8, 0.25, 0.45)

var general: General
var loyalty := GameConfig.LOYALTY_START
var trust := GameConfig.TRUST_START
## Ordres actifs : {type, text, primary, target (Vector3 ou INF), node, time, progress, goal}.
var active: Array[Dictionary] = []
var traitor := false
## Secondes avant de pouvoir refaire une suggestion.
var influence_cooldown := 0.0
## Statistiques de fin de partie.
var accepted_suggestions := 0
var good_suggestions := 0
var orders_done := 0

var _squad: Array[Unit] = []
var _new_timer := 6.0
var _militia_time := 0.0
var _beam: MeshInstance3D
var _player: Player


func _ready() -> void:
	add_to_group("worker_orders")
	# Faisceau lumineux à l'endroit que désigne l'ordre principal.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = BEAM_COLOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 40.0
	mesh.material = material
	_beam = MeshInstance3D.new()
	_beam.mesh = mesh
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
		_player.died.connect(_on_player_died)
	influence_cooldown = maxf(influence_cooldown - delta, 0.0)
	_update_orders(delta)
	_update_traitor()
	_update_militia(delta)
	_new_timer -= delta
	if _new_timer <= 0.0 and active.size() < GameConfig.ORDER_MAX_ACTIVE and not traitor:
		_new_timer = GameConfig.ORDER_NEW_INTERVAL
		_issue_order()
	_update_beam()


# --- Ordres ---------------------------------------------------------------------------------------

func _has_order(type: String) -> bool:
	for order in active:
		if order["type"] == type:
			return true
	return false


## Choisit le prochain ordre selon la situation du camp.
func _issue_order() -> void:
	var lodge := general.town_hall()
	if lodge == null:
		return
	var site := general.current_site()
	if general.under_attack and not _has_order("defend"):
		_add("defend", ORDER_TEXT["defend"], true, lodge.global_position, lodge, 1.0)
	elif site != null and not _has_order("build") and not _has_order("colonize"):
		var colony := site == general.expansion_building
		_add("colonize" if colony else "build", ORDER_TEXT["colonize" if colony else "build"] % site.building_name,
			true, site.global_position, site, 1.0)
	elif _damaged_building() != null and not _has_order("repair"):
		var damaged := _damaged_building()
		_add("repair", ORDER_TEXT["repair"] % damaged.building_name, false, damaged.global_position, damaged, damaged.max_health * 0.2)
	elif general.army_state == General.Army.ASSAULT and not _has_order("attack") and general.enemy_town_hall() != null:
		_add("attack", ORDER_TEXT["attack"], false, general.enemy_town_hall().global_position, null, 12.0)
	else:
		# Récolte : la ressource qui manque le plus pour le prochain objectif du Général.
		var goal := general.next_goal()
		var want_gold := general.camp.gold <= general.camp.wood
		if not goal.is_empty():
			want_gold = int(goal["gold"]) - general.camp.gold >= int(goal["wood"]) - general.camp.wood
		var type := "gather_gold" if want_gold else "gather_wood"
		if _has_order(type):
			type = "gather_wood" if want_gold else "gather_gold"
		if _has_order(type):
			return
		var spot := Vector3.INF
		var mine := get_tree().get_first_node_in_group("mine_point_0") as Node3D
		if type == "gather_gold" and mine:
			spot = mine.global_position
		_add(type, ORDER_TEXT[type] % GameConfig.ORDER_GATHER_AMOUNT, not _has_primary(), spot, null, GameConfig.ORDER_GATHER_AMOUNT)


func _has_primary() -> bool:
	for order in active:
		if order["primary"]:
			return true
	return false


func _damaged_building() -> CampBuilding:
	for node in get_tree().get_nodes_in_group("buildings_0"):
		var building := node as CampBuilding
		if building.is_built() and building.health < building.max_health * 0.7:
			return building
	return null


func _add(type: String, text: String, primary: bool, target: Vector3, node: Node, goal: float) -> void:
	active.append({"type": type, "text": text, "primary": primary, "target": target, "node": node,
		"time": GameConfig.ORDER_DURATION, "progress": 0.0, "goal": goal})
	# Les ordres principaux en tête de liste.
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["primary"] and not b["primary"])
	general.message.emit(text + ".")
	if target != Vector3.INF:
		ping.emit(target)
	orders_changed.emit()


func _update_orders(delta: float) -> void:
	var lodge := general.town_hall()
	for order: Dictionary in active.duplicate():
		order["time"] -= delta
		var node := order["node"] as CampBuilding
		match order["type"]:
			"build", "colonize":
				if node == null or not is_instance_valid(node) or node.state == CampBuilding.State.DESTROYED:
					_drop(order)
				elif node.state == CampBuilding.State.BUILT:
					# Compte comme obéi si le joueur a fourni une part réelle du travail.
					if node.player_work >= node.build_time * 0.15:
						_complete(order)
					else:
						_fail(order)
				continue
			"repair":
				if node == null or not is_instance_valid(node) or not node.is_built():
					_drop(order)
					continue
				if node.health >= node.max_health * 0.95:
					if order["progress"] > 0.0:
						_complete(order)
					else:
						_drop(order)
					continue
			"defend":
				if lodge and _player.global_position.distance_to(lodge.global_position) < GameConfig.GENERAL_DEFENSE_RADIUS and not _player.is_dead():
					order["progress"] += delta * 0.2
				if not general.under_attack:
					if order["progress"] >= order["goal"]:
						_complete(order)
					else:
						_fail(order)
					continue
			"attack":
				var target := general.enemy_town_hall()
				if target and _player.global_position.distance_to(target.global_position) < 45.0 and not _player.is_dead():
					order["progress"] += delta
				if general.army_state != General.Army.ASSAULT and order["progress"] < order["goal"]:
					_drop(order)
					continue
		if order["progress"] >= order["goal"] and order["type"] in ["gather_gold", "gather_wood", "attack"]:
			_complete(order)
		elif order["time"] <= 0.0:
			_fail(order)


func _complete(order: Dictionary) -> void:
	active.erase(order)
	orders_done += 1
	add_loyalty(GameConfig.LOYALTY_ORDER_DONE)
	add_trust(GameConfig.TRUST_ORDER_DONE)
	_player.progress.add_xp(GameConfig.XP_ORDER)
	general.message.emit("Bien, péon.")
	orders_changed.emit()


func _fail(order: Dictionary) -> void:
	active.erase(order)
	add_loyalty(-GameConfig.LOYALTY_ORDER_IGNORED)
	add_trust(-GameConfig.TRUST_ORDER_IGNORED)
	general.message.emit("Tu ignores mes ordres, péon. Je m'en souviendrai.")
	orders_changed.emit()


## Retire un ordre devenu sans objet, sans récompense ni reproche.
func _drop(order: Dictionary) -> void:
	active.erase(order)
	orders_changed.emit()


# --- Ce que fait le joueur ----------------------------------------------------------------------------

## Le joueur a déposé `amount` de bois ("wood") ou d'or ("gold").
func notify_deposit(resource: String, amount: int) -> void:
	add_loyalty(GameConfig.LOYALTY_DEPOSIT * amount)
	for order in active:
		if order["type"] == "gather_" + resource:
			order["progress"] += amount
	orders_changed.emit()


func notify_repair(building: CampBuilding, amount: float) -> void:
	for order in active:
		if order["type"] == "repair" and order["node"] == building:
			order["progress"] += amount


## Le joueur a tué un ennemi : un exploit (confiance), et de quoi valider défense ou attaque.
func notify_kill() -> void:
	add_trust(GameConfig.TRUST_KILL)
	for order in active:
		if order["type"] == "defend" or order["type"] == "attack":
			order["progress"] += float(order["goal"])


func add_loyalty(amount: float) -> void:
	loyalty = clampf(loyalty + amount, 0.0, 100.0)
	loyalty_changed.emit(loyalty)


func add_trust(amount: float) -> void:
	trust = clampf(trust + amount, 0.0, 100.0)
	trust_changed.emit(trust)


# --- Traître (§6.5) --------------------------------------------------------------------------------------

func _update_traitor() -> void:
	if not traitor:
		if loyalty <= 0.0 and not _player.is_dead():
			traitor = true
			active.clear()
			orders_changed.emit()
			_squad = general.send_executioners(_player)
			general.message.emit("Tu es relevé de tes fonctions, TRAÎTRE. Tuez-le !")
			# Fenêtre de grâce : un ordre urgent, qui rachète le péon s'il l'accomplit avant l'arrivée de l'escouade.
			_add("gather_wood", "Dernière chance : rapporte %d bois" % 5, true, Vector3.INF, null, 5.0)
		return
	var alive := 0
	for unit in _squad:
		if is_instance_valid(unit) and not unit.is_dead():
			alive += 1
	if loyalty > 0.0:
		_end_traitor("Sursis, péon. Ne me déçois plus.", 0.0)
	elif alive == 0:
		_end_traitor("... Tu as survécu. Reprends le travail.", GameConfig.LOYALTY_REPRIEVE)


func _on_player_died() -> void:
	if traitor:
		_end_traitor("Qu'on entraîne un autre péon. Plus docile.", GameConfig.LOYALTY_REPRIEVE)


func _end_traitor(text: String, loyalty_gain: float) -> void:
	traitor = false
	active.clear()
	orders_changed.emit()
	for unit in _squad:
		if is_instance_valid(unit):
			unit.hunt_target = null
	_squad.clear()
	if loyalty_gain > 0.0:
		add_loyalty(loyalty_gain)
	general.message.emit(text)


# --- Appel aux armes (§10.6) ---------------------------------------------------------------------------------

## Le Général sonne l'appel aux armes : le péon qui rejoint la loge devient milicien.
func call_to_arms() -> void:
	_militia_time = GameConfig.MILITIA_DURATION


func _update_militia(delta: float) -> void:
	if _militia_time <= 0.0:
		return
	_militia_time -= delta
	var lodge := general.town_hall()
	if lodge and _player.global_position.distance_to(lodge.global_position) < GameConfig.GENERAL_DEFENSE_RADIUS:
		_player.set_militia(_militia_time)


# --- Influence (§7) ----------------------------------------------------------------------------------------------

## Suggestion faite par la roue de communication. Renvoie {accepted, text, cooldown}.
func suggest(option: String) -> Dictionary:
	if influence_cooldown > 0.0:
		return {"accepted": false, "cooldown": true, "text": "Laisse-moi réfléchir, péon. (%d s)" % ceili(influence_cooldown)}
	influence_cooldown = GameConfig.INFLUENCE_COOLDOWN
	var good := general.evaluate(option)
	var chance := GameConfig.INFLUENCE_BASE_CHANCE + trust / 100.0 * GameConfig.INFLUENCE_TRUST_WEIGHT \
		+ (GameConfig.INFLUENCE_GOOD_BONUS if good else -GameConfig.INFLUENCE_BAD_MALUS) \
		+ randf_range(-GameConfig.INFLUENCE_RANDOM, GameConfig.INFLUENCE_RANDOM)
	var text := ""
	var accepted := randf() < chance
	if accepted:
		text = general.apply_suggestion(option)
		accepted_suggestions += 1
		_player.progress.add_xp(GameConfig.XP_INFLUENCE)
		if good:
			# Le conseil était bon : confiance et XP en prime.
			good_suggestions += 1
			add_trust(GameConfig.TRUST_GOOD_ADVICE)
			_player.progress.add_xp(GameConfig.XP_INFLUENCE_CORRECT)
			text += " Bon œil, péon."
		else:
			add_trust(-GameConfig.TRUST_BAD_ADVICE)
	else:
		text = "Tu n'es pas en position de me conseiller." if trust < 35.0 else "Non. Pas maintenant."
		if not good:
			add_trust(-GameConfig.TRUST_BAD_ADVICE * 0.5)
	general.message.emit(text)
	return {"accepted": accepted, "cooldown": false, "text": text}


func _update_beam() -> void:
	_beam.visible = false
	for order in active:
		var target: Vector3 = order["target"]
		if order["primary"] and target != Vector3.INF:
			_beam.visible = true
			_beam.global_position = Vector3(target.x, 20.0, target.z)
			return
