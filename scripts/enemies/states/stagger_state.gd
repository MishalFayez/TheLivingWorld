class_name EnemyStaggerState
extends EnemyState
## Stagger reaction: interrupted, open to punishment until the timer ends.


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	e.runner.interrupt()


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	e.stop_moving(delta)
	if e.stagger_timer <= 0.0:
		e.play_anim("idle")
		sm.change("chase", {"pause": 0.15})
