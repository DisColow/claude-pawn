class_name Tracer
## Trait lumineux bref entre un tireur et sa cible (flèche, carreau, éclair de sort).


static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.9, 0.55), width: float = 0.05) -> void:
	if from.distance_squared_to(to) < 0.01:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, from.distance_to(to))
	mesh.material = material
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(tracer)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT
	tracer.look_at_from_position((from + to) * 0.5, to, up)
	parent.get_tree().create_timer(0.12).timeout.connect(tracer.queue_free)
