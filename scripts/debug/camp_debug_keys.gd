extends Node
## Touches de test, en attendant le Général et les ennemis : K inflige des dégâts au bâtiment du
## camp le plus proche du joueur (comme une attaque ennemie), B ordonne sa (re)construction.
## À retirer de la scène quand ces systèmes existeront.


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var building := _nearest_building()
	if building == null:
		return
	if key.physical_keycode == KEY_K:
		building.take_damage(GameConfig.DEBUG_BUILDING_DAMAGE)
	elif key.physical_keycode == KEY_B and building.state != CampBuilding.State.UNDER_CONSTRUCTION:
		building.begin_construction()


func _nearest_building() -> CampBuilding:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var nearest: CampBuilding = null
	for node in get_tree().get_nodes_in_group("camp_buildings"):
		var building := node as CampBuilding
		if player == null:
			return building
		if nearest == null or building.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
			nearest = building
	return nearest
