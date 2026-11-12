extends CanvasLayer
## HUD (§4.7 du cahier des charges, fig. 4.1) : réticule, panneau des ordres du Général, minimap,
## jauges de loyauté et de confiance, vie et endurance, charge portée, message du Général.
## S'y ajoutent : stock du camp, niveau et XP, invite d'action, roue de communication, écran des
## talents, écran de mort, dialogues de campagne et écran de fin (Renom gagné).
## Tout est construit par script ; chaque partie est facultative (scènes de test sans Général).

const ORDER_CHIME := preload("res://assets/sounds/axe/axe_chop.ogg")

var _player: Player
var _director: GameDirector
var _orders: WorkerOrders
var _general: General
var _wood_carried := 0
var _gold_carried := 0
var _toast_time := 0.0
var _dialogue: Array = []

var _order_panel: Panel
var _order_list: Label
var _camp: Label
var _toast: Label
var _toast_panel: Panel
var _minimap: Minimap
var _loyalty_bar: ProgressBar
var _trust_bar: ProgressBar
var _gauges: Control
var _health_bar: ProgressBar
var _health_text: Label
var _stamina_bar: ProgressBar
var _carried: Label
var _carried_panel: Panel
var _xp_bar: ProgressBar
var _level: Label
var _prompt: Label
var _action_bar: ProgressBar
var _hurt_flash: ColorRect
var _death: Label
var _end_panel: ColorRect
var _end_label: Label
var _dialogue_panel: Panel
var _dialogue_label: Label
var _wheel: CommWheel
var _chime: AudioStreamPlayer

@onready var _root: Control = $Root


func _ready() -> void:
	# Le HUD reste actif quand la partie est figée (talents, dialogues, écran de fin).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.stamina_changed.connect(_on_stamina_changed)
		_player.health_changed.connect(_on_health_changed)
		_player.hurt.connect(func() -> void: _hurt_flash.color.a = 0.35)
		_player.carrier.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
		_player.carrier.load_changed.connect(_on_load_changed)
		_player.carrier.gold_changed.connect(_on_gold_changed)
		_player.carrier.progress_changed.connect(_on_progress_changed)
	_connect_game.call_deferred()


## Le Général, ses ordres et le directeur de partie peuvent être absents (scènes de test).
func _connect_game() -> void:
	if _player:
		_player.progress.xp_changed.connect(_on_xp_changed)
		_player.progress.leveled_up.connect(func(level: int) -> void: _show_toast("Niveau %d ! Un point de talent (Tab)." % level))
		_on_xp_changed(_player.progress.xp, _player.progress.xp_needed(), _player.progress.level)
		_on_health_changed(_player.health, _player.max_health())
	_general = get_tree().get_first_node_in_group("general") as General
	if _general:
		_general.message.connect(_on_general_message)
	_orders = get_tree().get_first_node_in_group("worker_orders") as WorkerOrders
	_order_panel.visible = _orders != null
	_gauges.visible = _orders != null
	if _orders:
		_orders.orders_changed.connect(_refresh_orders)
		_orders.ping.connect(_minimap.add_ping)
		_wheel.suggested.connect(func(option: String) -> void: _orders.suggest(option))
		_refresh_orders()
	_director = get_tree().get_first_node_in_group("game_director") as GameDirector
	_minimap.visible = _director != null
	if _director:
		_director.game_ended.connect(_on_game_ended)
		var mission := _director.mission_index()
		if mission >= 0:
			_start_dialogue(GameConfig.CAMPAIGN[mission]["intro"])


func _process(delta: float) -> void:
	_hurt_flash.color.a = move_toward(_hurt_flash.color.a, 0.0, delta * 0.9)
	_toast_time -= delta
	_toast_panel.modulate.a = clampf(_toast_time, 0.0, 1.0)
	if CampEconomy.instance:
		var camp := CampEconomy.instance
		_camp.text = "Bois %d   Or %d   Nourriture %d / %d" % [camp.wood, camp.gold, camp.food_used() + 1, camp.food_cap()]
	if _orders:
		_loyalty_bar.value = _orders.loyalty
		_trust_bar.value = _orders.trust
		_refresh_orders()
	if _player:
		_death.visible = _player.is_dead() and not (_director and _director.ended)
		var status := _director.respawn_status() if _director else "Réapparition dans %d s" % ceili(_player.get_respawn_time())
		_death.text = "Tu es mort. Tes talents sont perdus.\n" + status


func _unhandled_input(event: InputEvent) -> void:
	if not _dialogue.is_empty() and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		_next_dialogue_line()
		get_viewport().set_input_as_handled()
	elif _director and _director.ended and event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_R:
			_director.restart()
		elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_ESCAPE:
			_director.to_menu()


# --- Mises à jour ------------------------------------------------------------------------------------

func _refresh_orders() -> void:
	var lines: Array[String] = []
	for order in _orders.active:
		var line := "☐ " + String(order["text"])
		var goal := float(order["goal"])
		if String(order["type"]).begins_with("gather"):
			line += "  (%d / %d)" % [int(order["progress"]), int(goal)]
		if order["primary"]:
			line += "  — prioritaire"
		lines.append(line)
	if _orders.traitor:
		lines.insert(0, "☠ TRAÎTRE : le Général veut ta mort")
	if lines.is_empty():
		lines.append("Aucun ordre pour l'instant.")
	_order_list.text = "\n".join(lines)


func _on_general_message(text: String) -> void:
	_show_toast("Le Général : « %s »" % text)
	_chime.pitch_scale = 2.2
	_chime.play()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 6.0


func _on_stamina_changed(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value


func _on_health_changed(value: float, max_value: float) -> void:
	_health_bar.max_value = max_value
	_health_bar.value = value
	_health_text.text = "%d / %d" % [ceili(value), int(max_value)]


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	var points := _player.progress.points
	_level.text = "Niv. %d" % level + ("   ·   %d point%s de talent (Tab)" % [points, "s" if points > 1 else ""] if points > 0 else "")


func _on_load_changed(count: int, _capacity: int) -> void:
	_wood_carried = count
	_update_carried()


func _on_gold_changed(amount: int) -> void:
	_gold_carried = amount
	_update_carried()


func _update_carried() -> void:
	if _wood_carried > 0:
		_carried.text = "Bois %d / %d" % [_wood_carried, _player.wood_capacity()]
	elif _gold_carried > 0:
		_carried.text = "Or %d / %d" % [_gold_carried, _player.gold_capacity()]
	_carried_panel.visible = _wood_carried > 0 or _gold_carried > 0


func _on_progress_changed(ratio: float) -> void:
	_action_bar.visible = ratio >= 0.0
	_action_bar.value = ratio


# --- Dialogues de campagne (§2.1 : texte, sans voix) ---------------------------------------------------

func _start_dialogue(lines: Array) -> void:
	_dialogue = lines.duplicate()
	get_tree().paused = true
	_dialogue_panel.visible = true
	_dialogue_label.text = String(_dialogue[0]) + "\n\n[Espace] Continuer"


func _next_dialogue_line() -> void:
	_dialogue.pop_front()
	if _dialogue.is_empty():
		_dialogue_panel.visible = false
		get_tree().paused = false
	else:
		_dialogue_label.text = String(_dialogue[0]) + "\n\n[Espace] Continuer"


# --- Fin de partie ------------------------------------------------------------------------------------------

func _on_game_ended(victory: bool) -> void:
	_end_panel.visible = true
	var lines: Array[String] = ["VICTOIRE" if victory else "DÉFAITE",
		"La loge ennemie est tombée." if victory else "Notre loge est tombée.", ""]
	var mission := _director.mission_index()
	if victory and mission >= 0:
		for line: String in GameConfig.CAMPAIGN[mission]["outro"]:
			lines.append(line)
		lines.append("")
	for label: String in _director.renown_breakdown:
		lines.append("%s : +%d" % [label, _director.renown_breakdown[label]])
	lines.append("Renom gagné : %d" % _director.renown_earned)
	lines.append("")
	lines.append("[Entrée] Menu     [R] Rejouer")
	_end_label.text = "\n".join(lines)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Construction ----------------------------------------------------------------------------------------------

func _build() -> void:
	_hurt_flash = ColorRect.new()
	_hurt_flash.color = Color(0.7, 0.05, 0.02, 0.0)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt_flash)
	_hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(crosshair)
	UiKit.place(crosshair, Control.PRESET_CENTER, -2, -2, 2, 2)

	# 2 — Ordres du Général (haut gauche), avec le stock du camp dessous.
	_order_panel = UiKit.panel(_root)
	UiKit.place(_order_panel, Control.PRESET_TOP_LEFT, 16, 16, 396, 150)
	var header := UiKit.panel(_order_panel, UiKit.GOLD, 6)
	UiKit.place(header, Control.PRESET_TOP_WIDE, 0, 0, 0, 30)
	var header_text := UiKit.label(header, 15, HORIZONTAL_ALIGNMENT_LEFT, Color(0.12, 0.09, 0.04))
	header_text.text = "⚑ ORDRES DU GÉNÉRAL"
	header_text.remove_theme_constant_override("outline_size")
	UiKit.place(header_text, Control.PRESET_FULL_RECT, 10, 4, 0, 0)
	_order_list = UiKit.label(_order_panel, 15)
	_order_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(_order_list, Control.PRESET_FULL_RECT, 10, 36, -8, -4)
	_camp = UiKit.label(_root, 17, HORIZONTAL_ALIGNMENT_LEFT, UiKit.GOLD)
	UiKit.place(_camp, Control.PRESET_TOP_LEFT, 20, 156, 440, 182)

	# 9 — Message du Général (haut centre).
	_toast_panel = UiKit.panel(_root, Color(0.1, 0.13, 0.17, 0.88), 16)
	UiKit.place(_toast_panel, Control.PRESET_CENTER_TOP, -230, 18, 400, 58)
	_toast = UiKit.label(_toast_panel, 17, HORIZONTAL_ALIGNMENT_CENTER, Color(1.0, 0.85, 0.45))
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.clip_text = true
	UiKit.place(_toast, Control.PRESET_FULL_RECT, 12, 0, -12, 0)
	_toast_panel.modulate.a = 0.0

	# 3 — Minimap (haut droite) ; 4, 5 — loyauté et confiance dessous.
	_minimap = Minimap.new()
	_root.add_child(_minimap)
	UiKit.place(_minimap, Control.PRESET_TOP_RIGHT, -Minimap.SIZE - 16, 16, -16, Minimap.SIZE + 16)
	_gauges = UiKit.panel(_root)
	UiKit.place(_gauges, Control.PRESET_TOP_RIGHT, -Minimap.SIZE - 16, Minimap.SIZE + 24, -16, Minimap.SIZE + 96)
	_loyalty_bar = _gauge("LOYAUTÉ (obéissance)", UiKit.GOLD, 6)
	_trust_bar = _gauge("CONFIANCE (écoute)", Color(0.25, 0.65, 0.3), 38)

	# 6, 7 — Vie et endurance (bas gauche).
	_health_bar = UiKit.bar(_root, Color(0.8, 0.18, 0.14))
	UiKit.place(_health_bar, Control.PRESET_BOTTOM_LEFT, 56, -62, 286, -46)
	_health_text = UiKit.label(_root, 14)
	UiKit.place(_health_text, Control.PRESET_BOTTOM_LEFT, 294, -66, 400, -42)
	var hp_tag := UiKit.label(_root, 14)
	hp_tag.text = "PV"
	UiKit.place(hp_tag, Control.PRESET_BOTTOM_LEFT, 20, -66, 54, -42)
	_stamina_bar = UiKit.bar(_root, Color(0.25, 0.65, 0.3))
	_stamina_bar.max_value = GameConfig.MAX_STAMINA
	_stamina_bar.value = GameConfig.MAX_STAMINA
	UiKit.place(_stamina_bar, Control.PRESET_BOTTOM_LEFT, 56, -38, 286, -24)
	var sta_tag := UiKit.label(_root, 14)
	sta_tag.text = "END"
	UiKit.place(sta_tag, Control.PRESET_BOTTOM_LEFT, 20, -42, 54, -18)

	# 8 — Charge portée (bas centre), niveau et XP au-dessus.
	_carried_panel = UiKit.panel(_root, Color(0.08, 0.1, 0.12, 0.85), 14)
	UiKit.place(_carried_panel, Control.PRESET_CENTER_BOTTOM, -90, -58, 90, -22)
	_carried = UiKit.label(_carried_panel, 17, HORIZONTAL_ALIGNMENT_CENTER)
	_carried.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.place(_carried, Control.PRESET_FULL_RECT, 0, 0, 0, 0)
	_carried_panel.visible = false
	_xp_bar = UiKit.bar(_root, Color(0.45, 0.6, 0.95))
	UiKit.place(_xp_bar, Control.PRESET_CENTER_BOTTOM, -200, -12, 200, -6)
	_level = UiKit.label(_root, 14, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_level, Control.PRESET_CENTER_BOTTOM, -300, -86, 300, -62)

	_prompt = UiKit.label(_root, 20, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_prompt, Control.PRESET_CENTER, -340, 28, 340, 58)
	_action_bar = UiKit.bar(_root, Color(0.95, 0.9, 0.75))
	_action_bar.max_value = 1.0
	_action_bar.visible = false
	UiKit.place(_action_bar, Control.PRESET_CENTER, -110, 64, 110, 72)

	_death = UiKit.label(_root, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_death.visible = false
	UiKit.place(_death, Control.PRESET_CENTER, -460, -150, 460, -50)

	_wheel = CommWheel.new()
	_root.add_child(_wheel)
	var talents := TalentScreen.new()
	_root.add_child(talents)

	_dialogue_panel = UiKit.panel(_root, Color(0.06, 0.07, 0.1, 0.94), 10)
	_dialogue_panel.visible = false
	UiKit.place(_dialogue_panel, Control.PRESET_CENTER_BOTTOM, -430, -250, 430, -110)
	_dialogue_label = UiKit.label(_dialogue_panel, 20, HORIZONTAL_ALIGNMENT_CENTER)
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(_dialogue_label, Control.PRESET_FULL_RECT, 18, 10, -18, -10)

	_end_panel = ColorRect.new()
	_end_panel.color = Color(0.03, 0.02, 0.01, 0.8)
	_end_panel.visible = false
	_root.add_child(_end_panel)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_label = UiKit.label(_end_panel, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_chime = AudioStreamPlayer.new()
	_chime.stream = ORDER_CHIME
	_chime.volume_db = -8.0
	add_child(_chime)


func _gauge(title: String, color: Color, top: float) -> ProgressBar:
	var tag := UiKit.label(_gauges, 11, HORIZONTAL_ALIGNMENT_LEFT, UiKit.DIM)
	tag.text = title
	UiKit.place(tag, Control.PRESET_TOP_WIDE, 10, top, -8, top + 14)
	var gauge := UiKit.bar(_gauges, color)
	gauge.max_value = 100.0
	UiKit.place(gauge, Control.PRESET_TOP_WIDE, 10, top + 16, -10, top + 26)
	return gauge
