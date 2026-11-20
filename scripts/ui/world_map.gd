class_name WorldMap
extends Control
## Stylized parchment map of Ashen Valley drawn from the live world data: areas, road, gates,
## encounters (cleared / not), checkpoints (rest points), totems, shrine, boss arena, player.

var t: float = 0.0
const Z_MIN := -215.0
const Z_MAX := 75.0
const X_HALF := 48.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func w2m(p: Vector3) -> Vector2:
	# north (negative z) is up
	var u := (p.x + X_HALF) / (X_HALF * 2.0)
	var v := (p.z - Z_MIN) / (Z_MAX - Z_MIN)
	var mh := size.y - 40.0
	var mw := mh * (X_HALF * 2.0) / (Z_MAX - Z_MIN) * 2.2
	var ox := (size.x - mw) * 0.5
	return Vector2(ox + u * mw, 20.0 + v * mh)


func _draw() -> void:
	var w = Game.world
	# parchment
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.86, 0.79, 0.62))
	for i in 40:
		var y := i * size.y / 40.0
		draw_rect(Rect2(0, y, size.x, size.y / 40.0), Color(0.55, 0.42, 0.25, 0.04 * (1.0 + sin(i * 1.7))))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.28, 0.15), false, 4.0)
	draw_rect(Rect2(Vector2(8, 8), size - Vector2(16, 16)), Color(0.5, 0.36, 0.2, 0.6), false, 1.5)
	if w == null or not ("AREAS" in w):
		return
	var tf := UITheme.title_font(true)
	var bf := UITheme.body_font(true)
	# areas
	var fills := {"outskirts": Color(0.55, 0.7, 0.42), "ruins": Color(0.62, 0.66, 0.55), "keep": Color(0.55, 0.47, 0.44)}
	for a in w.AREAS:
		var ad: Dictionary = w.AREAS[a]
		var c: Vector3 = ad.center
		var s: Vector2 = ad.size
		var r0 := w2m(c + Vector3(-s.x * 0.5, 0, -s.y * 0.5))
		var r1 := w2m(c + Vector3(s.x * 0.5, 0, s.y * 0.5))
		var rect := Rect2(r0, r1 - r0)
		draw_rect(rect, fills[a])
		draw_rect(rect, Color(0.35, 0.25, 0.15), false, 2.5)
		var label: String = ad.name.to_upper()
		var lw := tf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(tf, Vector2(rect.position.x - lw - 14, rect.get_center().y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.18, 0.1))
		var lvl: String = {"outskirts": "Lv 1-3", "ruins": "Lv 4-7", "keep": "Lv 8-10"}[a]
		draw_string(bf, Vector2(rect.position.x - lw - 14, rect.get_center().y + 18), lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.25, 0.15))
	# corridors + road
	for zz in [[-30.0, -55.0], [-115.0, -135.0]]:
		var a0 := w2m(Vector3(-5, 0, zz[0]))
		var a1 := w2m(Vector3(5, 0, zz[1]))
		draw_rect(Rect2(a0, a1 - a0), Color(0.6, 0.6, 0.5))
	var pts := PackedVector2Array()
	var z := 31.0
	while z > -190.0:
		pts.append(w2m(Vector3(Scenery.road_x(z), 0, z)))
		z -= 3.0
	draw_polyline(pts, Color(0.62, 0.48, 0.3), 6.0, true)
	# training yard
	var ty0 := w2m(Vector3(-14, 0, 48))
	var ty1 := w2m(Vector3(14, 0, 70))
	draw_rect(Rect2(ty0, ty1 - ty0), Color(0.66, 0.6, 0.45))
	draw_rect(Rect2(ty0, ty1 - ty0), Color(0.35, 0.25, 0.15), false, 2.0)
	draw_string(bf, ty0 + Vector2(6, 16), "TRAINING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.2, 0.1))
	# gates
	for a in w.gates:
		var g = w.gates[a]
		if is_instance_valid(g):
			var gp := w2m(g.global_position)
			draw_rect(Rect2(gp - Vector2(14, 3), Vector2(28, 6)), Color(1.0, 0.5, 0.2))
	# boss arena
	if not w.boss_zone.is_empty():
		var bc := w2m(w.boss_zone.center)
		var br: float = (w2m(w.boss_zone.center + Vector3(w.boss_zone.radius, 0, 0)) - bc).x
		draw_arc(bc, br, 0, TAU, 40, Color(0.5, 0.15, 0.1), 2.5, true)
		var done: bool = w.cleared.get("boss", false)
		_star(bc, 10.0, Color(0.4, 0.4, 0.4) if done else Color(1.0, 0.45, 0.2))
	# encounters
	for a in w.zones:
		for zn in w.zones[a]:
			var zp := w2m(zn.global_position)
			draw_circle(zp, 6.5, Color(0.45, 0.85, 0.45) if zn.done else Color(0.95, 0.3, 0.25))
			draw_arc(zp, 6.5, 0, TAU, 16, Color(0.2, 0.12, 0.08), 1.5, true)
	# interactables
	for it in w.interactables:
		var ip := w2m(it.pos)
		draw_rect(Rect2(ip - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.7, 0.3) if not String(it.label).begins_with("Elemental") else Color(0.45, 0.7, 1.0))
	# checkpoints
	for a in w.AREAS:
		var cp := w2m(w.AREAS[a].checkpoint)
		draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -8), cp + Vector2(7, 5), cp + Vector2(-7, 5)]), Color(0.45, 0.75, 1.0))
	# objective highlight
	var q := Quests.current()
	if q.has("area"):
		var ad2: Dictionary = w.AREAS[q.area]
		var pc := w2m(ad2.center)
		draw_arc(pc, 24.0 + 4.0 * sin(t * 3.0), 0, TAU, 32, Color(0.9, 0.6, 0.15, 0.8), 2.0, true)
	# player
	var p = Game.player
	if is_instance_valid(p):
		var pp := w2m(p.global_position)
		var f: Vector3 = p.forward()
		var dir := Vector2(f.x, f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pp + dir * 11, pp - dir * 6 + side * 7, pp - dir * 3, pp - dir * 6 - side * 7]), Color(1.0, 0.85, 0.3))
		draw_arc(pp, 13.0 + 2.0 * sin(t * 5.0), 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.6), 1.5, true)
	# compass
	var cc := Vector2(size.x - 50, 60)
	draw_circle(cc, 26, Color(0.8, 0.72, 0.55))
	draw_arc(cc, 26, 0, TAU, 32, Color(0.4, 0.28, 0.15), 2.0, true)
	draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -22), cc + Vector2(6, 0), cc + Vector2(-6, 0)]), Color(0.6, 0.15, 0.1))
	draw_string(tf, cc + Vector2(-5, -30), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.18, 0.1))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
