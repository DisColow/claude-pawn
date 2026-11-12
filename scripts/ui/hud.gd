extends CanvasLayer
## HUD : réticule, vie et endurance, invite d'action (avec jauge pour miner / construire), charge
## portée (bois, or), stock du camp, ordre du Général, vagues ennemies, mort et fin de partie.

const TEXT_COLOR := Color(0.96, 0.84, 0.6)
const OUTLINE_COLOR := Color(0.1, 0.07, 0.03)

var _wood_carried := 0
var _gold_carried := 0
var _player: Player
var _director: GameDirector
var _order: Label
var _wave: Label
var _health_bar: ProgressBar
var _action_bar: ProgressBar
var _hurt_flash: ColorRect
var _death: Label
var _end_panel: ColorRect
var _end_label: Label

@onready var _root: Control = $Root
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _prompt: Label = %PromptLabel
@onready var _load: Label = %LoadLabel
@onready var _camp: Label = %CampLabel


func _ready() -> void:
	# Le HUD reste actif quand la partie est figée (écran de fin, touche R).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stamina_bar.modulate.a = 0.0
	_prompt.text = ""
	_load.text = ""
	_build_widgets()
	CampEconomy.instance.wood_changed.connect(_update_camp.unbind(1))
	CampEconomy.instance.gold_changed.connect(_update_camp.unbind(1))
	_update_camp()
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.stamina_changed.connect(_on_stamina_changed)
		_player.health_changed.connect(_on_health_changed)
		_player.hurt.connect(func() -> void: _hurt_flash.color.a = 0.35)
		_player.carrier.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
		_player.carrier.load_changed.connect(_on_load_changed)
		_player.carrier.gold_changed.connect(_on_gold_changed)
		_player.carrier.progress_changed.connect(_on_progress_changed)
	# Le Général et le directeur de partie peuvent être absents (scènes de test).
	_connect_game.call_deferred()


func _connect_game() -> void:
	var general := get_tree().get_first_node_in_group("general") as General
	if general:
		general.order_changed.connect(_on_order_changed)
		_on_order_changed(general.order)
	_director = get_tree().get_first_node_in_group("game_director") as GameDirector
	if _director:
		_director.game_ended.connect(_on_game_ended)


func _process(delta: float) -> void:
	_hurt_flash.color.a = move_toward(_hurt_flash.color.a, 0.0, delta * 0.9)
	if _player:
		var respawn := _player.get_respawn_time()
		_death.visible = respawn > 0.0
		_death.text = "Tu es mort…\nRéapparition au camp dans %d s" % ceili(respawn)
	if _director:
		_wave.text = _wave_text()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and key.physical_keycode == KEY_R and _director and _director.ended:
		_director.restart()


func _wave_text() -> String:
	var enemies := get_tree().get_nodes_in_group("undead_units").size() + _director.get_pending_spawns()
	var text := "Vague %d / %d" % [_director.wave, GameConfig.WAVE_COUNT]
	if enemies > 0:
		text += "\nSquelettes : %d" % enemies
	if _director.wave < GameConfig.WAVE_COUNT and _director.get_pending_spawns() == 0:
		text += "\nProchaine vague : %d s" % ceili(_director.time_to_next)
	return text


func _on_stamina_changed(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	var target_alpha := 0.0 if value >= max_value else 1.0
	_stamina_bar.modulate.a = move_toward(_stamina_bar.modulate.a, target_alpha, get_process_delta_time() * 3.0)


func _on_health_changed(value: float, max_value: float) -> void:
	_health_bar.max_value = max_value
	_health_bar.value = value
	_health_bar.visible = value < max_value


func _on_load_changed(count: int, _capacity: int) -> void:
	_wood_carried = count
	_update_load()


func _on_gold_changed(amount: int) -> void:
	_gold_carried = amount
	_update_load()


func _update_load() -> void:
	var parts: Array[String] = []
	if _wood_carried > 0:
		parts.append("Bois : %d / %d" % [_wood_carried, GameConfig.BASE_WOOD_CAPACITY])
	if _gold_carried > 0:
		parts.append("Or : %d / %d" % [_gold_carried, GameConfig.BASE_GOLD_CAPACITY])
	_load.text = "    ".join(parts)


func _on_progress_changed(ratio: float) -> void:
	_action_bar.visible = ratio >= 0.0
	_action_bar.value = ratio


func _update_camp() -> void:
	_camp.text = "Camp — Bois : %d    Or : %d" % [CampEconomy.instance.wood, CampEconomy.instance.gold]


func _on_order_changed(text: String) -> void:
	_order.text = "Le Général : « %s »" % text if text != "" else ""


func _on_game_ended(victory: bool) -> void:
	_end_panel.visible = true
	_end_label.text = ("VICTOIRE\nLe camp a tenu bon." if victory else "DÉFAITE\nLe bastion est tombé.") + "\n\n[R] Rejouer"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Construction des éléments ajoutés par script -----------------------------------------------

func _build_widgets() -> void:
	_hurt_flash = ColorRect.new()
	_hurt_flash.color = Color(0.7, 0.05, 0.02, 0.0)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt_flash)
	_root.move_child(_hurt_flash, 0)
	_hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_order = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_order.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_order.offset_left = -420.0
	_order.offset_right = 420.0
	_order.offset_top = 58.0
	_order.offset_bottom = 124.0
	_order.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_wave = _make_label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	_wave.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_wave.offset_left = -320.0
	_wave.offset_right = -24.0
	_wave.offset_top = 20.0
	_wave.offset_bottom = 110.0

	_health_bar = _make_bar(Color(0.8, 0.16, 0.12, 0.95))
	_health_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_health_bar.offset_left = -140.0
	_health_bar.offset_right = 140.0
	_health_bar.offset_top = -66.0
	_health_bar.offset_bottom = -54.0
	_health_bar.max_value = GameConfig.PLAYER_MAX_HEALTH
	_health_bar.value = GameConfig.PLAYER_MAX_HEALTH
	_health_bar.visible = false

	_action_bar = _make_bar(Color(0.95, 0.9, 0.75, 0.95))
	_action_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_action_bar.offset_left = -110.0
	_action_bar.offset_right = 110.0
	_action_bar.offset_top = 64.0
	_action_bar.offset_bottom = 72.0
	_action_bar.max_value = 1.0
	_action_bar.visible = false

	_death = _make_label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_death.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death.offset_left = -400.0
	_death.offset_right = 400.0
	_death.offset_top = -140.0
	_death.offset_bottom = -50.0
	_death.visible = false

	_end_panel = ColorRect.new()
	_end_panel.color = Color(0.03, 0.02, 0.01, 0.72)
	_end_panel.visible = false
	_root.add_child(_end_panel)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_label = _make_label(44, HORIZONTAL_ALIGNMENT_CENTER, _end_panel)
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_label(font_size: int, alignment: HorizontalAlignment, parent: Control = null) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", font_size)
	(parent if parent else _root).add_child(label)
	return label


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.04, 0.55)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	_root.add_child(bar)
	return bar
