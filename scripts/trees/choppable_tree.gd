class_name ChoppableTree
extends StaticBody3D
## Arbre abattable : encaisse les coups de hache, oscille, puis bascule autour d'une charnière
## au sommet de la souche. À l'impact au sol, le tronc se transforme en rondins physiques.
##
## Le modèle est découpé en deux GLB (souche + tronc). L'origine du nœud du tronc dans le GLB
## est la charnière de chute : le script la récupère automatiquement, aucun réglage par variante.

signal chopped(hit_count: int, health: float)
signal felled(fall_direction: Vector3)
signal landed(logs: Array[RigidBody3D])

enum State { STANDING, FALLING, FALLEN }

const GRAVITY := 9.81
## Hauteur (au-dessus du sol) où l'on mesure le rayon du tronc pour sa collision.
const TRUNK_PROBE_MIN_Y := 0.8
const TRUNK_PROBE_MAX_Y := 1.8

@export var log_scene: PackedScene = preload("res://scenes/props/wood_log.tscn")
@export var wood_chips_scene: PackedScene = preload("res://scenes/vfx/wood_chips_vfx.tscn")
@export var dust_scene: PackedScene = preload("res://scenes/vfx/dust_impact_vfx.tscn")
@export var hit_sounds: Array[AudioStream] = []
@export var creak_sound: AudioStream
@export var impact_sounds: Array[AudioStream] = []

var state := State.STANDING
var health := GameConfig.TREE_MAX_HEALTH
var hit_count := 0

var _sway := Vector3.ZERO           # vecteur de rotation (axe * angle), plan horizontal
var _sway_velocity := Vector3.ZERO
var _fall_direction := Vector3.FORWARD
var _fall_axis := Vector3.RIGHT
var _fall_angle := 0.0
var _fall_velocity := 0.0
var _fall_length := 4.0             # longueur du pendule équivalent (m)
var _trunk_length := 4.0            # distance charnière -> point le plus éloigné du tronc
var _has_hit_ground := false

@onready var _trunk_pivot: Node3D = $TrunkPivot
@onready var _trunk_collision: CollisionShape3D = $TrunkCollision
@onready var _stump_collision: CollisionShape3D = $StumpCollision
@onready var _hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var _creak_audio: AudioStreamPlayer3D = $CreakAudio
@onready var _impact_audio: AudioStreamPlayer3D = $ImpactAudio


func _ready() -> void:
	add_to_group("choppable_trees")
	_setup_hinge()
	_setup_collisions()


## Point d'entrée des dégâts. `from_position` = position de l'attaquant (oriente l'oscillation et la chute).
func take_hit(damage: float, hit_position: Vector3, hit_normal: Vector3, from_position: Vector3) -> void:
	if state != State.STANDING:
		return
	hit_count += 1
	health = maxf(health - damage, 0.0)

	var push := _horizontal_direction(global_position - from_position)
	_sway_velocity += Vector3.UP.cross(push).normalized() * GameConfig.TREE_SWAY_IMPULSE
	_spawn_chips(hit_position, hit_normal)
	_play_random(_hit_audio, hit_sounds, 0.9, 1.1)
	chopped.emit(hit_count, health)

	if health <= 0.0:
		_start_fall(push)


func _physics_process(delta: float) -> void:
	match state:
		State.STANDING:
			_update_sway(delta)
			_trunk_pivot.basis = _rotation_from_vector(_sway)
		State.FALLING:
			_update_fall(delta)


# --- Oscillation élastique ----------------------------------------------------------------

func _update_sway(delta: float) -> void:
	var acceleration := -_sway * GameConfig.TREE_SWAY_STIFFNESS - _sway_velocity * GameConfig.TREE_SWAY_DAMPING
	_sway_velocity += acceleration * delta
	_sway += _sway_velocity * delta


# --- Chute physique -------------------------------------------------------------------------

func _start_fall(direction: Vector3) -> void:
	state = State.FALLING
	_fall_direction = direction
	_fall_axis = Vector3.UP.cross(direction).normalized()
	# On part de l'inclinaison courante due à l'oscillation, projetée sur l'axe de chute.
	_fall_angle = maxf(_sway.dot(_fall_axis), 0.0) + GameConfig.TREE_FALL_INITIAL_ANGLE
	_fall_velocity = maxf(_sway_velocity.dot(_fall_axis), 0.0)
	_sway = Vector3.ZERO
	_trunk_collision.set_deferred("disabled", true)
	if creak_sound:
		_creak_audio.stream = creak_sound
		_creak_audio.play()
	felled.emit(direction)


func _update_fall(delta: float) -> void:
	# Pendule pesant (tige pivotant à une extrémité) : alpha = 3g / (2L) * sin(theta)
	var angular_acceleration := 3.0 * GRAVITY / (2.0 * _fall_length) * sin(_fall_angle)
	_fall_velocity += angular_acceleration * delta
	_fall_angle += _fall_velocity * delta

	var rest := GameConfig.TREE_FALL_REST_ANGLE
	if _fall_angle >= rest:
		_fall_angle = rest
		if not _has_hit_ground:
			_has_hit_ground = true
			_on_ground_impact(_fall_velocity)
		_fall_velocity = -_fall_velocity * GameConfig.TREE_FALL_BOUNCE
		if absf(_fall_velocity) < 0.08:
			_fall_velocity = 0.0
			state = State.FALLEN
			_vanish_trunk()
	_trunk_pivot.basis = Basis(_fall_axis, _fall_angle)


func _on_ground_impact(impact_speed: float) -> void:
	_creak_audio.stop()
	_play_random(_impact_audio, impact_sounds, 0.9, 1.05)

	var trunk_mid := _trunk_pivot.global_position + _fall_direction * _trunk_length * 0.5
	trunk_mid.y = global_position.y + 0.1
	_spawn_dust(trunk_mid)

	var intensity := clampf(impact_speed / 3.0, 0.4, 1.0) * GameConfig.SHAKE_TREE_FALL
	get_tree().call_group("camera_shake_receivers", "add_trauma_at",
		trunk_mid, intensity, GameConfig.SHAKE_TREE_FALL_RADIUS)

	landed.emit(_spawn_logs())


## Le tronc couché se dissout dans le nuage de poussière, laissant place aux rondins.
func _vanish_trunk() -> void:
	var duration := GameConfig.TREE_TRUNK_VANISH_TIME
	var tween := create_tween().set_parallel()
	for mesh_instance: MeshInstance3D in _trunk_pivot.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if material == null:
				continue
			material = material.duplicate()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_instance.set_surface_override_material(surface, material)
			tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_property(_trunk_pivot, "position:y", _trunk_pivot.position.y - 0.3, duration)
	tween.chain().tween_callback(_trunk_pivot.hide)


func _spawn_logs() -> Array[RigidBody3D]:
	var logs: Array[RigidBody3D] = []
	var side := _fall_axis
	var count := GameConfig.LOGS_PER_TREE
	for i in count:
		var wood_log: RigidBody3D = log_scene.instantiate()
		get_parent().add_child(wood_log)
		# Répartis le long du tronc couché, devant la souche.
		var along := lerpf(1.2, maxf(_trunk_length * 0.75, 2.6), float(i) / maxf(count - 1, 1))
		var spot := global_position + _fall_direction * along + side * randf_range(-0.45, 0.45)
		spot.y = global_position.y + 0.45 + 0.15 * i
		var yaw := atan2(-_fall_direction.z, _fall_direction.x) + randf_range(-0.5, 0.5)
		wood_log.global_transform = Transform3D(Basis(Vector3.UP, yaw), spot)
		var impulse := (_fall_direction * 0.4 + side * randf_range(-1.0, 1.0) + Vector3.UP * 0.8).normalized()
		wood_log.apply_central_impulse(impulse * GameConfig.LOG_SCATTER_IMPULSE * wood_log.mass)
		wood_log.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * wood_log.mass * 0.2)
		logs.append(wood_log)
	return logs


# --- Mise en place ------------------------------------------------------------------------

## Déplace le pivot du tronc sur l'origine du mesh de tronc (= charnière exportée depuis Blender).
func _setup_hinge() -> void:
	var trunk_mesh := _find_mesh(_trunk_pivot)
	if trunk_mesh == null:
		push_warning("%s : aucun mesh de tronc sous TrunkPivot" % name)
		return
	var hinge_local := to_local(trunk_mesh.global_position)
	_trunk_pivot.position = hinge_local
	for child in _trunk_pivot.get_children():
		if child is Node3D:
			child.position -= hinge_local

	var aabb := _local_aabb(trunk_mesh)
	var farthest := maxf(aabb.end.y, 0.5)
	_trunk_length = farthest
	# Le feuillage concentre la masse vers le haut : pendule équivalent un peu plus long que la moitié.
	_fall_length = maxf(farthest * 0.85, 2.0)


func _setup_collisions() -> void:
	var trunk_mesh := _find_mesh(_trunk_pivot)
	var stump_mesh := _find_mesh($Stump)
	var hinge_y := _trunk_pivot.position.y
	var trunk_radius := 0.25
	if trunk_mesh:
		trunk_radius = _radius_between(trunk_mesh, TRUNK_PROBE_MIN_Y, TRUNK_PROBE_MAX_Y, 0.25)
	var stump_radius := trunk_radius
	if stump_mesh:
		stump_radius = _radius_between(stump_mesh, 0.0, hinge_y, trunk_radius) * 0.85

	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = trunk_radius
	trunk_shape.height = 3.0
	_trunk_collision.shape = trunk_shape
	_trunk_collision.position = Vector3(_trunk_pivot.position.x, hinge_y + trunk_shape.height * 0.5, _trunk_pivot.position.z)

	var stump_shape := CylinderShape3D.new()
	stump_shape.radius = stump_radius
	stump_shape.height = hinge_y
	_stump_collision.shape = stump_shape
	_stump_collision.position = Vector3(_trunk_pivot.position.x, hinge_y * 0.5, _trunk_pivot.position.z)


## Rayon moyen des sommets du mesh dont la hauteur (repère de l'arbre) est dans [min_y, max_y].
func _radius_between(mesh_instance: MeshInstance3D, min_y: float, max_y: float, fallback: float) -> float:
	var to_tree := global_transform.affine_inverse() * mesh_instance.global_transform
	var axis := Vector2(_trunk_pivot.position.x, _trunk_pivot.position.z)
	var total := 0.0
	var count := 0
	for surface in mesh_instance.mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var p := to_tree * vertex
			if p.y >= min_y and p.y <= max_y:
				total += Vector2(p.x, p.z).distance_to(axis)
				count += 1
	return total / count if count > 0 else fallback


# --- Utilitaires --------------------------------------------------------------------------

func _spawn_chips(hit_position: Vector3, hit_normal: Vector3) -> void:
	var chips: Node3D = wood_chips_scene.instantiate()
	get_parent().add_child(chips)
	var normal := hit_normal if hit_normal.length_squared() > 0.01 else Vector3.BACK
	chips.global_position = hit_position + normal * 0.05
	# Le +Z local des particules pointe le long de la normale de l'impact.
	chips.global_basis = Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT)


func _spawn_dust(at: Vector3) -> void:
	var dust: Node3D = dust_scene.instantiate()
	if dust.has_method("set_length"):
		dust.set_length(_trunk_length)
	get_parent().add_child(dust)
	dust.global_position = at
	dust.global_basis = Basis.looking_at(_fall_direction, Vector3.UP)


func _play_random(player: AudioStreamPlayer3D, streams: Array[AudioStream], pitch_min: float, pitch_max: float) -> void:
	if streams.is_empty():
		return
	player.stream = streams.pick_random()
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()


func _horizontal_direction(v: Vector3) -> Vector3:
	v.y = 0.0
	if v.length_squared() < 0.0001:
		return Vector3.FORWARD
	return v.normalized()


func _rotation_from_vector(v: Vector3) -> Basis:
	var angle := v.length()
	if angle < 0.00001:
		return Basis.IDENTITY
	return Basis(v / angle, angle)


func _find_mesh(root: Node) -> MeshInstance3D:
	var found := root.find_children("*", "MeshInstance3D", true, false)
	return found[0] if not found.is_empty() else null


func _local_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var to_pivot := _trunk_pivot.global_transform.affine_inverse() * mesh_instance.global_transform
	return to_pivot * mesh_instance.get_aabb()
