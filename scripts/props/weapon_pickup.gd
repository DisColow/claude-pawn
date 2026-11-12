class_name WeaponPickup
extends RigidBody3D
## Arme lâchée par un soldat tombé (§4.6) : le péon peut la ramasser avec E s'il a débloqué le
## ramassage d'armes. Elle frappe plus fort que la hache, mais casse au bout de quelques coups.

## Scène du modèle de l'arme (celle que tenait le soldat).
var weapon_scene: PackedScene


func _ready() -> void:
	add_to_group("weapon_pickups")
	collision_layer = 8
	collision_mask = 13
	mass = 4.0
	if weapon_scene:
		var model: Node3D = weapon_scene.instantiate()
		model.rotation.z = PI * 0.5
		add_child(model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.2, 0.3)
	shape.shape = box
	add_child(shape)
	# Les armes abandonnées ne restent pas éternellement sur le champ de bataille.
	get_tree().create_timer(60.0).timeout.connect(queue_free)
