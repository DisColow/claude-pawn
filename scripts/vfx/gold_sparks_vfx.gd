class_name GoldSparksVFX
extends OneShotVFX
## Étincelles et paillettes d'or projetées quand la pioche frappe une veine (le -Z local sort du mur).


func _init() -> void:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.3, -1.0)
	material.spread = 55.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0.0, -9.0, 0.0)
	material.scale_min = 0.5
	material.scale_max = 1.2
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_color = Color(1.0, 0.82, 0.25)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.035
	mesh.material = look
	var particles := GPUParticles3D.new()
	particles.amount = 14
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.process_material = material
	particles.draw_pass_1 = mesh
	add_child(particles)
