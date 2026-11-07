class_name LogCarrier
extends Node3D
## Ramassage des bûches (touche E) et pile portée sur l'épaule gauche.
## Le ramassage est animé en body awareness : accroupissement, regard vers la bûche, bras gauche
## qui va la saisir au sol (IK), puis la remonte sur la pile, que la main gauche maintient ensuite.

signal prompt_changed(text: String)
signal load_changed(count: int, capacity: int)

const LOG_MODEL := preload("res://assets/models/props/wood_log.glb")
## Pile, rangées du bas vers le haut : 4 + 4 + 2 = 10 bûches (large et basse, à côté de la tête).
const ROWS: Array[int] = [4, 4, 2]
const LOG_RADIUS := 0.125
const LOG_LENGTH := 1.0
## Appui de la pile par rapport à l'épaule gauche (repère du corps : -X = gauche, -Z = avant) :
## à l'extérieur de la tête et un peu en arrière, seul le bout des bûches entre dans le champ de vision.
const STACK_OFFSET := Vector3(-0.2, 0.08, 0.03)
## Main gauche sur le flanc extérieur du fagot (repère de la pile).
const HOLD_OFFSET := Vector3(-0.24, -0.05, -0.1)
## Coude gauche : vers l'extérieur et le bas.
const ELBOW_POLE_OFFSET := Vector3(-0.45, -0.45, 0.15)
## Point de passage de la bûche entre le sol et l'épaule : par la gauche, hors du centre de la vue.
const LIFT_WAYPOINT := Vector3(-0.45, -0.3, -0.15)

## Nombre de bûches portées.
var count := 0
## Accroupissement (0..1), décalage du regard (rad) et pas vers la bûche (m/s) à appliquer par le joueur.
var crouch := 0.0
var look_offset := 0.0
var step_velocity := Vector3.ZERO

var _target: WoodLog
var _prompt := ""
var _busy := false
var _time := 0.0
var _picked: WoodLog
var _grab_point := Vector3.ZERO
var _grab_basis := Basis.IDENTITY
var _hand_start := Vector3.ZERO
var _in_hand: Node3D
var _stack_root: Node3D
var _stack: Array[Node3D] = []

@onready var _player: Player = owner
@onready var _body: FirstPersonBody = owner.get_node("Body")
@onready var _camera: Camera3D = owner.get_node("Head/Camera3D")


func _ready() -> void:
	_stack_root = Node3D.new()
	_stack_root.name = "LogStack"
	_body.add_child.call_deferred(_stack_root)
	load_changed.emit.call_deferred(count, GameConfig.BASE_WOOD_CAPACITY)


func is_busy() -> bool:
	return _busy


func _physics_process(delta: float) -> void:
	if _stack_root.is_inside_tree():
		_stack_root.position = _body.get_left_shoulder_local() + STACK_OFFSET
	if _busy:
		_update_pickup(delta)
	else:
		_update_target()
		if _target and Input.is_action_just_pressed("interact") and count < GameConfig.BASE_WOOD_CAPACITY:
			_start_pickup(_target)
		_hold_stack()


# --- Visée ------------------------------------------------------------------------------------

func _update_target() -> void:
	var from := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - _camera.global_basis.z * GameConfig.PICKUP_RANGE, 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_target = hit.collider as WoodLog if not hit.is_empty() else null
	var text := ""
	if _target:
		text = "Charge pleine (%d/%d)" % [count, GameConfig.BASE_WOOD_CAPACITY] if count >= GameConfig.BASE_WOOD_CAPACITY else "[E] Ramasser"
	_set_prompt(text)


func _set_prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


# --- Séquence de ramassage --------------------------------------------------------------------

func _start_pickup(wood_log: WoodLog) -> void:
	_busy = true
	_time = 0.0
	_picked = wood_log
	_set_prompt("")
	_hand_start = _left_hand_rest()


func _update_pickup(delta: float) -> void:
	_time += delta
	var grab := GameConfig.PICKUP_GRAB_TIME
	var duration := GameConfig.PICKUP_DURATION

	# Accroupissement : descente jusqu'à la saisie, puis relevé.
	crouch = smoothstep(0.0, grab * 0.8, _time) if _time < grab + 0.05 \
		else 1.0 - smoothstep(grab + 0.05, duration - 0.05, _time)

	if _picked and is_instance_valid(_picked):
		_grab_point = _nearest_grab_point(_picked)
		_grab_basis = _picked.global_basis
	elif _time < grab:
		_cancel_pickup()
		return

	# L'orc fait un pas vers la bûche en s'accroupissant, pour l'avoir à portée de main.
	step_velocity = Vector3.ZERO
	if _time < grab * 0.8:
		var to_grab := _grab_point - _player.global_position
		to_grab.y = 0.0
		var gap := to_grab.length() - GameConfig.PICKUP_REACH
		if gap > 0.0:
			step_velocity = to_grab.normalized() * gap / maxf(grab * 0.8 - _time, delta)

	# Le regard est attiré vers la bûche pendant la descente.
	var to_log := _grab_point - _camera.global_position
	var log_pitch := atan2(to_log.y, Vector2(to_log.x, to_log.z).length())
	look_offset = (log_pitch - _player.look_pitch()) * GameConfig.PICKUP_LOOK_BLEND * smoothstep(0.0, 1.0, crouch)

	var pole := _body.to_global(_body.get_left_shoulder_local() + ELBOW_POLE_OFFSET)
	if _time < grab:
		var reach := _ease(_time / grab)
		_body.hold_left_hand_at(_hand_start.lerp(_grab_point, reach), pole, smoothstep(0.0, 0.25, _time / grab))
	else:
		if _picked:
			_take_log()
		var slot := _stack_root.global_transform * _slot_transform(count)
		var u := _ease(clampf((_time - grab) / (duration - grab), 0.0, 1.0))
		var from := Transform3D(_grab_basis.orthonormalized().scaled(Vector3.ONE * GameConfig.CARRIED_LOG_SCALE), _grab_point)
		# Trajectoire en arc par la gauche (courbe de Bézier) : la bûche ne passe pas devant les yeux.
		var waypoint := _body.to_global(_body.get_left_shoulder_local() + LIFT_WAYPOINT)
		var lift_position := from.origin.lerp(waypoint, u).lerp(waypoint.lerp(slot.origin, u), u)
		var rotation_blend := from.basis.orthonormalized().slerp(slot.basis.orthonormalized(), u)
		_in_hand.global_transform = Transform3D(rotation_blend.scaled(Vector3.ONE * GameConfig.CARRIED_LOG_SCALE), lift_position)
		_body.hold_left_hand_at(_in_hand.global_position - Vector3.UP * LOG_RADIUS * GameConfig.CARRIED_LOG_SCALE * 1.4, pole, 1.0)

	if _time >= duration:
		_finish_pickup()


## Saisie : la bûche physique disparaît, sa copie portée suit la main.
func _take_log() -> void:
	_picked.queue_free()
	_picked = null
	_in_hand = _make_log_visual()
	_stack_root.add_child(_in_hand)


## Point de saisie : l'endroit de l'axe de la bûche le plus proche du joueur (un peu au-dessus).
func _nearest_grab_point(wood_log: WoodLog) -> Vector3:
	var axis := wood_log.global_basis.x.normalized()
	var half := LOG_LENGTH * 0.5 - 0.12
	var along := clampf((_player.global_position - wood_log.global_position).dot(axis), -half, half)
	return wood_log.global_position + axis * along + Vector3.UP * LOG_RADIUS * 0.6


func _finish_pickup() -> void:
	_in_hand.transform = _slot_transform(count)
	_stack.append(_in_hand)
	_in_hand = null
	count += 1
	_busy = false
	crouch = 0.0
	look_offset = 0.0
	step_velocity = Vector3.ZERO
	load_changed.emit(count, GameConfig.BASE_WOOD_CAPACITY)


func _cancel_pickup() -> void:
	_busy = false
	_picked = null
	crouch = 0.0
	look_offset = 0.0
	step_velocity = Vector3.ZERO


# --- Pile sur l'épaule -------------------------------------------------------------------------

## Main gauche posée sous l'avant de la pile tant qu'on porte du bois, bras libre sinon.
func _hold_stack() -> void:
	var pole := _body.to_global(_body.get_left_shoulder_local() + ELBOW_POLE_OFFSET)
	if count == 0:
		_body.hold_left_hand_at(_left_hand_rest(), pole, 0.0)
		return
	_body.hold_left_hand_at(_stack_root.to_global(HOLD_OFFSET), pole, 1.0)


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


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
