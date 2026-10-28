class_name DustImpactVFX
extends OneShotVFX
## Nuage de poussière soulevé par la chute d'un tronc. Le -Z local suit le tronc couché.


## Étire la zone d'émission sur la longueur du tronc (appelé avant l'entrée dans l'arbre de scène).
func set_length(length: float) -> void:
	for particles: GPUParticles3D in find_children("*", "GPUParticles3D", true, false):
		var material := particles.process_material as ParticleProcessMaterial
		if material and material.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX:
			material = material.duplicate()
			material.emission_box_extents.z = length * 0.5
			particles.process_material = material
			particles.amount = int(particles.amount * clampf(length / 4.0, 1.0, 2.0))
