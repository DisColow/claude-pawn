class_name Minimap
extends Control
## Minimap (§4.7) : toute la carte vue de dessus. Mines d'or (Au), bâtiments des deux camps (la loge
## ennemie est marquée X), unités, flèche du joueur, et les « pings » que le Général pose quand il
## désigne un endroit. Les unités ennemies n'apparaissent que près des nôtres.

const SIZE := 190.0
const PING_TIME := 10.0

## Pings : [position, secondes restantes].
var _pings: Array[Array] = []
var _bounds := Rect2(-100, -100, 200, 200)
var _bounds_timer := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_ping(world_position: Vector3) -> void:
	_pings.append([world_position, PING_TIME])


func _process(delta: float) -> void:
	for entry in _pings:
		entry[1] -= delta
	_pings = _pings.filter(func(entry: Array) -> bool: return entry[1] > 0.0)
	_bounds_timer -= delta
	if _bounds_timer <= 0.0:
		_bounds_timer = 3.0
		_update_bounds()
	queue_redraw()


## Cadre de la carte : tout ce qui compte (bâtiments, mines, extensions), avec une marge.
func _update_bounds() -> void:
	var first := true
	var rect := Rect2()
	for group: String in ["buildings", "gold_mines", "expansion_points"]:
		for node in get_tree().get_nodes_in_group(group):
			var position_2d := Vector2((node as Node3D).global_position.x, (node as Node3D).global_position.z)
			rect = Rect2(position_2d, Vector2.ZERO) if first else rect.expand(position_2d)
			first = false
	if first:
		return
	rect = rect.grow(35.0)
	# Carré, pour ne pas déformer la carte.
	var side := maxf(rect.size.x, rect.size.y)
	_bounds = Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


func _to_map(world_position: Vector3) -> Vector2:
	return (Vector2(world_position.x, world_position.z) - _bounds.position) / _bounds.size * SIZE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.13, 0.2, 0.14, 0.88))
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), UiKit.GOLD, false, 2.0)
	var font := get_theme_default_font()
	for node in get_tree().get_nodes_in_group("gold_mines"):
		var spot := _to_map((node as Node3D).global_position)
		draw_circle(spot, 5.0, Color(1.0, 0.8, 0.2))
		draw_string(font, spot + Vector2(7, 4), "Au", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.4))
	var friends: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as CampBuilding
		if building.state == CampBuilding.State.DESTROYED:
			continue
		var spot := _to_map(building.global_position)
		var color := Color(0.9, 0.3, 0.25) if building.team == 0 else Color(0.35, 0.55, 1.0)
		var half := 5.0 if building.kind == "war_lodge" else 3.0
		draw_rect(Rect2(spot - Vector2(half, half), Vector2(half, half) * 2.0), color)
		if building.kind == "war_lodge":
			draw_string(font, spot + Vector2(7, 4), "B" if building.team == 0 else "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color.lightened(0.4))
		if building.team == 0:
			friends.append(building.global_position)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		friends.append(player.global_position)
	for node in get_tree().get_nodes_in_group("units_0"):
		friends.append((node as Node3D).global_position)
		draw_circle(_to_map((node as Node3D).global_position), 1.8, Color(1.0, 0.55, 0.4))
	for node in get_tree().get_nodes_in_group("units_1"):
		var where := (node as Node3D).global_position
		for friend in friends:
			if friend.distance_squared_to(where) < 3600.0:
				draw_circle(_to_map(where), 1.8, Color(0.5, 0.7, 1.0))
				break
	for entry in _pings:
		var spot := _to_map(entry[0])
		var pulse := 6.0 + 5.0 * absf(sin(float(entry[1]) * 4.0))
		draw_arc(spot, pulse, 0.0, TAU, 20, Color(1.0, 0.9, 0.3), 2.0)
	if player:
		var spot := _to_map(player.global_position)
		var forward := Vector2(-player.global_basis.z.x, -player.global_basis.z.z).normalized()
		var side := Vector2(-forward.y, forward.x)
		draw_colored_polygon(PackedVector2Array([spot + forward * 8.0, spot - forward * 5.0 + side * 5.0, spot - forward * 5.0 - side * 5.0]), Color.WHITE)
