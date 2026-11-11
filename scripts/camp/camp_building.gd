class_name CampBuilding
extends StaticBody3D
## Bâtiment du camp : il a des points de vie, se construit (sur ordre du Général) et peut être
## détruit (par les ennemis). Trois états, chacun avec son modèle : chantier (étapes successives
## sous échafaudage), bâtiment debout, ruines. Comme dans Warcraft 3, les points de vie montent
## pendant la construction et un chantier peut être détruit avant d'être fini.
## Les classes filles règlent `max_health` et `build_time` (depuis `GameConfig`) avant `super._ready()`.

signal state_changed(state: State)
signal health_changed(health: float, max_health: float)

enum State { UNDER_CONSTRUCTION, BUILT, DESTROYED }

const DUST_SCENE := preload("res://scenes/vfx/dust_impact_vfx.tscn")
const BAR_SIZE := Vector2(3.6, 0.3)

## Nom affiché au-dessus du bâtiment.
@export var building_name := "Bâtiment"
## false = le bâtiment apparaît en chantier et se construit tout seul.
@export var starts_built := true
@export var built_model: PackedScene
## Modèles du chantier, du début à la fin de la construction.
@export var stage_models: Array[PackedScene] = []
@export var scaffolding_model: PackedScene
@export var ruins_model: PackedScene
@export var hit_sounds: Array[AudioStream] = []
@export var collapse_sound: AudioStream

var max_health := 1000.0
var build_time := 20.0
var health := 0.0
var state := State.BUILT
## Avancement de la construction, de 0 à 1.
var build_progress := 1.0

var _visual: Node3D
var _stage := -1
var _label: Label3D
var _bar: Node3D
var _bar_fill: MeshInstance3D

@onready var _collision: CollisionShape3D = $Collision
@onready var _audio: AudioStreamPlayer3D = $Audio


func _ready() -> void:
	add_to_group("camp_buildings")
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3.ONE * GameConfig.BUILDING_MODEL_SCALE
	add_child(_visual)
	_collision.shape = BoxShape3D.new()
	_build_overlay()
	# Nom et barre de vie à hauteur fixe, au-dessus du bâtiment fini (même pendant le chantier).
	if built_model:
		var built: Node3D = built_model.instantiate()
		_visual.add_child(built)
		var bounds := _local_bounds(built)
		_label.position = Vector3(bounds.get_center().x, bounds.end.y + 1.5, bounds.get_center().z)
		_bar.position = _label.position - Vector3(0.0, 0.7, 0.0)
		_visual.remove_child(built)
		built.free()
	if starts_built:
		_complete_construction()
	else:
		begin_construction()


func _process(delta: float) -> void:
	if state != State.UNDER_CONSTRUCTION:
		return
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
	state = State.UNDER_CONSTRUCTION
	build_progress = 0.0
	_stage = -1
	_set_health(max_health * GameConfig.BUILDING_START_HEALTH_RATIO)
	_show_stage()
	_update_overlay()
	state_changed.emit(state)


## Dégâts infligés par un ennemi. À zéro point de vie, le bâtiment (ou son chantier) s'effondre.
func take_damage(amount: float) -> void:
	if state == State.DESTROYED or amount <= 0.0:
		return
	_set_health(health - amount)
	if not hit_sounds.is_empty():
		_audio.stream = hit_sounds.pick_random()
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


func _set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)


func _complete_construction() -> void:
	state = State.BUILT
	build_progress = 1.0
	if starts_built and health <= 0.0:
		_set_health(max_health)
	_show_model([built_model])
	_update_overlay()
	state_changed.emit(state)


func _collapse() -> void:
	state = State.DESTROYED
	_show_model([ruins_model])
	_update_overlay()
	var dust: DustImpactVFX = DUST_SCENE.instantiate()
	dust.set_length(4.0)
	dust.scale = Vector3.ONE * 2.0
	add_child(dust)
	if collapse_sound:
		_audio.stream = collapse_sound
		_audio.pitch_scale = randf_range(0.8, 0.95)
		_audio.play()
	get_tree().call_group("camera_shake_receivers", "add_trauma_at", global_position,
		GameConfig.SHAKE_BUILDING_COLLAPSE, GameConfig.SHAKE_BUILDING_COLLAPSE_RADIUS)
	state_changed.emit(state)


## Affiche l'étape de chantier qui correspond à l'avancement (sous l'échafaudage).
func _show_stage() -> void:
	if stage_models.is_empty():
		return
	var stage := mini(int(build_progress * stage_models.size()), stage_models.size() - 1)
	if stage != _stage:
		_stage = stage
		_show_model([stage_models[stage], scaffolding_model])


## Remplace les modèles affichés et ajuste la boîte de collision au premier (le bâtiment lui-même).
func _show_model(models: Array[PackedScene]) -> void:
	for child in _visual.get_children():
		_visual.remove_child(child)
		child.queue_free()
	var bounds := AABB()
	for index in models.size():
		if models[index] == null:
			continue
		var model: Node3D = models[index].instantiate()
		_visual.add_child(model)
		if index == 0:
			bounds = _local_bounds(model)
	# Boîte un peu plus étroite que le modèle : les débords (toit, bûches au sol) ne bloquent pas.
	var box := _collision.shape as BoxShape3D
	box.size = Vector3(bounds.size.x * 0.8, bounds.size.y, bounds.size.z * 0.8)
	_collision.position = bounds.get_center()
	_on_model_changed()


## Appelé après chaque changement de modèle (pour les classes filles).
func _on_model_changed() -> void:
	pass


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
	_label.modulate = Color(1.0, 0.96, 0.86)
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
			_label.text = "%s — construction %d %%" % [building_name, int(build_progress * 100.0)]
		State.DESTROYED:
			_label.text = "%s détruite" % building_name
		_:
			_label.text = "%s — %d / %d" % [building_name, ceili(health), int(max_health)] if ratio < 1.0 else building_name
	# Barre masquée quand le bâtiment est intact ou en ruines.
	_bar.visible = state == State.UNDER_CONSTRUCTION or (state == State.BUILT and ratio < 1.0)
	var quad := _bar_fill.mesh as QuadMesh
	quad.size = Vector2(maxf(BAR_SIZE.x * ratio, 0.001), BAR_SIZE.y)
	# La barre se vide vers la gauche : le quad reste calé sur le bord gauche du fond.
	quad.center_offset = Vector3(-(BAR_SIZE.x - quad.size.x) * 0.5, 0.0, 0.0)
	var fill := quad.material as StandardMaterial3D
	fill.albedo_color = Color(0.85, 0.2, 0.15) if ratio < 0.3 else (Color(0.9, 0.7, 0.2) if ratio < 0.6 else Color(0.35, 0.8, 0.25))
