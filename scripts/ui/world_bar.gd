class_name WorldBar
extends Node3D
## Petite barre de vie flottante, toujours tournée vers la caméra (au-dessus des unités).

var _size := Vector2(1.0, 0.1)
var _fill: MeshInstance3D


func _init(size: Vector2 = Vector2(1.0, 0.1)) -> void:
	_size = size
	add_child(_make_quad(Color(0.08, 0.06, 0.04), size + Vector2(0.04, 0.04), 0))
	_fill = _make_quad(Color(0.35, 0.8, 0.25), size, 1)
	add_child(_fill)


## Remplissage de 0 à 1 ; la barre se vide vers la gauche et vire au jaune puis au rouge.
func set_ratio(ratio: float) -> void:
	var quad := _fill.mesh as QuadMesh
	quad.size = Vector2(maxf(_size.x * clampf(ratio, 0.0, 1.0), 0.001), _size.y)
	quad.center_offset = Vector3(-(_size.x - quad.size.x) * 0.5, 0.0, 0.0)
	var material := quad.material as StandardMaterial3D
	material.albedo_color = Color(0.85, 0.2, 0.15) if ratio < 0.3 else (Color(0.9, 0.7, 0.2) if ratio < 0.6 else Color(0.35, 0.8, 0.25))


func _make_quad(color: Color, size: Vector2, priority: int) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	material.render_priority = priority
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = quad
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance
