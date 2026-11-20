class_name SkillData
extends Resource
## An active skill (Vanguard uses three equipped skills drafted from a larger pool).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var class_id: String = "vanguard"
@export_enum("standard", "advanced", "exotic") var rarity: String = "standard"
@export var shared: bool = false
@export var cooldown: float = 6.0
@export var attack: AttackData
## Contextual variation attack (interception rush, riposte, guarded sweep ...).
@export var alt_attack: AttackData
@export var resolve_cost: float = 30.0
@export var chargeable: bool = false
@export var variations: PackedStringArray = PackedStringArray()
