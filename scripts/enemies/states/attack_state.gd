class_name EnemyAttackState
extends EnemyState
## Executes an attack (telegraph -> active -> recovery window) and follows combo chains.

var attack: AttackData
var finished_flag: bool = false


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	attack = msg.get("attack")
	finished_flag = false
	if not e.runner.finished.is_connected(_on_finished):
		e.runner.finished.connect(_on_finished)
	e.begin_attack(attack)


func exit() -> void:
	if e.runner.finished.is_connected(_on_finished):
		e.runner.finished.disconnect(_on_finished)


func _on_finished(d: AttackData, _ctx: Dictionary, interrupted: bool) -> void:
	if interrupted or sm.current != self:
		return
	if d.chain_next != "" and randf() < e.chain_chance and e.target != null and is_instance_valid(e.target) and e.target.is_targetable() and e.dist_to_target() < d.ai_range.y + 2.5:
		var nxt := e.find_attack(d.chain_next)
		if nxt:
			attack = nxt
			e.begin_attack(nxt)
			return
	finished_flag = true


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	if finished_flag:
		sm.change("chase", {"pause": e.post_attack_pause()})
	elif not e.runner.is_busy() and t > 0.2 and not finished_flag:
		sm.change("chase")
