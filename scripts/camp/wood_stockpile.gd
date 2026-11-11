class_name WoodStockpile
extends StaticBody3D
## Pile de bois du camp (§3.3), dans la cour de la scierie : quand le joueur est dans la zone, E
## décharge le bois porté. La scierie la désactive (`enabled`) tant qu'elle n'est pas debout.
## Chaque rondin vole de l'épaule jusqu'à la pile, qui grandit (tas en pyramide, l'un après l'autre) ;
## le stock global (`CampEconomy.instance.wood`) est crédité dès que le rondin quitte l'épaule.

const LOG_MODEL := preload("res://assets/models/props/wood_log.glb")
const LOG_RADIUS := 0.125
## Écart entre deux tas, dans l'axe des rondins (qui font 1 m de long).
const STACK_STEP := 1.08
## Écart entre deux rondins d'une rangée, et hauteur d'une rangée (empilement en quinconce).
const ROW_STEP := 0.255
const ROW_HEIGHT := 0.217

@export var drop_sounds: Array[AudioStream] = []
## true = on peut aussi y déposer l'or (cour du bastion).
@export var accepts_gold := false

## false = on ne peut plus rien y déposer (scierie en chantier ou détruite).
var enabled := true:
	set(value):
		enabled = value
		for player in _players_inside:
			if enabled:
				player.carrier.enter_stockpile(self)
			else:
				player.carrier.exit_stockpile(self)

## Rondins arrivés sur la pile (ceux en vol ne sont pas encore comptés ici).
var landed := 0

## Rondins en vol vers la pile (leur place est déjà réservée).
var _in_flight := 0
## Joueurs présents dans la zone (même quand le dépôt est désactivé).
var _players_inside: Array[Player] = []

var _multimesh: MultiMesh
var _stack_shapes: Array[CollisionShape3D] = []

@onready var _logs: MultiMeshInstance3D = $Logs
@onready var _zone: Area3D = $Zone
@onready var _audio: AudioStreamPlayer3D = $DropAudio


func _ready() -> void:
	add_to_group("wood_stockpiles")
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = _find_log_mesh()
	_multimesh.instance_count = max_visible_logs()
	_multimesh.visible_instance_count = 0
	_logs.multimesh = _multimesh
	for stack in GameConfig.STOCKPILE_STACKS:
		var collision := CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		collision.disabled = true
		add_child(collision)
		_stack_shapes.append(collision)
	_zone.body_entered.connect(_on_zone_body_entered)
	_zone.body_exited.connect(_on_zone_body_exited)


## Nombre de rondins qu'un tas peut contenir (pyramide : base, base - 1, … 1).
static func logs_per_stack() -> int:
	@warning_ignore("integer_division")
	return GameConfig.STOCKPILE_STACK_BASE * (GameConfig.STOCKPILE_STACK_BASE + 1) / 2


## Au-delà, le stock continue de monter mais la pile ne grandit plus à l'écran.
static func max_visible_logs() -> int:
	return logs_per_stack() * GameConfig.STOCKPILE_STACKS


## Reçoit un rondin porté : crédite le stock du camp, puis le rondin vole de `from` (transform
## global de la bûche sur l'épaule) jusqu'à sa place sur la pile.
func receive_log(from: Transform3D) -> void:
	CampEconomy.instance.add_wood(1)
	var flying: Node3D = LOG_MODEL.instantiate()
	add_child(flying)
	flying.global_transform = from
	var start := flying.transform
	var end := _slot_transform(mini(landed + _in_flight, max_visible_logs() - 1))
	_in_flight += 1
	var tween := create_tween()
	tween.tween_method(_move_flying.bind(flying, start, end), 0.0, 1.0, GameConfig.STOCKPILE_FLY_TIME)
	tween.tween_callback(_land.bind(flying))


## Vol en cloche de l'épaule à la pile ; le rondin reprend sa taille réelle en route.
func _move_flying(t: float, flying: Node3D, start: Transform3D, end: Transform3D) -> void:
	var eased := smoothstep(0.0, 1.0, t)
	var moved := start.interpolate_with(end, eased)
	moved.origin.y += sin(t * PI) * GameConfig.STOCKPILE_FLY_ARC
	flying.transform = moved


func _land(flying: Node3D) -> void:
	flying.queue_free()
	_in_flight -= 1
	if landed < max_visible_logs():
		_multimesh.set_instance_transform(landed, _slot_transform(landed))
		_multimesh.visible_instance_count = landed + 1
	landed += 1
	_update_collision()
	if not drop_sounds.is_empty():
		_audio.stream = drop_sounds.pick_random()
		_audio.pitch_scale = randf_range(0.95, 1.3)
		_audio.play()


## Place du `index`-ième rondin (repère du dépôt) : on remplit un tas en pyramide, puis le suivant.
func _slot_transform(index: int) -> Transform3D:
	@warning_ignore("integer_division")
	var stack := index / logs_per_stack()
	var in_stack := index % logs_per_stack()
	var row := 0
	var row_size := GameConfig.STOCKPILE_STACK_BASE
	while in_stack >= row_size:
		in_stack -= row_size
		row += 1
		row_size -= 1
	var x := (float(stack) - (GameConfig.STOCKPILE_STACKS - 1) * 0.5) * STACK_STEP
	var z := (float(in_stack) - (row_size - 1) * 0.5) * ROW_STEP
	var y := LOG_RADIUS + row * ROW_HEIGHT
	# Un peu de désordre, stable pour chaque emplacement : roulis quelconque, léger lacet, décalage en long.
	var jitter := Basis.from_euler(Vector3(index * 2.4, sin(index * 12.9) * 0.04, 0.0))
	return Transform3D(jitter, Vector3(x + sin(index * 3.1) * 0.03, y, z))


## Une boîte de collision par tas, à la hauteur des rangées déjà posées.
func _update_collision() -> void:
	var visible_logs := mini(landed, max_visible_logs())
	for stack in _stack_shapes.size():
		var in_stack := clampi(visible_logs - stack * logs_per_stack(), 0, logs_per_stack())
		var collision := _stack_shapes[stack]
		collision.disabled = in_stack == 0
		if in_stack == 0:
			continue
		var rows := 0
		var row_size := GameConfig.STOCKPILE_STACK_BASE
		var remaining := in_stack
		while remaining > 0:
			remaining -= row_size
			row_size -= 1
			rows += 1
		var height := LOG_RADIUS * 2.0 + (rows - 1) * ROW_HEIGHT
		# Largeur moyenne de la pyramide : assez pour bloquer sans mur invisible autour du sommet.
		var width := (GameConfig.STOCKPILE_STACK_BASE - (rows - 1) * 0.5) * ROW_STEP
		(collision.shape as BoxShape3D).size = Vector3(1.0, height, width)
		collision.position = Vector3((float(stack) - (GameConfig.STOCKPILE_STACKS - 1) * 0.5) * STACK_STEP, height * 0.5, 0.0)


func _find_log_mesh() -> Mesh:
	var model: Node = LOG_MODEL.instantiate()
	var mesh_instance := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mesh_instance.mesh
	model.free()
	return mesh


func _on_zone_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player:
		_players_inside.append(player)
		if enabled:
			player.carrier.enter_stockpile(self)


func _on_zone_body_exited(body: Node3D) -> void:
	var player := body as Player
	if player:
		_players_inside.erase(player)
		player.carrier.exit_stockpile(self)
