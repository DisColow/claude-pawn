class_name FpFinalizeModifier
extends SkeletonModifier3D
## Dernier modificateur de la vue subjective :
## 1. aligne la rotation de la main droite sur la cible (après l'IK, qui ne gère que la position) ;
## 2. recopie la pose finale sur le squelette d'ombre (ombre portée complète, tête comprise) ;
## 3. masque le cou et la tête du corps visible pour que la caméra ne voie jamais l'intérieur du crâne.

var hand_bone_name := "hand_r"
var head_bone_name := "neck_01"
## Rotation globale voulue pour la main (null = ne pas forcer).
var hand_target: Node3D
var shadow_skeleton: Skeleton3D

var _hand := -1
var _head := -1


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _hand < 0:
		_hand = skeleton.find_bone(hand_bone_name)
		_head = skeleton.find_bone(head_bone_name)

	if hand_target and _hand >= 0:
		var pose := skeleton.get_bone_global_pose(_hand)
		pose.basis = (skeleton.global_basis.inverse() * hand_target.global_basis).orthonormalized()
		skeleton.set_bone_global_pose(_hand, pose)

	if shadow_skeleton:
		for bone in skeleton.get_bone_count():
			shadow_skeleton.set_bone_pose(bone, skeleton.get_bone_pose(bone))

	if _head >= 0:
		skeleton.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
