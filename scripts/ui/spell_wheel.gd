class_name SpellWheel
extends Control
## LEVEL10-FOUNDATION-005 Part 3: compact radial selector for the Worldweaver's LMB (Q) / RMB (V) slots.
## Shown while the wheel key is HELD. The mouse stays captured: its motion moves a virtual cursor (the
## camera does not turn while the wheel is open). Every sector is ONE known spell, coloured and labelled by
## element and named, so a spell is never chosen through an ambiguous element. Escape cancels; releasing
## the key over the centre (dead zone) changes nothing. Gameplay keeps running.

const RADIUS := 150.0
const DEADZONE := 28.0
const CURSOR_MAX := 160.0

var cursor: Vector2 = Vector2.ZERO
var _was_open: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _el():
	if not is_instance_valid(Game.player) or Game.player.class_id != "mage":
		return null
	var k = Game.player.kit
	return k.el if k is MageKit and k.el != null else null


func _process(_delta: float) -> void:
	var el = _el()
	var open: bool = el != null and el.wheel_open
	if open != _was_open:
		_was_open = open
		cursor = Vector2.ZERO
	visible = open
	if open:
		el.wheel_hover = hover_index(el.wheel_options().size(), cursor)
		queue_redraw()


## Sector index for a cursor offset (clockwise from the top); -1 inside the dead zone.
static func hover_index(n: int, c: Vector2) -> int:
	if n <= 0 or c.length() < DEADZONE:
		return -1
	var a := fposmod(atan2(c.x, -c.y), TAU)
	return int(floor(a / (TAU / float(n)))) % n


func _input(event: InputEvent) -> void:
	var el = _el()
	if el == null or not el.wheel_open:
		return
	if event is InputEventMouseMotion:
		cursor += event.relative
		if cursor.length() > CURSOR_MAX:
			cursor = cursor.normalized() * CURSOR_MAX
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("release_mouse"):
		el.wheel_cancel()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var el = _el()
	if el == null or not el.wheel_open:
		return
	var opts: Array = el.wheel_options()
	var c := size * 0.5
	var font := get_theme_default_font()
	var slot_name: String = ["LMB", "RMB"][clampi(el.wheel_slot, 0, 1)]
	draw_circle(c, RADIUS + 46.0, Color(0.05, 0.04, 0.05, 0.72))
	var n := opts.size()
	for i in n:
		var s: ChargedSpellData = el.spells[opts[i]]
		var col: Color = MageElementalist.COLORS.get(s.element, Color.WHITE)
		var a0 := TAU * i / float(n) - PI * 0.5
		var a1 := TAU * (i + 1) / float(n) - PI * 0.5
		var hov: bool = i == el.wheel_hover
		var pts := PackedVector2Array([c])
		for k in 13:
			var a := lerpf(a0, a1, k / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * (RADIUS + 40.0))
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.42 if hov else 0.14))
		draw_line(c + Vector2(cos(a0), sin(a0)) * 30.0, c + Vector2(cos(a0), sin(a0)) * (RADIUS + 40.0), Color(0, 0, 0, 0.6), 2.0)
		var mid := (a0 + a1) * 0.5
		var p := c + Vector2(cos(mid), sin(mid)) * RADIUS
		GameIcon.draw_icon(self, s.element, Rect2(p - Vector2(18, 30), Vector2(36, 36)), col.lightened(0.2) if hov else col)
		var label := s.display_name
		var elab := s.element.capitalize()
		var fs := 15
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, p + Vector2(-w * 0.5, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if hov else Color(0.92, 0.88, 0.8))
		var ew := font.get_string_size(elab, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		draw_string(font, p + Vector2(-ew * 0.5, 38), elab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		if el.slot_spell(el.wheel_slot) == opts[i]:
			draw_arc(p + Vector2(0, -12), 24.0, 0, TAU, 24, Color(1, 0.9, 0.5, 0.9), 2.0)
	draw_circle(c, DEADZONE, Color(0, 0, 0, 0.5))
	var title := "%s slot" % slot_name
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
	draw_string(font, c + Vector2(-tw * 0.5, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.6))
	var hint := "Move the mouse to a spell, release to equip  ·  Esc / centre = cancel  ·  never casts"
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	draw_string(font, c + Vector2(-hw * 0.5, RADIUS + 72.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.8, 0.7))
	draw_circle(c + cursor, 6.0, Color(1, 1, 1, 0.9))
