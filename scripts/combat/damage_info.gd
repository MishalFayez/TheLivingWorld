class_name DamageInfo
extends RefCounted
## One damage event travelling from attacker to defender. Defensive systems mutate `amount`
## (guard, barrier, armor), and the results are written back for logging / augment hooks.

var source = null
var target = null
var attack: AttackData = null
var attack_name: String = ""
var damage_type: int = AttackData.DamageType.PHYSICAL
var raw_amount: float = 0.0
var amount: float = 0.0
var poise: float = 0.0
var is_crit: bool = false
var is_heavy: bool = false
var guard_break: bool = false
var is_projectile: bool = false
var is_dot: bool = false
var hit_index: int = 0
var hit_count: int = 1
var hitstop: float = 0.0
var knockback: float = 0.0
var threat_mult: float = 1.0
var stagger_on_hit: float = 0.0
var source_pos: Vector3 = Vector3.ZERO
var forced_guard: bool = false
var tags: Dictionary = {}

# results
var cancelled: bool = false
var final_amount: float = 0.0
var guarded: bool = false
var perfect: bool = false
var dodged: bool = false
var absorbed: float = 0.0
var intercepted: bool = false
var blocked_frontal: bool = false
var killed: bool = false
var staggered: bool = false


func copy() -> DamageInfo:
	var d := DamageInfo.new()
	for prop in ["source", "target", "attack", "attack_name", "damage_type", "raw_amount", "amount", "poise", "is_crit",
			"is_heavy", "guard_break", "is_projectile", "is_dot", "hit_index", "hit_count", "hitstop", "knockback",
			"threat_mult", "stagger_on_hit", "source_pos", "forced_guard"]:
		d.set(prop, get(prop))
	d.tags = tags.duplicate()
	return d
