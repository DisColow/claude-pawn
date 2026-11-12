class_name GoldVein
extends StaticBody3D
## Veine d'or sur une paroi de la mine : chaque coup de pioche en tire de l'or (§5.1 du cahier des
## charges). Elle s'épuise à vue d'œil (pépites qui disparaissent, lueur qui baisse) puis se
## reconstitue lentement. Le -Z local sort de la paroi.

const NUGGETS := 7

## Or restant dans la veine.
var gold_left := GameConfig.VEIN_GOLD

var _nuggets: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _regen_timer := 0.0
var _audio: AudioStreamPlayer3D

@export var hit_sounds: Array[AudioStream] = []


func _ready() -> void:
	add_to_group("gold_veins")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 0.35)
	shape.shape = box
	add_child(shape)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.2)
	gold.metallic = 0.6
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.15)
	gold.emission_energy_multiplier = 0.9
	for index in NUGGETS:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.16, 0.14) * (0.7 + 0.6 * absf(sin(index * 5.3)))
		mesh.material = gold
		var nugget := MeshInstance3D.new()
		nugget.mesh = mesh
		# Pépites en traînée oblique sur la paroi, orientations variées mais stables.
		var along := float(index) / (NUGGETS - 1) - 0.5
		nugget.position = Vector3(along * 1.2, sin(index * 2.1) * 0.25 + along * 0.5, -0.12)
		nugget.rotation = Vector3(index * 1.3, index * 0.7, index * 2.9)
		add_child(nugget)
		_nuggets.append(nugget)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.35)
	_light.omni_range = 5.0
	_light.position = Vector3(0.0, 0.2, -0.8)
	add_child(_light)
	_audio = AudioStreamPlayer3D.new()
	_audio.max_distance = 30.0
	add_child(_audio)
	_refresh()


func _physics_process(delta: float) -> void:
	if gold_left >= GameConfig.VEIN_GOLD:
		return
	_regen_timer += delta
	if _regen_timer >= GameConfig.VEIN_REGEN_INTERVAL:
		_regen_timer = 0.0
		gold_left += 1
		_refresh()


## Coup d'outil du joueur (même signature que les arbres) : étincelles et tintement.
func take_hit(_damage: float, hit_position: Vector3, hit_normal: Vector3, _from_position: Vector3,
		_swing_direction: Vector3 = Vector3.ZERO) -> void:
	if gold_left <= 0:
		return
	var sparks := GoldSparksVFX.new()
	get_parent().add_child(sparks)
	sparks.look_at_from_position(hit_position, hit_position - hit_normal, Vector3.UP if absf(hit_normal.y) < 0.9 else Vector3.RIGHT)
	if not hit_sounds.is_empty():
		_audio.stream = hit_sounds.pick_random()
		_audio.pitch_scale = randf_range(1.7, 2.1)
		_audio.play()


## Retire jusqu'à `amount` or de la veine et renvoie ce qui a vraiment été extrait.
func extract(amount: int) -> int:
	var taken := mini(amount, gold_left)
	gold_left -= taken
	_refresh()
	return taken


## Pépites visibles et lueur proportionnelles à l'or restant.
func _refresh() -> void:
	var ratio := float(gold_left) / GameConfig.VEIN_GOLD
	var shown := ceili(ratio * NUGGETS)
	for index in NUGGETS:
		_nuggets[index].visible = index < shown
	_light.light_energy = 0.2 + 1.3 * ratio
