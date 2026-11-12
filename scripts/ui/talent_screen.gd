class_name TalentScreen
extends Control
## Écran des talents (§8) : trois arbres, cinq paliers. Tab l'ouvre et met la partie en pause.
## Un clic investit un point ; « Redistribuer » rend tous les points (avec un délai).

var _player: Player
var _buttons: Dictionary = {}
var _points: Label
var _respec: Button
var _details: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := UiKit.label(self, 30, HORIZONTAL_ALIGNMENT_CENTER, UiKit.GOLD)
	title.text = "TALENTS"
	UiKit.place(title, Control.PRESET_CENTER_TOP, -300, 30, 300, 70)
	_points = UiKit.label(self, 20, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_points, Control.PRESET_CENTER_TOP, -400, 76, 400, 104)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	add_child(columns)
	UiKit.place(columns, Control.PRESET_CENTER, -480, -210, 480, 250)
	for tree: String in GameConfig.TALENT_TREES:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		columns.add_child(column)
		var header := UiKit.label(column, 22, HORIZONTAL_ALIGNMENT_CENTER, UiKit.GOLD)
		header.text = GameConfig.TALENT_TREES[tree]
		for tier in range(1, 6):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			column.add_child(row)
			var tier_label := UiKit.label(row, 13, HORIZONTAL_ALIGNMENT_LEFT, UiKit.DIM)
			tier_label.text = "P%d" % tier
			tier_label.custom_minimum_size = Vector2(26, 0)
			for talent: String in GameConfig.TALENTS:
				var config: Dictionary = GameConfig.TALENTS[talent]
				if config["tree"] != tree or int(config["tier"]) != tier:
					continue
				var button := UiKit.button(row, "", 15)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.custom_minimum_size = Vector2(0, 58)
				button.pressed.connect(_on_talent_pressed.bind(talent))
				button.mouse_entered.connect(_show_details.bind(talent))
				_buttons[talent] = button
	_details = UiKit.label(self, 17, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_details, Control.PRESET_CENTER_BOTTOM, -480, -128, 480, -84)
	_respec = UiKit.button(self, "Redistribuer")
	UiKit.place(_respec, Control.PRESET_CENTER_BOTTOM, -260, -70, -20, -28)
	_respec.pressed.connect(_on_respec)
	var close := UiKit.button(self, "Fermer (Tab)")
	UiKit.place(close, Control.PRESET_CENTER_BOTTOM, 20, -70, 260, -28)
	close.pressed.connect(toggle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("talents"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	var director := get_tree().get_first_node_in_group("game_director") as GameDirector
	if _player == null or (director and director.ended) or (not visible and get_tree().paused):
		return
	visible = not visible
	get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_refresh()


func _refresh() -> void:
	var progress := _player.progress
	_points.text = "Niveau %d — points à dépenser : %d" % [progress.level, progress.points]
	for talent: String in _buttons:
		var config: Dictionary = GameConfig.TALENTS[talent]
		var button := _buttons[talent] as Button
		button.text = "%s\n%d / %d" % [config["name"], progress.rank(talent), config["ranks"]]
		button.disabled = not progress.can_spend(talent)
		button.modulate = Color(1.0, 0.85, 0.5) if progress.rank(talent) > 0 else Color.WHITE
	_respec.disabled = progress.respec_cooldown > 0.0 or progress.ranks.is_empty()
	_respec.text = "Redistribuer" if progress.respec_cooldown <= 0.0 else "Redistribuer (%d s)" % ceili(progress.respec_cooldown)


func _show_details(talent: String) -> void:
	var config: Dictionary = GameConfig.TALENTS[talent]
	var needed := (int(config["tier"]) - 1) * GameConfig.TALENT_TIER_COST
	_details.text = "%s — %s" % [config["name"], config["desc"]]
	if needed > 0:
		_details.text += "\n(palier %d : %d points dans l'arbre %s)" % [config["tier"], needed, GameConfig.TALENT_TREES[config["tree"]]]


func _on_talent_pressed(talent: String) -> void:
	if _player.progress.spend(talent):
		# Les talents de vie et de capacité s'appliquent tout de suite.
		_player.health_changed.emit(_player.health, _player.max_health())
		_player.carrier.refresh_capacity()
	_refresh()


func _on_respec() -> void:
	_player.progress.respec()
	_player.carrier.refresh_capacity()
	_refresh()
