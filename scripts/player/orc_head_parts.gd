class_name OrcHeadParts
## Oreilles pointues et défenses de l'orc, greffées sur l'os "Head" du personnage de base.
## Repère de l'os Head (modèle regardant vers +Z) : tête de ±0,09 m de large, oreilles à ~0,10 m
## au-dessus de l'os, mâchoire inférieure devant à ~0,09 m.

const EAR_SCENE := preload("res://assets/models/characters/orc_ear.glb")
const TUSKS_SCENE := preload("res://assets/models/characters/orc_tusks.glb")
## Couleur de la peau de l'orc (médiane de sa texture), appliquée aux oreilles non texturées.
const SKIN_COLOR := Color(0.282, 0.376, 0.169)

## Repère du modèle d'oreille : couché à plat (épaisseur selon Y), base à l'origine, pointe vers -X/+Z.
const EAR_MODEL_TIP := Vector3(-0.89, 0.0, 0.45)
## Oreille du côté -X : pointe vers l'arrière, en haut et un peu vers l'extérieur, face large tournée
## vers l'extérieur. L'oreille du côté +X en est le miroir.
static var EAR_TRANSFORM := _ear_transform(Vector3(-0.62, 0.38, -0.69), Vector3(-0.08, 0.075, -0.01), 1.3)
## Défenses (base vers -Z, pointe vers +Z dans le modèle) redressées : bases dans la mâchoire
## inférieure, pointes qui remontent devant la lèvre supérieure.
static var TUSKS_TRANSFORM := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-80.0)), Vector3(0.0, 0.03, 0.1))


static func _ear_transform(tip: Vector3, base: Vector3, size: float) -> Transform3D:
	var model_tip := EAR_MODEL_TIP.normalized()
	var model := Basis(model_tip, Vector3.UP, model_tip.cross(Vector3.UP))
	var world_tip := tip.normalized()
	var outward := Vector3.LEFT if base.x < 0.0 else Vector3.RIGHT
	var normal := (outward - world_tip * outward.dot(world_tip)).normalized()
	var world := Basis(world_tip, normal, world_tip.cross(normal))
	return Transform3D((world * model.inverse()).scaled_local(Vector3.ONE * size), base)


## Greffe oreilles et défenses sur `skeleton`. Renvoie les nœuds créés (pour régler l'ombre / le z-clip).
static func attach(skeleton: Skeleton3D) -> Array[Node3D]:
	var attachment := BoneAttachment3D.new()
	attachment.name = "HeadParts"
	skeleton.add_child(attachment)
	attachment.bone_name = "Head"

	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN_COLOR
	skin.roughness = 0.8

	var parts: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var ear: Node3D = EAR_SCENE.instantiate()
		ear.name = "EarLeft" if side > 0.0 else "EarRight"
		ear.transform = Transform3D.FLIP_X * EAR_TRANSFORM if side > 0.0 else EAR_TRANSFORM
		for mesh_instance: MeshInstance3D in ear.find_children("*", "MeshInstance3D", true, false):
			mesh_instance.material_override = skin
		attachment.add_child(ear)
		parts.append(ear)

	var tusks: Node3D = TUSKS_SCENE.instantiate()
	tusks.name = "Tusks"
	tusks.transform = TUSKS_TRANSFORM
	attachment.add_child(tusks)
	parts.append(tusks)
	return parts
