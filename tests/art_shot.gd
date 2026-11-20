extends Node
## Art pass screenshots: environment areas, hero line-up, enemy line-up (uses a free camera).
var cam: Camera3D

func wait(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/art_%s.png" % n)

func look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	cam.make_current()

func _ready() -> void:
	Save.enabled = false
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.1)
	main.start_game("vanguard", true)
	Game.invincible = true
	Game.auto_open_drafts = false
	for n in ["HUD"]:
		var c = main.get_node_or_null(n)
		if c and "visible" in c:
			c.visible = false
	cam = Camera3D.new()
	main.world.add_child(cam)
	await wait(0.6)
	# heroes line-up
	var hs: Array = Game.heroes
	for i in hs.size():
		hs[i].get_node("Brain").set_physics_process(false)
		hs[i].get_node("Brain").set_process(false)
		hs[i].teleport(Vector3(-2.2 + i * 2.2, 0.1, 24))
		hs[i].face_dir(Vector3(0, 0, 1))
		hs[i].velocity = Vector3.ZERO
	await wait(0.5)
	look(Vector3(0, 1.6, 29.5), Vector3(0, 1.1, 24), 45)
	await wait(0.2)
	await shot("heroes")
	look(Vector3(-2.2, 1.75, 25.6), Vector3(-2.2, 1.55, 24), 40)
	await shot("vanguard_close")
	look(Vector3(0, 1.75, 25.6), Vector3(0, 1.55, 24), 40)
	await shot("mage_close")
	look(Vector3(2.2, 1.75, 25.6), Vector3(2.2, 1.55, 24), 40)
	await shot("reaver_close")
	# enemies line-up
	var types := ["wolf", "raider", "shield_guardian", "ash_caster", "ashen_warden", "training_dummy"]
	var es: Array = []
	for i in types.size():
		var e = Game.spawn_enemy(types[i], Vector3(-8 + i * 3.2, 0.2, 10), "outskirts")
		e.sm.set_physics_process(false)
		e.face_dir(Vector3(0, 0, 1))
		es.append(e)
	await wait(0.5)
	look(Vector3(0, 2.6, 19), Vector3(0, 1.2, 10), 55)
	await shot("enemies")
	for e in es:
		e.queue_free()
	# areas
	look(Vector3(0, 7, 30), Vector3(0, 0, 0), 65)
	await wait(0.3)
	await shot("outskirts")
	Scenery.update_atmosphere(-85)
	look(Vector3(5, 6, -58), Vector3(0, 1, -90), 65)
	await wait(0.3)
	await shot("ruins")
	Scenery.update_atmosphere(-165)
	look(Vector3(0, 8, -140), Vector3(0, 1, -180), 65)
	await wait(0.3)
	await shot("keep")
	get_tree().quit()
