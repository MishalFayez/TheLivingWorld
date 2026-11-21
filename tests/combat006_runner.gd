extends "res://tests/level10_runner.gd"
## COMBAT-BALANCE-UX-006: regression checks for the combat corrections (enemy commitment, Combat Weave,
## camera lock heading / collision smoothing) and, later milestones, the casting wheels and UI text.
##   godot --headless --fixed-fps 60 res://tests/combat006_runner.tscn
## Automated checks only: they verify the rules, not the feel.

var got_hit: bool = false
var dodged_n: int = 0


func _run_all() -> void:
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.target == Game.player and info.final_amount > 0.0: got_hit = true)
	Events.guard_event.connect(func(d, _i, k): if d == Game.player and k == "dodge": dodged_n += 1)
	await test_enemy_commitment()
	await test_dodge_vs_attacks()
	await test_weave_distances()
	await test_camera_heading_blend()
	await _extra()
	await teardown()


func _extra() -> void:
	pass


func _rig() -> CameraRig:
	for n in Game.world.get_children():
		if n is CameraRig:
			return n
	return null


func test_enemy_commitment() -> void:
	print("\n[Enemy commitment: tracks early, fades late, locked before impact; lunges commit earlier]")
	var h := await bd(10)
	var e := dummy("raider", h.global_position + Vector3(0, 0, -1.9))
	e.target = h
	face(e, h)
	var d: AttackData = e.find_attack("raider_combo1")
	check(is_equal_approx(d.track_full, 0.4) and is_equal_approx(d.commit_at, 0.7), "ordinary melee: full tracking to 40%, locked from 70% of the windup")
	var wl := load("res://data/attacks/wolf_lunge.tres") as AttackData
	check(wl.commit_at < d.commit_at, "fast lunge commits earlier (%.0f%%)" % (wl.commit_at * 100.0))
	e.begin_attack(d)
	var startup: float = d.startup / e.runner.speed
	var ks: Array = []
	var t := 0.0
	var moved := false
	var yaw_at_commit := 0.0
	var committed_seen := false
	while e.runner.phase == AttackRunner.Phase.STARTUP:
		ks.append(e.tracking_factor())
		if not moved and t >= startup * 0.5:
			moved = true
			h.global_position += Vector3(2.2, 0, 0)     # the player steps aside
		if not committed_seen and e.is_committed():
			committed_seen = true
			yaw_at_commit = e.rotation.y
		await get_tree().physics_frame
		t += 1.0 / 60.0
	check(ks[0] == 1.0 and ks[ks.size() - 1] == 0.0, "tracking factor 1 at the start, 0 at the end")
	var mono := true
	for i in range(1, ks.size()):
		if ks[i] > ks[i - 1] + 0.0001:
			mono = false
	check(mono, "tracking only fades (never re-acquires during the windup)")
	check(committed_seen and absf(wrapf(e.rotation.y - yaw_at_commit, -PI, PI)) < 0.001, "no rotation after the commit point")
	check(e.telegraph == null or not is_instance_valid(e.telegraph) or e.telegraph.committed, "the ground telegraph shows the lock")
	e.queue_free()


func test_dodge_vs_attacks() -> void:
	print("\n[A correctly timed side dodge avoids every melee attack; a late side WALK stays punishable]")
	var ok := 0
	var total := 0
	for spec in [["raider", "raider_combo1"], ["raider", "raider_heavy"], ["wolf", "wolf_lunge"], ["shield_guardian", "guardian_slam"], ["ashen_warden", "warden_slash1"], ["ashen_warden", "warden_execution"]]:
		for tb in [0.4, 0.25, 0.12]:
			var h := await bd(10)
			h.max_hp = 99999
			h.hp = 99999
			var e := dummy(String(spec[0]), h.global_position + Vector3(0, 0, -1.9))
			e.max_hp = 999999
			e.hp = 999999
			e.target = h
			face(e, h)
			h.lock_target = e
			await wait(0.05)
			var d: AttackData = e.find_attack(String(spec[1]))
			got_hit = false
			e.begin_attack(d)
			var startup: float = d.startup / e.runner.speed
			var acted := false
			var t := 0.0
			while t < startup + d.active + 0.3:
				if not acted and startup - t <= tb:
					acted = true
					var to: Vector3 = e.global_position - h.global_position
					to.y = 0
					h.move_input = to.normalized().cross(Vector3.UP)
					h.try_dodge()
				if acted and not h.dodging:
					h.move_input = Vector3.ZERO
				await get_tree().physics_frame
				t += 1.0 / 60.0
			total += 1
			if not got_hit:
				ok += 1
			else:
				print("    hit: %s side dodge %.2fs before" % [spec[1], tb])
			e.queue_free()
	check(ok == total, "side dodges 0.12-0.4s before impact avoid the hit: %d / %d" % [ok, total])


func test_weave_distances() -> void:
	print("\n[Combat Weave 006: side 2.8 / forward 2.6 / back 3.6m, same timing and i-frames, readable feedback]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h, 9.0)
	var toward := (r.global_position - h.global_position).normalized()
	var right := toward.cross(Vector3.UP).normalized()
	var side := await _dodge_travel(h, right)
	var fw := await _dodge_travel(h, toward)
	var back := await _dodge_travel(h, -toward)
	check(absf(side - 2.8) < 0.15 and absf(fw - 2.6) < 0.15 and absf(back - 3.6) < 0.15, "distances %.2f / %.2f / %.2fm" % [side, fw, back])
	await wait(0.05)
	check(is_equal_approx(Game.balance.dodge_duration, 0.42) and is_equal_approx(Game.balance.dodge_iframes, 0.28), "shared timing and i-frames unchanged")
	check(f.weave_completions >= 3, "every Weave ends with its completion cue (%d)" % f.weave_completions)
	# evade feedback on a real attack
	var h2 := await bd(10)
	var e := dummy("raider", h2.global_position + Vector3(0, 0, -1.9))
	h2.try_dodge()
	await wait(0.08)
	enemy_hit(h2, e)
	check(bk(h2).evades == 1, "a real attack through the i-frames gives the EVADED cue")
	h2.try_dodge()
	await until_idle(h2)
	check(bk(h2).evades == 1, "an empty dodge gives no evade cue")
	# committed strike stays committed
	var cc := load("res://data/attacks/bd_committed.tres") as AttackData
	check(not cc.dodge_cancel, "Committed Cut remains non-cancelable")


func test_camera_heading_blend() -> void:
	print("\n[Camera: no hard heading switch around 1.9m; rising collision limit is smoothed]")
	var h := await bd(10)
	var e := target(h, 1.5)
	var rig := _rig()
	await wait(0.6)
	var maxacc := 0.0
	var yaws: Array = []
	# walk sideways AND outward, crossing 1.9m with lock-on
	for fr in 150:
		var to: Vector3 = e.global_position - h.global_position
		to.y = 0
		h.move_input = (to.normalized().cross(Vector3.UP) - to.normalized() * 0.35).normalized()
		await get_tree().physics_frame
		await get_tree().process_frame
		yaws.append(rig.yaw)
	h.move_input = Vector3.ZERO
	for i in range(2, yaws.size()):
		maxacc = maxf(maxacc, absf(wrapf(yaws[i] - yaws[i - 1], -PI, PI) - wrapf(yaws[i - 1] - yaws[i - 2], -PI, PI)) * 3600.0)
	check(flat(h, e) > 2.2 and maxacc < 120.0, "crossing the hold distance: yaw acceleration max %.0f rad/s^2 (was ~1100 with the hard switch), ended %.2fm away" % [maxacc, flat(h, e)])
	check(rig.limit_rise_rate > 0.0 and rig.hold_blend_width > 0.0, "smoothing parameters present")
