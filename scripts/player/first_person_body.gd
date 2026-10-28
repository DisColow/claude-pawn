class_name FirstPersonBody
extends Node3D
## Corps de l'orc en vue subjective (Body Awareness) :
## - corps complet animé (idle / marche / course / sprint / saut), visible en regardant vers le bas ;
## - tête masquée côté caméra, mais présente dans l'ombre portée (squelette d'ombre dédié) ;
## - bras droit piloté par IK pour tenir la hache animée en espace caméra ;
## - tous les éléments de la vue subjective utilisent le Z-Clip Depth Scaling.

## Points de la blend space de locomotion (vitesse au sol en m/s -> animation).
const LOCOMOTION_POINTS := {"Idle": 0.0, "Walk": 1.8, "Jog_Fwd": 5.2, "Sprint": 8.2}
const AIR_ANIMATION := "Jump"
## Pose de poing fermé (main droite) empruntée à l'animation d'épée.
const GRIP_ANIMATION := "Sword_Idle"
const GRIP_FINGERS := ["index", "middle", "ring", "pinky", "thumb"]

## Position/orientation de la hache dans le repère de l'os hand_r (calibré sur la pose de poing) :
## le manche (+Y de la hache) suit +Z de la main, le tranchant (-X de la hache) suit les doigts (+Y).
## Le modèle de base mesure ~1,82 m : le péon orc est un peu plus massif.
const MODEL_SCALE := 1.05
## Recul du corps (m) quand on regarde vers le bas : le regard passe par-dessus le torse,
## buste et jambes restent visibles sans masquer le sol.
const LOOK_DOWN_BODY_SHIFT := 0.24
## Recul supplémentaire à pleine vitesse (les animations de course penchent le buste en avant).
const SPEED_BODY_SHIFT := 0.2
const AXE_IN_HAND := Transform3D(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(-0.035, 0.095, 0.08))

@export var model_scene: PackedScene = preload("res://assets/models/characters/orc_worker.glb")
@export var axe_scene: PackedScene = preload("res://assets/models/props/axe.glb")

## Inclinaison du regard (rad). Écrite par le joueur.
var look_pitch := 0.0

var skeleton: Skeleton3D
var arm_length := 0.55

var _model: Node3D
var _shadow_model: Node3D
var _anim_tree: AnimationTree
var _spine_modifier: FpSpinePitchModifier
var _arm_ik: TwoBoneIK3D
var _finalize: FpFinalizeModifier
var _hand_target: Node3D
var _elbow_pole: Node3D
var _shoulder_bone := -1
var _air_blend := 0.0
var _base_position := Vector3.ZERO


func _ready() -> void:
	_base_position = position
	# Le modèle glTF regarde vers +Z ; le joueur regarde vers -Z.
	_model = model_scene.instantiate()
	_model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * MODEL_SCALE), Vector3.ZERO)
	add_child(_model)
	_shadow_model = model_scene.instantiate()
	_shadow_model.name = "ShadowModel"
	_shadow_model.transform = _model.transform
	add_child(_shadow_model)

	skeleton = _find(_model, "Skeleton3D")
	var shadow_skeleton: Skeleton3D = _find(_shadow_model, "Skeleton3D")
	var shadow_player: AnimationPlayer = _find(_shadow_model, "AnimationPlayer")
	if shadow_player:
		shadow_player.queue_free()

	_set_shadow_mode(_model, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_set_shadow_mode(_shadow_model, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	ZClip.apply(_model)

	_attach_axe(skeleton, false)
	_attach_axe(shadow_skeleton, true)

	_hand_target = Node3D.new()
	_hand_target.name = "HandTarget"
	add_child(_hand_target)
	_elbow_pole = Node3D.new()
	_elbow_pole.name = "ElbowPole"
	add_child(_elbow_pole)

	_setup_modifiers(shadow_skeleton)
	_setup_animation_tree()

	_shoulder_bone = skeleton.find_bone("upperarm_r")
	var elbow := skeleton.find_bone("lowerarm_r")
	var hand := skeleton.find_bone("hand_r")
	arm_length = (skeleton.get_bone_global_rest(elbow).origin.distance_to(skeleton.get_bone_global_rest(_shoulder_bone).origin)
		+ skeleton.get_bone_global_rest(hand).origin.distance_to(skeleton.get_bone_global_rest(elbow).origin)) * MODEL_SCALE


## Place la main droite pour que la hache soit tenue à `axe_global`. `pole_global` oriente le coude.
func hold_axe_at(axe_global: Transform3D, pole_global: Vector3) -> void:
	_hand_target.global_transform = axe_global * AXE_IN_HAND.affine_inverse()
	_elbow_pole.global_position = pole_global


func get_shoulder_position() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_shoulder_bone).origin


## Met à jour la locomotion. `speed` = vitesse horizontale signée (négative en marche arrière).
func update_locomotion(speed: float, on_floor: bool, delta: float) -> void:
	_air_blend = move_toward(_air_blend, 0.0 if on_floor else 1.0, delta * 6.0)
	_anim_tree.set("parameters/locomotion/blend_position", absf(speed))
	_anim_tree.set("parameters/direction/scale", -1.0 if speed < -0.1 else 1.0)
	_anim_tree.set("parameters/air/blend_amount", _air_blend)
	_spine_modifier.pitch = look_pitch
	var look_down := smoothstep(0.0, deg_to_rad(75.0), -look_pitch)
	var speed_ratio := clampf(absf(speed) / GameConfig.SPRINT_SPEED, 0.0, 1.0)
	var shift := LOOK_DOWN_BODY_SHIFT * look_down + SPEED_BODY_SHIFT * speed_ratio * speed_ratio
	position.z = move_toward(position.z, _base_position.z + shift, delta * 1.5)
	_spine_modifier.right_axis = global_basis.x


# --- Mise en place ------------------------------------------------------------------------

func _setup_modifiers(shadow_skeleton: Skeleton3D) -> void:
	_spine_modifier = FpSpinePitchModifier.new()
	_spine_modifier.name = "SpinePitch"
	skeleton.add_child(_spine_modifier)

	_arm_ik = TwoBoneIK3D.new()
	_arm_ik.name = "RightArmIK"
	skeleton.add_child(_arm_ik)
	_arm_ik.setting_count = 1
	_arm_ik.set_root_bone_name(0, "upperarm_r")
	_arm_ik.set_middle_bone_name(0, "lowerarm_r")
	_arm_ik.set_end_bone_name(0, "hand_r")
	_arm_ik.set_target_node(0, _arm_ik.get_path_to(_hand_target))
	_arm_ik.set_pole_node(0, _arm_ik.get_path_to(_elbow_pole))

	_finalize = FpFinalizeModifier.new()
	_finalize.name = "Finalize"
	_finalize.hand_target = _hand_target
	_finalize.shadow_skeleton = shadow_skeleton
	skeleton.add_child(_finalize)


func _setup_animation_tree() -> void:
	var player: AnimationPlayer = _find(_model, "AnimationPlayer")
	var skeleton_path := String(_model.get_path_to(skeleton))
	var root := AnimationNodeBlendTree.new()

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 9.0
	for animation_name: String in LOCOMOTION_POINTS:
		var clip := AnimationNodeAnimation.new()
		clip.animation = animation_name
		locomotion.add_blend_point(clip, LOCOMOTION_POINTS[animation_name], -1, animation_name)
	root.add_node("locomotion", locomotion)

	var direction := AnimationNodeTimeScale.new()
	root.add_node("direction", direction)
	root.connect_node("direction", 0, "locomotion")

	var jump := AnimationNodeAnimation.new()
	jump.animation = AIR_ANIMATION
	root.add_node("jump", jump)
	var air := AnimationNodeBlend2.new()
	root.add_node("air", air)
	root.connect_node("air", 0, "direction")
	root.connect_node("air", 1, "jump")

	var grip_pose := AnimationNodeAnimation.new()
	grip_pose.animation = GRIP_ANIMATION
	root.add_node("grip_pose", grip_pose)
	var grip := AnimationNodeBlend2.new()
	grip.filter_enabled = true
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		if bone_name.ends_with("_r") and GRIP_FINGERS.any(func(f: String) -> bool: return bone_name.begins_with(f)):
			grip.set_filter_path(NodePath("%s:%s" % [skeleton_path, bone_name]), true)
	root.add_node("grip", grip)
	root.connect_node("grip", 0, "air")
	root.connect_node("grip", 1, "grip_pose")
	root.connect_node("output", 0, "grip")

	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AnimationTree"
	_model.add_child(_anim_tree)
	_anim_tree.anim_player = _anim_tree.get_path_to(player)
	_anim_tree.tree_root = root
	_anim_tree.set("parameters/grip/blend_amount", 1.0)
	_anim_tree.active = true


func _attach_axe(target_skeleton: Skeleton3D, shadow_only: bool) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = "AxeAttachment"
	target_skeleton.add_child(attachment)
	attachment.bone_name = "hand_r"
	var axe: Node3D = axe_scene.instantiate()
	axe.name = "Axe"
	axe.transform = AXE_IN_HAND
	attachment.add_child(axe)
	if shadow_only:
		_set_shadow_mode(axe, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	else:
		_set_shadow_mode(axe, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		ZClip.apply(axe)


func _set_shadow_mode(root: Node, mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	for mesh_instance: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		mesh_instance.cast_shadow = mode


func _find(root: Node, type: String) -> Node:
	var found := root.find_children("*", type, true, false)
	return found[0] if not found.is_empty() else null
