class_name PlayerBrain
extends Node
## Translates keyboard / mouse into hero intents. All gameplay goes through Hero.press/release,
## exactly like the AI brains, so player and AI share one combat implementation.
## Owns the CameraRig (sole camera authority) and the LockOnSystem.

const ACTIONS := ["light", "heavy", "dodge", "guard", "blade_modifier", "life", "core", "skill1", "skill2", "skill3", "heal_target"]

var hero: Hero
var rig: CameraRig
var lock: LockOnSystem


func _ready() -> void:
	hero = get_parent()
	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.target = hero
	Game.world.add_child.call_deferred(rig)
	lock = LockOnSystem.new()
	lock.name = "LockOn"
	lock.setup(hero, rig)
	add_child(lock)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if is_instance_valid(rig):
		rig.queue_free()


func _input_allowed() -> bool:
	return Game.ui_block == 0 and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")


## Lock-on + target switching are event based (mouse-wheel "presses" are instantaneous and would be
## missed by polling). These actions are separate from every weapon / item action.
func _unhandled_input(event: InputEvent) -> void:
	if hero == null or not _input_allowed() or hero.downed:
		return
	if event.is_action_pressed("lock_on"):
		lock.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lock_switch_right"):
		if lock.is_locked():
			lock.switch(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lock_switch_left"):
		if lock.is_locked():
			lock.switch(-1)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(rig):
		return
	if not _input_allowed():
		hero.move_input = Vector3.ZERO
		for a in ACTIONS:
			if hero.is_held(a):
				hero.release(a)
		return
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	hero.strafe_axis = v.x      # raw left/right intent (A/D or stick), for directional attacks
	hero.move_input = (rig.flat_right() * v.x - rig.flat_forward() * v.y)
	if hero.move_input.length() > 1.0:
		hero.move_input = hero.move_input.normalized()
	for a in ACTIONS:
		if Input.is_action_just_pressed(a):
			hero.press(a)
		elif Input.is_action_just_released(a):
			hero.release(a)
	if Input.is_action_just_pressed("interact") and Game.world and Game.world.has_method("try_interact"):
		Game.world.try_interact(hero)
	if Input.is_action_pressed("revive"):
		hero.try_revive(delta)
	else:
		hero.revive_target = null
