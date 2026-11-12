class_name Barricade
extends StaticBody3D
## Barricade temporaire posée par le péon (talent Fortifier) : un mur de rondins qui bloque le
## passage, que les ennemis doivent abattre, et qui se défait tout seul au bout d'un moment.

const LOG_MODEL := preload("res://assets/models/props/wood_log.glb")

var health := GameConfig.BARRICADE_HEALTH


func _ready() -> void:
	add_to_group("barricades")
	collision_layer = 1
	collision_mask = 0
	for row in 3:
		for column in 2:
			var wood: Node3D = LOG_MODEL.instantiate()
			wood.scale = Vector3(1.7, 1.6, 1.6)
			wood.position = Vector3(-0.85 + column * 1.7, 0.2 + row * 0.38, 0.0)
			wood.rotation.x = row * 1.3 + column
			add_child(wood)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 1.3, 0.5)
	shape.shape = box
	shape.position.y = 0.65
	add_child(shape)
	get_tree().create_timer(GameConfig.BARRICADE_LIFETIME).timeout.connect(queue_free)


func take_damage(amount: float, _from: Vector3 = Vector3.INF) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()


func is_targetable() -> bool:
	return not is_queued_for_deletion()


func get_target_radius() -> float:
	return 1.2


func is_flying() -> bool:
	return false
