class_name ChoppableTree
extends StaticBody3D
## Arbre abattable : encaisse les coups de hache et oscille. Quand sa vie tombe à zéro, le tronc
## explose sur place en rondins physiques, projetés surtout dans la direction du dernier coup.
## La souche reste en place, sans collision : on la traverse.
##
## Le modèle est découpé en deux GLB (souche + tronc). L'origine du nœud du tronc dans le GLB
## est le sommet de la souche : le script la récupère automatiquement, aucun réglage par variante.

signal chopped(hit_count: int, health: float)
signal burst(logs: Array[RigidBody3D])

enum State { STANDING, BURST }

## Hauteur (au-dessus du sol) où l'on mesure le rayon du tronc pour sa collision.
const TRUNK_PROBE_MIN_Y := 0.8
const TRUNK_PROBE_MAX_Y := 1.8

@export var log_scene: PackedScene = preload("res://scenes/props/wood_log.tscn")
@export var wood_chips_scene: PackedScene = preload("res://scenes/vfx/wood_chips_vfx.tscn")
@export var dust_scene: PackedScene = preload("res://scenes/vfx/dust_impact_vfx.tscn")
@export var hit_sounds: Array[AudioStream] = []
@export var burst_sounds: Array[AudioStream] = []

var state := State.STANDING
var health := GameConfig.TREE_MAX_HEALTH
var hit_count := 0

var _sway := Vector3.ZERO           # vecteur de rotation (axe * angle) dans le repère de l'arbre
var _sway_velocity := Vector3.ZERO
var _trunk_length := 4.0            # sommet de la souche -> sommet du tronc

@onready var _trunk_pivot: Node3D = $TrunkPivot
@onready var _trunk_collision: CollisionShape3D = $TrunkCollision
@onready var _stump_collision: CollisionShape3D = $StumpCollision
@onready var _hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var _burst_audio: AudioStreamPlayer3D = $BurstAudio


func _ready() -> void:
	add_to_group("choppable_trees")
	_setup_hinge()
	_setup_collisions()


## Point d'entrée des dégâts. `from_position` = position de l'attaquant (oriente l'oscillation et l'explosion),
## `swing_direction` = sens du mouvement de la hache (les éclats d'écorce partent à l'opposé).
func take_hit(damage: float, hit_position: Vector3, hit_normal: Vector3, from_position: Vector3,
		swing_direction := Vector3.ZERO) -> void:
	if state != State.STANDING:
		return
	hit_count += 1
	health = maxf(health - damage, 0.0)

	var push := _horizontal_direction(hit_position - from_position)
	var sway_axis := Vector3.UP.cross(push).normalized()
	_sway_velocity += global_basis.inverse() * sway_axis * GameConfig.TREE_SWAY_IMPULSE
	_spawn_chips(hit_position, _chip_direction(hit_normal, swing_direction))
	_play_random(_hit_audio, hit_sounds, 0.9, 1.1)
	chopped.emit(hit_count, health)

	if health <= 0.0:
		_burst(push)


func _physics_process(delta: float) -> void:
	if state == State.STANDING:
		_update_sway(delta)
		_trunk_pivot.basis = _rotation_from_vector(_sway)


# --- Oscillation élastique ----------------------------------------------------------------

func _update_sway(delta: float) -> void:
	var acceleration := -_sway * GameConfig.TREE_SWAY_STIFFNESS - _sway_velocity * GameConfig.TREE_SWAY_DAMPING
	_sway_velocity += acceleration * delta
	_sway += _sway_velocity * delta


# --- Explosion en rondins -----------------------------------------------------------------

func _burst(push: Vector3) -> void:
	state = State.BURST
	var base := _trunk_pivot.global_position
	var canopy := base + Vector3.UP * _trunk_length * 0.7

	# Une fois l'arbre réduit en bûches, plus rien ne bloque : ni le tronc, ni la souche.
	_trunk_collision.set_deferred("disabled", true)
	_stump_collision.set_deferred("disabled", true)
	_trunk_pivot.hide()
	_play_random(_burst_audio, burst_sounds, 0.95, 1.05)
	_spawn_dust(base - Vector3.UP * (base.y - global_position.y - 0.1), push, 2.0)
	_spawn_dust(canopy, push, 3.0)
	get_tree().call_group("camera_shake_receivers", "add_trauma_at",
		base, GameConfig.SHAKE_TREE_BURST, GameConfig.SHAKE_TREE_BURST_RADIUS)
	burst.emit(_spawn_logs(base, push))
	_trunk_pivot.queue_free()


## Rondins empilés le long du fût, projetés vers l'avant (direction du coup), sur les côtés et en l'air.
func _spawn_logs(base: Vector3, push: Vector3) -> Array[RigidBody3D]:
	var logs: Array[RigidBody3D] = []
	var side := Vector3.UP.cross(push).normalized()
	var count := GameConfig.LOGS_PER_TREE
	var top := minf(_trunk_length * 0.45, 3.0)
	for i in count:
		var t := float(i) / maxf(count - 1, 1)
		var spot := base + Vector3.UP * lerpf(0.35, top, t)
		var wood_log: RigidBody3D = log_scene.instantiate()
		get_parent().add_child(wood_log)
		wood_log.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), spot)
		var spread := side * randf_range(-1.0, 1.0) * GameConfig.LOG_BURST_SPREAD
		var direction := (push + spread).normalized()
		wood_log.linear_velocity = direction * GameConfig.LOG_BURST_SPEED * randf_range(0.7, 1.2) \
			+ Vector3.UP * GameConfig.LOG_BURST_UP_SPEED * randf_range(0.6, 1.1)
		wood_log.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 6.0
		_spawn_chips(spot, direction)
		logs.append(wood_log)
	return logs


# --- Mise en place ------------------------------------------------------------------------

## Déplace le pivot du tronc sur l'origine du mesh de tronc (= sommet de la souche, exporté depuis Blender).
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

	_trunk_length = maxf(_local_aabb(trunk_mesh).end.y, 0.5)


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

## Les éclats repartent à l'opposé du mouvement de la hache, en s'écartant un peu de l'écorce.
func _chip_direction(hit_normal: Vector3, swing_direction: Vector3) -> Vector3:
	var normal := hit_normal if hit_normal.length_squared() > 0.01 else Vector3.BACK
	if swing_direction.length_squared() < 0.01:
		return normal
	return (-swing_direction.normalized() + normal * GameConfig.BARK_CHIPS_SURFACE_BIAS).normalized()


func _spawn_chips(at: Vector3, direction: Vector3) -> void:
	var chips: Node3D = wood_chips_scene.instantiate()
	get_parent().add_child(chips)
	chips.global_position = at + direction * 0.04
	# Le +Z local des particules pointe dans la direction d'éjection.
	chips.global_basis = Basis.looking_at(-direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)


func _spawn_dust(at: Vector3, direction: Vector3, length: float) -> void:
	var dust: Node3D = dust_scene.instantiate()
	if dust.has_method("set_length"):
		dust.set_length(length)
	get_parent().add_child(dust)
	dust.global_position = at
	dust.global_basis = Basis.looking_at(direction, Vector3.UP)


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
