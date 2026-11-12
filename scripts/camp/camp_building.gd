class_name CampBuilding
extends StaticBody3D
## Bâtiment d'un camp (§10.2 du cahier des charges). Tout vient de `GameConfig.BUILDINGS[kind]` :
## nom, palier requis, vie, coût, nourriture, modèle, rôle (dépôt, tour, production).
## Trois états, chacun avec son modèle : chantier (étapes sous échafaudage), debout, ruines.
## Un bâtiment commandé par le Général apparaît d'abord en FANTÔME vert translucide (`ghost`) :
## on le traverse, les ennemis l'ignorent. Il ne devient tangible qu'au premier coup de marteau.
## Le chantier n'avance que si un péon y travaille (`work()`), sauf `auto_build`. Les points de vie
## montent avec la construction ; un chantier peut être détruit avant d'être fini.
## On dépose le bois et l'or directement dans l'hôtel de ville et les entrepôts (`is_dropoff()`).
## L'hôtel de ville (`war_lodge`) s'améliore en Bastion puis Forteresse (`start_upgrade()`).

signal state_changed(state: State)
signal health_changed(health: float, max_health: float)

enum State { UNDER_CONSTRUCTION, BUILT, DESTROYED }

const DUST_SCENE := preload("res://scenes/vfx/dust_impact_vfx.tscn")
const MODEL_DIR := "res://assets/models/buildings/"
const HIT_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/axe/axe_impact_0.ogg"), preload("res://assets/sounds/axe/axe_impact_3.ogg")]
const COLLAPSE_SOUND := preload("res://assets/sounds/tree/tree_crash.ogg")
const SHOT_SOUND := preload("res://assets/sounds/axe/axe_chop.ogg")
const BAR_SIZE := Vector2(3.6, 0.3)

## Clé du bâtiment dans `GameConfig.BUILDINGS`.
@export var kind := "burrow"
## Camp : 0 = joueur, 1 = ennemi.
@export var team := 0
## false = le bâtiment apparaît en chantier.
@export var starts_built := true
## true = le chantier avance tout seul (tests) ; false = il faut qu'un péon y travaille.
@export var auto_build := false

var building_name := "Bâtiment"
var max_health := 1000.0
var build_time := 20.0
var health := 0.0
var state := State.BUILT
## Avancement de la construction, de 0 à 1.
var build_progress := 1.0
## Chantier pas encore commencé : simple silhouette verte, intangible.
var ghost := false
## Palier (hôtel de ville seulement) et temps restant d'une amélioration en cours.
var tier := 1
var upgrade_time_left := 0.0
## Secondes de travail fournies par le joueur sur ce chantier (ordres, talent Renforcé).
var player_work := 0.0
## Dernier instant où le bâtiment a été frappé (détection d'attaque par le Général).
var last_hit_time := -1000.0

var _config: Dictionary
var _visual: Node3D
var _stage := -1
var _label: Label3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _saw: Node3D
## Demi-largeur de la boîte de collision (pour la portée d'attaque et de construction).
var _radius := 1.0
var _top := Vector3(0.0, 6.0, 0.0)
var _tower_cooldown := 0.0

@onready var _collision: CollisionShape3D = $Collision
@onready var _audio: AudioStreamPlayer3D = $Audio


func _ready() -> void:
	add_to_group("buildings")
	add_to_group("buildings_%d" % team)
	if team == 0:
		add_to_group("camp_buildings")
	if kind == "war_lodge":
		add_to_group("town_hall_%d" % team)
	_config = GameConfig.BUILDINGS[kind]
	building_name = _config["name"]
	max_health = _config["health"]
	build_time = _config["build_time"]
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3.ONE * float(_config["scale"])
	add_child(_visual)
	_collision.shape = BoxShape3D.new()
	_build_overlay()
	# Nom et barre de vie à hauteur fixe, au-dessus du bâtiment fini (même pendant le chantier).
	var built: Node3D = _model("built").instantiate()
	_visual.add_child(built)
	var bounds := _local_bounds(built)
	_label.position = Vector3(bounds.get_center().x, bounds.end.y + 1.5, bounds.get_center().z)
	_bar.position = _label.position - Vector3(0.0, 0.7, 0.0)
	_radius = maxf(bounds.size.x, bounds.size.z) * 0.4
	_visual.remove_child(built)
	built.free()
	if starts_built:
		_complete_construction()
	else:
		begin_construction()


func _process(delta: float) -> void:
	if auto_build:
		work(delta)
	if _saw and state == State.BUILT:
		_saw.rotate_x(GameConfig.LUMBER_MILL_SAW_SPEED * delta)
	if upgrade_time_left > 0.0 and state == State.BUILT:
		upgrade_time_left -= delta
		if upgrade_time_left <= 0.0:
			_finish_upgrade()
		_update_overlay()


func _physics_process(delta: float) -> void:
	if _config.get("tower", false) and state == State.BUILT:
		_update_tower(delta)


# --- Construction -----------------------------------------------------------------------------

## Fait avancer le chantier de `delta` secondes de travail (appelé tant qu'un péon construit).
func work(delta: float) -> void:
	if state != State.UNDER_CONSTRUCTION:
		return
	if ghost:
		_materialize()
	build_progress = minf(build_progress + delta / build_time, 1.0)
	# Les points de vie montent avec le chantier ; les dégâts déjà subis restent.
	_set_health(health + max_health * (1.0 - GameConfig.BUILDING_START_HEALTH_RATIO) * delta / build_time)
	if build_progress >= 1.0:
		_complete_construction()
	else:
		_show_stage()
		_update_overlay()


## Ordre de construction (ou de reconstruction après destruction) : le chantier démarre.
func begin_construction() -> void:
	_set_state(State.UNDER_CONSTRUCTION)
	build_progress = 0.0
	player_work = 0.0
	_stage = -1
	_set_health(max_health * GameConfig.BUILDING_START_HEALTH_RATIO)
	# Silhouette verte du bâtiment fini, sans collision, jusqu'au premier coup de marteau.
	ghost = true
	_show_model([_model("built")])
	_collision.disabled = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3, 1.0, 0.4, 0.32)
	for mesh_instance: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_overlay()
	state_changed.emit(state)


## Premier coup de marteau : le chantier devient tangible (première étape sous échafaudage).
func _materialize() -> void:
	ghost = false
	_collision.disabled = false
	_show_stage()


## Achève le chantier d'un coup (talent Architecte).
func finish_now() -> void:
	if state == State.UNDER_CONSTRUCTION:
		work(build_time)


## Augmente la vie maximale (talent Renforcé du joueur qui a bâti).
func reinforce(ratio: float) -> void:
	max_health *= 1.0 + ratio
	_set_health(health * (1.0 + ratio))
	_update_overlay()


# --- Hôtel de ville : paliers --------------------------------------------------------------------

## Lance l'amélioration au palier suivant (Bastion, puis Forteresse). Renvoie false si impossible.
func start_upgrade() -> bool:
	if kind != "war_lodge" or state != State.BUILT or upgrade_time_left > 0.0 or tier >= GameConfig.TOWN_HALL_TIERS.size():
		return false
	upgrade_time_left = float(GameConfig.TOWN_HALL_TIERS[tier]["time"])
	_update_overlay()
	return true


func _finish_upgrade() -> void:
	upgrade_time_left = 0.0
	var next: Dictionary = GameConfig.TOWN_HALL_TIERS[tier]
	tier += 1
	building_name = next["name"]
	var ratio := health / max_health
	max_health = next["health"]
	_set_health(max_health * ratio)
	_visual.scale = Vector3.ONE * (float(_config["scale"]) + 0.35 * (tier - 1))
	var camp := CampEconomy.of(team)
	if camp:
		camp.tier = tier
	_update_overlay()
	state_changed.emit(state)


## Nourriture fournie.
func food() -> int:
	if kind == "war_lodge":
		return int(GameConfig.TOWN_HALL_TIERS[tier - 1]["food"])
	return int(_config.get("food", 0))


# --- Dégâts et réparation -------------------------------------------------------------------------

## Dégâts infligés par un ennemi. À zéro point de vie, le bâtiment (ou son chantier) s'effondre.
func take_damage(amount: float, _from: Vector3 = Vector3.INF) -> void:
	if state == State.DESTROYED or amount <= 0.0:
		return
	last_hit_time = Time.get_ticks_msec() / 1000.0
	_set_health(health - amount)
	if not _audio.playing:
		_audio.stream = HIT_SOUNDS.pick_random()
		_audio.pitch_scale = randf_range(0.6, 0.75)
		_audio.play()
	if health <= 0.0:
		_collapse()
	else:
		_update_overlay()


## Réparation : rend des points de vie à un bâtiment debout.
func repair(amount: float) -> void:
	if state == State.BUILT and amount > 0.0:
		_set_health(health + amount)
		_update_overlay()


func is_built() -> bool:
	return state == State.BUILT


func is_damaged() -> bool:
	return state == State.BUILT and health < max_health


## Cible valable pour les ennemis : tout bâtiment qui n'est pas en ruines.
func is_targetable() -> bool:
	return state != State.DESTROYED and not ghost


## On peut y déposer bois et or (hôtel de ville, entrepôt), s'il est debout.
func is_dropoff() -> bool:
	return state == State.BUILT and bool(_config.get("dropoff", false))


## Point où entrent les rondins déposés (porte du bâtiment, à mi-hauteur).
func get_deposit_point() -> Vector3:
	return global_position + Vector3(0.0, 1.6, 0.0)


## Distance du centre au bord (les unités s'arrêtent au bord, pas au centre).
func get_target_radius() -> float:
	return _radius


func is_flying() -> bool:
	return false


## Point dégagé devant le bâtiment (sortie des unités, dépôt des péons du Général).
func get_front_point(extra: float = 2.5) -> Vector3:
	return global_position + global_basis.z.normalized() * (_radius + extra)


func _set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)


func _set_state(new_state: State) -> void:
	state = new_state


func _complete_construction() -> void:
	_set_state(State.BUILT)
	ghost = false
	_collision.disabled = false
	build_progress = 1.0
	if starts_built and health <= 0.0:
		_set_health(max_health)
	_show_model([_model("built")])
	_update_overlay()
	state_changed.emit(state)


func _collapse() -> void:
	_set_state(State.DESTROYED)
	upgrade_time_left = 0.0
	_show_model([_model("ruins")])
	_update_overlay()
	var dust: DustImpactVFX = DUST_SCENE.instantiate()
	dust.set_length(4.0)
	dust.scale = Vector3.ONE * 2.0
	add_child(dust)
	_audio.stream = COLLAPSE_SOUND
	_audio.pitch_scale = randf_range(0.8, 0.95)
	_audio.play()
	get_tree().call_group("camera_shake_receivers", "add_trauma_at", global_position,
		GameConfig.SHAKE_BUILDING_COLLAPSE, GameConfig.SHAKE_BUILDING_COLLAPSE_RADIUS)
	state_changed.emit(state)


# --- Tour de guet -----------------------------------------------------------------------------------

## Tire sur l'unité ennemie la plus proche à portée.
func _update_tower(delta: float) -> void:
	_tower_cooldown -= delta
	if _tower_cooldown > 0.0:
		return
	var from := to_global(_top)
	var target: Unit = null
	var best := GameConfig.TOWER_RANGE
	for node in get_tree().get_nodes_in_group("units_%d" % (1 - team)):
		var unit := node as Unit
		var distance := from.distance_to(unit.global_position)
		if distance < best:
			best = distance
			target = unit
	if target == null:
		_tower_cooldown = 0.25
		return
	_tower_cooldown = GameConfig.TOWER_FIRE_INTERVAL
	target.take_damage(GameConfig.TOWER_DAMAGE, global_position)
	Tracer.spawn(get_parent(), from, target.get_aim_point())
	_audio.stream = SHOT_SOUND
	_audio.pitch_scale = randf_range(1.5, 1.8)
	_audio.play()


# --- Modèles ----------------------------------------------------------------------------------------

func _model(what: String) -> PackedScene:
	match what:
		"built":
			return load(MODEL_DIR + "building_%s_%s.gltf" % [_config["model"], GameConfig.TEAM_COLORS[team]])
		"ruins":
			return load(MODEL_DIR + "building_destroyed.gltf")
		"scaffolding":
			return load(MODEL_DIR + "building_scaffolding.gltf")
	return load(MODEL_DIR + "building_stage_%s.gltf" % what)


## Affiche l'étape de chantier qui correspond à l'avancement (sous l'échafaudage).
func _show_stage() -> void:
	var stages := ["A", "B", "C"]
	var stage := mini(int(build_progress * stages.size()), stages.size() - 1)
	if stage != _stage:
		_stage = stage
		_show_model([_model(stages[stage]), _model("scaffolding")])


## Remplace les modèles affichés et ajuste la boîte de collision au premier (le bâtiment lui-même).
func _show_model(models: Array[PackedScene]) -> void:
	for child in _visual.get_children():
		_visual.remove_child(child)
		child.queue_free()
	var bounds := AABB()
	for index in models.size():
		var model: Node3D = models[index].instantiate()
		_visual.add_child(model)
		if index == 0:
			bounds = _local_bounds(model)
	# Boîte un peu plus étroite que le modèle : les débords (toit, bûches au sol) ne bloquent pas.
	var box := _collision.shape as BoxShape3D
	box.size = Vector3(bounds.size.x * 0.8, bounds.size.y, bounds.size.z * 0.8)
	_collision.position = bounds.get_center()
	_top = Vector3(_collision.position.x, box.size.y * 0.85, _collision.position.z)
	var saws := _visual.find_children("*saw*", "Node3D", true, false)
	_saw = saws[0] as Node3D if not saws.is_empty() else null


## Encombrement d'un modèle dans le repère du bâtiment.
func _local_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var to_local := _visual.transform * _relative_transform(mesh_instance)
		var mesh_bounds := to_local * mesh_instance.get_aabb()
		bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
		first = false
	return bounds


## Transform de `node` par rapport à `_visual` (utilisable avant l'entrée dans l'arbre de scène).
func _relative_transform(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != _visual and current is Node3D:
		result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


# --- Nom et barre de vie au-dessus du bâtiment -------------------------------------------------

func _build_overlay() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.011
	_label.font_size = 64
	_label.outline_size = 16
	_label.modulate = Color(1.0, 0.96, 0.86) if team == 0 else Color(0.75, 0.85, 1.0)
	_label.outline_modulate = Color(0.1, 0.07, 0.03)
	add_child(_label)
	_bar = Node3D.new()
	_bar.name = "HealthBar"
	add_child(_bar)
	_bar.add_child(_make_bar_quad(Color(0.08, 0.06, 0.04), BAR_SIZE + Vector2(0.08, 0.08), 0))
	_bar_fill = _make_bar_quad(Color(0.35, 0.8, 0.25), BAR_SIZE, 1)
	_bar.add_child(_bar_fill)


func _make_bar_quad(color: Color, size: Vector2, priority: int) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	material.render_priority = priority
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = quad
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance


func _update_overlay() -> void:
	var ratio := health / max_health
	match state:
		State.UNDER_CONSTRUCTION:
			_label.text = "%s — à construire" % building_name if ghost else "%s — construction %d %%" % [building_name, int(build_progress * 100.0)]
		State.DESTROYED:
			_label.text = "%s (ruines)" % building_name
		_:
			if upgrade_time_left > 0.0:
				_label.text = "%s — amélioration : %d s" % [building_name, ceili(upgrade_time_left)]
			else:
				_label.text = "%s — %d / %d" % [building_name, ceili(health), int(max_health)] if ratio < 1.0 else building_name
	# Barre masquée quand le bâtiment est intact ou en ruines.
	_bar.visible = (state == State.UNDER_CONSTRUCTION and not ghost) or (state == State.BUILT and ratio < 1.0)
	var quad := _bar_fill.mesh as QuadMesh
	quad.size = Vector2(maxf(BAR_SIZE.x * ratio, 0.001), BAR_SIZE.y)
	# La barre se vide vers la gauche : le quad reste calé sur le bord gauche du fond.
	quad.center_offset = Vector3(-(BAR_SIZE.x - quad.size.x) * 0.5, 0.0, 0.0)
	var fill := quad.material as StandardMaterial3D
	fill.albedo_color = Color(0.85, 0.2, 0.15) if ratio < 0.3 else (Color(0.9, 0.7, 0.2) if ratio < 0.6 else Color(0.35, 0.8, 0.25))
