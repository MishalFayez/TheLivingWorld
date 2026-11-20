class_name FusionData
extends Resource
## Arcane Weave fusion. `key` is the two element ids sorted alphabetically and joined by "+".

@export var id: String = ""
@export var display_name: String = ""
@export var key: String = ""
@export_multiline var description: String = ""
@export var mana_cost: float = 20.0
@export var power: float = 1.0
@export var heal_power: float = 0.0
@export var radius: float = 5.0
@export var duration: float = 0.0
@export var tick: float = 0.5
@export var poise_damage: float = 0.0
@export var bounces: int = 0
@export var status_power: float = 0.0
@export var status_duration: float = 0.0
