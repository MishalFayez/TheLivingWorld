extends "res://tests/test_runner.gd"
## Update 5 automated checks: save/load, debug isolation, unlock gating, stat previews,
## equipment, Mage Ley Sigils, Reaver Sword Sense, training dummy.
##   godot --headless --fixed-fps 60 res://tests/update5_runner.tscn
## These are automated mechanical checks only - they do not replace human playtesting.


func _run_all() -> void:
	await test_save_roundtrip()
	await test_debug_taint()
	await test_unlock_gating()
	await test_stat_preview()
	await test_equipment()
	await test_sigils_heal_without_attacking()
	await test_sigils_offense_resonance_consume()
	await test_openings_and_cuts()
	await test_perfect_dodge_opening()
	await test_training_dummy()
	await test_qa_save_tmp_write_failure()
	await test_qa_save_replace_reports_truthfully()
	await test_qa_save_game_keeps_unreadable_file()
	await test_qa_settings_keep_characters()
	await test_qa_switch_class_invalid_id()
	await test_rv_recover_interrupted_write()
	await test_rv_recover_invalid_primary()
	await test_rv_no_valid_backup_keeps_everything()
	await test_rv_newest_candidate_and_orphan_tmp()
	await test_rv_tools_isolate_real_save()
	await teardown()


func test_save_roundtrip() -> void:
	print("\n[Save / load round trip]")
	await teardown()
	Save.enabled = true
	Save.path = fixture_path("test_save_u5.json")
	Save.delete_save()
	Game.reset_all_progress()
	Game.debug_tainted = false
	Game.create_character("reaver", "Kaelen")
	Game.create_character("mage", "Lyra")
	var p := Game.prog("reaver")
	p.set_level(4)
	p.allocate("dex")
	p.allocate("str")
	p.augments.append("predators_patience")
	p.inventory.append("r_crimson_blade")
	Game.active_class = "reaver"
	check(Save.save_game(), "save_game writes a save file", Save.last_error)
	Game.reset_all_progress()
	check(not Game.prog("reaver").created, "memory cleared before load")
	check(Save.load_game(), "load_game reads it back")
	var q := Game.prog("reaver")
	check(q.created and q.character_name == "Kaelen" and q.level == 4, "reaver name + level restored", "%s L%d" % [q.character_name, q.level])
	check(int(q.allocated.dex) == 1 and int(q.allocated.str) == 1 and q.free_points == p.free_points, "allocated stats restored")
	check(q.augments.has("predators_patience") and q.inventory.has("r_crimson_blade"), "augments + inventory restored")
	check(q.equipment.get("weapon", "") == "starter_r_sword", "starter equipment restored", str(q.equipment))
	check(Game.prog("mage").created and Game.prog("mage").character_name == "Lyra" and Game.prog("mage").level == 1, "other class progresses independently")
	check(not Game.prog("vanguard").created, "uncreated class stays uncreated")
	check(Game.active_class == "reaver", "last played class restored")
	Save.delete_save()
	Save.enabled = false


# ------------------------------------------------------------------ QA-001 save safety regressions
# All on disposable files under .dev/reports/qa_fixtures; the user's real save is never opened.

func _qa_begin(file_name: String) -> String:
	await teardown()
	var p := fixture_path(file_name)
	clear_fixture(p)
	Save.enabled = true
	Save.path = p
	Game.reset_all_progress()
	Game.debug_tainted = false
	return p


func _qa_end(p: String) -> void:
	clear_fixture(p)
	Save.enabled = false
	Game.debug_tainted = false
	Game.reset_all_progress()


func _qa_parse(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null


func test_qa_save_tmp_write_failure() -> void:
	print("\n[QA-001: a failed temp write keeps the previous save]")
	var p: String = await _qa_begin("qa_tmpfail.json")
	Game.create_character("vanguard", "Keeper")
	var before := FileAccess.get_file_as_string(p)
	DirAccess.make_dir_absolute(p + ".tmp")   # the temp file cannot be created
	Game.prog("vanguard").set_level(5)
	var r := Save.save_game()
	check(not r and Save.last_error != "", "save_game reports the failed write", Save.last_error)
	check(FileAccess.get_file_as_string(p) == before, "previous save is byte-for-byte intact")
	_qa_end(p)


func test_qa_save_replace_reports_truthfully() -> void:
	print("\n[QA-001: save_game returns true only when the file really holds the new data]")
	var p: String = await _qa_begin("qa_readonly.json")
	Game.create_character("vanguard", "Keeper")
	FileAccess.set_read_only_attribute(p, true)   # replacing the existing file is obstructed
	Game.prog("vanguard").set_level(5)
	var r := Save.save_game()
	var d = _qa_parse(p)
	var lvl := int(d.characters.vanguard.level) if d is Dictionary and d.has("characters") else -1
	check(lvl == 1 or lvl == 5, "a readable save remains on disk", "level on disk %d" % lvl)
	check(r == (lvl == 5), "return value matches what was written", "returned %s, level on disk %d, error '%s'" % [r, lvl, Save.last_error])
	_qa_end(p)


func test_qa_save_game_keeps_unreadable_file() -> void:
	print("\n[QA-001: an unreadable existing save is preserved, not deleted, when a new save is written]")
	var p: String = await _qa_begin("qa_corrupt.json")
	var junk := "{\"version\": 1, \"characters\": {\"vanguard\": {\"level\": 7"   # truncated JSON
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(junk)
	f.close()
	Game.create_character("mage", "Lyra")   # writes a fresh save over the unreadable one
	var d = _qa_parse(p)
	check(d is Dictionary and d.characters.mage.created, "new save written and readable")
	var kept := false
	for n in DirAccess.get_files_at(p.get_base_dir()):
		if n.begins_with(p.get_file() + ".corrupt") and FileAccess.get_file_as_string(p.get_base_dir().path_join(n)) == junk:
			kept = true
	check(kept, "the unreadable previous file is kept as a .corrupt copy")
	_qa_end(p)


func test_qa_settings_keep_characters() -> void:
	print("\n[QA-001: writing settings never destroys character data]")
	var p: String = await _qa_begin("qa_settings.json")
	Game.create_character("reaver", "Kaelen")
	Save.settings.invert_y = true
	Save.save_settings()
	var d = _qa_parse(p)
	check(d is Dictionary and d.characters.reaver.created and d.characters.reaver.name == "Kaelen" and bool(d.settings.invert_y), "settings saved alongside intact characters")
	Save.settings.invert_y = false
	var junk := "{\"characters\": {\"reaver\": {\"name\": \"Kaelen\", \"level\": 9"   # truncated JSON
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(junk)
	f.close()
	Save.settings.camera_shake = false
	Save.save_settings()
	check(FileAccess.get_file_as_string(p) == junk, "unreadable save is not overwritten by a settings change", Save.last_error)
	Save.reset_settings()
	check(Save.settings == Save.DEFAULT_SETTINGS, "settings can be reset to defaults for isolated fixtures")
	_qa_end(p)


func test_qa_switch_class_invalid_id() -> void:
	print("\n[QA-001: an invalid class id never corrupts the active class]")
	var h := await setup("mage", false, false, false)
	Game.switch_class("paladin")
	await wait(0.1)
	check(Game.active_class == "mage" and is_instance_valid(Game.player) and Game.player == h and Game.player.class_id == "mage", "in session: unknown id ignored, Mage still active", Game.active_class)
	Game.switch_class("vanguard")
	await wait(0.2)
	check(Game.active_class == "vanguard" and Game.player.class_id == "vanguard", "valid switch still works")
	await teardown()
	Game.switch_class("")
	check(Game.active_class == "vanguard", "out of session: unknown id ignored", Game.active_class)
	Game.switch_class("reaver")
	check(Game.active_class == "reaver", "out of session: valid id still selects the class")


# ------------------------------------------------------------------ REVIEW-001 crash recovery regressions
# Simulates the states a crash can leave on disk; every case uses disposable fixtures under .dev/reports.

func _rv_saved(file_name: String, lvl: int) -> String:
	var p: String = await _qa_begin(file_name)
	Game.create_character("reaver", "Kaelen")
	Game.prog("reaver").set_level(lvl)
	Game.active_class = "reaver"
	Save.save_game()
	return p


func _rv_bytes(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else "<missing>"


func _rv_siblings(p: String, prefix: String) -> Array:
	return Array(DirAccess.get_files_at(p.get_base_dir())).filter(func(n): return n.begins_with(p.get_file() + prefix))


func test_rv_recover_interrupted_write() -> void:
	print("\n[REVIEW-001: crash after the old save moved to .bak, before the new one was installed]")
	var p: String = await _rv_saved("rv_interrupted.json", 4)
	var good := _rv_bytes(p)
	DirAccess.rename_absolute(p, p + ".bak")          # the crash state: no primary, valid backup
	Game.reset_all_progress()
	check(Save.has_save(), "has_save() detects recoverable progress", Save.last_error)
	check(Save.load_game() and Game.prog("reaver").level == 4 and Game.prog("reaver").character_name == "Kaelen", "character progress restored from .bak")
	check(_rv_bytes(p) == good and _rv_bytes(p + ".bak") == good, "primary restored, backup kept (copied, not moved)")
	check(Save.recovered_from == p.get_file() + ".bak", "recovery source reported", Save.recovered_from)
	_qa_end(p)


func test_rv_recover_invalid_primary() -> void:
	print("\n[REVIEW-001: unreadable primary save, valid backup]")
	var p: String = await _rv_saved("rv_invalid.json", 6)
	var good := _rv_bytes(p)
	DirAccess.copy_absolute(p, p + ".bak")
	var junk := "{\"characters\": {\"reaver\": {\"level\": 6"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(junk)
	f.close()
	Game.reset_all_progress()
	check(Save.load_game() and Game.prog("reaver").level == 6, "progress loaded from the validated backup")
	check(_rv_bytes(p) == good, "valid primary reinstalled from the backup")
	var kept := _rv_siblings(p, ".corrupt").any(func(n): return _rv_bytes(p.get_base_dir().path_join(n)) == junk)
	check(kept, "the unreadable primary is kept as .corrupt-*, not deleted")
	_qa_end(p)


func test_rv_no_valid_backup_keeps_everything() -> void:
	print("\n[REVIEW-001: unreadable primary AND unreadable backup: nothing recovered, nothing deleted]")
	var p: String = await _qa_begin("rv_nothing.json")
	var junk1 := "{\"characters\": {\"mage\": {\"level\": 9"
	var junk2 := "not json at all"
	for pair in [[p, junk1], [p + ".bak", junk2]]:
		var f := FileAccess.open(pair[0], FileAccess.WRITE)
		f.store_string(pair[1])
		f.close()
	check(not Save.recover_if_needed(), "an invalid backup is never restored")
	check(not Save.load_game(), "load reports failure instead of inventing data")
	check(_rv_bytes(p) == junk1 and _rv_bytes(p + ".bak") == junk2, "both files untouched by loading")
	Game.create_character("vanguard", "Aldric")   # a new save is written over the unreadable state
	var junk1_kept := _rv_siblings(p, ".corrupt").any(func(n): return _rv_bytes(p.get_base_dir().path_join(n)) == junk1)
	check(junk1_kept and _rv_bytes(p + ".bak") == junk2, "after a new save both unreadable files still exist")
	var d = _qa_parse(p)
	check(d is Dictionary and d.characters.vanguard.created, "the new save is valid")
	_qa_end(p)


func test_rv_newest_candidate_and_orphan_tmp() -> void:
	print("\n[REVIEW-001: newest valid candidate wins; a finished .tmp is never overwritten]")
	var p: String = await _rv_saved("rv_newest.json", 3)
	var older := _rv_bytes(p)
	Game.prog("reaver").set_level(7)
	Save.save_game()
	var newer := _rv_bytes(p)
	# crash state: older generation in .bak, newer fully written .tmp, no primary
	DirAccess.remove_absolute(p)
	for pair in [[p + ".bak", older.replace("\"saved_at\": \"", "\"saved_at\": \"0")], [p + ".tmp", newer]]:
		var f := FileAccess.open(pair[0], FileAccess.WRITE)
		f.store_string(pair[1])
		f.close()
	Game.reset_all_progress()
	check(Save.load_game() and Game.prog("reaver").level == 7, "the newer valid .tmp is recovered (saved_at)", "Lv %d from %s" % [Game.prog("reaver").level, Save.recovered_from])
	# finished .tmp next to a valid primary (crash between verify and install): kept as .orphan-*
	var f2 := FileAccess.open(p + ".tmp", FileAccess.WRITE)
	f2.store_string(newer)
	f2.close()
	check(Save.save_game(), "the next save succeeds", Save.last_error)
	check(_rv_siblings(p, ".orphan").any(func(n): return _rv_bytes(p.get_base_dir().path_join(n)) == newer), "the earlier finished .tmp is preserved as .orphan-*")
	_qa_end(p)


func test_rv_tools_isolate_real_save() -> void:
	print("\n[REVIEW-001: every test / screenshot tool that starts main.tscn isolates the save first]")
	var bad: Array = []
	var n := 0
	for fname in DirAccess.get_files_at("res://tests"):
		if not fname.ends_with(".gd") or fname == "update5_runner.gd":
			continue
		var txt := FileAccess.get_file_as_string("res://tests/" + fname)
		var at := txt.find("load(\"res://scenes/main.tscn\")")
		if at < 0:
			continue
		n += 1
		var before := txt.substr(0, at)
		if not (before.contains("test_save_guard.gd\").isolate(") or before.contains("Save.enabled = false")):
			bad.append(fname)
	check(n >= 9 and bad.is_empty(), "all %d scripts that start main.tscn disable / redirect saving first" % n, "unsafe: %s" % str(bad))
	# and the guard itself really redirects
	var real := Save.path
	var gp: String = preload("res://tests/test_save_guard.gd").isolate("selfcheck")
	check(not Save.enabled and Save.path == gp and gp.contains(".dev/reports") and gp != real, "the guard disables writing and redirects to .dev/reports")
	Save.path = real


func test_debug_taint() -> void:
	print("\n[Debug testing cannot corrupt a saved character]")
	await teardown()
	Save.enabled = true
	Save.path = fixture_path("test_save_u5.json")
	Save.delete_save()
	Game.reset_all_progress()
	Game.debug_tainted = false
	Game.create_character("vanguard", "Aldric")
	check(Save.has_save(), "normal character saved")
	Game.debug_unlock_all("vanguard")
	check(Game.debug_tainted, "debug unlock taints the session")
	Game.prog("vanguard").set_level(10)
	check(not Save.save_game(), "tainted session refuses to save", Save.last_error)
	Game.autosave()
	Game.reset_all_progress()
	Save.load_game()
	check(Game.prog("vanguard").level == 1 and Game.prog("vanguard").debug_unlocks.is_empty(), "saved character is still the clean Level 1 one")
	Save.delete_save()
	Save.enabled = false
	Game.debug_tainted = false


func test_unlock_gating() -> void:
	print("\n[Level 1 starts small; abilities unlock with the class track]")
	var h := await setup("vanguard", false, false, false)
	check(Game.prog().level == 1 and not h.unlocked("shield_rush"), "Vanguard L1: Shield Rush locked")
	check(h.unlocked("v_guard") and h.unlocked("v_counter"), "Vanguard L1: Aegis Guard + counter available")
	var w := dummy("raider", h.global_position + Vector3(0, 0, -6))
	face(h, w)
	tap(h, "skill1")
	await wait(0.1)
	check(not h.runner.is_busy(), "locked skill does nothing")
	Game.set_level("vanguard", 3)
	await wait(0.1)
	check(h.unlocked("shield_rush") and not h.unlocked("judgment_strike"), "L3 unlocks Shield Rush only")
	tap(h, "skill1")
	await wait(0.1)
	check(h.runner.is_busy(), "Shield Rush usable after unlock")
	var t := Game.track("mage")
	check(t.unlock_level("m_sanctum") == 5 and t.unlock_level("m_renewal") == 7 and t.unlock_level("m_arcane_mastery") == 10, "Mage track milestones (Grand Elementalist)")
	check(Game.track("reaver").draft_levels.keys().size() == 3, "3 drafts per track")


func test_stat_preview() -> void:
	print("\n[Stat allocation preview = real formulas]")
	var h := await setup("vanguard", false, false, false)
	Game.set_level("vanguard", 2)
	var p := Game.prog()
	var before := StatPreview.derived("vanguard", p)
	check(absf(before["Max HP"] - h.max_hp) < 0.01 and absf(before["Weapon Power"] - h.weapon_power) < 0.01, "preview(current) == live hero stats")
	var prev := StatPreview.with_pending("vanguard", p, {"vit": 1, "str": 1})
	check(int(p.allocated.vit) == 0, "preview does not change the character")
	check(p.allocate("vit") and p.allocate("str"), "points allocated", "free %d" % p.free_points)
	Game.refresh_class_heroes("vanguard")
	check(absf(prev["Max HP"] - h.max_hp) < 0.01, "VIT preview matches actual Max HP", "%.1f vs %.1f" % [prev["Max HP"], h.max_hp])
	check(absf(prev["Heavy Damage"] - h.stats.heavy_mult()) < 0.0001 and absf(prev["Crit Damage"] - h.stats.crit_damage_total()) < 0.0001, "STR preview matches heavy/crit dmg")
	p.reset_allocation()
	check(int(p.allocated.vit) == 0 and p.free_points > 0, "reset stats returns points")


func test_equipment() -> void:
	print("\n[Equipment changes real stats]")
	var h := await setup("reaver", false, false, false)
	Game.prog().equipment["weapon"] = "starter_r_sword"
	Game.refresh_class_heroes("reaver")
	var wp0 := h.weapon_power
	var crit0 := h.stats.crit_chance
	var prev := StatPreview.with_item("reaver", Game.prog(), "r_crimson_blade")
	Game.give_item("reaver", "r_crimson_blade")
	check(Game.prog().inventory.has("r_crimson_blade"), "item added to inventory")
	check(Game.equip("reaver", "r_crimson_blade"), "equip succeeds")
	check(h.weapon_power > wp0 or h.stats.crit_chance > crit0, "better weapon raises weapon power / crit", "%.1f -> %.1f" % [wp0, h.weapon_power])
	check(absf(prev["Weapon Power"] - h.weapon_power) < 0.01, "equip preview matches result")
	check(Game.prog().inventory.has("starter_r_sword"), "old weapon returns to inventory")
	check(not Game.equip("reaver", "v_knight_sword"), "other-class item cannot be equipped")
	check(Game.unequip("reaver", "weapon") and h.weapon_power < wp0 + 0.01, "unequip removes the bonus")


func _mage_setup(unlock_lvl: int) -> Hero:
	var h := await setup("mage", true, false, false)
	Game.mage_core = "sigils"        # Ley Sigils is now a rejected legacy core (debug comparison)
	Game.set_level("mage", unlock_lvl)
	for o in Game.heroes:
		if o != h:
			o.get_node("Brain").set_physics_process(false)
	h.restore_all()
	return h


func test_sigils_heal_without_attacking() -> void:
	print("\n[Mage Ley Sigils: healing without attacking first]")
	var h := await _mage_setup(1)
	var kit: MageKit = h.kit
	check(kit.sigil_core(), "Ley Sigils legacy core selectable for comparison")
	var ally: Hero = null
	for o in Game.heroes:
		if o != h:
			ally = o
			break
	ally.global_position = h.global_position + Vector3(1.5, 0, 0)
	ally.hp = ally.max_hp * 0.4
	var hp0 := ally.hp
	tap(h, "life")                 # Mend - direct heal, no attack needed
	await wait(0.9)
	check(ally.hp > hp0, "Mend heals an ally immediately", "%.0f -> %.0f" % [hp0, ally.hp])
	check(kit.last_element == "life", "last cast element = Life")
	ally.hp = ally.max_hp * 0.4
	hp0 = ally.hp
	tap(h, "core")
	await wait(0.1)
	check(kit.sigils.size() == 1 and kit.sigils[0].element == "life", "E inscribes a Life Sigil")
	await wait(2.2)
	check(ally.hp > hp0, "Life Sigil pulses heal allies inside (no enemy involved)", "%.0f -> %.0f" % [hp0, ally.hp])
	check(Game.enemies().is_empty(), "no enemies were present")
	ally.hp = ally.max_hp * 0.2
	hp0 = ally.hp
	Game.set_level("mage", 3)
	await wait(0.4)
	tap(h, "life")
	await wait(0.9)
	check(ally.statuses.has("lifeline"), "Lv3 Lifeline: emergency Mend protects a critical ally")


func test_sigils_offense_resonance_consume() -> void:
	print("\n[Mage Ley Sigils: elements, Resonance, consume]")
	var h := await _mage_setup(5)
	var kit: MageKit = h.kit
	var w := dummy("raider", h.global_position + Vector3(0, 0, -7))
	w.max_hp = 99999
	w.hp = 99999
	face(h, w)
	h.lock_target = w
	tap(h, "light")                 # Firebolt -> last element Fire
	await wait(0.9)
	check(kit.last_element == "fire", "Firebolt sets Fire as the sigil element")
	tap(h, "core")
	await wait(0.1)
	check(kit.sigils.size() == 1 and kit.sigils[0].element == "fire" and kit.sigils[0].contains(w.global_position), "Fire Sigil placed under the locked target")
	var hp1 := w.hp
	await wait(2.2)
	check(w.hp < hp1, "Fire Sigil pulses damage enemies inside", "%.0f" % (hp1 - w.hp))
	CombatLog.clear()
	kit.mana = 100.0
	tap(h, "light")
	await wait(1.0)
	check(log_has("Resonance: Flare"), "Lv5 Resonance: Firebolt into a Fire Sigil triggers a flare")
	await wait(0.4)
	CombatLog.clear()
	tap(h, "core")                  # at the limit -> consume
	await wait(0.2)
	check(kit.sigils.is_empty() and log_has("Fire Sigil Eruption"), "E at the sigil limit consumes it (Fire eruption)")
	# Frost behaves differently: chill/freeze rather than damage over time
	kit.mana = 100.0
	Game.prog().unlock_element("frost")
	Game.prog().slots[1] = "frost"
	tap(h, "heavy")
	await wait(0.9)
	tap(h, "core")
	await wait(1.4)
	check(kit.sigils.size() == 1 and kit.sigils[0].element == "frost" and w.statuses.has("sigil_chill"), "Frost Sigil chills instead of burning")
	Game.set_level("mage", 9)
	await wait(0.2)
	check(kit.sigil_limit() == 2, "Lv9 Twin Sigils raises the limit to 2")


func test_openings_and_cuts() -> void:
	print("\n[Reaver Sword Sense: Openings + cuts]")
	var h := await setup("reaver", false, false, false)
	var kit: ReaverKit = h.kit
	check(kit.sense_core(), "Sword Sense is the default Reaver core")
	var r := dummy("raider", h.global_position + Vector3(0, 0, -1.8))
	r.max_hp = 99999
	r.hp = 99999
	r.target = h
	face(r, h)
	face(h, r)
	check(not r.has_opening(), "no Opening while idle")
	h.global_position = r.global_position + Vector3(0, 0, 4.5)      # out of reach of the swing
	face(h, r)
	r.begin_attack(r.find_attack("raider_heavy"))
	await wait(rh() + r.find_attack("raider_heavy").active + 0.05)
	check(r.has_opening() and r.opening_kind == "recovery", "enemy recovery creates an Opening", r.opening_kind)
	h.global_position = r.global_position + Vector3(0, 0, 1.7)
	face(h, r)
	CombatLog.clear()
	var st0 := h.stamina
	tap(h, "light")
	await wait(0.3)
	check(log_has("Quick Cut") and kit.cuts["Tempo Cut"] >= 1, "light on an Opening = Tempo Cut")
	check(r.has_opening(), "Tempo Cut keeps the Opening")
	await wait(0.25)
	tap(h, "heavy")
	await wait(0.7)
	check(kit.cuts["Sunder Cut"] >= 1, "heavy on an Opening = Sunder Cut")
	check(not r.has_opening() or r.opening_kind == "stagger", "Sunder Cut consumes the Opening")
	# without an Opening there is no cut bonus
	await wait(1.5)
	r.consume_opening()
	var c0: int = kit.cuts["Tempo Cut"]
	h.restore_all()
	tap(h, "light")
	await wait(0.4)
	check(kit.cuts["Tempo Cut"] == c0, "no cut without an Opening (no automatic procs)")
	# Vital Cut needs Piercing Lunge (Lv7)
	Game.set_level("reaver", 7)
	await wait(1.0)
	r.open_window("stagger", 2.0)
	h.restore_all()
	face(h, r)
	tap(h, "skill1")
	await wait(0.6)
	check(kit.cuts["Vital Cut"] >= 1 and log_has("CRIT"), "Piercing Lunge on an Opening = guaranteed-crit Vital Cut")


func test_perfect_dodge_opening() -> void:
	print("\n[Reaver Lv5 Perfect Dodge -> Opening]")
	var h := await setup("reaver", false, false, false)
	Game.set_level("reaver", 5)
	var r := dummy("raider", h.global_position + Vector3(0, 0, -1.8))
	r.target = h
	face(r, h)
	r.begin_attack(r.find_attack("raider_heavy"))
	await wait(rh() - 0.1)
	h.move_input = Vector3(1, 0, 0)
	tap(h, "dodge")
	h.move_input = Vector3.ZERO
	await wait(0.35)
	check(log_has("dodged"), "attack dodged")
	check(r.has_opening() and (r.opening_kind == "dodge" or r.opening_kind == "recovery"), "Perfect Dodge opens the attacker", r.opening_kind)


func test_training_dummy() -> void:
	print("\n[Training dummy + stats]")
	var h := await setup("reaver", false, false, false)
	if not Game.ENEMY_SCENES.has("training_dummy"):
		check(false, "training dummy enemy exists")
		return
	var d := Game.spawn_enemy("training_dummy", h.global_position + Vector3(0, 0, -1.7))
	face(h, d)
	await wait(0.1)
	Training.reset()
	tap(h, "light")
	await wait(0.4)
	tap(h, "light")
	await wait(0.4)
	check(Training.total > 0.0 and Training.hits == 2, "training records total + per-hit", "%.0f / %d" % [Training.total, Training.hits])
	check(Training.per_skill.size() >= 1 and Training.dps() > 0.0, "per-skill breakdown + DPS")
	check(not d.dead and d.hp > 0.0, "dummy never dies")
	Training.save_baseline()
	check(not Training.baseline.is_empty(), "baseline snapshot for before/after comparison")
