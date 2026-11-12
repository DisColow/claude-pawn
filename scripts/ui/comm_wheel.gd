class_name CommWheel
extends Control
## Roue de communication (§7.2) : maintenir Q (ou LB) l'ouvre, la souris (ou le stick droit) choisit
## une des huit suggestions, relâcher l'envoie au Général. Le centre annule.

signal suggested(option: String)

## Options dans l'ordre de la roue, en partant du haut et en tournant dans le sens horaire.
const OPTIONS := [
	["attack", "Attaquer", "ici"], ["defend", "Défendre", "ici"], ["colonize", "Coloniser", "la mine"],
	["build", "Construire", "le prochain"], ["retreat", "Repli", "maintenant"], ["train", "Entraîner", "des guerriers"],
	["hero", "Héros", "recruter / soigner"], ["economy", "Or / bois", "rééquilibrer"]]
const RADIUS := 170.0
const DEAD_ZONE := 45.0

var _cursor := Vector2.ZERO
var _selected := -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var can_open := player != null and not player.is_dead() and not get_tree().paused
	if not visible and Input.is_action_just_pressed("comm_wheel") and can_open:
		visible = true
		_cursor = Vector2.ZERO
		_selected = -1
	elif visible and not Input.is_action_pressed("comm_wheel"):
		visible = false
		if _selected >= 0:
			suggested.emit(OPTIONS[_selected][0])
	if visible:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if stick.length() > 0.5:
			_cursor = stick * RADIUS
		_selected = -1
		if _cursor.length() > DEAD_ZONE:
			# Secteur de 45° centré sur chaque option, la première en haut.
			var angle := fposmod(atan2(_cursor.x, -_cursor.y) + PI / 8.0, TAU)
			_selected = int(angle / (TAU / 8.0)) % 8
		queue_redraw()


func _input(event: InputEvent) -> void:
	# Roue ouverte : la souris choisit une option au lieu de tourner la tête.
	if visible and event is InputEventMouseMotion:
		_cursor = (_cursor + (event as InputEventMouseMotion).relative).limit_length(RADIUS)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var center := size * 0.5
	var font := get_theme_default_font()
	draw_circle(center, RADIUS + 70.0, Color(0.05, 0.07, 0.1, 0.78))
	draw_string(font, center + Vector2(-200, -RADIUS - 86), "ROUE DE COMMUNICATION", HORIZONTAL_ALIGNMENT_CENTER, 400, 20, UiKit.TEXT)
	for index in OPTIONS.size():
		var angle := TAU * index / OPTIONS.size()
		var spot := center + Vector2(sin(angle), -cos(angle)) * RADIUS
		draw_line(center, spot, Color(0.3, 0.35, 0.42), 2.0)
		draw_circle(spot, 46.0, UiKit.GOLD if index == _selected else Color(0.17, 0.21, 0.27))
		var ink := Color(0.1, 0.08, 0.04) if index == _selected else UiKit.TEXT
		draw_string(font, spot + Vector2(-60, -2), OPTIONS[index][1], HORIZONTAL_ALIGNMENT_CENTER, 120, 15, ink)
		draw_string(font, spot + Vector2(-60, 14), OPTIONS[index][2], HORIZONTAL_ALIGNMENT_CENTER, 120, 10, ink)
	draw_circle(center, 40.0, Color(0.09, 0.11, 0.14) if _selected >= 0 else Color(0.35, 0.12, 0.1))
	draw_string(font, center + Vector2(-40, 5), "annuler", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, UiKit.DIM)
	draw_circle(center + _cursor, 5.0, Color.WHITE)
