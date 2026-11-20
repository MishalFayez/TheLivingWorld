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
	for i in n:
		await tick()
		steps.append(rig.global_position.distance_to(prev))
		offs.append((rig.global_position - CameraRig.vis_pos(h)).length())
		prev = rig.global_position
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
	print("Engine %s | physics interpolation in use: %s | render fps 144 vs physics 60" % [Engine.get_version_info().string, rig.use_interpolation])
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
		max_jump = maxf(max_jump, absf(rig.cur_dist - prev_d))
		if rig.forced_snaps == snaps0:
			max_smooth = maxf(max_smooth, absf(rig.cur_dist - prev_d))
		snaps0 = rig.forced_snaps
		prev_d = rig.cur_dist
		min_d = minf(min_d, rig.cur_dist)
	Input.action_release("move_left")
	check(min_d < rig.distance - 0.5 and max_smooth < (0.7 if per_physics else 0.35), "near walls: occlusion pull-in is smooth (capped)", "min dist %.2f, max smooth change %.3f m/frame" % [min_d, max_smooth])
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
	print("\n==== CAMERA: %d passed, %d failed ====" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)
