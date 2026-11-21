extends "res://tests/freeflow_runner.gd"
## REAVER FREE FLOW 002 (collaboration/tasks/REAVER-FREEFLOW-002.md): focused FUNCTIONAL checks.
##   godot --headless --fixed-fps 60 res://tests/freeflow2_runner.tscn
## Mechanics only: combat feel must come from human playtesting.


func _run_all() -> void:
	Events.augment_triggered.connect(func(_o, id, d): trig.append([id, d]))
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.source == Game.player: dmg.append(info))
	await test_pursuit_slash_gap_closing()
	await test_pursuit_slash_limits()
	await test_backward_reengage()
	await test_perfect_dodge_reward_window()
	await test_counter_followups()
	await test_recovery_punish()
	await test_flank_followup()
	await test_tempo_transitions()
	await test_stamina_rework()
	await test_augment_interactions()
	await test_animation_transition()
	await test_save_safety()
	await test_unchanged_systems()
	await teardown()


func flat(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## Completes a sideways dodge in open ground (nothing to avoid), then returns.
func dodge_done(h: Hero) -> void:
	h.move_input = Vector3(1, 0, 0)
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await until_idle(h)


## Places the hero `dist` metres in front of the target, facing it and locked on.
func place(h: Hero, r: Enemy, dist: float) -> void:
	h.global_position = r.global_position + Vector3(0, 0, dist)
	h.velocity = Vector3.ZERO
	h.knock_velocity = Vector3.ZERO
	h.lock_target = r
	face(h, r)


## Dodges WHILE an enemy attack reaches the hero at dodge time `at` (seconds into the dodge).
## (Each call can use another attack id: one enemy attack EVENT only ever rewards one Perfect Dodge.)
func dodge_hit_at(h: Hero, r: Enemy, at: float, attack_id: String = "raider_heavy") -> DamageInfo:
	h.try_dodge()
	var n := 0
	while h.dodging and h.dodge_t < at and n < 60:
		await get_tree().physics_frame
		n += 1
	return enemy_hit(h, r, attack_id)


func hit_on(r: Enemy) -> DamageInfo:
	for i in dmg:
		if i.target == r:
			return i
	return null


# ------------------------------------------------------------------ 1. Pursuit Slash
func test_pursuit_slash_gap_closing() -> void:
	print("\n[Pursuit Slash: post-dodge Light closes a short gap (collision-safe, no teleport)]")
	var h := await ff(1)
	var f := fk(h)
	var r := target(h, 3.2)
	# baseline: the same gap without a dodge -> ordinary Flow Strike, which does not reach
	place(h, r, 3.2)
	dmg.clear()
	tap(h, "light")
	await wait(0.03)
	check(cur(h).begins_with("ff_strike"), "without a dodge, LMB is an ordinary Flow Strike", cur(h))
	await until_idle(h)
	check(hit_on(r) == null, "baseline: a Flow Strike from 3.2m does not reach (the gap the playtest reported)")
	await wait(1.0)
	await dodge_done(h)
	check(f.pursuit_slash_ready(), "a completed dodge opens the brief Pursuit Slash window")
	place(h, r, 3.2)
	var p0 := h.global_position
	dmg.clear()
	refill(h)
	tap(h, "light")
	await wait(0.02)
	check(cur(h) == "ff_pursuit_slash", "post-dodge LMB = Pursuit Slash", cur(h))
	var d: AttackData = h.runner.data
	var strike := load("res://data/attacks/ff_strike_1.tres") as AttackData
	check(d.anim_style != strike.anim_style and d.anim_style != "rising" and d.anim_style != "thrust", "visually distinct motion from the three Flow Strikes", d.anim_style)
	check(d.has_tag("light") and d.damage_type == AttackData.DamageType.PHYSICAL, "a physical light attack")
	var inv := false
	var max_step := 0.0
	var last := h.global_position
	for i in 24:
		inv = inv or h.is_invulnerable()
		await get_tree().physics_frame
		max_step = maxf(max_step, (h.global_position - last).length())
		last = h.global_position
	await until_idle(h)
	var moved := Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	check(moved >= 1.0 and moved <= 1.6, "approach about 1.0-1.5m", "%.2fm" % moved)
	check(max_step < 0.4, "continuous movement, no teleport (largest single-frame step)", "%.3fm" % max_step)
	check(not inv, "no invulnerability during Pursuit Slash")
	check(hit_on(r) != null, "the slash connects after the approach")
	check(flat(h, r) > 1.2, "stops at weapon range, never slides into the enemy", "%.2fm" % flat(h, r))
	check(f.last_connected and f.in_sequence(), "Free Flow continuation preserved (a connecting Pursuit Slash keeps the sequence open)")
	# the window is brief
	await wait(1.0)
	await dodge_done(h)
	await wait(PURSUIT_WINDOW() + 0.1)
	place(h, r, 2.2)
	refill(h)
	tap(h, "light")
	await wait(0.02)
	check(cur(h).begins_with("ff_strike"), "after the brief window, LMB is an ordinary Flow Strike again", cur(h))
	r.queue_free()


func PURSUIT_WINDOW() -> float:
	return ReaverFreeFlow.PURSUIT_SLASH_WINDOW


func test_pursuit_slash_limits() -> void:
	print("\n[Pursuit Slash limits: max distance, distant enemies, collision]")
	var h := await ff(1)
	var r := target(h, 4.0)
	# gap 2.0m beyond range: the step is capped at 1.5m and the hit is NOT guaranteed
	await dodge_done(h)
	place(h, r, 4.0)
	var p0 := h.global_position
	dmg.clear()
	refill(h)
	tap(h, "light")
	await until_idle(h)
	var moved := Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	check(moved <= 1.55, "approach capped at 1.5m", "%.2fm" % moved)
	# distant enemy: no automatic pull
	await wait(1.0)
	await dodge_done(h)
	place(h, r, 7.0)
	p0 = h.global_position
	refill(h)
	tap(h, "light")
	await until_idle(h)
	moved = Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	check(cur(h) == "" and moved < 0.1, "a distant enemy (7m) is not pulled toward: no movement", "%.2fm" % moved)
	# already in range: no movement
	await wait(1.0)
	await dodge_done(h)
	place(h, r, 1.9)
	p0 = h.global_position
	refill(h)
	tap(h, "light")
	await until_idle(h)
	moved = Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	check(moved < 0.15, "target already in range: no approach step", "%.2fm" % moved)
	# a body in the way: the second enemy blocks the path (move_and_slide), never passed through
	await wait(1.0)
	var blocker := dummy("raider", r.global_position + Vector3(0, 0, 1.6))
	blocker.max_hp = 99999
	blocker.hp = 99999
	await dodge_done(h)
	place(h, r, 3.4)
	refill(h)
	tap(h, "light")
	await until_idle(h)
	check(h.global_position.z > blocker.global_position.z + 0.3, "an enemy body in the way stops the approach (collision)", "hero z %.2f, blocker z %.2f" % [h.global_position.z, blocker.global_position.z])
	blocker.queue_free()
	# no target at all: no movement (the approach never invents a destination)
	r.queue_free()
	await wait(0.2)
	h.lock_target = null
	await dodge_done(h)
	h.velocity = Vector3.ZERO      # isolate the slash from the dodge's own deceleration
	await get_tree().physics_frame
	p0 = h.global_position
	refill(h)
	tap(h, "light")
	await until_idle(h)
	moved = Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	check(moved < 0.1, "no enemy nearby: Pursuit Slash does not move", "%.2fm" % moved)


# ------------------------------------------------------------------ correction: backward dodge
## The playtest scenario: target 2.2m away, Light, Light, dodge with `dodge_input`, then optionally
## hold `follow_input` and press Light right after the dodge. Returns measured values.
func _ll_dodge_light(dodge_input: Vector3, follow_input: Vector3, target_dist: float = 2.2) -> Dictionary:
	var h := await ff(3)
	var r := target(h, target_dist)
	tap(h, "light")
	await until_can_act(h)
	tap(h, "light")
	await until_can_act(h)
	h.move_input = dodge_input
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await until_idle(h)
	var res := {"after_dodge": flat(h, r), "backward": fk(h).dodge_was_backward}
	h.velocity = Vector3.ZERO      # isolate the follow-up from the dodge's own deceleration (~0.2m)
	h.move_input = follow_input
	var p0 := h.global_position
	var cd0: float = h.kit.skill_cd("r_pursuit_cut")
	dmg.clear()
	tap(h, "light")
	await wait(0.02)
	res["attack"] = cur(h)
	res["inv"] = false
	var mx := 0.0
	var last := h.global_position
	for i in 30:
		res["inv"] = res["inv"] or h.is_invulnerable()
		await get_tree().physics_frame
		mx = maxf(mx, (h.global_position - last).length())
		last = h.global_position
	h.move_input = Vector3.ZERO
	await until_idle(h)
	res["moved"] = Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	res["end"] = flat(h, r)
	res["hit"] = hit_on(r) != null
	res["max_step"] = mx
	res["cd_used"] = h.kit.skill_cd("r_pursuit_cut") > cd0
	r.queue_free()
	return res


func test_backward_reengage() -> void:
	print("\n[Correction: backward dodge -> intentional forward Light re-engages (bounded, collision-safe)]")
	var toward := Vector3(0, 0, -1)       # target() puts the enemy at -Z: forward input = toward it
	var away := Vector3(0, 0, 1)
	# 1. the original playtest scenario
	var a := await _ll_dodge_light(away, toward)
	check(a.backward and a.after_dodge > 5.0, "backward dodge leaves the Reaver far away (the reported failure)", "%.2fm" % a.after_dodge)
	check(a.attack == "ff_reengage_slash", "forward + Light after a backward dodge = forward re-engagement", a.attack)
	check(a.hit, "it reconnects (target 2.2m, L, L, backward Dodge, forward Light)", "%.2fm -> %.2fm, moved %.2fm" % [a.after_dodge, a.end, a.moved])
	check(a.moved <= ReaverFreeFlow.REENGAGE_SEARCH and a.moved <= 4.05, "bounded movement (max 4.0m)", "%.2fm" % a.moved)
	check(a.end >= 1.3, "stops at weapon range, never into the enemy", "%.2fm" % a.end)
	check(a.max_step < 0.4 and not a.inv, "continuous movement (no teleport) and no invulnerability", "largest frame step %.3fm" % a.max_step)
	check(not a.cd_used, "no Pursuit Cut cooldown needed or used")
	var d := load("res://data/attacks/ff_reengage_slash.tres") as AttackData
	var ps := load("res://data/attacks/ff_pursuit_slash.tres") as AttackData
	check(d.startup > ps.startup and d.total_time() > ps.total_time() and not d.has_tag("light") and is_equal_approx(d.damage_mult, ps.damage_mult), "more commitment than Pursuit Slash (slower, no startup dodge-cancel), same damage", "%.2fs / %.2fs total" % [d.total_time(), ps.total_time()])
	# 2. backward-diagonal
	var b := await _ll_dodge_light(Vector3(1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized())
	check(b.backward and b.attack == "ff_reengage_slash" and b.hit, "backward-diagonal dodge + forward Light also reconnects", "%.2fm -> %.2fm" % [b.after_dodge, b.end])
	# 3. no directional intent: no pull
	var c := await _ll_dodge_light(away, Vector3.ZERO)
	check(c.attack == "ff_pursuit_slash" and c.moved < 0.15 and not c.hit, "backward dodge WITHOUT forward input: no automatic pull", "%s moved %.2fm" % [c.attack, c.moved])
	var c2 := await _ll_dodge_light(away, Vector3(1, 0, 0))
	check(c2.attack != "ff_reengage_slash", "sideways input is not forward intent", c2.attack)
	# 4. side dodge keeps the normal Pursuit Slash, even with forward input
	var s := await _ll_dodge_light(Vector3(1, 0, 0), Vector3(-1, 0, -1).normalized())
	check(not s.backward and s.attack == "ff_pursuit_slash" and s.hit, "side dodge: the normal Pursuit Slash still closes and hits", "%s %.2fm -> %.2fm" % [s.attack, s.after_dodge, s.end])
	var s2 := await _ll_dodge_light(Vector3(1, 0, 0), Vector3.ZERO)
	check(s2.attack == "ff_pursuit_slash" and s2.hit, "side dodge without input: normal Pursuit Slash")
	# 5. distant enemy: bounded, no long pull
	var f := await _ll_dodge_light(away, toward, 6.0)
	check(f.attack == "ff_reengage_slash" and f.moved <= 4.05, "an enemy beyond reach: movement still capped at 4.0m", "%.2fm -> %.2fm, moved %.2fm, %s" % [f.after_dodge, f.end, f.moved, "hit" if f.hit else "miss"])
	check(not f.hit, "the hit is not guaranteed (too far away)")
	# 6. window: after the brief post-dodge window, forward Light is a normal Flow Strike
	var h := await ff(3)
	var r := target(h)
	h.move_input = away
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await until_idle(h)
	await wait(ReaverFreeFlow.PURSUIT_SLASH_WINDOW + 0.1)
	h.move_input = toward
	tap(h, "light")
	await wait(0.02)
	h.move_input = Vector3.ZERO
	check(cur(h).begins_with("ff_strike"), "outside the post-dodge window: ordinary Flow Strike", cur(h))
	await until_idle(h)
	# 7. collision: an enemy body in the path stops the advance
	await wait(1.0)
	place(h, r, 2.2)
	h.move_input = away
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await until_idle(h)
	var blocker := dummy("raider", (h.global_position + r.global_position) * 0.5)
	blocker.max_hp = 99999
	blocker.hp = 99999
	h.move_input = toward
	tap(h, "light")
	await wait(0.02)
	var used := cur(h)
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(used == "ff_reengage_slash" and h.global_position.z > blocker.global_position.z + 0.3, "an enemy body in the path stops the advance (collision)", "%s hero z %.2f blocker z %.2f" % [used, h.global_position.z, blocker.global_position.z])
	blocker.queue_free()
	# 8. backward dodge that was a Perfect Dodge: the advance keeps Perfect Flow -> Counter Slash next
	await wait(1.0)
	place(h, r, 2.2)
	h.move_input = away
	h.try_dodge()
	h.move_input = Vector3.ZERO
	var n := 0
	while h.dodging and h.dodge_t < 0.08 and n < 30:
		await get_tree().physics_frame
		n += 1
	enemy_hit(h, r, "raider_combo1")
	await until_idle(h)
	var pf: bool = fk(h).has_opportunity()
	h.move_input = toward
	tap(h, "light")
	await wait(0.02)
	var adv := cur(h)
	h.move_input = Vector3.ZERO
	await until_can_act(h)
	refill(h)
	tap(h, "light")
	await wait(0.02)
	check(pf and adv == "ff_reengage_slash" and cur(h) == "ff_counter_slash", "Perfect backward dodge: Advance, then the Counter Slash is still available", "%s -> %s" % [adv, cur(h)])
	await until_idle(h)
	r.queue_free()


# ------------------------------------------------------------------ 7. Perfect Dodge accuracy
func test_perfect_dodge_reward_window() -> void:
	print("\n[Perfect Dodge: narrow offensive reward window, defensive i-frames unchanged]")
	var h := await ff(1)
	var f := fk(h)
	var r := target(h, 3.0)
	var iend: float = Game.balance.dodge_iframe_start + Game.balance.dodge_iframes * h.kit.iframe_mult()
	var rend: float = Game.balance.dodge_iframe_start + ReaverFreeFlow.PD_REWARD_WINDOW
	check(rend < iend - 0.1, "the reward window is narrower than the defensive i-frames", "reward to %.2fs, i-frames to %.2fs" % [rend, iend])
	var hp0 := h.hp
	var early := await dodge_hit_at(h, r, 0.08)
	check(early.dodged and h.hp == hp0 and f.has_opportunity() and f.flow_source == "dodge", "well-timed (0.08s): avoided AND Perfect Flow", "t=%.2f" % h.dodge_t)
	await until_idle(h)
	await wait(2.3)
	var late0: int = f.late_dodges
	var late := await dodge_hit_at(h, r, 0.26)
	check(h.is_invulnerable() and late.dodged and h.hp == hp0, "late in the i-frames (0.26s): still fully safe (defense unchanged)", "t=%.2f" % h.dodge_t)
	check(not f.has_opportunity() and f.late_dodges == late0 + 1, "late in the i-frames: no Perfect Flow / no Counter Slash")
	await until_idle(h)
	place(h, r, 2.2)
	refill(h)
	tap(h, "light")
	await wait(0.02)
	check(cur(h) != "ff_counter_slash", "after a merely safe dodge LMB is not a Counter Slash", cur(h))
	await until_idle(h)
	await wait(0.5)
	var plain0: int = f.opportunities_created
	await dodge_done(h)
	check(f.opportunities_created == plain0, "a dodge that avoids nothing grants nothing")
	r.queue_free()


# ------------------------------------------------------------------ 2A + 5. Counter follow-ups
func test_counter_followups() -> void:
	print("\n[Perfect Dodge -> Counter Slash (LMB) / Counter Pursuit (1): faster, physical, one follow-up]")
	var h := await ff(3)
	var f := fk(h)
	var r := target(h, 3.0)
	await dodge_hit_at(h, r, 0.08)
	await until_idle(h)
	place(h, r, 2.6)
	dmg.clear()
	refill(h)
	var c0: int = f.opportunities_consumed
	tap(h, "light")
	await wait(0.02)
	check(cur(h) == "ff_counter_slash", "LMB after a Perfect Dodge = Counter Slash", cur(h))
	var cs: AttackData = h.runner.data
	var strike := load("res://data/attacks/ff_strike_1.tres") as AttackData
	var ps := load("res://data/attacks/ff_pursuit_slash.tres") as AttackData
	check(cs.startup < strike.startup and cs.total_time() < strike.total_time(), "faster than a normal attack", "startup %.2f vs %.2f, total %.2f vs %.2f" % [cs.startup, strike.startup, cs.total_time(), strike.total_time()])
	check(cs.anim_style != strike.anim_style and cs.anim_style != ps.anim_style, "its own animation response", cs.anim_style)
	check(cs.damage_type == AttackData.DamageType.PHYSICAL and cs.damage_mult <= strike.damage_mult, "a physical sword attack, no inflated damage", "x%.2f" % cs.damage_mult)
	check(f.opportunities_consumed == c0 + 1 and not f.has_opportunity(), "consumes Perfect Flow (one enhanced follow-up)")
	await until_idle(h)
	check(hit_on(r) != null, "the Counter Slash connects")
	check(f.tempo() != ReaverFreeFlow.Tempo.PERFECT_FLOW, "a consuming follow-up does not re-grant Perfect Flow")
	# Counter Pursuit
	await wait(1.0)
	place(h, r, 3.0)
	await dodge_hit_at(h, r, 0.08, "raider_combo1")
	await until_idle(h)
	place(h, r, 5.0)
	refill(h)
	tap(h, "skill1")
	await wait(0.02)
	var base_p := load("res://data/attacks/ff_pursuit.tres") as AttackData
	check(cur(h) == "ff_pursuit" and h.runner.data.display_name == "Counter Pursuit" and h.runner.data.startup < base_p.startup * 0.7, "1 after a Perfect Dodge = Counter Pursuit (faster start)", "%.3fs" % h.runner.data.startup)
	check(f.last_followup == "counter_pursuit" and not f.has_opportunity(), "Counter Pursuit consumes Perfect Flow")
	await until_idle(h)
	# Perfect Flow is not mandatory: everything works from Neutral
	await wait(5.2)
	place(h, r, 5.0)
	refill(h)
	tap(h, "skill1")
	await wait(0.02)
	check(cur(h) == "ff_pursuit" and h.runner.data.display_name != "Counter Pursuit", "without a Perfect Dodge Pursuit Cut is the ordinary skill (reads are optional)")
	r.queue_free()


# ------------------------------------------------------------------ 2B. Enemy recovery
func _enemy_attack(r: Enemy, recovery: float = 3.0) -> void:
	var d := AttackData.new()
	d.id = "test_enemy_swing"
	d.startup = 0.05
	d.active = 0.05
	d.recovery = recovery
	d.hits = 0
	r.runner.start(d, {})


func test_recovery_punish() -> void:
	print("\n[Heavy Cut in enemy attack recovery: more Poise (a read), no extra damage]")
	var h := await ff(7)
	var r := target(h)
	place(h, r, 2.2)
	dmg.clear()
	refill(h)
	tap(h, "heavy")
	await until_idle(h)
	var base := hit_on(r)
	await wait(1.0)
	_enemy_attack(r)
	await wait(0.15)
	check(ReaverFreeFlow.in_attack_recovery(r), "(enemy is in attack recovery)")
	place(h, r, 2.2)
	dmg.clear()
	refill(h)
	tap(h, "heavy")
	await until_idle(h)
	var pun := hit_on(r)
	if base and pun:
		check(pun.tags.get("punish", false) and absf(pun.poise / base.poise - ReaverFreeFlow.PUNISH_POISE) < 0.02, "Heavy Cut during enemy recovery: Poise x1.5", "x%.3f" % (pun.poise / base.poise))
		check(absf(pun.raw_amount / base.raw_amount - 1.0) < 0.01, "no damage multiplier (Poise only)", "x%.3f" % (pun.raw_amount / base.raw_amount))
	else:
		check(false, "both Heavy Cuts connected")
	r.runner.interrupt()
	# enemy winding up (not recovering): no punish -> spamming Heavy is not rewarded
	await wait(1.0)
	var d := AttackData.new()
	d.id = "test_long_windup"
	d.startup = 3.0
	d.active = 0.05
	d.recovery = 0.1
	d.hits = 0
	r.runner.start(d, {})
	place(h, r, 2.2)
	dmg.clear()
	refill(h)
	tap(h, "heavy")
	await until_idle(h)
	var wind := hit_on(r)
	check(wind != null and not wind.tags.get("punish", false), "Heavy Cut into an enemy wind-up (or idle enemy): no punish")
	r.runner.interrupt()
	# a Light in recovery is not a punish (Heavy / Decisive read)
	await wait(1.0)
	_enemy_attack(r)
	await wait(0.15)
	place(h, r, 2.2)
	dmg.clear()
	refill(h)
	tap(h, "light")
	await until_idle(h)
	var li := hit_on(r)
	check(li != null and not li.tags.get("punish", false), "a Flow Strike during recovery gets no punish bonus")
	r.runner.interrupt()
	# Decisive Cut also reads recovery ("improved Heavy or Decisive execution")
	await wait(1.0)
	_enemy_attack(r)
	await wait(0.15)
	place(h, r, 2.2)
	dmg.clear()
	refill(h)
	tap(h, "skill3")
	await until_idle(h)
	var dc := hit_on(r)
	check(dc != null and dc.tags.get("punish", false), "Decisive Cut during enemy recovery: punish")
	r.runner.interrupt()
	r.queue_free()


# ------------------------------------------------------------------ 2C. Flank follow-up
func test_flank_followup() -> void:
	print("\n[Pivot Cut from the flank -> faster offensive continuation (not a damage multiplier)]")
	var h := await ff(5)
	var f := fk(h)
	var r := target(h, 2.0)
	dmg.clear()
	refill(h)
	tap(h, "heavy")
	await until_idle(h)
	var base := hit_on(r)
	await wait(1.0)
	r.global_position = h.global_position + Vector3(0, 0, -2.0)
	r.face_dir(Vector3(1, 0, 0))
	h.lock_target = r
	face(h, r)
	refill(h)
	h.move_input = Vector3(-1, 0, 0)
	tap(h, "skill2")
	await wait(0.05)
	h.move_input = Vector3.ZERO
	var n := 0
	while h.runner.is_busy() and h.runner.phase != AttackRunner.Phase.RECOVERY and n < 60:
		await get_tree().physics_frame
		n += 1
	check(f.has_opportunity() and f.flow_source == "flank", "flank Pivot hit: Perfect Flow (flank)", f.last_reason)
	await get_tree().physics_frame
	var piv: AttackData = load("res://data/attacks/ff_pivot.tres")
	check(h.runner.is_busy() and h.runner.time_in_recovery() < piv.cancel_after and h.can_act(), "the Pivot's recovery can be cancelled immediately", "%.3fs into recovery (normal cancel %.2fs)" % [h.runner.time_in_recovery(), piv.cancel_after])
	dmg.clear()
	tap(h, "heavy")
	await wait(0.02)
	var hv := load("res://data/attacks/ff_heavy.tres") as AttackData
	check(cur(h) == "ff_heavy" and absf(h.runner.data.startup - hv.startup * ReaverFreeFlow.FLANK_STARTUP) < 0.001, "the follow-up starts faster (Heavy startup x0.6)", "%.3fs" % h.runner.data.startup)
	check(f.last_followup == "flank_heavy" and not f.has_opportunity(), "one follow-up consumes it")
	await until_idle(h)
	var fl := hit_on(r)
	if base and fl:
		check(absf(fl.raw_amount / base.raw_amount - 1.0) < 0.01, "flank follow-up: speed, not a damage multiplier", "x%.3f" % (fl.raw_amount / base.raw_amount))
	else:
		check(false, "flank follow-up connected")
	# frontal Pivot: no follow-up
	await wait(4.5)
	face(r, h)
	refill(h)
	h.move_input = Vector3(1, 0, 0)
	tap(h, "skill2")
	await wait(0.05)
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(not f.has_opportunity(), "a frontal Pivot Cut grants no flank follow-up")
	r.queue_free()


# ------------------------------------------------------------------ 3. Tempo
func test_tempo_transitions() -> void:
	print("\n[Tempo: Neutral -> In Rhythm -> (Heavy) -> Neutral; Perfect Flow supersedes; no HUD element]")
	var h := await ff(1)
	var f := fk(h)
	var r := target(h)
	check(f.tempo() == ReaverFreeFlow.Tempo.NEUTRAL, "starts Neutral")
	dmg.clear()
	refill(h)
	tap(h, "heavy")
	await until_idle(h)
	var base := hit_on(r)
	await wait(1.0)
	tap(h, "light")
	await until_can_act(h)
	tap(h, "light")
	await wait(0.3)
	check(f.tempo() == ReaverFreeFlow.Tempo.IN_RHYTHM and f.rhythm_entries == 1, "two connected transitions: In Rhythm", f.tempo_name())
	await until_can_act(h)
	dmg.clear()
	refill(h)
	tap(h, "heavy")
	await wait(0.02)
	var hv := load("res://data/attacks/ff_heavy.tres") as AttackData
	check(cur(h) == "ff_heavy" and absf(h.runner.data.startup - hv.startup * ReaverFreeFlow.RHYTHM_HEAVY_STARTUP) < 0.001, "In Rhythm: the next Heavy Cut starts faster (x0.75)", "%.3fs" % h.runner.data.startup)
	check(f.tempo() == ReaverFreeFlow.Tempo.NEUTRAL and f.rhythm_used == 1, "the eligible follow-up spends it: back to Neutral")
	await until_idle(h)
	var rh_hit := hit_on(r)
	if base and rh_hit:
		check(absf(rh_hit.raw_amount / base.raw_amount - 1.0) < 0.01, "In Rhythm adds no damage (no passive scaling)", "x%.3f" % (rh_hit.raw_amount / base.raw_amount))
	# In Rhythm is lost when the sequence ends
	await wait(1.0)
	tap(h, "light")
	await until_can_act(h)
	tap(h, "light")
	await until_idle(h)
	check(f.tempo() == ReaverFreeFlow.Tempo.IN_RHYTHM, "(In Rhythm again)")
	await wait(ReaverFreeFlow.CONTINUE_GRACE + 0.1)
	check(f.tempo() == ReaverFreeFlow.Tempo.NEUTRAL, "In Rhythm fades with the sequence (unused)")
	# misses never build rhythm
	h.lock_target = null
	h.face_dir(Vector3(0, 0, 1))
	var e0: int = f.rhythm_entries
	for i in 4:
		await until_can_act(h)
		refill(h)
		tap(h, "light")
	await until_idle(h)
	check(f.rhythm_entries == e0 and f.tempo() == ReaverFreeFlow.Tempo.NEUTRAL, "repeated misses never build In Rhythm")
	# Perfect Flow supersedes In Rhythm (one state at a time)
	place(h, r, 2.2)
	tap(h, "light")
	await until_can_act(h)
	tap(h, "light")
	await until_idle(h)
	f.grant("test")
	check(f.tempo() == ReaverFreeFlow.Tempo.PERFECT_FLOW and not f.rhythm, "Perfect Flow replaces In Rhythm (states never overlap)")
	tap(h, "heavy")
	await until_idle(h)
	check(f.tempo() != ReaverFreeFlow.Tempo.PERFECT_FLOW, "after its one follow-up: Perfect Flow ends")
	check(not ("tempo" in h.kit.hud_lines()[0].to_lower()) and not ("rhythm" in h.kit.hud_lines()[0].to_lower()), "no gauge / counter / tempo text on the HUD")
	r.queue_free()


# ------------------------------------------------------------------ 4. Stamina
func test_stamina_rework() -> void:
	print("\n[Stamina: 4 / 12 / 10 / 8 / 20, +2 once per connecting attack, misses restore nothing]")
	var expect := {"ff_strike_1": 4.0, "ff_strike_2": 4.0, "ff_strike_3": 4.0, "ff_pursuit_slash": 4.0, "ff_counter_slash": 4.0,
		"ff_heavy": 12.0, "ff_pursuit": 10.0, "ff_pivot": 8.0, "ff_decisive": 20.0}
	var bad := ""
	for id in expect:
		var a := load("res://data/attacks/%s.tres" % id) as AttackData
		if not is_equal_approx(a.stamina_cost, expect[id]):
			bad += "%s=%.0f " % [id, a.stamina_cost]
	check(bad == "", "costs match the approved table", bad)
	check(is_equal_approx(Game.balance.dodge_cost, 22.0) and is_equal_approx(Game.balance.stamina_regen, 30.0) and is_equal_approx(Game.balance.stamina_regen_delay, 0.7) and is_equal_approx(Game.balance.reaver_dodge_cost_mult, 0.8), "global dodge cost and stamina regeneration unchanged")
	var h := await ff(8)
	var f := fk(h)
	var r := target(h)
	h.stamina = 50.0
	tap(h, "light")
	await wait(0.02)
	check(is_equal_approx(h.stamina, 46.0), "Light costs 4", "%.1f" % h.stamina)
	await until_idle(h)
	h.stamina_delay = 99.0
	check(absf(h.stamina - 48.0) < 0.6, "a connecting Light restores 2 (net cost 2)", "%.1f" % h.stamina)
	# miss: nothing restored
	await wait(1.0)
	h.lock_target = null
	h.face_dir(Vector3(0, 0, 1))
	await wait(0.05)
	h.stamina = 50.0
	tap(h, "light")
	await until_idle(h)
	h.stamina_delay = 99.0
	check(absf(h.stamina - 46.0) < 0.6, "a missed Light restores nothing (net cost 4)", "%.1f" % h.stamina)
	# multi-hit: Tempest Edge refunds once
	place(h, r, 2.2)
	Game.add_augment("reaver", "tempest_edge")
	h.stats.crit_chance = 0.0
	await wait(0.1)
	h.kit.cooldowns.clear()
	h.stamina = 60.0
	var ref0: float = f.stamina_refunded
	dmg.clear()
	tap(h, "skill3")
	await wait(0.02)
	h.stamina_delay = 99.0
	await until_idle(h)
	var hits := dmg.filter(func(i): return i.target == r).size()
	check(hits == 4 and absf(f.stamina_refunded - ref0 - 2.0) < 0.01, "a 4-hit Tempest Edge refunds 2 once, not per hit", "%d hits, refunded %.1f" % [hits, f.stamina_refunded - ref0])
	check(absf(h.stamina - 42.0) < 0.6, "Decisive Cut costs 20 (60 - 20 + 2)", "%.1f" % h.stamina)
	Game.remove_augment("reaver", "tempest_edge")
	# never above max, and no infinite loop: 20 connecting Lights from full always lose stamina
	place(h, r, 2.2)
	h.stamina = h.max_stamina
	tap(h, "light")
	await until_idle(h)
	check(h.stamina <= h.max_stamina, "refund never exceeds max stamina")
	await wait(1.0)
	h.stamina = 80.0
	var start := h.stamina
	var spent := 0
	for i in 20:
		await until_can_act(h)
		h.stamina_delay = 99.0       # freeze regeneration: isolate cost vs refund
		tap(h, "light")
		spent += 1
	await until_idle(h)
	h.stamina_delay = 99.0
	check(h.stamina < start - 30.0, "connecting attacks alone never sustain themselves (no infinite loop)", "%.1f -> %.1f after %d Lights" % [start, h.stamina, spent])
	r.queue_free()


# ------------------------------------------------------------------ 5. Augments
func test_augment_interactions() -> void:
	print("\n[Edge augments stay compatible with the new follow-ups]")
	var h := await ff(8)
	var f := fk(h)
	var r := target(h)
	dmg.clear()
	refill(h)
	tap(h, "skill3")
	await until_idle(h)
	var base := hit_on(r)
	await wait(8.2)
	Game.add_augment("reaver", "precision_edge")
	h.stats.crit_chance = 0.0
	await wait(0.1)
	place(h, r, 3.0)
	await dodge_hit_at(h, r, 0.08)
	await until_idle(h)
	place(h, r, 2.2)
	face(r, h)
	refill(h)
	dmg.clear()
	tap(h, "skill3")
	await wait(0.02)
	check(h.runner.data.display_name == "Precision Edge" and h.runner.ctx.get("consumed", false), "Precision Edge Decisive consumes a Perfect-Dodge Perfect Flow")
	await until_idle(h)
	var pe := hit_on(r)
	check(pe != null and pe.raw_amount > 0.0, "the transformed Decisive Cut connects")
	Game.remove_augment("reaver", "precision_edge")
	Game.add_augment("reaver", "momentum_edge")
	h.stats.crit_chance = 0.0
	await wait(0.1)
	refill(h)
	place(h, r, 4.0)
	h.lock_target = null
	face(h, r)
	var p0 := h.global_position
	tap(h, "skill3")
	await until_idle(h)
	check((h.global_position - p0).length() > 1.0, "Momentum Edge still rushes", "%.2fm" % (h.global_position - p0).length())
	Game.remove_augment("reaver", "momentum_edge")
	var p := Game.prog("reaver")
	var pool: Array = Game.augment_db.eligible("reaver", p).map(func(a): return a.id)
	pool.sort()
	check(pool == ["momentum_edge", "precision_edge", "sundering_verdict", "tempest_edge"], "draft pool unchanged by 002", str(pool))
	if base == null:
		check(false, "base Decisive connected")
	r.queue_free()


# ------------------------------------------------------------------ 6. Animation transition
func _weapon_rot(h: Hero) -> Vector3:
	return h.weapon_pivot.rotation if h.weapon_pivot else Vector3.ZERO


func test_animation_transition() -> void:
	print("\n[Reaver-only animation transition: cross-fade between chained Free Flow attacks]")
	var h := await ff(1)
	var r := target(h)
	tap(h, "light")
	await wait(0.02)
	check(is_equal_approx(h.attack_blend, ReaverFreeFlow.DEFAULT_BLEND), "an attack from idle keeps the shared 0.04s blend")
	await until_can_act(h)
	tap(h, "light")
	await wait(0.02)
	check(is_equal_approx(h.attack_blend, ReaverFreeFlow.RHYTHM_BLEND), "a chained Free Flow attack cross-fades over 0.10s", "%.2f" % h.attack_blend)
	await until_idle(h)
	Game.set_core("reaver", "swordmaster")
	check(is_equal_approx(h.attack_blend, 0.04), "switching core restores the shared default")
	Game.set_core("reaver", "freeflow")
	Game.debug_tainted = false
	r.queue_free()
	# other classes untouched
	var v := await setup("vanguard", false, false, false)
	var e := dummy("raider", v.global_position + Vector3(0, 0, -2.0))
	v.lock_target = e
	face(v, e)
	tap(v, "light")
	await wait(0.3)
	tap(v, "light")
	await wait(0.05)
	check(is_equal_approx(v.attack_blend, 0.04), "Vanguard keeps the shared 0.04s attack blend")
	e.queue_free()


# ------------------------------------------------------------------ saves
func test_save_safety() -> void:
	print("\n[Save safety: tempo / follow-ups never reach the save; format unchanged]")
	var path := fixture_path("ff2_save.json")
	clear_fixture(path)
	var old_path: String = Save.path
	var h := await ff(8)
	var r := target(h)
	Save.path = path
	Save.enabled = true
	Game.debug_tainted = false
	check(Save.save_game(), "(fixture save written)")
	var fa := FileAccess.open(path, FileAccess.READ)
	var before = JSON.parse_string(fa.get_as_text())
	fa.close()
	await dodge_hit_at(h, r, 0.08)
	await until_idle(h)
	tap(h, "light")
	await until_can_act(h)
	tap(h, "light")
	await until_can_act(h)
	tap(h, "heavy")
	await until_idle(h)
	check(Save.save_game(), "(fixture save written after 002 actions)")
	fa = FileAccess.open(path, FileAccess.READ)
	var text := fa.get_as_text()
	var after = JSON.parse_string(text)
	fa.close()
	check(before is Dictionary and after is Dictionary and Save.validate_save(after) == "", "the save stays valid")
	if before is Dictionary and after is Dictionary:
		var kb: Array = before.characters.reaver.keys()
		var ka: Array = after.characters.reaver.keys()
		kb.sort()
		ka.sort()
		check(kb == ka and before.keys() == after.keys(), "same save structure (no new fields)")
		check(after.characters.reaver.level == 8 and after.characters.reaver.augments == before.characters.reaver.augments, "progress untouched")
	check(not text.contains("rhythm") and not text.contains("tempo") and not text.contains("perfect_flow"), "no combat-state data in the save")
	Save.enabled = false
	Save.path = old_path
	clear_fixture(path)
	r.queue_free()


func test_unchanged_systems() -> void:
	print("\n[Out of scope systems unchanged]")
	check(is_equal_approx(Game.balance.dodge_iframe_start, 0.03) and is_equal_approx(Game.balance.dodge_iframes, 0.28) and is_equal_approx(Game.balance.dodge_duration, 0.42) and is_equal_approx(Game.balance.dodge_speed, 11.0), "shared dodge defensive values unchanged (0.03 / 0.28 / 0.42s / 11)")
	var h := await ff(1)
	check(is_equal_approx(h.kit.iframe_mult(), 1.2), "Reaver i-frame multiplier unchanged (x1.2)")
	var hv := load("res://data/attacks/ff_heavy.tres") as AttackData
	check(is_equal_approx(hv.startup, 0.32) and is_equal_approx(hv.active, 0.14) and is_equal_approx(hv.recovery, 0.43), "base Heavy Cut timing still 0.32 / 0.14 / 0.43")
	check(Game.DEFAULT_REAVER_CORE == "freeflow", "Free Flow still the default Reaver core")
