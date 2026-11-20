extends Node
## Screenshots of the refoundation features from the real game scene.
var main


func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/refound_%s.png" % n)


func _ready() -> void:
	Save.enabled = false
	Game.reset_all_progress()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.3)
	main.start_game("reaver", true, true)
	Game.invincible = true
	Game.auto_open_drafts = false
	for h in Game.heroes:
		if h != Game.player:
			h.get_node("Brain").set_physics_process(false)
	await wait(0.5)
	var p = Game.player
	# 1. guided scenario R1 + lateral cut
	GuidedPlaytest.start("R1")
	await wait(0.6)
	var r = Game.enemies().filter(func(x): return x.enemy_type == "raider")
	if not r.is_empty():
		r[0].sm.set_physics_process(false)
		p.lock_target = r[0]
		p.face_dir(r[0].global_position - p.global_position)
		p.global_position = r[0].global_position + Vector3(0, 0, 2.4)
		p.face_dir(r[0].global_position - p.global_position)
	await wait(0.3)
	p.move_input = Vector3(-1, 0, 0)
	p.press("light")
	p.release("light")
	await wait(0.18)
	p.move_input = Vector3.ZERO
	await shot("01_guided_R1_lateral_cut")
	await wait(0.8)
	# 2. status priority row + notice
	p.statuses.add(StatusEffect.make("chill", "Chill", "debuff", 6.0, {"move_speed": 0.55}))
	p.statuses.add(StatusEffect.make("burn", "Burning", "dot", 6.0, {}, 3.0, 1.0))
	p.statuses.add(StatusEffect.make("last_line", "Last Line", "buff", 6.0, {"damage_taken": 0.65}))
	p.statuses.add(StatusEffect.make("haste", "Haste", "buff", 6.0, {"attack_speed": 1.2}))
	Events.combat_notice.emit("POISE BROKEN", null)
	await wait(0.2)
	await shot("02_status_priority_and_notice")
	GuidedPlaytest.current.queue_free()
	# 3. Lab tab
	var dbg = main.get_node("DebugPanel")
	dbg.toggle()
	await wait(0.3)
	dbg._build()
	dbg.tabs.current_tab = dbg.tabs.get_node("Lab").get_index()
	await wait(0.4)
	await shot("03_class_experience_lab")
	dbg.toggle()
	# 4. Vanguard perfect guard banner
	Game.switch_class("vanguard")
	await wait(0.6)
	Events.combat_notice.emit("PERFECT GUARD", Game.player)
	await wait(0.15)
	await shot("04_vanguard_perfect_guard_banner")
	# 5. Augments tab with mutation limit
	for id in ["phantom_bulwark", "verdict_of_steel"]:
		Game.add_augment("vanguard", id)
	var gm = main.get_node("GameMenu")
	gm.open_tab("Augments")
	await wait(0.4)
	await shot("05_augments_mutation_limit")
	get_tree().quit()
