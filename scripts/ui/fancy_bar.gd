class_name FancyBar
extends Control
## Smoothly animated resource bar: fast fill + slow "chip" trail on damage (white) or a soft
## preview on heal (green), glossy highlight, end-caps and optional centred text.

var max_value: float = 100.0
var value: float = 100.0
var shown: float = 100.0
var chip: float = 100.0
var fill_color: Color = UITheme.HP
var chip_color: Color = Color(1.0, 0.92, 0.75, 0.9)
var label_text: String = "":
	set(v):
		if v != label_text:
			label_text = v
			queue_redraw()
var font_size: int = 13
var segments: int = 0
var caps: bool = true
var _chip_hold: float = 0.0
var _initialized: bool = false


func set_values(v: float, m: float) -> void:
	max_value = maxf(m, 0.001)
	if not _initialized:
		shown = v
		chip = v
		_initialized = true
	if v < value:
		_chip_hold = 0.45
	value = v


func _process(delta: float) -> void:
	var old_s := shown
	var old_c := chip
	shown = move_toward(shown, value, max_value * delta * (4.0 if value < shown else 1.6))
	if _chip_hold > 0.0:
		_chip_hold -= delta
	elif chip > shown:
		chip = move_toward(chip, shown, max_value * delta * 0.9)
	if chip < shown:
		chip = shown
	if old_s != shown or old_c != chip:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var h := size.y
	draw_rect(r, Color(0.02, 0.02, 0.02, 0.85))
	var inner := r.grow(-1.5)
	var fs := clampf(shown / max_value, 0.0, 1.0)
	var fc := clampf(chip / max_value, 0.0, 1.0)
	if fc > fs:
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * fs, 0), Vector2(inner.size.x * (fc - fs), inner.size.y)), chip_color)
	if value > shown + 0.01:
		var fv := clampf(value / max_value, 0.0, 1.0)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * fs, 0), Vector2(inner.size.x * (fv - fs), inner.size.y)), Color(fill_color.r, fill_color.g, fill_color.b, 0.35))
	if fs > 0.0:
		var fr := Rect2(inner.position, Vector2(inner.size.x * fs, inner.size.y))
		draw_rect(fr, fill_color.darkened(0.15))
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.45)), fill_color.lightened(0.12))
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, maxf(1.0, fr.size.y * 0.12))), Color(1, 1, 1, 0.25))
	if segments > 1:
		for i in range(1, segments):
			var x := inner.position.x + inner.size.x * float(i) / float(segments)
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0, 0, 0, 0.55), 1.0)
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.9), false, 1.0)
	draw_rect(r.grow(1.0), Color(UITheme.GOLD_DIM.r, UITheme.GOLD_DIM.g, UITheme.GOLD_DIM.b, 0.8), false, 1.0)
	if caps and h >= 8.0:
		for x in [-3.0, size.x + 3.0]:
			var c := Vector2(x, h * 0.5)
			var k := h * 0.42
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.7, 0), c + Vector2(0, k), c + Vector2(-k * 0.7, 0)]), UITheme.GOLD)
	if label_text != "":
		var f := UITheme.body_font(true)
		var tw := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var p := Vector2((size.x - tw.x) * 0.5, (h + font_size * 0.72) * 0.5)
		draw_string_outline(f, p, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.85))
		draw_string(f, p, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.PARCHMENT)
