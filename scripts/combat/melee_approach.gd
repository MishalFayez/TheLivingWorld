class_name MeleeApproach
extends RefCounted
## Distance-aware melee attack movement (reusable; enabled per attack via AttackData.approach_*).
##   target already inside effective range          -> no movement
##   target slightly outside (gap <= approach_max)  -> short step during STARTUP, stops at range
##   target far outside (gap > approach_max * far)  -> no movement (no auto-dash / teleport)
## Uses the lock-on target when available, otherwise the best enemy inside a narrow cone of the
## attack direction. Movement runs through move_and_slide, so collisions (enemies, walls) stop it.

const FAR_FACTOR := 1.5
const CONE_DEG := 45.0
const MIN_GAP := 0.15

var active: bool = false
var target = null
var remaining: float = 0.0
var speed: float = 0.0
var stop_range: float = 1.6
var gap: float = 0.0
var reason: String = "disabled"


static func plan(attacker, d: AttackData, lock_target, aim_dir: Vector3, attack_speed: float) -> MeleeApproach:
	var m := MeleeApproach.new()
	if d.approach_max <= 0.0:
		return m
	var tgt = null
	if lock_target != null and is_instance_valid(lock_target) and lock_target.is_targetable():
		tgt = lock_target
	else:
		tgt = _cone_target(attacker, aim_dir, d.approach_range + d.approach_max * FAR_FACTOR + 0.5)
	if tgt == null:
		m.reason = "no target"
		return m
	m.target = tgt
	m.stop_range = d.approach_range
	m.gap = _flat_dist(attacker, tgt) - d.approach_range
	if m.gap <= MIN_GAP:
		m.reason = "in range"
		return m
	if m.gap > d.approach_max * FAR_FACTOR:
		m.reason = "too far"
		return m
	m.active = true
	m.reason = "step"
	m.remaining = minf(m.gap, d.approach_max)
	var window := maxf(d.startup * d.approach_window / maxf(attack_speed, 0.1), 0.05)
	m.speed = m.remaining / window
	return m


static func _flat_dist(a, b) -> float:
	var v: Vector3 = b.global_position - a.global_position
	v.y = 0
	return v.length()


static func _cone_target(attacker, aim_dir: Vector3, max_dist: float):
	var fwd := Vector3(aim_dir.x, 0, aim_dir.z)
	if fwd.length_squared() < 0.001:
		fwd = attacker.forward()
	fwd = fwd.normalized()
	var best = null
	var best_d := INF
	var group := "enemies" if attacker.team == 0 else "heroes"
	for e in attacker.get_tree().get_nodes_in_group(group):
		if not e.is_targetable():
			continue
		var to: Vector3 = e.global_position - attacker.global_position
		to.y = 0
		var dist := to.length()
		if dist > max_dist or dist < 0.01:
			continue
		if rad_to_deg(fwd.angle_to(to / dist)) > CONE_DEG:
			continue
		if dist < best_d:
			best_d = dist
			best = e
	return best


## Called every physics frame while the attack is in STARTUP. Returns the approach velocity.
func step(attacker, delta: float) -> Vector3:
	if not active:
		return Vector3.ZERO
	if target == null or not is_instance_valid(target) or not target.is_targetable():
		active = false
		return Vector3.ZERO
	var to: Vector3 = target.global_position - attacker.global_position
	to.y = 0
	var dist := to.length()
	if dist <= stop_range or remaining <= 0.0:
		active = false
		return Vector3.ZERO
	var move := minf(speed * delta, remaining)
	remaining -= move
	attacker.turn_toward(to, 14.0, delta)
	# never overshoot the stop range in this frame (no sliding into / through the target)
	var v := minf(speed, (dist - stop_range) / maxf(delta, 0.001))
	return to / dist * maxf(v, 0.0)
