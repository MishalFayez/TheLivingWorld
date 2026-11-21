class_name StatPreview
extends RefCounted
## Stat allocation previews computed from the REAL formulas (StatBlock.for_class + the hero's
## weapon-power formula). The Character screen shows before -> after for every derived value.

const STAT_KEYS := ["str", "dex", "vit", "for", "mas"]
const STAT_NAMES := {"str": "Strength", "dex": "Dexterity", "vit": "Vitality", "for": "Fortitude", "mas": "Mastery"}
const STAT_ROLE := {
	"str": "Heavy & charged damage, critical damage",
	"dex": "Combined damage of multi-hit attacks",
	"vit": "Maximum health",
	"for": "Effectiveness of armor & magic resist",
	"mas": "Power of healing, shields, statuses",
}


static func weapon_power(class_id: String, p: ClassProgress) -> float:
	var b := Game.balance
	return float(b.class_base.get(class_id, {}).get("power", 20.0)) * (1.0 + b.weapon_power_per_level * (p.level - 1)) * (1.0 + p.equipment_bonus("power"))


static func derived(class_id: String, p: ClassProgress) -> Dictionary:
	var s := StatBlock.for_class(class_id, p, Game.balance)
	return {
		"STR": s.strength, "DEX": s.dexterity, "VIT": s.vitality, "FOR": s.fortitude, "MAS": s.mastery,
		"Max HP": s.max_hp(),
		"Weapon Power": weapon_power(class_id, p),
		"Heavy Damage": s.heavy_mult(),
		"Crit Chance": s.crit_chance,
		"Crit Damage": s.crit_damage_total(),
		"Multi-hit Total": s.multihit_mult(),
		"Physical Reduction": s.phys_reduction(),
		"Magic Reduction": s.magic_reduction(),
		"Effect Power": s.effect_power(),
		"Attack Speed": s.attack_speed,
		"Cooldown Reduction": s.cdr,
	}


## Format a derived value for display.
static func fmt(key: String, v: float) -> String:
	match key:
		"Crit Chance", "Physical Reduction", "Magic Reduction", "Cooldown Reduction":
			return "%.1f%%" % (v * 100.0)
		"Heavy Damage", "Crit Damage", "Multi-hit Total", "Effect Power", "Attack Speed":
			return "x%.2f" % v
		"Max HP", "Weapon Power":
			return "%d" % roundi(v)
	return "%d" % roundi(v)


static func clone(p: ClassProgress) -> ClassProgress:
	var c := ClassProgress.new(p.class_id)
	c.from_dict(p.to_dict().duplicate(true))
	c.debug_bonus = p.debug_bonus.duplicate()
	return c


## Derived values if `pending` ({stat: points}) were allocated on top of the current allocation.
static func with_pending(class_id: String, p: ClassProgress, pending: Dictionary) -> Dictionary:
	return derived(class_id, clone_with_pending(p, pending))


static func clone_with_pending(p: ClassProgress, pending: Dictionary) -> ClassProgress:
	var c := clone(p)
	for k in pending:
		c.allocated[k] = int(c.allocated.get(k, 0)) + int(pending[k])
	return c


## Derived values if `item_id` were equipped instead of the current item in its slot.
static func with_item(class_id: String, p: ClassProgress, item_id: String) -> Dictionary:
	var c := clone(p)
	var it = Game.item(item_id)
	if it:
		c.equipment[it.slot] = item_id
	return derived(class_id, c)
