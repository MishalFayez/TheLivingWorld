class_name GameIcon
extends Control
## Vector-drawn icons (no external assets). draw_icon() is static so other widgets can reuse it.

@export var icon_id: String = "sword"
@export var color: Color = UITheme.PARCHMENT


func _draw() -> void:
	GameIcon.draw_icon(self, icon_id, Rect2(Vector2.ZERO, size), color)


func set_icon(id: String, col: Color) -> void:
	if id != icon_id or col != color:
		icon_id = id
		color = col
		queue_redraw()


static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


static func _poly(ci: CanvasItem, r: Rect2, pts: Array, col: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_p(r, p[0], p[1]))
	ci.draw_colored_polygon(arr, col)


static func _line(ci: CanvasItem, r: Rect2, a: Array, b: Array, col: Color, w: float = 2.0) -> void:
	ci.draw_line(_p(r, a[0], a[1]), _p(r, b[0], b[1]), col, w * r.size.x / 40.0, true)


static func draw_icon(ci: CanvasItem, id: String, r: Rect2, col: Color) -> void:
	var dark := col.darkened(0.45)
	var s := r.size.x
	var c := r.get_center()
	match id:
		"sword", "light":
			_poly(ci, r, [[0.5, 0.08], [0.58, 0.2], [0.58, 0.66], [0.42, 0.66], [0.42, 0.2]], col)
			_poly(ci, r, [[0.26, 0.66], [0.74, 0.66], [0.74, 0.73], [0.26, 0.73]], dark.lightened(0.3))
			_poly(ci, r, [[0.46, 0.73], [0.54, 0.73], [0.54, 0.9], [0.46, 0.9]], dark)
		"heavy":
			_poly(ci, r, [[0.5, 0.06], [0.66, 0.22], [0.64, 0.64], [0.36, 0.64], [0.34, 0.22]], col)
			_poly(ci, r, [[0.2, 0.64], [0.8, 0.64], [0.8, 0.72], [0.2, 0.72]], dark.lightened(0.3))
			_poly(ci, r, [[0.45, 0.72], [0.55, 0.72], [0.55, 0.92], [0.45, 0.92]], dark)
		"shield", "guard":
			_poly(ci, r, [[0.2, 0.15], [0.8, 0.15], [0.8, 0.5], [0.5, 0.9], [0.2, 0.5]], col)
			_poly(ci, r, [[0.3, 0.24], [0.7, 0.24], [0.7, 0.48], [0.5, 0.76], [0.3, 0.48]], dark)
			_poly(ci, r, [[0.47, 0.3], [0.53, 0.3], [0.53, 0.62], [0.47, 0.62]], col)
			_poly(ci, r, [[0.38, 0.4], [0.62, 0.4], [0.62, 0.46], [0.38, 0.46]], col)
		"shield_rush":
			_poly(ci, r, [[0.38, 0.18], [0.86, 0.18], [0.86, 0.5], [0.62, 0.86], [0.38, 0.5]], col)
			_poly(ci, r, [[0.47, 0.27], [0.77, 0.27], [0.77, 0.48], [0.62, 0.72], [0.47, 0.48]], dark)
			for i in 3:
				var y := 0.3 + i * 0.18
				_line(ci, r, [0.08, y], [0.3, y], col, 2.5)
		"judgment":
			_poly(ci, r, [[0.5, 0.92], [0.58, 0.78], [0.58, 0.3], [0.42, 0.3], [0.42, 0.78]], col)
			_poly(ci, r, [[0.28, 0.3], [0.72, 0.3], [0.72, 0.23], [0.28, 0.23]], dark.lightened(0.3))
			_poly(ci, r, [[0.46, 0.23], [0.54, 0.23], [0.54, 0.08], [0.46, 0.08]], dark)
			for a in [-0.8, -0.4, 0.4, 0.8]:
				var p1 := c + Vector2(sin(a), cos(a)) * s * 0.3 + Vector2(0, s * 0.15)
				var p2 := c + Vector2(sin(a), cos(a)) * s * 0.44 + Vector2(0, s * 0.15)
				ci.draw_line(p1, p2, col, s / 18.0, true)
		"sweep":
			ci.draw_arc(c, s * 0.32, -PI * 0.9, PI * 0.55, 24, col, s / 10.0, true)
			_poly(ci, r, [[0.72, 0.82], [0.92, 0.72], [0.74, 0.6]], col)
			_poly(ci, r, [[0.47, 0.3], [0.53, 0.3], [0.53, 0.7], [0.47, 0.7]], dark.lightened(0.4))
		"dodge":
			ci.draw_arc(c, s * 0.3, 0.3, PI * 1.7, 24, col, s / 12.0, true)
			ci.draw_arc(c, s * 0.15, 0.3 + PI, PI * 2.7, 16, col, s / 14.0, true)
		"fire":
			_poly(ci, r, [[0.5, 0.06], [0.72, 0.38], [0.78, 0.62], [0.66, 0.86], [0.34, 0.86], [0.22, 0.62], [0.32, 0.42], [0.4, 0.52]], col)
			_poly(ci, r, [[0.52, 0.42], [0.64, 0.62], [0.6, 0.8], [0.4, 0.8], [0.38, 0.64]], Color(1, 0.9, 0.5))
		"life":
			_poly(ci, r, [[0.5, 0.1], [0.78, 0.4], [0.72, 0.68], [0.5, 0.9], [0.28, 0.68], [0.22, 0.4]], col)
			_line(ci, r, [0.5, 0.2], [0.5, 0.86], dark, 2.0)
			_line(ci, r, [0.5, 0.45], [0.66, 0.34], dark, 1.6)
			_line(ci, r, [0.5, 0.6], [0.34, 0.48], dark, 1.6)
		"frost":
			for i in 3:
				var a := i * PI / 3.0
				var d := Vector2(cos(a), sin(a)) * s * 0.38
				ci.draw_line(c - d, c + d, col, s / 13.0, true)
				var d2 := Vector2(cos(a), sin(a))
				var n := Vector2(-d2.y, d2.x)
				for sgn in [-1.0, 1.0]:
					var tip: Vector2 = c + d2 * s * 0.26 * sgn
					ci.draw_line(tip, tip + (n - d2 * sgn) * s * 0.08, col, s / 18.0, true)
					ci.draw_line(tip, tip + (-n - d2 * sgn) * s * 0.08, col, s / 18.0, true)
		"storm":
			_poly(ci, r, [[0.58, 0.05], [0.24, 0.55], [0.47, 0.55], [0.38, 0.95], [0.78, 0.4], [0.54, 0.4], [0.66, 0.05]], col)
		"stone":
			_poly(ci, r, [[0.5, 0.1], [0.84, 0.32], [0.8, 0.74], [0.5, 0.9], [0.2, 0.74], [0.16, 0.32]], col)
			_line(ci, r, [0.5, 0.1], [0.5, 0.5], dark, 1.8)
			_line(ci, r, [0.16, 0.32], [0.5, 0.5], dark, 1.8)
			_line(ci, r, [0.84, 0.32], [0.5, 0.5], dark, 1.8)
			_line(ci, r, [0.5, 0.5], [0.5, 0.9], dark, 1.8)
		"weave":
			ci.draw_arc(c + Vector2(-s * 0.12, 0), s * 0.24, 0, TAU, 28, col, s / 13.0, true)
			ci.draw_arc(c + Vector2(s * 0.12, 0), s * 0.24, 0, TAU, 28, col.lightened(0.3), s / 13.0, true)
			ci.draw_circle(c, s * 0.06, Color(1, 1, 1))
		"split":
			for i in 3:
				var x := 0.3 + i * 0.2
				_poly(ci, r, [[x, 0.1], [x + 0.06, 0.2], [x + 0.06, 0.78], [x - 0.06, 0.78], [x - 0.06, 0.2]], col if i != 1 else col.lightened(0.25))
		"focus":
			_poly(ci, r, [[0.5, 0.06], [0.64, 0.2], [0.64, 0.7], [0.36, 0.7], [0.36, 0.2]], col)
			for a in [-1.2, -0.6, 0.0, 0.6, 1.2]:
				var base := _p(r, 0.5, 0.86)
				ci.draw_line(base, base + Vector2(sin(a), -cos(a) * 0.4) * s * 0.3, col.lightened(0.3), s / 20.0, true)
		"precision":
			ci.draw_arc(c, s * 0.34, 0, TAU, 32, col, s / 16.0, true)
			ci.draw_arc(c, s * 0.16, 0, TAU, 20, col, s / 16.0, true)
			for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(c + v * s * 0.22, c + v * s * 0.46, col, s / 16.0, true)
			ci.draw_circle(c, s * 0.04, col)
		"sigil":
			ci.draw_arc(c, s * 0.38, 0, TAU, 36, col, s / 14.0, true)
			ci.draw_arc(c, s * 0.22, 0, TAU, 28, col.lightened(0.2), s / 18.0, true)
			for i in 6:
				var a := TAU * i / 6.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.22, c + Vector2(cos(a), sin(a)) * s * 0.38, col, s / 22.0, true)
			ci.draw_circle(c, s * 0.06, Color(1, 1, 1))
		"ward":
			_poly(ci, r, [[0.5, 0.1], [0.84, 0.24], [0.8, 0.56], [0.5, 0.9], [0.2, 0.56], [0.16, 0.24]], Color(col.r, col.g, col.b, 0.35))
			ci.draw_polyline(PackedVector2Array([_p(r, 0.5, 0.1), _p(r, 0.84, 0.24), _p(r, 0.8, 0.56), _p(r, 0.5, 0.9), _p(r, 0.2, 0.56), _p(r, 0.16, 0.24), _p(r, 0.5, 0.1)]), col, s / 14.0, true)
			_poly(ci, r, [[0.44, 0.3], [0.56, 0.3], [0.56, 0.44], [0.68, 0.44], [0.68, 0.54], [0.56, 0.54], [0.56, 0.7], [0.44, 0.7], [0.44, 0.54], [0.32, 0.54], [0.32, 0.44], [0.44, 0.44]], col)
		"lunge", "r_lunge":
			_poly(ci, r, [[0.92, 0.5], [0.72, 0.42], [0.2, 0.44], [0.2, 0.56], [0.72, 0.58]], col)
			for i in 3:
				var y := 0.3 + i * 0.2
				_line(ci, r, [0.06, y], [0.18 + (0.1 if i == 1 else 0.0), y], col.lightened(0.3), 2.0)
		"flurry", "r_flurry":
			for i in 4:
				var a := -0.9 + i * 0.6
				var p0 := c + Vector2(cos(a + PI), sin(a + PI)) * s * 0.36
				var p1 := c + Vector2(cos(a), sin(a)) * s * 0.36
				ci.draw_line(p0, p1, col if i % 2 == 0 else col.lightened(0.3), s / 15.0, true)
		"opening", "r_openings":
			ci.draw_arc(c, s * 0.3, 0, TAU, 28, col, s / 18.0, true)
			_poly(ci, r, [[0.5, 0.04], [0.56, 0.44], [0.96, 0.5], [0.56, 0.56], [0.5, 0.96], [0.44, 0.56], [0.04, 0.5], [0.44, 0.44]], col.lightened(0.25))
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.08), s * 0.17, PI, TAU, 16, col, s / 12.0, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.06), Vector2(s * 0.48, s * 0.36)), col)
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.05, col.darkened(0.6))
		"helm", "head":
			_poly(ci, r, [[0.2, 0.55], [0.22, 0.3], [0.5, 0.12], [0.78, 0.3], [0.8, 0.55], [0.8, 0.85], [0.2, 0.85]], col)
			_poly(ci, r, [[0.3, 0.48], [0.7, 0.48], [0.7, 0.56], [0.3, 0.56]], dark)
		"chest", "armor":
			_poly(ci, r, [[0.2, 0.18], [0.38, 0.12], [0.5, 0.2], [0.62, 0.12], [0.8, 0.18], [0.84, 0.5], [0.72, 0.52], [0.72, 0.88], [0.28, 0.88], [0.28, 0.52], [0.16, 0.5]], col)
			_line(ci, r, [0.5, 0.22], [0.5, 0.84], dark, 2.0)
		"hands", "gloves":
			_poly(ci, r, [[0.3, 0.88], [0.3, 0.45], [0.36, 0.2], [0.44, 0.2], [0.46, 0.4], [0.5, 0.14], [0.58, 0.14], [0.6, 0.4], [0.66, 0.22], [0.74, 0.24], [0.72, 0.6], [0.66, 0.88]], col)
		"feet", "boots":
			_poly(ci, r, [[0.3, 0.12], [0.56, 0.12], [0.56, 0.62], [0.86, 0.72], [0.86, 0.88], [0.3, 0.88]], col)
			_poly(ci, r, [[0.3, 0.3], [0.56, 0.3], [0.56, 0.36], [0.3, 0.36]], dark)
		"accessory", "ring", "amulet":
			ci.draw_arc(c + Vector2(0, s * 0.08), s * 0.26, 0, TAU, 28, col, s / 11.0, true)
			_poly(ci, r, [[0.5, 0.06], [0.62, 0.2], [0.5, 0.34], [0.38, 0.2]], Color(0.55, 0.85, 1.0))
		"staff", "weapon_staff":
			_line(ci, r, [0.24, 0.9], [0.7, 0.3], col, 3.0)
			ci.draw_circle(_p(r, 0.74, 0.24), s * 0.12, Color(0.55, 0.85, 1.0))
			ci.draw_arc(_p(r, 0.74, 0.24), s * 0.17, 0, TAU, 20, col, s / 20.0, true)
		"map":
			_poly(ci, r, [[0.1, 0.2], [0.36, 0.1], [0.64, 0.2], [0.9, 0.1], [0.9, 0.8], [0.64, 0.9], [0.36, 0.8], [0.1, 0.9]], col)
			_line(ci, r, [0.36, 0.1], [0.36, 0.8], dark, 1.5)
			_line(ci, r, [0.64, 0.2], [0.64, 0.9], dark, 1.5)
		"quest":
			_poly(ci, r, [[0.24, 0.1], [0.76, 0.1], [0.76, 0.9], [0.24, 0.9]], col)
			for i in 4:
				_line(ci, r, [0.32, 0.25 + i * 0.16], [0.68, 0.25 + i * 0.16], dark, 1.8)
		"counter":
			GameIcon.draw_icon(ci, "shield", r, col)
			_line(ci, r, [0.12, 0.88], [0.88, 0.12], Color(1, 0.9, 0.6), 2.5)
		"revive":
			_poly(ci, r, [[0.42, 0.14], [0.58, 0.14], [0.58, 0.42], [0.86, 0.42], [0.86, 0.58], [0.58, 0.58], [0.58, 0.86], [0.42, 0.86], [0.42, 0.58], [0.14, 0.58], [0.14, 0.42], [0.42, 0.42]], col)
		# augment categories
		"passive":
			ci.draw_arc(c, s * 0.34, 0, TAU, 32, col, s / 10.0, true)
			ci.draw_circle(c, s * 0.12, col)
		"conditional":
			_poly(ci, r, [[0.25, 0.12], [0.75, 0.12], [0.5, 0.5]], col)
			_poly(ci, r, [[0.25, 0.88], [0.75, 0.88], [0.5, 0.5]], col.darkened(0.25))
		"enhancement":
			_poly(ci, r, [[0.5, 0.1], [0.85, 0.5], [0.62, 0.5], [0.62, 0.9], [0.38, 0.9], [0.38, 0.5], [0.15, 0.5]], col)
		"synergy":
			ci.draw_arc(c + Vector2(-s * 0.13, 0), s * 0.2, 0, TAU, 24, col, s / 11.0, true)
			ci.draw_arc(c + Vector2(s * 0.13, 0), s * 0.2, 0, TAU, 24, col, s / 11.0, true)
		"mutation":
			var pts := PackedVector2Array()
			for i in 40:
				var a := i * 0.32
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.04 + i * 0.0095))
			ci.draw_polyline(pts, col, s / 13.0, true)
		# statuses
		"buff":
			_poly(ci, r, [[0.5, 0.15], [0.82, 0.55], [0.18, 0.55]], col)
			_poly(ci, r, [[0.4, 0.55], [0.6, 0.55], [0.6, 0.85], [0.4, 0.85]], col)
		"debuff":
			_poly(ci, r, [[0.5, 0.85], [0.82, 0.45], [0.18, 0.45]], col)
			_poly(ci, r, [[0.4, 0.45], [0.6, 0.45], [0.6, 0.15], [0.4, 0.15]], col)
		"hot":
			GameIcon.draw_icon(ci, "revive", r, col)
		# class emblems
		"vanguard":
			GameIcon.draw_icon(ci, "shield", r, col)
		"mage":
			ci.draw_arc(c, s * 0.36, 0, TAU, 32, col, s / 14.0, true)
			for i in 5:
				var a1 := -PI / 2 + i * TAU / 5.0
				var a2 := -PI / 2 + ((i + 2) % 5) * TAU / 5.0
				ci.draw_line(c + Vector2(cos(a1), sin(a1)) * s * 0.33, c + Vector2(cos(a2), sin(a2)) * s * 0.33, col, s / 18.0, true)
		"reaver":
			_poly(ci, r, [[0.2, 0.86], [0.26, 0.92], [0.86, 0.22], [0.82, 0.1], [0.7, 0.14]], col)
			_poly(ci, r, [[0.8, 0.86], [0.74, 0.92], [0.14, 0.22], [0.18, 0.1], [0.3, 0.14]], col.darkened(0.15))
		_:
			ci.draw_circle(c, s * 0.3, col)
