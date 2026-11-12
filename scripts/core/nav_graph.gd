class_name NavGraph
extends Node
## Graphe de chemins de la carte (routes dégagées entre les camps, les mines et les extensions),
## écrit par le générateur de carte. Les unités s'en servent pour les longs trajets ; sur de courtes
## distances (à l'intérieur d'une clairière) elles vont tout droit.

static var instance: NavGraph

## Points du graphe et arêtes (paires d'indices de points).
@export var points: PackedVector3Array = PackedVector3Array()
@export var edges: PackedInt32Array = PackedInt32Array()
## En dessous de cette distance, on va tout droit.
@export var direct_distance := 22.0

var _neighbors: Array[PackedInt32Array] = []


func _enter_tree() -> void:
	instance = self
	_neighbors.clear()
	for index in points.size():
		_neighbors.append(PackedInt32Array())
	for index in range(0, edges.size() - 1, 2):
		_neighbors[edges[index]].append(edges[index + 1])
		_neighbors[edges[index + 1]].append(edges[index])


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Chemin de `from` à `to` : liste de points à suivre, `to` compris (tout droit s'il n'y a pas de graphe).
static func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var direct := PackedVector3Array([to])
	if instance == null or instance.points.is_empty() or from.distance_to(to) < instance.direct_distance:
		return direct
	var start := instance._nearest(from)
	var goal := instance._nearest(to)
	if start == goal:
		return direct
	# Dijkstra : le graphe ne compte que quelques dizaines de points.
	var count := instance.points.size()
	var distance: Array[float] = []
	var previous: Array[int] = []
	var done: Array[bool] = []
	for index in count:
		distance.append(INF)
		previous.append(-1)
		done.append(false)
	distance[start] = 0.0
	for step in count:
		var current := -1
		for index in count:
			if not done[index] and (current == -1 or distance[index] < distance[current]):
				current = index
		if current == -1 or distance[current] == INF or current == goal:
			break
		done[current] = true
		for next in instance._neighbors[current]:
			var candidate := distance[current] + instance.points[current].distance_to(instance.points[next])
			if candidate < distance[next]:
				distance[next] = candidate
				previous[next] = current
	if previous[goal] == -1:
		return direct
	var path := PackedVector3Array([to])
	var node := goal
	while node != -1:
		path.insert(0, instance.points[node])
		node = previous[node]
	# Inutile de revenir en arrière vers le premier point si on est déjà plus près du deuxième.
	if path.size() > 2 and from.distance_to(path[1]) < path[0].distance_to(path[1]):
		path.remove_at(0)
	return path


func _nearest(position: Vector3) -> int:
	var best := 0
	for index in points.size():
		if points[index].distance_squared_to(position) < points[best].distance_squared_to(position):
			best = index
	return best
