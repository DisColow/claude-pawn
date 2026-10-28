class_name ChoppableTree
extends StaticBody3D
## Arbre abattable : encaisse les coups de hache et oscille. Quand sa vie tombe à zéro, le tronc
## devient un corps rigide, retenu à la souche par une rotule (charnière), et le dernier coup lui
## donne son élan : il tombe là où la physique l'emmène (direction du coup + penchant naturel dû au
## feuillage, obstacles). Au contact du sol, il éclate en rondins physiques.
##
## Le modèle est découpé en deux GLB (souche + tronc). L'origine du nœud du tronc dans le GLB
## est la charnière de chute : le script la récupère automatiquement, aucun réglage par variante.

signal chopped(hit_count: int, health: float)
signal felled(fall_direction: Vector3)
signal landed(logs: Array[RigidBody3D])

enum State { STANDING, FALLING, FALLEN }

## Hauteur (au-dessus du sol) où l'on mesure le rayon du tronc pour sa collision.
const TRUNK_PROBE_MIN_Y := 0.8
const TRUNK_PROBE_MAX_Y := 1.8
## Pas de la grille utilisée pour réduire les points des enveloppes convexes (m).
const HULL_GRID := 0.08

@export var log_scene: PackedScene = preload("res://scenes/props/wood_log.tscn")
@export var wood_chips_scene: PackedScene = preload("res://scenes/vfx/wood_chips_vfx.tscn")
@export var dust_scene: PackedScene = preload("res://scenes/vfx/dust_impact_vfx.tscn")
@export var hit_sounds: Array[AudioStream] = []
@export var creak_sound: AudioStream
@export var impact_sounds: Array[AudioStream] = []

var state := State.STANDING
var health := GameConfig.TREE_MAX_HEALTH
var hit_count := 0

var _sway := Vector3.ZERO           # vecteur de rotation (axe * angle) dans le repère de l'arbre
var _sway_velocity := Vector3.ZERO
var _trunk_length := 4.0            # distance charnière -> sommet du tronc
var _trunk_radius := 0.25
var _fall_shapes: Array[Shape3D] = []
var _fall_center_of_mass := Vector3.ZERO

var _trunk_body: RigidBody3D
var _hinge: PinJoint3D
var _fall_time := 0.0

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
	_build_fall_shapes()


## Point d'entrée des dégâts. `from_position` = position de l'attaquant (oriente l'oscillation et la chute).
func take_hit(damage: float, hit_position: Vector3, hit_normal: Vector3, from_position: Vector3) -> void:
	if state != State.STANDING:
		return
	hit_count += 1
	health = maxf(health - damage, 0.0)

	var push := _horizontal_direction(hit_position - from_position)
	var sway_axis := Vector3.UP.cross(push).normalized()
	_sway_velocity += global_basis.inverse() * sway_axis * GameConfig.TREE_SWAY_IMPULSE
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

func _start_fall(push: Vector3) -> void:
	state = State.FALLING
	_trunk_collision.set_deferred("disabled", true)
	_trunk_body = _create_trunk_body()
	# Le dernier coup lance la bascule dans sa direction ; la gravité amplifie ensuite cet élan
	# ET le penchant naturel de l'arbre (feuillage décentré) : la chute mélange les deux.
	var kick_axis := Vector3.UP.cross(push).normalized()
	_trunk_body.angular_velocity = global_basis * _sway_velocity + kick_axis * GameConfig.TREE_FELL_KICK
	_sway = Vector3.ZERO
	_sway_velocity = Vector3.ZERO
	if creak_sound:
		_creak_audio.stream = creak_sound
		_creak_audio.play()
	felled.emit(push)


## Transforme le tronc en corps rigide attaché à la souche par une rotule.
func _create_trunk_body() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "FallingTrunk"
	body.collision_layer = 4
	body.collision_mask = 1 | 4 | 8
	body.mass = GameConfig.TREE_TRUNK_MASS
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = _fall_center_of_mass
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.angular_damp = GameConfig.TREE_FALL_ANGULAR_DAMP
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.15
	body.physics_material_override = material
	for shape in _fall_shapes:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	add_child(body)
	body.global_transform = _trunk_pivot.global_transform
	_trunk_pivot.reparent(body)
	_trunk_pivot.transform = Transform3D.IDENTITY
	# Le tronc repose dans la souche : on ignore les collisions entre les deux.
	body.add_collision_exception_with(self)
	body.body_entered.connect(_on_trunk_contact)

	_hinge = PinJoint3D.new()
	_hinge.name = "Hinge"
	_hinge.position = to_local(body.global_position)
	_hinge.node_a = NodePath("..")
	_hinge.node_b = NodePath("../" + body.name)
	add_child(_hinge)
	return body


func _update_fall(delta: float) -> void:
	_fall_time += delta
	# La charnière cède une fois le tronc bien engagé : il peut alors glisser hors de la souche.
	if _hinge and _trunk_tilt() > GameConfig.TREE_HINGE_BREAK_ANGLE:
		_hinge.queue_free()
		_hinge = null
	# Sécurité : tronc coincé (appuyé sur un autre arbre) ou tombé hors du monde.
	if _fall_time > GameConfig.TREE_MAX_FALL_TIME or _trunk_body.global_position.y < global_position.y - 20.0:
		_on_ground_impact(_trunk_tip_speed())


## Seul le sol (couche "world") déclenche l'impact : un tronc peut rebondir sur un autre arbre avant.
func _on_trunk_contact(other: Node) -> void:
	if state != State.FALLING or not other is CollisionObject3D:
		return
	if other.collision_layer & 1 and _trunk_tilt() > GameConfig.TREE_IMPACT_MIN_TILT:
		_on_ground_impact(_trunk_tip_speed())


## Au contact du sol, le tronc éclate en rondins dans un nuage de poussière.
func _on_ground_impact(impact_speed: float) -> void:
	state = State.FALLEN
	_creak_audio.stop()
	_play_random(_impact_audio, impact_sounds, 0.9, 1.05)

	var axis := _trunk_axis()
	var trunk_mid := (axis[0] + axis[1]) * 0.5
	trunk_mid.y = _ground_height(trunk_mid) + 0.1
	_spawn_dust(trunk_mid, _horizontal_direction(axis[1] - axis[0]))

	var intensity := clampf(impact_speed / 8.0, 0.4, 1.0) * GameConfig.SHAKE_TREE_FALL
	get_tree().call_group("camera_shake_receivers", "add_trauma_at",
		trunk_mid, intensity, GameConfig.SHAKE_TREE_FALL_RADIUS)

	var logs := _burst_into_logs()
	if _hinge:
		_hinge.queue_free()
	_trunk_body.queue_free()
	landed.emit(logs)


## Rondins répartis le long du tronc au moment de l'impact, projetés par l'éclatement.
func _burst_into_logs() -> Array[RigidBody3D]:
	var logs: Array[RigidBody3D] = []
	var axis := _trunk_axis()
	var along := axis[1] - axis[0]
	var log_axis := along.normalized()
	var side := Vector3.UP.cross(log_axis).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var com := _trunk_body.global_transform * _trunk_body.center_of_mass
	var count := GameConfig.LOGS_PER_TREE
	for i in count:
		var spot := axis[0] + along * lerpf(0.15, 0.7, float(i) / maxf(count - 1, 1))
		spot.y = maxf(spot.y, _ground_height(spot) + 0.3)
		var wood_log: RigidBody3D = log_scene.instantiate()
		get_parent().add_child(wood_log)
		# Le rondin (axe X de son modèle) suit l'axe du tronc, avec un peu de désordre.
		var log_basis := Basis(log_axis, side.cross(log_axis).normalized(), side).rotated(Vector3.UP, randf_range(-0.35, 0.35))
		wood_log.global_transform = Transform3D(log_basis, spot)
		# Hérite d'une partie de la vitesse du tronc, plus l'éclatement (latéral et vers le haut).
		var trunk_velocity := _trunk_body.linear_velocity + _trunk_body.angular_velocity.cross(spot - com)
		var burst := (side * randf_range(-1.0, 1.0) + Vector3.UP * randf_range(0.6, 1.0)).normalized()
		wood_log.linear_velocity = trunk_velocity * 0.25 + burst * GameConfig.LOG_BURST_SPEED
		wood_log.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 4.0
		_spawn_chips(spot, Vector3.UP)
		logs.append(wood_log)
	return logs


func _trunk_tilt() -> float:
	return _trunk_body.global_basis.y.normalized().angle_to(Vector3.UP)


## [base, sommet] du tronc en coordonnées globales.
func _trunk_axis() -> Array[Vector3]:
	var base := _trunk_body.global_transform * Vector3.ZERO
	var top := _trunk_body.global_transform * Vector3(0.0, _trunk_length, 0.0)
	return [base, top]


func _trunk_tip_speed() -> float:
	var tip := _trunk_axis()[1]
	var com := _trunk_body.global_transform * _trunk_body.center_of_mass
	return (_trunk_body.linear_velocity + _trunk_body.angular_velocity.cross(tip - com)).length()


func _ground_height(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 10.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else global_position.y


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

	_trunk_length = maxf(_local_aabb(trunk_mesh).end.y, 0.5)


func _setup_collisions() -> void:
	var trunk_mesh := _find_mesh(_trunk_pivot)
	var stump_mesh := _find_mesh($Stump)
	var hinge_y := _trunk_pivot.position.y
	var trunk_radius := 0.25
	if trunk_mesh:
		trunk_radius = _radius_between(trunk_mesh, TRUNK_PROBE_MIN_Y, TRUNK_PROBE_MAX_Y, 0.25)
	_trunk_radius = trunk_radius
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


## Collisions du tronc en chute : deux enveloppes convexes (fût et feuillage) calculées depuis le mesh,
## dans le repère de la charnière. Le feuillage commence là où le mesh s'élargit nettement.
func _build_fall_shapes() -> void:
	var trunk_mesh := _find_mesh(_trunk_pivot)
	if trunk_mesh == null:
		return
	var to_pivot := _trunk_pivot.global_transform.affine_inverse() * trunk_mesh.global_transform
	var points := PackedVector3Array()
	for surface in trunk_mesh.mesh.get_surface_count():
		var vertices: PackedVector3Array = trunk_mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			points.append(to_pivot * vertex)

	var canopy_start := _canopy_start_height(points)
	var trunk_points := {}
	var canopy_points := {}
	for p in points:
		var key := Vector3i((p / HULL_GRID).round())
		if p.y < canopy_start:
			trunk_points[key] = p
		if p.y >= canopy_start * 0.85:
			canopy_points[key] = p

	_fall_shapes.clear()
	var trunk_center := Vector3.ZERO
	var canopy_center := Vector3.ZERO
	for hull_points: Dictionary in [trunk_points, canopy_points]:
		if hull_points.size() < 4:
			continue
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array(hull_points.values())
		_fall_shapes.append(shape)
	for p: Vector3 in trunk_points.values():
		trunk_center += p / trunk_points.size()
	for p: Vector3 in canopy_points.values():
		canopy_center += p / canopy_points.size()
	# Le bois du fût pèse plus lourd que le feuillage.
	_fall_center_of_mass = trunk_center.lerp(canopy_center, GameConfig.TREE_CANOPY_MASS_SHARE)


## Première hauteur (au-dessus de 1 m) où le mesh devient bien plus large que le fût.
func _canopy_start_height(points: PackedVector3Array) -> float:
	const BAND := 0.25
	var bands := {}
	for p in points:
		var band := int(p.y / BAND)
		var r := Vector2(p.x, p.z).length()
		bands[band] = maxf(bands.get(band, 0.0), r)
	var keys := bands.keys()
	keys.sort()
	for band: int in keys:
		var height := band * BAND
		if height > 1.0 and bands[band] > _trunk_radius * 4.0:
			return height
	return _trunk_length * 0.5


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


func _spawn_dust(at: Vector3, direction: Vector3) -> void:
	var dust: Node3D = dust_scene.instantiate()
	if dust.has_method("set_length"):
		dust.set_length(_trunk_length)
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
