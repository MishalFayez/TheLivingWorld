class_name AttackData
extends Resource
## Data-driven attack definition used by heroes AND enemies.
## All timings are seconds at Attack Speed 1.0 (runner scales them by attack speed).
## damage_mult / poise_damage are TOTALS for the whole attack (multi-hit attacks split them across hits).

enum DamageType { PHYSICAL, MAGIC }

@export var id: String = ""
@export var display_name: String = ""
@export_enum("slash_h", "slash_v", "thrust", "spin", "rising", "bash", "flurry", "slam", "cast", "lunge", "bite", "sweep", "ff_pursuit_slash", "ff_counter", "bd_neutral", "bd_forward", "bd_lateral_l", "bd_lateral_r", "bd_precision", "bd_committed", "bd_orbit", "bd_withdraw", "bd_whirl", "bd_break", "bd_relentless", "bd_twin") var anim_style: String = "slash_h"

@export_group("Timing")
@export var startup: float = 0.2
@export var active: float = 0.12
@export var recovery: float = 0.3
## Seconds into RECOVERY after which another attack may cancel this one.
@export var cancel_after: float = 0.15
## Dodge may cancel recovery at any time.
@export var dodge_cancel: bool = true

@export_group("Damage")
@export var damage_mult: float = 1.0
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var poise_damage: float = 10.0
@export var hits: int = 1
## Optional per-hit weights (sum should be 1.0). Empty = even split.
@export var hit_weights: PackedFloat32Array = PackedFloat32Array()
@export var final_hit_heavy: bool = false
@export var final_hit_crit_damage_bonus: float = 0.0
@export var is_heavy: bool = false
@export var is_charged: bool = false
@export var crit_chance_bonus: float = 0.0
@export var crit_damage_bonus: float = 0.0
@export var guard_break: bool = false
@export var threat_mult: float = 1.0
@export var hitstop: float = 0.05
@export var knockback: float = 2.0
## If > 0, a successful hit forces this stagger duration on non-boss targets (launch / heavy impact).
@export var stagger_on_hit: float = 0.0

@export_group("Hitbox")
@export var hitbox_size: Vector3 = Vector3(2.0, 1.6, 1.8)
@export var hitbox_offset: Vector3 = Vector3(0, 1.0, -1.3)

@export_group("Movement & Cost")
@export var stamina_cost: float = 10.0
## Forward speed applied during the ACTIVE window.
@export var lunge: float = 0.0
## Fraction of normal move speed allowed while the attack runs (Flowing Edge etc).
@export var move_during: float = 0.0
## Frontal damage reduction while the attack runs (Unyielding Charge, Guarded Sweep).
@export var frontal_guard: float = 0.0
## Poise damage reduction while attacking (hyper armor / commitment).
@export var poise_armor: float = 0.0
## Distance-aware approach step (MeleeApproach). 0 = disabled.
@export var approach_max: float = 0.0
## Desired distance (centre to centre) to stop at — effective weapon range.
@export var approach_range: float = 1.6
## Fraction of STARTUP used to cover the step.
@export var approach_window: float = 0.85
@export var charge_time: float = 0.0
@export var charge_damage_bonus: float = 0.0
@export var charge_poise_bonus: float = 0.0

@export_group("Tags")
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Enemy AI")
@export var ai_range: Vector2 = Vector2(0.0, 2.5)
@export var ai_weight: float = 1.0
@export var ai_cooldown: float = 0.0
@export var ai_min_phase: int = 1
@export var chain_next: String = ""
## Enemy preparation (STARTUP) that Lightning Verdict may cancel. Must be set explicitly per attack.
@export var interruptible: bool = false
## COMBAT-BALANCE-UX-006: enemy attack commitment (fractions of STARTUP).
##   0 .. track_full   early telegraph: full tracking (turn_speed x track_rate)
##   track_full .. commit_at   late telegraph: tracking fades linearly to 0
##   commit_at .. impact / active   committed: the direction is locked (lunges keep moving along it)
@export var track_full: float = 0.4
@export var commit_at: float = 0.7
@export var track_rate: float = 0.6
@export var telegraph_color: Color = Color(1.0, 0.15, 0.1, 0.5)
## Free-form hook consumed by enemy/boss scripts (projectile, ground_burst, burning_ground, execution...).
@export var special: String = ""


func total_time() -> float:
	return startup + active + recovery


func has_tag(t: String) -> bool:
	return tags.has(t)


func add_tag(t: String) -> void:
	if tags.has(t):
		return
	var arr := tags
	arr.append(t)
	tags = arr


func remove_tag(t: String) -> void:
	var arr := PackedStringArray()
	for x in tags:
		if x != t:
			arr.append(x)
	tags = arr


func clone() -> AttackData:
	return duplicate(true) as AttackData


func anim_key() -> String:
	return "atk_%d" % ("%s|%.3f|%.3f|%.3f|%d" % [anim_style, startup, active, recovery, hits]).hash()
