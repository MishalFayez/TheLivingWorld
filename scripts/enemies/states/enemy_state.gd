class_name EnemyState
extends Node
## Base enemy state. Concrete states are declared in their own files.

var e: Enemy
var sm: EnemyStateMachine
var t: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	t = 0.0


func exit() -> void:
	pass


func physics_update(delta: float) -> void:
	t += delta
