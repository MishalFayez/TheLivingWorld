class_name ItemData
extends Resource
## Equipment item. Bonuses are added to the wearer's StatBlock (see StatBlock.for_class).
## bonus keys: str dex vit for mas armor mres crit critdmg aspd cdr power (weapon power %).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("weapon", "head", "chest", "hands", "feet", "accessory") var slot: String = "weapon"
## "" = any class
@export var class_id: String = ""
@export_enum("standard", "advanced", "exotic") var rarity: String = "standard"
## Visual tier (1 beginner .. 3 elite) — changes the character model.
@export var tier: int = 1
@export var icon: String = "sword"
@export var bonuses: Dictionary = {}
@export var drop_weight: float = 1.0
@export var min_area: int = 0   ## 0 outskirts, 1 ruins, 2 keep


func bonus_lines() -> Array:
	var names := {"str": "STR", "dex": "DEX", "vit": "VIT", "for": "FOR", "mas": "MAS", "armor": "Armor", "mres": "Magic Resist",
		"crit": "Crit Chance", "critdmg": "Crit Damage", "aspd": "Attack Speed", "cdr": "Cooldown Reduction", "power": "Weapon Power"}
	var out: Array = []
	for k in bonuses:
		var v: float = bonuses[k]
		if k in ["crit", "critdmg", "aspd", "cdr", "power"]:
			out.append("%+d%% %s" % [roundi(v * 100), names.get(k, k)])
		else:
			out.append("%+d %s" % [roundi(v), names.get(k, k)])
	return out
