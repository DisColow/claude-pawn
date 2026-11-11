class_name GameDirector
extends Node
## Déroulement de la partie : vagues de squelettes qui sortent de la forêt (aux `Marker3D` du groupe
## `enemy_spawns`), victoire quand la dernière vague est repoussée, défaite si le bastion tombe.

signal wave_started(wave: int, total: int)
signal game_ended(victory: bool)

const ENEMY_SCENES := {
	"skeleton_minion": preload("res://scenes/units/skeleton_minion.tscn"),
	"skeleton_warrior": preload("res://scenes/units/skeleton_warrior.tscn"),
}

## Numéro de la vague en cours (0 = aucune encore).
var wave := 0
## Secondes avant la prochaine vague.
var time_to_next := GameConfig.WAVE_FIRST_DELAY
var ended := false
var victory := false

var _to_spawn: Array[String] = []
var _spawn_timer := 0.0


func _ready() -> void:
	add_to_group("game_director")


func _physics_process(delta: float) -> void:
	if ended:
		return
	var bastion := get_tree().get_first_node_in_group("bastion") as CampBuilding
	if bastion and bastion.state == CampBuilding.State.DESTROYED:
		_end(false)
		return
	if not _to_spawn.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = GameConfig.WAVE_SPAWN_INTERVAL
			_spawn(_to_spawn.pop_back())
	elif wave < GameConfig.WAVE_COUNT:
		time_to_next -= delta
		if time_to_next <= 0.0:
			start_next_wave()
	elif get_tree().get_nodes_in_group("undead_units").is_empty():
		_end(true)


## Lance tout de suite la vague suivante (aussi appelé par la touche de test N).
func start_next_wave() -> void:
	if ended or wave >= GameConfig.WAVE_COUNT:
		return
	wave += 1
	time_to_next = GameConfig.WAVE_INTERVAL
	var size := GameConfig.WAVE_BASE_SIZE + int((wave - 1) * GameConfig.WAVE_GROWTH)
	for index in size:
		# À partir d'une certaine vague, un ennemi sur trois est un guerrier.
		var warrior := wave >= GameConfig.WAVE_WARRIOR_FROM and index % 3 == 0
		_to_spawn.append("skeleton_warrior" if warrior else "skeleton_minion")
	_spawn_timer = 0.0
	wave_started.emit(wave, GameConfig.WAVE_COUNT)


## Ennemis encore à faire apparaître dans la vague en cours.
func get_pending_spawns() -> int:
	return _to_spawn.size()


## Nouvelle partie : stock remis à zéro, niveau rechargé.
func restart() -> void:
	get_tree().paused = false
	CampEconomy.instance.reset()
	get_tree().reload_current_scene()


func _spawn(kind: String) -> void:
	var spawns := get_tree().get_nodes_in_group("enemy_spawns")
	if spawns.is_empty():
		return
	var marker := spawns.pick_random() as Node3D
	var enemy: Unit = ENEMY_SCENES[kind].instantiate()
	enemy.position = marker.global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemy.rotation.y = marker.global_rotation.y
	get_parent().add_child(enemy)


func _end(is_victory: bool) -> void:
	ended = true
	victory = is_victory
	game_ended.emit(is_victory)
	get_tree().paused = true
