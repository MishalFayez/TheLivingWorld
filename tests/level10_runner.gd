extends "res://tests/bladedancer_runner.gd"
## LEVEL10-FOUNDATION-005: functional checks for the Level 1-10 foundation (spec Part 11).
##   godot --headless --fixed-fps 60 res://tests/level10_runner.tscn
## Automated checks only: they verify numbers, rules and wiring, not how the game feels.


func _run_all() -> void:
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.source == Game.player: dmg.append(info))
	await test_palette()
	await test_attack_numbers_match_combat()
	await test_crit_numbers()
	await test_scaling_labels()
	await test_tooltip_text_numbers()
	await test_stat_preview()
	await test_spell_and_heal_numbers()
	await test_vanguard_tooltips()
	await test_bd004_forward()
	await test_bd004_lateral()
	await test_bd004_orbit()
	await test_bd004_withdraw_whirl()
	await test_bd004_charge_feedback()
	# (006: the Q / V wheel test is replaced by the LMB / RMB casting-wheel tests in combat006_runner)
	await test_poise_break_windows()
	await teardown()


func stat_hit(h: Hero, r: Enemy, action: String, input: Vector3 = Vector3.ZERO) -> DamageInfo:
	dmg.clear()
	place(h, r, 1.6)
	await act(h, action, input)
	return hit_on(r)


# ------------------------------------------------------------------ A1. palette
func test_palette() -> void:
	print("\n[Stat colors: spec palette, abbreviation always printed with the color]")
	var want := {"str": "f28c52", "dex": "48c8d8", "vit": "66c985", "for": "80a8e8", "mas": "bd92f5"}
	var ok := true
	for k in want:
		if StatStyle.stat_color(k).to_html(false) != want[k]:
			ok = false
	check(ok, "STR / DEX / VIT / FOR / MAS colors = #F28C52 / #48C8D8 / #66C985 / #80A8E8 / #BD92F5")
	check(StatStyle.stat_tag("str").contains("STR") and StatStyle.stat_tag("mas").contains("MAS"), "color tags always include the abbreviation (never color alone)")
	check(StatStyle.fx("poise", "Poise").contains("Poise") and StatStyle.labeled("heal", "Healing", "40").contains("Healing:"), "effect labels carry readable text")


# ------------------------------------------------------------------ A2. tooltip math == combat math
func test_attack_numbers_match_combat() -> void:
	print("\n[DamageCalc breakdown = the damage the attack really deals (pre-armor and post-armor)]")
	var h := await bd(10)
	var p := Game.prog("reaver")
	p.allocated["str"] = 6
	p.allocated["dex"] = 5
	h.refresh_stats(true)
	h.stats.crit_chance = 0.0
	var r := target(h)
	r.max_hp = 99999
	r.hp = 99999
	for c in [["neutral", "light", Vector3.ZERO, "bd_dance_neutral"], ["forward", "light", Vector3(0, 0, -1), "bd_dance_forward"]]:
		var info := await stat_hit(h, r, String(c[1]), c[2])
		var d: AttackData = load("res://data/attacks/%s.tres" % c[3])
		var bdn := DamageCalc.for_combatant(h, d, {}, r)
		check(info != null and absf(info.raw_amount - float(bdn.per_hit[0])) < 0.01, "%s Dance: tooltip %.2f = dealt %.2f (pre-armor)" % [c[0], bdn.per_hit[0], info.raw_amount if info else -1.0])
		check(info != null and absf(info.final_amount - float(bdn.per_hit[0]) * float(bdn.mitigation)) < 0.01, "%s Dance: post-armor estimate %.2f = dealt %.2f" % [c[0], float(bdn.per_hit[0]) * float(bdn.mitigation), info.final_amount if info else -1.0])
		await wait(0.3)
		refill(h)
	# Committed Cut at full charge: STR (charged) applies
	place(h, r, 1.6)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	h.press("light")
	await wait(0.8)
	h.release("light")
	await wait(0.02)
	await until_idle(h)
	var ci := hit_on(r)
	var full := ReaverBladeDancer.committed_attack(load("res://data/attacks/bd_committed.tres"), 1.0)
	var cb := DamageCalc.for_combatant(h, full, {}, r)
	check(ci != null and absf(ci.raw_amount - float(cb.noncrit)) < 0.01, "full Committed Cut: tooltip %.2f = dealt %.2f" % [cb.noncrit, ci.raw_amount if ci else -1.0])
	check(cb.str_applies and absf(float(cb.str_mult) - h.stats.heavy_mult()) < 0.0001, "Committed Cut lists STR (charged) with the real multiplier x%.2f" % float(cb.str_mult))
	h.release("heavy")
	await wait(0.4)
	refill(h)
	# Whirling Assault: multi-hit (DEX), total split across hits
	p.debug_unlocks.append("bd_offense")
	h.refresh_stats(true)
	h.stats.crit_chance = 0.0
	dmg.clear()
	place(h, r, 1.6)
	await act(h, "core")
	var tot := 0.0
	var n := 0
	for i in dmg:
		if i.target == r and i.attack_name == "Whirling Assault":
			tot += i.raw_amount
			n += 1
	var wb := DamageCalc.for_combatant(h, load("res://data/attacks/bd_whirl.tres"), {}, r)
	check(n == int(wb.hits) and absf(tot - float(wb.noncrit)) < 0.05, "Whirling Assault: %d hits, tooltip total %.2f = dealt %.2f" % [n, wb.noncrit, tot])
	check(wb.dex_applies and not wb.str_applies, "Whirling Assault scales with DEX (multi-hit), not STR")


func test_crit_numbers() -> void:
	print("\n[Critical value shown = critical damage dealt]")
	var h := await bd(10)
	h.stats.crit_chance = 1.0
	var r := target(h)
	r.max_hp = 99999
	r.hp = 99999
	var info := await stat_hit(h, r, "light")
	var bdn := DamageCalc.for_combatant(h, load("res://data/attacks/bd_dance_neutral.tres"), {}, r)
	check(info != null and info.is_crit and absf(info.raw_amount - float(bdn.per_hit_crit[0])) < 0.01, "crit tooltip %.2f = crit dealt %.2f" % [bdn.per_hit_crit[0], info.raw_amount if info else -1.0])
	check(absf(float(bdn.crit_mult) - h.stats.crit_damage_total()) < 0.0001, "crit multiplier = base crit damage + STR x 1.2pp")
	var e := float(bdn.expected)
	check(absf(e - float(bdn.crit)) < 0.01, "expected value at 100% crit chance = crit value")


# ------------------------------------------------------------------ A3. only real stats are shown
func test_scaling_labels() -> void:
	print("\n[A skill shows only the stats that really affect it]")
	var src := TooltipText.source_for_progress("reaver", Game.prog("reaver"))
	var ents := SkillCatalog.entries("reaver")
	var by := {}
	for e in ents:
		by[e.id] = TooltipText.skill(e, src, TooltipText.LEVEL_SIMPLE)
	check(not by.bd_dance.contains("(heavy / charged)") and not by.bd_dance.contains("multi-hit"), "Dance: no STR heavy / DEX scaling (it is neither heavy nor multi-hit)")
	check(by.bd_committed.contains("(heavy / charged)"), "Committed Cut: STR (charged) shown")
	check(by.bd_whirl.contains("(multi-hit total)") and not by.bd_whirl.contains("(heavy / charged)"), "Whirling Assault: DEX shown, STR heavy not shown")
	var all_txt := "".join(by.values())
	check(not all_txt.contains("VIT") and not all_txt.contains("MAS"), "no VIT / MAS on Reaver damage skills (VIT = HP only, MAS = effects only)")
	var mp := ClassProgress.new("mage")
	mp.level = 10
	Game.mage_core = "elementalist"
	var msrc := TooltipText.source_for_progress("mage", mp)
	var mtxt := {}
	for e in SkillCatalog.entries("mage", mp):
		mtxt[e.id] = TooltipText.skill(e, msrc, TooltipText.LEVEL_DETAILED)
	check(mtxt.verdant_renewal.contains("MAS"), "Verdant Renewal (heal over time) shows MAS")
	check(not mtxt.life_bloom.contains("MAS (") and mtxt.life_bloom.contains("do not scale with MAS"), "Life Bloom (direct heal) says honestly that MAS does not scale it")
	check(mtxt.flame_cataclysm.contains("full charge only"), "Flame Cataclysm: STR only on the full release (real formula)")


func test_tooltip_text_numbers() -> void:
	print("\n[Tooltip text prints the computed numbers, at all three levels]")
	var h := await bd(10)
	var src := TooltipText.source_for_hero(h)
	var ent: Dictionary = {}
	for e in SkillCatalog.entries("reaver"):
		if e.id == "bd_committed":
			ent = e
	var full: AttackData = ent.variants[1].attack
	var bdn := TooltipText.breakdown_attack(src, full)
	var simple := TooltipText.skill(ent, src, TooltipText.LEVEL_SIMPLE)
	var det := TooltipText.skill(ent, src, TooltipText.LEVEL_DETAILED)
	var adv := TooltipText.skill(ent, src, TooltipText.LEVEL_ADVANCED)
	check(simple.contains(StatStyle.num(bdn.noncrit)) and simple.contains("Stamina") and simple.contains("Poise"), "SIMPLE: damage %s, Poise and Stamina" % StatStyle.num(bdn.noncrit))
	check(det.contains("Weapon Power") and det.contains("STR") and det.contains("Expected"), "DETAILED: base, STR contribution, expected value")
	check(adv.contains("Formula") and adv.contains("Phases") and adv.contains("Hits"), "ADVANCED: formula, timing phases, hit distribution")
	check(simple.length() < det.length() and det.length() < adv.length(), "each level adds information")
	check(absf(full.damage_mult - (load("res://data/attacks/bd_committed.tres").damage_mult + ReaverBladeDancer.COMMIT_DMG_BONUS)) < 0.0001, "catalog full-charge variant = the attack the kit starts (+%.1f)" % ReaverBladeDancer.COMMIT_DMG_BONUS)


# ------------------------------------------------------------------ A4. before / after
func test_stat_preview() -> void:
	print("\n[Allocation preview: before -> after uses the real formula and matches the real hit]")
	var h := await bd(10)
	var p := Game.prog("reaver")
	p.free_points = 4
	var before := StatPreview.clone(p)
	var after := StatPreview.clone_with_pending(p, {"str": 1})
	var rows := TooltipText.preview_rows("reaver", before, after)
	var row: Dictionary = {}
	var nrow: Dictionary = {}
	for x in rows:
		if String(x.name).contains("Committed Cut") and String(x.name).contains("Full"):
			row = x
		if String(x.name).contains("Neutral"):
			nrow = x
	check(not row.is_empty() and float(row.after) > float(row.before), "STR +1: Committed Cut (full) %s -> %s" % [StatStyle.num(row.get("before", 0)), StatStyle.num(row.get("after", 0))])
	check(not nrow.is_empty() and absf(float(nrow.after) - float(nrow.before)) < 0.001, "STR +1: neutral Dance unchanged (not heavy, not charged)")
	# allocate for real and hit: the real hit equals the preview's "after"
	p.allocate("str")
	h.refresh_stats(true)
	h.stats.crit_chance = 0.0
	var r := target(h)
	r.max_hp = 99999
	r.hp = 99999
	place(h, r, 1.6)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	h.press("light")
	await wait(0.8)
	h.release("light")
	await wait(0.02)
	await until_idle(h)
	var ci := hit_on(r)
	check(ci != null and absf(ci.raw_amount - float(row.after)) < 0.01, "after allocating: real hit %.2f = preview %.2f" % [ci.raw_amount if ci else -1.0, float(row.get("after", 0))])
	h.release("heavy")
	var vit_after := TooltipText.preview_rows("reaver", StatPreview.clone(p), StatPreview.clone_with_pending(p, {"vit": 3}))
	var any := false
	for x in vit_after:
		if absf(float(x.after) - float(x.before)) > 0.001:
			any = true
	check(not any, "VIT +3 changes no skill damage (VIT = Max HP only)")
	check(absf(StatPreview.with_pending("reaver", p, {"vit": 3})["Max HP"] - StatPreview.derived("reaver", p)["Max HP"] - 3.0 * Game.balance.hp_per_vit) < 0.001, "VIT +3 previews +%d Max HP" % roundi(3.0 * Game.balance.hp_per_vit))


# ------------------------------------------------------------------ A5. spells / heals
func test_spell_and_heal_numbers() -> void:
	print("\n[Worldweaver: spell and heal tooltips = real amounts]")
	var h := await setup("mage", false, false, false)
	Game.set_level("mage", 10)
	Game.prog("mage").pending_drafts = 0
	Game.prog("mage").pending_draft_tiers.clear()
	await wait(0.2)
	h.refresh_stats(true)
	h.stats.crit_chance = 0.0
	var r := dummy("raider", h.global_position + Vector3(0, 0, -3))
	r.max_hp = 99999
	r.hp = 99999
	var s: ChargedSpellData = load("res://data/mage_spells/flame_cataclysm.tres")
	for full in [false, true]:
		var info: DamageInfo = h.spell_damage(r, h.kit.el.dmg_power(s, full), 10.0, "test")
		var bdn := DamageCalc.spell_breakdown(h.stats, h.weapon_power, s, full, r, h.statuses.mult("damage_dealt"))
		check(absf(info.raw_amount - float(bdn.noncrit)) < 0.01, "Flame Cataclysm %s: tooltip %.2f = dealt %.2f" % ["full" if full else "partial", bdn.noncrit, info.raw_amount])
	var got := [0.0]
	var cb := func(_s, t, amount, over, _tags): if t == h: got[0] = amount + over
	Events.healed.connect(cb)
	h.hp = 1.0
	h.kit.mana = 100.0
	h.kit.el.lifeline()
	Events.healed.disconnect(cb)
	var ll: ChargedSpellData = load("res://data/mage_spells/lifeline.tres")
	check(absf(got[0] - DamageCalc.direct_heal(h.weapon_power, ll.power_partial)) < 0.01, "Lifeline: tooltip heal %.1f = real heal %.1f" % [DamageCalc.direct_heal(h.weapon_power, ll.power_partial), got[0]])


func test_vanguard_tooltips() -> void:
	print("\n[Vanguard: guard facts come from the balance config; charged Judgment uses the kit builder]")
	var p := ClassProgress.new("vanguard")
	p.level = 10
	var src := TooltipText.source_for_progress("vanguard", p)
	var txt := ""
	var jud: Dictionary = {}
	for e in SkillCatalog.entries("vanguard"):
		txt += TooltipText.skill(e, src, TooltipText.LEVEL_SIMPLE)
		if e.id == "judgment_strike":
			jud = e
	check(txt.contains(StatStyle.pct(Game.balance.guard_reduction)) and txt.contains("%.2fs" % Game.balance.perfect_guard_window), "Guard reduction %s and Perfect Guard window %.2fs from BalanceConfig" % [StatStyle.pct(Game.balance.guard_reduction), Game.balance.perfect_guard_window])
	var sd: SkillData = load("res://data/skills/judgment_strike.tres")
	check(not jud.is_empty() and absf(jud.variants[1].attack.damage_mult - (sd.attack.damage_mult + sd.attack.charge_damage_bonus)) < 0.0001 and jud.variants[1].attack.is_charged, "full Judgment Strike = ClassKit.charged_attack(ratio 1)")


# ------------------------------------------------------------------ B. Blade Dancer 004
func test_bd004_forward() -> void:
	print("\n[004 Forward Dance: ~1.3m with room, a short step when already in weapon range; collision real]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h)
	var res := {}
	for gap in [4.0, 2.4, 1.6]:
		place(h, r, gap)
		await wait(0.2)
		var toward := (r.global_position - h.global_position).normalized()
		var mv := await act(h, "light", toward)
		res[gap] = mv.dot(toward)
		refill(h)
	check(res[4.0] >= 1.15 and res[4.0] <= 1.45, "gap 4.0m: travel %.2fm (target ~1.3m)" % res[4.0])
	check(res[2.4] > res[1.6] and res[2.4] <= 1.35, "gap 2.4m: travel %.2fm (closes toward weapon range)" % res[2.4])
	check(res[1.6] <= 0.6, "gap 1.6m (already in range): short step %.2fm" % res[1.6])
	check(flat(h, r) >= 0.85, "never passes through the enemy (bodies collide), end gap %.2fm" % flat(h, r))
	var d := load("res://data/attacks/bd_dance_forward.tres") as AttackData
	check(is_equal_approx(d.damage_mult, 1.0) and is_equal_approx(d.startup, 0.14), "damage and timing preserved (x%.2f, startup %.2fs)" % [d.damage_mult, d.startup])
	# no i-frames on movement attacks
	place(h, r, 3.0)
	h.move_input = (r.global_position - h.global_position).normalized()
	tap(h, "light")
	var inv := false
	for i in 20:
		await get_tree().physics_frame
		inv = inv or h.is_invulnerable()
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(not inv, "Forward Dance has no invulnerability")


func test_bd004_lateral() -> void:
	print("\n[004 Lateral Dance: ~1.0m, locked target radius kept; repeated laterals stay in melee range]")
	var h := await bd(1)
	var r := target(h)
	place(h, r, 2.0)
	await wait(0.2)
	var gaps: Array = [flat(h, r)]
	var travel := 0.0
	for i in 6:
		var to := r.global_position - h.global_position
		to.y = 0
		var right := to.normalized().cross(Vector3.UP).normalized()
		var p0 := h.global_position
		var r0 := r.global_position
		await act(h, "light", right)
		travel += flat_v(h.global_position - p0)
		# measure the Reaver's own movement: undo the hit knockback the dummy received
		r.knock_velocity = Vector3.ZERO
		r.global_position = r0
		gaps.append(flat(h, r))
		refill(h)
	var lo := 99.0
	var hi := 0.0
	for g in gaps:
		lo = minf(lo, g)
		hi = maxf(hi, g)
	check(travel / 6.0 >= 0.85 and travel / 6.0 <= 1.15, "average lateral travel %.2fm (target ~1.0m)" % (travel / 6.0))
	check(hi - lo < 0.35 and hi < 2.4, "6 lateral attacks: radius %.2f-%.2fm (no drift out of range)" % [lo, hi])
	# without lock-on: straight and predictable
	h.lock_target = null
	h.face_dir(Vector3(0, 0, -1))
	var p1 := h.global_position
	await act(h, "light", Vector3(1, 0, 0))
	var mv := h.global_position - p1
	check(absf(mv.z) < 0.15 and mv.x > 0.8, "no lock-on: straight sidestep (%.2f, %.2f)" % [mv.x, mv.z])


func test_bd004_orbit() -> void:
	print("\n[004 Orbit Step: ~75 deg at close range, bounded duration, radius kept, no invulnerability]")
	var h := await bd(3)
	var f := bk(h)
	var r := target(h)
	var rows: Array = []
	for rad in [1.6, 2.2, 3.0]:
		place(h, r, rad)
		await wait(0.2)
		var p0 := h.global_position
		var a0 := Vector3(h.global_position - r.global_position)
		a0.y = 0
		h.move_input = a0.normalized().cross(Vector3.UP)
		tap(h, "footwork")
		var inv := false
		for i in 30:
			await get_tree().physics_frame
			inv = inv or h.is_invulnerable()
		h.move_input = Vector3.ZERO
		await until_idle(h)
		var a1 := Vector3(h.global_position - r.global_position)
		a1.y = 0
		rows.append({"r": rad, "deg": rad_to_deg(a0.angle_to(a1)), "end_r": a1.length(), "path": flat_v(h.global_position - p0), "startup": f.last_orbit.get("startup", 0.0), "inv": inv})
		refill(h)
		await wait(0.3)
	var txt := ""
	for x in rows:
		txt += "r %.1f: %.0f deg, end r %.2f, startup %.2fs; " % [x.r, x.deg, x.end_r, x.startup]
	print("    measured: ", txt)
	check(rows[0].deg >= 68.0 and rows[0].deg <= 85.0, "radius 1.6m: %.0f deg (target 70-80)" % rows[0].deg)
	check(rows[1].deg >= 60.0 and rows[1].deg <= 85.0, "radius 2.2m: %.0f deg" % rows[1].deg)
	check(rows[2].deg > 35.0, "radius 3.0m: %.0f deg (duration capped at %.2fs, sensible tangential speed)" % [rows[2].deg, ReaverBladeDancer.ORBIT_MAX_T])
	var kept := true
	for x in rows:
		if absf(x.end_r - x.r) > 0.45 or x.inv:
			kept = false
	check(kept, "radius kept within 0.45m and no invulnerability at every radius")


func test_bd004_withdraw_whirl() -> void:
	print("\n[004 Withdraw ~1.5m with the thrust still reaching; Whirling Assault keeps 4 hits and engagement]")
	var h := await bd(5)
	var r := target(h)
	r.max_hp = 99999
	r.hp = 99999
	place(h, r, 1.6)
	await wait(0.2)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	var p0 := h.global_position
	tap(h, "footwork")
	await wait(0.03)
	await until_idle(h)
	var back := -(h.global_position - p0).dot((r.global_position - p0).normalized())
	check(back >= 1.3 and back <= 1.7, "Withdraw retreat %.2fm (target ~1.5m; 003 ~0.8m)" % back)
	check(hit_on(r) != null, "the thrust still reaches from the new spacing (hitbox unchanged)")
	var wd := load("res://data/attacks/bd_withdraw.tres") as AttackData
	check(is_equal_approx(wd.hitbox_size.z, 3.2) and is_equal_approx(wd.hitbox_offset.z, -2.0), "Withdraw hitbox not extended")
	h.release("heavy")
	await wait(0.4)
	refill(h)
	place(h, r, 2.6)
	await wait(0.2)
	dmg.clear()
	tap(h, "core")
	await wait(0.03)
	await until_idle(h)
	var n := 0
	for i in dmg:
		if i.target == r:
			n += 1
	var wa := load("res://data/attacks/bd_whirl.tres") as AttackData
	check(wa.hits == 4 and is_equal_approx(wa.damage_mult, 2.2), "Whirling Assault: still 4 hits, damage x2.2 unchanged")
	check(n == 4, "starting 2.6m away with lock-on, all 4 hits connect (stays engaged): %d" % n)


func test_bd004_charge_feedback() -> void:
	print("\n[004 Committed Cut feedback: progression, one full-charge cue, blade highlight, clean cancel, no damage change]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h)
	r.max_hp = 99999
	r.hp = 99999
	place(h, r, 1.6)
	h.press("heavy")
	await wait(0.05)
	h.press("light")
	await wait(0.2)
	check(not f.charge_fx_active(), "no feedback before the 0.35s Committed threshold")
	await wait(0.3)
	check(f.charge_fx_active() and not f.blade_highlight_active(), "charging glow after the threshold, no full highlight yet")
	await wait(0.4)
	check(f.blade_highlight_active() and f.full_charge_cues == 1 and h.anim.current_animation == ReaverBladeDancer.FULL_POSE_ANIM, "full charge: blade highlight + max-charge pose + cue")
	await wait(0.6)
	check(f.full_charge_cues == 1, "holding longer never repeats the cue (once per charge)")
	dmg.clear()
	h.release("light")
	await wait(0.02)
	check(not f.charge_fx_active() and not f.blade_highlight_active(), "feedback ends when the strike is released")
	await until_idle(h)
	var ci := hit_on(r)
	var full := ReaverBladeDancer.committed_attack(load("res://data/attacks/bd_committed.tres"), 1.0)
	h.stats.crit_chance = 0.0
	check(ci != null and absf(ci.raw_amount - float(DamageCalc.for_combatant(h, full, {}, r).per_hit[0])) < 0.01 or (ci != null and ci.is_crit), "damage = existing full-charge value (no extra damage)")
	await wait(0.4)
	refill(h)
	h.press("light")
	await wait(0.8)
	check(f.full_charge_cues == 2, "a new charge can cue again")
	h.release("heavy")
	await wait(0.03)
	check(not f.charge_fx_active() and not f.blade_highlight_active() and not h.runner.is_busy(), "releasing RMB cancels the charge and clears every feedback element (no strike)")
	h.release("light")

# ------------------------------------------------------------------ B. Worldweaver spell wheels
func ww(level: int) -> Hero:
	var h := await setup("mage", false, false, false)
	Game.set_level("mage", level)
	Game.prog("mage").pending_drafts = 0
	Game.prog("mage").pending_draft_tiers.clear()
	await wait(0.6)
	h.refresh_stats(true)
	h.restore_all()
	for c in h.get_children():
		if c is PlayerBrain:
			c.set_physics_process(false)
	return h


func test_spell_wheels() -> void:
	print("\n[Spell wheels: hold = radial selector of known spells, release = equip, tap = previous, never casts]")
	var h := await ww(9)
	var el: MageElementalist = h.kit.el
	var opts := el.wheel_options()
	var known := el.known_charged()
	check(opts.size() == known.size() and opts.size() >= 5, "wheel lists exactly the known charged spells (%d)" % opts.size())
	var order_ok := true
	var last := -1
	for id in opts:
		var idx := MageElementalist.ELEMENT_ORDER.find(el.spells[id].element)
		if idx < last:
			order_ok = false
		last = idx
	check(order_ok, "grouped by element: Fire, Life, Frost, Storm, Stone")
	var lp := ClassProgress.new("mage")
	lp.level = 1
	Game.prog("mage").debug_locks.append("elem:storm")
	check(not el.wheel_options().any(func(x): return el.spells[x].element == "storm"), "unlearned spells are never offered")
	Game.prog("mage").debug_locks.erase("elem:storm")
	# hold opens after 0.2s, a tap does not
	var lmb0 := el.slot_spell(0)
	var rmb0 := el.slot_spell(1)
	var mana0: float = h.kit.mana
	h.press("wheel_primary")
	await wait(0.1)
	check(not el.wheel_open, "not open during a quick press")
	await wait(0.2)
	check(el.wheel_open and Game.wheel_open, "holding opens the wheel (camera input paused, game running)")
	var pick := ""
	for i in opts.size():
		if opts[i] != lmb0 and opts[i] != rmb0:
			pick = opts[i]
			el.wheel_hover = i
			break
	h.release("wheel_primary")
	await wait(0.05)
	check(el.slot_spell(0) == pick and not el.wheel_open and not Game.wheel_open, "release over a spell equips it on LMB (%s)" % pick)
	check(el.cur == null and not h.runner.is_busy() and absf(h.kit.mana - mana0) < 0.01, "nothing cast, no mana spent")
	check(String(Game.prog("mage").spell_loadout[0]) == pick, "saved loadout updated (Spellbook shows it)")
	# tap swaps back
	tap(h, "wheel_primary")
	await wait(0.05)
	check(el.slot_spell(0) == lmb0, "tap swaps back to the previous LMB spell")
	tap(h, "wheel_primary")
	await wait(0.05)
	check(el.slot_spell(0) == pick, "tap again toggles (current <-> previous)")
	# choosing the RMB spell for LMB swaps the two slots (no slot left empty)
	h.press("wheel_primary")
	await wait(0.3)
	el.wheel_hover = opts.find(rmb0)
	h.release("wheel_primary")
	await wait(0.05)
	check(el.slot_spell(0) == rmb0 and el.slot_spell(1) == pick, "picking the RMB spell for LMB swaps the two slots")
	# secondary wheel changes RMB
	h.press("wheel_secondary")
	await wait(0.3)
	el.wheel_hover = opts.find(lmb0)
	h.release("wheel_secondary")
	await wait(0.05)
	check(el.slot_spell(1) == lmb0, "V wheel changes the RMB slot")
	# cancel: Escape / dead zone
	var before := el.slot_spell(0)
	h.press("wheel_primary")
	await wait(0.3)
	el.wheel_cancel()
	h.release("wheel_primary")
	await wait(0.05)
	check(el.slot_spell(0) == before and not Game.wheel_open, "Escape cancels: nothing changes")
	h.press("wheel_primary")
	await wait(0.3)
	el.wheel_hover = -1
	h.release("wheel_primary")
	await wait(0.05)
	check(el.slot_spell(0) == before, "releasing in the centre (no valid spell) cancels")
	check(SpellWheel.hover_index(6, Vector2(0, -100)) == 0 and SpellWheel.hover_index(6, Vector2(100, 0)) == 1 and SpellWheel.hover_index(6, Vector2(3, 3)) == -1, "mouse direction picks the sector; the centre is a dead zone")
	# invalid previous spell: tap does nothing
	el.prev_spell[1] = "lightning_verdict_unknown"
	var r_before := el.slot_spell(1)
	tap(h, "wheel_secondary")
	await wait(0.05)
	check(el.slot_spell(1) == r_before and el.wheel_events.back().kind == "tap_invalid", "tap with no valid previous spell does nothing (soft notice)")
	# during a charge: never interrupts, applied when the charge ends
	h.kit.mana = 100.0
	var cur_spell := el.slot_spell(0)
	var tgt := ""
	for id in opts:
		if id != cur_spell and el.spells[id].element != "life":
			tgt = id
			break
	h.press("light")
	await wait(0.1)
	check(el.cur != null, "(charging %s)" % cur_spell)
	h.press("wheel_primary")
	await wait(0.3)
	el.wheel_hover = opts.find(tgt)
	h.release("wheel_primary")
	await wait(0.05)
	check(el.cur != null and el.cur.id == cur_spell and el.slot_spell(0) == cur_spell and not el.pending_slot.is_empty(), "mid-charge selection does not interrupt the charge (request kept)")
	h.release("light")
	await wait(1.2)
	check(el.slot_spell(0) == tgt and el.pending_slot.is_empty(), "the deferred selection is applied when the charge ends")
	# third slot / utility untouched, healing intact
	check(el.slot_spell(2) == String(Game.prog("mage").spell_loadout[2]) or el.slot_spell(2) == "", "third charged slot and utility slot untouched")
	await until_idle(h)
	h.hp = h.max_hp * 0.3
	h.kit.mana = 100.0
	var hp0 := h.hp
	h.kit.el.lifeline()
	check(h.hp > hp0, "Lifeline (F) still heals")

# ------------------------------------------------------------------ B. Poise / Stagger (Part 9)
func test_poise_break_windows() -> void:
	print("\n[Poise Break windows by tier; minor reactions separate; no break chaining; readable feedback]")
	var h := await bd(10)
	var notices: Array = []
	var cb := func(t, who): if t == "POISE BROKEN": notices.append(who)
	Events.combat_notice.connect(cb)
	var res := {}
	for spec in [["raider", false, "normal"], ["raider", true, "elite"], ["ashen_warden", false, "boss"]]:
		var e := dummy(String(spec[0]), h.global_position + Vector3(0, 0, -2.2), true, bool(spec[1]))
		e.max_hp = 999999
		e.hp = 999999
		await wait(0.1)
		e.take_poise(e.max_poise + 1.0)
		var t0 := Game.time
		var dur := e.stagger_timer
		check(e.is_poise_broken(), "%s: Poise Break state" % spec[2])
		var hp_before := e.poise
		e.take_poise(e.max_poise * 2.0)
		check(e.poise == hp_before and e.poise_breaks == 1, "%s: Poise damage during the window is ignored (no chaining)" % spec[2])
		while e.stagger_timer > 0.0 and Game.time - t0 < 3.0:
			await get_tree().physics_frame
		res[spec[2]] = Game.time - t0
		e.queue_free()
		await wait(0.1)
	print("    measured Poise Break windows: normal %.2fs, elite %.2fs, boss %.2fs" % [res.normal, res.elite, res.boss])
	check(res.normal >= 1.2 and res.normal <= 1.4, "normal enemy: %.2fs (target 1.2-1.4s; was 0.85s)" % res.normal)
	check(res.elite >= 0.8 and res.elite <= 1.0, "elite enemy: %.2fs (target 0.8-1.0s)" % res.elite)
	check(res.boss >= 0.5 and res.boss <= 0.7, "boss: %.2fs (target 0.5-0.7s; was 0.47s)" % res.boss)
	check(notices.size() == 3, "every Poise Break announces POISE BROKEN (%d)" % notices.size())
	Events.combat_notice.disconnect(cb)
	# minor hit reaction stays short and is not a Poise Break
	var r := dummy("raider", h.global_position + Vector3(0, 0, -2.2))
	r.max_hp = 99999
	r.hp = 99999
	var info := DamageInfo.new()
	info.source = h
	info.amount = 1.0
	info.poise = 1.0
	info.stagger_on_hit = 0.3
	info.source_pos = h.global_position
	r.take_damage(info)
	check(r.is_staggered() and not r.is_poise_broken() and r.stagger_timer <= 0.31, "minor reaction: %.2fs, not a Poise Break" % r.stagger_timer)
	await wait(0.5)
	# usable window: from a fresh break, a Precision Cut lands well inside the opening
	r.poise = 1.0
	place(h, r, 1.8)
	h.stats.crit_chance = 0.0
	r.take_poise(5.0)
	var tb := Game.time
	h.press("heavy")
	await wait(0.02)
	dmg.clear()
	tap(h, "light")
	var landed := -1.0
	for i in 60:
		await get_tree().physics_frame
		if hit_on(r) != null and landed < 0.0:
			landed = Game.time - tb
	h.release("heavy")
	check(landed > 0.0 and landed < Game.balance.poise_break_normal - 0.5, "a Precision Cut lands %.2fs into the %.1fs opening (room for a follow-up)" % [landed, Game.balance.poise_break_normal])