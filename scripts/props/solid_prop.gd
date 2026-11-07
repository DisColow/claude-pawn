class_name SolidProp
extends StaticBody3D
## Élément de décor solide (rocher…) : collision convexe calculée depuis ses meshes au chargement,
## une seule fois par modèle (cache partagé entre toutes les instances de la forêt).

static var _shape_cache: Dictionary = {}


func _ready() -> void:
	for mesh_instance: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var key := mesh_instance.mesh.get_instance_id()
		if not _shape_cache.has(key):
			_shape_cache[key] = mesh_instance.mesh.create_convex_shape(true, false)
		var collision := CollisionShape3D.new()
		collision.shape = _shape_cache[key]
		collision.transform = global_transform.affine_inverse() * mesh_instance.global_transform
		add_child(collision)
