class_name OrnamentDivider
extends Control
## ——◆—— divider with optional caption.

var caption: String = ""
var color: Color = UITheme.GOLD


func _draw() -> void:
	var w := size.x
	var y := size.y * 0.5
	var cx := w * 0.5
	var gap := 10.0
	if caption != "":
		var f := UITheme.title_font(true)
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		gap = tw * 0.5 + 18.0
		draw_string(f, Vector2(cx - tw * 0.5, y + 5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.GOLD)
	var c0 := Color(color.r, color.g, color.b, 0.0)
	draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(cx - gap, y)]), PackedColorArray([c0, color]), 1.0, true)
	draw_polyline_colors(PackedVector2Array([Vector2(cx + gap, y), Vector2(w, y)]), PackedColorArray([color, c0]), 1.0, true)
	if caption == "":
		_diamond(Vector2(cx, y), 4.5, color)
	else:
		_diamond(Vector2(cx - gap + 4, y), 3.0, color)
		_diamond(Vector2(cx + gap - 4, y), 3.0, color)


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)
