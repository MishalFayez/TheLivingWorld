class_name StatBlock
extends RefCounted
## Primary + secondary stats and the derived formulas. Stat identities follow the design doc:
## STR  -> Heavy / Charged damage + Critical Damage scaling
## DEX  -> combined TOTAL damage of multi-hit attacks (applied once to the total, then split)
## VIT  -> max HP only
## FOR  -> effectiveness of existing Armor / Magic Resistance (0 armor stays 0)
## MAS  -> power of buffs, debuffs, DoT and HoT

var strength: float = 0.0
var dexterity: float = 0.0
var vitality: float = 0.0
var fortitude: float = 0.0
var mastery: float = 0.0
var base_hp: float = 100.0
var crit_chance: float = 0.05
var crit_damage: float = 1.5
var attack_speed: float = 1.0
var cdr: float = 0.0
var armor: float = 0.0
var magic_resist: float = 0.0
var b: BalanceConfig


func _init(balance: BalanceConfig = null) -> void:
	b = balance if balance else Game.balance


static func for_class(class_id: String, p: ClassProgress, balance: BalanceConfig) -> StatBlock:
	var s := StatBlock.new(balance)
	var base: Dictionary = balance.class_base.get(class_id, {})
	var growth: Dictionary = balance.class_growth.get(class_id, {})
	var lv := p.level - 1
	var keys := {"str": "strength", "dex": "dexterity", "vit": "vitality", "for": "fortitude", "mas": "mastery"}
	for k in keys:
		var v: float = float(base.get(k, 5)) + float(growth.get(k, 0)) * lv + float(p.allocated.get(k, 0)) + float(p.debug_bonus.get(k, 0)) + p.equipment_bonus(k)
		s.set(keys[k], v)
	s.base_hp = float(base.get("hp", 150))
	s.crit_chance = float(base.get("crit", 0.05)) + float(p.debug_bonus.get("crit", 0.0)) + p.equipment_bonus("crit")
	s.crit_damage = float(base.get("critdmg", 1.5)) + float(p.debug_bonus.get("critdmg", 0.0)) + p.equipment_bonus("critdmg")
	s.attack_speed = float(base.get("aspd", 1.0)) + float(p.debug_bonus.get("aspd", 0.0)) + p.equipment_bonus("aspd")
	s.cdr = clampf(float(base.get("cdr", 0.0)) + float(p.debug_bonus.get("cdr", 0.0)) + p.equipment_bonus("cdr"), 0.0, 0.6)
	s.armor = float(base.get("armor", 10)) + float(growth.get("armor", 0)) * lv + float(p.debug_bonus.get("armor", 0.0)) + p.equipment_bonus("armor")
	s.magic_resist = float(base.get("mres", 10)) + float(growth.get("mres", 0)) * lv + float(p.debug_bonus.get("mres", 0.0)) + p.equipment_bonus("mres")
	return s


## Copy (COMBAT-BALANCE-UX-006 tooltips: "+1 STR" previews run the real formulas on a copy).
func copy() -> StatBlock:
	var s := StatBlock.new(b)
	for k in ["strength", "dexterity", "vitality", "fortitude", "mastery", "base_hp", "crit_chance", "crit_damage", "attack_speed", "cdr", "armor", "magic_resist"]:
		s.set(k, get(k))
	return s


func max_hp() -> float:
	return base_hp + vitality * b.hp_per_vit


func heavy_mult() -> float:
	return 1.0 + strength * b.str_heavy_scale


func crit_damage_total() -> float:
	return crit_damage + strength * b.str_crit_damage_scale


func multihit_mult() -> float:
	return 1.0 + dexterity * b.dex_multihit_scale


func effective_armor() -> float:
	return armor * (1.0 + fortitude * b.for_defense_scale)


func effective_mres() -> float:
	return magic_resist * (1.0 + fortitude * b.for_defense_scale)


func phys_reduction() -> float:
	var a := effective_armor()
	return a / (a + b.armor_constant)


func magic_reduction() -> float:
	var m := effective_mres()
	return m / (m + b.armor_constant)


func effect_power() -> float:
	return 1.0 + mastery * b.mas_effect_scale


func summary() -> Dictionary:
	return {
		"STR": strength, "DEX": dexterity, "VIT": vitality, "FOR": fortitude, "MAS": mastery,
		"Max HP": max_hp(), "Crit Chance": crit_chance, "Crit Damage": crit_damage_total(),
		"Attack Speed": attack_speed, "CDR": cdr, "Armor": armor, "Eff. Armor": effective_armor(),
		"Magic Resist": magic_resist, "Eff. MR": effective_mres(), "Heavy x": heavy_mult(),
		"Multi-hit total x": multihit_mult(), "Effect power x": effect_power(),
	}
