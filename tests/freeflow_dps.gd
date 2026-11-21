extends "res://tests/benchmark_runner.gd"
## REAVER FREE FLOW DPS / STAMINA COMPARISON (measurement only; NOT pass/fail, NOT part of tools/dev/Test.ps1).
##   godot --headless --fixed-fps 60 res://tests/freeflow_dps.tscn
## Same conditions as benchmark_runner part A: Level 10 natural unlocks, starter gear, no allocated points,
## frozen Raider (99999 HP), 10s, crits ON, seeds 11 / 22 / 33. Swordmaster baseline is re-measured in
## the same run. Scripted inputs, not a human: it measures, it does not judge feel.
## REAVER-FREEFLOW-002 adds stamina metrics (uptime, dodge-ready time, minimum), a repeated-miss scenario
## and a scripted Perfect Dodge read scenario. Fields that only exist in 002 are read defensively, so the
## same tool can be run on the 001 commit for a before / after comparison.

var core := "swordmaster"
var transform_aug := ""


func _run_all() -> void:
	Events.damage_applied.connect(_on_damage)
	core = "swordmaster"
	for scen in ["LMB every 0.25s (F->F)", "deliberate lines F,L,F,R,Heavy", "skills when ready + lines"]:
		await _trials("A", "reaver", "SM " + scen)
	core = "freeflow"
	for scen in ["LMB every 0.25s", "LMB,LMB,Heavy", "skills when ready + LMB,LMB,Heavy", "LMB,LMB,Heavy ALL MISSING",
			"Perfect Dodge read every 2s + LMB,LMB,Heavy"]:
		await _trials("A", "reaver", "FF " + scen)
	for t in ["precision_edge", "tempest_edge", "momentum_edge"]:
		transform_aug = t
		await _trials("A", "reaver", "FF skills + LMB,LMB,Heavy [%s]" % t)
	transform_aug = ""
	print("\n==== FREE FLOW DPS (mean of %d seeded trials; min-max in brackets) ====" % TRIALS.size())
	for r in rows:
		print(r)
	print("\n==== FREE FLOW DPS: done ====")
	await teardown()


func _hero(cls: String) -> Hero:
	var h: Hero = await super._hero(cls)
	Game.reaver_core = core
	Game.set_level(cls, 10)
	Game.prog(cls).pending_drafts = 0
	Game.prog(cls).pending_draft_tiers.clear()
	if transform_aug != "":
		Game.add_augment(cls, transform_aug)
	await wait(0.1)
	h.refresh_stats(true)
	h.restore_all()
	return h


func _cost(id: String) -> float:
	return (load("res://data/attacks/%s.tres" % id) as AttackData).stamina_cost


func _scripted(cls: String, scen: String) -> Dictionary:
	if scen.begins_with("SM "):
		return await super._scripted(cls, scen.substr(3))
	var h: Hero = await _hero(cls)
	var r := dummy("raider", h.global_position + Vector3(0, 0, -2.2))
	r.max_hp = 99999
	r.hp = 99999
	var missing := scen.contains("MISSING")
	h.lock_target = null if missing else r
	if missing:
		h.face_dir(Vector3(0, 0, 1))     # turned away: every attack misses
	else:
		face(h, r)
	_reset_metrics()
	var hp0 := r.hp
	var dur := 10.0
	var frames := int(dur * 60.0)
	var last_st := h.stamina
	var pattern := ["light", "light", "heavy"]
	var pi := 0
	var next_at := 0
	var ffk: ReaverFreeFlow = h.kit.ff
	var dodge_need: float = Game.balance.dodge_cost * h.kit.dodge_cost_mult()
	var busy := 0
	var dodge_ready := 0
	var min_st := h.stamina
	var next_read := 60
	var read_state := 0      # 0 idle, 1 dodging (inject the enemy attack early in the i-frames)
	var raider_atk := load("res://data/attacks/raider_combo1.tres") as AttackData
	var c_dec := _cost("ff_decisive")
	var c_piv := _cost("ff_pivot")
	var c_pur := _cost("ff_pursuit")
	for f in frames:
		if scen.contains("Perfect Dodge read"):
			if read_state == 0 and f >= next_read and h.can_act() and h.stamina > dodge_need:
				h.try_dodge()
				read_state = 1
				next_read = f + 120
			elif read_state == 1 and h.dodging and h.dodge_t >= 0.08:
				var info := DamageInfo.new()
				info.source = r
				info.target = h
				info.attack = raider_atk
				info.attack_name = "read"
				info.amount = 0.0
				info.raw_amount = 0.0
				info.source_pos = r.global_position
				h.take_damage(info)
				read_state = 0
		if scen.contains("every 0.25s"):
			if f >= next_at:
				tap(h, "light")
				next_at = f + 15
		elif h.can_act() and read_state == 0:
			var act := ""
			if scen.contains("skills"):
				if h.kit.skill_cd("r_decisive_cut") <= 0.0 and h.stamina >= c_dec:
					act = "skill3"
				elif h.kit.skill_cd("r_pivot_cut") <= 0.0 and h.stamina >= c_piv:
					act = "skill2"
				elif h.kit.skill_cd("r_pursuit_cut") <= 0.0 and h.stamina >= c_pur:
					act = "skill1"
			if act == "":
				act = pattern[pi % pattern.size()]
				pi += 1
			# Pivot Cut circles the target (lateral input); everything else stands still
			h.move_input = Vector3(1, 0, 0) if act == "skill2" else Vector3.ZERO
			tap(h, act)
			if not missing:
				h.lock_target = r
		await get_tree().physics_frame
		m.stamina += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
		if h.runner.is_busy():
			busy += 1
		if h.stamina >= dodge_need:
			dodge_ready += 1
		min_st = minf(min_st, h.stamina)
	h.move_input = Vector3.ZERO
	await wait(1.0)
	var dmg := hp0 - r.hp
	r.queue_free()
	var refunded: float = float(ffk.get("stamina_refunded")) if ffk.get("stamina_refunded") != null else 0.0
	return {"DPS": dmg / dur, "dmg/stamina": dmg / maxf(1.0, m.stamina), "stamina spent": m.stamina,
		"refunded": refunded, "min stamina": min_st, "attack uptime %": 100.0 * busy / frames,
		"dodge-ready %": 100.0 * dodge_ready / frames, "crit %": 100.0 * m.dealt_crit / maxf(1.0, m.dealt),
		"enhanced follow-ups": ffk.opportunities_consumed}
