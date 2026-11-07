class_name RustlingBush
extends Area3D
## Buisson traversable : froissement de feuilles et frémissement quand le joueur passe dedans.
## Le son se répète tant qu'on s'y déplace, plus fort en courant.

@export var rustle_sounds: Array[AudioStream] = []

var _bodies: Array[CharacterBody3D] = []
var _cooldown := 0.0

@onready var _model: Node3D = $Model
@onready var _audio: AudioStreamPlayer3D = $RustleAudio


func _ready() -> void:
	_build_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	for body in _bodies:
		var speed := Vector2(body.velocity.x, body.velocity.z).length()
		if speed > GameConfig.BUSH_RUSTLE_MIN_SPEED:
			_rustle(speed / GameConfig.SPRINT_SPEED)
			return


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_bodies.append(body)
	_rustle(0.8)
	set_physics_process(true)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
	if _bodies.is_empty():
		set_physics_process(false)


func _rustle(intensity: float) -> void:
	_cooldown = GameConfig.BUSH_RUSTLE_INTERVAL
	if not rustle_sounds.is_empty():
		_audio.stream = rustle_sounds.pick_random()
		_audio.pitch_scale = randf_range(0.9, 1.15)
		_audio.volume_db = linear_to_db(clampf(intensity, 0.35, 1.0))
		_audio.play()
	# Frémissement : le feuillage penche un instant puis revient en oscillant.
	var tilt := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * GameConfig.BUSH_SHAKE_ANGLE
	var tween := create_tween()
	tween.tween_property(_model, "rotation", tilt, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_model, "rotation", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Zone de détection : cylindre englobant le feuillage.
func _build_shape() -> void:
	var bounds := AABB()
	var first := true
	for mesh_instance: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var local := (global_transform.affine_inverse() * mesh_instance.global_transform) * mesh_instance.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	var shape := CylinderShape3D.new()
	shape.radius = maxf(bounds.size.x, bounds.size.z) * 0.4
	shape.height = maxf(bounds.size.y, 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = bounds.get_center()
	add_child(collision)
