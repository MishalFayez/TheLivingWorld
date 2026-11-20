extends "res://tests/test_runner.gd"
## REVIEW-001 design ANALYSIS (measurements only, NOT a pass/fail suite, NOT in Test.ps1).
##   godot --headless --fixed-fps 60 res://tests/analysis_runner.tscn
## Lv10 natural kits, no augments, seeded. Every number describes "class + scripted input" or "class + its
## Party AI"; none of it is human play. Nothing in the game is changed by this tool.

const SEEDS := [11, 22, 33]


## TEST-ONLY bot variant used to separate AI decisions from class strength. The game's AIBrain is NOT changed.
## Same kit, same numbers, same inputs; only the decisions differ:
##   Reaver  : reacts to EVERY telegraphed attack and keeps one dodge of stamina before starting a cut.
##   Vanguard: dodges guard-breaking attacks instead of guarding them.
class DisciplinedAI extends AIBrain:
	const RESERVE := 30.0

	func _reaver(delta: float) -> void:
		var threat = _incoming_attack()
		if threat != null and _react_once(threat):
			dodge_at = Game.time + maxf(0.0, threat.startup_remaining() - 0.12)
			dodge_from = threat
		if Game.time >= dodge_at:
			dodge_at = INF
			if is_instance_valid(dodge_from):
				var side: Vector3 = (hero.global_position - dodge_from.global_position).cross(Vector3.UP)
				side.y = 0
				hero.move_input = side.normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
			tap("dodge")
			return
		if dodge_at < INF:
			hero.move_input = Vector3.ZERO      # a dodge is scheduled: do not start a cut into it
			return
		if hero.stamina < RESERVE:
			var t = _pick_target()
			if t != null:
				var away: Vector3 = hero.global_position - t.global_position
				away.y = 0
				hero.move_input = away.normalized() if away.length() < 3.5 else Vector3.ZERO
			return
		super._reaver(delta)

	func _vanguard(delta: float) -> void:
		var threat = _incoming_attack()
		if threat != null and threat.runner.data.guard_break and _react_once(threat):
			dodge_at = Game.time + maxf(0.0, threat.startup_remaining() - 0.12)
			dodge_from = threat
		if Game.time >= dodge_at:
			dodge_at = INF
			if hero.is_held("guard"):
				holds.erase("guard")
				hero.release("guard")
			if is_instance_valid(dodge_from):
				var side: Vector3 = (hero.global_position - dodge_from.global_position).cross(Vector3.UP)
				side.y = 0
				hero.move_input = side.normalized()
			tap("dodge")
			return
		if dodge_at < INF:
			return
		super._vanguard(delta)
var hits: Array = []          # damage taken by the hero, with context
var dealt: Dictionary = {}    # attack name -> damage dealt by the hero
var starts: Dictionary = {}   # attack id -> times started
var guards: Dictionary = {}
var ai: AIBrain


func _run_all() -> void:
	Events.damage_applied.connect(_on_damage)
	Events.guard_event.connect(func(d, _i, kind): if d == Game.player: guards[kind] = int(guards.get(kind, 0)) + 1)
	await reaver_boss()
	await vanguard_boss()
	await disciplined_boss()
	await mage_vs_guardian()
	await flame_partial_vs_full_cluster()
	await swordmaster_line_coverage()
	print("\n==== ANALYSIS: done ====")
	await teardown()


func _hero(cls: String) -> Hero:
	var h := await setup(cls, false, false, false)
	Game.permadeath = false
	Game.invincible = false
	Game.set_level(cls, 10)
	Game.prog(cls).pending_drafts = 0
	Game.prog(cls).pending_draft_tiers.clear()
	await wait(0.2)
	h.refresh_stats(true)
	h.restore_all()
	hits.clear()
	dealt.clear()
	starts.clear()
	guards.clear()
	h.runner.started.connect(func(d, _c): starts[d.id] = int(starts.get(d.id, 0)) + 1)
	return h


var use_disciplined := false


func _with_ai(h: Hero, s: int) -> void:
	var pb := h.get_node_or_null("Brain")
	if pb:
		h.remove_child(pb)
		pb.queue_free()
	ai = DisciplinedAI.new() if use_disciplined else AIBrain.new()
	ai.name = "Brain"
	h.add_child(ai)
	ai.rng.seed = s
	# behave exactly like a Party companion: several kit paths read AI-only requests only when not is_player
	# (e.g. ReaverSwordmaster.ai_lateral). Game.player still points at this hero for the metrics.
	h.is_player = false


func _state(h: Hero) -> String:
	if h.dodging:
		return "dodging(no i-frames)" if not h.is_invulnerable() else "dodging(i-frames)"
	if h.is_staggered():
		return "staggered"
	if h.runner.is_busy():
		var d: AttackData = h.runner.data
		var ph: String = ["", "startup", "active", "recovery"][h.runner.phase]
		return "own %s %s" % [ph, "heavy" if d.is_heavy or d.is_charged else ("skill" if d.has_tag("skill") else "light")]
	if h.is_held("guard"):
		return "guarding"
	return "free (moving/idle)"


func _on_damage(info) -> void:
	var p = Game.player
	if not is_instance_valid(p):
		return
	if info.target == p and info.final_amount > 0.0:
		var src := String(info.attack_name) if String(info.attack_name) != "" else "?"
		hits.append({"src": src, "dmg": info.final_amount, "state": _state(p), "stam": p.stamina, "dot": info.is_dot,
			"reaction_pending": ai != null and is_instance_valid(ai) and ai.dodge_at < INF})
	elif info.source == p and info.target != p:
		var n := String(info.attack_name)
		dealt[n] = float(dealt.get(n, 0.0)) + info.final_amount


func _table(title: String, d: Dictionary, total: float) -> void:
	print("  %s:" % title)
	var keys := d.keys()
	keys.sort_custom(func(a, b): return float(d[a]) > float(d[b]))
	for k in keys:
		print("    %-34s %7.0f  (%4.1f%%)" % [k, float(d[k]), 100.0 * float(d[k]) / maxf(total, 1.0)])


# ------------------------------------------------------------------ Priority 4: why does the Reaver bot die to the boss?
func _boss_fight(cls: String, s: int, limit: float) -> Dictionary:
	seed(s)
	Game.rng.seed = s
	var h: Hero = await _hero(cls)
	_with_ai(h, s)
	var boss := Game.spawn_enemy("ashen_warden", h.global_position + Vector3(0, 0, -12), "keep")
	var t := 0.0
	var low_stam := 0
	var frames := 0
	var resolve_gain := 0.0
	var resolve_spend := 0.0
	var last_res := float(h.kit.resolve) if "resolve" in h.kit else 0.0
	while t < limit and not h.downed and is_instance_valid(boss) and not boss.dead:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		frames += 1
		if h.stamina < 18.0:
			low_stam += 1
		if "resolve" in h.kit:
			var r := float(h.kit.resolve)
			if r > last_res:
				resolve_gain += r - last_res
			elif r < last_res:
				resolve_spend += last_res - r
			last_res = r
	var out := {"t": t, "downed": h.downed, "boss_hp_pct": 100.0 * boss.hp / boss.max_hp if is_instance_valid(boss) else 0.0,
		"low_stam_pct": 100.0 * low_stam / maxf(1, frames), "hits": hits.duplicate(), "dealt": dealt.duplicate(), "starts": starts.duplicate(),
		"guards": guards.duplicate(), "res_gain": resolve_gain, "res_spend": resolve_spend}
	if is_instance_valid(boss):
		boss.queue_free()
	return out


func reaver_boss() -> void:
	print("\n==== P4 REAVER (Swordmaster) BOT vs ASHEN WARDEN: what hits it, in which state ====")
	var by_src := {}
	var by_state := {}
	var taken := 0.0
	var dot := 0.0
	var ignored := 0
	var starved := 0
	for s in SEEDS:
		var r := await _boss_fight("reaver", s, 120.0)
		print("  seed %d: %.1fs, downed %s, boss HP left %.0f%%, time with stamina < 18: %.0f%%" % [s, r.t, r.downed, r.boss_hp_pct, r.low_stam_pct])
		for x in r.hits:
			taken += x.dmg
			by_src[x.src] = float(by_src.get(x.src, 0.0)) + x.dmg
			by_state[x.state] = float(by_state.get(x.state, 0.0)) + x.dmg
			if x.dot:
				dot += x.dmg
			if x.state.begins_with("free") and not x.reaction_pending:
				ignored += 1
			if x.stam < 17.6:
				starved += 1
		if s == SEEDS[0]:
			_table("attacks started (seed 11)", r.starts, 1.0)
	_table("damage taken by boss attack (3 seeds)", by_src, taken)
	_table("hero state when hit", by_state, taken)
	print("  damage from ground fire / DoT: %.0f (%.1f%%); hits while free with NO dodge scheduled: %d; hits with stamina below one dodge (17.6): %d" % [dot, 100.0 * dot / maxf(taken, 1.0), ignored, starved])


func vanguard_boss() -> void:
	print("\n==== P6 VANGUARD BOT vs ASHEN WARDEN: guard, Resolve and damage sources ====")
	for s in SEEDS:
		var r := await _boss_fight("vanguard", s, 150.0)
		var tot := 0.0
		for k in r.dealt:
			tot += r.dealt[k]
		print("  seed %d: %.1fs, downed %s, boss HP left %.0f%%, guards %s, Resolve gained %.0f / spent %.0f" % [s, r.t, r.downed, r.boss_hp_pct, str(r.guards), r.res_gain, r.res_spend])
		if s == SEEDS[0]:
			_table("damage dealt by attack (seed 11)", r.dealt, tot)
			_table("attacks started (seed 11)", r.starts, 1.0)


func disciplined_boss() -> void:
	print("\n==== P4/P6 SAME CLASS, DIFFERENT DECISIONS: test-only DisciplinedAI vs the shipped AIBrain (boss) ====")
	use_disciplined = true
	for cls in ["reaver", "vanguard"]:
		var won := 0
		var downs := 0
		var times: Array = []
		var hp_left: Array = []
		for s in SEEDS:
			var r := await _boss_fight(cls, s, 150.0)
			if r.downed:
				downs += 1
			elif r.boss_hp_pct <= 0.0:
				won += 1
			times.append(r.t)
			hp_left.append(r.boss_hp_pct)
			print("  %s seed %d: %.1fs, downed %s, boss HP left %.0f%%, stamina < 18 for %.0f%% of the fight, guards %s" % [cls, s, r.t, r.downed, r.boss_hp_pct, r.low_stam_pct, str(r.guards)])
		print("  -> %s DisciplinedAI: boss killed %d/3, downed %d/3" % [cls, won, downs])
	use_disciplined = false


# ------------------------------------------------------------------ Priority 5: Mage vs Shield Guardian / Flame tradeoff
func _mage_loop(h: Hero, slot_spell: String, hold_s: float, dur: float) -> Dictionary:
	h.kit.el.equip_spell(0, slot_spell)
	await wait(0.2)
	h.kit.mana = Game.balance.mana_max
	var mana0 := 0.0
	var last := float(h.kit.mana)
	var f := 0
	var frames := int(dur * 60.0)
	while f < frames:
		if h.can_act():
			h.press("light")
			var hold := int(hold_s * 60.0)
			for i in hold:
				await get_tree().physics_frame
				f += 1
				mana0 += maxf(0.0, last - float(h.kit.mana))
				last = float(h.kit.mana)
			h.release("light")
		await get_tree().physics_frame
		f += 1
		mana0 += maxf(0.0, last - float(h.kit.mana))
		last = float(h.kit.mana)
		h.kit.mana = Game.balance.mana_max      # unlimited mana: measures damage per cast time, mana reported separately
		last = h.kit.mana
	await wait(1.0)
	return {"mana": mana0}


func mage_vs_guardian() -> void:
	print("\n==== P5 MAGE vs SHIELD GUARDIAN (frozen, 12s per case, unlimited mana) ====")
	for case in [["front", "flame_cataclysm", 1.25], ["front", "flame_cataclysm", 0.3], ["side 90deg", "flame_cataclysm", 1.25],
			["behind", "flame_cataclysm", 1.25], ["front", "earthbreaker", 1.85], ["front", "thunder_conduit", 1.25]]:
		var vals: Array = []
		var mana := 0.0
		for s in SEEDS:
			seed(s)
			var h: Hero = await _hero("mage")
			var g := dummy("shield_guardian", h.global_position + Vector3(0, 0, -7))
			g.max_hp = 99999
			g.hp = 99999
			match case[0]:
				"front":
					face(g, h)
				"side 90deg":
					g.face_dir(Vector3(1, 0, 0))
				"behind":
					g.face_dir(Vector3(0, 0, -1))
			h.lock_target = g
			face(h, g)
			var r := await _mage_loop(h, case[1], case[2], 12.0)
			vals.append((99999.0 - g.hp) / 12.0)
			mana += r.mana
			g.queue_free()
		var mean: float = vals.reduce(func(a, b): return a + b, 0.0) / vals.size()
		print("  %-11s %-16s hold %.2fs : DPS %.1f [%.1f-%.1f], mana/s %.1f" % [case[0], case[1], case[2], mean, vals.min(), vals.max(), mana / (12.0 * SEEDS.size())])


func flame_partial_vs_full_cluster() -> void:
	print("\n==== P5 FLAME CATACLYSM partial vs full: 1 target vs a tight group of 3 (frozen wolves, 12s) ====")
	for layout in [[1, 1.0], [3, 1.0], [3, 2.6]]:
		var n: int = layout[0]
		var gap: float = layout[1]
		for hold in [0.3, 1.25]:
			var vals: Array = []
			var mana := 0.0
			for s in SEEDS:
				seed(s)
				var h: Hero = await _hero("mage")
				var ws: Array = []
				for i in n:
					var w := dummy("wolf", h.global_position + Vector3(-gap + i * gap, 0, -8))
					w.max_hp = 99999
					w.hp = 99999
					ws.append(w)
				h.lock_target = ws[0] if n == 1 else ws[1]
				face(h, h.lock_target)
				var r := await _mage_loop(h, "flame_cataclysm", hold, 12.0)
				var dmg := 0.0
				for w in ws:
					dmg += 99999.0 - w.hp
					w.queue_free()
				vals.append(dmg / 12.0)
				mana += r.mana
			var mean: float = vals.reduce(func(a, b): return a + b, 0.0) / vals.size()
			print("  %d target(s) %.1fm apart, %s : total DPS %.1f [%.1f-%.1f], damage per mana %.2f" % [n, gap, "partial" if hold < 1.0 else "full", mean, vals.min(), vals.max(), mean * 12.0 * SEEDS.size() / maxf(mana, 1.0)])


# ------------------------------------------------------------------ Priority 4: do the Blade Lines have different tactical reach?
func swordmaster_line_coverage() -> void:
	print("\n==== P4 SWORDMASTER LINES: targets reached per cut (frozen raiders) ====")
	var layouts := {"3 side by side at 1.8m": [Vector3(-1.4, 0, -1.8), Vector3(0, 0, -1.8), Vector3(1.4, 0, -1.8)],
		"1 at 2.6m (deep)": [Vector3(0, 0, -2.6)], "1 at 3.1m (far)": [Vector3(0, 0, -3.1)]}
	for lay in layouts:
		for line in ["forward", "left", "heavy"]:
			var h: Hero = await _hero("reaver")
			var es: Array = []
			for off in layouts[lay]:
				var e := dummy("raider", h.global_position + off)
				e.max_hp = 99999
				e.hp = 99999
				es.append(e)
			face(h, es[es.size() / 2])
			h.lock_target = null
			var got := [0]            # lambdas capture by value: count through a shared array
			var cb := func(_t, _i): got[0] += 1
			h.runner.hit_landed.connect(cb)
			if line == "heavy":
				tap(h, "heavy")
			else:
				if line == "left":
					h.held["blade_modifier"] = true
					h.strafe_axis = -1.0
				tap(h, "light")
				h.held["blade_modifier"] = false
				h.strafe_axis = 0.0
			await wait(1.0)
			h.runner.hit_landed.disconnect(cb)
			print("  %-24s %-8s : %d target(s) hit, moved %.2fm" % [lay, line, got[0], h.global_position.distance_to(Vector3(0, 0.2, 26))])
			for e in es:
				e.queue_free()
