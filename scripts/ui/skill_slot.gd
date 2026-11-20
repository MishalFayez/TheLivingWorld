class_name SkillSlot
extends Control
## Ability slot: framed icon, keycap, radial cooldown sweep + seconds, ready flash, active glow.

var icon_id: String = "sword"
var icon_color: Color = UITheme.PARCHMENT
var key: String = "LMB"
var accent: Color = UITheme.GOLD
var cooldown: float = 0.0
var cooldown_max: float = 1.0
var active: bool = false
var disabled: bool = false
var caption: String = ""
var locked_level: int = 0           ## > 0: ability not learned yet (shows a lock + unlock level)
var charge: float = -1.0            ## 0..1 while a spell in this slot is charging (-1 = not charging)
var charge_full: bool = false
var charge_color: Color = Color.WHITE
var _ready_flash: float = 0.0
var _was_cd: bool = false
var _pulse: float = 0.0


func setup(p_icon: String, p_key: String, p_color: Color, p_accent: Color, p_caption: String = "") -> SkillSlot:
	icon_id = p_icon
	key = p_key
	icon_color = p_color
	accent = p_accent
	caption = p_caption
	custom_minimum_size = Vector2(54, 54)
	tooltip_text = p_caption
	return self


func set_state(cd: float, cd_max: float, p_active: bool = false, p_disabled: bool = false) -> void:
	if _was_cd and cd <= 0.0:
		_ready_flash = 0.45
	_was_cd = cd > 0.0
	cooldown = cd
	cooldown_max = maxf(cd_max, 0.01)
	active = p_active
	disabled = p_disabled
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	if _ready_flash > 0.0:
		_ready_flash -= delta
		queue_redraw()
	elif active:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := r.get_center()
	# glow
	if active:
		var a := 0.35 + 0.2 * sin(_pulse * 6.0)
		draw_rect(r.grow(4), Color(accent.r, accent.g, accent.b, a * 0.5))
	draw_rect(r, Color(0.04, 0.035, 0.035, 0.92))
	draw_rect(r.grow(-3), Color(0.1, 0.085, 0.08, 1.0))
	var ic := icon_color if not disabled else Color(0.35, 0.35, 0.35)
	GameIcon.draw_icon(self, icon_id, r.grow(-9), ic)
	# cooldown sweep
	if cooldown > 0.0:
		var frac := clampf(cooldown / cooldown_max, 0.0, 1.0)
		var pts := PackedVector2Array([c])
		var steps := 32
		for i in steps + 1:
			var ang := -PI / 2.0 + TAU * frac * float(i) / float(steps)
			pts.append(c + Vector2(cos(ang), sin(ang)) * size.x * 0.5)
		if pts.size() >= 3 and frac > 0.01:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.7))
		var f := UITheme.title_font(true)
		var t := "%.1f" % cooldown if cooldown < 10.0 else str(int(cooldown))
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string_outline(f, Vector2(c.x - tw * 0.5, c.y + 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color.BLACK)
		draw_string(f, Vector2(c.x - tw * 0.5, c.y + 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UITheme.PARCHMENT)
	if disabled:
		draw_rect(r, Color(0, 0, 0, 0.45))
	if charge >= 0.0:
		# charge progress: fills the frame clockwise; full charge = bright steady frame
		var pts2 := PackedVector2Array()
		var per := [Vector2(c.x, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y), Vector2(0, 0), Vector2(c.x, 0)]
		var total := 4.0
		var want := charge * total
		pts2.append(per[0])
		var seglens := [0.5, 1.0, 1.0, 1.0, 0.5]
		var acc := 0.0
		for i in 5:
			var l: float = seglens[i]
			if acc + l <= want:
				pts2.append(per[i + 1])
				acc += l
			else:
				var f2 := (want - acc) / l
				pts2.append(per[i].lerp(per[i + 1], f2))
				break
		if pts2.size() >= 2:
			draw_polyline(pts2, charge_color if not charge_full else Color(1, 1, 1), 4.0 if charge_full else 3.0)
		if charge_full:
			draw_rect(r.grow(2), Color(charge_color.r, charge_color.g, charge_color.b, 0.5 + 0.3 * sin(_pulse * 12.0)), false, 2.0)
	if locked_level > 0:
		draw_rect(r, Color(0.02, 0.02, 0.03, 0.78))
		GameIcon.draw_icon(self, "lock", Rect2(r.position + Vector2(size.x * 0.28, 6), Vector2(size.x * 0.44, size.x * 0.44)), Color(0.75, 0.7, 0.6))
		var lf := UITheme.body_font(true)
		var lt := "Lv %d" % locked_level
		var lw := lf.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(lf, Vector2(c.x - lw * 0.5, size.y - 18), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)
	# frame
	var fc := accent if (active or _ready_flash > 0.0) else UITheme.GOLD_DIM
	draw_rect(r, fc, false, 2.0 if active else 1.5)
	if _ready_flash > 0.0:
		draw_rect(r.grow(_ready_flash * 8.0), Color(1, 0.9, 0.6, _ready_flash), false, 2.0)
	# corner studs
	for p in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)]), UITheme.GOLD)
	# keycap
	var kf := UITheme.body_font(true)
	var kw := kf.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
	var kr := Rect2(Vector2(size.x - kw - 1, size.y - 15), Vector2(kw, 15))
	draw_rect(kr, Color(0.02, 0.02, 0.02, 0.92))
	draw_rect(kr, UITheme.GOLD_DIM, false, 1.0)
	draw_string(kf, kr.position + Vector2(4, 12), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.GOLD_BRIGHT)
