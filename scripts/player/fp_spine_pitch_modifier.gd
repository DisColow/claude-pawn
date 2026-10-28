class_name FpSpinePitchModifier
extends SkeletonModifier3D
## Penche le buste avec le regard (haut/bas) pour que bras et hache suivent la visée,
## en répartissant l'angle sur les vertèbres.

## Vertèbres et part de l'inclinaison appliquée à chacune.
const SPINE_SHARES := {"spine_01": 0.06, "spine_02": 0.1, "spine_03": 0.14}

## Inclinaison du regard (rad, positif = vers le haut). Écrit par FirstPersonBody.
var pitch := 0.0
## Axe "droite" du personnage dans l'espace global. Écrit par FirstPersonBody.
var right_axis := Vector3.RIGHT

var _bones: Dictionary = {}


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or absf(pitch) < 0.0001:
		return
	if _bones.is_empty():
		for bone_name: String in SPINE_SHARES:
			_bones[bone_name] = skeleton.find_bone(bone_name)
	var axis := (skeleton.global_basis.inverse() * right_axis).normalized()
	for bone_name: String in SPINE_SHARES:
		var bone: int = _bones[bone_name]
		if bone < 0:
			continue
		var pose := skeleton.get_bone_global_pose(bone)
		pose.basis = Basis(axis, pitch * SPINE_SHARES[bone_name] * influence) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
