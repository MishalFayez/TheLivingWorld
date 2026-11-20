class_name EnemyStateMachine
extends Node
## Node-based finite state machine. Each state is a child node (EnemyState subclass).

var e: Enemy
var states: Dictionary = {}
var current: EnemyState
var current_name: String = ""


func setup(enemy: Enemy) -> void:
	e = enemy
	_add("idle", EnemyIdleState.new())
	_add("chase", EnemyChaseState.new())
	_add("attack", EnemyAttackState.new())
	_add("reposition", EnemyRepositionState.new())
	_add("stagger", EnemyStaggerState.new())
	_add("dead", EnemyDeadState.new())
	for extra in e.extra_states():
		_add(extra[0], extra[1])
	change("idle")


func _add(n: String, s: EnemyState) -> void:
	s.name = n.capitalize()
	s.e = e
	s.sm = self
	add_child(s)
	states[n] = s


func change(n: String, msg: Dictionary = {}) -> void:
	if current_name == "dead":
		return
	if not states.has(n):
		push_warning("Unknown enemy state " + n)
		return
	if current:
		current.exit()
	current = states[n]
	current_name = n
	current.enter(msg)


func _physics_process(delta: float) -> void:
	if e == null or e.hitstop > 0.0 or current == null:
		return
	current.physics_update(delta)
