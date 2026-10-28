class_name CameraShake
extends Camera3D
## Secousse d'écran par "trauma" : l'intensité perçue est trauma², bruitée et amortie dans le temps.

@export var max_offset := Vector3(0.06, 0.05, 0.0)
@export var max_roll := deg_to_rad(4.0)
@export var max_tilt := deg_to_rad(2.5)
@export var decay := 1.8
@export var frequency := 22.0

var trauma := 0.0

var _noise := FastNoiseLite.new()
var _time := 0.0
var _base_transform := Transform3D.IDENTITY


func _ready() -> void:
	add_to_group("camera_shake_receivers")
	_noise.seed = randi()
	_noise.frequency = 1.0
	_base_transform = transform


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Secousse provenant d'un événement du monde, atténuée avec la distance.
func add_trauma_at(world_position: Vector3, amount: float, radius: float) -> void:
	var distance := global_position.distance_to(world_position)
	if distance >= radius:
		return
	add_trauma(amount * (1.0 - distance / radius))


func _process(delta: float) -> void:
	_time += delta * frequency
	trauma = maxf(trauma - decay * delta, 0.0)
	var shake := trauma * trauma
	var offset := Vector3(
		max_offset.x * shake * _noise.get_noise_2d(_time, 0.0),
		max_offset.y * shake * _noise.get_noise_2d(_time, 100.0),
		0.0)
	var rotation_offset := Vector3(
		max_tilt * shake * _noise.get_noise_2d(_time, 200.0),
		max_tilt * shake * _noise.get_noise_2d(_time, 300.0),
		max_roll * shake * _noise.get_noise_2d(_time, 400.0))
	transform = _base_transform * Transform3D(Basis.from_euler(rotation_offset), offset)
