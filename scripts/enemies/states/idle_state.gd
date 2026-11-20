class_name EnemyIdleState
extends EnemyState
## Wait at home, scan for heroes (proximity or threat).

var scan_t: float = 0.0


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	e.stop_moving(delta)
	scan_t -= delta
	if scan_t <= 0.0:
		scan_t = 0.25
		e.update_target(0.25)
		if e.target != null:
			sm.change("chase")
			return
	if e.global_position.distance_to(e.home_position) > 2.0:
		e.move_to(e.home_position, delta, 0.6)
