extends Node
## Automated gameplay test-suite. Run headless with deterministic time:
##   godot --headless --fixed-fps 60 res://tests/test_runner.tscn
## Every test spins up a real Ashen Valley session and drives heroes through the same
## press()/release() interface the player uses, then inspects state and the combat log.

var passed: int = 0
var failed: int = 0
var failures: Array = []
var world: Node3D


func _ready() -> void:
	CombatLog.echo_to_stdout = false
	Game.auto_open_drafts = false
	Save.enabled = false       # never touch the user's real save while testing
	Save.path = "user://test_save.json"
	await get_tree().process_frame
	await _run_all()
	print("\n==== RESULTS: %d passed, %d failed ====" % [passed, failed])
	for f in failures:
		print("  FAIL: ", f)
	get_tree().quit(1 if failed > 0 else 0)


func check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  PASS  ", name, ("  (" + detail + ")") if detail != "" else "")
	else:
		failed += 1
		failures.append(name + "  " + detail)
		print("  FAIL  ", name, "  ", detail)


func wait(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame


## Legacy tests run with every milestone unlocked and the legacy cores (weave / bladecraft) so the
## mechanics they check are reachable; Update 5 tests pass `legacy=false, unlock=false`.
func setup(class_id: String, party: bool = false, legacy: bool = true, unlock: bool = true) -> Hero:
	await teardown()
	Game.reset_all_progress()
	for c in Game.CLASSES:
		Game.prog(c).created = true
		if unlock:
			for m in Game.track(c).milestones:
				if m.kind != "stats" and m.kind != "augment":
					Game.prog(c).debug_unlocks.append(m.id)
	Game.mage_core = "weave" if legacy else "elementalist"
	Game.reaver_core = "bladecraft" if legacy else "sense"
	Game.permadeath = true
	Game.invincible = false
	Game.party_mode = false
	CombatLog.clear()
	world = load("res://scenes/world/ashen_valley.tscn").instantiate()
	add_child(world)
	# park the session somewhere without encounter triggers
	Game.start_session(world, class_id, party)
	Game.player.global_position = Vector3(0, 0.2, 26)
	await wait(0.2)
	return Game.player


func teardown() -> void:
	get_tree().paused = false
	if is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Game.heroes.clear()
	Game.player = null
	Game.world = null


func dummy(type: String, pos: Vector3, freeze: bool = true, elite: bool = false) -> Enemy:
	var e := Game.spawn_enemy(type, pos, "outskirts", elite)
	if freeze:
		e.sm.set_physics_process(false)
	return e


func tap(h: Hero, a: String) -> void:
	h.press(a)
	h.release(a)


func log_has(text: String, cat: String = "") -> bool:
	for e in CombatLog.lines:
		if (cat == "" or e.cat == cat) and String(e.text).contains(text):
			return true
	return false


func log_count(text: String) -> int:
	var n := 0
	for e in CombatLog.lines:
		if String(e.text).contains(text):
			n += 1
	return n


func rh() -> float:
	return (load("res://data/attacks/raider_heavy.tres") as AttackData).startup


func face(h: Node3D, target: Node3D) -> void:
	h.face_dir(target.global_position - h.global_position)


# =====================================================================
func _run_all() -> void:
	await test_core_combat()
	await test_dodge_and_enemy_hits()
	await test_vanguard_guard()
	await test_vanguard_skills_and_augments()
	await test_vanguard_approach()
	await test_telegraph_before_damage()
	await test_interception_last_line()
	await test_mage()
	await test_reaver_bladecraft()
	await test_reaver_augments()
	await test_stats_identities()
	await test_progression_and_drafts()
	await test_true_death()
	await test_downed_revive()
	await test_enemy_types()
	await test_boss_phases()
	await test_party_ai()
	await test_stage_exp_budget()
	await test_lock_on_switching()
	await test_lock_camera_transitions()
	await teardown()


func test_core_combat() -> void:
	print("\n[Core combat: Reaver light hits a wolf, hitstop, combo]")
	var h := await setup("reaver")
	var w := dummy("wolf", h.global_position + Vector3(0, 0, -1.6))
	face(h, w)
	var hp0 := w.hp
	tap(h, "light")
	await wait(0.4)
	check(w.hp < hp0, "light attack damages enemy via Area3D hitbox", "%.0f -> %.0f" % [hp0, w.hp])
	check(log_has("Quick Cut"), "combat log records the hit")
	tap(h, "light")
	await wait(0.35)
	tap(h, "light")
	await wait(0.35)
	check(h.kit.combo == 3 or log_has("Piercing Step"), "light combo advances (1->2->3)")
	var r := h.runner
	r.start(load("res://data/attacks/r_heavy.tres"), {}, 1.0)
	check(not r.can_cancel(), "heavy attack is not cancellable during startup (commitment)")
	await wait(1.2)
	check(not r.is_busy(), "attack finishes after startup+active+recovery")


func test_dodge_and_enemy_hits() -> void:
	print("\n[Dodge i-frames + enemy hitboxes]")
	var h := await setup("reaver")
	var raider := dummy("raider", h.global_position + Vector3(0, 0, -1.8))
	raider.target = h
	face(raider, h)
	var hp0 := h.hp
	raider.begin_attack(raider.find_attack("raider_heavy"))
	await wait(rh() + 0.6)
	check(h.hp < hp0, "enemy heavy hits an idle hero", "%.0f -> %.0f" % [hp0, h.hp])
	await wait(1.6)
	h.restore_all()
	hp0 = h.hp
	raider.begin_attack(raider.find_attack("raider_heavy"))
	await wait(rh() - 0.1)
	h.move_input = Vector3(1, 0, 0)
	tap(h, "dodge")
	h.move_input = Vector3.ZERO
	await wait(0.6)
	check(log_has("dodged"), "dodge i-frames negate the hit", "hp %.0f -> %.0f" % [hp0, h.hp])
	check(h.stamina < h.max_stamina, "dodge consumes stamina")


func test_vanguard_guard() -> void:
	print("\n[Vanguard Aegis Guard: normal / perfect / guard break / counter]")
	var h := await setup("vanguard")
	var kit: VanguardKit = h.kit
	var raider := dummy("raider", h.global_position + Vector3(0, 0, -1.8))
	raider.target = h
	face(h, raider)
	face(raider, h)
	# normal guard (raised long before impact)
	h.press("guard")
	raider.begin_attack(raider.find_attack("raider_heavy"))
	await wait(rh() + 0.45)
	check(log_has("guarded", "guard"), "normal guard registers")
	check(kit.resolve >= 5.0, "normal guard generates Resolve", "resolve %.0f" % kit.resolve)
	h.release("guard")
	await wait(2.2)
	# perfect guard (raised right before the hit)
	CombatLog.clear()
	kit.resolve = 0.0
	var hp0 := h.hp
	raider.begin_attack(raider.find_attack("raider_heavy"))
	await wait(rh() - 0.09)
	h.press("guard")
	await wait(0.4)
	check(log_has("PERFECT GUARD"), "perfect guard when guard raised just before impact")
	check(kit.resolve >= 20.0, "perfect guard grants more Resolve", "resolve %.0f" % kit.resolve)
	check(hp0 - h.hp < 5.0, "perfect guard nearly negates damage", "lost %.1f" % (hp0 - h.hp))
	check(Game.time < kit.counter_until, "perfect guard opens counter window")
	h.release("guard")
	tap(h, "light")
	await wait(0.1)
	check(h.runner.is_busy() and h.runner.data.id == "v_counter", "light during counter window = Aegis Counter")
	await wait(1.5)
	# guard break
	CombatLog.clear()
	var g := dummy("shield_guardian", h.global_position + Vector3(0, 0, -2.0))
	g.target = h
	face(g, h)
	face(h, g)
	raider.global_position += Vector3(10, 0, 0)
	h.press("guard")
	await wait(0.5)
	g.begin_attack(g.find_attack("guardian_breaker"))
	await wait(g.find_attack("guardian_breaker").startup + 0.5)
	check(log_has("GUARD BROKEN"), "Guard Breaker breaks a normal guard")
	h.release("guard")


func test_vanguard_skills_and_augments() -> void:
	print("\n[Vanguard skills + Iron Reprisal / Crushing Rhythm / Steadfast / Unyielding / Phantom Bulwark]")
	var h := await setup("vanguard")
	var kit: VanguardKit = h.kit
	var w := dummy("shield_guardian", h.global_position + Vector3(0, 0, -2.0))
	w.max_hp = 99999
	w.hp = 99999
	face(h, w)
	w.rotation.y += PI   # turn its shield away so all hits connect
	# Iron Sweep multi-hit -> Crushing Rhythm
	Game.add_augment("vanguard", "crushing_rhythm")
	tap(h, "skill3")
	await wait(1.4)
	check(log_count("Iron Sweep") >= 3, "Iron Sweep lands 3 hits", "hits logged %d" % log_count("Iron Sweep"))
	check(kit.crushing_ready, "Crushing Rhythm primed after all hits connect")
	# Iron Reprisal via perfect guard then heavy
	Game.add_augment("vanguard", "iron_reprisal")
	var raider := dummy("raider", h.global_position + Vector3(2.5, 0, 0))
	raider.target = h
	face(raider, h)
	face(h, raider)
	raider.begin_attack(raider.find_attack("raider_heavy"))
	await wait(rh() - 0.09)
	h.press("guard")
	await wait(0.3)
	h.release("guard")
	check(Game.time < kit.reprisal_until, "Iron Reprisal armed by Perfect Guard")
	await wait(0.4)
	CombatLog.clear()
	face(h, w)
	tap(h, "heavy")
	await wait(1.2)
	check(log_has("Iron Reprisal", "augment") and log_has("Crushing Rhythm", "augment"), "Iron Reprisal + Crushing Rhythm both modify the heavy (multiplicative poise)")
	raider.queue_free()
	# Steadfast stamina reduction (additive stacking)
	Game.add_augment("vanguard", "steadfast")
	Game.add_augment("vanguard", "steadfast")
	Game.add_augment("vanguard", "steadfast")
	check(Game.prog("vanguard").augment_stacks("steadfast") == 2, "Steadfast stacks to max 2 (third refused)")
	# Judgment Strike charge + Unyielding Charge
	Game.add_augment("vanguard", "unyielding_charge")
	await wait(1.0)
	h.press("skill2")
	await wait(0.3)
	var info := DamageInfo.new()
	info.source = w
	info.amount = 50.0
	info.raw_amount = 50.0
	info.poise = 30.0
	info.source_pos = h.global_position + h.forward() * 2.0
	h.take_damage(info)
	check(log_has("Unyielding Charge", "augment"), "Unyielding Charge reduces frontal damage while charging", "took %.1f of 50 raw" % info.final_amount)
	await wait(1.0)
	h.release("skill2")
	await wait(0.2)
	check(h.runner.is_busy() and h.runner.data.is_charged, "Judgment Strike released as charged attack")
	await wait(1.4)
	# Phantom Bulwark
	Game.add_augment("vanguard", "phantom_bulwark")
	kit.cooldowns.clear()
	kit.resolve = 0.0
	tap(h, "skill1")
	await wait(1.2)
	var barriers := get_tree().get_nodes_in_group("barriers")
	check(barriers.size() == 1, "Phantom Bulwark spawns a barrier at the end of Shield Rush")
	if barriers.size() == 1:
		var b: Barrier = barriers[0]
		var hp_b := b.hp
		var hit := DamageInfo.new()
		hit.source = w
		hit.amount = 30.0
		hit.raw_amount = 30.0
		hit.source_pos = b.global_position + Vector3(10, 0, 0)
		h.global_position = b.global_position
		h.take_damage(hit)
		check(b.hp < hp_b and hit.absorbed > 0.0, "barrier absorbs damage from outside attackers", "absorbed %.0f" % hit.absorbed)
		var p_hits_before := b.hp
		var caster := dummy("ash_caster", b.global_position + Vector3(0, 0, -12))
		caster.target = h
		caster.fire_projectile(caster.find_attack("caster_bolt"), h)
		await wait(1.2)
		check(not is_instance_valid(b) or b.hp < p_hits_before, "barrier blocks enemy projectiles")


func test_interception_last_line() -> void:
	print("\n[Vanguard interception + Last Line (Party Test)]")
	var h := await setup("vanguard", true)
	var mage: Hero = null
	for o in Game.heroes:
		if o.class_id == "mage":
			mage = o
	for o in Game.heroes:
		if o != h:
			o.get_node("Brain").set_physics_process(false)
	Game.add_augment("vanguard", "last_line")
	mage.global_position = h.global_position + Vector3(0, 0, -5)
	var r := dummy("raider", mage.global_position + Vector3(0, 0, -1.8))
	r.target = mage
	face(r, mage)
	face(h, mage)
	r.begin_attack(r.find_attack("raider_heavy"))
	await wait(0.15)
	var hp_m := mage.hp
	tap(h, "skill1")
	await wait(1.5)
	check(log_has("INTERCEPTED"), "Shield Rush toward endangered ally intercepts the blow")
	check(mage.hp >= hp_m - 0.5, "ally takes no damage", "%.0f -> %.0f" % [hp_m, mage.hp])
	check(h.statuses.has("last_line"), "Last Line buff granted on interception")


func test_mage() -> void:
	print("\n[Mage: quick/charged spells, Echoes, Arcane Weave fusions, discoveries, augments]")
	var h := await setup("mage", true)
	for o in Game.heroes:
		if o != h:
			o.get_node("Brain").set_physics_process(false)
	var kit: MageKit = h.kit
	var w := dummy("raider", h.global_position + Vector3(0, 0, -8))
	w.max_hp = 99999
	w.hp = 99999
	face(h, w)
	h.lock_target = w
	tap(h, "light")
	await wait(0.9)
	check(w.hp < 99999, "Firebolt (quick) hits", "%.0f dmg" % (99999 - w.hp))
	check(w.statuses.has("burn"), "Firebolt applies Burn DoT")
	h.press("light")
	await wait(0.6)
	h.release("light")
	await wait(1.3)
	check(log_has("Fireball"), "holding = charged cast (Fireball explosion)")
	kit.mana = 100
	# Life: hurt an ally
	var ally: Hero = Game.heroes.filter(func(x): return x != h)[0]
	ally.hp = ally.max_hp * 0.4
	ally.global_position = h.global_position + Vector3(2, 0, 0)
	var ahp := ally.hp
	tap(h, "life")
	await wait(0.7)
	check(ally.hp > ahp, "Mend heals the most wounded ally", "%.0f -> %.0f" % [ahp, ally.hp])
	check(kit.echoes.size() == 2 and kit.fusion_key() == "fire+life", "two most recent Echoes stored", str(kit.echoes))
	kit.mana = 100
	tap(h, "core")
	await wait(0.8)
	check(log_has("Phoenix Bloom", "fusion"), "Fire+Life weave = Phoenix Bloom")
	await wait(1.5)
	# Life + Life
	kit.mana = 100
	tap(h, "life")
	await wait(0.7)
	tap(h, "life")
	await wait(0.7)
	tap(h, "core")
	await wait(0.8)
	check(log_has("Sanctuary", "fusion"), "Life+Life weave = Sanctuary")
	# Discoveries
	check(Game.augment_db.ineligible_reason(Game.augment_db.get_augment("living_current"), Game.prog("mage")) != "", "Living Current hidden until Storm is known")
	Game.choose_augment("mage", "frost_discovery")
	Game.choose_augment("mage", "storm_discovery")
	check(Game.prog("mage").elements.has("frost") and Game.prog("mage").elements.has("storm"), "Frost/Storm discoveries unlock elements")
	check(Game.augment_db.ineligible_reason(Game.augment_db.get_augment("frost_discovery"), Game.prog("mage")) != "", "discovery not offered again once known")
	var p := Game.prog("mage")
	var combos := [["fire", "frost", "Thermal Fracture"], ["frost", "life", "Winter's Embrace"], ["fire", "storm", "Plasma Surge"], ["storm", "life", "Vital Current"]]
	for c in combos:
		kit.mana = 100
		kit.weave_cd = 0
		kit.echoes = [c[0], c[1]]
		CombatLog.clear()
		tap(h, "core")
		await wait(0.9)
		check(log_has(c[2], "fusion"), "%s + %s weave = %s" % [c[0], c[1], c[2]])
	# slot cycling + frost/storm casts
	p.slots = ["frost", "storm"]
	kit.mana = 100
	tap(h, "light")
	await wait(0.8)
	check(w.statuses.has("chill"), "Ice Shard applies Chill")
	tap(h, "heavy")
	await wait(0.6)
	check(log_has("Spark"), "Spark (storm quick) chains")
	# Augments
	Game.add_augment("mage", "living_flame")
	Game.add_augment("mage", "spell_echo")
	Game.add_augment("mage", "gentle_restoration")
	Game.add_augment("mage", "living_current")
	p.slots = ["fire", "storm"]
	kit.mana = 100
	CombatLog.clear()
	tap(h, "light")
	await wait(0.6)
	tap(h, "life")
	await wait(1.2)
	check(log_has("Living Flame", "augment"), "Living Flame leaves burning ground")
	check(log_has("Spell Echo", "augment"), "Spell Echo re-casts the previous spell (Firebolt -> Mend)")
	ally.hp = ally.max_hp
	h.hp = h.max_hp
	kit.mana = 100
	tap(h, "life")
	await wait(0.7)
	check(log_has("Gentle Restoration", "augment"), "Gentle Restoration converts overheal to HoT")
	ally.hp = ally.max_hp * 0.5
	tap(h, "heavy")
	await wait(0.7)
	check(log_has("Living Current", "augment"), "Living Current: storm damage heals an ally")


func test_reaver_bladecraft() -> void:
	print("\n[Reaver Bladecraft: Split / Focus / Precision change the actual attack; disable toggle]")
	var h := await setup("reaver")
	var w := dummy("raider", h.global_position + Vector3(0, 0, -1.8))
	w.max_hp = 99999
	w.hp = 99999
	face(h, w)
	var base_heavy: AttackData = load("res://data/attacks/r_heavy.tres")
	tap(h, "skill1")
	tap(h, "heavy")
	await wait(0.05)
	var d := h.runner.data
	check(d.hits == 4 and d.anim_style == "flurry" and not d.is_heavy, "Split: heavy -> 4-hit flurry, DEX-scaled", "hits %d" % d.hits)
	CombatLog.clear()
	await wait(1.4)
	check(log_count("Split") >= 4, "Split hits connect separately", "%d hit lines" % log_count("Split"))
	tap(h, "skill2")
	tap(h, "heavy")
	await wait(0.05)
	d = h.runner.data
	check(d.is_heavy and d.anim_style == "slam" and d.damage_mult > base_heavy.damage_mult and d.startup > base_heavy.startup, "Focus: slower, heavier single slam")
	await wait(1.5)
	tap(h, "skill3")
	tap(h, "light")
	await wait(0.05)
	d = h.runner.data
	check(d.has_tag("precision") and d.anim_style == "thrust" and d.hitbox_size.z >= 3.0, "Precision: narrow thrust with long hitbox")
	await wait(0.8)
	# situational crit on staggered target
	w.stagger(2.0)
	var crit_bonus: float = h.kit.situational_crit(d, w, {})
	check(crit_bonus >= 0.4, "Precision gains crit chance vs staggered target", "%.2f" % crit_bonus)
	await wait(2.0)
	# Focus not eligible on plain light
	tap(h, "skill2")
	tap(h, "light")
	await wait(0.05)
	check(h.runner.data.hits <= 1 and h.runner.data.anim_style != "slam", "Focus is not eligible on non-finisher lights (stays armed)")
	await wait(0.6)
	# Critical Test: disable Bladecraft
	Game.set_flag("bladecraft_enabled", false)
	h.restore_all()
	tap(h, "skill1")
	await wait(0.6)
	tap(h, "heavy")
	await wait(0.05)
	check(h.runner.data.hits == 1 and h.runner.data.anim_style == "slash_v", "Bladecraft disabled: forms cannot be armed, normal heavy remains")
	check(Game.augment_db.ineligible_reason(Game.augment_db.get_augment("execution_line"), Game.prog("reaver")) != "", "Bladecraft-only augments hidden from drafts when disabled")
	await wait(1.2)
	h.restore_all()
	CombatLog.clear()
	w.global_position = h.global_position + h.forward() * 1.6
	tap(h, "light")
	await wait(0.3)
	tap(h, "light")
	await wait(0.3)
	check(log_has("Back Cut"), "normal light combos still work without Bladecraft")
	Game.set_flag("bladecraft_enabled", true)


func test_reaver_augments() -> void:
	print("\n[Reaver augments]")
	var h := await setup("reaver")
	var kit: ReaverKit = h.kit
	var base: AttackData = load("res://data/attacks/r_heavy.tres")
	Game.add_augment("reaver", "splintering_steel")
	var r: Array = kit.build_attack(base, "heavy")
	check(r[0].hits == 3 and r[0].anim_style == "flurry", "Splintering Steel: heavy -> 3 hits")
	Game.add_augment("reaver", "one_perfect_cut")
	r = kit.build_attack(base, "heavy")
	var w: PackedFloat32Array = r[0].hit_weights
	check(w.size() == 3 and w[2] > w[0] and r[0].final_hit_heavy, "One Perfect Cut concentrates the final hit", str(w))
	Game.add_augment("reaver", "legacy_flowing_edge")
	r = kit.build_attack(base, "heavy")
	check(r[0].move_during > 0.0, "(legacy core) Flowing Edge allows movement during multi-hit")
	kit.armed_form = "split"
	kit.armed_until = Game.time + 3.0
	r = kit.build_attack(base, "heavy")
	check(r[0].hits == 5, "Splintering + Split stack (+2 hits)", "hits %d" % r[0].hits)
	Game.add_augment("reaver", "execution_line")
	kit.armed_form = "precision"
	kit.armed_until = Game.time + 3.0
	r = kit.build_attack(load("res://data/attacks/r_light1.tres"), "light")
	check(r[0].display_name == "Execution Line" and r[0].hitbox_size.z > 5.0 and r[0].hitbox_size.x < 0.5, "Execution Line: longer, narrower precision", "%s" % r[0].hitbox_size)
	Game.add_augment("reaver", "rising_crescent")
	r = kit.build_attack(base, "heavy")
	check(r[0].anim_style == "rising" and r[0].stagger_on_hit > 0.0, "Rising Crescent replaces uncharged heavy with a launching rising strike")
	r = kit.build_attack(load("res://data/attacks/r_charged.tres"), "charged")
	check(r[0].hits == 3, "Splintering still applies to charged when Rising Crescent owns the plain heavy")
	# Unbroken Form: arming a different form mid transformed attack enables early cancel
	Game.add_augment("reaver", "unbroken_form")
	var dummy_w := dummy("raider", h.global_position + Vector3(0, 0, -1.8))
	face(h, dummy_w)
	tap(h, "skill1")
	tap(h, "light")
	await wait(0.25)
	var st := h.stamina
	tap(h, "skill2")
	check(h.runner.cancel_override and h.stamina < st, "Unbroken Form: seamless transition at extra stamina cost")
	await wait(1.0)


func test_stats_identities() -> void:
	print("\n[Stat identities]")
	var h := await setup("reaver")
	var p := Game.prog("reaver")
	var s0 := StatBlock.for_class("reaver", p, Game.balance)
	p.debug_bonus["str"] = 20
	var s1 := StatBlock.for_class("reaver", p, Game.balance)
	check(s1.heavy_mult() > s0.heavy_mult() and s1.crit_damage_total() > s0.crit_damage_total() and s1.multihit_mult() == s0.multihit_mult(), "STR: heavy/charged + crit damage only")
	p.debug_bonus["str"] = 0
	p.debug_bonus["dex"] = 20
	var s2 := StatBlock.for_class("reaver", p, Game.balance)
	check(s2.multihit_mult() > s0.multihit_mult() and s2.heavy_mult() == s0.heavy_mult(), "DEX: multi-hit total only")
	p.debug_bonus["dex"] = 0
	p.debug_bonus["vit"] = 10
	var s3 := StatBlock.for_class("reaver", p, Game.balance)
	check(s3.max_hp() > s0.max_hp() and s3.effective_armor() == s0.effective_armor(), "VIT: max HP only")
	p.debug_bonus["vit"] = 0
	p.debug_bonus["for"] = 10
	var s4 := StatBlock.for_class("reaver", p, Game.balance)
	check(s4.effective_armor() > s0.effective_armor() and s4.armor == s0.armor, "FOR: improves existing armor effectiveness")
	p.debug_bonus["for"] = 0
	p.debug_bonus["mas"] = 10
	var s5 := StatBlock.for_class("reaver", p, Game.balance)
	check(s5.effect_power() > s0.effect_power() and s5.max_hp() == s0.max_hp(), "MAS: buff/debuff/DoT/HoT power")
	p.debug_bonus["mas"] = 0
	# DEX on combined total: 4-hit total equals 1-hit total * multihit
	var d1 := AttackData.new()
	d1.damage_mult = 1.0
	d1.hits = 1
	var d4 := d1.clone()
	d4.hits = 4
	var w := dummy("raider", h.global_position + Vector3(0, 0, -5))
	h.stats.crit_chance = 0.0
	var one := h.build_damage(d1, w, 0, {}).amount
	var four := 0.0
	for i in 4:
		four += h.build_damage(d4, w, i, {}).amount
	check(absf(four - one * h.stats.multihit_mult()) < 0.01, "multi-hit: DEX applied to the TOTAL then split per hit", "1-hit %.1f, 4-hit total %.1f" % [one, four])
	h.refresh_stats(true)


func test_progression_and_drafts() -> void:
	print("\n[Leveling + augment drafts]")
	var h := await setup("reaver")
	Game.gain_exp(80, "test")
	check(Game.prog().level == 2 and Game.prog().pending_drafts == 0 and Game.prog().free_points > 0, "level 2 grants stat points, no draft (Update 5 track)")
	while Game.prog().level < 4:
		Game.gain_exp(40, "test")
	check(Game.prog().level == 4 and Game.prog().pending_drafts == 1, "level 4 grants the first augment draft")
	var cards := Game.roll_draft("reaver")
	var ids := {}
	var all_reaver := true
	for c in cards:
		ids[c.id] = true
		if c.class_id != "reaver":
			all_reaver = false
	check(cards.size() == 3 and ids.size() == 3 and all_reaver, "draft = 3 distinct cards from the class pool")
	Game.choose_augment("reaver", cards[0].id)
	var again := Game.roll_draft("reaver")
	var dup := false
	for c in again:
		if c.id == cards[0].id:
			dup = true
	check(not dup, "owned non-stackable augment not offered again")
	Game.gain_exp(100000, "test")
	check(Game.prog().level == 10, "capped at level 10")
	check(Game.prog().pending_drafts + Game.prog().drafts_taken == 3, "3 augment drafts across levels 1-10 (L4 / L8 / L10)")
	check(Game.prog("mage").level == 1 and Game.prog("vanguard").level == 1, "other classes' levels untouched")
	# rarity weighting sanity
	var counts := {"standard": 0, "advanced": 0, "exotic": 0}
	var p := ClassProgress.new("vanguard")
	for i in 400:
		for c in Game.augment_db.roll("vanguard", p, 1, Game.rng):
			counts[c.rarity] += 1
	check(counts.standard > counts.exotic, "rarity weights respected", str(counts))


func test_true_death() -> void:
	print("\n[True Death resets only the active class]")
	var h := await setup("reaver")
	Game.gain_exp(600, "test")
	Game.add_augment("reaver", "flowing_edge")
	Game.prog("mage").level = 3
	h.hp = 1
	var info := DamageInfo.new()
	info.amount = 100
	info.raw_amount = 100
	info.source_pos = h.global_position
	h.take_damage(info)
	check(h.downed, "HP 0 -> Downed (not dead)")
	await wait(Game.balance.downed_window + 0.3)
	check(Game.prog("reaver").level == 1 and Game.prog("reaver").augments.is_empty(), "True Death (permadeath) resets Reaver life")
	check(Game.prog("mage").level == 3, "Mage progression intact")
	check(Game.prog("reaver").life_number == 2, "life counter advances")
	Game.permadeath = false
	Game.gain_exp(300, "test")
	var lvl := Game.prog("reaver").level
	Game.player.downed = false
	Game.player.dead = true
	Game.on_hero_true_death(Game.player)
	check(Game.prog("reaver").level == lvl, "permadeath disabled keeps progression")
	Game.permadeath = true


func test_downed_revive() -> void:
	print("\n[Downed / Revive in Party Test]")
	var h := await setup("reaver", true)
	for o in Game.heroes:
		if o != h:
			o.get_node("Brain").set_physics_process(false)
	var ally: Hero = Game.heroes.filter(func(x): return x != h)[0]
	ally.global_position = h.global_position + Vector3(1.2, 0, 0)
	var info := DamageInfo.new()
	info.amount = 99999
	info.raw_amount = 99999
	info.source_pos = ally.global_position
	ally.take_damage(info)
	check(ally.downed, "ally downed")
	for i in int((Game.balance.revive_time + 0.3) * 60):
		h.try_revive(1.0 / 60.0)
		await get_tree().physics_frame
	check(not ally.downed and ally.hp > 0, "holding revive near ally revives them", "hp %.0f" % ally.hp)


func test_enemy_types() -> void:
	print("\n[Enemy types: FSM, telegraphs, attacks, special behaviour]")
	var h := await setup("vanguard")
	Game.invincible = true
	var types := ["wolf", "raider", "shield_guardian", "ash_caster"]
	var es := []
	for i in types.size():
		var e := Game.spawn_enemy(types[i], h.global_position + Vector3(-6 + i * 4, 0.2, -6), "outskirts")
		es.append(e)
	var states_seen := {}
	var hit_names := {}
	var rec := func(info): hit_names[info.attack_name] = true
	Events.damage_applied.connect(rec)
	for f in 60 * 12:
		await get_tree().physics_frame
		for e in es:
			if is_instance_valid(e):
				states_seen[e.enemy_type + ":" + e.sm.current_name] = true
				if e.telegraph != null:
					states_seen[e.enemy_type + ":telegraph"] = true
	for e in es:
		check(e.attack_serial > 0, "%s selects and executes attacks" % e.enemy_type, "attacks %d" % e.attack_serial)
	check(states_seen.has("wolf:chase") and states_seen.has("wolf:attack"), "FSM transitions chase -> attack")
	check(states_seen.has("raider:telegraph"), "melee attacks show ground telegraphs")
	Events.damage_applied.disconnect(rec)
	check(hit_names.has("Ash Bolt") or hit_names.has("Ash Burst"), "Ash Caster magic hits land (projectile / AoE)", str(hit_names.keys()))
	Game.invincible = false
	# frontal block
	var g: Enemy = es[2]
	g.sm.set_physics_process(false)
	g.runner.interrupt()
	g.face_dir(h.global_position - g.global_position)
	var info := DamageInfo.new()
	info.source = h
	info.amount = 100
	info.raw_amount = 100
	info.poise = 50
	info.source_pos = h.global_position
	g.take_damage(info)
	check(info.blocked_frontal and info.final_amount < 40.0, "Shield Guardian blocks frontal light hits", "%.0f dmg" % info.final_amount)
	var info2 := info.copy()
	info2.source_pos = g.global_position - g.forward() * 3.0
	info2.cancelled = false
	g.take_damage(info2)
	check(not info2.blocked_frontal, "flanking the Shield Guardian bypasses its shield")
	# stagger
	var w := dummy("wolf", h.global_position + Vector3(4, 0, 0), false)
	w.take_poise(999)
	await wait(0.05)
	check(w.sm.current_name == "stagger", "poise break -> stagger state")


func test_boss_phases() -> void:
	print("\n[Ashen Warden phases]")
	var h := await setup("vanguard")
	Game.invincible = true
	var b := Game.spawn_enemy("ashen_warden", h.global_position + Vector3(0, 0.3, -6), "keep") as AshenWarden
	await wait(1.0)
	var hit := func(frac: float):
		var info := DamageInfo.new()
		info.source = h
		info.amount = b.max_hp * frac
		info.raw_amount = info.amount
		info.source_pos = b.global_position + b.forward()
		b.stats.armor = 0
		b.take_damage(info)
	hit.call(0.45)
	check(b.phase == 2, "phase 2 at 60% HP")
	await wait(6.0)
	hit.call(0.4)
	check(b.phase == 3 and b.cooldown_mult < 1.0 and b.stats.attack_speed > 1.0, "phase 3 at 25% HP: faster, shorter openings")
	var found_p2 := false
	for a in b.attacks:
		if a.ai_min_phase >= 2:
			found_p2 = true
	check(found_p2 and b.find_attack("warden_execution") != null, "phase-gated moves (burning ground, lance, execution) exist")
	await wait(10.0)
	check(b.attack_serial > 2, "boss fights in phase 3", "attacks %d" % b.attack_serial)
	Game.invincible = false


func test_party_ai() -> void:
	print("\n[Party Test AI companions]")
	var h := await setup("reaver", true)
	Game.invincible = true
	for i in 3:
		var e := Game.spawn_enemy("raider", h.global_position + Vector3(-3 + i * 3, 0.2, -7), "outskirts")
		e.max_hp = 5000.0
		e.hp = 5000.0
	for o in Game.heroes:
		o.hp = o.max_hp * 0.6
	h.hp = h.max_hp * 0.5
	await wait(5.0)
	var tgt := {}
	for e in Game.enemies():
		if e.is_targetable() and e.target:
			tgt[e.target.class_id] = tgt.get(e.target.class_id, 0) + 1
	check(tgt.get("vanguard", 0) >= 1, "Vanguard AI draws threat (aura + guarding + threat multiplier)", str(tgt))
	await wait(10.0)
	check(log_has("Mage (AI) heals"), "Mage AI heals allies")
	check(log_has("Vanguard (AI) ->") or log_has("Vanguard (AI) guarded") or log_has("Vanguard (AI) PERFECT"), "Vanguard AI fights / guards")
	Game.invincible = false


func test_stage_exp_budget() -> void:
	print("\n[Stage EXP budget vs curve]")
	var h := await setup("reaver")
	var b := Game.balance
	var total := 0.0
	var per_area := {}
	for area in world.zones:
		var sum := 0.0
		for z in world.zones[area]:
			for wave in z.waves:
				for entry in wave:
					var x := float(b.enemy_exp[entry[0]])
					if entry.size() > 1 and entry[1]:
						x *= b.elite_exp_mult
					sum += x * float(b.area_exp_mult[area])
			sum += z.objective_exp
		sum += b.area_objective_exp
		per_area[area] = sum
		total += sum
	total += b.enemy_exp["ashen_warden"] * float(b.area_exp_mult["keep"])
	var need := 0
	for v in b.exp_curve:
		need += v
	print("    EXP per area: ", per_area, "  boss: ", b.enemy_exp["ashen_warden"] * b.area_exp_mult["keep"], "  total: ", total, "  needed for Lv10: ", need)
	check(total >= need * 0.95, "full clear of Ashen Valley reaches ~Level 10", "%d / %d" % [total, need])


func test_vanguard_approach() -> void:
	print("\n[Vanguard distance-aware attack movement]")
	var cases := [["in range", 1.5, "light", false], ["slightly out", 2.7, "light", true], ["far away", 6.5, "light", false], ["heavy, out of range", 3.3, "heavy", true]]
	for c in cases:
		var h := await setup("vanguard")
		var w := dummy("raider", h.global_position + Vector3(0, 0, -c[1]))
		face(h, w)
		var p0 := h.global_position
		tap(h, c[2])
		var d_atk: AttackData = h.runner.data
		await wait(d_atk.startup / h.attack_speed() + 0.02)
		var moved := Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
		var gap := Vector2(h.global_position.x - w.global_position.x, h.global_position.z - w.global_position.z).length()
		if c[3]:
			check(moved > 0.4 and gap >= 0.85 and gap <= 2.0, "%s (%.1fm): steps in to sword range" % [c[0], c[1]], "moved %.2f, now %.2f from target" % [moved, gap])
		else:
			check(moved < 0.12, "%s (%.1fm): no forward step" % [c[0], c[1]], "moved %.2f" % moved)
	# follow-up attacks once in range stay in place
	var h2 := await setup("vanguard")
	var w2 := dummy("raider", h2.global_position + Vector3(0, 0, -2.7))
	face(h2, w2)
	tap(h2, "light")
	await wait(0.6)
	w2.global_position = h2.global_position + h2.forward() * 1.5
	await wait(0.1)
	var p1 := h2.global_position
	tap(h2, "light")
	await wait(0.6)
	check(Vector2(h2.global_position.x - p1.x, h2.global_position.z - p1.z).length() < 0.12, "follow-up attack in range stays in place")
	# collision: wall between Vanguard and target stops the step
	var h3 := await setup("vanguard")
	var w3 := dummy("raider", h3.global_position + Vector3(0, 0, -2.9))
	face(h3, w3)
	var wall: StaticBody3D = world.box(h3.global_position + Vector3(0, 1, -1.0), Vector3(3, 2, 0.3), Color.GRAY, world, false)
	await wait(0.1)
	var z0 := h3.global_position.z
	tap(h3, "heavy")
	await wait(0.7)
	var wall_face := wall.global_position.z + 0.15
	check(h3.global_position.z < z0 - 0.05 and h3.global_position.z >= wall_face + 0.4, "approach step respects collisions (stopped by wall, never passes it)", "start z %.2f, end z %.2f, wall face z %.2f" % [z0, h3.global_position.z, wall_face])
	# Reaver is NOT given the behaviour
	var h4 := await setup("reaver")
	var w4 := dummy("raider", h4.global_position + Vector3(0, 0, -2.7))
	face(h4, w4)
	var p4 := h4.global_position
	tap(h4, "light")
	await wait(0.5)
	check(Vector2(h4.global_position.x - p4.x, h4.global_position.z - p4.z).length() < 0.12, "Reaver light attack has no auto-approach (Vanguard only)")


func test_telegraph_before_damage() -> void:
	print("\n[Enemy telegraphs precede damage; Ash Caster tempo]")
	var h := await setup("reaver")
	var times := {"hit": -1.0}
	var rec := func(info):
		if info.target == h and times.hit < 0.0:
			times.hit = Game.time
	Events.damage_applied.connect(rec)
	for type_atk in [["raider", "raider_heavy"], ["wolf", "wolf_lunge"], ["shield_guardian", "guardian_slam"]]:
		var e := dummy(type_atk[0], h.global_position + Vector3(0, 0, -2.0))
		e.target = h
		face(e, h)
		times.hit = -1.0
		var d: AttackData = e.find_attack(type_atk[1])
		var t0 := Game.time
		e.begin_attack(d)
		await wait(0.1)
		var shown: bool = e.alert.visible and e.telegraph != null and e.body_material.emission_enabled
		await wait(d.startup + d.active + 0.4)
		check(shown and times.hit > 0.0 and times.hit - t0 >= d.startup * 0.95, "%s: '!' + ground telegraph + glow shown, damage only after %.2fs startup" % [type_atk[1], d.startup], "hit at +%.2fs" % (times.hit - t0))
		e.queue_free()
		h.restore_all()
		await wait(0.8)
	# caster: cast is long and the bolt travels slowly
	var c := dummy("ash_caster", h.global_position + Vector3(0, 0, -10.0))
	c.target = h
	face(c, h)
	times.hit = -1.0
	var t1 := Game.time
	c.begin_attack(c.find_attack("caster_bolt"))
	await wait(0.2)
	check(c.charge_orb != null, "Ash Caster shows a growing charge orb while casting")
	await wait(3.0)
	check(times.hit > 0.0 and times.hit - t1 >= 1.8, "Ash Bolt: >= 1.8s from cast start to impact at 10m", "+%.2fs" % (times.hit - t1))
	Events.damage_applied.disconnect(rec)
	# free-running caster attack frequency
	c.queue_free()
	Game.invincible = true
	var c2 := Game.spawn_enemy("ash_caster", h.global_position + Vector3(0, 0.2, -11.0), "outskirts")
	await wait(15.0)
	check(c2.attack_serial <= 5, "Ash Caster casts at a readable rate", "%d casts in 15s" % c2.attack_serial)
	Game.invincible = false


func _action_event(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _wheel(up: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.factor = 1.0
	Input.parse_input_event(ev)
	var rel := InputEventMouseButton.new()
	rel.button_index = ev.button_index
	rel.pressed = false
	Input.parse_input_event(rel)


func _idx(es: Array, t) -> int:
	return es.find(t)


func test_lock_on_switching() -> void:
	print("\n[Lock-on: acquisition + screen-space switching (5 enemies in front)]")
	var h := await setup("vanguard")
	var brain = h.get_node("Brain")
	var lock: LockOnSystem = brain.lock
	var es := []
	for i in 5:
		es.append(dummy("raider", h.global_position + Vector3(-6.0 + i * 3.0, 0, -9.0)))
	await wait(0.3)
	_action_event("lock_on")
	await wait(0.05)
	check(h.lock_target == es[2], "Tab locks the enemy closest to screen centre", "locked #%d" % _idx(es, h.lock_target))
	var faces_before := h.rotation.y
	_wheel(true)
	await wait(0.05)
	check(h.lock_target == es[3], "Wheel Up -> next target to the right on screen", "#%d" % _idx(es, h.lock_target))
	await wait(0.35)
	_wheel(true)
	_wheel(true)
	await wait(0.05)
	check(h.lock_target == es[4], "one wheel burst switches once (cooldown prevents skipping)", "#%d" % _idx(es, h.lock_target))
	await wait(0.35)
	var fails := {"n": 0}
	lock.switch_failed.connect(func(_d): fails.n += 1)
	_wheel(true)
	await wait(0.05)
	check(h.lock_target == es[4] and fails.n == 1, "no target further right -> keeps current (no wrap / random pick)")
	await wait(0.35)
	_wheel(false)
	await wait(0.35)
	_wheel(false)
	await wait(0.05)
	check(h.lock_target == es[2], "Wheel Down x2 -> moves left across targets", "#%d" % _idx(es, h.lock_target))
	# keyboard alternatives
	await wait(0.35)
	_action_event("lock_switch_left")
	await wait(0.05)
	check(h.lock_target == es[1], "keyboard Z also switches left (InputMap action)")
	# walls exclude targets
	await wait(0.35)
	var wall: StaticBody3D = world.box(h.global_position + Vector3(-6, 2.5, -6.0), Vector3(5.0, 6, 0.4), Color.GRAY, world, false)
	await wait(0.1)
	var ok_wall: bool = not lock.is_eligible(es[0], lock.acquire_range)
	_wheel(false)
	await wait(0.05)
	check(ok_wall and h.lock_target == es[1], "enemy behind a wall is never selected")
	wall.queue_free()
	# switching never triggers weapon actions / unwanted rotation
	check(not h.runner.is_busy(), "target switching does not trigger attacks")
	# death -> automatic retarget to a valid enemy
	var dead_one = h.lock_target
	var info := DamageInfo.new()
	info.source = h
	info.amount = 999999.0
	info.raw_amount = 999999.0
	dead_one.take_damage(info)
	await wait(0.1)
	check(h.lock_target != null and h.lock_target != dead_one and h.lock_target.is_targetable(), "target death -> lock moves to another valid enemy")
	# out of range -> invalid
	var cur = h.lock_target
	cur.global_position += Vector3(0, 0, -40)
	cur.reset_physics_interpolation()
	await wait(0.1)
	check(h.lock_target != cur, "target leaving lock range releases / retargets")
	# unlocked: wheel does nothing
	_action_event("lock_on")
	await wait(0.05)
	var was = h.lock_target
	_wheel(true)
	await wait(0.05)
	check(was == null and h.lock_target == null and not h.runner.is_busy(), "wheel without lock-on does nothing (no target, no attack)")


func test_lock_camera_transitions() -> void:
	print("\n[Lock-on camera: smooth entry, bounded rotation, switch, exit keeps direction]")
	var h := await setup("reaver")
	var brain = h.get_node("Brain")
	var lock: LockOnSystem = brain.lock
	var rig: CameraRig = brain.rig
	var a := dummy("raider", h.global_position + Vector3(-5.0, 0, -7.0))
	var b := dummy("raider", h.global_position + Vector3(0.5, 0, -9.0))
	await wait(0.3)
	var y0 := rig.yaw
	lock._set_target(a, false)   # lock the side enemy (35 deg off-centre) to test the reframe
	var max_step := 0.0
	var max_face := 0.0
	var prev := rig.yaw
	var prev_face := h.rotation.y
	for i in 90:
		await get_tree().physics_frame
		max_step = maxf(max_step, absf(wrapf(rig.yaw - prev, -PI, PI)))
		max_face = maxf(max_face, absf(wrapf(h.rotation.y - prev_face, -PI, PI)))
		prev = rig.yaw
		prev_face = h.rotation.y
	var to: Vector3 = h.lock_target.global_position - h.global_position
	var want := atan2(-to.x, -to.z)
	var limit := rig.lock_max_turn_speed / 60.0 + 0.002
	check(absf(wrapf(rig.yaw - want, -PI, PI)) < 0.08, "free -> lock reframes onto the target", "yaw err %.3f rad" % absf(wrapf(rig.yaw - want, -PI, PI)))
	check(max_step <= limit and absf(wrapf(rig.yaw - y0, -PI, PI)) > 0.3, "no camera snap on lock (max %.3f rad/frame, cap %.3f)" % [max_step, limit])
	check(max_face <= Hero.FACE_TURN_SPEED / 60.0 + 0.01, "character turns smoothly to the target (max %.3f rad/frame)" % max_face)
	# switch to the other side
	lock.switch(1)
	max_step = 0.0
	prev = rig.yaw
	for i in 90:
		await get_tree().physics_frame
		max_step = maxf(max_step, absf(wrapf(rig.yaw - prev, -PI, PI)))
		prev = rig.yaw
	check(h.lock_target == b and max_step <= limit and max_step > 0.001, "target switch reframes smoothly (no snap)", "max %.3f rad/frame" % max_step)
	# strafe/circle around the locked target: movement stays at full speed and the camera stays bounded
	var circ_ok := true
	var spd_sum := 0.0
	prev = rig.yaw
	for i in 120:
		var tgt: Vector3 = h.lock_target.global_position - h.global_position
		tgt.y = 0
		h.move_input = tgt.normalized().cross(Vector3.UP)
		await get_tree().physics_frame
		spd_sum += Vector2(h.velocity.x, h.velocity.z).length()
		if absf(wrapf(rig.yaw - prev, -PI, PI)) > limit:
			circ_ok = false
		prev = rig.yaw
	h.move_input = Vector3.ZERO
	check(circ_ok and spd_sum / 120.0 > Game.balance.move_speed * 0.85, "circling a locked target: full move speed, smooth camera", "avg speed %.2f" % (spd_sum / 120.0))
	# lock -> free keeps the current direction
	await wait(0.2)
	var before := rig.yaw
	lock.release()
	await wait(0.3)
	check(absf(wrapf(rig.yaw - before, -PI, PI)) < 0.02, "lock -> free preserves camera direction (no reset behind the hero)")
	# dodge works in every direction while locked
	lock.acquire()
	await wait(0.3)
	var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var all_ok := true
	for d in dirs:
		h.restore_all()
		var p0 := h.global_position
		h.move_input = d
		tap(h, "dodge")
		await wait(0.45)
		h.move_input = Vector3.ZERO
		var moved: Vector3 = h.global_position - p0
		if moved.normalized().dot(d) < 0.8:
			all_ok = false
		await wait(0.3)
	check(all_ok, "dodge travels in all four directions while locked")
