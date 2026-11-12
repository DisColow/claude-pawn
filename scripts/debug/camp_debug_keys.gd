extends Node
## Touches de test : K inflige des dégâts au bâtiment allié le plus proche du joueur, L donne 100
## bois et 100 or au camp, N fait attaquer l'armée ennemie tout de suite, X donne un niveau au péon.
## À retirer pour une version publiée.


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	match key.physical_keycode:
		KEY_K:
			var building := _nearest_building(player)
			if building:
				building.take_damage(GameConfig.DEBUG_BUILDING_DAMAGE)
		KEY_L:
			CampEconomy.instance.add_wood(100)
			CampEconomy.instance.add_gold(100)
		KEY_N:
			var enemy := get_tree().get_first_node_in_group("general_1") as General
			if enemy:
				enemy.start_assault()
		KEY_X:
			if player:
				player.progress.add_xp(player.progress.xp_needed())


func _nearest_building(player: Node3D) -> CampBuilding:
	var nearest: CampBuilding = null
	for node in get_tree().get_nodes_in_group("camp_buildings"):
		var building := node as CampBuilding
		if player == null:
			return building
		if nearest == null or building.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
			nearest = building
	return nearest
