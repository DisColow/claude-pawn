class_name GoldSack
extends RigidBody3D
## Sac d'or tombé au sol (lâché par un péon mort) : on le ramasse avec E comme une bûche.

const MODEL := preload("res://assets/models/mine/sack.gltf")

## Or contenu dans le sac.
var amount := 0


func _ready() -> void:
	add_to_group("gold_sacks")
	collision_layer = 8
	# Pas de collision avec le joueur : le sac tombe à ses pieds sans être éjecté.
	collision_mask = 13
	mass = 8.0
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * 5.0
	add_child(model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.3, 0.75)
	shape.shape = box
	shape.position.y = 0.15
	add_child(shape)
