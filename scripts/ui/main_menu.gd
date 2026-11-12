extends Control
## Menu principal (§2 du cahier des charges) : Partie libre (carte + difficulté), Campagne (arc court
## de trois missions, débloquées l'une après l'autre), Progression (améliorations permanentes
## achetées avec le Renom, §9) et Options (sensibilité, volume, touches reconfigurables, §14.2).

## Actions reconfigurables et leur nom affiché.
const ACTIONS := {"move_forward": "Avancer", "move_back": "Reculer", "move_left": "Gauche", "move_right": "Droite",
	"jump": "Sauter", "sprint": "Sprinter", "dodge": "Roulade", "interact": "Interagir / construire",
	"comm_wheel": "Roue de communication", "talents": "Talents", "barricade": "Barricade", "architect": "Achever (Architecte)"}

var _screen: Control
var _map := "valley"
var _difficulty := "normal"
## Action dont on attend la nouvelle touche ("" = aucune).
var _rebinding := ""


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color(0.09, 0.12, 0.15)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_main()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _rebinding != "" and key and key.pressed:
		if key.physical_keycode != KEY_ESCAPE:
			MetaProgress.instance.rebind(_rebinding, key.physical_keycode)
		_rebinding = ""
		_show_options()
		get_viewport().set_input_as_handled()


## Remplace l'écran courant par une colonne centrée, avec un titre.
func _new_screen(title: String, width: float = 560.0) -> VBoxContainer:
	if _screen:
		_screen.queue_free()
	_screen = Control.new()
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading := UiKit.label(_screen, 44, HORIZONTAL_ALIGNMENT_CENTER, UiKit.GOLD)
	heading.text = title
	UiKit.place(heading, Control.PRESET_CENTER_TOP, -500, 24, 500, 84)
	var scroll := ScrollContainer.new()
	_screen.add_child(scroll)
	# Colonne centrée, du dessous du titre jusqu'en bas de l'écran.
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = -width * 0.5
	scroll.offset_right = width * 0.5
	scroll.offset_top = 104.0
	scroll.offset_bottom = -24.0
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	return column


func _text(parent: Control, text: String, font_size: int = 18, color: Color = UiKit.TEXT) -> Label:
	var node := UiKit.label(parent, font_size, HORIZONTAL_ALIGNMENT_CENTER, color)
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


func _button(parent: Control, text: String, action: Callable, enabled: bool = true) -> Button:
	var node := UiKit.button(parent, text, 22)
	node.custom_minimum_size = Vector2(0, 52)
	node.disabled = not enabled
	node.pressed.connect(action)
	return node


# --- Écrans ----------------------------------------------------------------------------------------------

func _show_main() -> void:
	var column := _new_screen("PAWN")
	_text(column, "Du péon sacrifiable à la légende du champ de bataille", 20, UiKit.DIM)
	var meta := MetaProgress.instance
	if not meta.last_result.is_empty():
		_text(column, "%s — Renom gagné : %d" % ["Victoire" if meta.last_result["victory"] else "Défaite", meta.last_result["renown"]], 20, UiKit.GOLD)
	_text(column, "Renom : %d" % meta.renown, 20)
	_button(column, "Partie libre", _show_free_play)
	_button(column, "Campagne — L'Ascension", _show_campaign)
	_button(column, "Progression", _show_meta)
	_button(column, "Options", _show_options)
	_button(column, "Quitter", get_tree().quit)


func _show_free_play() -> void:
	var column := _new_screen("PARTIE LIBRE")
	_text(column, "Carte")
	for map: String in GameConfig.MAPS:
		_button(column, ("▶ " if map == _map else "") + String(GameConfig.MAPS[map]["name"]), func() -> void:
			_map = map
			_show_free_play())
	_text(column, "Difficulté (compétence du Général ennemi)")
	for difficulty: String in ["easy", "normal", "hard"]:
		_button(column, ("▶ " if difficulty == _difficulty else "") + String(GameConfig.DIFFICULTIES[difficulty]["name"]), func() -> void:
			_difficulty = difficulty
			_show_free_play())
	_button(column, "LANCER LA PARTIE", func() -> void: _start(_map, _difficulty, -1))
	_button(column, "Retour", _show_main)


func _show_campaign() -> void:
	var column := _new_screen("CAMPAGNE — L'ASCENSION")
	_text(column, "Un péon anonyme, trois batailles, une légende. Les talents repartent de zéro à chaque mission ; le Renom reste.", 17, UiKit.DIM)
	var done := MetaProgress.instance.campaign_done
	for index in GameConfig.CAMPAIGN.size():
		var mission: Dictionary = GameConfig.CAMPAIGN[index]
		var status := "  ✔" if index < done else ("" if index == done else "  (verrouillée)")
		_button(column, String(mission["title"]) + status, func() -> void:
			_start(mission["map"], mission["difficulty"], index), index <= done)
	_button(column, "Retour", _show_main)


func _show_meta() -> void:
	var meta := MetaProgress.instance
	var column := _new_screen("PROGRESSION", 760.0)
	_text(column, "Renom disponible : %d. Ces améliorations sont permanentes : elles survivent à la mort et aux parties." % meta.renown, 18, UiKit.GOLD)
	var category := ""
	for upgrade: String in GameConfig.META_UPGRADES:
		var config: Dictionary = GameConfig.META_UPGRADES[upgrade]
		if config["category"] != category:
			category = config["category"]
			_text(column, category.to_upper(), 16, UiKit.DIM)
		var level := MetaProgress.level_of(upgrade)
		var maxed := level >= int(config["levels"])
		var text := "%s  %d / %d — %s" % [config["name"], level, config["levels"], config["desc"]]
		text += "" if maxed else "   [%d Renom]" % meta.cost_of(upgrade)
		var button := _button(column, text, func() -> void:
			meta.buy(upgrade)
			_show_meta(), meta.can_buy(upgrade))
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size = Vector2(0, 42)
	_button(column, "Retour", _show_main)


func _show_options() -> void:
	var meta := MetaProgress.instance
	var column := _new_screen("OPTIONS", 640.0)
	_text(column, "Sensibilité de la souris")
	_slider(column, 0.3, 2.5, meta.mouse_sensitivity, func(value: float) -> void:
		meta.mouse_sensitivity = value
		meta.save())
	_text(column, "Volume")
	_slider(column, 0.0, 1.0, meta.volume, func(value: float) -> void:
		meta.volume = value
		meta.apply_settings()
		meta.save())
	_text(column, "Touches (cliquer puis appuyer sur la nouvelle touche ; Échap annule). Manette : sticks, A sauter, B roulade, X interagir, RT frapper, LB roue, Start talents.", 15, UiKit.DIM)
	for action: String in ACTIONS:
		var label := "… appuie sur une touche …" if action == _rebinding else _key_name(action)
		var button := _button(column, "%s : %s" % [ACTIONS[action], label], func() -> void:
			_rebinding = action
			_show_options())
		button.add_theme_font_size_override("font_size", 17)
		button.custom_minimum_size = Vector2(0, 40)
	_button(column, "Retour", _show_main)


func _slider(parent: Control, minimum: float, maximum: float, value: float, changed: Callable) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(changed)
	parent.add_child(slider)


func _key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode))
	return "—"


func _start(map: String, difficulty: String, mission: int) -> void:
	MetaProgress.instance.pending = {"map": map, "difficulty": difficulty, "mission": mission}
	get_tree().change_scene_to_file(GameConfig.MAPS[map]["scene"])
