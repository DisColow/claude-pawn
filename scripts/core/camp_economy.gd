class_name CampEconomy
extends Node
## État d'un camp : stock de bois et d'or, palier de l'hôtel de ville, améliorations de la forge.
## Il y en a un par camp. Celui du joueur (camp 0) est l'autoload `Camp`, accessible par
## `CampEconomy.instance` ; celui de l'ennemi est créé par son Général. `CampEconomy.of(camp)` les retrouve.
## (On passe par ces accès statiques plutôt que par le nom de l'autoload, qui n'existe pas encore
## quand Godot compile un script lancé avec `-s`.)

signal wood_changed(total: int)
signal gold_changed(total: int)

static var instance: CampEconomy
static var camps: Dictionary = {}

## Camp : 0 = joueur, 1 = ennemi.
var team := 0
var wood := 0
var gold := 0
## Palier de l'hôtel de ville (1 à 3).
var tier := 1
## Niveaux d'armes et d'armures achetés à la forge.
var weapon_level := 0
var armor_level := 0
## Ressources déposées depuis le début de la partie (statistique de fin).
var gathered := 0
## Part déposée par le joueur lui-même (compte pour son Renom).
var player_gathered := 0
## Or mis de côté pour entraîner le nouveau péon du joueur : le Général n'y touche pas.
var reserved_gold := 0


func _enter_tree() -> void:
	camps[team] = self
	if team == 0:
		instance = self


func _exit_tree() -> void:
	if team != 0 and camps.get(team) == self:
		camps.erase(team)


static func of(camp: int) -> CampEconomy:
	return camps.get(camp) as CampEconomy


func add_wood(amount: int) -> void:
	if amount <= 0:
		return
	wood += amount
	gathered += amount
	wood_changed.emit(wood)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gathered += amount
	gold_changed.emit(gold)


func can_afford(wood_cost: int, gold_cost: int, use_reserve: bool = false) -> bool:
	return wood >= wood_cost and gold - (0 if use_reserve else reserved_gold) >= gold_cost


## Dépense les ressources si le stock suffit. Renvoie false (et ne dépense rien) sinon.
## `use_reserve` : puiser dans l'or réservé (réapparition du joueur).
func spend(wood_cost: int, gold_cost: int, use_reserve: bool = false) -> bool:
	if not can_afford(wood_cost, gold_cost, use_reserve):
		return false
	wood -= wood_cost
	gold -= gold_cost
	wood_changed.emit(wood)
	gold_changed.emit(gold)
	return true


## Nourriture fournie par les bâtiments debout du camp (plafonnée).
func food_cap() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("buildings_%d" % team):
		var building := node as CampBuilding
		if building.is_built():
			total += building.food()
	return mini(total, GameConfig.FOOD_CAP)


## Nourriture consommée par les unités vivantes du camp.
func food_used() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("units_%d" % team):
		total += (node as Unit).food()
	return total


## Nouvelle partie : stock de départ, palier 1, forge vierge.
func reset() -> void:
	wood = GameConfig.START_WOOD
	gold = GameConfig.START_GOLD
	tier = 1
	weapon_level = 0
	armor_level = 0
	gathered = 0
	player_gathered = 0
	reserved_gold = 0
	wood_changed.emit(wood)
	gold_changed.emit(gold)
