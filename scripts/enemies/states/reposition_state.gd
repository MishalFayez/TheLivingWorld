class_name EnemyRepositionState
extends EnemyState
## Back away to preferred range (Ash Caster distancing, boss spacing).


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	if e.target == null or not is_instance_valid(e.target):
		sm.change("idle")
		return
	var away: Vector3 = e.global_position - e.target.global_position
	away.y = 0
	e.move_dir(away, delta, 0.9)
	e.turn_toward(-away, e.turn_speed, delta)
	var atk = e.choose_attack()
	if t > 0.6 and atk != null and atk.ai_range.y > 4.0:
		sm.change("attack", {"attack": atk})
		return
	if e.dist_to_target() >= e.preferred_range or t > 2.0:
		sm.change("chase")
