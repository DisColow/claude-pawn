class_name GameDirector
extends Node
## Déroulement d'une partie (§10.8) : règle la difficulté du Général ennemi, surveille les deux
## hôtels de ville (détruire celui de l'ennemi = victoire, perdre le sien = défaite), compte les
## exploits du joueur, gère sa réapparition (un nouveau péon entraîné par le Général, §4.5) et
## attribue le Renom à la fin (§9.1). À placer AVANT les Généraux dans la scène de la carte.

signal game_ended(victory: bool)

var ended := false
var victory := false
var elapsed := 0.0
## Statistiques du joueur pour la partie.
var kills := 0
var deaths := 0
## Détail du Renom gagné (rempli à la fin) : libellé → montant.
var renown_breakdown: Dictionary = {}
var renown_earned := 0

var _player: Player
var _waiting_respawn := false
var _respawn_paid := false
var _respawn_timer := 0.0
var _respawn_wait := 0.0


func _ready() -> void:
	add_to_group("game_director")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	var setup: Dictionary = MetaProgress.instance.pending if MetaProgress.instance else {"difficulty": "normal", "mission": -1}
	var enemy := get_node_or_null("../General1") as General
	if enemy:
		enemy.difficulty = setup["difficulty"]
	get_tree().node_added.connect(_on_node_added)
	_start.call_deferred()


func _start() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.managed_respawn = true
		_player.died.connect(_on_player_died)
	var orders := get_tree().get_first_node_in_group("worker_orders") as WorkerOrders
	var mission := mission_index()
	if orders and mission >= 0:
		orders.loyalty = GameConfig.CAMPAIGN[mission]["loyalty"]
		orders.loyalty_changed.emit(orders.loyalty)


func _physics_process(delta: float) -> void:
	if ended or get_tree().paused:
		return
	elapsed += delta
	var ours := get_tree().get_first_node_in_group("town_hall_0") as CampBuilding
	var theirs := get_tree().get_first_node_in_group("town_hall_1") as CampBuilding
	if theirs and theirs.state == CampBuilding.State.DESTROYED:
		_end(true)
	elif ours and ours.state == CampBuilding.State.DESTROYED:
		_end(false)
	elif _waiting_respawn:
		_update_respawn(delta, ours)


## Index de la mission de campagne en cours (-1 en partie libre).
func mission_index() -> int:
	return int(MetaProgress.instance.pending.get("mission", -1)) if MetaProgress.instance else -1


# --- Réapparition (§4.5) ------------------------------------------------------------------------------

func _on_player_died() -> void:
	deaths += 1
	_waiting_respawn = true
	_respawn_paid = false
	_respawn_wait = 0.0


## Le Général entraîne un nouveau péon : une fois l'accrochage fini, au prix d'un péon, après un délai.
func _update_respawn(delta: float, lodge: CampBuilding) -> void:
	var general := get_tree().get_first_node_in_group("general") as General
	if general == null or lodge == null:
		return
	_respawn_wait += delta
	if not _respawn_paid:
		# On attend la fin de l'accrochage (au plus 25 s), puis que le camp ait de quoi payer.
		if general.under_attack and _respawn_wait < 25.0:
			return
		# L'or du nouveau péon est réservé : le Général ne le dépense pas ailleurs entre-temps.
		var cost: Dictionary = GameConfig.UNITS["peon"]
		general.camp.reserved_gold = cost["gold"]
		if not general.camp.spend(cost["wood"], cost["gold"], true):
			return
		general.camp.reserved_gold = 0
		_respawn_paid = true
		_respawn_timer = GameConfig.PLAYER_RESPAWN_TIME
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_waiting_respawn = false
		var spot := lodge.get_front_point(4.0)
		_player.respawn(Transform3D(Basis.looking_at(-lodge.global_basis.z.normalized()), spot))


## Texte d'attente affiché au joueur mort.
func respawn_status() -> String:
	if not _waiting_respawn:
		return ""
	if _respawn_paid:
		return "Le Général entraîne un nouveau péon : %d s" % ceili(_respawn_timer)
	var general := get_tree().get_first_node_in_group("general") as General
	if general and general.under_attack and _respawn_wait < 25.0:
		return "Le Général attend la fin du combat pour entraîner un nouveau péon"
	return "Le Général n'a pas assez d'or pour un nouveau péon (%d or)" % int(GameConfig.UNITS["peon"]["gold"])


# --- Exploits -----------------------------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is Unit:
		(node as Unit).died.connect(_on_unit_died)


func _on_unit_died(unit: Unit, killer: Node) -> void:
	if killer is Player and unit.team != 0:
		kills += 1
		(killer as Player).progress.add_xp(GameConfig.XP_KILL)
		var orders := get_tree().get_first_node_in_group("worker_orders") as WorkerOrders
		if orders:
			orders.notify_kill()


# --- Fin de partie --------------------------------------------------------------------------------------------

func _end(is_victory: bool) -> void:
	ended = true
	victory = is_victory
	var orders := get_tree().get_first_node_in_group("worker_orders") as WorkerOrders
	var gathered := CampEconomy.instance.player_gathered if CampEconomy.instance else 0
	renown_breakdown = {
		("Victoire" if is_victory else "Défaite"): GameConfig.RENOWN_WIN if is_victory else GameConfig.RENOWN_LOSS,
		"Ressources déposées (%d)" % gathered: floori(float(gathered) / GameConfig.RENOWN_PER_RESOURCES),
		"Ennemis tués (%d)" % kills: kills * GameConfig.RENOWN_PER_KILL,
		"Bons conseils (%d)" % (orders.good_suggestions if orders else 0): (orders.good_suggestions if orders else 0) * GameConfig.RENOWN_PER_INFLUENCE,
		"Survie": GameConfig.RENOWN_NO_DEATH if deaths == 0 else 0,
	}
	renown_earned = 0
	for label: String in renown_breakdown:
		renown_earned += int(renown_breakdown[label])
	var meta := MetaProgress.instance
	if meta:
		var mission := mission_index()
		if is_victory and mission >= 0:
			meta.campaign_done = maxi(meta.campaign_done, mission + 1)
		meta.last_result = {"victory": is_victory, "renown": renown_earned}
		meta.add_renown(renown_earned)
	game_ended.emit(is_victory)
	get_tree().paused = true


## Nouvelle partie sur la même carte.
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
