extends "res://tests/benchmark_runner.gd"
## LEVEL10-FOUNDATION-005 review: Level 1-10 balance comparison (measurement tool, NOT a pass/fail suite,
## not in Test.ps1). Deterministic: global RNG, Game.rng and the AI brain are seeded per run.
##   godot --headless --fixed-fps 60 res://tests/l10_balance.tscn
##
## Part B (live): the class's own Party AI (AIBrain) plays the measured hero against real enemies (they
## attack, move, guard, recover) - natural level unlocks, approved cores, starter gear, no attribute points.
## Builds: none / one path anchor (Lv4) / anchor + 1 (Lv8) / three cards per path (Lv10) with a MECHANICAL
## synergy pair, plus a same-path alternative WITHOUT a synergy pair. Party runs add the AI companions.
## Part S (scripted, Reaver only): the AI never uses Edge, so Edge Mastery is measured with a scripted loop
## against a raider that keeps attacking.
## The numbers describe "class + bot + build"; they do not judge how it feels to a human.

const SEED := 11
const BUILDS := {
	"vanguard": {"A1": ["vb01_living_fortress"], "B1": ["vk01_aegis_reversal"],
		"A2": ["vb01_living_fortress", "vb03_bastion_pulse"], "B2": ["vk01_aegis_reversal", "vk04_retaliation_window"],
		"A3 syn": ["vb01_living_fortress", "vb03_bastion_pulse", "vb04_heavy_anchor"], "A3 alt": ["vb01_living_fortress", "vb04_heavy_anchor", "vc02_steel_foundation"],
		"B3 syn": ["vk01_aegis_reversal", "vk03_redirected_force", "vk04_retaliation_window"], "B3 alt": ["vk01_aegis_reversal", "vk05_judgment_echo", "vk02_precise_defense"],
		"A3 party": ["vb01_living_fortress", "vb03_bastion_pulse", "vc03_shared_aegis"], "B3 party": ["vk01_aegis_reversal", "vk05_judgment_echo", "vk06_guardians_retort"]},
	"mage": {"A1": ["mf01_elemental_crossroads"], "B1": ["ma01_spell_threading"],
		"A2": ["mf01_elemental_crossroads", "mf03_thermal_fracture"], "B2": ["ma01_spell_threading", "mc05_dual_invocation"],
		"A3 syn": ["mf01_elemental_crossroads", "mf03_thermal_fracture", "mf05_living_confluence"], "A3 alt": ["mf01_elemental_crossroads", "mf02_lingering_essence", "mc02_gentle_current"],
		"B3 syn": ["ma01_spell_threading", "mc05_dual_invocation", "ma03_rewoven_spell"], "B3 alt": ["ma01_spell_threading", "ma04_swift_invocation", "mc03_elemental_memory"],
		"A3 party": ["mf01_elemental_crossroads", "mf05_living_confluence", "mc06_woven_protection"], "B3 party": ["ma01_spell_threading", "ma05_sympathetic_link", "ma02_arcane_relay"]},
	"reaver": {"A1": ["rd01_phantom_footwork"], "B1": ["re01_perfect_draw"],
		"A2": ["rd01_phantom_footwork", "rd02_flowing_steps"], "B2": ["re01_perfect_draw", "re03_fracturing_edge"],
		"A3 syn": ["rd01_phantom_footwork", "rd02_flowing_steps", "rd05_tempest_waltz"], "A3 alt": ["rd01_phantom_footwork", "rd04_extended_orbit", "rc02_swordsmans_breath"],
		"B3 syn": ["re01_perfect_draw", "re03_fracturing_edge", "rc06_clean_execution"], "B3 alt": ["re01_perfect_draw", "re06_patient_blade", "re02_steel_focus"],
		"A3 party": ["rd01_phantom_footwork", "rd02_flowing_steps", "g02_measured_recovery"], "B3 party": ["re01_perfect_draw", "re03_fracturing_edge", "g03_echoing_impact"]},
}
## [level, build, encounter, party]
const PLAN := [
	[1, "none", "1 raider", false], [1, "none", "elite raider", false],
	[4, "none", "1 raider", false], [4, "A1", "1 raider", false], [4, "B1", "1 raider", false],
	[4, "none", "elite raider", false], [4, "A1", "elite raider", false], [4, "B1", "elite raider", false],
	[8, "A2", "1 raider", false], [8, "B2", "1 raider", false], [8, "A2", "elite raider", false], [8, "B2", "elite raider", false],
	[10, "none", "1 raider", false], [10, "A3 syn", "1 raider", false], [10, "A3 alt", "1 raider", false], [10, "B3 syn", "1 raider", false], [10, "B3 alt", "1 raider", false],
	[10, "none", "elite raider", false], [10, "A3 syn", "elite raider", false], [10, "B3 syn", "elite raider", false],
	[10, "none", "boss", false], [10, "A3 syn", "boss", false], [10, "B3 syn", "boss", false],
	[10, "none", "3 raiders party", true], [10, "A3 party", "3 raiders party", true], [10, "B3 party", "3 raiders party", true],
]

## Part S: identical scripted inputs for every build (only the cards differ). [level, build, enemy]
const SCRIPTED := [[4, "none", "elite raider"], [4, "A1", "elite raider"], [4, "B1", "elite raider"],
	[10, "none", "elite raider"], [10, "A3 syn", "elite raider"], [10, "A3 alt", "elite raider"], [10, "B3 syn", "elite raider"], [10, "B3 alt", "elite raider"],
	[10, "none", "boss"], [10, "A3 syn", "boss"], [10, "B3 syn", "boss"]]

var trig_n: Dictionary = {}
var poise_breaks: int = 0
var shields: float = 0.0


func _run_all() -> void:
	Events.damage_applied.connect(_on_damage)
	Events.healed.connect(_on_heal)
	Events.guard_event.connect(_on_guard)
	Events.augment_triggered.connect(func(o, id, _d): if is_instance_valid(Game.player) and o == Game.player and Game.augment_db.get_augment(id) != null and Game.augment_db.get_augment(id).pool == "l10": trig_n[id] = int(trig_n.get(id, 0)) + 1)
	Events.combat_notice.connect(func(t, who): if t == "POISE BROKEN" and who is Enemy: poise_breaks += 1)
	Events.log_message.connect(_on_log)
	var only := OS.get_environment("L10_BALANCE_CLASS")
	for cls in ["vanguard", "mage", "reaver"]:
		if only != "" and only != cls:
			continue
		if OS.get_environment("L10_BALANCE_PART") != "S":
			for row in PLAN:
				await _run(cls, int(row[0]), String(row[1]), String(row[2]), bool(row[3]))
	for cls in ["vanguard", "mage", "reaver"]:
		if only != "" and only != cls:
			continue
		for row in SCRIPTED:
			await _scripted_run(cls, int(row[0]), String(row[1]), String(row[2]))
	# determinism check: the same scripted run twice must give identical numbers
	if only == "" or only == "reaver":
		await _scripted_run("reaver", 10, "B3 syn", "elite raider")
	print("\n==== L10 BALANCE RESULTS ====")
	for r in rows:
		print(r)
	print("\n==== L10 BALANCE: done ====")
	await teardown()


func _on_log(text, _cat) -> void:
	var s := String(text)
	if s.contains("gains a Ward (") and is_instance_valid(Game.player):
		shields += float(s.get_slice("(", 1).get_slice(")", 0))


func _setup_hero(cls: String, level: int, build: String, party: bool) -> Hero:
	var h := await setup(cls, party, false, false)
	Game.reaver_core = "bladedancer"
	Game.mage_core = "elementalist"
	Game.permadeath = false
	Game.invincible = false
	Game.party_mode = party
	Game.set_level(cls, level)
	for c in Game.CLASSES:
		Game.prog(c).pending_drafts = 0
		Game.prog(c).pending_draft_tiers.clear()
	if build != "none":
		for id in BUILDS[cls][build]:
			Game.prog(cls).augments.append(id)
	await wait(0.2)
	h.refresh_stats(true)
	h.restore_all()
	return h


func _run(cls: String, level: int, build: String, scen: String, party: bool) -> void:
	seed(SEED)
	Game.rng.seed = SEED
	var h := await _setup_hero(cls, level, build, party)
	var pb := h.get_node_or_null("Brain")
	if pb:
		h.remove_child(pb)
		pb.queue_free()
	var ai := AIBrain.new()
	ai.name = "Brain"
	h.add_child(ai)
	ai.rng.seed = SEED
	h.is_player = false
	# an AI-driven hero reads the companion progression (same level, auto-allocated points): give it the build
	var cp := Game.companion_prog(cls)
	cp.augments.clear()
	cp.inactive_mutations.clear()
	if build != "none":
		for id in BUILDS[cls][build]:
			cp.augments.append(id)
	h.refresh_stats(true)
	h.restore_all()
	var c := h.global_position + Vector3(0, 0, -9)
	var spawns: Array = []
	match scen:
		"1 raider":
			spawns = [["raider", c, false]]
		"elite raider":
			spawns = [["raider", c, true]]
		"boss":
			spawns = [["ashen_warden", c + Vector3(0, 0, -3), false]]
		"3 raiders party":
			spawns = [["raider", c + Vector3(-2, 0, 0), false], ["raider", c, false], ["raider", c + Vector3(2, 0, 0), false]]
	var area := "keep" if scen == "boss" else ("ruins" if level >= 8 else "outskirts")
	var foes: Array = []
	for sp in spawns:
		foes.append(Game.spawn_enemy(sp[0], sp[1], area, sp[2]))
	_reset_metrics()
	trig_n.clear()
	poise_breaks = 0
	shields = 0.0
	var limit := 150.0 if scen == "boss" else 90.0
	var t := 0.0
	var last_st := h.stamina
	var last_mana := _mana(h)
	var was_down := false
	var busy := 0
	var frames := 0
	var targeted := 0
	var target_samples := 0
	while t < limit:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		frames += 1
		if h.runner.is_busy() or h.kit.charging != "":
			busy += 1
		m.stamina += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
		var mana_now := _mana(h)
		m.mana += maxf(0.0, last_mana - mana_now)
		last_mana = mana_now
		for e in foes:
			if is_instance_valid(e) and not e.dead and e.target != null:
				target_samples += 1
				if e.target == h:
					targeted += 1
		if h.downed and not was_down:
			m.downed += 1
		was_down = h.downed
		if h.downed or h.dead:
			break
		if foes.filter(func(e): return is_instance_valid(e) and not e.dead).is_empty():
			break
	var alive_n := foes.filter(func(e): return is_instance_valid(e) and not e.dead).size()
	for e in foes:
		if is_instance_valid(e):
			e.queue_free()
	var tr := 0
	for k in trig_n:
		tr += int(trig_n[k])
	var top: Array = trig_n.keys()
	top.sort_custom(func(a, b): return int(trig_n[a]) > int(trig_n[b]))
	var top_txt := ", ".join(top.slice(0, 3).map(func(k): return "%s %d" % [String(k).get_slice("_", 0), int(trig_n[k])]))
	var line := "B | %-8s | Lv%-2d | %-8s | %-15s | cleared %d | TTK %5.1fs | DPS %6.1f | uptime %3d%% | taken %4d%%HP | downed %d | heal %5d | shield %4d | stamina %5d | mana %5d | guards %3d perfect %2d intercept %2d | aggro on hero %3d%% | poise breaks %2d | aug triggers %3d (%s)" % [
		cls, level, build, scen, 1 if alive_n == 0 else 0, t, m.dealt / maxf(t, 0.1), roundi(100.0 * busy / maxf(1, frames)),
		roundi(100.0 * m.taken / h.max_hp), m.downed, roundi(m.heal_done), roundi(shields), roundi(m.stamina), roundi(m.mana),
		m.guard, m.perfect, m.intercept, roundi(100.0 * targeted / maxf(1, target_samples)), poise_breaks, tr, top_txt]
	rows.append(line)
	print(line)


## Part S: a scripted player (same inputs for every build) against a LIVE attacking enemy, 30 s window.
## Vanguard: fresh Guard just before each enemy hit (Perfect Guard), walk forward while guarding, then
##   alternate Heavy / LMB counter; light combo and skills otherwise.
## Worldweaver: Crystal Formation next to the enemy, full Flame Cataclysm onto it (Fire / Frost), Life Bloom
##   on itself when below 60%, wheel swap every 4th cast; dodge an attack about to land.
## Reaver: Dance (neutral / lateral) and an Edge strike every 4th action (full-charge Committed Cut or
##   Precision Cut); dodge an attack about to land.
func _scripted_run(cls: String, level: int, build: String, enemy: String) -> void:
	seed(SEED)
	Game.rng.seed = SEED
	var h := await _setup_hero(cls, level, build, false)
	for ch in h.get_children():
		if ch is PlayerBrain:
			ch.set_physics_process(false)
	var r: Enemy
	if enemy == "boss":
		r = Game.spawn_enemy("ashen_warden", h.global_position + Vector3(0, 0, -3.0), "keep", false)
	else:
		r = Game.spawn_enemy("raider", h.global_position + Vector3(0, 0, -2.4), "ruins" if level >= 8 else "outskirts", true)
	r.max_hp = 999999
	r.hp = 999999
	h.lock_target = r
	face(h, r)
	_reset_metrics()
	trig_n.clear()
	poise_breaks = 0
	shields = 0.0
	var dur := 30.0
	var hold := -1
	var hold_action := ""
	var step := 0
	var casts := 0
	var last_st := h.stamina
	var last_mana := _mana(h)
	var busy := 0
	var frames := int(dur * 60.0)
	for f in frames:
		var to: Vector3 = r.global_position - h.global_position
		to.y = 0
		var incoming: bool = r.runner.is_busy() and r.runner.phase == AttackRunner.Phase.STARTUP and r.runner.data != null and r.runner.data.hits > 0 \
			and r.runner.t > r.runner.data.startup - 0.14 and to.length() < 4.5
		if hold > 0:
			hold -= 1
			if cls == "vanguard" and hold_action == "guard":
				h.move_input = to.normalized() if to.length() > 1.6 else Vector3.ZERO
			if hold == 0:
				h.release(hold_action)
				h.move_input = Vector3.ZERO
				hold = -1
				hold_action = ""
		elif cls == "vanguard":
			var vk: VanguardKit = h.kit
			if incoming and not vk.guarding:
				h.runner.interrupt()
				h.press("guard")
				hold_action = "guard"
				hold = 30
			elif Game.time < vk.counter_until and h.can_act():
				tap(h, "heavy" if step % 2 == 0 else "light")
				step += 1
			elif h.can_act():
				if to.length() > 3.0 and vk.unlocked("shield_rush") and vk.skill_ready(0):
					tap(h, "skill1")
				else:
					h.move_input = to.normalized() if to.length() > 1.8 else Vector3.ZERO
					tap(h, "light")
					h.move_input = Vector3.ZERO
		elif cls == "mage":
			var el: MageElementalist = h.kit.el
			if incoming and h.stamina > 30.0 and el.cur == null:
				h.move_input = to.normalized().cross(Vector3.UP)
				h.try_dodge()
				h.move_input = Vector3.ZERO
			elif el.cur == null and h.can_act():
				casts += 1
				var slot := "light"
				if h.hp < h.max_hp * 0.6:
					el.set_heal_target(h)
					el.ai_spell = {"heavy": "life_bloom"}
					slot = "heavy"
				elif casts % 3 == 1 and el.spell_known("crystal_formation"):
					el.ai_spell = {"heavy": "crystal_formation"}
					el.ai_aim = r.global_position - to.normalized() * 1.2
					slot = "heavy"
				else:
					el.ai_spell = {"light": "flame_cataclysm"}
				if casts % 4 == 0:
					tap(h, "wheel_primary")    # a tap swap (spell wheel) between casts
				h.press(slot)
				hold_action = slot
				hold = 70
		else:
			var bdk: ReaverBladeDancer = h.kit.bd
			if incoming and h.stamina > 30.0 and not h.dodging:
				h.release("heavy")
				h.move_input = to.normalized().cross(Vector3.UP)
				h.try_dodge()
				h.move_input = Vector3.ZERO
			elif h.can_act() and h.kit.charging == "":
				if to.length() > 3.0:
					h.release("heavy")
					h.move_input = to.normalized()
					tap(h, "light")
					h.move_input = Vector3.ZERO
				else:
					var k := step % 4
					step += 1
					if k == 3:
						if not bdk.in_edge():
							h.press("heavy")
							step -= 1
						else:
							h.press("light")
							hold_action = "light"
							hold = 48 if (step / 4) % 2 == 0 else 2
					else:
						h.release("heavy")
						h.move_input = to.normalized().cross(Vector3.UP) * (1.0 if k == 1 else 0.0)
						tap(h, "light")
						h.move_input = Vector3.ZERO
		h.lock_target = r
		await get_tree().physics_frame
		if h.runner.is_busy() or h.kit.charging != "":
			busy += 1
		m.stamina += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
		var mana_now := _mana(h)
		m.mana += maxf(0.0, last_mana - mana_now)
		last_mana = mana_now
		if h.downed:
			break
	for a in ["guard", "heavy", "light"]:
		h.release(a)
	var tr := 0
	for k in trig_n:
		tr += int(trig_n[k])
	var keys: Array = trig_n.keys()
	keys.sort()
	var line := "S | %-8s | Lv%-2d | %-8s | %-12s | DPS %6.1f | uptime %3d%% | taken %4d%%HP | downed %d | heal %5d | shield %4d | stamina %5d | mana %5d | perfect %2d | dodged %2d | poise breaks %2d | aug triggers %3d (%s)" % [
		cls, level, build, enemy, m.dealt / dur, roundi(100.0 * busy / maxf(1, frames)), roundi(100.0 * m.taken / h.max_hp), m.downed,
		roundi(m.heal_done), roundi(shields), roundi(m.stamina), roundi(m.mana), m.perfect, m.dodge, poise_breaks, tr,
		", ".join(keys.map(func(k): return "%s %d" % [String(k).get_slice("_", 0), int(trig_n[k])]))]
	rows.append(line)
	print(line)
	r.queue_free()