extends "res://tests/level10_runner.gd"
## LEVEL10-FOUNDATION-005 Milestones C / D: path framework, drafts and the 60-card augment pool.
##   godot --headless --fixed-fps 60 res://tests/l10_augment_runner.tscn
## Automated functional checks only (triggers, cooldowns, caps, eligibility, drafts, saves). They do not
## judge fun or balance feel.


func _run_all() -> void:
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.source == Game.player: dmg.append(info))
	Events.augment_triggered.connect(func(o, id, d): trig.append({"owner": o, "id": id, "detail": d}))
	await test_catalog()
	await test_text_from_params()
	await test_eligibility()
	await test_drafts()
	await test_exclusive_and_replacement()
	await test_save_and_reset()
	await test_global_cards()
	await test_reaver_cards()
	await test_vanguard_cards()
	await test_mage_cards()
	await test_no_recursion_and_caps()
	await test_presentation_review()
	await test_fresh_test_route()
	await teardown()


func give(cls: String, id: String) -> void:
	Game.add_augment(cls, id)
	# add_augment refreshes the hero stats: keep crits off so exact values can be compared
	if is_instance_valid(Game.player):
		Game.player.stats.crit_chance = 0.0


func fired(id: String) -> int:
	var n := 0
	for t in trig:
		if t.id == id:
			n += 1
	return n


func recovering(r: Enemy) -> void:
	enemy_swing(r, 0.05, 1.2)
	await wait(0.15)


# ------------------------------------------------------------------ catalog / framework
func test_catalog() -> void:
	print("\n[Catalog: 6 global, 18 class-common, 36 path cards; one anchor per path; blockers reported]")
	var cards: Array = Game.augment_db.all.values().filter(func(a): return a.pool == "l10")
	check(cards.size() == 60, "60 cards in the Level 1-10 pool (%d)" % cards.size())
	var glob := cards.filter(func(a): return a.class_id == "global")
	check(glob.size() == 6, "6 global cards")
	for c in ["vanguard", "mage", "reaver"]:
		var common := cards.filter(func(a): return a.class_id == c and a.path_id == "")
		check(common.size() == 6, "%s: 6 class-common cards" % c)
		for pth in AugmentDB.PATHS[c]:
			var pc := cards.filter(func(a): return a.path_id == pth)
			var anchors := pc.filter(func(a): return a.is_anchor)
			check(pc.size() == 6 and anchors.size() == 1 and anchors[0].group() == "anchor_" + c, "%s: 6 cards, exactly one anchor (group anchor_%s)" % [AugmentDB.PATH_NAMES[pth], c])
	var blocked := cards.filter(func(a): return a.blocked_reason != "")
	check(blocked.size() == 3 and blocked.any(func(a): return a.id == "mf04_healing_ember") and blocked.any(func(a): return a.id == "mf06_purifying_confluence") and blocked.any(func(a): return a.id == "vb05_fortress_breaker"), "3 cards blocked with a reported prerequisite (Healing Ember, Purifying Confluence, Fortress Breaker): 57 playable")
	var meta_ok := true
	for a in cards:
		if a.trigger_summary == "" or a.code == "" or a.description == "":
			meta_ok = false
	check(meta_ok, "every card has code, trigger summary and description (structured metadata)")
	var syn_ok := true
	for a in cards:
		for pid in a.synergy_partners:
			if Game.augment_db.get_augment(pid) == null or String(a.synergy_text.get(pid, "")) == "":
				syn_ok = false
	check(syn_ok, "every synergy partner exists and has its combined-behaviour text")


func test_text_from_params() -> void:
	print("\n[Card text is generated from the card's params (no hard-coded numbers)]")
	var ok := true
	for a in Game.augment_db.all.values():
		if a.pool == "l10" and AugmentText.describe(a).contains("{"):
			ok = false
	check(ok, "no unresolved tokens in any description")
	var g01: AugmentData = Game.augment_db.get_augment("g01_second_wind")
	check(AugmentText.describe(g01).contains("25%") and AugmentText.describe(g01).contains("3s"), "Second Wind text: 25% / 3s from params")
	g01.params["stamina_off"] = 0.3
	check(AugmentText.describe(g01).contains("30%"), "changing the param changes the text (30%)")
	g01.params["stamina_off"] = 0.25
	var ex: AugmentData = Game.augment_db.get_augment("re04_executioners_distance")
	check(AugmentText.describe(ex).contains("+15%") and AugmentText.describe(ex).contains("20%"), "Executioner's Distance: +15% range, 20% narrower")


func test_eligibility() -> void:
	print("\n[Eligibility: class, unlocks, blockers, legacy vs Level 1-10 pool]")
	var h := await bd(4)
	var db: AugmentDB = Game.augment_db
	var rp := Game.prog("reaver")
	check(db.ineligible_reason(db.get_augment("vb01_living_fortress"), rp) == "wrong class", "Vanguard card never offered to the Reaver")
	check(db.ineligible_reason(db.get_augment("rd05_tempest_waltz"), rp).begins_with("requires bd_offense"), "Tempest Waltz needs Whirling Assault (Lv5): not at Lv4")
	check(db.ineligible_reason(db.get_augment("rd04_extended_orbit"), rp) == "", "Extended Orbit eligible at Lv4 (Orbit Step is Lv3)")
	check(db.ineligible_reason(db.get_augment("crosswind"), rp).begins_with("outside"), "legacy Reaver cards are not drafted under Blade Dancer")
	check(db.ineligible_reason(db.get_augment("mf04_healing_ember"), Game.prog("mage")).begins_with("blocked"), "blocked card never eligible")
	var mp := Game.prog("mage")
	Game.mage_core = "elementalist"
	check(db.ineligible_reason(db.get_augment("g04_calculated_risk"), mp).begins_with("not for this class"), "Calculated Risk not offered to the Worldweaver (reported limitation)")
	var vp := Game.prog("vanguard")
	vp.level = 4
	Game.party_mode = true
	check(db.ineligible_reason(db.get_augment("vc03_shared_aegis"), vp).begins_with("requires v_intercept"), "interception cards wait for Interception (Lv7)")
	vp.level = 8
	Game.party_mode = false
	check(db.ineligible_reason(db.get_augment("vc03_shared_aegis"), vp).begins_with("needs a party"), "solo: ally-protection cards are not offered (nothing to protect)")
	Game.party_mode = true
	check(db.ineligible_reason(db.get_augment("vc03_shared_aegis"), vp) == "", "... in party play they are offered from Lv8")
	Game.party_mode = false
	Game.reaver_core = "freeflow"
	check(db.ineligible_reason(db.get_augment("rd01_phantom_footwork"), rp) != "", "Level 1-10 cards stay out of the comparison cores")
	Game.reaver_core = "bladedancer"


func test_drafts() -> void:
	print("\n[Drafts 4 / 8 / 10: both anchors + common at 4; path-favoured at 8; completion at 10; reproducible]")
	var h := await bd(4)
	var rng := RandomNumberGenerator.new()
	for cls in ["reaver", "vanguard", "mage"]:
		if cls == "mage":
			Game.mage_core = "elementalist"
		var p := Game.prog(cls)
		p.level = 4
		p.augments.clear()
		rng.seed = 11
		var d4: Array = Game.augment_db.roll_l10(cls, p, 4, rng)
		var anchors := d4.filter(func(a): return a.is_anchor)
		var paths := {}
		for a in anchors:
			paths[a.path_id] = true
		var common := d4.filter(func(a): return a.path_id == "" and a.class_id == cls)
		check(d4.size() == 3 and anchors.size() == 2 and paths.size() == 2 and common.size() == 1, "%s Lv4: one anchor of each path + one class-common card (%s)" % [cls, ", ".join(d4.map(func(a): return a.display_name))])
		rng.seed = 11
		var again: Array = Game.augment_db.roll_l10(cls, p, 4, rng)
		check(again.map(func(a): return a.id) == d4.map(func(a): return a.id), "%s: same seed, same draft (reproducible)" % cls)
	# Lv8 with the Dance anchor owned
	var rp := Game.prog("reaver")
	rp.level = 8
	rp.augments.clear()
	rp.augments.append("rd01_phantom_footwork")
	var ok8 := true
	var dance8 := 0
	for s in 20:
		rng.seed = 100 + s
		var d8: Array = Game.augment_db.roll_l10("reaver", rp, 8, rng)
		if d8.size() != 3 or d8.any(func(a): return a.is_anchor or a.id == "rd01_phantom_footwork"):
			ok8 = false
		dance8 += d8.filter(func(a): return a.path_id == "dance").size()
	check(ok8, "Lv8 with Phantom Footwork: 3 cards, never the opposite anchor, never a duplicate (20 seeds)")
	check(dance8 >= 30, "Lv8 favours the chosen Dance path (%d of 60 offers)" % dance8)
	rp.augments.clear()
	rng.seed = 5
	var d8n: Array = Game.augment_db.roll_l10("reaver", rp, 8, rng)
	check(d8n.filter(func(a): return a.is_anchor).size() == 2, "Lv8 with no path yet: both anchors offered again")
	rp.level = 10
	rp.augments.assign(["rd02_flowing_steps", "rc02_swordsmans_breath"])
	var ok10 := true
	var syn10 := 0
	for s in 20:
		rng.seed = 300 + s
		var d10: Array = Game.augment_db.roll_l10("reaver", rp, 10, rng)
		if d10.size() != 3 or d10.any(func(a): return rp.augments.has(a.id) or Game.augment_db.ineligible_reason(a, rp) != ""):
			ok10 = false
		if d10.any(func(a): return Game.augment_db.synergy_text(a, rp) != ""):
			syn10 += 1
	check(ok10, "Lv10: always 3 legitimate, non-owned, eligible cards")
	check(syn10 >= 15, "Lv10 prioritises synergy completion (%d / 20 drafts offer a synergy)" % syn10)
	rp.augments.clear()
	# Game.roll_draft uses the track's draft level
	rp.drafts_taken = 0
	check(Game.draft_level("reaver") == 4, "first draft = Lv4 milestone")
	rp.drafts_taken = 2
	check(Game.draft_level("reaver") == 10, "third draft = Lv10 milestone")
	rp.drafts_taken = 0


func test_exclusive_and_replacement() -> void:
	print("\n[Exclusive anchors / transformations; safe replacement keeps the benched card]")
	var h := await bd(10)
	var rp := Game.prog("reaver")
	rp.augments.clear()
	give("reaver", "rd01_phantom_footwork")
	check(Game.augment_db.ineligible_reason(Game.augment_db.get_augment("re01_perfect_draw"), rp).begins_with("excluded by"), "owning one Reaver anchor excludes the other")
	give("reaver", "re01_perfect_draw")
	check(rp.augment_stacks("re01_perfect_draw") == 0, "add_augment refuses the conflicting anchor")
	rp.augments.append("twin_tempest")
	check(Game.augment_db.ineligible_reason(Game.augment_db.get_augment("re05_twin_verdict"), rp).begins_with("excluded by"), "Twin Verdict excluded while the legacy Twin Tempest transformation is owned")
	rp.augments.erase("twin_tempest")
	give("reaver", "rd03_circling_predator")
	check(Game.dependents_of("reaver", "rd01_phantom_footwork").is_empty(), "a rule-only pair (Phantom Footwork / Circling Predator) is not announced as a lost synergy")
	rp.augments.append("rd02_flowing_steps")
	rp.augments.append("rd05_tempest_waltz")
	check(Game.dependents_of("reaver", "rd02_flowing_steps").has("Tempest Waltz"), "benching a card warns about its MECHANICAL synergy partner")
	rp.augments.erase("rd02_flowing_steps")
	rp.augments.erase("rd05_tempest_waltz")
	rp.pending_drafts = 1
	rp.pending_draft_tiers = ["exotic"]
	var dt := rp.drafts_taken
	Game.choose_augment_replacing("reaver", "re01_perfect_draw", "rd01_phantom_footwork")
	check(rp.augments.has("rd01_phantom_footwork") and rp.augment_stacks("rd01_phantom_footwork") == 0, "benched card stays OWNED but inactive (never deleted)")
	check(rp.augment_stacks("re01_perfect_draw") == 1 and rp.drafts_taken == dt + 1 and rp.pending_drafts == 0, "the new card uses the draft (no free pick, no extra draft)")
	var active := 0
	for id in rp.augments:
		if rp.augment_stacks(id) > 0:
			active += 1
	check(active == 2, "no extra active slot: %d active after replacing" % active)
	rp.augments.clear()
	rp.inactive_mutations.clear()


func test_save_and_reset() -> void:
	print("\n[Save / reload keeps cards, benched state and the Crossroads choice; death resets]")
	var p := ClassProgress.new("mage")
	p.level = 8
	p.augments.assign(["mf01_elemental_crossroads", "mc02_gentle_current"])
	p.inactive_mutations.assign(["mc02_gentle_current"])
	p.crossroads_choice = "shattered_winter"
	var q := ClassProgress.new("mage")
	q.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check(q.augments.size() == 2 and q.inactive_mutations.has("mc02_gentle_current") and q.crossroads_choice == "shattered_winter", "round trip through JSON")
	var old := ClassProgress.new("mage")
	var d := p.to_dict()
	d.erase("crossroads_choice")
	old.from_dict(d)
	check(old.crossroads_choice == "", "old saves without the new key load (default choice)")
	q.reset()
	check(q.augments.is_empty() and q.crossroads_choice == "" and q.level == 1, "death / reset clears the build")


# ------------------------------------------------------------------ global
func test_global_cards() -> void:
	print("\n[Global cards: Second Wind, Measured Recovery, Echoing Impact, Calculated Risk, Near Miss, Resolute Spirit]")
	var h := await bd(10)
	var r := target(h)
	place(h, r, 1.6)
	# G01: empty dodge does nothing; dodging a real attack discounts the next action
	give("reaver", "g01_second_wind")
	h.try_dodge()
	await until_idle(h)
	check(not h.rt.active("g01"), "G01: an empty dodge does not trigger")
	refill(h)
	h.try_dodge()
	await wait(0.08)
	enemy_hit(h, r)
	check(h.rt.active("g01"), "G01: dodging a real attack opens the discount")
	await until_idle(h)
	refill(h)
	var st0 := h.stamina
	await act(h, "light")
	var d := load("res://data/attacks/bd_dance_neutral.tres") as AttackData
	check(absf((st0 - h.stamina) - (d.stamina_cost * 0.75 - ReaverBladeDancer.STAMINA_REFUND)) < 0.6 or absf((st0 - h.stamina) - d.stamina_cost * 0.75) < 0.6, "G01: next attack costs 75%% (%.2f spent of %.0f)" % [st0 - h.stamina, d.stamina_cost])
	check(not h.rt.active("g01"), "G01: consumed by one action")
	# G02: recovering enemy -> +5 stamina, ICD 5s
	give("reaver", "g02_measured_recovery")
	refill(h)
	h.stamina = 50.0
	place(h, r, 1.6)
	await recovering(r)
	await act(h, "light")
	check(fired("g02_measured_recovery") == 1, "G02: hit during real recovery restores stamina")
	place(h, r, 1.6)
	await recovering(r)
	await act(h, "light")
	check(fired("g02_measured_recovery") == 1, "G02: internal cooldown (no second refund within 5s)")
	# G03: third separate action -> one echo at 25%, no echo of the echo
	give("reaver", "g03_echoing_impact")
	h.rt.cds.clear()
	dmg.clear()
	for i in 3:
		place(h, r, 1.6)
		await act(h, "light")
		refill(h)
	await wait(0.6)
	var echoes := dmg.filter(func(x): return x.attack_name == "Echoing Impact")
	var hits := dmg.filter(func(x): return x.attack != null)
	check(echoes.size() == 1 and absf(echoes[0].raw_amount - hits[2].raw_amount * 0.25) < 0.05, "G03: the 3rd action echoes once for 25%% (%.1f of %.1f)" % [echoes[0].raw_amount if echoes.size() > 0 else -1.0, hits[2].raw_amount if hits.size() > 2 else -1.0])
	check(echoes.size() == 1 and echoes[0].tags.get(AugmentRuntime.SECONDARY, false), "G03: the echo is tagged secondary (cannot trigger augments)")
	# G04: committed actions only, +20% damage, miss -> +20% recovery
	give("reaver", "g04_calculated_risk")
	h.stats.crit_chance = 0.0
	place(h, r, 1.6)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	h.press("light")
	await wait(0.8)
	h.release("light")
	await wait(0.02)
	await until_idle(h)
	var full := ReaverBladeDancer.committed_attack(load("res://data/attacks/bd_committed.tres"), 1.0)
	var base := DamageCalc.for_combatant(h, full, {}, r)
	var ci := hit_on(r)
	check(ci != null and absf(ci.raw_amount - float(base.noncrit) * 1.2) < 0.05, "G04: Committed Cut x1.2 (%.1f vs base %.1f)" % [ci.raw_amount if ci else -1.0, base.noncrit])
	h.release("heavy")
	await wait(0.3)
	dmg.clear()
	place(h, r, 1.6)
	await act(h, "light")
	var dn := hit_on(r)
	var nb := DamageCalc.for_combatant(h, load("res://data/attacks/bd_dance_neutral.tres"), {}, r)
	check(dn != null and absf(dn.raw_amount - float(nb.noncrit)) < 0.05, "G04: untagged Dance attacks unchanged")
	refill(h)
	r.global_position += Vector3(0, 0, -8)
	h.press("heavy")
	await wait(0.05)
	h.press("light")
	await wait(0.8)
	h.release("light")
	await wait(0.4)
	var rec: float = h.runner.data.recovery if h.runner.is_busy() else -1.0
	check(absf(rec - full.recovery * 1.2) < 0.02, "G04: a missed Committed Cut recovers 20%% longer (%.2f vs %.2f)" % [rec, full.recovery])
	await until_idle(h)
	h.release("heavy")
	r.global_position += Vector3(0, 0, 8)
	# G06: recovering from Stagger
	give("reaver", "g06_resolute_spirit")
	h.stagger(0.3)
	await wait(0.4)
	check(h.statuses.has("resolute_spirit") and absf(h.statuses.mult("poise_taken") - 0.8) < 0.001, "G06: after Stagger, Poise taken x0.8")
	# G05: near miss by moving vs dodge
	give("reaver", "g05_near_miss")
	var e := dummy("raider", h.global_position + Vector3(0, 0, -2.0))
	e.target = h
	face(e, h)
	var atk := load("res://data/attacks/raider_heavy.tres") as AttackData
	h.velocity = Vector3(4, 0, 0)
	e.runner.targets_hit = {}
	AugmentRuntime.enemy_attack_resolved(e, atk, {})
	check(h.statuses.has("near_miss") and absf(h.statuses.mult("move_speed") - 1.15) < 0.001, "G05: moving through the reach of a missed attack: +15% speed")
	h.statuses.remove("near_miss")
	h.rt.cds.clear()
	AugmentRuntime.enemy_attack_resolved(e, atk, {h.get_instance_id(): h})
	check(not h.statuses.has("near_miss"), "G05: not when the attack actually hit")
	h.velocity = Vector3.ZERO
	AugmentRuntime.enemy_attack_resolved(e, atk, {})
	check(not h.statuses.has("near_miss"), "G05: standing still is not a near miss")
	h.last_dodge_end = Game.time
	h.velocity = Vector3(4, 0, 0)
	AugmentRuntime.enemy_attack_resolved(e, atk, {})
	check(not h.statuses.has("near_miss"), "G05: a dodge never counts")


# ------------------------------------------------------------------ Reaver
func test_reaver_cards() -> void:
	print("\n[Reaver cards: common, Dance Mastery, Edge Mastery]")
	var h := await bd(10)
	var r := target(h)
	h.stats.crit_chance = 0.0
	# R-C02 Swordsman's Breath + R-C06 Clean Execution
	give("reaver", "rc02_swordsmans_breath")
	give("reaver", "rc06_clean_execution")
	place(h, r, 1.8)
	await recovering(r)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	h.stamina = 50.0
	tap(h, "light")
	await until_idle(h)
	var pc := hit_on(r)
	var pb := DamageCalc.for_combatant(h, load("res://data/attacks/bd_precision.tres"), {}, r)
	check(pc != null and absf(pc.poise - float(pb.poise) * 1.25) < 0.05, "R-C06: Precision Cut on a recovering enemy +25%% Poise (%.1f vs %.1f)" % [pc.poise if pc else -1.0, pb.poise])
	check(fired("rc02_swordsmans_breath") == 1, "R-C02: connecting Precision Cut restores stamina (once)")
	h.release("heavy")
	await wait(0.3)
	# R-E04 Executioner's Distance hitbox
	give("reaver", "re04_executioners_distance")
	var d := (load("res://data/attacks/bd_precision.tres") as AttackData).clone()
	h.rt.bd_precision(d)
	var b0 := load("res://data/attacks/bd_precision.tres") as AttackData
	check(absf(d.hitbox_size.z - b0.hitbox_size.z * 1.15) < 0.001 and absf(d.hitbox_size.x - b0.hitbox_size.x * 0.8) < 0.001, "R-E04: Precision range x1.15, width x0.8")
	# R-E05 Twin Verdict + R-E06 Patient Blade
	h.prog().augments.erase("re04_executioners_distance")
	give("reaver", "re05_twin_verdict")
	give("reaver", "re06_patient_blade")
	refill(h)
	place(h, r, 1.6)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	h.press("light")
	await wait(0.8)
	h.release("light")
	await wait(0.02)
	var tv_name: String = h.runner.data.display_name
	var st_before := h.stamina
	await until_idle(h)
	var tv := dmg.filter(func(x): return x.target == r and x.attack != null)
	var full := ReaverBladeDancer.committed_attack(load("res://data/attacks/bd_committed.tres"), 1.0)
	var single := DamageCalc.for_combatant(h, full, {}, r)
	var tot := 0.0
	for x in tv:
		tot += x.raw_amount
	check(tv_name == "Twin Verdict" and tv.size() == 2, "R-E05: two committed impacts")
	check(tv.size() == 2 and absf(tv[0].raw_amount / tot - 0.4) < 0.01 and absf(tot - float(single.noncrit)) < 0.1, "R-E05: 40 / 60 split, total unchanged (%.1f vs %.1f)" % [tot, single.noncrit])
	check(fired("re06_patient_blade") == 1, "R-E06: refund once for the whole committed action")
	h.release("heavy")
	await wait(0.3)
	# R-E01 Perfect Draw: inside / outside the window
	h.prog().augments.erase("re05_twin_verdict")
	h.prog().augments.erase("re06_patient_blade")
	give("reaver", "re01_perfect_draw")
	var cd := ReaverBladeDancer.committed_attack(load("res://data/attacks/bd_committed.tres"), 1.0)
	var t1 := cd.clone()
	h.rt.bd_committed(t1, 0.80, "")
	var t2 := cd.clone()
	h.rt.bd_committed(t2, 0.95, "")
	check(absf(t1.recovery - cd.recovery * 0.8) < 0.001 and absf(t2.recovery - cd.recovery) < 0.001 and is_equal_approx(t1.damage_mult, cd.damage_mult), "R-E01: released 0.05s after full charge -> recovery x0.8; 0.2s late -> normal; damage unchanged")
	# R-E02 Steel Focus
	give("reaver", "re02_steel_focus")
	h.press("heavy")
	await wait(0.05)
	h.press("light")
	await wait(0.2)
	var inf := DamageInfo.new()
	inf.source = r
	inf.poise = 10.0
	inf.amount = 1.0
	inf.source_pos = r.global_position
	h.rt.modify_incoming(inf)
	check(absf(inf.poise - 8.0) < 0.001, "R-E02: Poise taken x0.8 while charging Committed Cut")
	h.release("heavy")
	h.release("light")
	await until_idle(h)
	await wait(0.3)
	# R-E03 Fracturing Edge: Breaking Point vs recovering, narrower
	give("reaver", "re03_fracturing_edge")
	var bk := (load("res://data/attacks/bd_break.tres") as AttackData).clone()
	h.rt.bd_technique("bd_break", bk)
	check(absf(bk.hitbox_size.x - (load("res://data/attacks/bd_break.tres") as AttackData).hitbox_size.x * 0.85) < 0.001, "R-E03: Breaking Point width x0.85")
	var pi := DamageInfo.new()
	pi.poise = 10.0
	await recovering(r)
	h.rt.modify_outgoing(pi, bk, r, 0, {"kind": "break"})
	check(absf(pi.poise - 13.0) < 0.001, "R-E03: +30% Poise vs a recovering enemy")
	var ci2 := DamageInfo.new()
	ci2.poise = 10.0
	h.rt.modify_outgoing(ci2, load("res://data/attacks/bd_precision.tres"), r, 0, {"kind": "precision"})
	check(absf(ci2.poise - 12.5) < 0.001 or absf(ci2.poise - 10.0) < 0.001, "R-C06 on its own per-target cooldown")
	# R-D01 Phantom Footwork (anchor) - Edge anchor removed first
	h.prog().augments.assign(["rd01_phantom_footwork"])
	refill(h)
	place(h, r, 2.0)
	await wait(0.2)
	var p0 := h.global_position
	var to := r.global_position - h.global_position
	to.y = 0
	var right := to.normalized().cross(Vector3.UP)
	await act(h, "light", right)
	var path := flat_v(h.global_position - p0)
	check(path >= 0.95 and absf(flat(h, r) - 2.0) < 0.3, "R-D01: curved lateral step %.2fm, radius kept (%.2fm)" % [path, flat(h, r)])
	# R-D04 Extended Orbit
	give("reaver", "rd04_extended_orbit")
	check(absf(bk_angle(h) - ReaverBladeDancer.ORBIT_ANGLE * 1.2) < 0.01, "R-D04: Orbit Step target angle x1.2 (%.0f deg)" % bk_angle(h))
	var ob := (load("res://data/attacks/bd_orbit.tres") as AttackData).clone()
	var r0 := ob.recovery
	h.rt.bd_technique("bd_orbit", ob)
	check(absf(ob.recovery - r0 * 1.15) < 0.001, "R-D04: +15% movement commitment")
	# R-D05 Tempest Waltz
	give("reaver", "rd05_tempest_waltz")
	var wa := (load("res://data/attacks/bd_whirl.tres") as AttackData).clone()
	var md := wa.move_during
	h.rt.bd_technique("bd_whirl", wa)
	check(absf(wa.move_during - md * 1.15) < 0.001 and wa.hits == 4 and is_equal_approx(wa.damage_mult, 2.2), "R-D05: +15% movement, still 4 hits and the same damage")
	# R-D02 Flowing Steps / R-C05 Blade Reflex / R-D06 Dancer's Reversal via a real side dodge
	give("reaver", "rd02_flowing_steps")
	give("reaver", "rc05_blade_reflex")
	give("reaver", "rd06_dancers_reversal")
	h.rt.cds.clear()
	refill(h)
	place(h, r, 2.0)
	h.move_input = right
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await wait(0.08)
	enemy_hit(h, r)
	check(h.rt.active("rd02") and h.rt.active("rc05") and h.rt.active("rd06"), "real side dodge readies Flowing Steps, Blade Reflex and Dancer's Reversal")
	await until_idle(h)
	tap(h, "light")
	await wait(0.03)
	check(bk(h).last_attack == "reflex" and h.runner.data.display_name == "Reflex Cut", "R-C05: next LMB is the Reflex follow-up (Dance)")
	await until_idle(h)
	refill(h)
	var st1 := h.stamina
	var to3 := r.global_position - h.global_position
	to3.y = 0
	h.move_input = to3.normalized().cross(Vector3.UP)
	tap(h, "light")
	await wait(0.03)
	h.move_input = Vector3.ZERO
	check(h.runner.data.display_name.begins_with("Reversal"), "R-D06: next directional Dance is the turning follow-up")
	check(absf((st1 - h.stamina) - 5.0 * 0.75) < 0.01, "R-D02: and costs 25%% less stamina (%.2f)" % (st1 - h.stamina))
	await until_idle(h)
	# R-C01 Seamless Steel
	h.prog().augments.assign(["rc01_seamless_steel"])
	h.rt.cds.clear()
	refill(h)
	place(h, r, 1.6)
	await act(h, "light")
	h.press("heavy")
	await wait(0.05)
	tap(h, "light")
	await wait(0.02)
	check(h.runner.data.display_name.begins_with("Seamless") and absf(h.runner.data.startup - 0.18 * 0.8) < 0.001, "R-C01: Precision after a Dance hit starts 20% sooner (mobile transition)")
	await until_idle(h)
	h.release("heavy")
	await wait(0.3)
	# R-C03 Measured Blade
	h.prog().augments.assign(["rc03_measured_blade"])
	h.rt.cds.clear()
	refill(h)
	await recovering(r)
	place(h, r, 1.6)
	await act(h, "light")
	check(h.rt.active("rc03"), "R-C03: hitting a recovering enemy arms the faster recovery")
	tap(h, "light")
	await wait(0.03)
	var dl := load("res://data/attacks/bd_dance_neutral.tres") as AttackData
	check(absf(h.runner.data.recovery - dl.recovery * 0.85) < 0.001, "R-C03: next attack recovery x0.85")
	await until_idle(h)
	# R-C04 Close Pursuit
	h.prog().augments.assign(["rc04_close_pursuit"])
	refill(h)
	place(h, r, 1.6)
	await act(h, "light")
	place(h, r, 3.0)
	h.rt.open("rc04", 3.0, {"target": r})
	var ex := {}
	var dfw := (load("res://data/attacks/bd_dance_forward.tres") as AttackData).clone()
	h.rt.bd_dance("forward", dfw, ex)
	check(absf(float(ex.get("travel_mult", 1.0)) - 1.2) < 0.001, "R-C04: Forward Dance toward a target 3.0m away travels +20%")
	h.rt.open("rc04", 3.0, {"target": r})
	place(h, r, 1.6)
	var ex2 := {}
	h.rt.bd_dance("forward", dfw, ex2)
	check(not ex2.has("travel_mult"), "R-C04: no bonus when the target is still in range")
	# R-D03 Circling Predator: flank hit after a real lateral move
	h.prog().augments.assign(["rd03_circling_predator"])
	h.rt.cds.clear()
	refill(h)
	r.face_dir(Vector3(0, 0, 1))
	h.global_position = r.global_position + Vector3(2.0, 0, 0.3)
	h.lock_target = r
	face(h, r)
	await wait(0.1)
	var to2 := r.global_position - h.global_position
	to2.y = 0
	await act(h, "light", to2.normalized().cross(Vector3.UP))
	check(h.rt.active("rd03"), "R-D03: flank hit after a lateral step readies the Predator Cut")
	dmg.clear()
	tap(h, "light")
	await wait(0.03)
	check(bk(h).last_attack == "predator" and absf(h.runner.data.damage_mult - (load("res://data/attacks/bd_dance_lateral.tres") as AttackData).damage_mult * 0.85) < 0.001, "R-D03: Predator Cut = 85% damage")
	await until_idle(h)
	h.prog().augments.clear()


func bk_angle(h: Hero) -> float:
	return (h.kit as ReaverKit).bd.orbit_angle()


# ------------------------------------------------------------------ Vanguard
func vg(level: int) -> Hero:
	var h := await setup("vanguard", false, false, false)
	Game.set_level("vanguard", level)
	Game.prog("vanguard").pending_drafts = 0
	Game.prog("vanguard").pending_draft_tiers.clear()
	await wait(0.2)
	h.refresh_stats(true)
	h.restore_all()
	h.stats.crit_chance = 0.0
	for c in h.get_children():
		if c is PlayerBrain:
			c.set_physics_process(false)
	return h


func guard_now(h: Hero) -> void:
	h.press("guard")
	await wait(0.05)


func test_vanguard_cards() -> void:
	print("\n[Vanguard cards: Guard, protection and counters in both paths]")
	var h := await vg(10)
	var vk: VanguardKit = h.kit
	var r := dummy("raider", h.global_position + Vector3(0, 0, -1.8))
	r.max_hp = 99999
	r.hp = 99999
	face(r, h)
	face(h, r)
	h.lock_target = r
	# V-C04 / V-B04 guard movement
	give("vanguard", "vc04_unyielding_footing")
	await guard_now(h)
	check(absf(vk.move_mult() - Game.balance.guard_move_mult * 1.15) < 0.001, "V-C04: Guard movement x1.15")
	give("vanguard", "vb04_heavy_anchor")
	check(absf(vk.move_mult() - Game.balance.guard_move_mult * 1.15 * 0.9) < 0.001, "V-B04: Guard movement x0.9 more")
	var pi := DamageInfo.new()
	pi.source = r
	pi.poise = 10.0
	pi.source_pos = r.global_position
	h.rt.modify_incoming(pi)
	check(absf(pi.poise - 8.0) < 0.001, "V-B04: Poise taken x0.8 while guarding")
	# V-B01 Living Fortress
	give("vanguard", "vb01_living_fortress")
	h.move_input = h.forward()
	check(absf(vk.move_mult() - 0.6) < 0.001 and absf(vk.stamina_regen_mult() - 0.35 * 0.7) < 0.001, "V-B01: forward in Guard at 60% speed; Guard stamina recovery -30%")
	h.move_input = -h.forward()
	check(vk.move_mult() < 0.6, "V-B01: only FORWARD steps are faster")
	h.move_input = Vector3.ZERO
	h.release("guard")
	await wait(0.4)
	# V-C02 Steel Foundation + V-B05 Fortress Breaker (with Heavy Anchor synergy) + V-C06 Last Barrier
	give("vanguard", "vc02_steel_foundation")
	give("vanguard", "vb05_fortress_breaker")
	give("vanguard", "vc06_last_barrier")
	h.hp = h.max_hp * 0.3
	h.press("guard")
	await wait(0.5)
	var heavy := enemy_hit(h, r, "raider_heavy")
	heavy.is_heavy = true
	var info := DamageInfo.new()
	info.source = r
	info.attack = load("res://data/attacks/raider_heavy.tres")
	info.amount = 20.0
	info.raw_amount = 20.0
	info.is_heavy = true
	info.source_pos = r.global_position
	h.rt.cds.erase("vb05_cd")
	h.take_damage(info)
	check(info.guarded and h.rt.active("vc02"), "V-C02: a successful Guard arms the knockback reduction")
	check(not h.rt.active("vb05") and not h.rt.has("vb05_fortress_breaker"), "V-B05 is blocked (no heavy enemy attacks): never active even when owned")
	check(h.has_shield() and fired("vc06_last_barrier") >= 1, "V-C06: Guard below 35% HP grants the shield")
	var kb := DamageInfo.new()
	kb.knockback = 4.0
	kb.source_pos = r.global_position
	h.rt.modify_incoming(kb)
	check(absf(kb.knockback - 2.8) < 0.001, "V-C02: next hit knockback x0.7")
	h.release("guard")
	await wait(0.3)
	var pc := DamageInfo.new()
	pc.poise = 10.0
	h.rt.modify_outgoing(pc, load("res://data/attacks/v_counter.tres"), r, 0, {"counter": true})
	check(absf(pc.poise - 10.0) < 0.001, "no hidden Poise bonus from the blocked card")
	# Counterguard: V-K01 / V-K02 / V-K05 / V-K04
	h.prog().augments.assign(["vk01_aegis_reversal", "vk02_precise_defense", "vk05_judgment_echo", "vk04_retaliation_window"])
	h.rt.cds.clear()
	h.rt.windows.clear()
	h.hp = h.max_hp
	vk.guard_release_time = -10.0
	h.press("guard")
	await wait(0.03)
	var pg := DamageInfo.new()
	pg.source = r
	pg.attack = load("res://data/attacks/raider_heavy.tres")
	pg.amount = 10.0
	pg.raw_amount = 10.0
	pg.source_pos = r.global_position
	h.take_damage(pg)
	check(pg.perfect and h.rt.active("vk01") and h.rt.active("vk02"), "Perfect Guard opens Aegis Reversal and Precise Defense")
	check(absf(h.rt.perfect_window_bonus() - 0.03) < 0.0001, "V-K02: next Perfect Guard window +0.03s")
	h.release("guard")
	await wait(0.05)
	dmg.clear()
	h.press("heavy")
	h.release("heavy")
	await wait(0.03)
	check(h.runner.data.display_name == "Aegis Reversal" and h.runner.ctx.get("reversal", false), "V-K01: the Heavy became the Reversal counter")
	var hv := load("res://data/attacks/v_heavy.tres") as AttackData
	check(absf(h.runner.data.hitbox_size.z - hv.hitbox_size.z * 0.9) < 0.001, "V-K01: -10% reach")
	await until_idle(h)
	var rh := hit_on(r)
	var base := DamageCalc.for_combatant(h, hv, {}, r)
	check(rh != null and absf(rh.poise - float(base.poise) * 1.3) < 0.1, "V-K01: +30%% Poise (%.1f vs %.1f)" % [rh.poise if rh else -1.0, base.poise])
	check(h.rt.active("vk05"), "V-K05: a connecting counter opens the Echo Strike")
	dmg.clear()
	tap(h, "light")
	await wait(0.03)
	check(h.runner.data.display_name == "Echo Strike" and h.runner.data.anim_style == "rising", "V-K05 + V-K01 synergy: Echo Strike uses the alternate animation after a Reversal")
	var vc := load("res://data/attacks/v_counter.tres") as AttackData
	check(absf(h.runner.data.damage_mult - vc.damage_mult * 0.65) < 0.001 and absf(h.runner.data.recovery - vc.recovery * 1.2) < 0.001, "V-K05: 65% damage, +20% recovery")
	await until_idle(h)
	# V-K04: guard may return 20% earlier after a connecting counter (same conditions with / without)
	var times: Array = []
	for with_card in [false, true]:
		h.prog().augments.assign(["vk04_retaliation_window"] if with_card else [])
		h.rt.windows.clear()
		vk.counter_until = Game.time + 1.0
		place_v(h, r)
		await wait(0.1)
		tap(h, "light")
		h.press("guard")
		var raised := -1.0
		var t0 := Game.time
		for i in 90:
			await get_tree().physics_frame
			if vk.guarding and raised < 0.0:
				raised = Game.time - t0
		times.append(raised)
		h.release("guard")
		await wait(0.4)
	check(times[1] > 0.0 and times[1] < times[0] - 0.03, "V-K04: Guard back at %.2fs instead of %.2fs after a connecting counter" % [times[1], times[0]])
	# interception family: V-C01 / V-C03 / V-C05 / V-B06 / V-K06 (simulated successful interception)
	h.prog().augments.assign(["vc01_guardians_reach", "vc03_shared_aegis", "vc05_defenders_oath", "vb06_sheltering_counter", "vk06_guardians_retort"])
	h.rt.cds.clear()
	h.rt.windows.clear()
	check(absf(h.rt.intercept_range_mult() - 1.2) < 0.001, "V-C01: interception range x1.2")
	var ally: Hero = Game.spawn_hero("reaver", h.global_position + Vector3(2.0, 0, 0), false)
	await wait(0.2)
	var blow := DamageInfo.new()
	blow.source = r
	blow.target = ally
	blow.amount = 30.0
	blow.raw_amount = 30.0
	blow.source_pos = r.global_position
	check(vk.try_intercept(blow, ally), "(interception succeeded)")
	check(ally.has_shield() and absf(ally.shield_hp - h.max_hp * 0.06) < 0.5, "V-C03: ally shield = 6%% of the Vanguard's max HP (%d)" % roundi(ally.shield_hp))
	check(ally.get_meta("oath_guard", null) == h, "V-C05: Defender's Oath active on the ally")
	var hp_v := h.hp
	var oath := DamageInfo.new()
	oath.source = r
	oath.amount = 40.0
	oath.raw_amount = 40.0
	oath.source_pos = r.global_position
	AugmentRuntime.oath_split(ally, oath)
	check(absf(oath.amount - 30.0) < 0.01 and h.hp < hp_v, "V-C05: 25% of the ally's hit goes to the Vanguard (who really takes it)")
	var hp_v2 := h.hp
	var again := DamageInfo.new()
	again.amount = 40.0
	again.tags["oath"] = true
	AugmentRuntime.oath_split(ally, again)
	check(again.amount == 40.0 and h.hp == hp_v2, "V-C05: redirected damage never redirects again")
	ally.shield_hp = 0.0
	vk.counter_until = Game.time + 1.0
	place_v(h, r)
	tap(h, "light")
	await until_idle(h)
	check(ally.has_shield() and fired("vb06_sheltering_counter") >= 1 and fired("vk06_guardians_retort") >= 1, "V-B06 / V-K06: a counter right after protecting shields the ally")
	check(ally.shield_hp <= maxf(h.max_hp * 0.05, ally.max_hp * 0.08) + 0.5, "shields from both cards do not stack beyond the larger one")
	ally.queue_free()
	h.prog().augments.clear()


func place_v(h: Hero, r: Enemy) -> void:
	h.global_position = r.global_position + Vector3(0, 0, 1.6)
	h.velocity = Vector3.ZERO
	face(h, r)


# ------------------------------------------------------------------ Worldweaver
func test_mage_cards() -> void:
	print("\n[Worldweaver cards: healing support in both paths, preparation, interactions]")
	var h := await ww(10)
	var el: MageElementalist = h.kit.el
	var r := dummy("raider", h.global_position + Vector3(0, 0, -4))
	r.max_hp = 99999
	r.hp = 99999
	var ally: Hero = Game.spawn_hero("vanguard", h.global_position + Vector3(2, 0, 0), false)
	await wait(0.2)
	# M-C02 Gentle Current / M-C06 Woven Protection / M-C04 Benevolent Casting / M-C05 Dual Invocation
	h.prog().augments.assign(["mc02_gentle_current", "mc06_woven_protection", "mc04_benevolent_casting", "mc05_dual_invocation"])
	ally.hp = ally.max_hp * 0.3
	h.kit.heal_target(ally, ally.max_hp, "test heal")
	check(ally.statuses.has("gentle_current") and absf(ally.statuses.mult("move_speed") - 1.1) < 0.001, "M-C02: effective heal -> +10% speed")
	check(ally.has_shield() and ally.shield_hp <= ally.max_hp * 0.06 + 0.01, "M-C06: overheal -> shield capped at 6%% max HP (%d)" % roundi(ally.shield_hp))
	check(h.rt.active("mc04") and h.rt.active("mc05_off"), "M-C04 / M-C05: heal on an ally below 40% opens the support discount and the offensive preparation window")
	var lb: ChargedSpellData = el.spells.life_bloom
	check(absf(h.rt.mana_mult(lb) - 0.85) < 0.001 and not h.rt.active("mc04"), "M-C04: next support spell -15% mana, consumed")
	var fc: ChargedSpellData = el.spells.flame_cataclysm
	var mods := h.rt.charge_mods(fc)
	check(absf(float(mods.full) - 0.85) < 0.001, "M-C05: next offensive spell prepares 15% faster")
	ally.hp = ally.max_hp
	ally.statuses.clear()
	h.kit.heal_target(ally, 50.0, "pure overheal")
	check(not ally.statuses.has("gentle_current"), "M-C02: pure overheal does not trigger")
	# M-C03 Elemental Memory
	h.prog().augments.assign(["mc03_elemental_memory"])
	Events.spell_released.emit(h, "flame_cataclysm", "fire", false, 0.5, 10.0)
	check(absf(h.rt.mana_mult(fc) - 1.0) < 0.001, "M-C03: repeating the same element gives nothing")
	Events.spell_released.emit(h, "glacial_spear", "frost", false, 0.5, 10.0)
	check(absf(h.rt.mana_mult(fc) - 0.88) < 0.001, "M-C03: returning to Fire within 6s: -12% mana")
	# M-C01 Merciful Conduit
	h.prog().augments.assign(["mc01_merciful_conduit"])
	ally.hp = ally.max_hp * 0.5
	var hp0 := ally.hp
	var sd: DamageInfo = h.spell_damage(r, 2.0, 0.0, "test spell")
	check(ally.hp > hp0 and ally.hp - hp0 <= ally.max_hp * 0.08 + 0.01 and absf((ally.hp - hp0) - minf(sd.final_amount * 0.12, ally.max_hp * 0.08)) < 0.5, "M-C01: 12% of the damage heals the most injured ally (cap 8%)")
	var hp1 := ally.hp
	h.spell_damage(r, 2.0, 0.0, "test spell")
	check(ally.hp == hp1, "M-C01: once every 8s")
	# M-F01 Crossroads + M-F03 Thermal Fracture (caps)
	h.prog().augments.assign(["mf01_elemental_crossroads", "mf03_thermal_fracture"])
	check(absf(h.rt.interaction_mult("thermal_fracture") - 1.2) < 0.001 and absf(h.rt.interaction_mult("shattered_winter") - 1.0) < 0.001, "M-F01: only the chosen interaction is enhanced (+20%)")
	check(absf(h.rt.thermal_poise_mult(r) - 1.4) < 0.001, "M-F01 + M-F03: Fire/Frost Poise bonus capped at +40%")
	check(absf(h.rt.thermal_poise_mult(r) - 1.2) < 0.001, "M-F03: 6s per-target cooldown (only the Crossroads part remains)")
	h.prog().crossroads_choice = "living_bastion"
	check(absf(h.rt.interaction_mult("living_bastion") - 1.2) < 0.001 and absf(h.rt.interaction_mult("thermal_fracture") - 1.0) < 0.001, "M-F01: the UI choice changes the enhanced interaction")
	h.prog().crossroads_choice = ""
	# M-F02 Lingering Essence
	h.prog().augments.assign(["mf02_lingering_essence"])
	ElementalStates.apply_chill(r, h, 3.0, 0.7)
	var ch := 0.0
	for e in r.statuses.effects:
		if e.id == "chill":
			ch = e.duration
	check(absf(ch - 3.6 * (1.0 + (h.stats.effect_power() - 1.0) * 0.5)) < 0.05, "M-F02: Chill 3.0s -> 3.6s (+20%%) before MAS scaling (%.2fs)" % ch)
	r.statuses.clear()
	ElementalStates.apply_chill(r, h, 10.0, 0.7)
	for e in r.statuses.effects:
		if e.id == "chill":
			ch = e.duration
	check(absf(ch - 11.5 * (1.0 + (h.stats.effect_power() - 1.0) * 0.5)) < 0.05, "M-F02: extension capped at +1.5s")
	r.statuses.clear()
	# M-F05 Living Confluence
	h.prog().augments.assign(["mf05_living_confluence"])
	Events.elemental_interaction.emit(h, "thermal_fracture", "test")
	Events.spell_released.emit(h, "glacial_spear", "frost", false, 0.5, 10.0)
	dmg.clear()
	var lc: DamageInfo = h.spell_damage(r, 2.0, 0.0, "Glacial Spear")
	var sec := dmg.filter(func(x): return x.attack_name == "Living Confluence")
	check(sec.size() == 1 and absf(sec[0].raw_amount - lc.raw_amount * 0.2) < 0.05, "M-F05: different element after an interaction -> 20% follow-up impact (once)")
	# M-A01 Spell Threading (+ Dual Invocation cap)
	h.prog().augments.assign(["ma01_spell_threading", "mc05_dual_invocation"])
	h.rt.windows.clear()
	h.rt.cds.clear()
	Events.spell_released.emit(h, "flame_cataclysm", "fire", false, 0.5, 10.0)
	var gs: ChargedSpellData = el.spells.glacial_spear
	var m1 := h.rt.charge_mods(gs)
	check(absf(float(m1.min) - 0.8) < 0.001 and absf(float(m1.full) - 0.9) < 0.001, "M-A01: a different spell within 3s: min charge x0.8, full x0.9")
	var m_same := h.rt.charge_mods(fc)
	check(absf(float(m_same.min) - 1.0) < 0.001, "M-A01: the same spell is not threaded")
	h.rt.open("mc05_off", 3.0)
	var m2 := h.rt.charge_mods(gs)
	check(float(m2.full) >= 0.75 - 0.001 and absf(float(m2.full) - 0.9 * 0.85) < 0.001, "M-A01 + M-C05: reductions combine under the 25%% cap (full x%.3f)" % float(m2.full))
	# M-A04 Swift Invocation (wheel change)
	h.prog().augments.assign(["ma04_swift_invocation"])
	h.rt.windows.clear()
	h.rt.cds.clear()
	Events.spell_slot_changed.emit(h, 0, "flame_cataclysm", "glacial_spear", "wheel")
	check(absf(float(h.rt.charge_mods(gs).full) - 0.9) < 0.001, "M-A04: a wheel change -> next spell prepares 10% faster")
	h.rt.consume_charge_mods(gs)
	check(not h.rt.active("ma04"), "M-A04: consumed by casting")
	# M-A03 Rewoven Spell
	h.prog().augments.assign(["ma03_rewoven_spell"])
	var r2 := dummy("raider", r.global_position + Vector3(2, 0, 0))
	r2.max_hp = 99999
	r2.hp = 99999
	Events.spell_released.emit(h, "glacial_spear", "frost", false, 0.5, 10.0)
	dmg.clear()
	var rs: DamageInfo = h.spell_damage(r, 2.0, 0.0, "Glacial Spear")
	var rw := dmg.filter(func(x): return x.attack_name == "Rewoven Spell")
	check(rw.size() == 1 and rw[0].target == r2 and absf(rw[0].raw_amount - rs.raw_amount * 0.25) < 0.05, "M-A03: single-target hit -> second enemy takes 25% (no chaining)")
	# M-A02 Arcane Relay / M-A05 Sympathetic Link / M-A06 Emergency Thread
	h.prog().augments.assign(["ma02_arcane_relay", "ma05_sympathetic_link", "ma06_emergency_thread"])
	h.rt.windows.clear()
	h.rt.cds.clear()
	ally.hp = ally.max_hp * 0.2
	h.kit.heal_target(ally, 20.0, "test heal")
	check(h.rt.active("ma02") and h.rt.active("ma06") and not h.rt._link.is_empty(), "heal on an ally below 35% opens Relay, Emergency Thread and the Link")
	var org := h.rt.relay_origin(Vector3.ZERO, 30.0)
	check(org.distance_to(ally.global_position + Vector3(0, 1.4, 0)) < 0.01, "M-A02: next projectile launches from the ally")
	dmg.clear()
	h.kit.heal_target(ally, 20.0, "second heal")
	var lk := dmg.filter(func(x): return x.attack_name == "Sympathetic Link")
	check(lk.size() == 1 and lk[0].raw_amount <= h.weapon_power * 0.6 + 0.01, "M-A05: the next heal strikes the linked enemy (15%, capped)")
	check(absf(h.rt.spell_recovery_mult(fc) - 0.85) < 0.001, "M-A06: next offensive cast recovers 15% faster")
	# healing stays available with every card (both paths)
	for set in [["mf01_elemental_crossroads", "mf03_thermal_fracture", "mf05_living_confluence"], ["ma01_spell_threading", "ma03_rewoven_spell", "ma05_sympathetic_link"]]:
		h.prog().augments.assign(set)
		h.hp = h.max_hp * 0.3
		h.kit.mana = 100.0
		h.kit.cooldowns.clear()
		var hp2 := h.hp
		await until_idle(h)
		el.set_heal_target(h)
		el.lifeline()
		check(h.hp > hp2, "Lifeline heals with the %s build" % ("Fusion" if set[0].begins_with("mf") else "Arcane"))
	ally.queue_free()
	r2.queue_free()
	h.prog().augments.clear()


func test_no_recursion_and_caps() -> void:
	print("\n[No recursion, no per-hit duplication, cooldown floors]")
	var h := await ww(10)
	var r := dummy("raider", h.global_position + Vector3(0, 0, -4))
	r.max_hp = 99999
	r.hp = 99999
	var r2 := dummy("raider", r.global_position + Vector3(2, 0, 0))
	r2.max_hp = 99999
	r2.hp = 99999
	h.prog().augments.assign(["ma03_rewoven_spell", "g03_echoing_impact", "mc01_merciful_conduit"])
	Events.spell_released.emit(h, "glacial_spear", "frost", false, 0.5, 10.0)
	dmg.clear()
	for i in 6:
		h.spell_damage(r, 1.0, 0.0, "Glacial Spear")
	await wait(0.7)
	var secs := dmg.filter(func(x): return x.tags.get(AugmentRuntime.SECONDARY, false))
	var bad := secs.filter(func(x): return x.attack_name == "Rewoven Spell" and x.target == r)
	check(bad.is_empty() and secs.size() <= 3, "secondary hits never create further secondaries (%d secondaries)" % secs.size())
	var mods := h.rt.charge_mods(h.kit.el.spells.flame_cataclysm)
	check(float(mods.min) >= 0.75 and float(mods.full) >= 0.75, "preparation never below 75% of base (floor)")
	h.prog().augments.clear()
	r.queue_free()
	r2.queue_free()


# ------------------------------------------------------------------ review 1: presentation + safe playtest route
func test_presentation_review() -> void:
	print("\n[Review: scaling labels follow the formulas, honest pair labels, blocked / party states]")
	var h := await bd(10)
	var src := TooltipText.source_for_hero(h)
	var ok := true
	for cls in ["reaver", "vanguard"]:
		for e in SkillCatalog.entries(cls):
			for v in e.get("variants", []):
				var b := TooltipText.breakdown_attack(src, v.attack)
				var txt := "\n".join(TooltipText._attack_lines("x", b, v.attack, src, 0))
				if txt.contains("(heavy / charged)") != bool(b.str_applies) or txt.contains("(multi-hit total)") != bool(b.dex_applies):
					ok = false
					print("    mismatch: ", e.name, " / ", v.label)
	check(ok, "every attack variant shows STR / DEX exactly when the real formula applies them")
	var db: AugmentDB = Game.augment_db
	check(db.pair_kind(db.get_augment("mf01_elemental_crossroads"), db.get_augment("mf05_living_confluence")) == "visual", "Crossroads + Living Confluence is labelled visual feedback only")
	check(db.pair_kind(db.get_augment("vb04_heavy_anchor"), db.get_augment("vb05_fortress_breaker")) == "inactive", "a pair with a blocked card is shown as inactive")
	var mp := Game.prog("mage")
	Game.mage_core = "elementalist"
	mp.level = 10
	mp.augments.assign(["mf01_elemental_crossroads"])
	check(db.synergy_text(db.get_augment("mf05_living_confluence"), mp) == "", "no SYNERGY AVAILABLE for a visual pair")
	var ins := AugmentText.inspect(db.get_augment("mf05_living_confluence"), "mage", mp)
	check(ins.contains("VISUAL LINK") and not ins.contains("SYNERGY AVAILABLE"), "inspect text says VISUAL LINK")
	mp.augments.assign(["mf03_thermal_fracture"])
	check(db.synergy_text(db.get_augment("mf01_elemental_crossroads"), mp) != "", "a mechanical pair is announced as SYNERGY AVAILABLE")
	mp.augments.clear()
	check(AugmentText.inspect(db.get_augment("mf04_healing_ember"), "mage", mp).contains("NOT AVAILABLE"), "blocked card clearly marked NOT AVAILABLE")
	Game.party_mode = false
	check(AugmentText.inspect(db.get_augment("ma05_sympathetic_link"), "mage", mp).contains("NEEDS A PARTY"), "party-only card marked when solo")
	check(AugmentText.inspect(db.get_augment("g04_calculated_risk"), "mage", mp).contains("NOT FOR THIS CLASS") and db.ineligible_reason(db.get_augment("g04_calculated_risk"), mp) != "", "Calculated Risk is excluded for the Worldweaver (no partial effect shown as available)")
	# Thunder Conduit chain: tooltip value = real chain hit (DEX multi-hit included)
	var w := await ww(10)
	w.stats.crit_chance = 0.0
	var e1 := dummy("raider", w.global_position + Vector3(0, 0, -5))
	var e2 := dummy("raider", w.global_position + Vector3(1.5, 0, -6))
	for e in [e1, e2]:
		e.max_hp = 99999
		e.hp = 99999
	w.lock_target = e1
	face(w, e1)
	dmg.clear()
	var tc: ChargedSpellData = w.kit.el.spells.thunder_conduit
	w.kit.el.ai_spell = {"light": "thunder_conduit"}
	w.kit.mana = 100.0
	w.press("light")
	await wait(tc.full_charge + 0.2)
	w.release("light")
	await wait(0.4)
	var chain := dmg.filter(func(x): return String(x.attack_name).contains("(chain)"))
	var want := w.weapon_power * DamageCalc.chain_power(w.stats, DamageCalc.charged_power(w.stats, tc, true), tc.chain_falloff, 0)
	check(chain.size() >= 1 and absf(chain[0].raw_amount - want) < 0.05, "Thunder Conduit first chain jump: tooltip %.1f = dealt %.1f" % [want, chain[0].raw_amount if chain.size() > 0 else -1.0])
	var tt := TooltipText.skill({"id": "thunder_conduit", "name": "Thunder Conduit", "spell": tc}, TooltipText.source_for_hero(w), TooltipText.LEVEL_SIMPLE)
	check(tt.contains("DEX") and tt.contains("Chain"), "spell tooltip shows the DEX-scaled chain")
	e1.queue_free()
	e2.queue_free()


func test_fresh_test_route() -> void:
	print("\n[Safe fresh Level 1-10 route: non-saving, real drafts at 4 / 8 / 10, discarded on return]")
	await teardown()
	var fx := fixture_path("fresh_route_save.json")
	clear_fixture(fx)
	Save.path = fx
	Save.enabled = true
	Game.reset_all_progress()
	Game.reaver_core = "bladedancer"
	Game.mage_core = "elementalist"
	var v := Game.prog("vanguard")
	v.created = true
	v.character_name = "Owner"
	v.set_level(7)
	v.augments.assign(["phantom_bulwark"])
	Save.save_game()
	var hash0 := FileAccess.get_md5(fx)
	for cls in ["vanguard", "mage", "reaver"]:
		Game.start_fresh_test(cls)
		var p := Game.prog(cls)
		check(Game.test_session and Game.fresh_test and p.level == 1 and p.augments.is_empty(), "%s: fresh Level 1 test character (labelled test session)" % cls)
		for i in 9:
			Game.test_gain_level()
		check(p.level == 10 and p.pending_drafts == 3, "%s: levels through the real EXP path, drafts at 4 / 8 / 10 pending (%d)" % [cls, p.pending_drafts])
		var cards := Game.roll_draft(cls)
		check(cards.size() == 3 and cards.all(func(a): return a.pool == "l10"), "%s: the Level 4 draft offers new Level 1-10 cards" % cls)
		Game.choose_augment(cls, cards[0].id)
		Game.autosave()
		check(FileAccess.get_md5(fx) == hash0, "%s: nothing written to the save during the test session" % cls)
	# return to title: the main menu discards a test session by reloading the save
	Game.reset_all_progress()
	Save.load_game()
	Game.fresh_test = false
	check(not Game.test_session and Game.prog("vanguard").level == 7 and Game.prog("vanguard").character_name == "Owner" and Game.prog("vanguard").augments.has("phantom_bulwark"), "returning to the title restores the saved characters exactly")
	check(FileAccess.get_md5(fx) == hash0, "the save file is byte-identical")
	Save.enabled = false
	clear_fixture(fx)