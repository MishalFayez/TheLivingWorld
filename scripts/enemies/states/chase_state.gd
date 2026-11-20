class_name EnemyChaseState
extends EnemyState
## Pursue the highest-threat hero via NavigationAgent3D. Once an attack is available the enemy
## hesitates (engage delay, strafing) and needs an attack token before committing — so packs
## take turns instead of piling on, and the player can read who is about to swing.

var pause: float = 0.0
var retarget_t: float = 0.0
var pending = null
var engage_t: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	pause = float(msg.get("pause", 0.0))
	pending = null
	engage_t = 0.0


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	retarget_t -= delta
	if retarget_t <= 0.0:
		retarget_t = 0.3
		e.update_target(0.3)
	if e.target == null:
		sm.change("idle")
		return
	var dist := e.dist_to_target()
	if pause > 0.0:
		pause -= delta
		if dist < 6.0:
			e.strafe(delta, 0.3)
		else:
			e.stop_moving(delta)
			e.turn_toward(e.dir_to_target(), e.turn_speed * 0.5, delta)
		return
	if pending != null and (dist < pending.ai_range.x or dist > pending.ai_range.y):
		pending = null
	if pending == null:
		pending = e.choose_attack()
	if pending != null:
		if e.may_attack():
			engage_t += delta
		if engage_t >= e.next_engage:
			var atk = pending
			pending = null
			engage_t = 0.0
			e.roll_engage()
			sm.change("attack", {"attack": atk})
			return
		e.strafe(delta, 0.35)
		return
	if e.preferred_range > 0.0 and dist < e.preferred_range * 0.6:
		sm.change("reposition")
		return
	if e.custom_chase(delta):
		return
	var stop := 1.6 if e.preferred_range <= 0.0 else e.preferred_range
	if dist > stop:
		# run when far, walk in deliberately when close
		e.move_to(e.target.global_position, delta, 1.0 if dist > 5.5 else 0.6)
	else:
		e.stop_moving(delta)
		e.turn_toward(e.dir_to_target(), e.turn_speed, delta)
