class_name LogCarrier
extends Node3D
## Ramassage des bûches (touche E) et pile portée sur l'épaule gauche.
## Ramassage « ninja » : la bûche visée disparaît dans un nuage de fumée et réapparaît aussitôt
## sur la pile. La main gauche tient la pile tant qu'on porte du bois.

signal prompt_changed(text: String)
signal load_changed(count: int, capacity: int)

const LOG_MODEL := preload("res://assets/models/props/wood_log.glb")
const POOF_SCENE := preload("res://scenes/vfx/poof_vfx.tscn")
## Pile, rangées du bas vers le haut : 4 + 4 + 2 = 10 bûches (large et basse, à côté de la tête).
const ROWS: Array[int] = [4, 4, 2]
const LOG_RADIUS := 0.125
## Appui de la pile par rapport à l'épaule gauche (repère du corps : -X = gauche, -Z = avant) :
## à l'extérieur de la tête et un peu en arrière, seul le bout des bûches entre dans le champ de vision.
const STACK_OFFSET := Vector3(-0.2, 0.08, 0.03)
## Main gauche sur le flanc extérieur du fagot (repère de la pile).
const HOLD_OFFSET := Vector3(-0.24, -0.05, -0.1)
## Coude gauche : vers l'extérieur et le bas (repère du corps, à partir de l'épaule).
const ELBOW_POLE_OFFSET := Vector3(-0.45, -0.45, 0.15)

## Nombre de bûches portées.
var count := 0

var _target: WoodLog
var _prompt := ""
var _stack_root: Node3D
var _stack: Array[Node3D] = []
## Bûche qui vient d'apparaître sur la pile et le temps écoulé depuis (petit « pop » d'apparition).
var _popping: Node3D
var _pop_time := 0.0
## Poids de la main gauche sur la pile (monte en douceur à la première bûche).
var _left_weight := 0.0

@onready var _body: FirstPersonBody = owner.get_node("Body")
@onready var _camera: Camera3D = owner.get_node("Head/Camera3D")


func _ready() -> void:
	_stack_root = Node3D.new()
	_stack_root.name = "LogStack"
	_body.add_child.call_deferred(_stack_root)
	load_changed.emit.call_deferred(count, GameConfig.BASE_WOOD_CAPACITY)


func _physics_process(delta: float) -> void:
	if _stack_root.is_inside_tree():
		_stack_root.position = _body.get_left_shoulder_local() + STACK_OFFSET
	_update_target()
	if _target and Input.is_action_just_pressed("interact") and count < GameConfig.BASE_WOOD_CAPACITY:
		pick_up(_target)
	_update_pop(delta)
	_hold_stack(delta)


# --- Visée ------------------------------------------------------------------------------------

func _update_target() -> void:
	var from := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - _camera.global_basis.z * GameConfig.PICKUP_RANGE, 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_target = hit.collider as WoodLog if not hit.is_empty() else null
	if _target and _target.is_queued_for_deletion():
		_target = null
	var text := ""
	if _target:
		text = "Charge pleine (%d/%d)" % [count, GameConfig.BASE_WOOD_CAPACITY] if count >= GameConfig.BASE_WOOD_CAPACITY else "[E] Ramasser"
	_set_prompt(text)


func _set_prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


# --- Ramassage --------------------------------------------------------------------------------

## La bûche part en fumée et réapparaît sur la pile.
func pick_up(wood_log: WoodLog) -> void:
	var poof: Node3D = POOF_SCENE.instantiate()
	wood_log.get_parent().add_child(poof)
	poof.global_transform = Transform3D(wood_log.global_basis.orthonormalized(), wood_log.global_position)
	wood_log.queue_free()

	var carried := _make_log_visual()
	_stack_root.add_child(carried)
	carried.transform = _slot_transform(count)
	_stack.append(carried)
	_popping = carried
	_pop_time = 0.0
	_update_pop(0.0)
	count += 1
	load_changed.emit(count, GameConfig.BASE_WOOD_CAPACITY)


## Apparition sur la pile : la bûche grossit de 0 à sa taille en dépassant un peu (rebond).
func _update_pop(delta: float) -> void:
	if _popping == null:
		return
	_pop_time += delta
	var t := clampf(_pop_time / GameConfig.PICKUP_POP_TIME, 0.0, 1.0)
	var overshoot := 1.70158
	var bounce := 1.0 + (overshoot + 1.0) * pow(t - 1.0, 3.0) + overshoot * pow(t - 1.0, 2.0)
	var slot := _slot_transform(_stack.find(_popping))
	_popping.transform = Transform3D(slot.basis.scaled(Vector3.ONE * maxf(bounce, 0.001)), slot.origin)
	if t >= 1.0:
		_popping = null


# --- Pile sur l'épaule -------------------------------------------------------------------------

## Main gauche sur le flanc de la pile tant qu'on porte du bois, bras libre sinon.
func _hold_stack(delta: float) -> void:
	var pole := _body.to_global(_body.get_left_shoulder_local() + ELBOW_POLE_OFFSET)
	_left_weight = move_toward(_left_weight, 1.0 if count > 0 else 0.0, delta / GameConfig.PICKUP_POP_TIME)
	if _left_weight <= 0.0:
		_body.hold_left_hand_at(_left_hand_rest(), pole, 0.0)
		return
	_body.hold_left_hand_at(_stack_root.to_global(HOLD_OFFSET), pole, smoothstep(0.0, 1.0, _left_weight))


func _left_hand_rest() -> Vector3:
	return _body.to_global(_body.get_left_shoulder_local() + Vector3(-0.05, -0.55, -0.05))


## Emplacement de la `index`-ième bûche dans la pile (repère de la pile).
func _slot_transform(index: int) -> Transform3D:
	var radius := LOG_RADIUS * GameConfig.CARRIED_LOG_SCALE
	var row := 0
	var first := 0
	while row < ROWS.size() - 1 and index >= first + ROWS[row]:
		first += ROWS[row]
		row += 1
	var in_row := index - first
	var x := (float(in_row) - (ROWS[row] - 1) * 0.5) * radius * 2.05
	var y := row * radius * 1.75
	# Un peu de désordre, stable pour chaque emplacement.
	var jitter := Basis.from_euler(Vector3(0.0, sin(index * 12.9) * 0.08, sin(index * 7.3) * 0.25))
	var along_z := Basis(Vector3.UP, PI * 0.5)
	return Transform3D((jitter * along_z).scaled(Vector3.ONE * GameConfig.CARRIED_LOG_SCALE),
		Vector3(x, y, sin(index * 3.1) * 0.03))


## Bûche portée : visible (z-clip, sans ombre) + copie qui ne fait que l'ombre.
func _make_log_visual() -> Node3D:
	var root := Node3D.new()
	var visible_log: Node3D = LOG_MODEL.instantiate()
	for mesh_instance: GeometryInstance3D in visible_log.find_children("*", "GeometryInstance3D", true, false):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ZClip.apply(visible_log)
	root.add_child(visible_log)
	var shadow_log: Node3D = LOG_MODEL.instantiate()
	for mesh_instance: GeometryInstance3D in shadow_log.find_children("*", "GeometryInstance3D", true, false):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	root.add_child(shadow_log)
	return root
