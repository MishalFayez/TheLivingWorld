class_name TooltipText
extends RefCounted
## LEVEL10-FOUNDATION-005 (Part 8.3): three tooltip levels (SIMPLE / DETAILED / ADVANCED) as BBCode, built
## ONLY from DamageCalc results. `src` = {stats: StatBlock, wp: float, status_dmg, status_poise, target}.

const LEVEL_SIMPLE := 0
const LEVEL_DETAILED := 1
const LEVEL_ADVANCED := 2


static func source_for_progress(class_id: String, p: ClassProgress) -> Dictionary:
	return {"stats": StatBlock.for_class(class_id, p, Game.balance), "wp": StatPreview.weapon_power(class_id, p), "status_dmg": 1.0, "status_poise": 1.0, "target": null}


static func source_for_hero(h) -> Dictionary:
	var t = h.lock_target if "lock_target" in h and h.lock_target != null and is_instance_valid(h.lock_target) else null
	return {"stats": h.stats, "wp": h.weapon_power, "status_dmg": h.statuses.mult("damage_dealt"), "status_poise": h.statuses.mult("poise_damage"), "target": t}


static func breakdown_attack(src: Dictionary, d: AttackData) -> Dictionary:
	return DamageCalc.attack_breakdown(src.stats, src.wp, d, {}, src.get("target"), float(src.get("status_dmg", 1.0)), float(src.get("status_poise", 1.0)))


static func breakdown_spell(src: Dictionary, s: ChargedSpellData, full: bool) -> Dictionary:
	return DamageCalc.spell_breakdown(src.stats, src.wp, s, full, src.get("target"), float(src.get("status_dmg", 1.0)))


## Main entry: tooltip body for one SkillCatalog entry.
static func skill(entry: Dictionary, src: Dictionary, level: int) -> String:
	var lines: Array = []
	lines.append("[b]%s[/b]" % entry.name)
	if String(entry.get("purpose", "")) != "":
		lines.append(String(entry.purpose))
	if entry.has("facts"):
		for f in entry.facts:
			lines.append("%s: %s" % [f[0], f[1]])
	if entry.has("variants"):
		for v in entry.variants:
			lines.append("")
			lines += _attack_lines(String(v.label), breakdown_attack(src, v.attack), v.attack, src, level)
	if entry.has("spell"):
		var s: ChargedSpellData = entry.spell
		if entry.get("heal", false):
			lines += _heal_lines(s, src, level)
		elif s.power_full > 0.0 or s.power_partial > 0.0:
			for full in [false, true]:
				lines.append("")
				lines += _spell_lines(s, full, breakdown_spell(src, s, full), src, level)
		else:
			lines.append("")
			lines.append("%s  ·  %s" % [StatStyle.labeled("mana", "Mana", "%d / %d (partial / full)" % [roundi(s.mana_partial), roundi(s.mana_full)]),
				"Charge %.2fs → %.2fs" % [s.min_charge, s.full_charge]])
	if entry.has("motion"):
		lines.append("")
		for m in entry.motion:
			lines.append("%s: %s" % [m[0], m[1]])
	if float(entry.get("cooldown", 0.0)) > 0.0:
		var cdr: float = src.stats.cdr
		lines.append("Cooldown: %.1fs%s" % [float(entry.cooldown) * (1.0 - cdr), "  (base %.1fs, CDR %s)" % [entry.cooldown, StatStyle.pct(cdr)] if cdr > 0.0 and level > 0 else ""])
	if String(entry.get("risk", "")) != "":
		lines.append(StatStyle.fx("negative", "Risk: ") + String(entry.risk))
	if level == LEVEL_SIMPLE:
		lines.append("[color=#8a8070](hold Shift for the calculation)[/color]")
	return "\n".join(lines)


static func _scaling_text(r: Dictionary) -> String:
	var parts: Array = []
	if r.str_applies:
		parts.append(StatStyle.stat_tag("str") + " (heavy / charged)")
	if r.dex_applies:
		parts.append(StatStyle.stat_tag("dex") + " (multi-hit total)")
	parts.append(StatStyle.stat_tag("str") + " (critical damage)")
	return "Scaling: " + ", ".join(parts)


static func _attack_lines(label: String, r: Dictionary, d: AttackData, src: Dictionary, level: int) -> Array:
	var kind: String = r.type
	var dl := "Physical Damage" if kind == "physical" else "Magic Damage"
	var out: Array = []
	out.append("[u]%s[/u]" % label)
	var dmg := StatStyle.num(r.noncrit)
	if int(r.hits) > 1:
		dmg += "  (%d hits)" % r.hits
	out.append("%s   %s" % [StatStyle.labeled(kind, dl, dmg), StatStyle.fx("crit", "Crit %s (%s chance)" % [StatStyle.num(r.crit), StatStyle.pct(r.crit_chance, 1)])])
	if r.get("has_target", false):
		out.append("  vs %s (after armor): %s · crit %s" % [r.target_name, StatStyle.num(r.noncrit_vs_target), StatStyle.num(r.crit_vs_target)])
	out.append("%s   %s   Time %.2fs" % [StatStyle.labeled("poise", "Poise", StatStyle.num(r.poise)), StatStyle.labeled("stamina", "Stamina", StatStyle.num(r.stamina)), d.startup + d.active + d.recovery])
	out.append(_scaling_text(r))
	if level >= LEVEL_DETAILED:
		out.append(StatStyle.fx("neutral", "Calculation (before crit and armor):"))
		var steps: Array = ["Weapon Power %s" % StatStyle.num(r.weapon_power, 1), "× attack %.2f" % r.attack_mult]
		if absf(r.ctx_mult - 1.0) > 0.0001:
			steps.append("× modifiers %.2f" % r.ctx_mult)
		if r.str_applies:
			steps.append("× %s %.2f (%d %s × %s)" % [StatStyle.stat_tag("str"), r.str_mult, roundi(r.str), "STR", StatStyle.pct(src.stats.b.str_heavy_scale)])
		if r.dex_applies:
			steps.append("× %s %.2f (%d DEX × %s)" % [StatStyle.stat_tag("dex"), r.dex_mult, roundi(r.dex), StatStyle.pct(src.stats.b.dex_multihit_scale)])
		if absf(r.status_mult - 1.0) > 0.0001:
			steps.append("× buffs %.2f" % r.status_mult)
		steps.append("= %s" % StatStyle.num(r.noncrit, 1))
		out.append("  " + " ".join(steps))
		out.append("  %s ×%.2f (base %s + %s %s)" % [StatStyle.fx("crit", "Critical"), r.crit_mult, StatStyle.num(src.stats.crit_damage, 2),
			StatStyle.stat_tag("str"), "+%.1fpp" % (r.str_crit_pp * 100.0)])
		out.append("  Expected per use (with crit chance): %s" % StatStyle.num(r.expected, 1))
		if r.get("has_target", false):
			out.append("  Target mitigation ×%.2f → expected %s" % [r.mitigation, StatStyle.num(r.expected_vs_target, 1)])
	if level >= LEVEL_ADVANCED:
		out.append(StatStyle.fx("neutral", "Advanced:"))
		out.append("  Formula: WeaponPower × %.2f%s%s × buffs, split by hit weight, × crit on a crit roll, × (1 − armor/MR reduction) on the target" % [
			d.damage_mult, " × STR" if r.str_applies else "", " × DEX" if r.dex_applies else ""])
		out.append("  Phases: startup %.2fs · active %.2fs · recovery %.2fs (cancel after %.2fs)%s" % [d.startup, d.active, d.recovery, d.cancel_after, " · dodge-cancel" if d.dodge_cancel else " · no dodge-cancel"])
		var ph: Array = []
		for i in r.per_hit.size():
			ph.append(StatStyle.num(r.per_hit[i], 1))
		out.append("  Hits: %d (%s) · type %s" % [r.hits, " / ".join(ph), dl.trim_suffix(" Damage")])
		out.append("  Poise %s total%s" % [StatStyle.num(r.poise, 1), " · knockback %.1f" % d.knockback if d.knockback > 0.0 else ""])
		if d.poise_armor > 0.0:
			out.append("  Poise armor while attacking: %s" % StatStyle.pct(d.poise_armor))
	return out


static func _spell_lines(s: ChargedSpellData, full: bool, r: Dictionary, src: Dictionary, level: int) -> Array:
	var out: Array = []
	out.append("[u]%s release[/u]  (charge %.2fs)" % ["Full" if full else "Partial", s.full_charge if full else s.min_charge])
	out.append("%s   %s" % [StatStyle.labeled("magic", "Magic Damage", StatStyle.num(r.noncrit)), StatStyle.fx("crit", "Crit %s (%s)" % [StatStyle.num(r.crit), StatStyle.pct(r.crit_chance, 1)])])
	if r.get("has_target", false):
		out.append("  vs %s (after magic resist): %s" % [r.target_name, StatStyle.num(r.noncrit_vs_target)])
	out.append("%s   %s   Recovery %.2fs" % [StatStyle.labeled("poise", "Poise", StatStyle.num(r.poise)), StatStyle.labeled("mana", "Mana", StatStyle.num(r.mana)), r.recovery])
	var jumps := s.chains_full if full else s.chains_partial
	out.append("Scaling: %s" % ((StatStyle.stat_tag("str") + " (full charge only), ") if full else "") + StatStyle.stat_tag("str") + " (critical damage)" + ((", " + StatStyle.stat_tag("dex") + " (chain jumps)") if jumps > 0 else ""))
	if jumps > 0:
		var cp := DamageCalc.chain_power(src.stats, DamageCalc.charged_power(src.stats, s, full), s.chain_falloff, 0)
		out.append("Chain: up to %d jump(s) of %.0fm, first jump %s (×%.2f per jump, × %s %.2f)" % [jumps, s.chain_range, StatStyle.num(src.wp * cp * float(src.get("status_dmg", 1.0))), s.chain_falloff, StatStyle.stat_tag("dex"), src.stats.multihit_mult()])
	if level >= LEVEL_DETAILED:
		var steps := "Weapon Power %s × power %.2f" % [StatStyle.num(r.weapon_power, 1), r.base_power]
		if full:
			steps += " × %s %.2f (%d STR)" % [StatStyle.stat_tag("str"), r.str_mult, roundi(r.str)]
		if absf(r.status_mult - 1.0) > 0.0001:
			steps += " × buffs %.2f" % r.status_mult
		out.append("  %s = %s" % [steps, StatStyle.num(r.noncrit, 1)])
		out.append("  Expected per cast (with crit chance): %s" % StatStyle.num(r.expected, 1))
	if level >= LEVEL_ADVANCED:
		out.append("  Movement while charging %s · radius %.1fm · %s" % [StatStyle.pct(s.move_mult), s.radius_full if full else s.radius_partial,
			s.full_text if full else s.partial_text])
		if s.status_power > 0.0:
			out.append("  Status / area power %.2f × %s %.2f (MAS %d)" % [s.status_power, StatStyle.stat_tag("mas"), src.stats.effect_power(), roundi(src.stats.mastery)])
	return out


static func _heal_lines(s: ChargedSpellData, src: Dictionary, level: int) -> Array:
	var out: Array = []
	var hot := s.id == "verdant_renewal"
	for full in ([false] if s.slot_kind == "emergency" else [false, true]):
		var pw: float = s.power_full if full else s.power_partial
		out.append("")
		out.append("[u]%s[/u]" % ("Cast" if s.slot_kind == "emergency" else ("Full release" if full else "Partial release")))
		if hot:
			var total := DamageCalc.hot_total(src.stats, src.wp, pw)
			var dur := s.duration_full if full else s.duration_partial
			out.append("%s over %.0fs   %s" % [StatStyle.labeled("heal", "Healing", StatStyle.num(total)), dur, StatStyle.labeled("mana", "Mana", StatStyle.num(s.mana_for(full)))])
			out.append("Scaling: %s (heal over time)" % StatStyle.stat_tag("mas"))
			if level >= LEVEL_DETAILED:
				out.append("  Weapon Power %s × power %.2f × %s %.2f (%d MAS × %s) = %s" % [StatStyle.num(src.wp, 1), pw, StatStyle.stat_tag("mas"), src.stats.effect_power(),
					roundi(src.stats.mastery), StatStyle.pct(src.stats.b.mas_effect_scale), StatStyle.num(total, 1)])
		else:
			var amt := DamageCalc.direct_heal(src.wp, pw)
			out.append("%s   %s" % [StatStyle.labeled("heal", "Healing", StatStyle.num(amt)), StatStyle.labeled("mana", "Mana", StatStyle.num(s.mana_for(full)))])
			out.append("Scaling: Weapon Power (level, equipment). Direct heals do not scale with MAS.")
			if level >= LEVEL_DETAILED:
				out.append("  Weapon Power %s × heal power %.2f = %s (overheal beyond missing HP is wasted unless an augment converts it)" % [StatStyle.num(src.wp, 1), pw, StatStyle.num(amt, 1)])
	if level >= LEVEL_ADVANCED:
		out.append("  Charge %.2fs → %.2fs · recovery %.2f / %.2fs · movement while charging %s" % [s.min_charge, s.full_charge, s.recovery_partial, s.recovery_full, StatStyle.pct(s.move_mult)])
	return out


## Before / after values of every damage / heal variant of a class (Character allocation preview).
static func preview_rows(class_id: String, before: ClassProgress, after: ClassProgress) -> Array:
	var a := source_for_progress(class_id, before)
	var z := source_for_progress(class_id, after)
	var rows: Array = []
	for e in SkillCatalog.entries(class_id, before):
		if String(e.get("unlock", "")) != "" and not before.has_unlock(String(e.unlock)) and not e.get("known", false):
			continue
		if e.has("variants"):
			for v in e.variants:
				rows.append({"name": "%s · %s" % [e.name, v.label] if e.variants.size() > 1 else String(e.name), "kind": "physical",
					"before": breakdown_attack(a, v.attack).noncrit, "after": breakdown_attack(z, v.attack).noncrit})
		elif e.has("spell") and e.get("known", false):
			var s: ChargedSpellData = e.spell
			if e.get("heal", false):
				var pw := s.power_full if s.slot_kind != "emergency" else s.power_partial
				var hot := s.id == "verdant_renewal"
				rows.append({"name": s.display_name + (" (full)" if s.slot_kind != "emergency" else ""), "kind": "heal",
					"before": DamageCalc.hot_total(a.stats, a.wp, pw) if hot else DamageCalc.direct_heal(a.wp, pw),
					"after": DamageCalc.hot_total(z.stats, z.wp, pw) if hot else DamageCalc.direct_heal(z.wp, pw)})
			elif s.power_full > 0.0:
				rows.append({"name": s.display_name + " (full)", "kind": "magic", "before": breakdown_spell(a, s, true).noncrit, "after": breakdown_spell(z, s, true).noncrit})
	return rows
