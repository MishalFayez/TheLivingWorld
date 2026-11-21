extends "res://tests/freeflow2_runner.gd"
## REAVER-FREEFLOW-002 section 6: FEEL PROBE (measurement only; NOT pass/fail, NOT part of Test.ps1).
##   godot --headless --fixed-fps 60 res://tests/freeflow_feel_probe.tscn
## Measures four things SEPARATELY, so each can be judged and tuned on its own:
##   1. movement responsiveness   2. attack cancel responsiveness   3. animation blending
##   4. target spacing / approach
## Numbers describe the implementation; they do not replace a human judging the feel.

var out: Array = []


func _run_all() -> void:
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.source == Game.player: dmg.append(info))
	await probe_movement()
	await probe_cancel()
	await probe_blend()
	await probe_spacing()
	print("\n==== FREE FLOW FEEL PROBE ====")
	for l in out:
		print(l)
	print("==== FEEL PROBE: done ====")
	await teardown()


func line(s: String) -> void:
	out.append(s)
	print(s)


# ------------------------------------------------------------------ 1. movement
func probe_movement() -> void:
	# The headless PlayerBrain rewrites move_input every frame from the (absent) keyboard, so ground
	# acceleration is derived from the shared code (hero.gd: velocity move_toward desired at 60 m/s^2).
	line("\n[1] MOVEMENT RESPONSIVENESS")
	var spd: float = Game.balance.move_speed
	line("  run speed %.1f m/s, shared acceleration 60 m/s^2 -> 90%% speed after %.3fs (%d frames) from standing or after an attack" % [spd, 0.9 * spd / 60.0, ceili(0.9 * spd / 60.0 * 60.0)])
	line("  movement is blocked until the attack ENDS or is cancelled into another action; then it is immediate")
	var h := await ff(7)
	var r := target(h)
	# movement allowed DURING an attack (AttackData.move_during)
	for id in ["ff_strike_1", "ff_pursuit_slash", "ff_counter_slash", "ff_heavy", "ff_pivot", "ff_decisive"]:
		var d := load("res://data/attacks/%s.tres" % id) as AttackData
		line("  move during %-18s %.0f%% of run speed" % [id + ":", d.move_during * 100.0])
	r.queue_free()


# ------------------------------------------------------------------ 2. cancel
func _time_to_next(h: Hero, first: String) -> float:
	tap(h, first)
	await get_tree().physics_frame
	var n := 1
	while not h.can_act() and n < 180:
		await get_tree().physics_frame
		n += 1
	return n / 60.0


func probe_cancel() -> void:
	line("\n[2] ATTACK CANCEL RESPONSIVENESS (press -> earliest next attack; startup = press -> damage)")
	var h := await ff(7)
	var r := target(h)
	for pair in [["light", "ff_strike_1"], ["heavy", "ff_heavy"]]:
		await until_idle(h)
		await wait(1.0)
		place(h, r, 2.2)
		refill(h)
		var t := await _time_to_next(h, pair[0])
		var d := load("res://data/attacks/%s.tres" % pair[1]) as AttackData
		line("  %-22s next action after %.3fs (data: startup %.2f, total %.2f)" % [pair[1], t, d.startup, d.total_time()])
	for id in ["ff_pursuit_slash", "ff_counter_slash", "ff_pursuit", "ff_pivot", "ff_decisive"]:
		var d := load("res://data/attacks/%s.tres" % id) as AttackData
		line("  %-22s startup %.2fs, cancel from %.2fs, total %.2fs" % [id, d.startup, d.startup + d.active + d.cancel_after, d.total_time()])
	var hv := load("res://data/attacks/ff_heavy.tres") as AttackData
	line("  Heavy startup: Neutral %.2fs | In Rhythm %.2fs | flank follow-up %.2fs" % [hv.startup, hv.startup * ReaverFreeFlow.RHYTHM_HEAVY_STARTUP, hv.startup * ReaverFreeFlow.FLANK_STARTUP])
	var pv := load("res://data/attacks/ff_pivot.tres") as AttackData
	line("  Pivot recovery cancel: normal after %.2fs of recovery | flank hit: immediately" % pv.cancel_after)
	r.queue_free()


# ------------------------------------------------------------------ 3. blending
## Largest single-frame change of the weapon's rotation (radians) across a Light -> Light transition
## started at the first attack's cancel point, for a given cross-fade time. Isolated from gameplay: the
## animations are played directly on the hero's AnimationPlayer.
func _blend_jump(h: Hero, blend: float) -> float:
	var a := load("res://data/attacks/ff_strike_1.tres") as AttackData
	var b := load("res://data/attacks/ff_strike_2.tres") as AttackData
	h.attack_blend = 0.04
	h.play_attack_anim(a, 1.0)
	await wait(a.startup + a.active + a.cancel_after)
	var prev: Vector3 = h.weapon_pivot.rotation
	h.attack_blend = blend
	h.play_attack_anim(b, 1.0)
	var mx := 0.0
	for i in 12:
		await get_tree().process_frame
		var cur_r: Vector3 = h.weapon_pivot.rotation
		mx = maxf(mx, (cur_r - prev).length())
		prev = cur_r
	h.attack_blend = 0.04
	await wait(0.6)
	return mx


func probe_blend() -> void:
	line("\n[3] ANIMATION BLENDING (largest one-frame weapon rotation jump at a Light -> Light transition)")
	var h := await ff(1)
	await wait(0.3)
	for bl in [0.04, 0.10]:
		var j := await _blend_jump(h, bl)
		line("  cross-fade %.2fs: %.2f rad (%.0f deg) in one frame%s" % [bl, j, rad_to_deg(j), "   <- shared default (001)" if bl == 0.04 else "   <- Free Flow 002 chained attacks"])
	line("  note: every procedural attack starts from the REST pose keyed at t=0; the cross-fade only")
	line("  softens the jump from the previous pose. True pose-to-pose blending needs the shared ProcAnim.")


# ------------------------------------------------------------------ 4. spacing
func probe_spacing() -> void:
	line("\n[4] TARGET SPACING (Light, Light, Dodge, then follow-up; enemy 2.2m away, frozen)")
	var reach: float = 2.7     # Flow Strike hitbox far edge (offset 1.5 + half length 1.2)
	line("  dodge travel: %.2fm (speed %.0f decaying to half over %.2fs)" % [Game.balance.dodge_speed * Game.balance.dodge_duration * 0.75, Game.balance.dodge_speed, Game.balance.dodge_duration])
	for dir in [["back", Vector3(0, 0, 1)], ["side", Vector3(1, 0, 0)], ["diag back", Vector3(1, 0, 1).normalized()], ["forward-side", Vector3(1, 0, -1).normalized()]]:
		var h := await ff(1)
		var r := target(h)
		tap(h, "light")
		await until_can_act(h)
		tap(h, "light")
		await until_can_act(h)
		h.move_input = dir[1]
		h.try_dodge()
		h.move_input = Vector3.ZERO
		await until_idle(h)
		var after_dodge := flat(h, r)
		dmg.clear()
		tap(h, "light")
		await until_idle(h)
		var after_slash := flat(h, r)
		var hit := hit_on(r) != null
		line("  dodge %-12s distance after dodge %.2fm (Flow Strike reach %.1fm: %s) -> Pursuit Slash ends at %.2fm, %s" % [dir[0] + ":", after_dodge, reach, "in reach" if after_dodge <= reach else "OUT of reach", after_slash, "HIT" if hit else "miss"])
		r.queue_free()
