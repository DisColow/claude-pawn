class_name WatchTower
extends CampBuilding
## Tour de guet : une fois debout, elle tire sur le squelette le plus proche à portée.

@export var shot_sounds: Array[AudioStream] = []

var _cooldown := 0.0
var _top := Vector3(0.0, 6.0, 0.0)


func _physics_process(delta: float) -> void:
	if state != State.BUILT:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var from := to_global(_top)
	var target: Unit = null
	var best := GameConfig.TOWER_RANGE
	for node in get_tree().get_nodes_in_group("undead_units"):
		var unit := node as Unit
		var distance := from.distance_to(unit.global_position)
		if distance < best:
			best = distance
			target = unit
	if target == null:
		_cooldown = 0.2
		return
	_cooldown = GameConfig.TOWER_FIRE_INTERVAL
	var hit_point := target.global_position + Vector3(0.0, 1.0, 0.0)
	target.take_damage(GameConfig.TOWER_DAMAGE, global_position)
	_spawn_tracer(from, hit_point)
	if not shot_sounds.is_empty():
		_audio.stream = shot_sounds.pick_random()
		_audio.pitch_scale = randf_range(1.5, 1.8)
		_audio.play()


func _on_model_changed() -> void:
	var box := _collision.shape as BoxShape3D
	_top = Vector3(_collision.position.x, box.size.y * 0.85, _collision.position.z)


## Trait lumineux bref entre la tour et sa cible (la flèche).
func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.55)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, from.distance_to(to))
	mesh.material = material
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(tracer)
	tracer.look_at_from_position((from + to) * 0.5, to)
	get_tree().create_timer(0.12).timeout.connect(tracer.queue_free)
