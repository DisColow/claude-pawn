class_name Bastion
extends CampBuilding
## Bastion : cœur du camp. On y dépose le bois et l'or (dans sa cour). S'il tombe, la partie est perdue.


func _ready() -> void:
	add_to_group("bastion")
	super._ready()
