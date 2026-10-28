extends CanvasLayer
## HUD minimal : réticule et jauge d'endurance (masquée quand elle est pleine).

@onready var _stamina_bar: ProgressBar = %StaminaBar


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.stamina_changed.connect(_on_stamina_changed)
	_stamina_bar.modulate.a = 0.0


func _on_stamina_changed(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	var target_alpha := 0.0 if value >= max_value else 1.0
	_stamina_bar.modulate.a = move_toward(_stamina_bar.modulate.a, target_alpha, get_process_delta_time() * 3.0)
