class_name Unit
extends CharacterBody3D
## Unité d'un camp (§10.3) : péon du Général, soldat, lanceur de sorts, volant, engin de siège ou héros.
## Statistiques dans `GameConfig.UNITS[kind]`, apparence dans `GameConfig.UNIT_VISUALS[team][kind]`.
## Créer une unité avec `Unit.create(kind, team)`.
##  - Les soldats obéissent au Général : GUARD (tenir un point) ou ASSAULT (marcher sur un point en
##    attaquant ce qu'ils croisent). Les longs trajets suivent le `NavGraph` de la carte.
##  - Les péons (`worker`) récoltent, construisent, et se battent quand le Général sonne l'appel aux armes.
##  - Cibles : tout nœud qui a `is_targetable()`, `get_target_radius()`, `is_flying()` et `take_damage()`.

signal died(unit: Unit, killer: Node)

enum Mode { GUARD, ASSAULT }

const SCENE_PATH := "res://scenes/units/unit.tscn"
const HIT_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/axe/axe_impact_1.ogg"), preload("res://assets/sounds/axe/axe_impact_2.ogg")]
## Portée à partir de laquelle une attaque est un tir (trait lumineux, peut toucher les volants).
const RANGED_FROM := 5.0

static var _tint_cache: Dictionary = {}

@export var kind := "bruiser"
## Camp : 0 = joueur, 1 = ennemi.
@export var team := 0

var health := 1.0
var max_health := 1.0
var mode := Mode.GUARD
## Point à tenir (GUARD) ou à attaquer (ASSAULT).
var command_point := Vector3.ZERO
## Cible imposée, même alliée : le traître que le Général fait exécuter (§6.5).
var hunt_target: Node3D
## Héros : niveau et ennemis tués.
var level := 1
var kills := 0
## Désarmée par le joueur : ses dégâts sont divisés par deux.
var disarmed := false

# --- Péon du Général ---
## Tâche : "idle", "gold", "wood" ou "build".
var job := "idle"
var work_point := Vector3.ZERO
var dropoff_point := Vector3.ZERO
var site: CampBuilding
## Multiplicateur des récoltes (difficulté du Général).
var income_scale := 1.0
var _work_phase := 0
var _work_timer := 0.0
var _militia_time := 0.0

var _config: Dictionary
var _visuals: Dictionary
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
var _path := PackedVector3Array()
var _path_goal := Vector3.INF
var _model: Node3D
var _weapon: Node3D
var _animation: AnimationPlayer
var _bar: WorldBar
var _name_label: Label3D

@onready var _audio: AudioStreamPlayer3D = $Audio


## Crée une unité prête à être ajoutée à la scène.
static func create(unit_kind: String, unit_team: int) -> Unit:
	var unit: Unit = (load(SCENE_PATH) as PackedScene).instantiate()
	unit.kind = unit_kind
	unit.team = unit_team
	return unit


func _ready() -> void:
	_config = GameConfig.UNITS[kind]
	_visuals = GameConfig.UNIT_VISUALS[team][kind]
	max_health = _config["health"]
	health = max_health
	command_point = global_position
	add_to_group("units")
	add_to_group("units_%d" % team)
	add_to_group(("workers_%d" if is_worker() else "army_%d") % team)
	if is_hero():
		add_to_group("heroes_%d" % team)
	var scale_factor: float = _visuals["scale"]
	# Les modèles glTF regardent vers +Z ; l'unité avance vers -Z.
	_model = (load(_visuals["model"]) as PackedScene).instantiate()
	_model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * scale_factor), Vector3.ZERO)
	add_child(_model)
	_animation = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var anims: Array = _visuals["anims"]
	for looping: String in [anims[0], anims[1]]:
		_animation.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
	var skeleton := _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var is_orc := String(_visuals["model"]) == GameConfig.ORC_MODEL
	if String(_visuals["weapon"]) != "":
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name = "hand_r" if is_orc else "handslot.r"
		_weapon = (load(_visuals["weapon"]) as PackedScene).instantiate()
		if is_orc:
			_weapon.transform = FirstPersonBody.AXE_IN_HAND
		attachment.add_child(_weapon)
	if is_orc:
		OrcHeadParts.attach(skeleton)
	_apply_tint(_visuals["tint"])
	if is_flying():
		_model.position.y = GameConfig.FLY_HEIGHT
		collision_mask = 1
	var top := 2.05 * scale_factor * (1.0 if is_orc else 1.0) + (GameConfig.FLY_HEIGHT if is_flying() else 0.0)
	_bar = WorldBar.new(Vector2(0.9, 0.09))
	_bar.position = Vector3(0.0, top, 0.0)
	_bar.visible = false
	add_child(_bar)
	if is_hero():
		_name_label = Label3D.new()
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.pixel_size = 0.008
		_name_label.font_size = 48
		_name_label.outline_size = 12
		_name_label.modulate = Color(1.0, 0.85, 0.4) if team == 0 else Color(0.7, 0.8, 1.0)
		_name_label.position = Vector3(0.0, top + 0.35, 0.0)
		add_child(_name_label)
		_refresh_hero_label()
	_play(anims[0])


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_militia_time = maxf(_militia_time - delta, 0.0)
	var move := Vector3.ZERO
	if is_worker() and _militia_time <= 0.0 and hunt_target == null:
		move = _update_worker(delta)
	else:
		move = _update_fighter(delta)

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


# --- Ordres -----------------------------------------------------------------------------------

## Ordre du Général : tenir `point` (GUARD) ou marcher dessus en attaquant (ASSAULT).
func set_command(new_mode: Mode, point: Vector3) -> void:
	mode = new_mode
	command_point = point


## Tâche d'un péon du Général.
func assign(new_job: String, point: Vector3 = Vector3.ZERO, building: CampBuilding = null) -> void:
	if job == new_job and work_point.distance_to(point) < 1.0 and site == building:
		return
	job = new_job
	work_point = point
	site = building
	_work_phase = 0
	_work_timer = 0.0


## Appel aux armes (§10.6) : le péon devient milicien pour un temps.
func call_to_arms() -> void:
	_militia_time = GameConfig.MILITIA_DURATION


func is_militia() -> bool:
	return _militia_time > 0.0


# --- Combat --------------------------------------------------------------------------------

func _update_fighter(delta: float) -> Vector3:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not _is_valid(_target):
		_retarget_timer = 0.4
		_target = _pick_target()
	var anims: Array = _visuals["anims"]
	var goal := command_point
	var reach := 2.5
	if _target:
		goal = _target.global_position
		reach = float(_config["attack_range"]) + float(_target.call("get_target_radius"))
	var to_goal := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var in_reach := to_goal.length() <= reach
	if _attack_time >= 0.0:
		_update_attack(delta, in_reach)
	elif _target and in_reach:
		_face(to_goal, 1.0)
		_attack_time = 0.0
		_attack_landed = false
		_animation.stop()
		_play(anims[2])
	elif not in_reach:
		var move := _steer(_direction_to(goal), delta)
		_face(move, delta * 8.0)
		_play(anims[1])
		return move
	else:
		_play(anims[0])
	return Vector3.ZERO


## Coup d'outil du joueur (même signature que les arbres). Ses alliés ne sont pas blessés, sauf
## ceux que le Général a envoyés l'exécuter.
func take_hit(damage: float, _hit_position: Vector3, _hit_normal: Vector3, from_position: Vector3,
		_swing_direction: Vector3 = Vector3.ZERO) -> void:
	if team != 0 or hunt_target != null:
		take_damage(damage, from_position, get_tree().get_first_node_in_group("player"))


## Dégâts venant de `from` (position de l'attaquant, pour le recul), infligés par `attacker`.
func take_damage(amount: float, from: Vector3 = Vector3.INF, attacker: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	var camp := CampEconomy.of(team)
	if camp:
		amount *= 1.0 - GameConfig.FORGE_ARMOR_BONUS * camp.armor_level
	if is_militia():
		amount *= 1.0 - GameConfig.MILITIA_ARMOR
	health = maxf(health - amount, 0.0)
	_bar.visible = true
	_bar.set_ratio(health / max_health)
	if from != Vector3.INF:
		var away := Vector3(global_position.x - from.x, 0.0, global_position.z - from.z)
		_knockback = away.normalized() * GameConfig.UNIT_KNOCKBACK
	if not _audio.playing:
		_audio.stream = HIT_SOUNDS.pick_random()
		_audio.pitch_scale = randf_range(1.1, 1.4)
		_audio.play()
	if health <= 0.0:
		_die(attacker)


func heal(amount: float) -> void:
	if _dead:
		return
	health = minf(health + amount, max_health)
	_bar.set_ratio(health / max_health)
	_bar.visible = health < max_health


func is_targetable() -> bool:
	return not _dead


func get_target_radius() -> float:
	return 0.4


func is_dead() -> bool:
	return _dead


func is_worker() -> bool:
	return String(_config["type"]) == "worker"


func is_hero() -> bool:
	return String(_config["type"]) == "hero"


func is_flying() -> bool:
	return bool(_config.get("flying", false))


func unit_type() -> String:
	return _config["type"]


func display_name() -> String:
	return _config["name"]


func food() -> int:
	return _config["food"]


## Point visé par les tireurs.
func get_aim_point() -> Vector3:
	return global_position + Vector3(0.0, 1.0 + (GameConfig.FLY_HEIGHT if is_flying() else 0.0), 0.0)


## Le joueur lui arrache son arme (talent Désarmer).
func disarm() -> void:
	disarmed = true
	if _weapon:
		_weapon.visible = false


## Héros : un ennemi tué de plus, et peut-être un niveau.
func add_kill() -> void:
	kills += 1
	if not is_hero() or level >= GameConfig.HERO_MAX_LEVEL or kills < level * GameConfig.HERO_XP_PER_LEVEL:
		return
	level += 1
	var ratio := health / max_health
	max_health = float(_config["health"]) * (1.0 + GameConfig.HERO_LEVEL_BONUS * (level - 1))
	health = max_health * minf(ratio + 0.25, 1.0)
	_refresh_hero_label()


func _refresh_hero_label() -> void:
	_name_label.text = "%s — niv. %d" % [_config["name"], level]


func _update_attack(delta: float, in_reach: bool) -> void:
	_attack_time += delta
	if not _attack_landed and _attack_time >= float(_visuals["hit"]):
		_attack_landed = true
		if _is_valid(_target) and in_reach:
			_strike(_target)
	if _attack_time >= float(_config["attack_interval"]):
		_attack_time = -1.0


func _strike(target: Node3D) -> void:
	var ranged := float(_config["attack_range"]) >= RANGED_FROM
	var from := get_aim_point() + Vector3(0.0, 0.3, 0.0)
	var aim: Vector3 = target.call("get_aim_point") if target.has_method("get_aim_point") else target.global_position + Vector3(0.0, 1.2, 0.0)
	if _config.has("heal") and target is Unit and (target as Unit).team == team and hunt_target == null:
		(target as Unit).heal(float(_config["heal"]))
		Tracer.spawn(get_parent(), from, aim, Color(0.4, 1.0, 0.5), 0.08)
		return
	var damage: float = _config["damage"]
	if is_hero():
		damage *= 1.0 + GameConfig.HERO_LEVEL_BONUS * (level - 1)
	var camp := CampEconomy.of(team)
	if camp:
		damage *= 1.0 + GameConfig.FORGE_DAMAGE_BONUS * camp.weapon_level
	if is_militia():
		damage *= GameConfig.MILITIA_DAMAGE_BONUS
	if disarmed:
		damage *= 0.5
	if ranged:
		var caster := unit_type() == "caster" or kind == "storm_shaman"
		Tracer.spawn(get_parent(), from, aim, Color(0.6, 0.8, 1.0) if caster else Color(1.0, 0.9, 0.55), 0.09 if caster else 0.05)
	if target is Unit:
		var other := target as Unit
		var bonus: Dictionary = GameConfig.TYPE_BONUS[unit_type()]
		other.take_damage(damage * float(bonus.get(other.unit_type(), 1.0)), global_position, self)
	elif target is CampBuilding:
		(target as CampBuilding).take_damage(damage * float(_config.get("building_bonus", 1.0)), global_position)
	else:
		target.call("take_damage", damage)


func _die(killer: Node) -> void:
	_dead = true
	for group in get_groups():
		remove_from_group(group)
	collision_layer = 0
	collision_mask = 0
	_bar.visible = false
	var anims: Array = _visuals["anims"]
	if String(anims[3]) != "":
		_animation.stop()
		_play(anims[3])
	else:
		_animation.pause()
		var fall := create_tween()
		fall.tween_property(_model, "rotation:x", PI * 0.5, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if is_flying():
		create_tween().tween_property(_model, "position:y", 0.0, 0.5)
	if killer is Unit:
		(killer as Unit).add_kill()
	# Les soldats ennemis lâchent parfois leur arme.
	if team != 0 and _weapon and not disarmed and randf() < GameConfig.WEAPON_DROP_CHANCE:
		var pickup := WeaponPickup.new()
		pickup.weapon_scene = load(_visuals["weapon"])
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector3(0.0, 0.6, 0.0)
	died.emit(self, killer)
	var sink := create_tween()
	sink.tween_interval(GameConfig.UNIT_CORPSE_TIME)
	sink.tween_property(self, "position:y", position.y - 1.5, 1.2)
	sink.tween_callback(queue_free)


# --- Choix de la cible ---------------------------------------------------------------------

func _is_valid(target: Node3D) -> bool:
	return target != null and is_instance_valid(target) and bool(target.call("is_targetable"))


## Un volant ne se touche qu'au tir, ou depuis les airs.
func _can_reach(target: Node3D) -> bool:
	return not bool(target.call("is_flying")) or is_flying() or float(_config["attack_range"]) >= RANGED_FROM


func _pick_target() -> Node3D:
	if hunt_target != null:
		return hunt_target if _is_valid(hunt_target) else null
	var aggro: float = maxf(float(_config["aggro"]), 12.0 if is_worker() else 0.0)
	if _config.has("heal"):
		var wounded := _most_wounded_ally(aggro)
		if wounded:
			return wounded
	var enemy := 1 - team
	var living: Array[Node] = get_tree().get_nodes_in_group("units_%d" % enemy)
	if enemy == 0:
		living += get_tree().get_nodes_in_group("player")
	var target := _nearest(living, aggro)
	if target:
		return target
	var structures: Array[Node] = get_tree().get_nodes_in_group("buildings_%d" % enemy)
	if enemy == 0:
		structures += get_tree().get_nodes_in_group("barricades")
	target = _nearest(structures, aggro)
	# À l'assaut, arrivée sur l'objectif : s'en prendre aux bâtiments, même loin.
	if target == null and mode == Mode.ASSAULT and global_position.distance_to(command_point) < 45.0:
		target = _nearest(get_tree().get_nodes_in_group("buildings_%d" % enemy), 90.0)
	return target


func _nearest(candidates: Array[Node], max_distance: float) -> Node3D:
	var best: Node3D = null
	var best_distance := max_distance
	for node in candidates:
		var candidate := node as Node3D
		if not _is_valid(candidate) or not _can_reach(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position) - float(candidate.call("get_target_radius"))
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _most_wounded_ally(max_distance: float) -> Unit:
	var best: Unit = null
	var best_ratio := 0.9
	for node in get_tree().get_nodes_in_group("units_%d" % team):
		var ally := node as Unit
		if ally == self or global_position.distance_to(ally.global_position) > max_distance:
			continue
		var ratio := ally.health / ally.max_health
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best


# --- Péon du Général : récolte et construction ------------------------------------------------

func _update_worker(delta: float) -> Vector3:
	var anims: Array = _visuals["anims"]
	match job:
		"gold", "wood":
			if _work_phase == 0:
				if _arrived(work_point, 2.5):
					_work_phase = 1
					_work_timer = GameConfig.PEON_WORK_TIME
				else:
					return _walk_to(work_point, delta)
			elif _work_phase == 1:
				_play(anims[2])
				_work_timer -= delta
				if _work_timer <= 0.0:
					_work_phase = 2
			elif _arrived(dropoff_point, 3.0):
				var camp := CampEconomy.of(team)
				if camp and job == "gold":
					camp.add_gold(roundi(GameConfig.PEON_TRIP_GOLD * income_scale))
				elif camp:
					camp.add_wood(roundi(GameConfig.PEON_TRIP_WOOD * income_scale))
				_work_phase = 0
			else:
				return _walk_to(dropoff_point, delta)
		"build":
			if site == null or not is_instance_valid(site) or site.state != CampBuilding.State.UNDER_CONSTRUCTION:
				job = "idle"
			elif _arrived(site.global_position, site.get_target_radius() + GameConfig.BUILD_RANGE - 0.8):
				_face(site.global_position - global_position, delta * 8.0)
				_play(anims[2])
				site.work(delta * GameConfig.PEON_BUILD_RATE)
			else:
				return _walk_to(site.global_position, delta)
		_:
			if _arrived(command_point, 4.0):
				_play(anims[0])
			else:
				return _walk_to(command_point, delta)
	return Vector3.ZERO


func _arrived(point: Vector3, reach: float) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= reach


func _walk_to(point: Vector3, delta: float) -> Vector3:
	var anims: Array = _visuals["anims"]
	var move := _steer(_direction_to(point), delta)
	_face(move, delta * 8.0)
	_play(anims[1])
	return move


# --- Déplacement et animation --------------------------------------------------------------

## Direction à suivre pour rejoindre `goal`, par le graphe de chemins si c'est loin.
func _direction_to(goal: Vector3) -> Vector3:
	if _path_goal.distance_to(goal) > 4.0 or _path.is_empty():
		_path_goal = goal
		_path = NavGraph.find_path(global_position, goal)
	while _path.size() > 1 and _arrived(_path[0], 3.5):
		_path.remove_at(0)
	var next := _path[0] if _path.size() > 1 else goal
	return Vector3(next.x - global_position.x, 0.0, next.z - global_position.z).normalized()


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
	if _animation.current_animation != animation or not _animation.is_playing():
		_animation.play(animation, 0.15)


## Teinte le modèle (différencie les unités qui partagent un modèle).
func _apply_tint(tint: Color) -> void:
	if tint == Color(1, 1, 1):
		return
	for mesh_instance: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			# Un matériau teinté par (matériau d'origine, teinte), partagé par toutes les unités et
			# gardé en cache : moins de matériaux, et aucun libéré pendant qu'un cadavre l'utilise encore.
			var key := "%d|%s" % [source.get_instance_id(), tint.to_html()]
			if not _tint_cache.has(key):
				var material := source.duplicate() as BaseMaterial3D
				material.albedo_color = Color(source.albedo_color.r * tint.r, source.albedo_color.g * tint.g, source.albedo_color.b * tint.b)
				_tint_cache[key] = material
			mesh_instance.set_surface_override_material(surface, _tint_cache[key])
