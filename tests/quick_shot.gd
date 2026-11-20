extends Node
## Fast layout check: HUD + boss bar, augment draft, debug panel.
func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/q_%s.png" % n)
func _ready() -> void:
	preload("res://tests/test_save_guard.gd").isolate("quick_shot")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.1)
	await shot("menu")
	main.start_game("mage", false)
	Game.invincible = true
	Game.auto_open_drafts = false
	Game.world.teleport_player("boss")
	await wait(0.2)
	Game.player.global_position = Game.world.boss_zone.center + Vector3(0, 0.5, 6)
	await wait(1.5)
	await shot("boss")
	var d = main.get_node("DraftUI")
	Game.gain_exp(90, "x")
	d.open("mage")
	await wait(0.1)
	await shot("draft")
	d._pick(d.current_cards[0].id)
	main.get_node("DebugPanel").toggle()
	await wait(0.1)
	await shot("debug")
	get_tree().quit()
