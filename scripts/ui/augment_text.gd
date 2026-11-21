class_name AugmentText
extends RefCounted
## LEVEL10-FOUNDATION-005 (Part 7.2 / 8.5 / 8.6): augment card text generated from the card's params, so
## the numbers on screen are always the values the runtime uses. Tokens: {pct:k} {chg:k} {s:k} {m:k}
## {n:k} {pp:k}. Before / after previews use DamageCalc and the class's real attack data.


static func describe(a: AugmentData) -> String:
	if a == null:
		return ""
	var txt := a.description
	var re := RegEx.new()
	re.compile("\\{(pct|chg|s|m|n|pp):([a-z_0-9]+)\\}")
	var out := txt
	for m in re.search_all(txt):
		var kind := m.get_string(1)
		var key := m.get_string(2)
		var v := float(a.params.get(key, 0.0))
		var rep := ""
		match kind:
			"pct":
				rep = _num(v * 100.0) + "%"
			"chg":
				rep = ("+" if v >= 1.0 else "-") + _num(absf(v - 1.0) * 100.0) + "%"
			"s":
				rep = _num(v, 2) + "s"
			"m":
				rep = _num(v, 2) + "m"
			"pp":
				rep = _num(v * 100.0) + "pp"
			_:
				rep = _num(v, 2)
		out = out.replace(m.get_string(0), rep)
	return out


static func _num(v: float, max_dec: int = 1) -> String:
	if absf(v - roundf(v)) < 0.001:
		return "%d" % roundi(v)
	var s := ("%." + str(max_dec) + "f") % v
	while s.ends_with("0"):
		s = s.trim_suffix("0")
	return s.trim_suffix(".")


static func header(a: AugmentData) -> String:
	var parts: Array = []
	if a.class_id == "global":
		parts.append("GLOBAL")
	elif a.path_id != "":
		parts.append(("PATH ANCHOR · " if a.is_anchor else "") + String(AugmentDB.PATH_NAMES.get(a.path_id, a.path_id)))
	else:
		parts.append("CLASS COMMON")
	parts.append(a.rarity.to_upper())
	if a.code != "":
		parts.append(a.code)
	return "  ·  ".join(parts)


## Full inspect text (BBCode): what changes, what stays, what is sacrificed, affected skills, before / after,
## synergy with owned cards, replacement warning, cooldown, real scaling sources.
static func inspect(a: AugmentData, class_id: String, p: ClassProgress) -> String:
	var lines: Array = []
	lines.append("[b]%s[/b]   [color=#b9a98a]%s[/color]" % [a.display_name, header(a)])
	lines.append(describe(a))
	if a.trigger_summary != "":
		lines.append("[color=#d8c890]Trigger:[/color] " + a.trigger_summary)
	if a.cooldown > 0.0:
		lines.append("[color=#d8c890]Cooldown:[/color] %ss" % _num(a.cooldown, 2))
	if a.mechanical_tradeoff != "":
		lines.append(StatStyle.fx("negative", "Sacrifice: ") + a.mechanical_tradeoff)
	if a.blocked_reason != "":
		lines.append(StatStyle.fx("negative", "NOT AVAILABLE: ") + a.blocked_reason)
	var sc: Array = []
	for s in a.scaling_sources:
		sc.append(StatStyle.stat_tag(s) if StatStyle.STAT.has(s) else String(s).replace("_", " ").capitalize())
	lines.append("Scaling: " + (", ".join(sc) if not sc.is_empty() else "none - fixed values from the card"))
	var pv := preview(a, class_id, p)
	if not pv.is_empty():
		lines.append("[color=#d8c890]Before → after (your current stats):[/color]")
		for l in pv:
			lines.append("  " + l)
	lines.append("Stays the same: your base kit (no skill is removed), damage of every other action.")
	var syn := Game.augment_db.synergy_text(a, p) if p != null else ""
	if syn != "":
		lines.append("[color=#8fe0ff][b]SYNERGY AVAILABLE[/b][/color]  " + syn)
	elif not a.synergy_partners.is_empty():
		var names: Array = []
		for pid in a.synergy_partners:
			var o: AugmentData = Game.augment_db.get_augment(pid)
			names.append(o.display_name if o else pid)
		lines.append("[color=#7fa7b8]Synergy partners:[/color] " + ", ".join(names))
	var rep := Game.augment_db.replaces(a, p) if p != null else ""
	if rep != "":
		var o: AugmentData = Game.augment_db.get_augment(rep)
		lines.append(StatStyle.fx("negative", "REPLACES your %s (same transformation) - it would stay owned but inactive." % (o.display_name if o else rep)))
	if a.is_anchor and p != null and Game.augment_db.chosen_path(p) != "" and Game.augment_db.chosen_path(p) != a.path_id:
		lines.append(StatStyle.fx("negative", "Path anchor of %s: your current cards favour %s." % [AugmentDB.PATH_NAMES.get(a.path_id, a.path_id), AugmentDB.PATH_NAMES.get(Game.augment_db.chosen_path(p), "")]))
	return "\n".join(lines)


static func _atk(id: String) -> AttackData:
	return load("res://data/attacks/%s.tres" % id) as AttackData


static func _src(class_id: String, p: ClassProgress) -> Dictionary:
	if is_instance_valid(Game.player) and Game.player.class_id == class_id:
		return TooltipText.source_for_hero(Game.player)
	return TooltipText.source_for_progress(class_id, p if p != null else ClassProgress.new(class_id))


static func _dmg(src: Dictionary, d: AttackData) -> Dictionary:
	return TooltipText.breakdown_attack(src, d)


## Card-specific before / after lines. Movement cards show real distances, defensive cards shield values,
## damage / Poise cards the real DamageCalc numbers - never an invented DPS.
static func preview(a: AugmentData, class_id: String, p: ClassProgress) -> Array:
	var out: Array = []
	var src := _src(class_id, p)
	var mhp: float = src.stats.max_hp()
	var b := Game.balance
	var pr := a.params
	match a.id:
		"g01_second_wind":
			out.append("Dodge %d stamina → next attack costs ×%.2f" % [roundi(b.dodge_cost), float(pr.stamina_mult)])
		"vc01_guardians_reach":
			out.append("Interception range %.1fm → %.1fm" % [b.intercept_range, b.intercept_range * float(pr.range_mult)])
		"vc03_shared_aegis", "vc06_last_barrier", "vb06_sheltering_counter":
			out.append("Shield: 0 → %d (%s of your %d max HP, VIT)" % [roundi(mhp * float(pr.shield_frac)), StatStyle.pct(float(pr.shield_frac)), roundi(mhp)])
		"vc04_unyielding_footing":
			out.append("Guard movement %s → %s of normal" % [StatStyle.pct(b.guard_move_mult, 1), StatStyle.pct(b.guard_move_mult * float(pr.guard_move_mult), 1)])
		"vb01_living_fortress":
			out.append("Forward speed in Guard %s → %s of normal" % [StatStyle.pct(b.guard_move_mult), StatStyle.pct(float(pr.forward_mult))])
		"vb04_heavy_anchor":
			out.append("Guard movement %s → %s; Poise taken in Guard ×%.2f" % [StatStyle.pct(b.guard_move_mult, 1), StatStyle.pct(b.guard_move_mult * float(pr.move_mult), 1), 1.0 - float(pr.poise_resist)])
		"vb02_shielded_advance":
			var sr := _atk("v_shield_rush")
			out.append("Shield Rush travel ×%.2f; frontal reduction %s → %s" % [float(pr.travel_mult), StatStyle.pct(sr.frontal_guard), StatStyle.pct(minf(sr.frontal_guard + float(pr.frontal_add_pp), float(pr.cap)))])
		"vk01_aegis_reversal":
			var h := _dmg(src, _atk("v_heavy"))
			out.append("Heavy Poise %s → %s; reach ×%.2f" % [StatStyle.num(h.poise), StatStyle.num(h.poise * (1.0 + float(pr.poise_bonus))), float(pr.reach_mult)])
		"vk05_judgment_echo":
			var c := _dmg(src, _atk("v_counter"))
			out.append("Echo Strike: %s damage (%s of Aegis Counter %s)" % [StatStyle.num(c.noncrit * float(pr.damage_share)), StatStyle.pct(float(pr.damage_share)), StatStyle.num(c.noncrit)])
		"vk02_precise_defense":
			out.append("Next Perfect Guard window %.2fs → %.2fs" % [b.perfect_guard_window, b.perfect_guard_window + float(pr.extra_window)])
		"rd01_phantom_footwork":
			out.append("Lateral Dance %.2fm straight → %.2fm curved around the target" % [ReaverBladeDancer.LATERAL_DIST, ReaverBladeDancer.LATERAL_DIST * float(pr.travel_mult)])
		"rd04_extended_orbit":
			var o := _atk("bd_orbit")
			out.append("Orbit Step %d° → %d°; recovery %.2fs → %.2fs" % [roundi(ReaverBladeDancer.ORBIT_ANGLE), roundi(ReaverBladeDancer.ORBIT_ANGLE * float(pr.angle_mult)), o.recovery, o.recovery * float(pr.commit_mult)])
		"rd06_dancers_reversal":
			out.append("Next directional Dance travel ×%.2f (lateral %.2fm → %.2fm)" % [float(pr.travel_mult), ReaverBladeDancer.LATERAL_DIST, ReaverBladeDancer.LATERAL_DIST * float(pr.travel_mult)])
		"rc04_close_pursuit":
			out.append("Forward Dance up to %.2fm → %.2fm toward a retreating target" % [ReaverBladeDancer.FORWARD_MAX, ReaverBladeDancer.FORWARD_MAX * (1.0 + float(pr.travel_bonus))])
		"rc01_seamless_steel":
			var pc := _atk("bd_precision")
			out.append("Precision Cut startup %.2fs → %.2fs after a Dance hit" % [pc.startup, pc.startup * float(pr.startup_mult)])
		"rc06_clean_execution", "rc02_swordsmans_breath":
			var pc2 := _dmg(src, _atk("bd_precision"))
			out.append("Precision Cut: %s damage, Poise %s%s" % [StatStyle.num(pc2.noncrit), StatStyle.num(pc2.poise), (" → %s vs recovering" % StatStyle.num(pc2.poise * (1.0 + float(pr.get("poise_bonus", 0.0))))) if pr.has("poise_bonus") else ""])
		"rd03_circling_predator":
			var la := _dmg(src, _atk("bd_dance_lateral"))
			out.append("Predator Cut %s damage (%s of Lateral Dance %s)" % [StatStyle.num(la.noncrit * float(pr.damage_share)), StatStyle.pct(float(pr.damage_share)), StatStyle.num(la.noncrit)])
		"re01_perfect_draw":
			var cm := _atk("bd_committed")
			out.append("Committed Cut recovery %.2fs → %.2fs when released %.2f-%.2fs" % [cm.recovery, cm.recovery * float(pr.recovery_mult), ReaverBladeDancer.COMMIT_MAX, ReaverBladeDancer.COMMIT_MAX + float(pr.window)])
		"re04_executioners_distance":
			var pc3 := _atk("bd_precision")
			out.append("Precision reach %.2fm → %.2fm; width %.2fm → %.2fm" % [absf(pc3.hitbox_offset.z) + pc3.hitbox_size.z * 0.5, absf(pc3.hitbox_offset.z) + pc3.hitbox_size.z * 0.5 * float(pr.range_mult) + pc3.hitbox_size.z * (float(pr.range_mult) - 1.0) * 0.5, pc3.hitbox_size.x, pc3.hitbox_size.x * float(pr.width_mult)])
		"re03_fracturing_edge":
			var br := _dmg(src, _atk("bd_break"))
			out.append("Breaking Point Poise vs recovering %s → %s; width ×%.2f" % [StatStyle.num(br.poise * ReaverBladeDancer.BREAK_PUNISH_POISE), StatStyle.num(br.poise * ReaverBladeDancer.BREAK_PUNISH_POISE * (1.0 + float(pr.poise_bonus))), float(pr.width_mult)])
		"re05_twin_verdict":
			var full := ReaverBladeDancer.committed_attack(_atk("bd_committed"), 1.0)
			var r := _dmg(src, full)
			out.append("Full Committed Cut %s → %s + %s (total %s)" % [StatStyle.num(r.noncrit), StatStyle.num(r.noncrit * float(pr.first)), StatStyle.num(r.noncrit * (1.0 - float(pr.first))), StatStyle.num(r.noncrit)])
			out.append("Exposure %.2fs → %.2fs" % [full.total_time(), full.total_time() * float(pr.exposure_mult)])
		"re06_patient_blade":
			out.append("Full Committed Cut costs %d stamina → net %d when it connects" % [roundi(_atk("bd_committed").stamina_cost), roundi(_atk("bd_committed").stamina_cost - float(pr.stamina))])
		"g04_calculated_risk":
			if class_id == "reaver":
				var full2 := ReaverBladeDancer.committed_attack(_atk("bd_committed"), 1.0)
				var r2 := _dmg(src, full2)
				out.append("Full Committed Cut %s → %s; miss: recovery %.2fs → %.2fs" % [StatStyle.num(r2.noncrit), StatStyle.num(r2.noncrit * float(pr.power_mult)), full2.recovery, full2.recovery * float(pr.fail_recovery_mult)])
			elif class_id == "vanguard":
				var hv := _dmg(src, _atk("v_heavy"))
				out.append("Shieldbreaker Slash %s → %s; miss: recovery ×%.2f" % [StatStyle.num(hv.noncrit), StatStyle.num(hv.noncrit * float(pr.power_mult)), float(pr.fail_recovery_mult)])
		"mc01_merciful_conduit", "mc06_woven_protection":
			out.append("Cap: %d HP on a %d max HP ally" % [roundi(mhp * float(pr.cap_frac)), roundi(mhp)])
		"ma05_sympathetic_link":
			out.append("Linked damage cap: %d (%.1f × Weapon Power %d)" % [roundi(src.wp * float(pr.cap_wp)), float(pr.cap_wp), roundi(src.wp)])
		"ma01_spell_threading":
			var s: ChargedSpellData = load("res://data/mage_spells/flame_cataclysm.tres")
			out.append("Flame Cataclysm (threaded): min %.2fs → %.2fs, full %.2fs → %.2fs" % [s.min_charge, s.min_charge * float(pr.min_mult), s.full_charge, s.full_charge * float(pr.full_mult)])
	return out
