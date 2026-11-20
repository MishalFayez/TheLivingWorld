class_name EnemyDeadState
extends EnemyState
## Death: collapse, fade, free.


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	e.play_anim("downed")
	if e.bar:
		e.bar.visible = false


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	e.stop_moving(delta)
	if t > 1.6:
		e.queue_free()
