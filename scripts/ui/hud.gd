extends CanvasLayer
## HUD minimal : réticule, jauge d'endurance (masquée quand elle est pleine), invite de ramassage
## et compteur de bûches portées.

@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _prompt: Label = %PromptLabel
@onready var _load: Label = %LoadLabel


func _ready() -> void:
	_stamina_bar.modulate.a = 0.0
	_prompt.text = ""
	_load.text = ""
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.stamina_changed.connect(_on_stamina_changed)
		var carrier := player.get_node("LogCarrier") as LogCarrier
		carrier.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
		carrier.load_changed.connect(_on_load_changed)


func _on_stamina_changed(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	var target_alpha := 0.0 if value >= max_value else 1.0
	_stamina_bar.modulate.a = move_toward(_stamina_bar.modulate.a, target_alpha, get_process_delta_time() * 3.0)


func _on_load_changed(count: int, capacity: int) -> void:
	_load.text = "Bois : %d / %d" % [count, capacity] if count > 0 else ""
