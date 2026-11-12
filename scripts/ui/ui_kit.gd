class_name UiKit
## Petits éléments d'interface partagés (HUD, menu) : mêmes couleurs, mêmes contours partout.

const TEXT := Color(0.96, 0.9, 0.78)
const GOLD := Color(0.92, 0.66, 0.16)
const DIM := Color(0.72, 0.7, 0.66)
const PANEL := Color(0.1, 0.13, 0.17, 0.82)
const OUTLINE := Color(0.06, 0.05, 0.03)


static func label(parent: Control, font_size: int, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.horizontal_alignment = alignment
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", OUTLINE)
	node.add_theme_constant_override("outline_size", 5)
	node.add_theme_font_size_override("font_size", font_size)
	parent.add_child(node)
	return node


static func bar(parent: Control, fill_color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background", box(Color(0.03, 0.03, 0.03, 0.7), 4))
	node.add_theme_stylebox_override("fill", box(fill_color, 4))
	parent.add_child(node)
	return node


static func panel(parent: Control, color: Color = PANEL, radius: int = 6) -> Panel:
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", box(color, radius))
	parent.add_child(node)
	return node


static func box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
	return style


static func button(parent: Control, text: String, font_size: int = 20) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_stylebox_override("normal", box(Color(0.16, 0.2, 0.26, 0.95), 6))
	node.add_theme_stylebox_override("hover", box(Color(0.24, 0.3, 0.38, 0.98), 6))
	node.add_theme_stylebox_override("pressed", box(Color(0.6, 0.42, 0.1, 1.0), 6))
	node.add_theme_stylebox_override("disabled", box(Color(0.12, 0.13, 0.15, 0.8), 6))
	node.add_theme_stylebox_override("focus", box(Color(0.24, 0.3, 0.38, 0.98), 6))
	parent.add_child(node)
	return node


## Place un Control : ancrage `preset`, puis décalages (gauche, haut, droite, bas).
static func place(node: Control, preset: Control.LayoutPreset, left: float, top: float, right: float, bottom: float) -> void:
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom
