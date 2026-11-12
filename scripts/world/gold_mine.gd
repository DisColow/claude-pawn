class_name GoldMine
extends StaticBody3D
## Mine d'or (§5.1 du cahier des charges) : on y entre par une galerie, et on frappe à la pioche
## les veines d'or des parois. La coque (parois, plafond, collisions) est bâtie par script à partir
## des dimensions ci-dessous. Des montagnes l'ENTOURENT (sans jamais la recouper : leurs blocs de
## roche imbriqués rempliraient la salle) et de gros rochers coiffent son toit. L'entrée regarde vers +Z.

const MOUNTAINS: Array[PackedScene] = [
	preload("res://assets/models/mine/mountain_B.gltf"), preload("res://assets/models/mine/mountain_A.gltf"),
	preload("res://assets/models/mine/mountain_C.gltf")]
## Montagnes autour de la coque : (modèle, x, z, échelle, lacet). Chacune reste hors de la salle.
const MOUNTAIN_LAYOUT: Array[Array] = [
	[0, -12.3, -1.0, 6.2, 0.0], [1, 12.3, -1.0, 6.2, 1.9], [2, 0.0, -13.2, 6.2, 0.7],
	[1, -9.5, -11.0, 5.0, 2.6], [0, 9.5, -11.0, 5.0, 4.0], [2, -7.3, 11.2, 3.9, 1.2], [1, 7.3, 11.2, 3.9, -0.9]]
## Gros rochers posés sur le toit : (x, z, échelle, lacet).
const ROOF_ROCKS: Array[Array] = [[-3.0, -3.5, 30.0, 0.4], [3.2, 1.5, 27.0, 2.2], [-2.5, 4.0, 22.0, 3.9], [2.0, -5.0, 20.0, 5.1]]
## Gris bleuté des montagnes KayKit, pour les faces extérieures de la coque.
const OUTSIDE_COLOR := Color(0.37, 0.42, 0.48)
const ROCKS: Array[PackedScene] = [
	preload("res://assets/models/mine/rock_single_B.gltf"), preload("res://assets/models/mine/rock_single_C.gltf")]
const LOG_MODEL := preload("res://assets/models/props/wood_log.glb")
const VEIN_SCRIPT := preload("res://scripts/world/gold_vein.gd")
const VEIN_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/axe/axe_impact_1.ogg"), preload("res://assets/sounds/axe/axe_impact_4.ogg")]

## Salle : demi-largeur (X), demi-profondeur (Z), hauteur ; épaisseur des parois.
const HALF_WIDTH := 5.5
const HALF_DEPTH := 6.5
const HEIGHT := 4.4
const WALL := 1.0
## Galerie d'entrée : demi-largeur, hauteur de passage, longueur.
const DOOR_HALF := 1.9
const DOOR_HEIGHT := 3.3
const TUNNEL := 4.0
## Roche de l'intérieur : brun sombre et chaud, pour trancher avec le gris bleuté de la montagne.
const ROCK_COLOR := Color(0.3, 0.26, 0.23)

var _rock_material: StandardMaterial3D
var _lining_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("gold_mines")
	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = OUTSIDE_COLOR
	_rock_material.roughness = 1.0
	_lining_material = StandardMaterial3D.new()
	_lining_material.albedo_color = ROCK_COLOR
	_lining_material.roughness = 1.0
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
	plane.material = _lining_material
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, 0.02, (WALL + TUNNEL) * 0.5)
	add_child(floor_mesh)
	# Doublure brune des faces intérieures (salle puis galerie) : parois, fond, façade, plafonds.
	var tunnel_z := outer_z + TUNNEL * 0.5
	for side: float in [-1.0, 1.0]:
		_add_lining(Vector3(side * (HALF_WIDTH - 0.03), HEIGHT * 0.5, 0.0), Vector3(0.06, HEIGHT, HALF_DEPTH * 2.0))
		_add_lining(Vector3(side * (DOOR_HALF + front_width * 0.5), HEIGHT * 0.5, HALF_DEPTH - 0.03), Vector3(front_width, HEIGHT, 0.06))
		_add_lining(Vector3(side * (DOOR_HALF - 0.03), DOOR_HEIGHT * 0.5, HALF_DEPTH + (WALL + TUNNEL) * 0.5), Vector3(0.06, DOOR_HEIGHT, WALL + TUNNEL))
	_add_lining(Vector3(0.0, HEIGHT * 0.5, -HALF_DEPTH + 0.03), Vector3(HALF_WIDTH * 2.0, HEIGHT, 0.06))
	_add_lining(Vector3(0.0, HEIGHT - 0.03, 0.0), Vector3(HALF_WIDTH * 2.0, 0.06, HALF_DEPTH * 2.0))
	_add_lining(Vector3(0.0, DOOR_HEIGHT - 0.03, HALF_DEPTH + (WALL + TUNNEL) * 0.5), Vector3(DOOR_HALF * 2.0, 0.06, WALL + TUNNEL))
	_add_lining(Vector3(0.0, (HEIGHT + DOOR_HEIGHT) * 0.5, HALF_DEPTH - 0.03), Vector3(DOOR_HALF * 2.0, HEIGHT - DOOR_HEIGHT, 0.06))
	_add_veins()
	_add_interior_props()
	_add_exterior(outer_z)
	_add_interior_zone(outer_z)


## Panneau de roche sombre plaqué sur une face intérieure (visuel seul).
func _add_lining(center: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _lining_material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = center
	add_child(visual)


func _add_block(center: Vector3, size: Vector3, with_mesh: bool = true) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)
	if not with_mesh:
		return
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _rock_material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = center
	add_child(visual)


## Huit veines : trois par paroi latérale, deux au fond.
func _add_veins() -> void:
	var spots: Array[Transform3D] = []
	for z: float in [-4.2, -0.6, 3.2]:
		spots.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-HALF_WIDTH + 0.05, 1.45, z)))
		spots.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(HALF_WIDTH - 0.05, 1.45, z + 0.9)))
	for x: float in [-2.6, 2.6]:
		spots.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x, 1.45, -HALF_DEPTH + 0.05)))
	for spot in spots:
		var vein := StaticBody3D.new()
		vein.set_script(VEIN_SCRIPT)
		vein.set("hit_sounds", VEIN_SOUNDS)
		vein.collision_mask = 0
		vein.transform = spot
		add_child(vein)


## Étais en rondins (poteaux et poutre) tous les quelques mètres, lanternes sous les poutres,
## éboulis au pied des parois : des repères de profondeur dans une galerie sinon uniforme.
func _add_interior_props() -> void:
	for z: float in [-4.6, -1.0, 2.6, HALF_DEPTH + WALL + 1.2]:
		var half := HALF_WIDTH - 0.35 if z < HALF_DEPTH else DOOR_HALF - 0.25
		var top := HEIGHT - 0.35 if z < HALF_DEPTH else DOOR_HEIGHT - 0.25
		for side: float in [-1.0, 1.0]:
			var post: Node3D = LOG_MODEL.instantiate()
			post.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(Vector3(top, 1.5, 1.5)), Vector3(side * half, top * 0.5, z))
			add_child(post)
		var beam: Node3D = LOG_MODEL.instantiate()
		beam.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(half * 2.0 + 0.5, 1.5, 1.5)), Vector3(0.0, top, z))
		add_child(beam)
		if z < HALF_DEPTH:
			var lantern := OmniLight3D.new()
			lantern.light_color = Color(1.0, 0.72, 0.4)
			lantern.light_energy = 1.4
			lantern.omni_range = 8.0
			lantern.position = Vector3(0.0, top - 0.6, z)
			add_child(lantern)
	for index in 10:
		var rock: Node3D = ROCKS[index % ROCKS.size()].instantiate()
		var side := -1.0 if index % 2 == 0 else 1.0
		rock.scale = Vector3.ONE * (3.0 + 2.5 * absf(sin(index * 2.7)))
		rock.position = Vector3(side * (HALF_WIDTH - 0.5), 0.0, -HALF_DEPTH + 0.8 + (index / 2) * 2.7)
		rock.rotation.y = index * 2.3
		add_child(rock)


## Montagne autour de la coque, rochers et cadre en rondins à l'entrée, nom au-dessus.
func _add_exterior(outer_z: float) -> void:
	for entry in MOUNTAIN_LAYOUT:
		var mountain: Node3D = MOUNTAINS[int(entry[0])].instantiate()
		var size := float(entry[3])
		mountain.scale = Vector3.ONE * size
		mountain.position = Vector3(float(entry[1]), -0.3, float(entry[2]))
		mountain.rotation.y = float(entry[4])
		add_child(mountain)
		# Roche pleine : on ne traverse pas la montagne à pied.
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = size * 0.72
		cylinder.height = 8.0
		shape.shape = cylinder
		shape.position = Vector3(float(entry[1]), 4.0, float(entry[2]))
		add_child(shape)
	for entry in ROOF_ROCKS:
		var boulder: Node3D = ROCKS[1].instantiate()
		boulder.scale = Vector3.ONE * float(entry[2])
		boulder.position = Vector3(float(entry[0]), HEIGHT + WALL - 0.4, float(entry[1]))
		boulder.rotation.y = float(entry[3])
		add_child(boulder)
	var mouth := outer_z + TUNNEL
	for index in 6:
		var rock: Node3D = ROCKS[index % ROCKS.size()].instantiate()
		var side := -1.0 if index % 2 == 0 else 1.0
		rock.scale = Vector3.ONE * (9.0 + 4.0 * absf(sin(index * 4.1)))
		rock.position = Vector3(side * (DOOR_HALF + WALL + 1.3 + 0.7 * (index / 2)), 0.0, mouth - 0.4 - 1.6 * (index / 2))
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
	label.position = Vector3(0.0, DOOR_HEIGHT + 1.8, mouth + 0.3)
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
