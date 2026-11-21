class_name CameraRig
extends Node3D
## Third-person camera — the ONE authoritative owner of camera yaw / pitch / position.
##
## Jitter fix (root cause): characters move in _physics_process (60 Hz) but the camera used to
## follow them in _process at monitor rate with exponential smoothing, so on >60 Hz displays the
## body stepped while the camera glided. Now:
##   * physics interpolation is enabled (Godot 4.4+) and the camera follows the INTERPOLATED
##     transform of the hero every rendered frame -> body and camera move in lock-step;
##   * on engines without 3D physics interpolation (4.3) the camera updates in _physics_process so
##     it shares the character's update rate (no relative jitter);
##   * position follow is direct (no lag smoothing on top of interpolation);
##   * the camera follows the hero ROOT, never the animated Model, so attack / dodge animations
##     and the approach step cannot shake the view.
## Lock-on: yaw eases toward the target with frame-rate independent exponential gain and an angular
## speed cap; the mouse keeps a decaying manual offset; framing adapts slowly (no zoom pumping);
## the target crossing behind/over the player holds the last stable heading.
## Collision: manual sphere cast — pulls in quickly (never clips), eases back out (no pops).

@export_group("Free camera")
@export var distance: float = 5.2
@export var height: float = 1.55
@export var mouse_sensitivity: float = 0.0032
@export var pitch_min: float = -1.15
@export var pitch_max: float = 0.45
## Over-the-shoulder offset (metres, camera-right) so the hero never hides a locked target.
@export var shoulder_offset: float = 0.55
@export_group("Lock-on")
@export var lock_turn_gain: float = 7.5          ## 1/s exponential approach toward the lock heading
@export var lock_max_turn_speed: float = 4.2     ## rad/s cap (no violent swings)
@export var lock_pitch_gain: float = 4.0
@export var lock_enter_time: float = 0.35        ## blend-in time free -> lock
@export var switch_soften_time: float = 0.3      ## softer gain right after a target switch
@export var lock_offset_limit: float = 0.55      ## manual mouse yaw offset allowed while locked (rad)
@export var lock_offset_decay: float = 1.3       ## how fast the manual offset recentres (1/s)
@export var lock_extra_distance: float = 1.1     ## max extra pull-back for far targets
@export var lock_pivot_shift: float = 1.2        ## pivot moves toward the target to frame both
@export var behind_hold_distance: float = 1.9    ## target closer than this: hold last heading
@export var hold_blend_width: float = 0.7        ## 006: hold -> follow blends over [1.2m, 2.2m] (no hard switch)
@export_group("Collision")
@export var collision_radius: float = 0.28
@export var pull_in_speed: float = 12.0        ## proportional pull-in (1/s)
@export var pull_in_min_speed: float = 14.0    ## m/s minimum pull-in speed
@export var near_clip_radius: float = 0.14     ## camera near-plane volume that must never be inside geometry
@export var occlusion_pull_speed: float = 15.0
@export var min_collision_distance: float = 0.3 ## closest the camera may come to the pivot (was 0.6)
@export var prediction_time: float = 0.3      ## s of pivot motion used to see obstacles coming
@export var prediction_samples: int = 3       ## points sampled along the prediction horizon
@export var shoulder_collision: bool = true   ## keep the shoulder / lock pivot offset out of geometry
## look-ahead only: a wider probe sees an obstacle sweeping toward the boom earlier, so the capped pull-in
## starts sooner. The camera's own clearance (collision_radius) is unchanged.
@export var prediction_radius: float = 0.28
@export var ease_out_speed: float = 4.0

var target = null                 # the Hero
var yaw: float = 0.0
var pitch: float = -0.3
var lock_blend: float = 0.0
var lock_offset_yaw: float = 0.0
var lock_offset_pitch: float = 0.0
var lock_heading: float = 0.0
var _near_sphere: SphereShape3D
var _last_pivot: Vector3 = Vector3.ZERO
var _has_last_pivot: bool = false
var forced_snaps: int = 0
var lifts: int = 0
var close_ins: int = 0              ## frames resolved by moving inside min_collision_distance (debug / tests)
var max_snap: float = 0.0           ## largest anti-clipping snap so far (m, debug / tests)
var _offset_frac: float = 1.0
var _pred_sphere: SphereShape3D
var cam_lift: float = 0.0
var last_snap_info: String = ""     ## anti-clipping snaps (debug / tests)
var debug_track_inside: bool = false   ## tests: count frames where the final camera sphere overlaps geometry
var inside_frames: int = 0
var frame_dist: float = 5.2
var cur_dist: float = 5.2
var shift: Vector3 = Vector3.ZERO
var switch_soft: float = 0.0
var cam: Camera3D
var shake_amount: float = 0.0
var shake_t: float = 0.0
var use_interpolation: bool = false
var _sphere := SphereShape3D.new()
var _last_lock = null
var _limit_smooth: float = 5.2
@export var limit_rise_rate: float = 5.0   ## 1/s: how fast a RISING collision limit is followed (006)
var dbg_want: float = 0.0          ## diagnostics (006 probe)
var dbg_target: float = 0.0
var dbg_blocked: bool = false


static func interpolation_available() -> bool:
	var v := Engine.get_version_info()
	return v.hex >= 0x040400 and bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))


## Visual (interpolated when available) position of a node.
static func vis_pos(n: Node3D) -> Vector3:
	if interpolation_available():
		return n.get_global_transform_interpolated().origin
	return n.global_position


func _ready() -> void:
	top_level = true
	set("physics_interpolation_mode", 2)   # OFF: the rig is driven manually every frame
	use_interpolation = interpolation_available()
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 400
	cam.near = 0.08
	add_child(cam)
	cam.current = true
	_sphere.radius = collision_radius
	frame_dist = distance
	cur_dist = distance
	if target:
		yaw = target.rotation.y
		snap_to_target()


func snap_to_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	shift = Vector3.ZERO
	_apply(target.global_position, 0.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or Game.ui_block > 0 or Game.wheel_open:
		return
	var sens: float = mouse_sensitivity * float(Save.settings.get("mouse_sensitivity", 1.0))
	var dx: float = event.relative.x * sens
	var dy: float = event.relative.y * sens * (-1.0 if Save.settings.get("invert_y", false) else 1.0)
	if _locked() != null:
		lock_offset_yaw = clampf(lock_offset_yaw - dx, -lock_offset_limit, lock_offset_limit)
		lock_offset_pitch = clampf(lock_offset_pitch - dy, -0.35, 0.35)
	else:
		yaw -= dx
		pitch = clampf(pitch - dy, pitch_min, pitch_max)


func add_shake(a: float) -> void:
	if not Save.settings.get("camera_shake", true):
		return
	shake_amount = maxf(shake_amount, a)


## Called by the lock-on system when the target changes.
func on_target_changed(_old, new_target, switched: bool) -> void:
	if switched:
		switch_soft = switch_soften_time
	if new_target == null:
		# Lock -> free: keep exactly the current view direction (fold the manual offset in).
		lock_offset_yaw = 0.0
		lock_offset_pitch = 0.0


func _locked():
	if target == null or not is_instance_valid(target):
		return null
	var l = target.lock_target
	if l != null and is_instance_valid(l) and l.is_targetable():
		return l
	return null


func _process(delta: float) -> void:
	if use_interpolation:
		_update(delta)


func _physics_process(delta: float) -> void:
	if not use_interpolation:
		_update(delta)


func _update(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var hp: Vector3 = vis_pos(target) if use_interpolation else target.global_position
	var lock = _locked()
	lock_blend = move_toward(lock_blend, 1.0 if lock != null else 0.0, delta / maxf(lock_enter_time, 0.01))
	var desired_dist := distance
	var desired_shift := Vector3.ZERO
	if lock != null:
		var tp: Vector3 = vis_pos(lock) if use_interpolation else lock.global_position
		var to := tp - hp
		to.y = 0.0
		var d := to.length()
		if _last_lock != lock:
			lock_heading = yaw if d < behind_hold_distance else atan2(-to.x, -to.z)
			_last_lock = lock
		# COMBAT-BALANCE-UX-006 jitter root cause: the heading used to switch HARD between "hold" (< 1.9m) and
		# "follow" (>= 1.9m). Blade Dancer fights at 1.2-2.2m, so lateral Dance / Orbit crossed that line and
		# the camera got a sudden yaw acceleration (measured ~1100 rad/s^2 spikes). Now the follow strength
		# blends smoothly across hold_blend_width around the threshold; far targets behave exactly as before.
		var w := smoothstep(behind_hold_distance - hold_blend_width, behind_hold_distance + 0.3, d)
		if w >= 0.999:
			lock_heading = atan2(-to.x, -to.z)
		elif w > 0.0:
			lock_heading = lerp_angle(lock_heading, atan2(-to.x, -to.z), 1.0 - exp(-12.0 * w * delta))
		# manual offset recentres smoothly
		var decay := exp(-lock_offset_decay * delta)
		lock_offset_yaw *= decay
		lock_offset_pitch *= decay
		var ease_k := lock_blend * lock_blend * (3.0 - 2.0 * lock_blend)
		var gain := lock_turn_gain * ease_k * (0.45 if switch_soft > 0.0 else 1.0)
		var diff := wrapf(lock_heading + lock_offset_yaw - yaw, -PI, PI)
		var step := diff * (1.0 - exp(-gain * delta))
		step = clampf(step, -lock_max_turn_speed * delta, lock_max_turn_speed * delta)
		yaw += step
		# pitch: comfortable downward look; large enemies don't drag the camera upward
		var desired_pitch := clampf(-0.2 - 0.9 / maxf(d, 2.0), -0.55, -0.22) + lock_offset_pitch
		pitch = lerpf(pitch, desired_pitch, 1.0 - exp(-lock_pitch_gain * ease_k * delta))
		desired_dist = distance + clampf((d - 4.0) * 0.1, 0.0, lock_extra_distance)
		if d > 0.5:
			desired_shift = to / d * minf(d * 0.2, lock_pivot_shift) * ease_k
	else:
		_last_lock = null
	switch_soft = maxf(0.0, switch_soft - delta)
	# slow, frame-rate independent framing changes (no zoom pumping)
	frame_dist = lerpf(frame_dist, desired_dist, 1.0 - exp(-1.2 * delta))
	shift = shift.lerp(desired_shift, 1.0 - exp(-3.0 * delta))
	_apply(hp, delta, false)


func _apply(hp: Vector3, delta: float, snap: bool) -> void:
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	# the shoulder offset and lock framing shift must never push the pivot through a wall: otherwise the
	# occlusion cast starts inside geometry and the camera ends frames inside it (hero backed into the side wall)
	var head := hp + Vector3(0, height, 0)
	var off := shift + b.x * shoulder_offset
	if shoulder_collision:
		# shrink at once (never through a wall), recover gradually (no sideways swing back into it)
		var safe := _clear_fraction(head, off)
		_offset_frac = safe if (snap or safe < _offset_frac) else move_toward(_offset_frac, safe, ease_out_speed * 0.5 * delta)
		off *= _offset_frac
	var pivot := head + off
	var back := b.z
	# Near-wall fix. Two different cases when geometry is behind the hero:
	#  * geometry only passes BETWEEN hero and camera (pillar / tree / wall edge while strafing): pull in at
	#    a capped speed, so a thin occluder no longer yanks the view ~0.66 m in a single frame;
	#  * the capped step would leave the camera's near plane INSIDE geometry (a wall section sweeping
	#    into the camera): snap to the safe distance - never showing the inside of a wall wins.
	var want := _collision_distance(pivot, back, frame_dist)
	# look-ahead along the pivot's own motion (strafing past a trunk / pillar / wall edge): start the
	# capped pull-in BEFORE the obstacle reaches the camera, so no anti-clipping snap is needed
	var target := want
	if not snap and delta > 0.0 and _has_last_pivot:
		var pv := (pivot - _last_pivot) / delta
		pv.y = 0.0
		if pv.length() > 0.3:
			# sample the whole horizon, not only its end: an obstacle crossed WITHIN the horizon (sliding past a
			# pillar on a curved path) is otherwise missed, the camera eases out, and later needs a snap
			for k in range(1, prediction_samples + 1):
				var t := prediction_time * float(k) / float(prediction_samples)
				target = minf(target, _collision_distance(pivot + pv * t, back, frame_dist, prediction_radius))
	_last_pivot = pivot
	_has_last_pivot = true
	# COMBAT-BALANCE-UX-006 jitter fix: cast_motion returns a QUANTIZED safe fraction, so while the boom is
	# limited by geometry the limit rises in 2-3 cm steps on alternate frames and the camera copied that
	# staircase (measured: position acceleration spikes on 70% of frames while locked). Decreases still apply
	# at once (never clip); increases are low-passed, so easing out is smooth. Never above the real limit.
	var raw_target := target
	if snap or target < _limit_smooth - 0.05 or target < cur_dist - 0.005 or (target < _limit_smooth and _penetrating(pivot + back * _limit_smooth)):
		_limit_smooth = target
	elif target < _limit_smooth:
		pass    # a quantization dip of a few cm that would not put the camera inside geometry: hold
	else:
		_limit_smooth = minf(target, lerpf(_limit_smooth, target, 1.0 - exp(-limit_rise_rate * delta)))
	target = _limit_smooth
	if snap:
		cur_dist = want
	elif target < cur_dist:
		var next_d := move_toward(cur_dist, target, occlusion_pull_speed * delta)
		if _penetrating(pivot + back * next_d):
			if debug_track_inside:
				last_snap_info = _overlap_info(pivot + back * next_d) + " d %.2f->%.2f" % [cur_dist, want]
			max_snap = maxf(max_snap, cur_dist - want)
			next_d = want
			forced_snaps += 1
		cur_dist = next_d
	else:
		# never ease OUT into geometry: at a wall the eased step would penetrate, be snapped back next
		# frame and repeat every 2-3 frames (a visible ~7cm oscillation)
		# a held quantization dip keeps the camera where it is, but never lets it ease OUT past the real
		# limit (that space can turn solid a frame later and force a small snap-back at walls)
		var out_d := move_toward(cur_dist, maxf(cur_dist, minf(target, raw_target)), ease_out_speed * delta)
		dbg_want = want
		dbg_target = target
		dbg_blocked = not (out_d <= cur_dist or snap or not _penetrating(pivot + back * out_d))
		if out_d <= cur_dist or snap or not _penetrating(pivot + back * out_d):
			cur_dist = out_d
	var cam_pos := pivot + back * cur_dist
	# min_collision_distance must never place the near plane inside geometry (hero backed into a tall
	# boundary wall): the pivot is kept clear above, so first move toward it until clear
	if _penetrating(cam_pos):
		var d := cur_dist
		while d > 0.0 and _penetrating(pivot + back * d):
			d = maxf(0.0, d - 0.05)
		if not _penetrating(pivot + back * d):
			cam_pos = pivot + back * d
			close_ins += 1
	# last resort: even the minimum distance is inside geometry (hero pressed against a pillar / trunk
	# with the camera on the far side) -> lift the camera over it instead of sitting inside it
	var lift := 0.0
	if _penetrating(cam_pos):
		for i in 8:
			lift += 0.2
			if not _penetrating(cam_pos + Vector3(0, lift, 0)):
				break
		lifts += 1
	cam_lift = move_toward(cam_lift, lift, (8.0 if lift > cam_lift else 2.0) * delta) if lift <= cam_lift else lift
	global_transform = Transform3D(b, cam_pos + Vector3(0, cam_lift, 0))
	if debug_track_inside and _penetrating(global_position):
		inside_frames += 1
	# smooth (non-random) impact shake
	if cam == null or not is_instance_valid(cam):
		return
	if shake_amount > 0.0:
		shake_t += delta
		shake_amount = maxf(0.0, shake_amount - delta * 1.8)
		cam.h_offset = sin(shake_t * 47.0) * shake_amount * 0.12
		cam.v_offset = cos(shake_t * 39.0) * shake_amount * 0.12
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## true when the camera's near-plane volume (sphere of near_clip_radius) is inside world geometry
func _penetrating(cam_pos: Vector3) -> bool:
	if not is_inside_tree():
		return false
	if _near_sphere == null:
		_near_sphere = SphereShape3D.new()
		_near_sphere.radius = near_clip_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _near_sphere
	q.transform = Transform3D(Basis(), cam_pos)
	q.collision_mask = Combatant.LAYER_WORLD
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _overlap_info(p: Vector3) -> String:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _near_sphere
	q.transform = Transform3D(Basis(), p)
	q.collision_mask = Combatant.LAYER_WORLD
	var r := get_world_3d().direct_space_state.intersect_shape(q, 4)
	var out := "cam %s:" % str(p.snapped(Vector3.ONE * 0.01))
	for h in r:
		var col = h.collider
		var shp = col.shape_owner_get_owner(col.shape_find_owner(h.shape)) if col is CollisionObject3D else null
		out += " [%s/%s %s at %s]" % [col.name, shp.name if shp else "?", str(shp.shape.get_class()) if shp and "shape" in shp else "", str((shp.global_position if shp else col.global_position).snapped(Vector3.ONE * 0.01))]
	return out


## Fraction (0..1) of a pivot offset (shoulder + lock shift) the camera sphere can travel clear of geometry.
func _clear_fraction(from: Vector3, offset: Vector3) -> float:
	if not is_inside_tree() or offset.length() < 0.001:
		return 1.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere
	q.transform = Transform3D(Basis(), from)
	q.motion = offset
	q.collision_mask = Combatant.LAYER_WORLD
	var res := get_world_3d().direct_space_state.cast_motion(q)
	if res.size() >= 1 and res[0] < 1.0:
		return res[0]
	return 1.0


func _collision_distance(pivot: Vector3, back: Vector3, want: float, radius: float = -1.0) -> float:
	if not is_inside_tree():
		return want
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere
	if radius > 0.0 and absf(radius - collision_radius) > 0.001:
		if _pred_sphere == null or absf(_pred_sphere.radius - radius) > 0.001:
			_pred_sphere = SphereShape3D.new()
			_pred_sphere.radius = radius
		q.shape = _pred_sphere
	q.transform = Transform3D(Basis(), pivot)
	q.motion = back * want
	q.collision_mask = Combatant.LAYER_WORLD
	var res := get_world_3d().direct_space_state.cast_motion(q)
	if res.size() >= 1 and res[0] < 1.0:
		return maxf(min_collision_distance, want * res[0])
	return want


func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func flat_right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))
