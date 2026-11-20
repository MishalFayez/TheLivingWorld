extends Node
## Lock-on screenshots (renderer required).
func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/%s.png" % n)
	print("saved ", n)
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.1)
	main.start_game("reaver", false)
	Game.invincible = true
	Game.auto_open_drafts = false
	for area in Game.world.zones:
		for z in Game.world.zones[area]:
			z.done = true
	await wait(0.3)
	var h := Game.player
	h.teleport(Vector3(0, 0.2, 22))
	h.get_node("Brain").rig.snap_to_target()
	for i in 5:
		var e := Game.spawn_enemy(["wolf", "raider", "shield_guardian", "raider", "ash_caster"][i], h.global_position + Vector3(-6 + i * 3, 0.3, -9), "outskirts", i == 3)
		e.sm.set_physics_process(false)
	await wait(0.4)
	var lock: LockOnSystem = h.get_node("Brain").lock
	lock.acquire()
	await wait(1.0)
	await shot("12_lock_on")
	lock.switch(1)
	await wait(0.08)
	await shot("13_lock_switching")
	await wait(1.0)
	await shot("14_lock_switched")
	get_tree().quit()
