class_name ClassCard
extends Control
## Class selection card: emblem, name, role, core mechanic, description; hover lift + selection glow.

signal chosen(class_id: String)

var class_id: String = "vanguard"
var selected: bool = false
var hover: bool = false
var t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hover = true)
	mouse_exited.connect(func(): hover = false)
	var info: Dictionary = MainMenuText.CLASSES[class_id]
	var acc: Color = UITheme.CLASS_ACCENT[class_id]
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 150
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var n := UITheme.title(class_id.to_upper(), 28, acc.lightened(0.35))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var r := UITheme.text(info.role, 14, UITheme.GOLD, true)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	var core := UITheme.text(info.core, 13, UITheme.PARCHMENT)
	core.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(core)
	var d := UITheme.text(info.text, 14, UITheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(260, 0)
	v.add_child(d)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(class_id)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var acc: Color = UITheme.CLASS_ACCENT[class_id]
	var lift := -6.0 if (hover or selected) else 0.0
	var r := Rect2(Vector2(0, lift), size)
	draw_rect(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, Color(0.06, 0.05, 0.05, 0.95))
	# accent wash at top
	for i in 30:
		var a := 0.22 * (1.0 - i / 30.0)
		draw_rect(Rect2(r.position + Vector2(0, i * 4), Vector2(r.size.x, 4)), Color(acc.r, acc.g, acc.b, a))
	var border := acc.lightened(0.2) if selected else (UITheme.GOLD if hover else UITheme.GOLD_DIM)
	draw_rect(r, border, false, 2.5 if selected else 1.5)
	if selected:
		draw_rect(r.grow(4 + sin(t * 4.0)), Color(acc.r, acc.g, acc.b, 0.35), false, 2.0)
	# emblem
	var c := r.position + Vector2(r.size.x * 0.5, 78)
	draw_circle(c, 54, Color(0.03, 0.025, 0.03, 1.0))
	draw_circle(c, 48, acc.darkened(0.65))
	GameIcon.draw_icon(self, class_id, Rect2(c - Vector2(30, 32), Vector2(60, 60)), acc.lightened(0.35))
	draw_arc(c, 54, 0, TAU, 64, UITheme.GOLD, 2.0, true)
	draw_arc(c, 58, 0, TAU, 64, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.4), 1.0, true)
	# corner ornaments
	for p in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end]:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), UITheme.GOLD)
	for ch in get_children():
		ch.position.y = 150 + lift
