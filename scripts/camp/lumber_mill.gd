class_name LumberMill
extends CampBuilding
## Scierie du camp : le bâtiment où l'on dépose le bois (§3.3). Le dépôt (`WoodStockpile`, la pile
## de rondins dans sa cour) ne fonctionne que si la scierie est debout : ni en chantier, ni en ruines.

var _saw: Node3D

@onready var _yard: WoodStockpile = $Yard


func _ready() -> void:
	max_health = GameConfig.LUMBER_MILL_MAX_HEALTH
	build_time = GameConfig.LUMBER_MILL_BUILD_TIME
	state_changed.connect(_on_state_changed)
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if _saw and state == State.BUILT:
		_saw.rotate_x(GameConfig.LUMBER_MILL_SAW_SPEED * delta)


func _on_model_changed() -> void:
	var saws := _visual.find_children("*saw*", "Node3D", true, false)
	_saw = saws[0] as Node3D if not saws.is_empty() else null


func _on_state_changed(new_state: State) -> void:
	_yard.enabled = new_state == State.BUILT
