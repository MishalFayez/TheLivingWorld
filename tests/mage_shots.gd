extends Node
## Screenshots of the Worldweaver Mage from the real game scene (game camera + HUD).
##   xvfb-run ... godot --rendering-driver opengl3 --resolution 1920x1080 res://tests/mage_shots.tscn
var pre := "ww"
var main


func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/mage_%s_%s.png" % [pre, n])


func spawn(type: String, off: Vector3) -> Enemy:
	var p = Game.player
	var e = Game.spawn_enemy(type, p.global_position + off, "outskirts")
	e.sm.set_physics_process(false)
	e.max_hp = 99999
	e.hp = 99999
	e.face_dir(p.global_position - e.global_position)
	return e


func clear() -> void:
	for e in Game.enemies():
		e.queue_free()
	Game.player.kit.el.clear_world()
	Game.player.kit.mana = Game.balance.mana_max
	Game.player.kit.cooldowns.clear()


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		pre = a[0]
	Save.enabled = false
	Game.reset_all_progress()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.3)
	main.start_game("mage", true)
	Game.invincible = true
	Game.auto_open_drafts = false
	for h in Game.heroes:
		if h != Game.player:
			h.get_node("Brain").set_physics_process(false)
	Game.set_level("mage", 10)
	for id in ["frozen_bastion", "stone_ward", "storm_arc", "inferno_wave"]:
		Game.prog("mage").debug_unlocks.append("spell:" + id)
	await wait(0.8)
	var p = Game.player
	var e: MageElementalist = p.kit.el
	# 1. charging Fire, full explosion, burning area
	var r1 = spawn("raider", Vector3(-1.2, 0.2, -9))
	spawn("raider", Vector3(1.2, 0.2, -9.6))
	p.lock_target = r1
	p.press("light")
	await wait(0.8)
	await shot("01_charging_fire")
	await wait(0.5)
	p.release("light")
	await wait(0.5)
	await shot("02_fire_full_explosion")
	await wait(1.0)
	await shot("03_burning_area")
	clear()
	await wait(0.3)
	# 2. Crystal Formation: placement preview, then the wall
	var w1 = spawn("wolf", Vector3(-1.5, 0.2, -12))
	spawn("wolf", Vector3(2, 0.2, -13))
	p.lock_target = w1
	e.equip_spell(2, "crystal_formation")
	p.press("skill1")
	await wait(1.25)
	await shot("04_crystal_preview_full")
	p.release("skill1")
	await wait(0.45)
	await shot("05_crystal_formation")
	# 3. Thermal Fracture -> steam
	p.lock_target = null
	p.face_dir(e.formations[-1].global_position - p.global_position)
	p.kit.mana = 100
	p.press("light")
	await wait(1.25)
	p.release("light")
	await wait(0.75)
	await shot("06_thermal_fracture_steam")
	clear()
	await wait(0.4)
	# 4. Stone Ward + Living Bastion
	e.equip_spell(3, "stone_ward")
	e.cast_utility("stone_ward")
	await wait(0.3)
	p.kit.mana = 100
	p.hp = p.max_hp * 0.5
	p.press("heavy")
	await wait(1.25)
	p.release("heavy")
	await wait(0.6)
	await shot("07_stone_ward_living_bastion")
	clear()
	await wait(0.3)
	# 5. Earthbreaker charge (major spell) and Shattered Winter
	var g = spawn("raider", Vector3(0, 0.2, -11))
	p.lock_target = g
	e.equip_spell(2, "crystal_formation")
	p.press("skill1")
	await wait(1.25)
	p.release("skill1")
	await wait(0.6)
	p.kit.mana = 100
	p.lock_target = null
	p.face_dir(e.formations[-1].global_position - p.global_position)
	e.equip_spell(0, "earthbreaker")
	p.press("light")
	await wait(1.0)
	await shot("08_earthbreaker_charging")
	await wait(0.9)
	p.release("light")
	await wait(0.45)
	await shot("09_shattered_winter")
	clear()
	await wait(0.3)
	# 6. Thunder Conduit chain + Sanctum
	p.kit.mana = 100
	p.kit.cooldowns.clear()
	e.cast_sanctum()
	await wait(0.5)
	e.equip_spell(0, "thunder_conduit")
	var es: Array = []
	for i in 4:
		es.append(spawn("raider", Vector3(-4.5 + i * 3.0, 0.2, -10)))
	p.lock_target = es[1]
	p.kit.mana = 100
	p.press("light")
	await wait(1.25)
	p.release("light")
	await wait(0.08)
	await shot("10_thunder_chain_in_sanctum")
	clear()
	await wait(0.3)
	# 7. Frozen Bastion aiming (hold 3)
	e.equip_spell(3, "frozen_bastion")
	var w2 = spawn("wolf", Vector3(0, 0.2, -10))
	p.lock_target = w2
	e.util_aiming = "frozen_bastion"
	await wait(0.3)
	await shot("11_bastion_aim_preview")
	p.release("skill3")
	e.on_release("skill3")
	await wait(0.4)
	await shot("12_frozen_bastion")
	clear()
	# 8. Spellbook UI
	var gm = main.get_node("GameMenu")
	gm.open_tab("Spellbook")
	await wait(0.5)
	await shot("13_spellbook")
	get_tree().quit()
