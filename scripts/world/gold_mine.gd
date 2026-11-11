class_name GoldMine
extends StaticBody3D
## Mine d'or (neutre, inépuisable pour l'instant) : dans sa zone, le péon maintient E pour remplir
## un sac d'or, qu'il rapporte ensuite au bastion.

const MODEL := preload("res://assets/models/buildings/building_mine_red.gltf")
const MODEL_SCALE := 4.5

@onready var _zone: Area3D = $Zone


func _ready() -> void:
	add_to_group("gold_mines")
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)
	var label := Label3D.new()
	label.text = "Mine d'or"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.011
	label.font_size = 64
	label.outline_size = 16
	label.modulate = Color(1.0, 0.86, 0.35)
	label.outline_modulate = Color(0.1, 0.07, 0.03)
	label.position = Vector3(0.0, 6.6, 0.0)
	add_child(label)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player:
		player.carrier.enter_mine(self)


func _on_body_exited(body: Node3D) -> void:
	var player := body as Player
	if player:
		player.carrier.exit_mine(self)
