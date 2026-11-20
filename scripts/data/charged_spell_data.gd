class_name ChargedSpellData
extends Resource
## Worldweaver Mage spell (data-driven). Every spell defines its OWN charge behaviour:
## minimum charge before it can release, full-charge time, movement while charging, mana and
## recovery for partial vs full release, and element-specific numbers. There is no universal
## perfect-release window.

@export var id: String = ""
@export var display_name: String = ""
@export_enum("fire", "life", "frost", "storm", "stone") var element: String = "fire"
@export_enum("charged", "instant") var cast_type: String = "charged"
@export_multiline var description: String = ""
@export var partial_text: String = ""
@export var full_text: String = ""
@export var unlock_id: String = ""            ## progression milestone that teaches it ("" = always)
## "charged" (LMB / RMB / 1 slots), "utility" (key 3 slot, quick cast + cooldown), "emergency" (F)
@export_enum("charged", "utility", "emergency") var slot_kind: String = "charged"
## Advanced spells have no level in the approved L1-10 table: only obtainable through Debug grants.
@export var advanced: bool = false
## Creates a world formation / targets a ground location (shows the placement preview).
@export var places_formation: bool = false
@export_group("Charge")
@export var min_charge: float = 0.25          ## seconds before a release is possible (earlier release waits for it)
@export var full_charge: float = 1.0          ## seconds to reach full charge
@export var move_mult: float = 0.6            ## movement speed while charging
@export var root_on_full: float = 0.0         ## extra commitment (rooted) after a full release
@export_group("Cost / recovery")
@export var mana_partial: float = 10.0
@export var mana_full: float = 20.0
@export var recovery_partial: float = 0.3
@export var recovery_full: float = 0.5
@export var cooldown: float = 0.0
@export_group("Effect")
@export var power_partial: float = 1.0        ## damage (x weapon power) or heal amount
@export var power_full: float = 2.0
@export var poise_partial: float = 10.0
@export var poise_full: float = 30.0
@export var radius_partial: float = 0.0
@export var radius_full: float = 0.0
@export var speed_partial: float = 22.0
@export var speed_full: float = 16.0
@export var max_range: float = 24.0
@export var duration_partial: float = 0.0
@export var duration_full: float = 0.0
@export var status_power: float = 0.0
@export var chains_partial: int = 0
@export var chains_full: int = 0
@export var chain_range: float = 8.0
@export var chain_falloff: float = 0.75
@export var width_partial: float = 0.0        ## formation width (m)
@export var width_full: float = 0.0


func mana_for(full: bool) -> float:
	return mana_full if full else mana_partial


func lerp_by(a: float, b: float, ratio: float) -> float:
	return lerpf(a, b, clampf(ratio, 0.0, 1.0))
