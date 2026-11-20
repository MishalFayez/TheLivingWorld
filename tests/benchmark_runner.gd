extends "res://tests/test_runner.gd"
## CLASS BENCHMARKS (audit, Phase 9). Repeatable, seeded measurements; NOT a pass/fail suite and NOT
## part of tools/dev/Test.ps1. It measures, it does not judge feel or balance intent.
##   godot --headless --fixed-fps 60 res://tests/benchmark_runner.tscn
##
## Every class: natural Level 10 unlocks (no Debug unlocks), default cores, starter equipment, NO augments,
## no allocated attribute points, permadeath off, never invincible.
## A. Scripted single-target: frozen Raider (99999 HP), 10 s, crits ON, global RNG seeded per trial.
## B. Live encounters: the class's own Party AI (AIBrain) drives the hero against identical spawns,
##    so every class is played by the same (imperfect) bot. Results measure "class + bot", not a human.

const TRIALS := [11, 22, 33]
var rows: Array = []
var m: Dictionary = {}


func _run_all() -> void:
	Events.damage_applied.connect(_on_damage)
	Events.healed.connect(_on_heal)
	Events.guard_event.connect(_on_guard)
	Events.spell_released.connect(func(c, _id, _el, full, _t, _mana): if c == Game.player: m["casts_full" if full else "casts_partial"] += 1)
	Events.spell_interrupted.connect(func(c, _id, _r): if c == Game.player: m.casts_interrupted += 1)
	for cls in Game.CLASSES:
		for scen in _scripted_for(cls):
			await _trials("A", cls, scen)
	for cls in Game.CLASSES:
		for scen in ["1 raider", "3 wolves", "6 mixed", "elite raider", "boss"]:
			await _trials("B", cls, scen)
	print("\n==== BENCHMARK RESULTS (mean of %d seeded trials; min-max in brackets) ====" % TRIALS.size())
	for r in rows:
		print(r)
	print("\n==== BENCHMARK: done ====")
	await teardown()


func _scripted_for(cls: String) -> Array:
	match cls:
		"vanguard":
			return ["LMB every 0.25s", "skills when ready + LMB"]
		"mage":
			return ["full Flame Cataclysm loop", "partial Flame Cataclysm loop", "full Thunder Conduit loop"]
		_:
			return ["LMB every 0.25s (F->F)", "deliberate lines F,L,F,R,Heavy", "skills when ready + lines"]


func _reset_metrics() -> void:
	m = {"dealt": 0.0, "dealt_crit": 0.0, "taken": 0.0, "heal_done": 0.0, "heal_taken": 0.0, "guard": 0, "perfect": 0,
		"break": 0, "dodge": 0, "intercept": 0, "casts_full": 0, "casts_partial": 0, "casts_interrupted": 0,
		"stamina": 0.0, "mana": 0.0, "downed": 0, "kills": 0}


func _on_damage(info) -> void:
	if not is_instance_valid(Game.player):
		return
	if info.source == Game.player and info.target != Game.player:
		m.dealt += info.final_amount
		if info.is_crit:
			m.dealt_crit += info.final_amount
	elif info.target == Game.player:
		m.taken += info.final_amount


func _on_heal(source, target, amount, _over, _tags) -> void:
	if source == Game.player:
		m.heal_done += amount
	if target == Game.player:
		m.heal_taken += amount


func _on_guard(defender, _info, kind) -> void:
	if defender == Game.player and m.has(kind):
		m[kind] += 1


func _hero(cls: String) -> Hero:
	var h := await setup(cls, false, false, false)
	Game.reaver_core = "swordmaster"
	Game.mage_core = "elementalist"
	Game.permadeath = false
	Game.invincible = false
	Game.set_level(cls, 10)
	Game.prog(cls).pending_drafts = 0
	Game.prog(cls).pending_draft_tiers.clear()
	await wait(0.2)
	h.refresh_stats(true)
	h.restore_all()
	return h


func _trials(part: String, cls: String, scen: String) -> void:
	var res: Array = []
	for s in TRIALS:
		seed(s)
		Game.rng.seed = s
		if part == "A":
			res.append(await _scripted(cls, scen))
		else:
			res.append(await _encounter(cls, scen, s))
	var keys: Array = res[0].keys()
	var line := "%s | %-8s | %-30s" % [part, cls, scen]
	for k in keys:
		var vals: Array = res.map(func(r): return float(r[k]))
		var mean: float = vals.reduce(func(a, b): return a + b, 0.0) / vals.size()
		line += " | %s %s [%s-%s]" % [k, _fmt(mean), _fmt(vals.min()), _fmt(vals.max())]
	rows.append(line)
	print(line)


func _fmt(v: float) -> String:
	return ("%d" % roundi(v)) if absf(v) >= 100.0 else ("%.2f" % v)


# ------------------------------------------------------------------ A. scripted single target
func _scripted(cls: String, scen: String) -> Dictionary:
	var h: Hero = await _hero(cls)
	var r := dummy("raider", h.global_position + Vector3(0, 0, -2.2))
	r.max_hp = 99999
	r.hp = 99999
	h.lock_target = r
	face(h, r)
	_reset_metrics()
	var hp0 := r.hp
	var dur := 10.0
	var frames := int(dur * 60.0)
	var last_st := h.stamina
	var last_mana := _mana(h)
	var seq := ["forward", "left", "forward", "right", "heavy"]
	var si := 0
	var next_at := 0
	var hold_until := -1
	var hold_action := ""
	var skill_i := 0
	var fallback_at := -1
	for f in frames:
		if hold_action != "" and f >= hold_until:
			h.release(hold_action)
			hold_action = ""
			next_at = f + 2
		if hold_action == "" and f >= next_at:
			match scen:
				"LMB every 0.25s", "LMB every 0.25s (F->F)":
					tap(h, "light")
					next_at = f + 15
				"skills when ready + LMB", "skills when ready + lines":
					if fallback_at == f:
						# the skill did not start (cooldown / not ready): basic attack instead
						if not h.runner.is_busy():
							if cls == "reaver":
								_line(h, seq[si % seq.size()])
								si += 1
							else:
								tap(h, "light")
						next_at = f + 14
					elif h.can_act():
						var k := skill_i % 3
						var sk: String = ["skill1", "skill2", "skill3"][k]
						skill_i += 1
						if cls == "vanguard" and sk == "skill2":
							if h.kit.skill_ready(1):
								h.press(sk)
								hold_action = sk
								hold_until = f + 75      # full Judgment charge
							else:
								fallback_at = f + 1
								next_at = f + 1
						else:
							tap(h, sk)
							fallback_at = f + 1
							next_at = f + 1
					else:
						next_at = f + 1
				"deliberate lines F,L,F,R,Heavy":
					_line(h, seq[si % seq.size()])
					si += 1
					next_at = f + 15
				"full Flame Cataclysm loop", "partial Flame Cataclysm loop", "full Thunder Conduit loop":
					if h.can_act():
						var slot := "light"
						if scen.contains("Thunder"):
							Game.prog("mage").spell_loadout[0] = "thunder_conduit"
						h.press(slot)
						hold_action = slot
						hold_until = f + (18 if scen.contains("partial") else 74)
					else:
						next_at = f + 1
		await get_tree().physics_frame
		m.stamina += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
		var mana_now := _mana(h)
		m.mana += maxf(0.0, last_mana - mana_now)
		last_mana = mana_now
	if hold_action != "":
		h.release(hold_action)
	await wait(1.0)
	var dmg := hp0 - r.hp
	r.queue_free()
	return {"DPS": dmg / dur, "crit %": 100.0 * m.dealt_crit / maxf(1.0, m.dealt), "dmg/stamina": dmg / maxf(1.0, m.stamina),
		"dmg/mana": dmg / maxf(1.0, m.mana) if m.mana > 0.0 else 0.0, "stamina": m.stamina, "mana": m.mana,
		"full casts": m.casts_full, "partial casts": m.casts_partial}


func _line(h: Hero, want: String) -> void:
	if want == "heavy":
		tap(h, "heavy")
		return
	if want != "forward":
		h.held["blade_modifier"] = true
		h.strafe_axis = -1.0 if want == "left" else 1.0
	tap(h, "light")
	h.held["blade_modifier"] = false
	h.strafe_axis = 0.0


func _mana(h: Hero) -> float:
	return float(h.kit.mana) if "mana" in h.kit else 0.0


# ------------------------------------------------------------------ B. live encounters (bot-driven)
func _encounter(cls: String, scen: String, s: int) -> Dictionary:
	var h: Hero = await _hero(cls)
	var pb := h.get_node_or_null("Brain")
	if pb:
		h.remove_child(pb)
		pb.queue_free()
	var ai := AIBrain.new()
	ai.name = "Brain"
	h.add_child(ai)
	ai.rng.seed = s
	# behave exactly like a Party companion (AI-only kit paths such as ai_lateral check not is_player)
	h.is_player = false
	var c := h.global_position + Vector3(0, 0, -9)
	var spawns: Array = []
	match scen:
		"1 raider":
			spawns = [["raider", c, false]]
		"3 wolves":
			spawns = [["wolf", c + Vector3(-2, 0, 0), false], ["wolf", c, false], ["wolf", c + Vector3(2, 0, 0), false]]
		"6 mixed":
			spawns = [["wolf", c + Vector3(-3, 0, 0), false], ["wolf", c + Vector3(3, 0, 0), false], ["raider", c + Vector3(-1.5, 0, -1), false],
				["raider", c + Vector3(1.5, 0, -1), false], ["shield_guardian", c + Vector3(0, 0, -2), false], ["ash_caster", c + Vector3(0, 0, -6), false]]
		"elite raider":
			spawns = [["raider", c, true]]
		"boss":
			spawns = [["ashen_warden", c + Vector3(0, 0, -3), false]]
	var foes: Array = []
	for sp in spawns:
		foes.append(Game.spawn_enemy(sp[0], sp[1], "keep" if scen == "boss" else "outskirts", sp[2]))
	_reset_metrics()
	var limit := 150.0 if scen == "boss" else 75.0
	var t := 0.0
	var last_st := h.stamina
	var last_mana := _mana(h)
	var was_down := false
	while t < limit:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		m.stamina += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
		var mana_now := _mana(h)
		m.mana += maxf(0.0, last_mana - mana_now)
		last_mana = mana_now
		if h.downed and not was_down:
			m.downed += 1
		was_down = h.downed
		if h.downed or h.dead:
			break
		var alive := foes.filter(func(e): return is_instance_valid(e) and not e.dead)
		if alive.is_empty():
			break
	var alive_n := foes.filter(func(e): return is_instance_valid(e) and not e.dead).size()
	for e in foes:
		if is_instance_valid(e):
			e.queue_free()
	return {"cleared": 1.0 if alive_n == 0 else 0.0, "TTK s": t, "downed": m.downed, "dmg taken": m.taken, "taken %HP": 100.0 * m.taken / h.max_hp,
		"DPS": m.dealt / maxf(t, 0.1), "crit %": 100.0 * m.dealt_crit / maxf(1.0, m.dealt), "self-heal": m.heal_taken,
		"stamina": m.stamina, "mana": m.mana, "guards": m.guard, "perfect": m.perfect, "guard breaks": m["break"], "dodged hits": m.dodge}
