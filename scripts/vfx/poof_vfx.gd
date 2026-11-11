class_name PoofVFX
extends OneShotVFX
## Disparition « ninja » : nuage de fumée blanche bien opaque qui gonfle d'un coup, quelques
## bouffées projetées à l'horizontale, puis tout se dissipe. Accompagné d'un « poof ».

@onready var _audio: AudioStreamPlayer3D = $PoofAudio


func _fire() -> void:
	_audio.pitch_scale = randf_range(0.92, 1.1)
	_audio.play()
	super._fire()
