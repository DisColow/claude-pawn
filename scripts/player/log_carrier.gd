class_name LogCarrier
extends Node3D
## Ramassage des bûches (touche E), pile portée sur l'épaule gauche et déchargement au dépôt du camp.
## Ramassage « ninja » : la bûche visée disparaît dans un nuage de fumée et réapparaît aussitôt
## sur la pile, avec le « clac » d'une bûche qui en cogne une autre. La main gauche tient la pile tant qu'on porte du bois.
## Dans la zone d'un `WoodStockpile`, E décharge la pile rondin par rondin (du haut vers le bas).
## Ce nœud gère aussi l'or (tiré des veines à la pioche, porté dans le sac à dos, déposé au bastion)
## et la construction (maintenir E près d'un chantier du Général).
## Règles du cahier des charges (§4.4, §4.5) : on porte du bois OU de l'or, jamais les deux ;
## à la mort, la charge tombe au sol et peut être ramassée.

signal prompt_changed(text: String)
signal load_changed(count: int, capacity: int)
signal gold_changed(amount: int)
## Avancement d'une action maintenue (minage, construction) : de 0 à 1, -1 = aucune action.
signal progress_changed(ratio: float)

const LOG_MODEL := preload("res://assets/models/props/wood_log.glb")
const LOG_SCENE := preload("res://scenes/props/wood_log.tscn")
const POOF_SCENE := preload("res://scenes/vfx/poof_vfx.tscn")
## Chocs de bois enregistrés (Kenney, CC0) : joués plus aigus, ils donnent le « clac » d'une bûche
## posée sur une autre.
const PICKUP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/axe/axe_impact_0.ogg"), preload("res://assets/sounds/axe/axe_impact_1.ogg"),
	preload("res://assets/sounds/axe/axe_impact_2.ogg"), preload("res://assets/sounds/axe/axe_impact_3.ogg"),
	preload("res://assets/sounds/axe/axe_impact_4.ogg"),
]
## Pile, rangées du bas vers le haut : 4 + 4 + 2 = 10 bûches (large et basse, à côté de la tête).
const ROWS: Array[int] = [4, 4, 2]
const LOG_RADIUS := 0.125
## Appui de la pile par rapport à l'épaule gauche (repère du corps : -X = gauche, -Z = avant) :
## à l'extérieur de la tête et un peu en arrière, seul le bout des bûches entre dans le champ de vision.
const STACK_OFFSET := Vector3(-0.2, 0.08, 0.03)
## Main gauche sur le flanc extérieur du fagot (repère de la pile).
const HOLD_OFFSET := Vector3(-0.24, -0.05, -0.1)
## Coude gauche : vers l'extérieur et le bas (repère du corps, à partir de l'épaule).
const ELBOW_POLE_OFFSET := Vector3(-0.45, -0.45, 0.15)

## Nombre de bûches portées.
var count := 0
## Or porté dans le sac à dos.
var gold := 0

## Objet visé au sol : une bûche (`WoodLog`) ou un sac d'or (`GoldSack`).
var _target: RigidBody3D
var _prompt := ""
var _stack_root: Node3D
var _stack: Array[Node3D] = []
## Bûche qui vient d'apparaître sur la pile et le temps écoulé depuis (petit « pop » d'apparition).
var _popping: Node3D
var _pop_time := 0.0
## Poids de la main gauche sur la pile (monte en douceur à la première bûche).
var _left_weight := 0.0
## Dépôt dans la zone duquel se trouve le joueur (null hors de toute zone).
var _stockpile: WoodStockpile
## Déchargement en cours et temps restant avant le prochain rondin.
var _unloading := false
var _unload_timer := 0.0
## Choc de bois du ramassage, non spatialisé (la pile est sur l'épaule du joueur).
var _pickup_audio: AudioStreamPlayer
## Mine à l'intérieur de laquelle se trouve le joueur (null dehors).
var _mine: GoldMine
## Chantier à portée (null si aucun).
var _site: CampBuilding
var _progress := -1.0
var _work_sound_timer := 0.0

@onready var _player: Player = owner
@onready var _body: FirstPersonBody = owner.get_node("Body")
@onready var _camera: Camera3D = owner.get_node("Head/Camera3D")


func _ready() -> void:
	_stack_root = Node3D.new()
	_stack_root.name = "LogStack"
	_body.add_child.call_deferred(_stack_root)
	_pickup_audio = AudioStreamPlayer.new()
	_pickup_audio.name = "PickupAudio"
	_pickup_audio.volume_db = GameConfig.PICKUP_SOUND_VOLUME_DB
	_pickup_audio.max_polyphony = 4
	add_child(_pickup_audio)
	load_changed.emit.call_deferred(count, GameConfig.BASE_WOOD_CAPACITY)


func _physics_process(delta: float) -> void:
	if _stack_root.is_inside_tree():
		_stack_root.position = _body.get_left_shoulder_local() + STACK_OFFSET
	_update_target()
	_site = _find_site()
	var can_pick := _can_pick()
	var can_deposit := _stockpile != null and (count > 0 or (gold > 0 and _stockpile.accepts_gold))
	var progress := -1.0
	if _player.is_dead():
		_unloading = false
	elif Input.is_action_just_pressed("interact") and can_pick:
		if _target is GoldSack:
			_pick_up_sack(_target as GoldSack)
		else:
			pick_up(_target as WoodLog)
	elif Input.is_action_just_pressed("interact") and can_deposit:
		_unloading = count > 0
		if gold > 0 and _stockpile.accepts_gold:
			CampEconomy.instance.add_gold(gold)
			_set_gold(0)
			_play_knock(1.6)
	elif Input.is_action_pressed("interact") and not can_pick and not can_deposit and _site:
		_site.work(delta)
		progress = _site.build_progress
		_work_feedback(delta)
	if progress != _progress:
		_progress = progress
		progress_changed.emit(progress)
	_update_prompt(can_pick, can_deposit)
	_update_unload(delta)
	_update_pop(delta)
	_hold_stack(delta)


# --- Visée ------------------------------------------------------------------------------------

func _update_target() -> void:
	var from := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - _camera.global_basis.z * GameConfig.PICKUP_RANGE, 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_target = hit.collider as RigidBody3D if not hit.is_empty() else null
	if _target and (_target.is_queued_for_deletion() or not (_target is WoodLog or _target is GoldSack)):
		_target = null


## Peut-on ramasser l'objet visé ? Bois et or s'excluent, et chaque charge a sa capacité.
func _can_pick() -> bool:
	if _target is WoodLog:
		return gold == 0 and count < GameConfig.BASE_WOOD_CAPACITY
	if _target is GoldSack:
		return count == 0 and gold < GameConfig.BASE_GOLD_CAPACITY
	return false


func _update_prompt(can_pick: bool, can_deposit: bool) -> void:
	var text := ""
	if _player.is_dead():
		text = ""
	elif can_pick:
		text = "[E] Ramasser le sac d'or (%d)" % (_target as GoldSack).amount if _target is GoldSack else "[E] Ramasser"
	elif can_deposit:
		if _unloading:
			text = ""
		elif count > 0:
			text = "[E] Déposer le bois (%d)" % count
		else:
			text = "[E] Déposer l'or (%d)" % gold
	elif _site:
		text = "[E] Construire : %s (maintenir)" % _site.building_name
	elif _target is WoodLog and gold > 0:
		text = "Dépose d'abord ton or"
	elif _target is GoldSack and count > 0:
		text = "Dépose d'abord ton bois"
	elif _target is WoodLog:
		text = "Charge pleine (%d/%d)" % [count, GameConfig.BASE_WOOD_CAPACITY]
	elif _target is GoldSack:
		text = "Sac plein (%d/%d)" % [gold, GameConfig.BASE_GOLD_CAPACITY]
	elif _mine and count > 0:
		text = "Dépose d'abord ton bois pour miner"
	elif _mine and gold >= GameConfig.BASE_GOLD_CAPACITY:
		text = "Sac plein : rapporte l'or au bastion"
	elif _mine:
		text = "Frappe une veine d'or à la pioche (clic gauche)"
	_set_prompt(text)


func _set_prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


# --- Ramassage --------------------------------------------------------------------------------

## La bûche part en fumée et réapparaît sur la pile.
func pick_up(wood_log: WoodLog) -> void:
	var poof: Node3D = POOF_SCENE.instantiate()
	wood_log.get_parent().add_child(poof)
	poof.global_transform = Transform3D(wood_log.global_basis.orthonormalized(), wood_log.global_position)
	wood_log.queue_free()
	_pickup_audio.stream = PICKUP_SOUNDS.pick_random()
	# Un peu plus aigu à chaque bûche : la pile qui monte s'entend.
	_pickup_audio.pitch_scale = GameConfig.PICKUP_SOUND_PITCH + GameConfig.PICKUP_SOUND_PITCH_PER_LOG * count \
		+ randf_range(-GameConfig.PICKUP_SOUND_PITCH_JITTER, GameConfig.PICKUP_SOUND_PITCH_JITTER)
	_pickup_audio.play()

	var carried := _make_log_visual()
	_stack_root.add_child(carried)
	carried.transform = _slot_transform(count)
	_stack.append(carried)
	_popping = carried
	_pop_time = 0.0
	_update_pop(0.0)
	count += 1
	load_changed.emit(count, GameConfig.BASE_WOOD_CAPACITY)


## Apparition sur la pile : la bûche grossit de 0 à sa taille en dépassant un peu (rebond).
func _update_pop(delta: float) -> void:
	if _popping == null:
		return
	_pop_time += delta
	var t := clampf(_pop_time / GameConfig.PICKUP_POP_TIME, 0.0, 1.0)
	var overshoot := 1.70158
	var bounce := 1.0 + (overshoot + 1.0) * pow(t - 1.0, 3.0) + overshoot * pow(t - 1.0, 2.0)
	var slot := _slot_transform(_stack.find(_popping))
	_popping.transform = Transform3D(slot.basis.scaled(Vector3.ONE * maxf(bounce, 0.001)), slot.origin)
	if t >= 1.0:
		_popping = null


# --- Or ------------------------------------------------------------------------------------------

## Appelé par la mine quand le joueur y entre : il sort sa pioche.
func enter_mine(mine: GoldMine) -> void:
	_mine = mine
	_body.set_pickaxe(true)


## Appelé par la mine quand le joueur en sort : il reprend sa hache.
func exit_mine(mine: GoldMine) -> void:
	if _mine == mine:
		_mine = null
		_body.set_pickaxe(false)


## Coup de pioche réussi sur une veine : l'or va dans le sac à dos, s'il reste de la place et qu'on
## ne porte pas de bois.
func mine_vein(vein: GoldVein) -> void:
	if count > 0 or gold >= GameConfig.BASE_GOLD_CAPACITY:
		return
	var taken := vein.extract(mini(GameConfig.GOLD_PER_SWING, GameConfig.BASE_GOLD_CAPACITY - gold))
	if taken > 0:
		_set_gold(gold + taken)


func _pick_up_sack(sack: GoldSack) -> void:
	var taken := mini(sack.amount, GameConfig.BASE_GOLD_CAPACITY - gold)
	sack.amount -= taken
	if sack.amount <= 0:
		sack.queue_free()
	_set_gold(gold + taken)
	_play_knock(1.6)


func _set_gold(amount: int) -> void:
	gold = amount
	_body.set_backpack_fill(float(gold) / GameConfig.BASE_GOLD_CAPACITY)
	gold_changed.emit(gold)


# --- Chantiers -----------------------------------------------------------------------------------

## Chantier du camp le plus proche à portée de travail.
func _find_site() -> CampBuilding:
	var nearest: CampBuilding = null
	var best := GameConfig.BUILD_RANGE
	for node in get_tree().get_nodes_in_group("camp_buildings"):
		var building := node as CampBuilding
		if building.state != CampBuilding.State.UNDER_CONSTRUCTION:
			continue
		var distance := Vector2(building.global_position.x - global_position.x,
			building.global_position.z - global_position.z).length() - building.get_target_radius()
		if distance < best:
			best = distance
			nearest = building
	return nearest


## Pendant qu'on mine ou qu'on construit : coups d'outil réguliers (animation de la hache + choc).
func _work_feedback(delta: float) -> void:
	_player.axe.request_swing()
	_work_sound_timer -= delta
	if _work_sound_timer <= 0.0:
		_work_sound_timer = GameConfig.AXE_SWING_DURATION
		_play_knock(0.9)


func _play_knock(pitch: float) -> void:
	_pickup_audio.stream = PICKUP_SOUNDS.pick_random()
	_pickup_audio.pitch_scale = pitch + randf_range(-GameConfig.PICKUP_SOUND_PITCH_JITTER, GameConfig.PICKUP_SOUND_PITCH_JITTER)
	_pickup_audio.play()


## Le joueur est mort : sa charge tombe au sol, où elle peut être ramassée (§4.5).
func drop_on_ground() -> void:
	var world := _player.get_parent()
	var origin := _player.global_position + Vector3(0.0, 1.0, 0.0)
	for index in count:
		var wood_log: WoodLog = LOG_SCENE.instantiate()
		world.add_child(wood_log)
		# En couronne autour du corps, pour ne pas naître dans sa capsule de collision.
		var around := Vector3.FORWARD.rotated(Vector3.UP, TAU * index / count) * 0.9
		wood_log.global_position = origin + around + Vector3(0.0, index * 0.12, 0.0)
		wood_log.rotation.y = randf() * TAU
	if gold > 0:
		var sack := GoldSack.new()
		sack.amount = gold
		world.add_child(sack)
		sack.global_position = origin
	for carried in _stack:
		carried.queue_free()
	_stack.clear()
	_popping = null
	_unloading = false
	count = 0
	load_changed.emit(count, GameConfig.BASE_WOOD_CAPACITY)
	_set_gold(0)


# --- Dépôt au camp ----------------------------------------------------------------------------

## Appelé par le dépôt quand le joueur entre dans sa zone.
func enter_stockpile(stockpile: WoodStockpile) -> void:
	_stockpile = stockpile
	if GameConfig.STOCKPILE_AUTO_DEPOSIT and count > 0:
		_unloading = true


## Appelé par le dépôt quand le joueur sort de sa zone : le déchargement s'arrête, le reste est gardé.
func exit_stockpile(stockpile: WoodStockpile) -> void:
	if _stockpile == stockpile:
		_stockpile = null
		_unloading = false


## Décharge la pile un rondin à la fois, celui du dessus d'abord.
func _update_unload(delta: float) -> void:
	if not _unloading:
		_unload_timer = 0.0
		return
	_unload_timer -= delta
	while _unload_timer <= 0.0 and count > 0:
		_unload_timer += GameConfig.STOCKPILE_UNLOAD_INTERVAL
		_stockpile.receive_log(_take_top_log())
	if count == 0:
		_unloading = false


## Retire la bûche du dessus de la pile portée et renvoie son transform global (départ du vol).
func _take_top_log() -> Transform3D:
	var carried: Node3D = _stack.pop_back()
	if carried == _popping:
		_popping = null
	var from := Transform3D(carried.global_basis, carried.global_position)
	carried.queue_free()
	count -= 1
	load_changed.emit(count, GameConfig.BASE_WOOD_CAPACITY)
	return from


# --- Pile sur l'épaule -------------------------------------------------------------------------

## Main gauche sur le flanc de la pile tant qu'on porte du bois, bras libre sinon.
func _hold_stack(delta: float) -> void:
	var pole := _body.to_global(_body.get_left_shoulder_local() + ELBOW_POLE_OFFSET)
	_left_weight = move_toward(_left_weight, 1.0 if count > 0 else 0.0, delta / GameConfig.PICKUP_POP_TIME)
	if _left_weight <= 0.0:
		_body.hold_left_hand_at(_left_hand_rest(), pole, 0.0)
		return
	_body.hold_left_hand_at(_stack_root.to_global(HOLD_OFFSET), pole, smoothstep(0.0, 1.0, _left_weight))


func _left_hand_rest() -> Vector3:
	return _body.to_global(_body.get_left_shoulder_local() + Vector3(-0.05, -0.55, -0.05))


## Emplacement de la `index`-ième bûche dans la pile (repère de la pile).
func _slot_transform(index: int) -> Transform3D:
	var radius := LOG_RADIUS * GameConfig.CARRIED_LOG_SCALE
	var row := 0
	var first := 0
	while row < ROWS.size() - 1 and index >= first + ROWS[row]:
		first += ROWS[row]
		row += 1
	var in_row := index - first
	var x := (float(in_row) - (ROWS[row] - 1) * 0.5) * radius * 2.05
	var y := row * radius * 1.75
	# Un peu de désordre, stable pour chaque emplacement.
	var jitter := Basis.from_euler(Vector3(0.0, sin(index * 12.9) * 0.08, sin(index * 7.3) * 0.25))
	var along_z := Basis(Vector3.UP, PI * 0.5)
	return Transform3D((jitter * along_z).scaled(Vector3.ONE * GameConfig.CARRIED_LOG_SCALE),
		Vector3(x, y, sin(index * 3.1) * 0.03))


## Bûche portée : visible (z-clip, sans ombre) + copie qui ne fait que l'ombre.
func _make_log_visual() -> Node3D:
	var root := Node3D.new()
	var visible_log: Node3D = LOG_MODEL.instantiate()
	for mesh_instance: GeometryInstance3D in visible_log.find_children("*", "GeometryInstance3D", true, false):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ZClip.apply(visible_log)
	root.add_child(visible_log)
	var shadow_log: Node3D = LOG_MODEL.instantiate()
	for mesh_instance: GeometryInstance3D in shadow_log.find_children("*", "GeometryInstance3D", true, false):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	root.add_child(shadow_log)
	return root
