class_name WorldOverlay
extends Control
## Screen-space combat overlay drawn over the 3D view:
##  - enemy HP bars with damage chip + poise strip (elite gold frame, name on target / elites)
##  - lock-on reticle (rotating brackets)
##  - downed-ally markers with revive timer
##  - Perfect Guard / Guard Broken screen feedback

var chips: Dictionary = {}
var t: float = 0.0
var flash_t: float = 0.0
var flash_kind: String = ""
# lock indicator animation
var ind_pos: Vector2 = Vector2.ZERO
var ind_from: Vector2 = Vector2.ZERO
var ind_t: float = 1.0
var ind_target = null
var switch_pulse: float = 0.0
var fail_shake: float = 0.0
const IND_TRAVEL := 0.18
var _hooked_lock = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.guard_event.connect(_on_guard)


func _on_guard(defender, _info, kind) -> void:
	if defender != Game.player:
		return
	if kind == "perfect" or kind == "break":
		flash_kind = kind
		flash_t = 0.6


func _process(delta: float) -> void:
	t += delta
	if flash_t > 0.0:
		flash_t -= delta
	ind_t = minf(1.0, ind_t + delta / IND_TRAVEL)
	switch_pulse = maxf(0.0, switch_pulse - delta)
	fail_shake = maxf(0.0, fail_shake - delta)
	_hook_lock_system()
	queue_redraw()


func _hook_lock_system() -> void:
	var h := Game.player
	if not is_instance_valid(h):
		return
	var brain = h.get_node_or_null("Brain")
	if brain == null or not ("lock" in brain) or brain.lock == null or brain.lock == _hooked_lock:
		return
	_hooked_lock = brain.lock
	brain.lock.target_changed.connect(_on_target_changed)
	brain.lock.switch_failed.connect(func(_d): fail_shake = 0.3)


func _on_target_changed(_old, new_target, switched: bool) -> void:
	ind_from = ind_pos
	ind_t = 0.0 if (switched and ind_target != null) else 1.0
	ind_target = new_target
	if new_target != null:
		switch_pulse = 0.35


func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var h := Game.player
	var lock = h.lock_target if is_instance_valid(h) else null
	var f := UITheme.body_font(true)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.is_boss:
			continue
		var top: Vector3 = CameraRig.vis_pos(e) + Vector3(0, 2.25 * e.body_scale + 0.25, 0)
		if cam.is_position_behind(top) or cam.global_position.distance_to(top) > 42.0:
			continue
		var p := cam.unproject_position(top)
		var key: int = e.get_instance_id()
		var frac: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
		var ch: Dictionary = chips.get(key, {"v": frac, "hold": 0.0})
		if frac < ch.v - 0.001 and ch.hold <= 0.0:
			ch.hold = 0.4
		ch.hold -= get_process_delta_time()
		if ch.hold <= 0.0:
			ch.v = move_toward(ch.v, frac, get_process_delta_time() * 0.8)
		chips[key] = ch
		var is_lock: bool = e == lock
		var full: bool = frac < 0.999 or is_lock or e.is_elite
		var w := 110.0 if is_lock else (86.0 if e.is_elite else 64.0)
		var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 6))
		if not full:
			r.size.x = 40.0
			r.position.x = p.x - 20.0
		if is_lock:
			r.size.y = 8.0
		var dim := 0.55 if (lock != null and not is_lock) else 1.0
		draw_set_transform(Vector2.ZERO)
		draw_rect(r.grow(1), Color(0, 0, 0, 0.75 * dim))
		draw_rect(Rect2(r.position, Vector2(r.size.x * ch.v, r.size.y)), Color(1, 0.9, 0.7, 0.8))
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), UITheme.HP if not e.is_elite else Color(0.9, 0.35, 0.1))
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, 2)), Color(1, 1, 1, 0.22))
		var pr := Rect2(r.position + Vector2(0, 8), Vector2(r.size.x * clampf(e.poise / e.max_poise, 0, 1), 2))
		draw_rect(pr, UITheme.POISE)
		var frame_col: Color = Color(1.0, 0.45, 0.3) if is_lock else (UITheme.GOLD if e.is_elite else Color(0.35, 0.3, 0.25, 0.9))
		draw_rect(r.grow(1.5), Color(frame_col.r, frame_col.g, frame_col.b, frame_col.a * dim), false, 1.5 if is_lock else 1.0)
		if e.is_staggered():
			_label(f, Vector2(p.x, r.position.y - 4), "STAGGERED", 11, UITheme.POISE)
		elif full and (is_lock or e.is_elite):
			_label(f, Vector2(p.x, r.position.y - 4), e.display_name, 14 if is_lock else 12, Color(1.0, 0.75, 0.6) if is_lock else UITheme.GOLD_BRIGHT)
	# lock-on indicator: brackets sized to the target, chevron above it, smooth travel on switch
	if lock != null and is_instance_valid(lock) and lock.is_targetable():
		var sc_b: float = lock.body_scale if "body_scale" in lock else 1.0
		var vp: Vector3 = CameraRig.vis_pos(lock)
		var center3 := vp + Vector3(0, 1.0 * sc_b, 0)
		if not cam.is_position_behind(center3):
			var c := cam.unproject_position(center3)
			var feet := cam.unproject_position(vp)
			var head := cam.unproject_position(vp + Vector3(0, 2.1 * sc_b, 0))
			var half_h := clampf(absf(feet.y - head.y) * 0.5, 22.0, 140.0)
			if ind_target != lock:
				ind_target = lock
				ind_t = 1.0
			var k := ind_t * ind_t * (3.0 - 2.0 * ind_t)
			ind_pos = ind_from.lerp(c, k) if ind_t < 1.0 else c
			var shake_x := sin(t * 60.0) * 6.0 * (fail_shake / 0.3)
			var pc := ind_pos + Vector2(shake_x, 0)
			var hw := half_h * 0.62
			var hh := half_h
			var grow := 1.0 + 0.25 * (switch_pulse / 0.35)
			hw *= grow
			hh *= grow
			var col := Color(1.0, 0.42, 0.28)
			var arm := minf(hw, hh) * 0.35
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := pc + Vector2(hw * sx, hh * sy)
					draw_polyline(PackedVector2Array([corner + Vector2(0, -arm * sy), corner, corner + Vector2(-arm * sx, 0)]), Color(0, 0, 0, 0.6), 4.5, true)
					draw_polyline(PackedVector2Array([corner + Vector2(0, -arm * sy), corner, corner + Vector2(-arm * sx, 0)]), col, 2.5, true)
			# chevron above the head (bobbing slightly)
			var top_y := pc.y - hh - 14.0 + 3.0 * sin(t * 4.0)
			var chev := PackedVector2Array([Vector2(pc.x - 9, top_y - 8), Vector2(pc.x, top_y), Vector2(pc.x + 9, top_y - 8)])
			draw_polyline(chev, Color(0, 0, 0, 0.7), 5.0, true)
			draw_polyline(chev, Color(1.0, 0.8, 0.4), 3.0, true)
			draw_circle(pc, 2.5, col)
			if switch_pulse > 0.0:
				draw_arc(pc, half_h * (1.4 - switch_pulse), 0, TAU, 48, Color(1.0, 0.75, 0.45, switch_pulse * 2.0), 2.0, true)
	# downed allies
	for o in Game.heroes:
		if is_instance_valid(o) and o.downed and o != h:
			var top2: Vector3 = CameraRig.vis_pos(o) + Vector3(0, 1.4, 0)
			if not cam.is_position_behind(top2):
				var p2 := cam.unproject_position(top2)
				GameIcon.draw_icon(self, "revive", Rect2(p2 - Vector2(12, 12), Vector2(24, 24)), Color(1, 0.35, 0.3))
				draw_arc(p2, 18, -PI / 2, -PI / 2 + TAU * clampf(o.revive_progress / Game.balance.revive_time, 0, 1), 32, UITheme.STAMINA, 3.0, true)
				_label(f, p2 + Vector2(0, 30), "%.0fs" % o.downed_timer, 13, Color(1, 0.5, 0.45))
	# perfect guard / guard break feedback
	if flash_t > 0.0:
		var k := flash_t / 0.6
		var sc := size * 0.5 + Vector2(0, -40)
		var col := Color(1.0, 0.82, 0.35, k) if flash_kind == "perfect" else Color(1.0, 0.3, 0.2, k)
		draw_arc(sc, 60.0 + (1.0 - k) * 120.0, 0, TAU, 64, col, 4.0 * k + 1.0, true)
		var ft := UITheme.title_font(true)
		var msg := "PERFECT GUARD" if flash_kind == "perfect" else "GUARD BROKEN"
		var size_px := int(30 + 8 * k)
		var tw := ft.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string_outline(ft, sc + Vector2(-tw * 0.5, 12), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 8, Color(0, 0, 0, k * 0.85))
		draw_string(ft, sc + Vector2(-tw * 0.5, 12), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _label(f: Font, p: Vector2, s: String, size_px: int, col: Color) -> void:
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(f, Vector2(p.x - tw * 0.5, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, Color(0, 0, 0, 0.85))
	draw_string(f, Vector2(p.x - tw * 0.5, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
