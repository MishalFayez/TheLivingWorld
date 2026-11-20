class_name ElementalStates
extends RefCounted
## WORLDWEAVER Elemental States (spec section 11). They describe the REAL condition of a target or
## formation; they are not stacks collected for a finisher.
##
##   burning          combatant  status "burn" (Magic DoT) / standing in a burning area
##   chill            combatant  status "chill" (movement + attack speed reduction)
##   frozen_structure formation  every alive Frost formation
##   conductive       formation  Stone formation that can relay Storm (granted explicitly only)
##   fortified        formation  defensive Stone formation (Stone Ward, Rising Pillar, Sanctum stone)
##   vitalized        formation  Living Bastion recovery pulses (timed)
##
## Application: apply_* functions (source + duration). Expiration: StatusEffect timers (combatants),
## WorldFormation.states expiry times (formations). Cleanup: removed with the status / formation.

const COMBATANT_STATES := ["burning", "chill"]
const FORMATION_STATES := ["frozen_structure", "conductive", "fortified", "vitalized"]


static func apply_burning(target, source, duration: float, dps_power: float) -> void:
	if not is_instance_valid(target) or target.dead:
		return
	# dps_power 0 = state marker only (e.g. standing in a burning area that deals its own damage)
	var st := StatusEffect.make("burn", "Burning", "dot" if dps_power > 0.0 else "debuff", duration, {}, source.weapon_power * dps_power, 1.0)
	st.source = source
	target.statuses.add(st.scaled_by(source.stats.effect_power()))


static func apply_chill(target, source, duration: float, slow: float) -> void:
	if not is_instance_valid(target) or target.dead:
		return
	var s := maxf(slow, 0.85) if target.is_boss else slow
	var st := StatusEffect.make("chill", "Chill", "debuff", duration, {"move_speed": s, "attack_speed": lerpf(1.0, s, 0.4)})
	st.source = source
	target.statuses.add(st.scaled_by(source.stats.effect_power()))


static func combatant_states(target) -> Array:
	var out: Array = []
	if not is_instance_valid(target):
		return out
	for e in target.statuses.effects:
		if e.id == "burn" and not out.has("burning"):
			out.append("burning")
		elif e.id == "chill" and not out.has("chill"):
			out.append("chill")
	return out


static func has(target, state: String) -> bool:
	if target is WorldFormation:
		return target.has_state(state)
	return combatant_states(target).has(state)


static func describe(target) -> String:
	if target is WorldFormation:
		return target.describe()
	return "%s: %s" % [target.display_name, ", ".join(combatant_states(target)) if not combatant_states(target).is_empty() else "-"]
