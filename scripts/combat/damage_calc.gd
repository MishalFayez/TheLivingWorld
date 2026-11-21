class_name DamageCalc
extends RefCounted
## LEVEL10-FOUNDATION-005 (Part 8.4): the SINGLE source of the deterministic damage / healing / Poise math.
## Combatant.build_damage and Combatant.spell_damage call these functions for their numbers, and every
## tooltip, Skills-menu breakdown and before/after preview reads the same functions. UI code never
## re-implements a formula.
##
## Randomness (the crit roll) and conditional runtime hooks (kit modify_outgoing, situational crit from
## the live target) are NOT part of these numbers; breakdowns report them as "conditional".


## Deterministic part of ONE hit of an AttackData attack. `status_dmg` is the attacker's
## statuses.mult("damage_dealt"); `status_poise` its statuses.mult("poise_damage").
static func attack_hit(stats: StatBlock, weapon_power: float, d: AttackData, idx: int, ctx: Dictionary,
		status_dmg: float = 1.0, status_poise: float = 1.0) -> Dictionary:
	var hit_count := maxi(1, d.hits)
	var weight := 1.0 / float(hit_count)
	if d.hit_weights.size() == hit_count:
		weight = d.hit_weights[idx]
	var total := weapon_power * d.damage_mult * float(ctx.get("damage_mult", 1.0))
	if d.is_heavy or d.is_charged:
		total *= stats.heavy_mult()          # STR: heavy & charged damage
	if d.hits > 1 and not d.has_tag("single_impact_scaling"):
		total *= stats.multihit_mult()       # DEX: combined total of multi-hit attacks
	total *= status_dmg
	var cc := stats.crit_chance + d.crit_chance_bonus + float(ctx.get("crit_chance_bonus", 0.0))
	var cd := stats.crit_damage_total() + d.crit_damage_bonus + float(ctx.get("crit_damage_bonus", 0.0))
	if idx == hit_count - 1:
		cd += d.final_hit_crit_damage_bonus
	return {
		"amount": total * weight, "weight": weight, "crit_chance": cc, "crit_mult": cd,
		"poise": d.poise_damage * weight * float(ctx.get("poise_mult", 1.0)) * status_poise,
	}


## Full breakdown of an attack for tooltips (all hits). `target` (optional Combatant) adds mitigation.
static func attack_breakdown(stats: StatBlock, weapon_power: float, d: AttackData, ctx: Dictionary = {},
		target = null, status_dmg: float = 1.0, status_poise: float = 1.0) -> Dictionary:
	var hit_count := maxi(1, d.hits)
	var str_on := d.is_heavy or d.is_charged
	var dex_on := d.hits > 1 and not d.has_tag("single_impact_scaling")
	var out := {
		"name": d.display_name, "type": "physical" if d.damage_type == AttackData.DamageType.PHYSICAL else "magic",
		"weapon_power": weapon_power, "attack_mult": d.damage_mult, "ctx_mult": float(ctx.get("damage_mult", 1.0)),
		"str_applies": str_on, "str_mult": stats.heavy_mult() if str_on else 1.0, "str": stats.strength,
		"dex_applies": dex_on, "dex_mult": stats.multihit_mult() if dex_on else 1.0, "dex": stats.dexterity,
		"status_mult": status_dmg, "hits": hit_count, "per_hit": [], "per_hit_crit": [],
		"crit_chance": 0.0, "crit_mult": stats.crit_damage_total(), "str_crit_pp": stats.strength * stats.b.str_crit_damage_scale,
		"noncrit": 0.0, "crit": 0.0, "expected": 0.0, "poise": 0.0,
		"stamina": d.stamina_cost, "startup": d.startup, "active": d.active, "recovery": d.recovery,
		"charge_time": d.charge_time,
	}
	for i in hit_count:
		var h := attack_hit(stats, weapon_power, d, i, ctx, status_dmg, status_poise)
		out.per_hit.append(h.amount)
		out.per_hit_crit.append(h.amount * h.crit_mult)
		out.noncrit += h.amount
		out.crit += h.amount * h.crit_mult
		var cc := clampf(h.crit_chance, 0.0, 1.0)
		out.expected += h.amount * (1.0 + cc * (h.crit_mult - 1.0))
		out.poise += h.poise
		out.crit_chance = h.crit_chance
		if i == hit_count - 1:
			out.crit_mult = h.crit_mult
	out["pre_status"] = out.noncrit / maxf(status_dmg, 0.0001)
	_add_mitigation(out, target)
	return out


## Deterministic part of a spell / projectile / AoE hit (Combatant.spell_damage).
static func spell_hit(stats: StatBlock, weapon_power: float, power: float, crit_bonus: float, status_dmg: float = 1.0) -> Dictionary:
	return {"amount": weapon_power * power * status_dmg, "crit_chance": stats.crit_chance + crit_bonus, "crit_mult": stats.crit_damage_total()}


## Charged-spell "power" coefficient exactly as the Worldweaver applies it (MageElementalist.dmg_power):
## STR scales the FULL release of damage spells only.
static func charged_power(stats: StatBlock, s: ChargedSpellData, full: bool) -> float:
	return s.power_full * stats.heavy_mult() if full else s.power_partial


static func spell_breakdown(stats: StatBlock, weapon_power: float, s: ChargedSpellData, full: bool, target = null,
		status_dmg: float = 1.0) -> Dictionary:
	var power := charged_power(stats, s, full)
	var h := spell_hit(stats, weapon_power, power, 0.0, status_dmg)
	var out := {
		"name": s.display_name, "type": "magic", "full": full, "weapon_power": weapon_power,
		"base_power": s.power_full if full else s.power_partial, "str_applies": full, "str_mult": stats.heavy_mult() if full else 1.0,
		"str": stats.strength, "dex_applies": false, "dex_mult": 1.0, "status_mult": status_dmg, "hits": 1,
		"crit_chance": h.crit_chance, "crit_mult": h.crit_mult, "noncrit": h.amount, "crit": h.amount * h.crit_mult,
		"expected": h.amount * (1.0 + clampf(h.crit_chance, 0.0, 1.0) * (h.crit_mult - 1.0)),
		"poise": s.poise_full if full else s.poise_partial, "mana": s.mana_for(full),
		"charge": s.full_charge if full else s.min_charge, "recovery": s.recovery_full + s.root_on_full if full else s.recovery_partial,
	}
	_add_mitigation(out, target)
	return out


## Direct heal amount (MageElementalist._bloom / lifeline): weapon power x heal power. Direct heals do
## NOT scale with MAS in the current game; heal-over-time effects do (StatusEffect.scaled_by).
static func direct_heal(weapon_power: float, power: float) -> float:
	return weapon_power * power


static func hot_total(stats: StatBlock, weapon_power: float, power: float) -> float:
	return weapon_power * power * stats.effect_power()


## Mitigation exactly as Combatant.take_damage applies it (armor / MR with FOR, damage_taken status).
static func mitigation_mult(target, magic: bool) -> float:
	if target == null or not is_instance_valid(target) or target.stats == null:
		return 1.0
	var red: float = target.stats.magic_reduction() if magic else target.stats.phys_reduction()
	return (1.0 - red) * target.statuses.mult("damage_taken")


static func _add_mitigation(out: Dictionary, target) -> void:
	out["has_target"] = target != null and is_instance_valid(target)
	if not out.has_target:
		return
	var m := mitigation_mult(target, out.type == "magic")
	out["target_name"] = target.display_name
	out["mitigation"] = m
	out["noncrit_vs_target"] = out.noncrit * m
	out["crit_vs_target"] = out.crit * m
	out["expected_vs_target"] = out.expected * m


## Breakdown for a Combatant source (live hero or enemy).
static func for_combatant(src, d: AttackData, ctx: Dictionary = {}, target = null) -> Dictionary:
	return attack_breakdown(src.stats, src.weapon_power, d, ctx, target, src.statuses.mult("damage_dealt"), src.statuses.mult("poise_damage"))


## Breakdown for a ClassProgress (no live hero needed; menus / previews). No statuses.
static func for_progress(class_id: String, p: ClassProgress, d: AttackData, ctx: Dictionary = {}) -> Dictionary:
	var s := StatBlock.for_class(class_id, p, Game.balance)
	return attack_breakdown(s, StatPreview.weapon_power(class_id, p), d, ctx)
