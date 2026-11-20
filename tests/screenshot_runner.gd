extends Node
## Captures reference screenshots of the UI (needs a real renderer):
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --fixed-fps 60 res://tests/screenshot_runner.tscn

var main: Node


func wait(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	get_viewport().get_texture().get_image().save_png("res://screenshots/%s.png" % n)
	print("saved ", n)


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.4)
	await shot("01_title")
	main._goto_select()
	main.class_cards["vanguard"].hover = true
	await wait(0.2)
	await shot("02_class_select")
	main.start_game("vanguard", true)
	Game.invincible = true
	Game.auto_open_drafts = false
	await wait(0.5)
	var p := Game.player
	p.global_position = Vector3(0, 0.3, 16)
	p.face_dir(Vector3(0, 0, -1))
	Game.add_augment("vanguard", "phantom_bulwark")
	for i in 3:
		var e := Game.spawn_enemy("raider", p.global_position + Vector3(-3 + i * 3, 0.3, -5), "outskirts", i == 1)
		e.update_target(0.0)
	p.lock_target = Game.enemies()[0]
	await wait(1.4)
	p.press("guard")
	await wait(0.5)
	await shot("03_vanguard_combat")
	p.release("guard")
	p.press("skill3")
	p.release("skill3")
	await wait(0.6)
	await shot("04_vanguard_skills")
	main.get_node("PauseMenu").open()
	await wait(0.05)
	await shot("05_pause_menu")
	main.get_node("PauseMenu").resume()
	Game.switch_class("mage")
	await wait(0.3)
	p = Game.player
	Game.unlock_element("frost", "shot")
	p.press("light")
	p.release("light")
	await wait(0.6)
	p.press("life")
	p.release("life")
	await wait(0.8)
	await shot("06_mage_hud")
	Game.switch_class("reaver")
	await wait(0.3)
	p = Game.player
	p.press("skill1")
	p.release("skill1")
	await wait(0.4)
	await shot("07_reaver_hud")
	Game.world.teleport_player("boss")
	await wait(0.2)
	Game.player.global_position = Game.world.boss_zone.center + Vector3(0, 0.5, 7)
	await wait(2.0)
	await shot("08_boss")
	var draft = main.get_node("DraftUI")
	Game.gain_exp(90, "shot")
	draft.open("reaver")
	await wait(0.4)
	await shot("09_augment_draft")
	draft._pick(draft.current_cards[0].id)
	main.get_node("GameMenu").open_tab("Character")
	await wait(0.3)
	await shot("10_character_sheet")
	main.get_node("GameMenu").close_menu()
	main.get_node("DebugPanel").toggle()
	await wait(0.2)
	await shot("11_debug_panel")
	get_tree().quit()
