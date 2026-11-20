class_name UITheme
extends RefCounted
## Fantasy ARPG theme built from code (StyleBoxFlat + free OFL fonts: Cinzel / Alegreya Sans).
## One shared Theme is applied to every UI root so all native Controls (Button, CheckBox, SpinBox,
## OptionButton, TabContainer, ScrollBar, ProgressBar, Tooltip...) look consistent.

const GOLD := Color(0.86, 0.68, 0.38)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.52)
const GOLD_DIM := Color(0.52, 0.4, 0.24)
const PARCHMENT := Color(0.94, 0.89, 0.78)
const TEXT_DIM := Color(0.68, 0.64, 0.58)
const INK := Color(0.055, 0.048, 0.052, 0.92)
const INK_SOFT := Color(0.09, 0.075, 0.075, 0.88)
const HP := Color(0.78, 0.13, 0.12)
const HP_HI := Color(0.95, 0.3, 0.25)
const STAMINA := Color(0.36, 0.72, 0.32)
const MANA := Color(0.28, 0.5, 0.98)
const RESOLVE := Color(1.0, 0.74, 0.25)
const POISE := Color(0.92, 0.8, 0.45)
const EXP := Color(0.7, 0.86, 0.35)
const CLASS_ACCENT := {"vanguard": Color(0.95, 0.78, 0.42), "mage": Color(0.45, 0.74, 1.0), "reaver": Color(0.95, 0.3, 0.25)}
const BURGUNDY := Color(0.42, 0.1, 0.12)
const CHARCOAL := Color(0.07, 0.065, 0.07)
const RARITY := {"standard": Color(0.78, 0.78, 0.8), "advanced": Color(0.35, 0.68, 1.0), "exotic": Color(1.0, 0.58, 0.18)}
const ELEMENT := {
	"fire": Color(1.0, 0.45, 0.15), "life": Color(0.4, 1.0, 0.5), "frost": Color(0.55, 0.85, 1.0),
	"storm": Color(0.78, 0.68, 1.0), "stone": Color(0.78, 0.6, 0.38), "": Color(0.35, 0.35, 0.35),
}

static var _theme: Theme
static var _title_font: Font
static var _title_font_bold: Font
static var _body_font: Font
static var _body_bold: Font


static func title_font(bold: bool = true) -> Font:
	_ensure_fonts()
	return _title_font_bold if bold else _title_font


static func body_font(bold: bool = false) -> Font:
	_ensure_fonts()
	return _body_bold if bold else _body_font


static func _ensure_fonts() -> void:
	if _body_font != null:
		return
	var cinzel = load("res://assets/fonts/Cinzel-Variable.ttf")
	var body = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	var bold = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	if cinzel == null or body == null:
		_title_font = ThemeDB.fallback_font
		_title_font_bold = ThemeDB.fallback_font
		_body_font = ThemeDB.fallback_font
		_body_bold = ThemeDB.fallback_font
		return
	var t := FontVariation.new()
	t.base_font = cinzel
	t.variation_opentype = {2003265652: 500}  # OpenType tag "wght"
	_title_font = t
	var tb := FontVariation.new()
	tb.base_font = cinzel
	tb.variation_opentype = {2003265652: 750}  # OpenType tag "wght"
	tb.spacing_glyph = 1
	_title_font_bold = tb
	_body_font = body
	_body_bold = bold if bold else body


static func box(bg: Color, border: Color = GOLD_DIM, bw: int = 1, radius: int = 3, margin: float = 10.0, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.55)
	return s


## Ornate panel: dark ink, thin gold rim, slightly brighter top edge, soft shadow.
static func panel(accent: Color = GOLD_DIM, alpha: float = 0.9) -> StyleBoxFlat:
	var s := box(Color(INK.r, INK.g, INK.b, alpha), accent, 1, 4, 14.0, 10)
	s.border_width_top = 2
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_ensure_fonts()
	var th := Theme.new()
	th.default_font = _body_font
	th.default_font_size = 16
	# Labels
	th.set_color("font_color", "Label", PARCHMENT)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 4)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	# Panels
	th.set_stylebox("panel", "PanelContainer", panel())
	th.set_stylebox("panel", "Panel", panel())
	th.set_stylebox("panel", "TooltipPanel", box(Color(0.06, 0.05, 0.05, 0.97), GOLD, 1, 3, 10))
	th.set_color("font_color", "TooltipLabel", PARCHMENT)
	th.set_font("font", "TooltipLabel", _body_font)
	# Buttons
	var bn := box(Color(0.13, 0.105, 0.095, 0.95), GOLD_DIM, 1, 3, 12.0)
	bn.border_width_bottom = 2
	var bh := box(Color(0.2, 0.155, 0.12, 0.98), GOLD, 1, 3, 12.0)
	bh.border_width_bottom = 2
	bh.shadow_color = Color(1.0, 0.7, 0.3, 0.25)
	bh.shadow_size = 6
	var bp := box(Color(0.3, 0.22, 0.13, 1.0), GOLD_BRIGHT, 1, 3, 12.0)
	var bd := box(Color(0.1, 0.1, 0.1, 0.7), Color(0.3, 0.3, 0.3), 1, 3, 12.0)
	var bf := box(Color(0, 0, 0, 0), GOLD_BRIGHT, 1, 3, 12.0)
	for cls in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", cls, bn)
		th.set_stylebox("hover", cls, bh)
		th.set_stylebox("pressed", cls, bp)
		th.set_stylebox("hover_pressed", cls, bp)
		th.set_stylebox("disabled", cls, bd)
		th.set_stylebox("focus", cls, bf)
		th.set_color("font_color", cls, PARCHMENT)
		th.set_color("font_hover_color", cls, GOLD_BRIGHT)
		th.set_color("font_pressed_color", cls, Color(1, 0.95, 0.85))
		th.set_color("font_hover_pressed_color", cls, Color(1, 0.95, 0.85))
		th.set_color("font_disabled_color", cls, Color(0.5, 0.5, 0.5))
		th.set_font("font", cls, _title_font)
		th.set_font_size("font_size", cls, 15)
	# Check boxes (custom drawn icons)
	var empty := StyleBoxEmpty.new()
	for cls in ["CheckBox", "CheckButton"]:
		th.set_stylebox("normal", cls, empty)
		th.set_stylebox("hover", cls, box(Color(1, 0.8, 0.5, 0.06), Color(0, 0, 0, 0), 0, 3, 4.0))
		th.set_stylebox("pressed", cls, empty)
		th.set_stylebox("hover_pressed", cls, box(Color(1, 0.8, 0.5, 0.06), Color(0, 0, 0, 0), 0, 3, 4.0))
		th.set_stylebox("focus", cls, empty)
		th.set_color("font_color", cls, PARCHMENT)
		th.set_color("font_hover_color", cls, GOLD_BRIGHT)
		th.set_color("font_pressed_color", cls, PARCHMENT)
		th.set_color("font_hover_pressed_color", cls, GOLD_BRIGHT)
		th.set_icon("checked", cls, _check_icon(true))
		th.set_icon("unchecked", cls, _check_icon(false))
		th.set_constant("h_separation", cls, 8)
	# Line edits / spin boxes
	th.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.035, 0.035, 0.95), GOLD_DIM, 1, 2, 6.0))
	th.set_stylebox("focus", "LineEdit", box(Color(0.06, 0.05, 0.04, 0.95), GOLD, 1, 2, 6.0))
	th.set_color("font_color", "LineEdit", PARCHMENT)
	# Progress bars
	th.set_stylebox("background", "ProgressBar", box(Color(0.03, 0.03, 0.03, 0.9), Color(0, 0, 0, 0.8), 1, 2, 0))
	th.set_stylebox("fill", "ProgressBar", box(GOLD, Color(0, 0, 0, 0), 0, 2, 0))
	# Popups / option lists
	th.set_stylebox("panel", "PopupMenu", box(Color(0.07, 0.06, 0.06, 0.98), GOLD_DIM, 1, 3, 8.0))
	th.set_stylebox("hover", "PopupMenu", box(Color(0.3, 0.22, 0.12, 0.9), Color(0, 0, 0, 0), 0, 2, 4.0))
	th.set_color("font_color", "PopupMenu", PARCHMENT)
	th.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	# Tabs
	var tab_sel := box(Color(0.16, 0.12, 0.09, 1.0), GOLD, 1, 3, 10.0)
	tab_sel.border_width_bottom = 0
	tab_sel.border_width_top = 2
	var tab_un := box(Color(0.07, 0.06, 0.06, 0.9), GOLD_DIM, 1, 3, 10.0)
	tab_un.border_width_bottom = 0
	th.set_stylebox("tab_selected", "TabContainer", tab_sel)
	th.set_stylebox("tab_unselected", "TabContainer", tab_un)
	th.set_stylebox("tab_hovered", "TabContainer", box(Color(0.12, 0.09, 0.07, 1.0), GOLD, 1, 3, 10.0))
	th.set_stylebox("panel", "TabContainer", box(Color(0.06, 0.05, 0.05, 0.6), GOLD_DIM, 1, 3, 10.0))
	th.set_color("font_selected_color", "TabContainer", GOLD_BRIGHT)
	th.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	th.set_color("font_hovered_color", "TabContainer", PARCHMENT)
	th.set_font("font", "TabContainer", _title_font)
	th.set_font_size("font_size", "TabContainer", 13)
	# Scrollbars
	var grab := box(GOLD_DIM, Color(0, 0, 0, 0), 0, 3, 0)
	var grab_h := box(GOLD, Color(0, 0, 0, 0), 0, 3, 0)
	var track := box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3, 0)
	for cls in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("grabber", cls, grab)
		th.set_stylebox("grabber_highlight", cls, grab_h)
		th.set_stylebox("grabber_pressed", cls, grab_h)
		th.set_stylebox("scroll", cls, track)
	# Rich text
	th.set_font("normal_font", "RichTextLabel", _body_font)
	th.set_font("bold_font", "RichTextLabel", _body_bold)
	th.set_color("default_color", "RichTextLabel", PARCHMENT)
	th.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	_theme = th
	return th


static func _check_icon(on: bool) -> ImageTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(n - 1) * 0.5
	for y in n:
		for x in n:
			var d := absf(x - c) + absf(y - c)   # diamond distance
			if d <= c and d >= c - 1.5:
				img.set_pixel(x, y, GOLD)
			elif d < c - 1.5:
				img.set_pixel(x, y, Color(0.05, 0.04, 0.04, 0.95))
			if on and d <= c - 4.0:
				img.set_pixel(x, y, GOLD_BRIGHT)
	return ImageTexture.create_from_image(img)


static func apply(c: Control) -> void:
	c.theme = get_theme()
	c.layout_direction = Control.LAYOUT_DIRECTION_LTR
	c.set("physics_interpolation_mode", 2)


static func title(text: String, size: int = 22, color: Color = GOLD_BRIGHT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	return l


static func text(t: String, size: int = 16, color: Color = PARCHMENT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", body_font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Ornamental divider: ——◆—— (drawn), optional centred caption.
static func divider(width: float = 300.0, caption: String = "") -> Control:
	var d := OrnamentDivider.new()
	d.caption = caption
	d.custom_minimum_size = Vector2(width, 18 if caption == "" else 26)
	return d


## Hover feedback: lift + brighten on any Control.
static func add_hover(c: Control, scale_to: float = 1.03) -> void:
	c.mouse_entered.connect(func():
		c.pivot_offset = c.size * 0.5
		var tw := c.create_tween()
		tw.set_parallel(true)
		tw.tween_property(c, "scale", Vector2.ONE * scale_to, 0.12).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(c, "modulate", Color(1.12, 1.08, 1.0), 0.12))
	c.mouse_exited.connect(func():
		var tw := c.create_tween()
		tw.set_parallel(true)
		tw.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(c, "modulate", Color(1, 1, 1), 0.15))
