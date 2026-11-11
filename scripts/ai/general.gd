class_name General
extends Node
## Le Général : l'IA qui dirige le camp. Il suit un plan de construction (les enfants du nœud
## `BuildSlots`, dans l'ordre ; le nom de chaque emplacement donne le bâtiment : `tower_1` → `tower`),
## paie les bâtiments avec le stock du camp, fait rebâtir ce qui est détruit, puis lève des grunts
## à la caserne. Le péon reçoit ses ordres par le signal `order_changed` (affiché par le HUD).

signal order_changed(text: String)

const SCENES := {
	"lumber_mill": preload("res://scenes/camp/lumber_mill.tscn"),
	"tower": preload("res://scenes/camp/watch_tower.tscn"),
	"barracks": preload("res://scenes/camp/barracks.tscn"),
}
const GRUNT_SCENE := preload("res://scenes/units/grunt.tscn")

var order := ""

var _slots: Array[Node3D] = []
## Bâtiment posé sur chaque emplacement (null tant qu'il n'est pas commandé).
var _buildings: Array[CampBuilding] = []
var _think_timer := 0.0
var _train_timer := 0.0


func _ready() -> void:
	add_to_group("general")
	for slot in get_node("../BuildSlots").get_children():
		_slots.append(slot as Node3D)
		_buildings.append(null)


func _physics_process(delta: float) -> void:
	_train_timer -= delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = GameConfig.GENERAL_THINK_INTERVAL
		_set_order(_think())


## Bâtiment du plan à l'emplacement `index` (null s'il n'a pas encore été commandé).
func get_building(index: int) -> CampBuilding:
	return _buildings[index]


## Prend une décision et renvoie l'ordre à donner au péon.
func _think() -> String:
	var economy := CampEconomy.instance
	for index in _slots.size():
		var building := _buildings[index]
		if building and building.state == CampBuilding.State.BUILT:
			continue
		var kind := String(_slots[index].name).rsplit("_", true, 1)[0]
		var config: Dictionary = GameConfig.BUILDINGS[kind]
		if building and building.state == CampBuilding.State.UNDER_CONSTRUCTION:
			return "Construis : %s — maintiens E sur le chantier" % config["name"]
		var wood: int = config["wood"]
		var gold: int = config["gold"]
		if economy.spend(wood, gold):
			if building:
				building.begin_construction()
			else:
				_buildings[index] = _place(kind, _slots[index])
			return "Construis : %s — maintiens E sur le chantier" % config["name"]
		return "Rapporte %s pour bâtir : %s" % [_missing(wood, gold), config["name"]]
	return _think_army()


## Tout le plan est debout : lever des grunts tant qu'il y a de l'or et de la place.
func _think_army() -> String:
	var grunts := get_tree().get_nodes_in_group("orc_units").size()
	if grunts >= GameConfig.GRUNT_CAP:
		return "Le camp est prêt. Tiens bon, péon !"
	var barracks := _first_built("barracks")
	if barracks and _train_timer <= 0.0 and CampEconomy.instance.spend(GameConfig.GRUNT_COST_WOOD, GameConfig.GRUNT_COST_GOLD):
		_train_timer = GameConfig.GRUNT_TRAIN_TIME
		_spawn_grunt(barracks)
		grunts += 1
	return "Rapporte de l'or pour lever des grunts (%d or chacun) — %d / %d" % [GameConfig.GRUNT_COST_GOLD, grunts, GameConfig.GRUNT_CAP]


func _missing(wood: int, gold: int) -> String:
	var parts: Array[String] = []
	if wood > CampEconomy.instance.wood:
		parts.append("%d bois" % (wood - CampEconomy.instance.wood))
	if gold > CampEconomy.instance.gold:
		parts.append("%d or" % (gold - CampEconomy.instance.gold))
	return " et ".join(parts)


func _place(kind: String, slot: Node3D) -> CampBuilding:
	var building: CampBuilding = SCENES[kind].instantiate()
	building.starts_built = false
	building.transform = slot.global_transform
	get_parent().add_child(building)
	return building


func _first_built(kind: String) -> CampBuilding:
	for building in _buildings:
		if building and building.kind == kind and building.state == CampBuilding.State.BUILT:
			return building
	return null


## Le grunt sort devant la caserne et y monte la garde.
func _spawn_grunt(barracks: CampBuilding) -> void:
	var grunt: Unit = GRUNT_SCENE.instantiate()
	var front := barracks.global_basis.z * (barracks.get_target_radius() + 2.0)
	grunt.position = barracks.global_position + front + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-1.0, 1.0))
	get_parent().add_child(grunt)


func _set_order(text: String) -> void:
	if text != order:
		order = text
		order_changed.emit(text)
