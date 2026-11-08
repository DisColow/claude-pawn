class_name LogCarrier
extends Node3D
## Ramassage des bûches (touche E) et pile portée sur l'épaule gauche.
## Le ramassage est animé en body awareness. La main gauche ne lâche jamais la pile (sinon les bûches
## déjà portées tomberaient) : l'orc range sa hache à la ceinture, s'accroupit, saisit la bûche de la
## main droite, la hisse en travers du corps jusqu'à son épaule gauche, puis reprend sa hache.

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
## Coudes : vers l'extérieur et le bas (repère du corps, à partir de chaque épaule).
const ELBOW_POLE_OFFSET := Vector3(-0.45, -0.45, 0.15)
const RIGHT_ELBOW_POLE_OFFSET := Vector3(0.45, -0.5, 0.2)
## Point de passage de la bûche entre le sol et l'épaule gauche : devant le bas du torse
## (repère du corps, à partir de l'épaule gauche).
const LIFT_WAYPOINT := Vector3(0.22, -0.4, -0.38)
## Bûche tenue dans le poing droit (repère de l'os hand_r) : son axe suit l'axe du poing (+Z),
## elle est sous la paume (-X), au centre du poing calibré pour la hache.
const GRIP_CENTER := Vector3(-0.035, 0.095, 0.0)

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
var _log_center := Vector3.ZERO
var _log_axis := Vector3.RIGHT
var _grab_hand := Transform3D.IDENTITY
var _axe_stowed := false
var _placed := false
var _count_before := 0
var _in_hand: Node3D
var _stack_root: Node3D
var _stack: Array[Node3D] = []

@onready var _player: Player = owner
@onready var _body: FirstPersonBody = owner.get_node("Body")
@onready var _camera: Camera3D = owner.get_node("Head/Camera3D")
@onready var _axe: AxeController = owner.get_node("Head/Camera3D/AxeRig")


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
		_hold_stack()
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
	_axe_stowed = false
	_placed = false
	_count_before = count
	_axe.suspended = true
	_set_prompt("")


func _update_pickup(delta: float) -> void:
	_time += delta
	var stow := GameConfig.PICKUP_STOW_TIME
	var grab := GameConfig.PICKUP_GRAB_TIME
	var place := GameConfig.PICKUP_PLACE_TIME
	var draw := GameConfig.PICKUP_DRAW_TIME
	var duration := GameConfig.PICKUP_DURATION

	if _picked and is_instance_valid(_picked):
		_log_axis = _picked.global_basis.x.normalized()
		_log_center = _nearest_grab_point(_picked)
	elif _time < grab:
		_cancel_pickup()
		return

	# Accroupissement pendant que la main va vers la bûche, relevé pendant qu'elle la hisse.
	crouch = smoothstep(stow * 0.5, grab, _time) if _time < grab + 0.05 \
		else 1.0 - smoothstep(grab + 0.05, place, _time)

	# L'orc fait un pas vers la bûche en s'accroupissant, pour l'avoir à portée de main.
	step_velocity = Vector3.ZERO
	if _time < grab * 0.85:
		var to_log := _log_center - _player.global_position
		to_log.y = 0.0
		var gap := to_log.length() - GameConfig.PICKUP_REACH
		if gap > 0.0:
			step_velocity = to_log.normalized() * gap / maxf(grab * 0.85 - _time, delta)

	# Le regard est attiré vers la bûche pendant la descente.
	var to_target := _log_center - _camera.global_position
	var log_pitch := atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	look_offset = (log_pitch - _player.look_pitch()) * GameConfig.PICKUP_LOOK_BLEND * smoothstep(0.0, 1.0, crouch)

	var guard := _axe.hand_pose()
	var holster := _body.hand_for_axe(_body.axe_stow_global())
	var pole := _body.to_global(_body.get_right_shoulder_local() + RIGHT_ELBOW_POLE_OFFSET)
	var hand: Transform3D

	if _time < stow:
		# 1. La main droite range la hache à la ceinture.
		hand = guard.interpolate_with(holster, _ease(_time / stow))
	elif _time < grab:
		_set_axe_stowed(true)
		# 2. Main droite vers la bûche, prise par-dessus.
		_grab_hand = _hand_on_log(_log_center, _log_axis, 1.0)
		hand = holster.interpolate_with(_grab_hand, _ease((_time - stow) / (grab - stow)))
	elif _time < place:
		if _picked:
			_take_log()
		# 3. La bûche est hissée en travers du corps jusqu'à l'épaule gauche, en rapetissant
		#    jusqu'à sa taille « portée ».
		var u := _ease((_time - grab) / (place - grab))
		var log_scale := lerpf(1.0, GameConfig.CARRIED_LOG_SCALE, u)
		var slot := _stack_root.global_transform * _slot_transform(count)
		var place_hand := slot * _log_in_hand(GameConfig.CARRIED_LOG_SCALE).affine_inverse()
		var waypoint := _body.to_global(_body.get_left_shoulder_local() + LIFT_WAYPOINT)
		var origin := _grab_hand.origin.lerp(waypoint, u).lerp(waypoint.lerp(place_hand.origin, u), u)
		hand = Transform3D(_grab_hand.basis.orthonormalized().slerp(place_hand.basis.orthonormalized(), u), origin)
		# La bûche suit le poing ; en fin de course elle se cale dans son emplacement.
		var held := hand * _log_in_hand(log_scale)
		_in_hand.global_transform = held.interpolate_with(slot, smoothstep(0.7, 1.0, u))
	else:
		if not _placed:
			_place_log()
		if _time < draw:
			# 4. La main droite redescend à la ceinture reprendre la hache…
			var slot_hand := _stack_root.global_transform * _slot_transform(count - 1) * _log_in_hand(GameConfig.CARRIED_LOG_SCALE).affine_inverse()
			hand = slot_hand.interpolate_with(holster, _ease((_time - place) / (draw - place)))
		else:
			_set_axe_stowed(false)
			# 5. … et revient en garde.
			hand = holster.interpolate_with(guard, _ease((_time - draw) / (duration - draw)))

	_body.hold_right_hand_at(hand, pole)
	if _time >= duration:
		_finish_pickup()


## Main droite qui empoigne la bûche par-dessus : axe du poing le long de la bûche (pouce vers la
## gauche du joueur), paume vers le bas.
func _hand_on_log(center: Vector3, axis: Vector3, log_scale: float) -> Transform3D:
	var player_left := -_player.global_basis.x
	var z := axis if axis.dot(player_left) >= 0.0 else -axis
	var x := Vector3.UP
	var y := z.cross(x).normalized()
	var grip := Basis(x, y, z)
	var held := _log_in_hand(log_scale)
	return Transform3D(grip, center - grip * held.origin)


## Bûche tenue dans le poing droit, à l'échelle `log_scale` (1 = taille au sol).
func _log_in_hand(log_scale: float) -> Transform3D:
	var along_fist := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	return Transform3D(along_fist.scaled(Vector3.ONE * log_scale), GRIP_CENTER + Vector3(-LOG_RADIUS * log_scale * 0.9, 0.0, 0.0))


func _set_axe_stowed(stowed: bool) -> void:
	if stowed != _axe_stowed:
		_axe_stowed = stowed
		_body.set_axe_stowed(stowed)


## Saisie : la bûche physique disparaît, sa copie portée suit la main.
func _take_log() -> void:
	_picked.queue_free()
	_picked = null
	_in_hand = _make_log_visual()
	_stack_root.add_child(_in_hand)


## Point de saisie : l'endroit de l'axe de la bûche le plus proche du joueur.
func _nearest_grab_point(wood_log: WoodLog) -> Vector3:
	var axis := wood_log.global_basis.x.normalized()
	var half := LOG_LENGTH * 0.5 - 0.15
	var along := clampf((_player.global_position - wood_log.global_position).dot(axis), -half, half)
	return wood_log.global_position + axis * along


## Pose : la bûche rejoint la pile, la main gauche (qui tient la pile) la cale.
func _place_log() -> void:
	_placed = true
	_in_hand.transform = _slot_transform(count)
	_stack.append(_in_hand)
	_in_hand = null
	count += 1
	load_changed.emit(count, GameConfig.BASE_WOOD_CAPACITY)


func _finish_pickup() -> void:
	_set_axe_stowed(false)
	_axe.suspended = false
	_busy = false
	crouch = 0.0
	look_offset = 0.0
	step_velocity = Vector3.ZERO


func _cancel_pickup() -> void:
	_set_axe_stowed(false)
	_axe.suspended = false
	_busy = false
	_picked = null
	crouch = 0.0
	look_offset = 0.0
	step_velocity = Vector3.ZERO


# --- Pile sur l'épaule -------------------------------------------------------------------------

## Main gauche sur le flanc de la pile tant qu'on porte du bois, bras libre sinon. Pour la toute
## première bûche, la main gauche monte l'accueillir pendant que la droite la hisse.
func _hold_stack() -> void:
	var pole := _body.to_global(_body.get_left_shoulder_local() + ELBOW_POLE_OFFSET)
	var weight := 1.0 if count > 0 else 0.0
	if _busy and _count_before == 0 and not _placed:
		var lift := (_time - GameConfig.PICKUP_GRAB_TIME) / (GameConfig.PICKUP_PLACE_TIME - GameConfig.PICKUP_GRAB_TIME)
		weight = smoothstep(0.4, 1.0, lift)
	if weight <= 0.0:
		_body.hold_left_hand_at(_left_hand_rest(), pole, 0.0)
		return
	_body.hold_left_hand_at(_stack_root.to_global(HOLD_OFFSET), pole, weight)


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
