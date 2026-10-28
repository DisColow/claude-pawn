class_name ZClip
## Utilitaire "Z-Clip Depth Scaling" : les éléments de la vue subjective (bras, hache, bois porté)
## sont rendus comme rapprochés de la caméra pour ne jamais être traversés par le décor.


## Applique use_z_clip_scale / z_clip_scale à tous les MeshInstance3D sous `root`.
static func apply(root: Node, scale: float = 0.1) -> void:
	for mesh_instance: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_apply_to_mesh(mesh_instance, scale)
	if root is MeshInstance3D:
		_apply_to_mesh(root, scale)


static func _apply_to_mesh(mesh_instance: MeshInstance3D, scale: float) -> void:
	if mesh_instance.mesh == null:
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.get_active_material(surface)
		if not source is BaseMaterial3D:
			continue
		var material := source.duplicate() as BaseMaterial3D
		material.use_z_clip_scale = true
		material.z_clip_scale = scale
		mesh_instance.set_surface_override_material(surface, material)
