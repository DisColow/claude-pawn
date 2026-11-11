class_name LumberMill
extends CampBuilding
## Scierie du camp : dépôt de bois avancé (la pile de rondins est dans sa cour) et bâtiment requis
## par le Général pour la suite. Sa scie tourne quand elle est debout.

var _saw: Node3D


func _process(delta: float) -> void:
	super._process(delta)
	if _saw and state == State.BUILT:
		_saw.rotate_x(GameConfig.LUMBER_MILL_SAW_SPEED * delta)


func _on_model_changed() -> void:
	var saws := _visual.find_children("*saw*", "Node3D", true, false)
	_saw = saws[0] as Node3D if not saws.is_empty() else null
