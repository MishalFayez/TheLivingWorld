extends "res://tests/benchmark_runner.gd"
## REAVER 002 (Free Flow) vs 003 (Blade Dancer) COMPARISON (measurement only; NOT pass/fail, NOT in Test.ps1).
##   godot --headless --fixed-fps 60 res://tests/bladedancer_compare.tscn
## Same conditions for both: Level 10 natural unlocks, starter gear, no allocated points, frozen Raider
## (99999 HP) 2.2m away and locked, 10s, crits ON, seeds 11 / 22 / 33. Scripted inputs (a bot, not a
## human): the numbers describe the systems, they do not judge feel.
## Metrics: DPS, stamina (spent, efficiency, minimum, dodge-ready time), average time between accepted
## actions, time unable to move, and real displacement during attacks.

var core := "bladedancer"


func _run_all() -> void:
	Events.damage_applied.connect(_on_damage)
	core = "freeflow"
	for scen in ["002 LMB spam", "002 LMB,LMB,Heavy", "002 skills + LMB,LMB,Heavy"]:
		await _trials("A", "reaver", scen)
	core = "bladedancer"
	for scen in ["003 neutral Dance spam", "003 lateral Dance spam", "003 Blade Weaving mix", "003 Weaving mix + techniques", "003 Edge Committed loop"]:
		await _trials("A", "reaver", scen)
	print("\n==== REAVER 002 vs 003 (mean of %d seeded trials; min-max in brackets) ====" % TRIALS.size())
	for r in rows:
		print(r)
	print("\n==== REAVER 002 vs 003: done ====")
	await teardown()


func _hero(cls: String) -> Hero:
	var h: Hero = await super._hero(cls)
	Game.reaver_core = core
	Game.set_level(cls, 10)
	Game.prog(cls).pending_drafts = 0
	Game.prog(cls).pending_draft_tiers.clear()
	await wait(0.1)
	h.refresh_stats(true)
	h.restore_all()
	for c in h.get_children():
		if c is PlayerBrain:
			c.set_physics_process(false)
	return h


func _scripted(cls: String, scen: String) -> Dictionary:
	var h: Hero = await _hero(cls)
	var r := dummy("raider", h.global_position + Vector3(0, 0, -2.2))
	r.max_hp = 99999
	r.hp = 99999
	h.lock_target = r
	face(h, r)
	_reset_metrics()
	var accepted := [0]
	var cb := func(_d, _c): accepted[0] += 1
	h.runner.started.connect(cb)
	var hp0 := r.hp
	var dur := 10.0
	var frames := int(dur * 60.0)
	var last_st := h.stamina
	var dodge_need: float = Game.balance.dodge_cost * h.kit.dodge_cost_mult()
	var busy := 0
	var locked := 0
	var ready := 0
	var min_st := h.stamina
	var moved := 0.0
	var last_pos := h.global_position
	var step := 0
	var next_at := 0
	var hold := -1        # Edge LMB hold countdown (frames)
	for f in frames:
		var to: Vector3 = r.global_position - h.global_position
		to.y = 0
		var tdir := to.normalized()
		var right := tdir.cross(Vector3.UP).normalized()
		if hold > 0:
			hold -= 1
			if hold == 0:
				h.release("light")
				hold = -1
		elif scen.begins_with("002"):
			if scen.contains("spam"):
				if f >= next_at:
					tap(h, "light")
					next_at = f + 15
			elif h.can_act():
				var act: String = ["light", "light", "heavy"][step % 3]
				if scen.contains("skills"):
					if h.kit.skill_cd("r_decisive_cut") <= 0.0 and h.stamina >= 20.0:
						act = "skill3"
					elif h.kit.skill_cd("r_pivot_cut") <= 0.0 and h.stamina >= 8.0:
						act = "skill2"
					elif h.kit.skill_cd("r_pursuit_cut") <= 0.0 and h.stamina >= 10.0:
						act = "skill1"
				if act in ["light", "heavy"]:
					step += 1
				h.move_input = right if act == "skill2" else Vector3.ZERO
				tap(h, act)
				h.move_input = Vector3.ZERO
		elif h.can_act() and h.kit.charging == "":
			var bdk: ReaverBladeDancer = h.kit.bd
			if scen.contains("neutral"):
				h.release("heavy")
				tap(h, "light")
			elif scen.contains("lateral"):
				h.release("heavy")
				h.move_input = right * (1.0 if int(step / 3.0) % 2 == 0 else -1.0)
				tap(h, "light")
				h.move_input = Vector3.ZERO
				step += 1
			elif scen.contains("Committed"):
				if not bdk.in_edge():
					h.press("heavy")
				else:
					h.press("light")
					hold = 30           # 0.5s hold -> Committed Cut
			else:
				# Blade Weaving mix: lateral / neutral / forward Dance, a Precision Cut every 4th action,
				# and (variant) Orbit Step / Whirling Assault / Breaking Point when stamina allows
				var k := step % 8
				step += 1
				if scen.contains("techniques") and k == 3 and h.stamina >= 30.0:
					h.release("heavy")
					h.move_input = right
					tap(h, "footwork")
					h.move_input = Vector3.ZERO
				elif scen.contains("techniques") and k == 6 and h.stamina >= 35.0:
					h.release("heavy")
					tap(h, "core")
				elif k == 7:
					if not bdk.in_edge():
						h.press("heavy")
						step -= 1       # retry once Edge is active
					else:
						tap(h, "light")   # Precision Cut
				else:
					h.release("heavy")
					if bdk.in_edge():
						step -= 1
					else:
						var dirs := [right, Vector3.ZERO, -right, tdir, right, Vector3.ZERO, -right]
						var m: Vector3 = dirs[k % dirs.size()]
						if m == tdir and to.length() < 1.6:
							m = Vector3.ZERO
						h.move_input = m
						tap(h, "light")
						h.move_input = Vector3.ZERO
			h.lock_target = r
		await get_tree().physics_frame
		m.stamina += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
		var mv := Vector2(h.global_position.x - last_pos.x, h.global_position.z - last_pos.z).length()
		last_pos = h.global_position
		if h.runner.is_busy():
			busy += 1
			moved += mv
			if h.runner.data.move_during <= 0.0:
				locked += 1
		elif h.dodging or h.stagger_timer > 0.0:
			locked += 1
		if h.stamina >= dodge_need:
			ready += 1
		min_st = minf(min_st, h.stamina)
	h.release("heavy")
	h.release("light")
	h.move_input = Vector3.ZERO
	h.runner.started.disconnect(cb)
	await wait(1.0)
	var dmg := hp0 - r.hp
	r.queue_free()
	return {"DPS": dmg / dur, "dmg/stamina": dmg / maxf(1.0, m.stamina), "stamina spent": m.stamina, "min stamina": min_st,
		"dodge-ready %": 100.0 * ready / frames, "accepted actions": accepted[0], "s between actions": dur / maxf(1.0, accepted[0]),
		"unable to move %": 100.0 * locked / frames, "attack uptime %": 100.0 * busy / frames,
		"m moved per attack": moved / maxf(1.0, accepted[0])}
