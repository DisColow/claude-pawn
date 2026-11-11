extends Node
## Touches de test : K inflige des dégâts au bâtiment du camp le plus proche du joueur,
## N lance tout de suite la vague ennemie suivante. À retirer pour une version publiée.


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_K:
		var building := _nearest_building()
		if building:
			building.take_damage(GameConfig.DEBUG_BUILDING_DAMAGE)
	elif key.physical_keycode == KEY_N:
		var director := get_tree().get_first_node_in_group("game_director") as GameDirector
		if director:
			director.start_next_wave()


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
