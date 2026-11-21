class_name SpellWheel
extends Control
## COMBAT-BALANCE-UX-006 Part 7: the Worldweaver CASTING WHEEL. Appears around the reticle while LMB / RMB is
## held (after a short delay, so quick taps never flash). A translucent ring with a hollow centre keeps the
## target visible. Mouse motion moves a selection vector (the camera does not turn while the wheel is open);
## pointing at a sector selects that spell at once and its charge restarts from zero. The selected sector
## shows the charge as an arc and glows at full charge. Releasing the button casts; the centre keeps the
## current spell. Every sector is one spell with its element icon, colour and name (never colour alone).

const R_IN := 92.0
const R_OUT := 168.0
const DEADZONE := 26.0
const CURSOR_MAX := 150.0

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
	var open: bool = el != null and el.wheel_open and el.wheel_slot >= 0
	if open != _was_open:
		_was_open = open
		cursor = Vector2.ZERO
	visible = open
	if open:
		var idx := hover_index(el.wheel_options(el.wheel_slot).size(), cursor)
		if idx >= 0 and idx != el.wheel_hover:
			el.wheel_select(idx)
		queue_redraw()


## Sector index for a cursor offset (clockwise from the top); -1 inside the centre.
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


func _draw() -> void:
	var el = _el()
	if el == null or not el.wheel_open or el.wheel_slot < 0:
		return
	var opts: Array = el.wheel_options(el.wheel_slot)
	# centred on the reticle (screen centre); the hollow ring keeps the target visible
	var c := get_viewport_rect().size * 0.5 - global_position
	var font := get_theme_default_font()
	var n := opts.size()
	if n == 0:
		return
	for i in n:
		var s: ChargedSpellData = el.spells[opts[i]]
		var col: Color = MageElementalist.COLORS.get(s.element, Color.WHITE)
		var a0 := TAU * i / float(n) - PI * 0.5
		var a1 := TAU * (i + 1) / float(n) - PI * 0.5
		var sel: bool = el.cur != null and el.cur.id == opts[i]
		var pts := PackedVector2Array()
		for k in 17:
			var a := lerpf(a0, a1, k / 16.0)
			pts.append(c + Vector2(cos(a), sin(a)) * R_OUT)
		for k in 17:
			var a := lerpf(a1, a0, k / 16.0)
			pts.append(c + Vector2(cos(a), sin(a)) * R_IN)
		draw_colored_polygon(pts, Color(col.r * 0.4, col.g * 0.4, col.b * 0.4, 0.5 if sel else 0.22))
		draw_line(c + Vector2(cos(a0), sin(a0)) * R_IN, c + Vector2(cos(a0), sin(a0)) * R_OUT, Color(0, 0, 0, 0.55), 2.0)
		var mid := (a0 + a1) * 0.5
		var p := c + Vector2(cos(mid), sin(mid)) * ((R_IN + R_OUT) * 0.5)
		GameIcon.draw_icon(self, s.element, Rect2(p - Vector2(15, 24), Vector2(30, 30)), col.lightened(0.25) if sel else col)
		var label := s.display_name
		var fs := 13
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p + Vector2(-w * 0.5, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if sel else Color(0.88, 0.84, 0.76))
		if sel:
			# charge progress along the outer edge of the selected sector, glow at full charge
			var r: float = el.ratio()
			draw_arc(c, R_OUT + 6.0, a0, lerpf(a0, a1, r), 24, col.lightened(0.3), 5.0, true)
			draw_arc(c, R_OUT, a0, a1, 24, Color(1, 0.92, 0.7, 0.9), 2.0, true)
			if el.is_full():
				draw_arc(c, R_OUT + 10.0, a0, a1, 24, Color(1, 0.95, 0.75, 0.6 + 0.3 * sin(Time.get_ticks_msec() * 0.012)), 3.0, true)
	draw_arc(c, R_IN, 0, TAU, 48, Color(1, 0.9, 0.6, 0.35), 1.5, true)
	var slot_name: String = ["LMB", "RMB"][clampi(el.wheel_slot, 0, 1)]
	var hint := "%s wheel · point to choose · release to cast" % slot_name
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, c + Vector2(-hw * 0.5, R_OUT + 34.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.85, 0.72, 0.85))
	if cursor.length() > 2.0:
		draw_circle(c + cursor.normalized() * minf(cursor.length(), R_IN - 10.0), 4.0, Color(1, 1, 1, 0.85))
