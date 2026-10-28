class_name Player
extends CharacterBody3D
## Travailleur orc en vue FPS : déplacement (ZQSD/WASD), sprint avec endurance, saut, coup de hache.

signal stamina_changed(value: float, max_value: float)

const PITCH_LIMIT := deg_to_rad(85.0)
const FOOTSTEP_DISTANCE := 1.6

## Rondins portés (le portage sur l'épaule arrive à l'étape suivante ; la pénalité est déjà câblée).
var carried_logs := 0
var stamina := GameConfig.MAX_STAMINA

var _pitch := 0.0
var _sprinting := false
var _stamina_regen_delay := 0.0
var _footstep_accumulator := 0.0
var _was_on_floor := true

@onready var head: Node3D = $Head
@onready var camera: CameraShake = $Head/Camera3D
@onready var body: FirstPersonBody = $Body
@onready var axe: AxeController = $Head/Camera3D/AxeRig
@onready var _footsteps: AudioStreamPlayer3D = $FootstepAudio
@onready var _axe_audio: AudioStreamPlayer3D = $AxeAudio

@export var footstep_sounds: Array[AudioStream] = []
@export var chop_sound: AudioStream


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	axe.hit_landed.connect(_on_axe_hit)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * GameConfig.MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - event.relative.y * GameConfig.MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		head.rotation.x = _pitch
	elif event.is_action_pressed("ui_release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		axe.request_swing()

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (global_basis * Vector3(input.x, 0.0, input.y))
	wish.y = 0.0
	wish = wish.normalized() * minf(input.length(), 1.0)

	_update_stamina(delta, input)
	var target_speed := (GameConfig.SPRINT_SPEED if _sprinting else GameConfig.WALK_SPEED) * get_carry_speed_multiplier()

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = GameConfig.JUMP_VELOCITY

	var acceleration := GameConfig.GROUND_ACCELERATION if is_on_floor() else GameConfig.AIR_ACCELERATION
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * target_speed, acceleration * target_speed * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_update_body(delta)
	_update_footsteps(delta)


## Pénalité de vitesse proportionnelle à la charge : jusqu'à -35 % à pleine capacité.
func get_carry_speed_multiplier() -> float:
	var load_ratio := clampf(float(carried_logs) / GameConfig.BASE_WOOD_CAPACITY, 0.0, 1.0)
	return 1.0 - GameConfig.MAX_CARRY_SPEED_PENALTY * load_ratio


func _update_stamina(delta: float, input: Vector2) -> void:
	var wants_sprint := Input.is_action_pressed("sprint") and input.y < -0.1 and is_on_floor()
	if wants_sprint and not _sprinting and stamina >= GameConfig.STAMINA_SPRINT_MIN:
		_sprinting = true
	elif not wants_sprint or stamina <= 0.0:
		_sprinting = false

	if _sprinting:
		stamina = maxf(stamina - GameConfig.STAMINA_SPRINT_DRAIN * delta, 0.0)
		_stamina_regen_delay = GameConfig.STAMINA_REGEN_DELAY
	elif _stamina_regen_delay > 0.0:
		_stamina_regen_delay -= delta
	else:
		stamina = minf(stamina + GameConfig.STAMINA_REGEN * delta, GameConfig.MAX_STAMINA)
	stamina_changed.emit(stamina, GameConfig.MAX_STAMINA)


func _update_body(delta: float) -> void:
	var local_velocity := global_basis.inverse() * velocity
	var horizontal_speed := Vector2(local_velocity.x, local_velocity.z).length()
	var signed_speed := horizontal_speed * (-1.0 if local_velocity.z > 0.5 else 1.0)
	body.look_pitch = _pitch
	body.update_locomotion(signed_speed, is_on_floor(), delta)
	axe.set_walk_bob(clampf(horizontal_speed / GameConfig.SPRINT_SPEED, 0.0, 1.0) if is_on_floor() else 0.0)


func _update_footsteps(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_play_footstep(0.8)
	_was_on_floor = on_floor
	if not on_floor:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.5:
		_footstep_accumulator = FOOTSTEP_DISTANCE * 0.6
		return
	_footstep_accumulator += speed * delta
	var stride := FOOTSTEP_DISTANCE * (1.25 if _sprinting else 1.0)
	if _footstep_accumulator >= stride:
		_footstep_accumulator = 0.0
		_play_footstep(1.0 if _sprinting else 0.75)


func _play_footstep(volume: float) -> void:
	if footstep_sounds.is_empty():
		return
	_footsteps.stream = footstep_sounds.pick_random()
	_footsteps.pitch_scale = randf_range(0.85, 1.05)
	_footsteps.volume_db = linear_to_db(volume)
	_footsteps.play()


func _on_axe_hit(_collider: Object, _position: Vector3) -> void:
	camera.add_trauma(GameConfig.SHAKE_AXE_HIT)
	if chop_sound:
		_axe_audio.stream = chop_sound
		_axe_audio.pitch_scale = randf_range(0.9, 1.1)
		_axe_audio.play()
