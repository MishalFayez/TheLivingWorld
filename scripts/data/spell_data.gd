class_name SpellData
extends Resource
## A Mage spell. Every element has a quick and a charged spell; behaviour is selected by `id`
## in MageKit, tuning values live here.

@export var id: String = ""
@export var display_name: String = ""
@export_enum("fire", "life", "frost", "storm", "stone") var element: String = "fire"
@export var charged: bool = false
@export var mana_cost: float = 10.0
@export var cast_time: float = 0.3
@export var recovery: float = 0.3
@export var power: float = 1.0
@export var radius: float = 0.0
@export var speed: float = 20.0
@export var max_range: float = 22.0
@export var poise_damage: float = 10.0
@export var status_duration: float = 0.0
@export var status_power: float = 0.0
@export var bounces: int = 0
@export var delay: float = 0.0
@export_multiline var description: String = ""
