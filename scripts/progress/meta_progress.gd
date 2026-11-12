class_name MetaProgress
extends Node
## Progression PERMANENTE (§9) et réglages, sauvegardés dans `user://pawn_save.json` : Renom gagné à
## chaque fin de partie, améliorations achetées, avancement de la campagne, options (sensibilité,
## volume, touches). Autoload `Meta` ; on y accède par `MetaProgress.instance` (voir `CampEconomy`).
## Porte aussi le réglage de la prochaine partie, choisi dans le menu (`pending`).

signal changed

const SAVE_PATH := "user://pawn_save.json"

static var instance: MetaProgress

var renown := 0
## Améliorations achetées : id → niveau.
var upgrades: Dictionary = {}
## Missions de campagne terminées.
var campaign_done := 0
var mouse_sensitivity := 1.0
var volume := 0.8
## Touches reconfigurées : action → code physique de touche.
var keys: Dictionary = {}
## Prochaine partie : {map, difficulty, mission (-1 = partie libre)}.
var pending := {"map": "valley", "difficulty": "normal", "mission": -1}
## Résultat de la dernière partie, affiché au retour dans le menu.
var last_result: Dictionary = {}


func _enter_tree() -> void:
	instance = self
	_setup_input()
	load_save()


## Actions ajoutées par script (roulade, roue, talents…) et commandes de manette (§14.1).
## Les actions de base (déplacement, saut, sprint, attaque, E) sont dans `project.godot`.
func _setup_input() -> void:
	_add_key("dodge", KEY_CTRL)
	_add_key("comm_wheel", KEY_Q)
	_add_key("talents", KEY_TAB)
	_add_key("barricade", KEY_B)
	_add_key("architect", KEY_F)
	_add_button("jump", JOY_BUTTON_A)
	_add_button("dodge", JOY_BUTTON_B)
	_add_button("interact", JOY_BUTTON_X)
	_add_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_button("comm_wheel", JOY_BUTTON_LEFT_SHOULDER)
	_add_button("talents", JOY_BUTTON_START)
	_add_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _add_key(action: String, physical_keycode: Key) -> void:
	_ensure_action(action)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key)


func _add_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_axis(action: String, axis: JoyAxis, direction: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


## Niveau d'une amélioration permanente (0 si le profil n'existe pas, par exemple en test).
static func level_of(upgrade: String) -> int:
	return int(instance.upgrades.get(upgrade, 0)) if instance else 0


func cost_of(upgrade: String) -> int:
	var config: Dictionary = GameConfig.META_UPGRADES[upgrade]
	return roundi(float(config["cost"]) * pow(GameConfig.META_COST_GROWTH, level_of(upgrade)))


func can_buy(upgrade: String) -> bool:
	return level_of(upgrade) < int(GameConfig.META_UPGRADES[upgrade]["levels"]) and renown >= cost_of(upgrade)


func buy(upgrade: String) -> bool:
	if not can_buy(upgrade):
		return false
	renown -= cost_of(upgrade)
	upgrades[upgrade] = level_of(upgrade) + 1
	save()
	changed.emit()
	return true


func add_renown(amount: int) -> void:
	renown += amount
	save()
	changed.emit()


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"renown": renown, "upgrades": upgrades, "campaign_done": campaign_done,
			"mouse_sensitivity": mouse_sensitivity, "volume": volume, "keys": keys}, "\t"))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	var saved := data as Dictionary
	renown = int(saved.get("renown", 0))
	campaign_done = int(saved.get("campaign_done", 0))
	mouse_sensitivity = float(saved.get("mouse_sensitivity", 1.0))
	volume = float(saved.get("volume", 0.8))
	upgrades.clear()
	var saved_upgrades: Dictionary = saved.get("upgrades", {})
	for upgrade: String in saved_upgrades:
		if GameConfig.META_UPGRADES.has(upgrade):
			upgrades[upgrade] = int(saved_upgrades[upgrade])
	keys = saved.get("keys", {})
	apply_settings()


## Applique volume et touches reconfigurées.
func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	for action: String in keys:
		if InputMap.has_action(action):
			rebind(action, int(keys[action]), false)


## Remplace la touche clavier d'une action (les boutons de souris et de manette sont conservés).
func rebind(action: String, physical_keycode: int, remember: bool = true) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key)
	if remember:
		keys[action] = physical_keycode
		save()
