class_name Unit
extends CharacterBody3D
## Unité de combat autonome : squelette ennemi ou grunt du camp. Elle choisit une cible, marche
## vers elle (en contournant les obstacles au jugé), frappe au corps à corps et meurt.
## Les valeurs (vie, vitesse, dégâts…) viennent de `GameConfig.UNITS[kind]`.
## Cibles : tout nœud qui a `is_targetable()`, `get_target_radius()` et `take_damage()`.

signal died(unit: Unit)

enum Team { ORCS, UNDEAD }

@export var kind := "skeleton_minion"
@export var team := Team.UNDEAD
@export var model_scene: PackedScene
@export var weapon_scene: PackedScene
## Os qui porte l'arme, et placement de l'arme dans son repère.
@export var weapon_bone := "handslot.r"
@export var weapon_transform := Transform3D.IDENTITY
## true = oreilles pointues et défenses d'orc sur la tête du modèle.
@export var orc_head := false
@export var anim_idle := "Idle"
@export var anim_run := "Running_A"
@export var anim_attack := "1H_Melee_Attack_Chop"
## Vide = pas d'animation de mort : l'unité bascule en arrière.
@export var anim_death := "Death_A"
## Instant du coup dans l'animation d'attaque (s).
@export var attack_hit_delay := 0.45
@export var hit_sounds: Array[AudioStream] = []

var health := 1.0
var max_health := 1.0
## Point de ralliement d'un grunt sans adversaire (position de départ par défaut).
var rally_point := Vector3.ZERO

var _config: Dictionary
var _target: Node3D
var _retarget_timer := 0.0
## Temps écoulé dans l'attaque en cours (-1 = pas d'attaque).
var _attack_time := -1.0
var _attack_landed := false
var _dead := false
var _knockback := Vector3.ZERO
var _stuck_time := 0.0
var _sidestep_time := 0.0
var _sidestep_sign := 1.0
var _model: Node3D
var _animation: AnimationPlayer
var _bar: WorldBar

@onready var _audio: AudioStreamPlayer3D = $Audio


func _ready() -> void:
	_config = GameConfig.UNITS[kind]
	max_health = _config["health"]
	health = max_health
	rally_point = global_position
	add_to_group("units")
	add_to_group("orc_units" if team == Team.ORCS else "undead_units")
	# Les modèles glTF regardent vers +Z ; l'unité avance vers -Z.
	_model = model_scene.instantiate()
	_model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * float(_config["scale"])), Vector3.ZERO)
	add_child(_model)
	_animation = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for looping: String in [anim_idle, anim_run]:
		_animation.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
	var skeleton := _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if weapon_scene:
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name = weapon_bone
		var weapon: Node3D = weapon_scene.instantiate()
		weapon.transform = weapon_transform
		attachment.add_child(weapon)
	if orc_head:
		OrcHeadParts.attach(skeleton)
	_bar = WorldBar.new(Vector2(0.9, 0.09))
	_bar.position = Vector3(0.0, 2.05 * float(_config["scale"]), 0.0)
	_bar.visible = false
	add_child(_bar)
	_play(anim_idle)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not _is_valid(_target):
		_retarget_timer = 0.4
		_target = _pick_target()

	var goal := rally_point
	var reach := 1.2
	if _target:
		goal = _target.global_position
		reach = float(_config["attack_range"]) + float(_target.call("get_target_radius"))
	var to_goal := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var in_reach := to_goal.length() <= reach

	var move := Vector3.ZERO
	if _attack_time >= 0.0:
		_update_attack(delta, in_reach)
	elif _target and in_reach:
		_face(to_goal, 1.0)
		_attack_time = 0.0
		_attack_landed = false
		_animation.stop()
		_play(anim_attack)
	elif not in_reach and (_target or team == Team.ORCS):
		move = _steer(to_goal.normalized(), delta)
		_face(move, delta * 8.0)
		_play(anim_run)
	else:
		_play(anim_idle)

	var speed: float = _config["speed"]
	velocity.x = move.x * speed + _knockback.x
	velocity.z = move.z * speed + _knockback.z
	velocity.y = velocity.y + get_gravity().y * delta if not is_on_floor() else 0.0
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 12.0)
	move_and_slide()
	if move != Vector3.ZERO and Vector2(get_real_velocity().x, get_real_velocity().z).length() < speed * 0.25:
		_stuck_time += delta
		if _stuck_time > 0.5:
			# Bloquée par un obstacle : on le longe un moment, d'un côté tiré au hasard.
			_stuck_time = 0.0
			_sidestep_time = 1.1
			_sidestep_sign = 1.0 if randf() < 0.5 else -1.0
	else:
		_stuck_time = 0.0


# --- Combat --------------------------------------------------------------------------------

## Coup de hache du joueur (même signature que les arbres). Les grunts du camp ne sont pas blessés.
func take_hit(damage: float, _hit_position: Vector3, _hit_normal: Vector3, from_position: Vector3,
		_swing_direction: Vector3 = Vector3.ZERO) -> void:
	if team == Team.UNDEAD:
		take_damage(damage, from_position)


## Dégâts venant de `from` (position de l'attaquant, pour le recul).
func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_bar.visible = true
	_bar.set_ratio(health / max_health)
	if from != Vector3.INF:
		var away := Vector3(global_position.x - from.x, 0.0, global_position.z - from.z)
		_knockback = away.normalized() * GameConfig.UNIT_KNOCKBACK
	if not hit_sounds.is_empty():
		_audio.stream = hit_sounds.pick_random()
		_audio.pitch_scale = randf_range(1.1, 1.4)
		_audio.play()
	if health <= 0.0:
		_die()


func is_targetable() -> bool:
	return not _dead


func get_target_radius() -> float:
	return 0.4


func is_dead() -> bool:
	return _dead


func _update_attack(delta: float, in_reach: bool) -> void:
	_attack_time += delta
	if not _attack_landed and _attack_time >= attack_hit_delay:
		_attack_landed = true
		if _is_valid(_target) and in_reach:
			var damage: float = _config["building_damage"] if _target is CampBuilding else _config["damage"]
			if _target is Unit:
				(_target as Unit).take_damage(damage, global_position)
			else:
				_target.call("take_damage", damage)
	if _attack_time >= float(_config["attack_interval"]):
		_attack_time = -1.0


func _die() -> void:
	_dead = true
	remove_from_group("orc_units")
	remove_from_group("undead_units")
	collision_layer = 0
	collision_mask = 0
	_bar.visible = false
	if anim_death != "":
		_animation.stop()
		_play(anim_death)
	else:
		_animation.pause()
		var fall := create_tween()
		fall.tween_property(_model, "rotation:x", PI * 0.5, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	died.emit(self)
	var sink := create_tween()
	sink.tween_interval(GameConfig.UNIT_CORPSE_TIME)
	sink.tween_property(self, "position:y", position.y - 1.5, 1.2)
	sink.tween_callback(queue_free)


# --- Choix de la cible ---------------------------------------------------------------------

func _is_valid(target: Node3D) -> bool:
	return target != null and is_instance_valid(target) and bool(target.call("is_targetable"))


## Squelettes : un adversaire vivant proche (joueur, grunt), sinon le bâtiment le plus proche.
## Grunts : le squelette le plus proche à portée de vue.
func _pick_target() -> Node3D:
	var aggro: float = _config["aggro"]
	if team == Team.ORCS:
		return _nearest(get_tree().get_nodes_in_group("undead_units"), aggro)
	var living := get_tree().get_nodes_in_group("orc_units") + get_tree().get_nodes_in_group("player")
	var target := _nearest(living, aggro)
	return target if target else _nearest(get_tree().get_nodes_in_group("camp_buildings"), INF)


func _nearest(candidates: Array[Node], max_distance: float) -> Node3D:
	var best: Node3D = null
	var best_distance := max_distance
	for node in candidates:
		var candidate := node as Node3D
		if not _is_valid(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position) - float(candidate.call("get_target_radius"))
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


# --- Déplacement et animation --------------------------------------------------------------

func _steer(direction: Vector3, delta: float) -> Vector3:
	if _sidestep_time > 0.0:
		_sidestep_time -= delta
		return direction.rotated(Vector3.UP, _sidestep_sign * deg_to_rad(75.0))
	return direction


func _face(direction: Vector3, weight: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(weight, 0.0, 1.0))


func _play(animation: String) -> void:
	if _animation.current_animation != animation:
		_animation.play(animation, 0.15)
