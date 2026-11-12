class_name Player
extends CharacterBody3D
## Travailleur orc en vue FPS (§4 du cahier des charges) : déplacement, sprint avec endurance, saut,
## roulade, coup d'outil, vie et mort. Le portage et les actions avec E sont dans `LogCarrier`.
## Ses statistiques combinent les valeurs de base (`GameConfig`), les talents de la partie
## (`progress`, remis à zéro à la mort) et les améliorations permanentes (`MetaProgress`).

signal stamina_changed(value: float, max_value: float)
signal health_changed(value: float, max_value: float)
## Le joueur vient d'être touché.
signal hurt
signal died
signal respawned

const PITCH_LIMIT := deg_to_rad(85.0)
const FOOTSTEP_DISTANCE := 1.6

## Rondins portés sur l'épaule (tenu à jour par LogCarrier) : ralentit le joueur.
var carried_logs := 0
var stamina := GameConfig.MAX_STAMINA
var health := GameConfig.PLAYER_MAX_HEALTH

## Talents et niveau de la partie en cours.
var progress: WorkerProgress
## true = la réapparition est décidée par le `GameDirector` (nouveau péon entraîné par le Général).
var managed_respawn := false
## Coups restants de l'arme ramassée (0 = outil habituel).
var picked_weapon_hits := 0

var _dead := false
var _militia_time := 0.0
var _adrenaline_time := 0.0
var _dodge_time := 0.0
var _dodge_cooldown := 0.0
var _dodge_direction := Vector3.ZERO
var _barricade_cooldown := 0.0
var _respawn_timer := 0.0
var _regen_delay := 0.0
## Point de réapparition (position de départ).
var _spawn_transform := Transform3D.IDENTITY

var _pitch := 0.0
var _sprinting := false
var _stamina_regen_delay := 0.0
var _footstep_accumulator := 0.0
var _was_on_floor := true

@onready var head: Node3D = $Head
@onready var camera: CameraShake = $Head/Camera3D
@onready var body: FirstPersonBody = $Body
@onready var axe: AxeController = $Head/Camera3D/AxeRig
@onready var carrier: LogCarrier = $LogCarrier
@onready var _footsteps: AudioStreamPlayer3D = $FootstepAudio
@onready var _axe_audio: AudioStreamPlayer3D = $AxeAudio

@export var footstep_sounds: Array[AudioStream] = []
@export var chop_sound: AudioStream


func _ready() -> void:
	add_to_group("player")
	progress = WorkerProgress.new()
	progress.name = "Progress"
	add_child(progress)
	health = max_health()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	axe.hit_landed.connect(_on_axe_hit)
	_spawn_transform = global_transform


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := GameConfig.MOUSE_SENSITIVITY * (MetaProgress.instance.mouse_sensitivity if MetaProgress.instance else 1.0)
		rotate_y(-event.relative.x * sensitivity)
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("ui_release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_update_health(delta)
	_update_timers(delta)
	# Regard à la manette (stick droit).
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		rotate_y(-look.x * GameConfig.GAMEPAD_LOOK_SPEED * delta)
		_pitch = clampf(_pitch - look.y * GameConfig.GAMEPAD_LOOK_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)
	axe.speed_scale = swing_speed()
	axe.damage = tool_damage()
	if Input.is_action_just_pressed("barricade") and not _dead:
		_place_barricade()
	if Input.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _dead:
		axe.request_swing()

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _dead:
		input = Vector2.ZERO
	carried_logs = carrier.count
	head.rotation.x = _pitch
	var wish := (global_basis * Vector3(input.x, 0.0, input.y))
	wish.y = 0.0
	wish = wish.normalized() * minf(input.length(), 1.0)

	_update_stamina(delta, input)
	var target_speed := (GameConfig.SPRINT_SPEED if _sprinting else GameConfig.WALK_SPEED) * get_carry_speed_multiplier() * move_multiplier()
	if Input.is_action_just_pressed("dodge") and not _dead:
		_try_dodge(wish)
	if _dodge_time > 0.0:
		wish = _dodge_direction
		target_speed = GameConfig.DODGE_DISTANCE / GameConfig.DODGE_TIME

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump") and not _dead:
		velocity.y = GameConfig.JUMP_VELOCITY * (1.0 + 0.12 * MetaProgress.level_of("jump_height"))

	var acceleration := GameConfig.GROUND_ACCELERATION if is_on_floor() else GameConfig.AIR_ACCELERATION
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * target_speed, acceleration * target_speed * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_update_body(delta)
	_update_footsteps(delta)


# --- Vie -----------------------------------------------------------------------------------

## Dégâts infligés par un ennemi (ignorés pendant une roulade).
func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0 or _dodge_time > 0.0:
		return
	amount *= 1.0 - 0.08 * progress.rank("tough")
	if _militia_time > 0.0:
		amount *= 1.0 - GameConfig.MILITIA_ARMOR
	health = maxf(health - amount, 0.0)
	_regen_delay = GameConfig.PLAYER_REGEN_DELAY
	_adrenaline_time = GameConfig.ADRENALINE_TIME
	camera.add_trauma(GameConfig.SHAKE_PLAYER_HURT)
	health_changed.emit(health, max_health())
	hurt.emit()
	if health <= 0.0:
		_die()


func is_dead() -> bool:
	return _dead


## Cible valable pour les ennemis tant qu'il est vivant.
func is_targetable() -> bool:
	return not _dead


func get_target_radius() -> float:
	return 0.4


func is_flying() -> bool:
	return false


# --- Statistiques (base + talents + améliorations permanentes) ---------------------------------

func max_health() -> float:
	return GameConfig.PLAYER_MAX_HEALTH + 15.0 * progress.rank("thick_skin") + 10.0 * MetaProgress.level_of("increased_hp")


func wood_capacity() -> int:
	return GameConfig.BASE_WOOD_CAPACITY + 5 * progress.rank("strong_back") + 10 * progress.rank("titan_hauler") \
		+ 2 * MetaProgress.level_of("carry_capacity")


func gold_capacity() -> int:
	return GameConfig.BASE_GOLD_CAPACITY + 5 * progress.rank("deep_pockets") + 10 * progress.rank("titan_hauler") \
		+ 2 * MetaProgress.level_of("carry_capacity")


## Vitesse des coups d'outil : hache dehors, pioche dans la mine.
func swing_speed() -> float:
	var tool := "faster_pickaxe" if carrier.is_in_mine() else "faster_axe"
	return 1.0 + 0.1 * progress.rank("efficient_swings") + 0.08 * MetaProgress.level_of(tool)


func tool_damage() -> float:
	var damage := GameConfig.AXE_DAMAGE * (1.0 + 0.15 * progress.rank("power_swing") + 0.12 * MetaProgress.level_of("sharpened_axe"))
	if picked_weapon_hits > 0:
		damage *= GameConfig.PICKED_WEAPON_MASTERY if progress.rank("weapon_mastery") > 0 else GameConfig.PICKED_WEAPON_DAMAGE
	if _militia_time > 0.0:
		damage *= GameConfig.MILITIA_DAMAGE_BONUS
	if _in_frenzy():
		damage *= 1.4
	return damage


func move_multiplier() -> float:
	return (1.0 + 0.04 * progress.rank("quick_feet") + 0.03 * MetaProgress.level_of("move_speed")) * (1.15 if _in_frenzy() else 1.0)


func build_speed() -> float:
	return 1.0 + 0.15 * progress.rank("hammer_down") + 0.25 * progress.rank("rapid_assembly")


func repair_speed() -> float:
	return 1.0 + 0.15 * progress.rank("careful_work")


## Frénésie : sous 30 % de vie avec le talent.
func _in_frenzy() -> bool:
	return progress.rank("battle_frenzy") > 0 and health < max_health() * 0.3 and not _dead


## Appel aux armes : le péon devient milicien pour `seconds`.
func set_militia(seconds: float) -> void:
	_militia_time = maxf(_militia_time, seconds)


func is_militia() -> bool:
	return _militia_time > 0.0


func _update_timers(delta: float) -> void:
	_militia_time = maxf(_militia_time - delta, 0.0)
	_adrenaline_time = maxf(_adrenaline_time - delta, 0.0)
	_dodge_time = maxf(_dodge_time - delta, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_barricade_cooldown = maxf(_barricade_cooldown - delta, 0.0)


## Roulade (§4.3) : bond dans la direction du déplacement, invulnérable le temps du bond.
## Débloquée par une amélioration permanente.
func _try_dodge(wish: Vector3) -> void:
	if MetaProgress.level_of("dodge_roll") == 0 or _dodge_cooldown > 0.0 or stamina < GameConfig.DODGE_STAMINA or not is_on_floor():
		return
	_dodge_direction = wish.normalized() if wish.length() > 0.1 else -global_basis.z
	_dodge_time = GameConfig.DODGE_TIME
	_dodge_cooldown = GameConfig.DODGE_COOLDOWN
	stamina -= GameConfig.DODGE_STAMINA
	_stamina_regen_delay = GameConfig.STAMINA_REGEN_DELAY
	camera.add_trauma(0.25)


## Barricade temporaire (talent Fortifier) : un mur de rondins posé devant soi.
func _place_barricade() -> void:
	if progress.rank("fortify") == 0 or _barricade_cooldown > 0.0:
		return
	_barricade_cooldown = GameConfig.BARRICADE_COOLDOWN
	var barricade := Barricade.new()
	get_parent().add_child(barricade)
	var forward := -global_basis.z
	barricade.global_transform = Transform3D(Basis.looking_at(forward), global_position + forward * 2.2)


## Mort (§4.5) : la charge tombe au sol, les talents et le niveau de la partie sont perdus.
## Un nouveau péon est entraîné par le Général (`GameDirector`) ; hors partie, on réapparaît
## simplement au point de départ après un délai.
func _die() -> void:
	_dead = true
	_respawn_timer = GameConfig.PLAYER_RESPAWN_TIME
	picked_weapon_hits = 0
	carrier.drop_on_ground()
	carrier.set_held_weapon(null)
	progress.reset()
	died.emit()


## Réapparition en `at` : un péon tout neuf.
func respawn(at: Transform3D) -> void:
	_dead = false
	global_transform = at
	velocity = Vector3.ZERO
	_pitch = 0.0
	health = max_health()
	stamina = GameConfig.MAX_STAMINA
	health_changed.emit(health, max_health())
	respawned.emit()


func _update_health(delta: float) -> void:
	if _dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0 and not managed_respawn:
			respawn(_spawn_transform)
		return
	if _regen_delay > 0.0:
		_regen_delay -= delta
	elif health < max_health():
		health = minf(health + GameConfig.PLAYER_REGEN * (1.0 + 0.3 * MetaProgress.level_of("regeneration")) * delta, max_health())
		health_changed.emit(health, max_health())


## Secondes restantes avant la réapparition (0 si vivant).
func get_respawn_time() -> float:
	return maxf(_respawn_timer, 0.0) if _dead else 0.0


## Pénalité de vitesse proportionnelle à la charge : jusqu'à -35 % à pleine capacité de bois,
## -15 % à sac d'or plein (on ne porte jamais les deux à la fois).
func get_carry_speed_multiplier() -> float:
	var load_ratio := clampf(float(carried_logs) / wood_capacity(), 0.0, 1.0)
	var gold_ratio := clampf(float(carrier.gold) / gold_capacity(), 0.0, 1.0)
	var relief := maxf(1.0 - 0.3 * progress.rank("light_load"), 0.0)
	return 1.0 - (GameConfig.MAX_CARRY_SPEED_PENALTY * load_ratio + GameConfig.MAX_GOLD_CARRY_SPEED_PENALTY * gold_ratio) * relief


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
		var boost := 2.0 if progress.rank("adrenaline") > 0 and _adrenaline_time > 0.0 else 1.0
		stamina = minf(stamina + GameConfig.STAMINA_REGEN * boost * delta, GameConfig.MAX_STAMINA)
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


func _on_axe_hit(collider: Object, _position: Vector3) -> void:
	if collider is GoldVein:
		carrier.mine_vein(collider as GoldVein)
	elif collider is Unit:
		_adrenaline_time = GameConfig.ADRENALINE_TIME
		var foe := collider as Unit
		if progress.rank("disarm") > 0 and not foe.disarmed and randf() < 0.2:
			foe.disarm()
		# L'arme ramassée s'use à chaque coup porté, puis casse.
		if picked_weapon_hits > 0:
			picked_weapon_hits -= 1
			if picked_weapon_hits == 0:
				carrier.set_held_weapon(null)
	camera.add_trauma(GameConfig.SHAKE_AXE_HIT)
	if chop_sound:
		_axe_audio.stream = chop_sound
		_axe_audio.pitch_scale = randf_range(0.9, 1.1)
		_axe_audio.play()
