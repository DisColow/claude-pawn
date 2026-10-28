class_name OneShotVFX
extends Node3D
## Effet ponctuel : déclenche toutes ses particules à l'apparition puis se libère.


func _ready() -> void:
	# Différé : le spawner place l'effet (global_transform) juste après add_child().
	_fire.call_deferred()


func _fire() -> void:
	var longest := 0.0
	for particles: GPUParticles3D in find_children("*", "GPUParticles3D", true, false):
		particles.one_shot = true
		particles.restart()
		longest = maxf(longest, particles.lifetime * (1.0 + particles.randomness))
	get_tree().create_timer(longest + 0.5).timeout.connect(queue_free)
