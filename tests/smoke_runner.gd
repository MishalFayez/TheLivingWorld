extends Node
## End-to-end smoke test of the real game flow: menu -> session with full UI, draft UI, debug panel,
## character sheet, encounters, gates, boss trigger, class switching. Run:
##   godot --headless --fixed-fps 60 res://tests/smoke_runner.tscn

var main: Node
var ok: int = 0
var bad: int = 0


func check(c: bool, n: String, d: String = "") -> void:
	if c:
		ok += 1
		print("  PASS  ", n, "  ", d)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)


func wait(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame


func kill_all() -> void:
	for e in Game.enemies():
		if e.is_targetable():
			var info := DamageInfo.new()
			info.source = Game.player
			info.amount = 999999.0
			info.raw_amount = 999999.0
			e.take_damage(info)


## QA-001: the smoke run must never depend on (or touch) the user's real save. Before main.tscn starts
## (its _ready loads the save), point Save at a disposable fixture holding pre-existing progress on
## another class, then disable writing. main loads the fixture through the normal startup path.
const FIXTURE_VANGUARD_LEVEL := 3
var fixture_path: String


func _isolate_save() -> void:
	var dir := ProjectSettings.globalize_path("res://.dev/reports/qa_fixtures")
	DirAccess.make_dir_recursive_absolute(dir)
	fixture_path = dir.path_join("smoke_save.json")
	_clear_fixture()
	Save.path = fixture_path
	Save.reset_settings()
	Save.enabled = true
	Game.reset_all_progress()
	Game.debug_tainted = false
	Game.create_character("vanguard", "Fixture")
	Game.set_level("vanguard", FIXTURE_VANGUARD_LEVEL)
	Save.save_game()
	Game.reset_all_progress()
	Save.enabled = false


func _clear_fixture() -> void:
	for f in DirAccess.get_files_at(fixture_path.get_base_dir()):
		if f.begins_with(fixture_path.get_file()):
			DirAccess.remove_absolute(fixture_path.get_base_dir().path_join(f))


func _ready() -> void:
	_isolate_save()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.2)
	var fx := Game.prog("vanguard")
	check(fx.created and fx.character_name == "Fixture" and fx.level == FIXTURE_VANGUARD_LEVEL and not Game.prog("mage").created, "startup loads the isolated fixture save (pre-existing Vanguard progress)", "vanguard Lv %d" % fx.level)
	main.start_game("mage", true)
	await wait(0.5)
	check(Game.heroes.size() == 3, "party session spawns player + 2 AI companions")
	# real input path through PlayerBrain with the full UI stack loaded
	Input.action_press("light")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var charging: bool = Game.player.kit.charging == "light"
	Input.action_release("light")
	await wait(0.35)        # a tap releases once the spell's minimum charge is reached
	check(Game.ui_block == 0 and charging and Game.player.runner.is_busy(), "UI does not block gameplay input (LMB press/release reaches the hero)")
	await wait(1.0)
	var hud = main.get_node("HUD")
	var dbg = main.get_node("DebugPanel")
	var draft = main.get_node("DraftUI")
	var gm = main.get_node("GameMenu")
	dbg.toggle()
	await wait(0.2)
	check(dbg.tabs.get_tab_count() == 10 and dbg.tabs.get_node_or_null("Lab") != null, "debug panel builds all sections incl. the Class Experience Lab", "%d tabs" % dbg.tabs.get_tab_count())
	dbg.toggle()
	Game.invincible = true
	# Level 4 -> first draft opens automatically and pauses
	while Game.prog().level < 4:
		Game.gain_exp(60, "smoke")
	await get_tree().process_frame
	await get_tree().process_frame
	check(draft.is_open and get_tree().paused, "draft UI opens at level 4 and pauses the game", "cards %d" % draft.current_cards.size())
	if draft.is_open and draft.current_cards.size() > 0:
		draft._pick(draft.current_cards[0].id)
	await get_tree().process_frame
	check(not get_tree().paused and Game.prog("mage").augments.size() == 1, "picking a card applies it and resumes")
	for t in GameMenu.TABS:
		gm.open_tab(t)
		await get_tree().process_frame
		check(gm.body.get_child_count() >= 1 and get_tree().paused, "game menu tab builds: " + t)
	gm.close_menu()
	await get_tree().process_frame
	check(not get_tree().paused and Game.ui_block == 0, "game menu closes and resumes")
	# Walk the stage via encounters
	for area in ["outskirts", "ruins", "keep"]:
		Game.world.teleport_player(area)
		await wait(0.3)
		for z in Game.world.zones[area]:
			Game.player.global_position = z.global_position + Vector3(0, 0.3, 3)
			for i in 6:
				await wait(0.5)
				kill_all()
				if draft.is_open:
					draft._pick(draft.current_cards[0].id if draft.current_cards.size() > 0 else "")
				if z.done:
					break
			await wait(2.2)
		check(Game.world.cleared.get(area, false), "%s: all encounter objectives complete -> area cleared" % area, "level now %d" % Game.prog().level)
	check(not Game.world.gates.has("outskirts") and not Game.world.gates.has("ruins"), "ash gates opened")
	Game.world.teleport_player("boss")
	await wait(0.2)
	Game.player.global_position = Game.world.boss_zone.center + Vector3(0, 0.5, 4)
	await wait(0.5)
	check(Game.world.boss != null, "entering the arena starts the Ashen Warden fight")
	await wait(4.0)
	check(hud.boss_root.visible, "boss frame visible")
	kill_all()
	await wait(0.5)
	while draft.is_open:
		draft._pick(draft.current_cards[0].id if draft.current_cards.size() > 0 else "")
		await get_tree().process_frame
		await get_tree().process_frame
	check(Game.world.cleared.get("boss", false), "boss defeat recorded")
	print("    Mage level after full clear: %d (augments %d, pending %d)" % [Game.prog().level, Game.prog().augments.size(), Game.prog().pending_drafts])
	check(Game.prog().level >= 9, "a full clear levels the class to ~10", "Lv %d" % Game.prog().level)
	# class switch keeps progress independent
	Game.switch_class("vanguard")
	await wait(0.5)
	# Vanguard must keep exactly its pre-existing (fixture) progress; the Mage run must not leak into it.
	var vg := Game.prog("vanguard")
	check(Game.player.class_id == "vanguard" and vg.created and vg.character_name == "Fixture" and vg.level == FIXTURE_VANGUARD_LEVEL and vg.augments.is_empty() and Game.prog("mage").level >= 9, "switching class keeps independent progression", "player %s, vanguard Lv %d (fixture %d), mage Lv %d" % [Game.player.class_id, vg.level, FIXTURE_VANGUARD_LEVEL, Game.prog("mage").level])
	check(Game.heroes.size() == 3, "companions respawned for the new class lineup")
	dbg.toggle()
	await wait(0.2)
	dbg.toggle()
	# pause menu + return to main menu + start again
	var pm = main.get_node("PauseMenu")
	pm.open()
	await get_tree().process_frame
	check(get_tree().paused and pm.is_open and Game.ui_block > 0, "Esc pause menu pauses the game")
	pm.resume()
	await get_tree().process_frame
	check(not get_tree().paused and Game.ui_block == 0, "resume restores control")
	pm._to_menu()
	await wait(0.3)
	check(main.menu != null and Game.player == null and main.get_node_or_null("HUD") == null, "return to main menu tears down the session")
	main._goto("select")
	await get_tree().process_frame
	check(main.select_list.get_child_count() == 3, "character selection lists the 3 class slots")
	main._goto("create")
	main._pick_new_class("reaver")
	await wait(0.2)
	check(main.preview != null and main.preview.rig != null, "creation screen shows the live class model")
	main.name_edit.text = "Kael"
	main._create_now()
	await wait(0.5)
	check(is_instance_valid(Game.player) and Game.player.class_id == "reaver" and Game.prog("reaver").level == 1 and Game.prog("reaver").character_name == "Kael" and Game.prog("mage").level >= 9, "New Character starts a Level 1 reaver; mage progress untouched")
	Game.world.teleport_player("training")
	await wait(0.5)
	check(get_tree().get_nodes_in_group("training_dummy").size() == 3 and main.get_node("TrainingUI").panel.visible, "training grounds: dummies + training panel")
	_clear_fixture()
	print("\n==== SMOKE: %d passed, %d failed ====" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)
