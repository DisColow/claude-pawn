class_name AxeController
extends Node3D
## Anime la hache en espace caméra (enfant de la caméra) et gère le coup :
## armé -> élan (wind-up) -> frappe en arc -> impact (hit-stop) -> retour.
## Le bras droit du corps suit la hache par IK (FirstPersonBody.hold_axe_at).

signal swing_started
signal hit_landed(collider: Object, position: Vector3)
signal swing_missed

enum Phase { READY, WINDUP, STRIKE, FOLLOW, RECOVER }

## Arc de frappe autour de l'épaule : axe légèrement incliné => coup oblique haut-droite -> bas-gauche.
const SWING_AXIS := Vector3(0.28, 1.0, 0.12)
const WINDUP_ANGLE := deg_to_rad(-115.0)   # hache armée derrière l'épaule droite
const STRIKE_ANGLE := deg_to_rad(8.0)      # devant soi, au moment de l'impact
const FOLLOW_ANGLE := deg_to_rad(32.0)     # accompagnement en cas de coup dans le vide
const HANDLE_RISE := 0.25                   # le manche remonte un peu au-dessus du plan de l'arc
const GRIP_OFFSET := 0.08                   # distance main -> origine du modèle de hache
const HIT_STOP_TIME := 0.07
const RECOIL_ANGLE := deg_to_rad(-6.0)

# Pose "armée" en espace caméra (position de la main, direction du manche, direction du tranchant).
const READY_HAND := Vector3(0.25, -0.27, -0.4)
const READY_HANDLE := Vector3(-0.2, 1.0, -0.15)
const READY_EDGE := Vector3(-0.25, 0.1, -1.0)

@export var body: FirstPersonBody
@export var camera: Camera3D

var phase := Phase.READY
var _time := 0.0
var _hit_stop := 0.0
var _did_hit := false
var _impact_angle := STRIKE_ANGLE
var _bob_time := 0.0
var _bob_amount := 0.0
var _swing_queued := false


func is_swinging() -> bool:
	return phase != Phase.READY


## Demande un coup. Mis en file s'il arrive pendant la fin du coup précédent.
func request_swing() -> void:
	if phase == Phase.READY:
		_start_swing()
	elif phase == Phase.RECOVER:
		_swing_queued = true


## Intensité du balancement de marche (0..1), écrite par le joueur.
func set_walk_bob(amount: float) -> void:
	_bob_amount = amount


func _physics_process(delta: float) -> void:
	if _hit_stop > 0.0:
		_hit_stop -= delta
	else:
		_advance(delta)
	_bob_time += delta * lerpf(0.0, 9.0, _bob_amount)
	_apply_pose()


func _start_swing() -> void:
	phase = Phase.WINDUP
	_time = 0.0
	_did_hit = false
	_swing_queued = false
	swing_started.emit()


func _advance(delta: float) -> void:
	if phase == Phase.READY:
		return
	_time += delta
	var hit_time := GameConfig.AXE_HIT_TIME
	var windup_end := hit_time * 0.62
	match phase:
		Phase.WINDUP:
			if _time >= windup_end:
				phase = Phase.STRIKE
		Phase.STRIKE:
			if _time >= hit_time:
				_resolve_hit()
				phase = Phase.FOLLOW
		Phase.FOLLOW:
			if _time >= hit_time + 0.12:
				phase = Phase.RECOVER
		Phase.RECOVER:
			if _time >= GameConfig.AXE_SWING_DURATION:
				phase = Phase.READY
				if _swing_queued:
					_start_swing()


func _resolve_hit() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_basis.z * GameConfig.AXE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	query.exclude = [owner.get_rid()] if owner is CollisionObject3D else []
	var result := space.intersect_ray(query)
	if result.is_empty() or not result.collider.has_method("take_hit"):
		swing_missed.emit()
		return
	_did_hit = true
	_impact_angle = STRIKE_ANGLE
	_hit_stop = HIT_STOP_TIME
	result.collider.take_hit(GameConfig.AXE_DAMAGE, result.position, result.normal, owner.global_position)
	hit_landed.emit(result.collider, result.position)


# --- Pose de la hache ----------------------------------------------------------------------

func _apply_pose() -> void:
	if body == null or camera == null:
		return
	var shoulder := camera.to_local(body.get_shoulder_position())
	var axe_local := _pose_for_phase(shoulder)
	var axe_global := camera.global_transform * axe_local
	var pole := camera.global_transform * (shoulder + Vector3(0.45, -0.55, 0.25))
	body.hold_axe_at(axe_global, pole)


func _pose_for_phase(shoulder: Vector3) -> Transform3D:
	var ready_pose := _ready_pose()
	var hit_time := GameConfig.AXE_HIT_TIME
	var windup_end := hit_time * 0.62
	match phase:
		Phase.WINDUP:
			var t := _ease_out(_time / windup_end)
			return ready_pose.interpolate_with(_arc_pose(shoulder, WINDUP_ANGLE), t)
		Phase.STRIKE:
			var t := _ease_in(clampf((_time - windup_end) / (hit_time - windup_end), 0.0, 1.0))
			return _arc_pose(shoulder, lerpf(WINDUP_ANGLE, STRIKE_ANGLE, t))
		Phase.FOLLOW:
			var t := _ease_out(clampf((_time - hit_time) / 0.12, 0.0, 1.0))
			var end_angle := _impact_angle + RECOIL_ANGLE if _did_hit else FOLLOW_ANGLE
			return _arc_pose(shoulder, lerpf(STRIKE_ANGLE, end_angle, t))
		Phase.RECOVER:
			var start := (hit_time + 0.12)
			var t := _ease_in_out(clampf((_time - start) / (GameConfig.AXE_SWING_DURATION - start), 0.0, 1.0))
			var end_angle := _impact_angle + RECOIL_ANGLE if _did_hit else FOLLOW_ANGLE
			return _arc_pose(shoulder, end_angle).interpolate_with(ready_pose, t)
	return ready_pose


func _ready_pose() -> Transform3D:
	var bob := Vector3(sin(_bob_time) * 0.018, -absf(cos(_bob_time)) * 0.022, 0.0) * _bob_amount
	return _axe_transform(READY_HAND + bob, READY_HANDLE, READY_EDGE)


## Pose sur l'arc de frappe : la main tourne autour de l'épaule, le tranchant mène le mouvement.
func _arc_pose(shoulder: Vector3, angle: float) -> Transform3D:
	var axis := SWING_AXIS.normalized()
	var forward := (Vector3.FORWARD - axis * Vector3.FORWARD.dot(axis)).normalized()
	var radial := forward.rotated(axis, angle)
	var hand := shoulder + radial * body.arm_length * 0.86 + Vector3(0, -0.08, 0)
	var handle := (radial + axis * HANDLE_RISE).normalized()
	var edge := axis.cross(radial).normalized()
	return _axe_transform(hand, handle, edge)


## Transform de la hache à partir de la main, du manche (+Y hache) et du tranchant (-X hache).
func _axe_transform(hand: Vector3, handle_dir: Vector3, edge_dir: Vector3) -> Transform3D:
	var y := handle_dir.normalized()
	var x := -(edge_dir - y * edge_dir.dot(y)).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), hand + y * GRIP_OFFSET)


func _ease_in(t: float) -> float:
	return t * t * t


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0)


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
