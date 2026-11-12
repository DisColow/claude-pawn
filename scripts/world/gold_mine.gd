class_name GoldMine
extends StaticBody3D
## Mine d'or (§5.1 du cahier des charges) : on y entre par une galerie, et on frappe à la pioche
## les veines d'or des parois. La coque (parois, plafond, collisions) est bâtie par script à partir
## des dimensions ci-dessous ; une montagne l'enveloppe à l'extérieur. L'entrée regarde vers +Z.

const MOUNTAINS: Array[PackedScene] = [
	preload("res://assets/models/mine/mountain_B.gltf"), preload("res://assets/models/mine/mountain_A.gltf"),
	preload("res://assets/models/mine/mountain_C.gltf")]
## Montagnes qui enveloppent la coque : (modèle, x, z, échelle, lacet).
const MOUNTAIN_LAYOUT: Array[Array] = [
	[0, 0.0, -1.5, 10.5, 0.0], [1, -4.6, 2.6, 6.8, 1.2], [2, 4.6, 2.6, 6.8, -0.9], [1, 0.0, -6.5, 7.5, 2.6]]
const ROCKS: Array[PackedScene] = [
	preload("res://assets/models/mine/rock_single_B.gltf"), preload("res://assets/models/mine/rock_single_C.gltf")]
const LOG_MODEL := preload("res://assets/models/props/wood_log.glb")
const VEIN_SCRIPT := preload("res://scripts/world/gold_vein.gd")
const VEIN_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/axe/axe_impact_1.ogg"), preload("res://assets/sounds/axe/axe_impact_4.ogg")]

## Salle : demi-largeur (X), demi-profondeur (Z), hauteur ; épaisseur des parois.
const HALF_WIDTH := 3.5
const HALF_DEPTH := 4.5
const HEIGHT := 3.2
const WALL := 1.0
## Galerie d'entrée : demi-largeur, hauteur de passage, longueur.
const DOOR_HALF := 1.3
const DOOR_HEIGHT := 2.6
const TUNNEL := 3.5
const ROCK_COLOR := Color(0.36, 0.4, 0.45)

var _rock_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("gold_mines")
	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = ROCK_COLOR
	_rock_material.roughness = 1.0
	var outer_x := HALF_WIDTH + WALL
	var outer_z := HALF_DEPTH + WALL
	var side_x := HALF_WIDTH + WALL * 0.5
	# Parois latérales, fond, façade de part et d'autre de la porte, linteau, plafond.
	_add_block(Vector3(-side_x, HEIGHT * 0.5, 0.0), Vector3(WALL, HEIGHT, outer_z * 2.0))
	_add_block(Vector3(side_x, HEIGHT * 0.5, 0.0), Vector3(WALL, HEIGHT, outer_z * 2.0))
	_add_block(Vector3(0.0, HEIGHT * 0.5, -HALF_DEPTH - WALL * 0.5), Vector3(HALF_WIDTH * 2.0, HEIGHT, WALL))
	var front_width := HALF_WIDTH - DOOR_HALF
	for side: float in [-1.0, 1.0]:
		_add_block(Vector3(side * (DOOR_HALF + front_width * 0.5), HEIGHT * 0.5, HALF_DEPTH + WALL * 0.5),
			Vector3(front_width, HEIGHT, WALL))
		# Parois de la galerie.
		_add_block(Vector3(side * (DOOR_HALF + WALL * 0.5), HEIGHT * 0.5, outer_z + TUNNEL * 0.5), Vector3(WALL, HEIGHT, TUNNEL))
	var lintel := HEIGHT - DOOR_HEIGHT
	_add_block(Vector3(0.0, DOOR_HEIGHT + lintel * 0.5, HALF_DEPTH + WALL * 0.5 + TUNNEL * 0.5),
		Vector3(DOOR_HALF * 2.0, lintel, WALL + TUNNEL))
	_add_block(Vector3(0.0, HEIGHT + WALL * 0.5, 0.0), Vector3(outer_x * 2.0, WALL, outer_z * 2.0))
	_add_block(Vector3(0.0, HEIGHT + 0.2, outer_z + TUNNEL * 0.5), Vector3((DOOR_HALF + WALL) * 2.0, 0.4, TUNNEL))
	# Sol sombre de la salle (le terrain reste dessous pour la collision).
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_WIDTH * 2.0, HALF_DEPTH * 2.0 + WALL + TUNNEL)
	plane.material = _rock_material
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, 0.02, (WALL + TUNNEL) * 0.5)
	add_child(floor_mesh)
	_add_veins()
	_add_exterior(outer_z)
	_add_interior_zone(outer_z)


func _add_block(center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _rock_material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = center
	add_child(visual)


## Six veines : deux par paroi latérale, deux au fond.
func _add_veins() -> void:
	var spots: Array[Transform3D] = []
	for z: float in [-2.2, 1.6]:
		spots.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-HALF_WIDTH + 0.05, 1.35, z)))
		spots.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(HALF_WIDTH - 0.05, 1.35, z + 0.6)))
	for x: float in [-1.7, 1.7]:
		spots.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x, 1.35, -HALF_DEPTH + 0.05)))
	for spot in spots:
		var vein := StaticBody3D.new()
		vein.set_script(VEIN_SCRIPT)
		vein.set("hit_sounds", VEIN_SOUNDS)
		vein.collision_mask = 0
		vein.transform = spot
		add_child(vein)


## Montagne autour de la coque, rochers et cadre en rondins à l'entrée, nom au-dessus.
func _add_exterior(outer_z: float) -> void:
	for entry in MOUNTAIN_LAYOUT:
		var mountain: Node3D = MOUNTAINS[int(entry[0])].instantiate()
		mountain.scale = Vector3.ONE * float(entry[3])
		mountain.position = Vector3(float(entry[1]), -0.3, float(entry[2]))
		mountain.rotation.y = float(entry[4])
		add_child(mountain)
	var mouth := outer_z + TUNNEL
	for index in 6:
		var rock: Node3D = ROCKS[index % ROCKS.size()].instantiate()
		var side := -1.0 if index % 2 == 0 else 1.0
		rock.scale = Vector3.ONE * (7.0 + 3.0 * absf(sin(index * 4.1)))
		rock.position = Vector3(side * (DOOR_HALF + WALL + 0.9 + 0.5 * (index / 2)), 0.0, mouth - 0.6 - 1.3 * (index / 2))
		rock.rotation.y = index * 1.9
		add_child(rock)
	# Cadre de galerie : deux poteaux et un linteau en rondins.
	for side: float in [-1.0, 1.0]:
		var post: Node3D = LOG_MODEL.instantiate()
		post.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(Vector3(DOOR_HEIGHT, 1.3, 1.3)),
			Vector3(side * (DOOR_HALF - 0.1), DOOR_HEIGHT * 0.5, mouth + 0.05))
		add_child(post)
	var beam: Node3D = LOG_MODEL.instantiate()
	beam.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(DOOR_HALF * 2.0 + 0.6, 1.4, 1.4)), Vector3(0.0, DOOR_HEIGHT + 0.1, mouth + 0.05))
	add_child(beam)
	var label := Label3D.new()
	label.text = "Mine d'or"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.011
	label.font_size = 64
	label.outline_size = 16
	label.modulate = Color(1.0, 0.86, 0.35)
	label.outline_modulate = Color(0.1, 0.07, 0.03)
	label.position = Vector3(0.0, DOOR_HEIGHT + 1.6, mouth + 0.3)
	add_child(label)


## Zone intérieure : le péon y sort sa pioche (et range sa hache).
func _add_interior_zone(outer_z: float) -> void:
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_WIDTH * 2.0, HEIGHT, HALF_DEPTH * 2.0 + WALL + TUNNEL - 0.5)
	shape.shape = box
	shape.position = Vector3(0.0, HEIGHT * 0.5, (WALL + TUNNEL - 0.5) * 0.5)
	zone.add_child(shape)
	add_child(zone)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player:
		player.carrier.enter_mine(self)


func _on_body_exited(body: Node3D) -> void:
	var player := body as Player
	if player:
		player.carrier.exit_mine(self)
