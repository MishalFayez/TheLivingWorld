extends Node
## Screenshots of the design-resolution features from the real game scene.
var main


func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/resolution_%s.png" % n)


func _ready() -> void:
	Save.enabled = false
	Game.reset_all_progress()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.3)
	main.start_game("reaver", true, true)
	Game.reaver_core = "swordmaster"
	Game.invincible = true
	Game.auto_open_drafts = false
	for h in Game.heroes:
		if h != Game.player:
			h.get_node("Brain").set_physics_process(false)
	Game.set_level("reaver", 10)
	for u in ["r_sunder_edge", "r_turning_edge", "r_final_stroke"]:
		Game.prog("reaver").debug_unlocks.append(u)
	await wait(0.5)
	var p = Game.player
	p.restore_all()
	# 1. Guided RA + Shift+A lateral cut
	GuidedPlaytest.start("RA")
	await wait(0.6)
	var r = Game.enemies().filter(func(x): return x.enemy_type == "raider")
	if not r.is_empty():
		r[0].sm.set_physics_process(false)
		p.global_position = r[0].global_position + Vector3(0, 0, 2.4)
		p.lock_target = r[0]
		p.face_dir(r[0].global_position - p.global_position)
	await wait(0.3)
	p.held["blade_modifier"] = true
	p.strafe_axis = -1.0
	p.press("light")
	p.release("light")
	await wait(0.16)
	p.held["blade_modifier"] = false
	p.strafe_axis = 0.0
	await shot("01_shift_A_lateral_cut")
	await wait(0.8)
	if GuidedPlaytest.current:
		GuidedPlaytest.current.queue_free()
	# 2. Final Stroke opportunity open on the HUD (Lv10 + showcase unlocks)
	Game.set_level("reaver", 10)
	for u in ["r_sunder_edge", "r_turning_edge", "r_final_stroke"]:
		Game.prog("reaver").debug_unlocks.append(u)
	await wait(0.4)
	p.kit.sm.refresh_loadout()
	p.kit.sm.open_finisher("shot")
	await wait(0.15)
	await shot("02_final_stroke_window_hud")
	await wait(1.6)
	# 3. Skills tab: progression + Reaver loadout + showcase labels
	var gm = main.get_node("GameMenu")
	gm.open_tab("Skills")
	await wait(0.4)
	await shot("03_reaver_progression_loadout")
	for sc in gm.find_children("*", "ScrollContainer", true, false):
		sc.scroll_vertical = 100000
	await wait(0.3)
	await shot("03b_reaver_showcase_levels")
	gm.close_menu()
	await wait(0.2)
	# 4. Vanguard Shield Plant
	Game.switch_class("vanguard")
	Game.set_level("vanguard", 10)
	Game.prog("vanguard").debug_unlocks.append("v_shield_plant")
	await wait(0.6)
	var v = Game.player
	v.restore_all()
	v.press("core")
	v.release("core")
	await wait(0.3)
	await shot("04_vanguard_shield_plant")
	await wait(4.2)
	# 5. Vanguard progression
	gm.open_tab("Skills")
	await wait(0.4)
	await shot("05_vanguard_progression")
	gm.close_menu()
	# 6. Lab tab
	var dbg = main.get_node("DebugPanel")
	dbg.toggle()
	await wait(0.3)
	dbg._build()
	dbg.tabs.current_tab = dbg.tabs.get_node("Lab").get_index()
	await wait(0.4)
	await shot("06_lab_scenarios")
	get_tree().quit()
