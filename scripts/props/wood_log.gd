class_name WoodLog
extends RigidBody3D
## Rondin de bois physique, prêt à être ramassé (le ramassage arrive à l'étape suivante).

const IMPACT_SOUND_MIN_SPEED := 1.5

@export var drop_sounds: Array[AudioStream] = []

@onready var _audio: AudioStreamPlayer3D = $DropAudio

var _sound_cooldown := 0.0


func _ready() -> void:
	add_to_group("wood_logs")
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_sound_cooldown = maxf(_sound_cooldown - delta, 0.0)


func _on_body_entered(_body: Node) -> void:
	if _sound_cooldown > 0.0 or drop_sounds.is_empty():
		return
	if linear_velocity.length() < IMPACT_SOUND_MIN_SPEED:
		return
	_sound_cooldown = 0.25
	_audio.stream = drop_sounds.pick_random()
	_audio.pitch_scale = randf_range(1.05, 1.3)
	_audio.volume_db = linear_to_db(clampf(linear_velocity.length() / 5.0, 0.3, 1.0))
	_audio.play()
