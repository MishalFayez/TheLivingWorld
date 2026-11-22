extends Node
## COMBAT-BALANCE-UX-006: rendered UI review screenshots (windowed run, saving disabled, fresh test session).
##   godot --path . res://tests/ui006_shots.tscn --resolution 1920x1080
## Output: res://screenshots/u006_*.png (git-ignored).

func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	get_viewport().get_texture().get_image().save_png("res://screenshots/u006_%s.png" % n)


func _ready() -> void:
	Save.enabled = false
	Game.reset_all_progress()
	Game.auto_open_drafts = false
	Game.reaver_core = "bladedancer"
	Game.mage_core = "elementalist"
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.3)
	# --- Worldweaver casting wheel
	Game.start_fresh_test("mage")
	main.start_game("mage", false)
	Game.invincible = true
	await wait(0.4)
	Game.set_level("mage", 9)
	Game.prog().pending_drafts = 0
	Game.prog().pending_draft_tiers.clear()
	await wait(0.6)
	var p: Hero = Game.player
	var e := Game.spawn_enemy("raider", p.global_position + Vector3(0, 0.2, -7), "outskirts")
	e.sm.set_physics_process(false)
	p.lock_target = e
	p.kit.mana = 100.0
	await wait(0.3)
	p.press("light")
	await wait(0.5)
	await shot("01_wheel_lmb_charging")
	var el: MageElementalist = p.kit.el
	var opts := el.wheel_options(0)
	el.wheel_select((opts.find(el.cur.id) + 2) % opts.size())
	await wait(1.4)
	await shot("02_wheel_switched_full_charge")
	p.release("light")
	await wait(0.12)
	await shot("02b_released_cast")
	await wait(1.0)
	# 006 review 1: the RMB wheel (its own set; default = every known charged spell, like LMB)
	p.kit.mana = 100.0
	p.press("heavy")
	await wait(0.5)
	await shot("02c_wheel_rmb")
	p.release("heavy")
	await wait(1.2)
	var gm = main.get_node("GameMenu")
	gm.open_tab("Skills")
	await wait(0.3)
	await shot("03_skills_mage_simple")
	gm.open_tab("Spellbook")
	await wait(0.3)
	await shot("04_spellbook_wheels")
	gm.close_menu()
	main.return_to_menu()
	await wait(0.4)
	# --- Reaver tooltips + Level 4 draft cards
	Game.start_fresh_test("reaver")
	main.start_game("reaver", false)
	Game.invincible = true
	await wait(0.4)
	for i in 3:
		Game.test_gain_level()
	await wait(0.3)
	gm = main.get_node("GameMenu")
	gm.open_tab("Skills")
	await wait(0.3)
	await shot("05_skills_reaver_simple")
	gm.close_menu()
	var draft = main.get_node("DraftUI")
	draft.open("reaver")
	await wait(0.6)
	await shot("06_draft_reaver_lv4")
	if draft.current_cards.size() > 0:
		draft._inspect(draft.current_cards[0].id)
		await wait(0.3)
		await shot("07_draft_inspect")
		draft._pick(draft.current_cards[0].id)
	await wait(0.3)
	gm.open_tab("Augments")
	await wait(0.3)
	await shot("08_augments_menu")
	gm.close_menu()
	main.return_to_menu()
	await wait(0.3)
	# --- Vanguard Level 4 draft
	Game.start_fresh_test("vanguard")
	main.start_game("vanguard", false)
	await wait(0.4)
	for i in 3:
		Game.test_gain_level()
	await wait(0.3)
	draft = main.get_node("DraftUI")
	draft.open("vanguard")
	await wait(0.6)
	await shot("09_draft_vanguard_lv4")
	draft._pick(draft.current_cards[0].id)
	main.return_to_menu()
	await wait(0.3)
	get_tree().quit(0)
