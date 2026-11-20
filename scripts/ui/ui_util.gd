class_name UIUtil
extends RefCounted
## Small helpers to build readable debug-style UI in code.


static func panel_style(bg: Color = Color(0.06, 0.05, 0.05, 0.82), border: Color = Color(0.5, 0.35, 0.2)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func bar(color: Color, width: float = 260.0, height: float = 16.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(width, height)
	pb.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	bg.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("fill", fill)
	pb.add_theme_stylebox_override("background", bg)
	return pb


static func label(text: String, size: int = 14, color: Color = UITheme.PARCHMENT) -> Label:
	return UITheme.text(text, size, color)


static func button(text: String, fn: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 0)
	b.pressed.connect(fn)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func check(text: String, value: bool, fn: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(fn)
	c.focus_mode = Control.FOCUS_NONE
	return c


static func header(text: String) -> Label:
	var l := UITheme.title(text, 14, UITheme.GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	return l


static func set_mouse_for_ui() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Game.ui_block > 0 else Input.MOUSE_MODE_CAPTURED


## Anchors + offsets in one call (robust for any window size / aspect ratio).
static func place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


## Force left-to-right layout (prevents automatic RTL mirroring on Arabic / Hebrew system locales).
static func ltr(c: Control) -> void:
	c.layout_direction = Control.LAYOUT_DIRECTION_LTR
