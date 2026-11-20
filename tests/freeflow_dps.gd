extends "res://tests/benchmark_runner.gd"
## REAVER-FREEFLOW-001 DPS COMPARISON (measurement only; NOT pass/fail, NOT part of tools/dev/Test.ps1).
##   godot --headless --fixed-fps 60 res://tests/freeflow_dps.tscn
## Same conditions as benchmark_runner part A: Level 10 natural unlocks, starter gear, no allocated points,
## frozen Raider (99999 HP), 10s, crits ON, seeds 11 / 22 / 33. Swordmaster baseline is re-measured in
## the same run. Scripted inputs, not a human: it measures, it does not judge feel.

var core := "swordmaster"
var transform_aug := ""


func _run_all() -> void:
	Events.damage_applied.connect(_on_damage)
	core = "swordmaster"
	for scen in ["LMB every 0.25s (F->F)", "deliberate lines F,L,F,R,Heavy", "skills when ready + lines"]:
		await _trials("A", "reaver", "SM " + scen)
	core = "freeflow"
	for scen in ["LMB every 0.25s", "LMB,LMB,Heavy", "skills when ready + LMB,LMB,Heavy"]:
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


func _scripted(cls: String, scen: String) -> Dictionary:
	if scen.begins_with("SM "):
		return await super._scripted(cls, scen.substr(3))
	var h: Hero = await _hero(cls)
	var r := dummy("raider", h.global_position + Vector3(0, 0, -2.2))
	r.max_hp = 99999
	r.hp = 99999
	h.lock_target = r
	face(h, r)
	_reset_metrics()
	var hp0 := r.hp
	var dur := 10.0
	var last_st := h.stamina
	var pattern := ["light", "light", "heavy"]
	var pi := 0
	var next_at := 0
	var opp := 0
	var ffk: ReaverFreeFlow = h.kit.ff
	for f in int(dur * 60.0):
		if scen.contains("every 0.25s"):
			if f >= next_at:
				tap(h, "light")
				next_at = f + 15
		elif h.can_act():
			var act := ""
			if scen.contains("skills"):
				if h.kit.skill_cd("r_decisive_cut") <= 0.0 and h.stamina >= 25.0:
					act = "skill3"
				elif h.kit.skill_cd("r_pivot_cut") <= 0.0 and h.stamina >= 16.0:
					act = "skill2"
				elif h.kit.skill_cd("r_pursuit_cut") <= 0.0 and h.stamina >= 16.0:
					act = "skill1"
			if act == "":
				act = pattern[pi % pattern.size()]
				pi += 1
			# Pivot Cut circles the target (lateral input); everything else stands still
			h.move_input = Vector3(1, 0, 0) if act == "skill2" else Vector3.ZERO
			tap(h, act)
			h.lock_target = r
		await get_tree().physics_frame
		m.stamina += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
	h.move_input = Vector3.ZERO
	await wait(1.0)
	opp = ffk.opportunities_consumed
	var dmg := hp0 - r.hp
	r.queue_free()
	return {"DPS": dmg / dur, "crit %": 100.0 * m.dealt_crit / maxf(1.0, m.dealt), "dmg/stamina": dmg / maxf(1.0, m.stamina),
		"stamina": m.stamina, "opp consumed": opp}
