class_name UiStyle
extends RefCounted

static func font(weight: int = 700) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Arial"])
	f.font_weight = weight
	return f


static func theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(600)
	theme.default_font_size = 18
	return theme


static func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.08, 0.82)
	box.border_color = Color(0.25, 0.85, 1.0, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func button(text: String, width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.08, 0.1))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.08, 0.1))
	b.add_theme_color_override("font_focus_color", Color(0.05, 0.08, 0.1))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.07, 0.1, 0.92)
	normal.border_color = Color(0.2, 0.82, 1.0, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.35, 0.92, 1.0, 0.96)
	hover.border_color = Color(1, 1, 1, 0.9)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.95, 0.62, 0.22, 0.98)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	return b
