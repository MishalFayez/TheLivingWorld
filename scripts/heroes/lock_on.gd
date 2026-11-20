class_name LockOnSystem
extends Node
## Player lock-on: acquisition, screen-space target switching, validation and the ground marker.
##   Tab                       toggle lock (target closest to screen centre, visible, in range)
##   Wheel Up / X              switch to the nearest eligible target to the RIGHT on screen
##   Wheel Down / Z            switch to the nearest eligible target to the LEFT on screen
## Rules: only while locked; one switch per cooldown; dead / obstructed / out-of-range enemies are
## never selected; no target in that direction -> keep current; the lock only changes on its own
## when the current target dies or becomes invalid (out of range / hidden behind walls too long).

signal target_changed(old_target, new_target, switched: bool)
signal switch_failed(direction: int)

@export var acquire_range: float = 24.0
@export var keep_range: float = 32.0
@export var switch_cooldown: float = 0.25
@export var los_grace: float = 1.5
@export var screen_margin: float = 0.02

var hero: Hero
var rig: CameraRig
var cooldown: float = 0.0
var los_lost: float = 0.0
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var _pulse: float = 0.0


func setup(h: Hero, r: CameraRig) -> void:
	hero = h
	rig = r


func _ready() -> void:
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.82
	tm.rings = 48
	ring.mesh = tm
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.45, 0.3, 0.8)
	ring_mat.no_depth_test = false
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	ring.set("physics_interpolation_mode", 2)
	ring.top_level = true
	add_child(ring)


func current():
	if hero == null:
		return null
	var t = hero.lock_target
	return t if t != null and is_instance_valid(t) else null


func is_locked() -> bool:
	return current() != null


# ------------------------------------------------------------------ public API
func toggle() -> void:
	if is_locked():
		release()
	else:
		acquire()


func acquire() -> bool:
	var t = best_center_target(null)
	if t != null:
		_set_target(t, false)
		return true
	return false


func release() -> void:
	_set_target(null, false)


## dir: +1 = right on screen, -1 = left on screen. Returns true if the target changed.
func switch(dir: int) -> bool:
	if not is_locked() or cooldown > 0.0:
		return false
	cooldown = switch_cooldown
	var t = pick_in_direction(dir)
	if t == null:
		switch_failed.emit(dir)
		return false
	_set_target(t, true)
	return true


# ------------------------------------------------------------------ selection
func _camera() -> Camera3D:
	if rig != null and is_instance_valid(rig) and rig.cam != null:
		return rig.cam
	return hero.get_viewport().get_camera_3d()


func focus_point(e) -> Vector3:
	return e.global_position + Vector3(0, 1.0 * (e.body_scale if "body_scale" in e else 1.0), 0)


func screen_pos(e) -> Vector2:
	var cam := _camera()
	return cam.unproject_position(focus_point(e)) if cam else Vector2.ZERO


func has_line_of_sight(e) -> bool:
	var space := hero.get_world_3d().direct_space_state
	var to := focus_point(e)
	var origins: Array = [hero.global_position + Vector3(0, 1.5, 0)]
	var cam := _camera()
	if cam:
		origins.append(cam.global_position)
	for o in origins:
		var q := PhysicsRayQueryParameters3D.create(o, to, Combatant.LAYER_WORLD)
		if space.intersect_ray(q).is_empty() and not SteamCloud.blocks(o, to):
			return true
	return false


func is_eligible(e, max_range: float) -> bool:
	if e == null or not is_instance_valid(e) or not e.is_targetable():
		return false
	if e.global_position.distance_to(hero.global_position) > max_range:
		return false
	var cam := _camera()
	if cam == null or cam.is_position_behind(focus_point(e)):
		return false
	var vp := hero.get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(focus_point(e))
	var m := vp * screen_margin
	if sp.x < -m.x or sp.y < -m.y or sp.x > vp.x + m.x or sp.y > vp.y + m.y:
		return false
	return has_line_of_sight(e)


func candidates(exclude = null) -> Array:
	var out: Array = []
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if e != exclude and is_eligible(e, acquire_range):
			out.append(e)
	return out


func best_center_target(exclude):
	var vp := hero.get_viewport().get_visible_rect().size
	var center := vp * 0.5
	var best = null
	var best_score := INF
	for e in candidates(exclude):
		var sp := screen_pos(e)
		var score: float = (sp - center).length() / vp.x + e.global_position.distance_to(hero.global_position) * 0.012
		if score < best_score:
			best_score = score
			best = e
	return best


func pick_in_direction(dir: int):
	var cur = current()
	if cur == null:
		return null
	var cp := screen_pos(cur)
	var best = null
	var best_score := INF
	for e in candidates(cur):
		var sp := screen_pos(e)
		var dx := sp.x - cp.x
		if dir > 0 and dx <= 4.0:
			continue
		if dir < 0 and dx >= -4.0:
			continue
		var score: float = absf(dx) + absf(sp.y - cp.y) * 0.5 + e.global_position.distance_to(hero.global_position) * 2.0
		if score < best_score:
			best_score = score
			best = e
	return best


# ------------------------------------------------------------------ validation / visuals
func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	cooldown = maxf(0.0, cooldown - delta)
	var t = hero.lock_target
	if t == null:
		return
	var invalid: bool = not is_instance_valid(t) or not t.is_targetable()
	if not invalid and t.global_position.distance_to(hero.global_position) > keep_range:
		invalid = true
	if not invalid:
		if has_line_of_sight(t):
			los_lost = 0.0
		else:
			los_lost += delta
			invalid = los_lost > los_grace
	if invalid:
		los_lost = 0.0
		var nxt = best_center_target(t if is_instance_valid(t) else null)
		_set_target(nxt, nxt != null)


func _process(delta: float) -> void:
	var t = current()
	ring.visible = t != null and t.is_targetable()
	if not ring.visible:
		return
	_pulse += delta
	var sc: float = (t.body_scale if "body_scale" in t else 1.0)
	var p := CameraRig.vis_pos(t)
	ring.global_transform = Transform3D(Basis().scaled(Vector3.ONE * sc * (1.0 + 0.04 * sin(_pulse * 5.0))), p + Vector3(0, 0.06, 0))
	ring_mat.albedo_color.a = 0.55 + 0.25 * sin(_pulse * 5.0)


func _set_target(t, switched: bool) -> void:
	var old = hero.lock_target
	if old == t:
		return
	hero.lock_target = t
	los_lost = 0.0
	_pulse = 0.0
	if rig:
		rig.on_target_changed(old, t, switched)
	target_changed.emit(old, t, switched)
