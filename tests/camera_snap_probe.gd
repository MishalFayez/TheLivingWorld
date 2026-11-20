extends Node
## CAMERA SNAP PROBE (REVIEW-002). A measurement tool, NOT a pass/fail suite and NOT part of
## tools/dev/Test.ps1. It reproduces the remaining anti-clipping snaps documented in
## collaboration/results/CAMERA_REMAINING_JUMPS.md and prints every snap with the exact setup, so a
## change can be compared before/after. It does not change camera behaviour.
##   godot --headless --fixed-fps 60  res://tests/camera_snap_probe.tscn
##   godot --headless --fixed-fps 144 res://tests/camera_snap_probe.tscn
## Sweep: 4 spots around the tall pillar / east boundary wall x 8 camera yaws x strafe left/right,
## 90 rendered frames each (64 runs), the same census used in REVIEW-001.

const SPOTS := [Vector3(28.0, 0.2, 0.0), Vector3(24.0, 0.2, -2.0), Vector3(26.0, 0.2, -5.0), Vector3(28.0, 0.2, -12.0)]


func _ready() -> void:
	preload("res://tests/test_save_guard.gd").isolate("camera_snap_probe")
	Game.auto_open_drafts = false
	var world = load("res://scenes/world/ashen_valley.tscn").instantiate()
	add_child(world)
	Game.start_session(world, "vanguard", false)
	for i in 30:
		await get_tree().process_frame
	for area in world.zones:
		for z in world.zones[area]:
			z.done = true
	Game.invincible = true
	var h := Game.player
	var rig: CameraRig = h.get_node("Brain").rig
	rig.debug_track_inside = true
	print("Engine %s | physics %d Hz | prediction_samples %d | occlusion_pull_speed %.1f m/s | args %s" % [
		Engine.get_version_info().string, Engine.physics_ticks_per_second, rig.prediction_samples,
		rig.occlusion_pull_speed, str(OS.get_cmdline_args())])
	var runs := 0
	var snaps := 0
	var inside0: int = rig.inside_frames
	var largest := 0.0
	for si in SPOTS.size():
		for yi in 8:
			for dir in ["move_left", "move_right"]:
				var spot: Vector3 = SPOTS[si]
				h.teleport(spot)
				rig.yaw = -PI + yi * PI / 4.0
				rig.snap_to_target()
				for i in 5:
					await get_tree().process_frame
				var seen: int = rig.forced_snaps
				var prev: float = rig.cur_dist
				Input.action_press(dir)
				for f in 90:
					await get_tree().process_frame
					if rig.forced_snaps > seen:
						var size := absf(prev - rig.cur_dist)
						largest = maxf(largest, size)
						snaps += rig.forced_snaps - seen
						print("SNAP run %d: spot %s yaw_index %d (yaw %.3f rad) %s frame %d | camera distance %.2f -> %.2f m (%.2f m) | hero at %s | %s" % [
							runs, str(spot), yi, rig.yaw, dir, f, prev, rig.cur_dist, size, str(h.global_position.snapped(Vector3.ONE * 0.01)), rig.last_snap_info])
					seen = rig.forced_snaps
					prev = rig.cur_dist
				Input.action_release(dir)
				runs += 1
	print("\n==== CAMERA SNAP PROBE: %d runs, %d anti-clipping snaps, largest %.2f m, %d frames inside geometry ====" % [
		runs, snaps, largest, rig.inside_frames - inside0])
	get_tree().quit(0)
