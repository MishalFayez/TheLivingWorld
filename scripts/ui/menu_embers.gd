class_name MenuEmbers
extends Control
## Drifting ash embers for the menu background.

var embers: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 70:
		embers.append(_new(true))


func _new(anywhere: bool) -> Dictionary:
	var s := size if size.x > 10 else Vector2(1600, 900)
	return {"p": Vector2(randf() * s.x, (randf() if anywhere else 1.05) * s.y), "v": Vector2(randf_range(-12, 12), randf_range(-45, -15)),
		"r": randf_range(1.0, 3.2), "a": randf_range(0.25, 0.85), "ph": randf() * TAU}


func _process(delta: float) -> void:
	for i in embers.size():
		var e: Dictionary = embers[i]
		e.p += e.v * delta + Vector2(sin(Time.get_ticks_msec() * 0.001 + e.ph) * 8.0 * delta, 0)
		if e.p.y < -10:
			embers[i] = _new(false)
	queue_redraw()


func _draw() -> void:
	for e in embers:
		var col := Color(1.0, 0.55, 0.2, e.a)
		draw_circle(e.p, e.r * 2.2, Color(col.r, col.g, col.b, e.a * 0.15))
		draw_circle(e.p, e.r, col)
