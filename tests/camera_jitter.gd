extends Node
## Camera stability test. Run with a render rate ABOVE the physics rate to reproduce the original jitter:
##   godot --headless --fixed-fps 144 res://tests/camera_jitter.tscn
## Measures how evenly the camera advances per rendered frame while the hero walks, attacks, dodges
## and slides along a wall. CV (std/mean of per-frame displacement) near 0 = smooth; the old camera
## produced alternating zero / large steps (CV ~ 0.6-1.0) because the body moved only on physics ticks.

var ok := 0
var bad := 0


func check(c: bool, n: String, d: String = "") -> void:
	if c:
		ok += 1
		print("  PASS  ", n, "  ", d)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)


var per_physics: bool = false


## Frame source: rendered frames when 3D physics interpolation exists (4.4+); physics ticks on 4.3,
## where the camera (by design) updates together with the character on the physics tick.
func tick() -> void:
	if per_physics:
		await get_tree().physics_frame
	else:
		await get_tree().process_frame


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func measure(rig: CameraRig, h: Hero, n: int) -> Dictionary:
	var prev := rig.global_position
	var steps: Array = []
	var offs: Array = []
	# process_frame fires BEFORE nodes run _process: the rig read here is the one placed last frame, from the
	# hero position read last frame. Comparing it with THIS frame's hero position measured one frame of hero
	# motion (scaling with frame time) instead of camera behaviour, so the previous hero sample is used.
	var prev_hero := CameraRig.vis_pos(h)
	for i in n:
		await tick()
		steps.append(rig.global_position.distance_to(prev))
		offs.append((rig.global_position - prev_hero).length())
		prev = rig.global_position
		prev_hero = CameraRig.vis_pos(h)
	var mean := 0.0
	for s in steps:
		mean += s
	mean /= steps.size()
	var v := 0.0
	for s in steps:
		v += (s - mean) * (s - mean)
	var cv := sqrt(v / steps.size()) / maxf(mean, 0.00001)
	var omin := 999.0
	var omax := 0.0
	for o in offs:
		omin = minf(omin, o)
		omax = maxf(omax, o)
	return {"cv": cv, "mean": mean, "offset_range": omax - omin}


## Lock-on camera motion, measured per second so the limits hold at any frame rate.
func _yaw_watch(rig: CameraRig, n: int) -> Dictionary:
	var prev := rig.yaw
	var prev_pos := rig.global_position
	var max_rate := 0.0
	var max_speed := 0.0
	for i in n:
		await tick()
		var dt := get_physics_process_delta_time() if per_physics else get_process_delta_time()
		max_rate = maxf(max_rate, absf(wrapf(rig.yaw - prev, -PI, PI)) / maxf(dt, 0.0001))
		max_speed = maxf(max_speed, rig.global_position.distance_to(prev_pos) / maxf(dt, 0.0001))
		prev = rig.yaw
		prev_pos = rig.global_position
	return {"rate": max_rate, "speed": max_speed}


func _in_view(rig: CameraRig, p: Vector3) -> bool:
	return rig.cam.is_position_in_frustum(p) and not rig.cam.is_position_behind(p)


func _lock_checks(h: Hero, rig: CameraRig) -> void:
	var lock: LockOnSystem = h.get_node("Brain").lock
	h.teleport(Vector3(0, 0.2, 20))
	rig.yaw = 0.0
	rig.snap_to_target()
	await frames(10)
	var foes: Array = []
	for i in 3:
		var e := Game.spawn_enemy("raider", h.global_position + Vector3(-5.0 + i * 5.0, 0.0, -8.0), "outskirts")
		e.sm.set_physics_process(false)
		foes.append(e)
	rig.yaw = 0.35             # target off-centre: locking must turn the camera, within its speed cap
	await frames(5)
	var cap := rig.lock_max_turn_speed * 1.05
	check(lock.acquire(), "lock-on acquires a target")
	var enter := await _yaw_watch(rig, 90)
	check(enter.rate <= cap and _in_view(rig, lock.focus_point(lock.current())), "lock enter: yaw turn speed-capped, target framed", "max %.2f rad/s (cap %.2f)" % [enter.rate, rig.lock_max_turn_speed])
	var sw0 = lock.current()
	lock.switch(1)
	var sw := await _yaw_watch(rig, 60)
	check(lock.current() != sw0 and sw.rate <= cap, "target switch: no yaw jump", "max %.2f rad/s" % sw.rate)
	Input.action_press("move_left")
	var strafe := await _yaw_watch(rig, 90)
	Input.action_release("move_left")
	var t = lock.current()
	check(is_instance_valid(t) and _in_view(rig, lock.focus_point(t)) and strafe.rate <= cap and strafe.speed < 12.0, "strafing while locked: target stays framed, no camera jump", "yaw %.2f rad/s, cam %.1f m/s" % [strafe.rate, strafe.speed])
	lock.release()
	var yaw_before := rig.yaw
	var rel := await _yaw_watch(rig, 30)
	check(absf(wrapf(rig.yaw - yaw_before, -PI, PI)) < 0.05 and rel.speed < 12.0, "unlock: the view direction is kept (no snap back)", "yaw drift %.3f rad" % absf(wrapf(rig.yaw - yaw_before, -PI, PI)))
	for e in foes:
		e.queue_free()
	# boss framing: the large Warden must stay framed and must not drag the camera upward
	h.teleport(Vector3(0, 0.2, 20))
	rig.yaw = 0.0
	rig.snap_to_target()
	var boss := Game.spawn_enemy("ashen_warden", h.global_position + Vector3(0, 0, -9), "keep")
	boss.sm.set_physics_process(false)
	await frames(10)
	var got := lock.acquire()
	var bw := await _yaw_watch(rig, 120)
	var top := boss.global_position + Vector3(0, 2.2, 0)
	var locked_boss: bool = got and lock.current() == boss
	var boss_view := _in_view(rig, lock.focus_point(boss))
	var hero_view := _in_view(rig, h.global_position + Vector3(0, 1.0, 0))
	check(locked_boss and boss_view and hero_view and rig.pitch <= -0.2 and bw.rate <= cap, "boss framing: boss and hero in view, comfortable downward pitch",
		"locked %s, boss %s, hero %s, pitch %.2f, rate %.2f | INFO top of boss in view: %s" % [locked_boss, boss_view, hero_view, rig.pitch, bw.rate, _in_view(rig, top)])
	lock.release()
	boss.queue_free()
	await frames(5)


func _ready() -> void:
	Game.auto_open_drafts = false
	var world = load("res://scenes/world/ashen_valley.tscn").instantiate()
	add_child(world)
	Game.start_session(world, "vanguard", false)
	await frames(30)
	# isolate from encounters (hits cause intentional hitstop / knockback, not camera jitter)
	for area in world.zones:
		for z in world.zones[area]:
			z.done = true
	Game.invincible = true
	var h := Game.player
	var rig: CameraRig = h.get_node("Brain").rig
	h.teleport(Vector3(0, 0.2, 20))
	rig.snap_to_target()
	per_physics = not rig.use_interpolation
	if per_physics:
		print("NOTE: no 3D physics interpolation on this engine -> camera + character update together on the physics tick; measuring per physics step.")
	print("Engine %s | physics interpolation in use: %s | physics %d Hz (run with --fixed-fps 144 to render faster than physics)" % [Engine.get_version_info().string, rig.use_interpolation, Engine.physics_ticks_per_second])
	await frames(20)
	Input.action_press("move_forward")
	await frames(40)
	var walk := await measure(rig, h, 144)
	check(walk.cv < (0.15 if per_physics else 0.05), "walking: camera advances evenly every rendered frame", "CV %.3f (mean %.4f m/frame)" % [walk.cv, walk.mean])
	check(walk.offset_range < 0.08, "walking: camera-to-hero distance stays constant", "range %.3f m" % walk.offset_range)
	# rapid direction changes
	Input.action_release("move_forward")
	var turn_offs := 0.0
	for k in 6:
		Input.action_press("move_left" if k % 2 == 0 else "move_right")
		var m := await measure(rig, h, 24)
		turn_offs = maxf(turn_offs, m.offset_range)
		Input.action_release("move_left" if k % 2 == 0 else "move_right")
	check(turn_offs < 0.12, "rapid direction changes: no camera jumps", "max offset range %.3f m" % turn_offs)
	# attacking + dodging while moving: camera follows the root, not animated parts
	Input.action_press("move_forward")
	h.press("light")
	h.release("light")
	var atk := await measure(rig, h, 60)
	h.press("dodge")
	h.release("dodge")
	var dod := await measure(rig, h, 70)
	Input.action_release("move_forward")
	check(atk.offset_range < 0.1 and dod.offset_range < 0.1, "attack + dodge: camera stays locked to the hero (no shake)", "attack %.3f m, dodge %.3f m" % [atk.offset_range, dod.offset_range])
	# wall: back the camera into a wall and move along it
	h.teleport(Vector3(28.0, 0.2, 0.0))
	rig.yaw = -PI / 2.0   # looking toward -X, camera behind the hero at +X (into the side wall)
	rig.snap_to_target()
	await frames(10)
	var max_jump := 0.0
	var prev_d := rig.cur_dist
	var min_d := 99.0
	var max_smooth := 0.0
	var snaps0: int = rig.forced_snaps
	rig.debug_track_inside = true
	rig.inside_frames = 0
	Input.action_press("move_left")
	for i in 120:
		await tick()
		var dt := get_physics_process_delta_time() if per_physics else get_process_delta_time()
		max_jump = maxf(max_jump, absf(rig.cur_dist - prev_d))
		if rig.forced_snaps == snaps0:
			max_smooth = maxf(max_smooth, absf(rig.cur_dist - prev_d) / maxf(dt, 0.0001))
		snaps0 = rig.forced_snaps
		prev_d = rig.cur_dist
		min_d = minf(min_d, rig.cur_dist)
	Input.action_release("move_left")
	# frame-rate independent: the pull-in is a SPEED cap (occlusion_pull_speed m/s), so measure m/s
	check(min_d < rig.distance - 0.5 and max_smooth <= rig.occlusion_pull_speed * 1.05, "near walls: occlusion pull-in is smooth (speed-capped)", "min dist %.2f, max smooth %.1f m/s (cap %.1f)" % [min_d, max_smooth, rig.occlusion_pull_speed])
	print("  INFO  near walls: anti-clipping snaps this run = %d (largest frame change %.3f m) %s" % [rig.forced_snaps, max_jump, rig.last_snap_info])
	check(rig.inside_frames == 0, "near walls: the camera near-plane never ends a frame inside geometry", "%d rendered frames" % rig.inside_frames)
	# extra sweeps: both directions, two speeds, both side walls, two camera yaws (snap census)
	var snaps_before: int = rig.forced_snaps
	var inside_before: int = rig.inside_frames
	var runs := 0
	for spot in [Vector3(28.0, 0.2, 0.0), Vector3(-28.0, 0.2, 0.0), Vector3(28.0, 0.2, -12.0)]:
		for yaw in [-PI / 2.0, PI / 2.0, -PI / 3.0]:
			for dir in ["move_left", "move_right"]:
				h.teleport(spot)
				rig.yaw = yaw
				rig.snap_to_target()
				await frames(5)
				Input.action_press(dir)
				for i in 90:
					await tick()
				Input.action_release(dir)
				runs += 1
	var extra_snaps: int = rig.forced_snaps - snaps_before
	print("  INFO  wall sweep census: %d runs, %d anti-clipping snaps, %d frames inside geometry %s" % [runs, extra_snaps, rig.inside_frames - inside_before, rig.last_snap_info])
	check(rig.inside_frames - inside_before == 0, "wall sweep census: camera never ends a frame inside geometry", "%d snaps in %d runs" % [extra_snaps, runs])
	# AUDIT regression 1: the documented 0.57m snap at the tall pillar (26, 2.25, -2) came from sampling only
	# the END of the look-ahead horizon while the hero slid around the pillar; the horizon is now sampled.
	check(extra_snaps == 0, "wall sweep census: no anti-clipping snap (pillar look-ahead samples the whole horizon)", "%d snaps in %d runs" % [extra_snaps, runs])
	# AUDIT regression 2: hero backed into the tall side boundary wall with the camera at an oblique angle.
	# The shoulder offset pushed the pivot through the wall and min_collision_distance kept the camera
	# inside it (23 rendered frames per run before the fix).
	var oblique_inside: int = rig.inside_frames
	for spot in [Vector3(28.0, 0.2, 0.0), Vector3(28.0, 0.2, -12.0), Vector3(26.0, 0.2, -5.0)]:
		h.teleport(spot)
		rig.yaw = PI / 4.0
		rig.snap_to_target()
		await frames(5)
		Input.action_press("move_right")
		for i in 90:
			await tick()
		Input.action_release("move_right")
	check(rig.inside_frames - oblique_inside == 0, "boundary wall at an oblique camera angle: never a frame inside geometry", "%d rendered frames" % (rig.inside_frames - oblique_inside))
	# REVIEW-001: at the wall the camera eased out by ~7cm, penetrated and was snapped back every 2-3 frames
	var osc_snaps: int = rig.forced_snaps
	h.teleport(Vector3(28.0, 0.2, 0.0))
	rig.yaw = PI / 4.0
	rig.snap_to_target()
	await frames(5)
	Input.action_press("move_right")
	var small_snaps := 0
	var big_snaps := 0
	var seen: int = rig.forced_snaps
	var before_d: float = rig.cur_dist
	for i in 120:
		await tick()
		if rig.forced_snaps > seen:
			if before_d - rig.cur_dist < 0.15:
				small_snaps += 1       # the oscillation signature: tiny ease-out then snap back
			else:
				big_snaps += 1
		seen = rig.forced_snaps
		before_d = rig.cur_dist
	Input.action_release("move_right")
	check(small_snaps == 0, "hugging a wall: no ease-out / snap-back oscillation", "%d small snap-backs; INFO %d larger snap(s) %s" % [small_snaps, big_snaps, rig.last_snap_info if big_snaps > 0 else ""])
	await _lock_checks(h, rig)
	print("\n==== CAMERA: %d passed, %d failed ====" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)
