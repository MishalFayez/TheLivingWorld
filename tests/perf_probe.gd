extends Node
## Rendering load probe: object / primitive / draw-call counts and frame time in a party fight.
func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame
func _ready() -> void:
	Save.enabled = false
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.2)
	main.start_game("mage", true)
	Game.invincible = true
	Game.auto_open_drafts = false
	for i in 8:
		Game.spawn_enemy(["wolf", "raider", "ash_caster", "shield_guardian"][i % 4], Game.player.global_position + Vector3(randf_range(-6, 6), 0.3, -8 - randf_range(0, 5)), "outskirts")
	await wait(1.0)
	var t0 := Time.get_ticks_usec()
	var frames := 0
	var worst := 0.0
	var last := t0
	while Time.get_ticks_usec() - t0 < 2_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var sec := (Time.get_ticks_usec() - t0) / 1e6
	print("PERF frames %d in %.1fs -> avg %.2f ms (worst %.1f ms)" % [frames, sec, sec * 1000.0 / frames, worst])
	print("PERF objects %d  primitives %d  draw calls %d  nodes %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	print("PERF process %.2f ms  physics %.2f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	Game.world.decor.visible = false
	await wait(0.3)
	print("PERF no-decor objects %d  primitives %d  draw calls %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit()
