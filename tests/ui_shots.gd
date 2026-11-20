extends Node
## Update 5 UI screenshots. Pass the output prefix after "--", e.g. -- 1080
var pre := "1080"

func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/u5_%s_%s.png" % [pre, n])

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		pre = a[0]
	var full := not a.has("short")
	Save.enabled = false
	Game.reset_all_progress()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.3)
	await shot("01_title")
	main._goto("create")
	main._pick_new_class("mage")
	await wait(0.6)
	await shot("02_create_mage")
	if full:
		main._pick_new_class("vanguard")
		await wait(0.4)
		await shot("03_create_vanguard")
		main._pick_new_class("reaver")
		await wait(0.4)
		await shot("04_create_reaver")
	main.name_edit.text = "Lyra"
	main._pick_new_class("mage")
	main._create_now()
	Game.invincible = true
	Game.auto_open_drafts = false
	await wait(0.5)
	# mage fight with sigils
	Game.set_level("mage", 5)
	Game.prog().unlock_element("frost")
	var p = Game.player
	var w1 = Game.spawn_enemy("raider", p.global_position + Vector3(-1.5, 0.2, -7), "outskirts")
	var w2 = Game.spawn_enemy("wolf", p.global_position + Vector3(1.5, 0.2, -7.5), "outskirts")
	for e in [w1, w2]:
		e.sm.set_physics_process(false)
	await wait(0.3)
	main.get_node("PauseMenu")  # ensure exists
	p.lock_target = w1
	p.press("light")
	p.release("light")
	await wait(0.9)
	p.press("core")
	p.release("core")
	await wait(1.6)
	await shot("05_hud_mage_fire_sigil")
	var gm = main.get_node("GameMenu")
	Game.prog().free_points = 4
	gm.open_tab("Character")
	gm.pending = {"vit": 1, "mas": 2}
	gm.show_tab("Character")
	await wait(0.5)
	await shot("06_menu_character_preview")
	gm.pending.clear()
	for t in (["Skills", "Augments", "Inventory", "Map", "Journal", "Settings"] if full else ["Skills", "Map"]):
		if t == "Inventory":
			Game.give_item("mage", "m_ley_staff")
			Game.give_item("mage", "circlet_of_insight")
			gm.selected_item = "m_ley_staff"
		gm.show_tab(t)
		await wait(0.3)
		await shot("07_menu_" + t.to_lower())
	gm.close_menu()
	# draft
	var d = main.get_node("DraftUI")
	Game.prog().pending_drafts = 1
	Game.prog().pending_draft_tiers = ["advanced"]
	d.open("mage")
	await wait(0.4)
	await shot("08_draft")
	d._inspect(d.current_cards[0].id)
	await wait(0.2)
	await shot("09_draft_inspect")
	d._pick(d.current_cards[0].id)
	await wait(0.2)
	# unlock popup
	Events.unlocks_gained.emit("mage", [Game.track("mage").milestone("m_ward")])
	await wait(0.6)
	await shot("10_unlock_popup")
	# reaver opening
	Game.create_character("reaver", "Kael")
	Game.switch_class("reaver")
	await wait(0.5)
	Game.set_level("reaver", 7)
	p = Game.player
	var r = Game.spawn_enemy("raider", p.global_position + p.forward() * 2.2 + Vector3(0, 0.2, 0), "outskirts")
	r.sm.set_physics_process(false)
	r.face_dir(p.global_position - r.global_position)
	p.lock_target = r
	r.open_window("recovery", 3.0)
	await wait(0.3)
	p.press("light")
	p.release("light")
	await wait(0.12)
	await shot("11_hud_reaver_opening")
	# training
	Game.world.teleport_player("training")
	await wait(0.5)
	p = Game.player
	var dm = get_tree().get_nodes_in_group("training_dummy")[1]
	p.teleport(dm.global_position + Vector3(0, 0.3, -1.7))
	p.face_dir(dm.global_position - p.global_position)
	await wait(0.2)
	for i in 6:
		p.press("light" if i % 3 != 2 else "heavy")
		p.release("light" if i % 3 != 2 else "heavy")
		await wait(0.5)
	await shot("12_training")
	main.get_node("DebugPanel").toggle()
	await wait(0.3)
	await shot("13_debug_panel")
	get_tree().quit()
