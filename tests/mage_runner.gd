extends "res://tests/test_runner.gd"
## MAGE - THE WORLDWEAVER: automated mechanical checks, organised by the spec's milestones A-F.
##   godot --headless --fixed-fps 60 res://tests/mage_runner.tscn
## These verify FUNCTIONALITY only. They do not show that the Mage is fun - that needs human playtesting.

var released: Array = []
var interrupted: Array = []
var triggered: Array = []
var inter: Array = []
var dmg: Array = []


func _run_all() -> void:
	Events.spell_released.connect(func(c, id, el, full, t, m): released.append({"id": id, "full": full, "t": t, "mana": m, "c": c}))
	Events.spell_interrupted.connect(func(c, id, reason): interrupted.append({"id": id, "reason": reason}))
	Events.augment_triggered.connect(func(c, id, d): triggered.append(id))
	Events.elemental_interaction.connect(func(c, id, d): inter.append(id))
	Events.damage_applied.connect(func(info): dmg.append({"name": String(info.attack_name), "target": info.target, "amount": info.final_amount}))
	await test_a_charged_casting()
	await test_a_life()
	await test_b_fire()
	await test_b_frost_formations()
	await test_b_formation_limits_and_cleanup()
	await test_b_enemy_pathing()
	await test_b_stone()
	await test_b_storm()
	await test_b_advanced_spells()
	await test_c_thermal_fracture()
	await test_c_shattered_winter()
	await test_c_conductive_anchors()
	await test_c_living_bastion()
	await test_d_sanctum()
	await test_e_progression()
	await test_e_augments()
	await test_e_stats()
	await test_f_ai_and_save()
	await test_g_delayed_effects_world_clock()
	await teardown()


# ------------------------------------------------------------------ helpers
func mage(level: int = 1, party: bool = false) -> Hero:
	var h := await setup("mage", party, false, false)
	Game.set_level("mage", level)
	for o in Game.heroes:
		if o != h:
			o.get_node("Brain").set_physics_process(false)
	await wait(0.6)      # discoveries / auto-equip run on a short timer
	h.restore_all()
	h.stats.crit_chance = 0.0
	released.clear()
	interrupted.clear()
	triggered.clear()
	inter.clear()
	return h


func grant(h: Hero, ids: Array) -> void:
	for id in ids:
		Game.prog("mage").debug_unlocks.append("spell:" + id)
	await wait(0.6)


func hold(h: Hero, action: String, sec: float) -> void:
	h.press(action)
	await wait(sec)
	h.release(action)


func enemy_at(type: String, pos: Vector3, hp: float = 99999.0) -> Enemy:
	var e := dummy(type, pos)
	e.max_hp = hp
	e.hp = hp
	return e


func el(h: Hero) -> MageElementalist:
	return h.kit.el


func refill(h: Hero) -> void:
	h.kit.mana = Game.balance.mana_max
	h.kit.cooldowns.clear()


func width_of(f: WorldFormation) -> float:
	var w := 0.0
	for s in f.segments:
		if s.alive:
			w += s.w
	return w


func lock(h: Hero, e) -> void:
	face(h, e)
	h.lock_target = e


# ================================================================== AUDIT regression
## A telegraphed delayed impact must land when its world telegraph says, even if the caster is downed
## (or in hitstop) meanwhile. Before the fix the damage was queued on the caster's kit clock, which stops
## while downed: the circle vanished on time and the impact fired only after the revive.
func test_g_delayed_effects_world_clock() -> void:
	print("\n[AUDIT] Delayed Mage impacts follow the world clock")
	var h := await mage(10)
	var e := el(h)
	Game.invincible = false
	await grant(h, ["cinderfall"])
	e.equip_spell(0, "cinderfall")
	var t := enemy_at("raider", h.global_position + Vector3(0, 0, -10))
	lock(h, t)
	refill(h)
	await wait(0.6)
	var n_rel := released.size()
	tap(h, "light")
	await wait(0.5)          # released at the 0.25s minimum; the 1.2s warning is now on the ground
	check(released.size() > n_rel and t.hp == 99999.0, "Cinderfall released, warning shown, impact pending")
	var kill := DamageInfo.new()
	kill.amount = h.hp + 9999.0
	kill.raw_amount = kill.amount
	kill.source = t
	kill.source_pos = t.global_position
	h.take_damage(kill)
	check(h.downed, "caster downed during the warning")
	await wait(1.1)
	check(t.hp < 99999.0, "the impact lands on time although the caster is downed", "target HP %.0f" % t.hp)
	var cf := func() -> int: return dmg.filter(func(d): return String(d.name).begins_with("Cinderfall")).size()
	var cf_before: int = cf.call()
	h.revive(null)
	t.queue_free()
	await wait(1.5)
	check(cf.call() == cf_before, "no late 'ghost' Cinderfall impact after the revive", "%d extra" % (cf.call() - cf_before))
	# Mountainfall: same pending-impact path, interrupted by the caster's own hitstop many times
	Game.add_augment("mage", "mountainfall")
	e.equip_spell(0, "earthbreaker")
	var m := enemy_at("raider", h.global_position + Vector3(0, 0, -8))
	lock(h, m)
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.85)
	var fire_at := Game.time + 1.0
	var mf := func() -> bool: return dmg.any(func(d): return d.target == m and String(d.name) == "Mountainfall")
	for i in 30:
		h.hitstop = 0.1           # caster keeps getting hit
		await wait(0.05)
		if mf.call():
			break
	h.hitstop = 0.0
	var late := Game.time - fire_at
	check(mf.call() and late >= -0.1 and late <= 0.25, "Mountainfall lands ~1s after release despite caster hitstop", "landed %s, %.2fs after the expected time" % [mf.call(), late])
	m.queue_free()
	Game.remove_augment("mage", "mountainfall")


# ================================================================== MILESTONE A
func test_a_charged_casting() -> void:
	print("\n[A] Charged casting framework (Level 1: Fire + Life)")
	var h := await mage(1)
	var e := el(h)
	check(h.kit.elementalist(), "Worldweaver is the default Mage core")
	check(Game.prog().known_elements() == ["fire", "life"], "Level 1 knows Fire + Life only", str(Game.prog().known_elements()))
	check(e.slot_spell(0) == "flame_cataclysm" and e.slot_spell(1) == "life_bloom" and e.slot_spell(2) == "" and e.utility_spell() == "", "Level 1 loadout: Flame Cataclysm / Life Bloom (+ Lifeline on F)")
	check(not h.unlocked("m_sanctum") and not e.spell_known("protective_renewal") and not e.spell_known("crystal_formation"), "no Sanctum / Renewal / Frost at Level 1")
	var fc: ChargedSpellData = e.spells.flame_cataclysm
	var eb: ChargedSpellData = e.spells.earthbreaker
	check(is_equal_approx(fc.min_charge, 0.25) and is_equal_approx(fc.full_charge, 1.2) and is_equal_approx(fc.move_mult, 0.65), "standard spell: min 0.25s, full 1.20s, 65% movement")
	check(is_equal_approx(eb.full_charge, 1.8) and is_equal_approx(eb.move_mult, 0.45), "major (heavy) spell: full 1.80s, 45% movement")
	check(is_equal_approx(e.spells.lifeline.cooldown, 12.0), "Lifeline cooldown 12s")
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -9))
	lock(h, w)
	for i in 12:
		tap(h, "light")
		await wait(0.1)
	await wait(0.4)
	var n := released.filter(func(r): return r.id == "flame_cataclysm").size()
	check(n <= 3, "no rapid Light Attack combo (each cast waits for minimum release + recovery)", "%d casts in 1.2s" % n)
	await wait(1.0)
	refill(h)
	released.clear()
	tap(h, "light")
	await wait(0.5)
	check(released.size() == 1 and not released[0].full and released[0].t >= 0.24, "tap = PARTIAL release after the 0.25s minimum", str(released))
	await wait(0.6)
	released.clear()
	h.press("light")
	await wait(0.5)
	check(e.cur != null and e.ratio() > 0.3 and e.ratio() < 1.0, "charge builds while held", "%.2f" % e.ratio())
	check(is_equal_approx(h.kit.move_mult(), 0.65), "movement while charging = 65%", "x%.2f" % h.kit.move_mult())
	check(e.fx != null and is_instance_valid(e.fx), "visible charge energy (ChargeFX) while charging")
	await wait(0.8)
	check(e.is_full(), "full charge reached at 1.2s")
	h.release("light")
	await wait(0.1)
	check(released.size() == 1 and released[0].full, "release at full charge = FULL version")
	check(h.runner.is_busy(), "cast recovery after release (animation state, no lockup)")
	await wait(1.2)
	check(not h.runner.is_busy() and e.cur == null, "recovery ends cleanly")
	# holding beyond full does not add power
	refill(h)
	dmg.clear()
	await hold(h, "light", 1.3)
	await wait(1.0)
	var d1: float = dmg.filter(func(x): return x.name == "Flame Cataclysm (full)" and x.target == w).reduce(func(acc, x): return acc + x.amount, 0.0)
	for z in e.fire_zones:
		z.queue_free()
	await wait(0.2)
	refill(h)
	dmg.clear()
	await hold(h, "light", 2.6)
	await wait(1.0)
	var d2: float = dmg.filter(func(x): return x.name == "Flame Cataclysm (full)" and x.target == w).reduce(func(acc, x): return acc + x.amount, 0.0)
	check(absf(d1 - d2) < 0.5, "holding beyond full charge adds nothing (no perfect-charge bonus)", "%.1f vs %.1f" % [d1, d2])
	for z in e.fire_zones:
		z.queue_free()
	# dodge cancels, no mana
	refill(h)
	await wait(0.6)
	var m0: float = h.kit.mana
	interrupted.clear()
	released.clear()
	h.press("light")
	await wait(0.5)
	h.press("dodge")
	h.release("dodge")
	await wait(0.05)
	h.release("light")
	check(e.cur == null and interrupted.size() >= 1 and interrupted[-1].reason == "dodge" and h.dodging, "Dodge cancels the charge immediately")
	check(released.is_empty(), "the cancelled spell does not release")
	check(h.kit.mana >= m0 - 0.1, "no mana is spent on a cancelled charge")
	await wait(0.8)
	check(not h.runner.is_busy() and not h.dodging, "no animation lockup after a dodge-cancel")
	check(e.preserved.is_empty(), "no charge preservation before Level 10")


func test_a_life() -> void:
	print("\n[A] Life magic without enemies")
	var h := await mage(1, true)
	var e := el(h)
	check(get_tree().get_nodes_in_group("enemies").is_empty(), "no enemies present")
	h.hp = h.max_hp * 0.3
	var hp0 := h.hp
	tap(h, "heavy")
	await wait(0.6)
	var part_heal := h.hp - hp0
	check(part_heal > 0.0, "Life Bloom self-heals with no enemy around (partial)", "+%.0f" % part_heal)
	await wait(0.6)
	refill(h)
	h.hp = h.max_hp * 0.2
	hp0 = h.hp
	await hold(h, "heavy", 1.3)
	await wait(0.2)
	var full_heal := h.hp - hp0
	var bl: ChargedSpellData = e.spells.life_bloom
	check(full_heal > part_heal * 1.5, "full Life Bloom heals more", "%.0f vs %.0f" % [full_heal, part_heal])
	check(full_heal / bl.mana_full > part_heal / bl.mana_partial, "full Life Bloom is more mana-efficient")
	var ally: Hero = null
	for o in Game.heroes:
		if o != h:
			ally = o
	ally.hp = ally.max_hp * 0.4
	e.set_heal_target(ally)
	var a0 := ally.hp
	refill(h)
	await wait(0.6)
	tap(h, "heavy")
	await wait(0.6)
	check(ally.hp > a0, "explicitly selected ally is healed")
	# out of range: never silently redirected
	ally.global_position = h.global_position + Vector3(0, 0, -40)
	h.hp = h.max_hp * 0.5
	var self0 := h.hp
	released.clear()
	refill(h)
	await wait(0.6)
	tap(h, "heavy")
	await wait(0.6)
	check(released.is_empty() and is_equal_approx(h.hp, self0), "out-of-range explicit target: cast refused, NOT redirected to someone else")
	e.set_heal_target(null)
	# Lifeline
	h.hp = h.max_hp * 0.25
	hp0 = h.hp
	refill(h)
	await wait(0.6)
	tap(h, "life")
	await wait(0.1)
	check(h.hp > hp0 and h.kit.cd("lifeline") > 11.0, "Lifeline: instant heal, 12s cooldown", "cd %.1f" % h.kit.cd("lifeline"))
	check(h.hp - hp0 < full_heal, "Lifeline heals less than a full Life Bloom (Bloom stays relevant)")
	var hp1 := h.hp
	await wait(0.5)
	tap(h, "life")
	await wait(0.1)
	check(is_equal_approx(h.hp, hp1), "Lifeline cannot be recast during its cooldown")


# ================================================================== MILESTONE B
func test_b_fire() -> void:
	print("\n[B] Fire: Flame Cataclysm")
	var h := await mage(1)
	var e := el(h)
	var a := enemy_at("raider", h.global_position + Vector3(0, 0, -8))
	var b := enemy_at("raider", h.global_position + Vector3(1.3, 0, -8.6))
	lock(h, a)
	tap(h, "light")
	await wait(0.9)
	var part_a := 99999.0 - a.hp
	check(part_a > 0.0 and e.fire_zones.is_empty(), "partial: compact projectile + small explosion, NO burning area", "%.0f" % part_a)
	refill(h)
	a.hp = 99999.0
	b.hp = 99999.0
	await wait(0.6)
	await hold(h, "light", 1.25)
	await wait(0.7)
	var full_a := 99999.0 - a.hp
	check(full_a > part_a * 1.3 and b.hp < 99999.0, "full: bigger explosion reaches the grouped enemy", "%.0f vs %.0f" % [full_a, part_a])
	check(e.fire_zones.size() == 1, "full: one burning area")
	var z = e.fire_zones[0]
	check(is_equal_approx(z.radius, 2.5) and is_equal_approx(z.duration, 5.0) and is_equal_approx(z.tick, 1.0), "burning area: 2.5m, 5s, 1s interval", "r %.1f d %.1f i %.1f" % [z.radius, z.duration, z.tick])
	dmg.clear()
	await wait(3.05)
	var ticks := dmg.filter(func(x): return x.name == "Burning Area" and x.target == a).size()
	check(ticks >= 2 and ticks <= 4, "area damages an enemy about once per second (no duplicate collision ticks)", "%d ticks in 3s" % ticks)
	check(ElementalStates.has(a, "burning"), "enemy inside is in the Burning state")
	for i in 2:
		refill(h)
		await wait(0.7)
		await hold(h, "light", 1.25)
		await wait(0.8)
	check(e.fire_zones.size() == 2, "max 2 persistent Fire areas (oldest removed)", "%d" % e.fire_zones.size())
	await wait(5.5)
	check(e.fire_zones.is_empty(), "burning areas expire")


func test_b_frost_formations() -> void:
	print("\n[B] Frost: Crystal Formation (world formation)")
	var h := await mage(2)
	var e := el(h)
	check(not e.knows_element("frost"), "Frost locked before Level 3")
	Game.set_level("mage", 3)
	await wait(0.7)
	check(e.knows_element("frost") and e.slot_spell(2) == "crystal_formation", "Level 3: Frost + Crystal Formation (auto-equipped on 1)")
	var w := enemy_at("wolf", h.global_position + Vector3(0, 0, -10))
	lock(h, w)
	h.press("skill1")
	await wait(0.3)
	check(e.preview != null and e.preview.visible and e.preview_box.visible, "placement preview shown while charging a formation spell")
	var pw: float = (e.preview_box.mesh as BoxMesh).size.x
	await wait(1.1)
	var fw: float = (e.preview_box.mesh as BoxMesh).size.x
	check(is_equal_approx(pw, 1.5) and is_equal_approx(fw, 4.0), "preview shows partial (1.5m) then full (4m) width", "%.1f -> %.1f" % [pw, fw])
	h.release("skill1")
	await wait(0.2)
	check(not e.preview.visible, "preview hidden after release")
	check(e.formations.size() == 1, "full release creates one formation")
	var f: WorldFormation = e.formations[0]
	check(absf(width_of(f) - 4.0) < 0.05 and f.alive_count() >= 4, "full formation: 4m connected ice", "%.2fm, %d sections" % [width_of(f), f.alive_count()])
	check(f.mage == h and f.element == "frost" and f.has_state("frozen_structure"), "formation has owner, element and Frozen Structure state")
	check(f.collision_layer == Combatant.LAYER_FROST and h.collision_mask & Combatant.LAYER_FROST == 0, "ice collides with enemies only (allies are never trapped)")
	var to_w: Vector3 = w.global_position - h.global_position
	to_w.y = 0
	var ax: Vector3 = f.global_transform.basis.x.normalized()
	check(absf(ax.dot(to_w.normalized())) < 0.1, "orientation follows the aim (wall across the line to the target)")
	check(ElementalStates.has(w, "chill") or w.global_position.distance_to(f.global_position) > 3.6, "full release Chills enemies within range")
	check(is_equal_approx(f.duration, 7.0), "formation lifetime 7s")
	# re-aim to the side: orientation changes
	var w2 := enemy_at("raider", h.global_position + Vector3(-9, 0, 0))
	lock(h, w2)
	refill(h)
	await wait(0.6)
	tap(h, "skill1")
	await wait(0.6)
	var f2: WorldFormation = e.formations[-1]
	check(absf(width_of(f2) - 1.5) < 0.05, "partial release: one small 1.5m obstruction", "%.2fm" % width_of(f2))
	var ax2: Vector3 = f2.global_transform.basis.x.normalized()
	check(absf(ax2.dot(ax)) < 0.2, "aiming elsewhere rotates the formation")
	# expiry
	await wait(6.8)
	check(not is_instance_valid(f) or f.gone, "formation expires after its lifetime (no permanent blocking)")
	# durability: enemy projectile damages the ice
	refill(h)
	lock(h, w)
	await wait(0.6)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	var f3: WorldFormation = e.formations[-1]
	var hp_before := 0.0
	for s in f3.segments:
		hp_before += s.hp
	var c := enemy_at("ash_caster", f3.global_position + Vector3(0, 0, -6))
	var from: Vector3 = c.global_position + Vector3(0, 1.0, 0)
	Projectile.spawn(c, from, (f3.global_position + Vector3(0, 1.0, 0)) - from, 16.0, 0.3, Color.ORANGE, func(_t, _p): pass, 2.0, 40.0)
	await wait(0.8)
	var hp_after := 0.0
	for s in f3.segments:
		hp_after += s.hp
	check(hp_after < hp_before, "enemy projectiles are stopped by the ice and damage it (durability)", "%.0f -> %.0f" % [hp_before, hp_after])
	# boss breaks it (no permanent boss control)
	var boss := dummy("ashen_warden", f3.global_position + Vector3(0, 0, -1.4))
	face(boss, f3)
	await wait(0.4)
	check(not is_instance_valid(f3) or f3.gone, "the boss breaks a formation on contact")
	boss.queue_free()
	c.queue_free()


func test_b_formation_limits_and_cleanup() -> void:
	print("\n[B] Formation limit (2 solid) + full cleanup")
	var h := await mage(3)
	var e := el(h)
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -12))
	lock(h, w)
	var made: Array = []
	for i in 3:
		refill(h)
		await wait(0.6)
		h.lock_target = null
		h.face_dir(Vector3(cos(i * 1.8), 0, sin(i * 1.8)))
		await hold(h, "skill1", 1.3)
		await wait(0.05)
		made.append(e.formations[-1])
	check(e.solid_count() == 2, "a 3rd solid formation keeps only 2 per Mage", "%d" % e.solid_count())
	var old: WorldFormation = made[0]
	check(old.gone and old.collision_layer == 0 and not old.is_in_group(WorldFormation.GROUP) and old.states.is_empty(), "the OLDEST was removed: collision off, group (steering / relay / LOS) references and states cleared")
	check(not e.formations.has(old), "the Mage no longer references it")
	await wait(0.5)
	check(not is_instance_valid(old), "removed formation node, collision shapes and VFX freed")
	e.clear_world()
	await wait(0.4)
	check(WorldFormation.active().is_empty() and e.fire_zones.is_empty(), "clear_world() removes every formation / area")


func test_b_enemy_pathing() -> void:
	print("\n[B] Enemy pathfinding around temporary formations")
	var h := await mage(3)
	var e := el(h)
	var w := dummy("wolf", h.global_position + Vector3(0, 0, -12), false)
	w.max_hp = 99999
	w.hp = 99999
	w.sm.set_physics_process(false)
	lock(h, w)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	var f: WorldFormation = e.formations[-1]
	var inside := false
	w.target = h
	w.sm.set_physics_process(true)
	var reached := false
	for i in 300:
		await get_tree().physics_frame
		if f.contains_xz(w.global_position, -0.1):
			inside = true
		if w.global_position.distance_to(h.global_position) < 3.0:
			reached = true
			break
	check(not inside, "the wolf never passes through the ice")
	check(reached, "the wolf finds a way AROUND the formation (no permanent blocking)", "dist %.1f" % w.global_position.distance_to(h.global_position))


func test_b_stone() -> void:
	print("\n[B] Stone: Earthbreaker (Level 7)")
	var h := await mage(6)
	var e := el(h)
	check(not e.knows_element("stone"), "Stone locked before Level 7")
	Game.set_level("mage", 7)
	await wait(0.7)
	check(e.knows_element("stone") and e.known_charged().has("earthbreaker") and e.spell_known("protective_renewal"), "Level 7: Stone + Earthbreaker + Protective Renewal")
	check(not e.knows_element("storm"), "Level 7 does not grant Storm")
	e.equip_spell(0, "earthbreaker")
	var g := enemy_at("shield_guardian", h.global_position + Vector3(0, 0, -6))
	face(g, h)
	lock(h, g)
	await wait(0.3)
	var p0: float = g.poise
	tap(h, "light")
	await wait(0.7)
	var part_poise := p0 - g.poise
	check(part_poise >= 30.0 or g.is_staggered(), "partial: Magic damage + moderate Poise damage (through a frontal guard)", "%.0f" % part_poise)
	var last := CombatLog.lines.filter(func(l): return String(l.text).contains("Earthbreaker"))
	check(not last.is_empty() and String(last[-1].text).contains("MAG"), "rocks stay MAGIC damage")
	g.queue_free()
	# weight-based displacement
	var res: Dictionary = {}
	for t in ["wolf", "raider", "shield_guardian", "ashen_warden"]:
		var x := enemy_at(t, h.global_position + Vector3(0, 0, -6))
		lock(h, x)
		refill(h)
		await wait(0.6)
		var p_before: Vector3 = x.global_position
		await hold(h, "light", 1.85)
		await wait(0.5)
		res[t] = Vector2(x.global_position.x - p_before.x, x.global_position.z - p_before.z).length()
		x.queue_free()
		await wait(0.1)
	check(res.wolf > res.raider + 0.2, "light enemy (Wolf) displaced more than medium (Raider)", str(res))
	check(res.raider > 0.1, "medium enemy receives limited displacement")
	check(res.shield_guardian < 0.15 and res.ashen_warden < 0.15, "heavy enemy and boss resist displacement")


func test_b_storm() -> void:
	print("\n[B] Storm: Thunder Conduit (Level 9)")
	var h := await mage(8)
	var e := el(h)
	check(not e.knows_element("storm"), "Storm locked before Level 9")
	Game.set_level("mage", 9)
	await wait(0.7)
	check(e.knows_element("storm") and e.known_charged().has("thunder_conduit"), "Level 9: Storm + Thunder Conduit")
	e.equip_spell(0, "thunder_conduit")
	var es: Array = []
	for i in 4:
		es.append(enemy_at("raider", h.global_position + Vector3(-4.5 + i * 3.0, 0, -10)))
	lock(h, es[1])
	tap(h, "light")
	await wait(0.5)
	check(es.filter(func(x): return x.hp < 99999.0).size() == 1, "partial: one target")
	for x in es:
		x.hp = 99999.0
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.3)
	await wait(0.3)
	var hit := es.filter(func(x): return x.hp < 99999.0).size()
	check(hit == 3, "full: max 3 total targets", "%d hit" % hit)
	check(int(e.last_release.get("targets", 0)) == 3, "no repeated hits in one chain")
	for x in es:
		x.queue_free()
	var a := enemy_at("raider", h.global_position + Vector3(0, 0, -10))
	var far := enemy_at("raider", h.global_position + Vector3(7.0, 0, -10))
	lock(h, a)
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.3)
	await wait(0.3)
	check(far.hp == 99999.0, "no jump beyond 6m")
	a.queue_free()
	far.queue_free()
	var c := enemy_at("ash_caster", h.global_position + Vector3(0, 0, -12))
	lock(h, c)
	c.target = h
	c.begin_attack(c.find_attack("caster_bolt"))
	refill(h)
	await wait(0.1)
	triggered.clear()
	await hold(h, "light", 1.25)
	await wait(0.05)
	check(not triggered.has("verdict_interrupt") and not e.last_release.has("interrupted"), "Thunder Conduit has no interrupt effect (that is Lightning Verdict's job; Poise rules still apply)")


func test_b_advanced_spells() -> void:
	print("\n[B] Advanced spells (Debug grant: no level in the approved table)")
	var h := await mage(10)
	var e := el(h)
	check(not e.spell_known("inferno_wave") and not e.spell_known("frozen_bastion") and not e.spell_known("lightning_verdict"), "advanced spells are NOT learned by level")
	await grant(h, ["inferno_wave", "cinderfall", "glacial_spear", "frozen_bastion", "rising_pillar", "stone_ward", "lightning_verdict", "storm_arc", "verdant_renewal"])
	check(e.known_charged().size() == 11 and e.known_utility().size() == 4, "Debug grant makes them available", "%d / %d" % [e.known_charged().size(), e.known_utility().size()])
	# Inferno Wave
	e.equip_spell(0, "inferno_wave")
	var es: Array = []
	for i in 3:
		es.append(enemy_at("raider", h.global_position + Vector3(0, 0, -3.0 - i * 3.0)))
	var off := enemy_at("raider", h.global_position + Vector3(6, 0, -6))
	lock(h, es[2])
	CombatLog.clear()
	await hold(h, "light", 1.25)
	await wait(1.4)
	var hits := CombatLog.lines.filter(func(l): return String(l.text).contains("Inferno Wave")).size()
	check(es.all(func(x): return x.hp < 99999.0) and off.hp == 99999.0, "Inferno Wave: forward wave hits enemies on its path only")
	check(hits == 3, "each enemy hit once per wave", "%d hits" % hits)
	for x in es + [off]:
		x.queue_free()
	# Cinderfall
	e.equip_spell(0, "cinderfall")
	var t := enemy_at("raider", h.global_position + Vector3(0, 0, -10))
	lock(h, t)
	refill(h)
	await wait(0.6)
	tap(h, "light")
	await wait(0.4)
	check(t.hp == 99999.0 and true, "Cinderfall: visible warning, impact is delayed")
	await wait(1.2)
	check(t.hp < 99999.0, "Cinderfall impact lands after the warning")
	t.queue_free()
	# Glacial Spear
	e.equip_spell(0, "glacial_spear")
	var s := enemy_at("raider", h.global_position + Vector3(0, 0, -10))
	lock(h, s)
	refill(h)
	await wait(0.6)
	tap(h, "light")
	await wait(0.7)
	check(s.hp < 99999.0 and ElementalStates.has(s, "chill"), "Glacial Spear: single-target damage + Chill")
	s.queue_free()
	# Lightning Verdict
	e.equip_spell(0, "lightning_verdict")
	var c := enemy_at("ash_caster", h.global_position + Vector3(0, 0, -12))
	lock(h, c)
	c.target = h
	refill(h)
	await wait(0.6)
	c.begin_attack(c.find_attack("caster_burst"))
	triggered.clear()
	h.press("light")
	await wait(0.3)
	h.release("light")
	await wait(0.1)
	check(triggered.has("verdict_interrupt") and not c.runner.is_busy(), "Lightning Verdict cancels an eligible (interruptible) preparation")
	c.queue_free()
	var r := enemy_at("raider", h.global_position + Vector3(0, 0, -6))
	lock(h, r)
	r.target = h
	refill(h)
	await wait(0.6)
	r.begin_attack(r.attacks[0])
	triggered.clear()
	h.press("light")
	await wait(0.27)
	h.release("light")
	await wait(0.05)
	check(not triggered.has("verdict_interrupt"), "attacks that do not expose an interruptible window are not interrupted")
	r.queue_free()
	var boss := enemy_at("ashen_warden", h.global_position + Vector3(0, 0, -8))
	lock(h, boss)
	boss.target = h
	refill(h)
	await wait(0.6)
	boss.begin_attack(boss.find_attack("warden_ember_lance"))
	triggered.clear()
	h.press("light")
	await wait(0.27)
	h.release("light")
	await wait(0.05)
	check(not triggered.has("verdict_interrupt") and boss.runner.is_busy(), "the boss resists Lightning Verdict")
	boss.queue_free()
	# Storm Arc
	e.equip_spell(0, "storm_arc")
	var on_route := enemy_at("raider", h.global_position + Vector3(0, 0, -6))
	var off_route := enemy_at("raider", h.global_position + Vector3(5, 0, -6))
	lock(h, on_route)
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.25)
	await wait(0.2)
	check(on_route.hp < 99999.0 and off_route.hp == 99999.0, "Storm Arc follows the aimed route")
	on_route.queue_free()
	off_route.queue_free()
	# Utilities
	e.equip_spell(3, "frozen_bastion")
	var w := enemy_at("wolf", h.global_position + Vector3(0, 0, -9))
	lock(h, w)
	refill(h)
	await wait(0.6)
	check(e.cast_utility("frozen_bastion"), "Frozen Bastion casts instantly")
	var fb: WorldFormation = e.formations[-1]
	check(fb.kind == "bastion" and fb.element == "frost" and h.kit.cd("frozen_bastion") > 0.0 and is_equal_approx(fb.duration, 4.0), "short-lived ice wall with a cooldown")
	check(not e.cast_utility("frozen_bastion"), "Frozen Bastion respects its cooldown")
	refill(h)
	e.equip_spell(3, "rising_pillar")
	var lw := enemy_at("wolf", h.global_position + Vector3(2, 0, -7))
	lock(h, lw)
	var lp := lw.global_position
	await wait(0.6)
	e.cast_utility("rising_pillar")
	await wait(0.4)
	var pl: WorldFormation = e.formations[-1]
	check(pl.kind == "pillar" and pl.has_state("fortified"), "Rising Pillar: stone pillar (Fortified)")
	check(Vector2(lw.global_position.x - lp.x, lw.global_position.z - lp.z).length() > 0.3, "limited displacement of the enemy at the spot")
	pl.damage_segment(0, 1.0e6, "test")
	check(pl.gone, "the pillar can be destroyed")
	refill(h)
	e.equip_spell(3, "stone_ward")
	e.cast_utility("stone_ward")
	var wd: WorldFormation = e.formations[-1]
	check(wd.kind == "ward" and wd.collision_layer == Combatant.LAYER_WORLD and wd.has_state("fortified"), "Stone Ward: directional cover (world collision)")
	var fwd: Vector3 = (wd.global_position - h.global_position)
	fwd.y = 0
	check(fwd.length() > 1.5 and fwd.length() < 3.5, "the ward rises in front of the Mage")
	var hp0 := h.hp
	var cc := enemy_at("ash_caster", wd.global_position + fwd.normalized() * 6.0)
	var from: Vector3 = cc.global_position + Vector3(0, 1.2, 0)
	var hit_me := [false]
	Projectile.spawn(cc, from, (h.global_position + Vector3(0, 1.0, 0)) - from, 16.0, 0.3, Color.ORANGE, func(tt, _p): if tt == h: hit_me[0] = true, 2.0, 30.0)
	await wait(0.8)
	check(not hit_me[0], "Stone Ward blocks an enemy projectile aimed at the Mage")
	cc.queue_free()
	# Verdant Renewal
	e.equip_spell(1, "verdant_renewal")
	h.hp = h.max_hp * 0.4
	var v0 := h.hp
	refill(h)
	await wait(0.6)
	await hold(h, "heavy", 1.25)
	await wait(0.2)
	var after_cast := h.hp
	await wait(4.0)
	check(after_cast - v0 < 0.25 * (h.hp - after_cast) and h.hp > after_cast + 5.0, "Verdant Renewal: healing over time (not an instant rescue)", "%.0f -> %.0f -> %.0f" % [v0, after_cast, h.hp])
	e.clear_world()


# ================================================================== MILESTONE C
func test_c_thermal_fracture() -> void:
	print("\n[C] Fire + Frost: Thermal Fracture")
	var h := await mage(3)
	var e := el(h)
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -12))
	lock(h, w)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	var f: WorldFormation = e.formations[-1]
	var n0 := f.alive_count()
	var near := enemy_at("raider", f.global_position + Vector3(0.8, 0, -1.2))
	h.lock_target = null
	face(h, f)
	refill(h)
	await wait(0.6)
	inter.clear()
	tap(h, "light")       # partial Fire into the ice
	await wait(0.8)
	check(inter.has("thermal_fracture"), "partial Fire contacting ice triggers Thermal Fracture")
	check(f.alive_count() < n0, "the affected ice section is destroyed", "%d -> %d" % [n0, f.alive_count()])
	check(near.hp < 99999.0 and SteamCloud.count() == 0, "partial: short-range fragment burst, no steam")
	near.queue_free()
	e.clear_world()
	await wait(0.3)
	lock(h, w)
	refill(h)
	await wait(0.6)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	f = e.formations[-1]
	h.lock_target = null
	face(h, f)
	refill(h)
	await wait(0.6)
	inter.clear()
	await hold(h, "light", 1.25)
	await wait(0.8)
	check(inter.has("thermal_fracture") and SteamCloud.count() == 1, "full Fire melts the ice -> steam cloud")
	var sc = get_tree().get_nodes_in_group(SteamCloud.GROUP)[0]
	check(is_equal_approx(sc.duration, 3.0), "steam lasts 3s")
	# steam blocks sight both ways
	var behind := enemy_at("raider", sc.global_position + (sc.global_position - h.global_position).normalized() * 4.0)
	behind.aggro_range = 40.0
	check(not h.get_node("Brain").lock.has_line_of_sight(behind), "player lock-on cannot see through steam")
	check(e.target_enemy(30.0) != behind, "Mage targeting ignores enemies hidden by steam")
	behind.sm.set_physics_process(true)
	behind.target = null
	behind.threat.clear()
	behind.update_target(0.0)
	check(behind.target != h, "an enemy cannot newly acquire a hero through steam")
	var boss := enemy_at("ashen_warden", sc.global_position + (sc.global_position - h.global_position).normalized() * 5.0)
	boss.aggro_range = 40.0
	boss.update_target(0.0)
	check(boss.target == h, "steam does not disable boss AI")
	boss.queue_free()
	# no stacking
	SteamCloud.spawn(h, sc.global_position + Vector3(0.3, 0, 0))
	check(SteamCloud.count() == 1, "steam does not stack (refreshes instead)")
	await wait(3.3)
	check(SteamCloud.count() == 0, "steam expires")
	behind.update_target(0.0)
	check(behind.target == h, "sight returns after the steam clears")
	behind.queue_free()


func test_c_shattered_winter() -> void:
	print("\n[C] Stone + Frost: Shattered Winter")
	var h := await mage(7)
	var e := el(h)
	e.equip_spell(0, "earthbreaker")
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -12))
	lock(h, w)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	var f: WorldFormation = e.formations[-1]
	var dir: Vector3 = (f.global_position - h.global_position)
	dir.y = 0
	dir = dir.normalized()
	var ahead := enemy_at("raider", f.global_position + dir * 2.5)
	var behind := enemy_at("raider", h.global_position + Vector3(dir.z, 0, -dir.x) * 6.0)
	h.lock_target = null
	face(h, f)
	refill(h)
	await wait(0.6)
	inter.clear()
	await hold(h, "light", 1.85)
	await wait(0.8)
	check(inter.count("shattered_winter") == 1, "a full Stone impact on ice triggers Shattered Winter once (no self-repeat)", str(inter))
	check(f.gone or f.alive_count() < 4, "the struck ice is destroyed")
	check(ahead.hp < 99999.0, "directional fragments hit enemies along the impact direction")
	check(behind.hp == 99999.0, "enemies off the impact direction are not hit")


func test_c_conductive_anchors() -> void:
	print("\n[C] Storm + Stone: Conductive Anchors")
	var h := await mage(9)
	var e := el(h)
	await grant(h, ["stone_ward", "rising_pillar"])
	e.equip_spell(0, "thunder_conduit")
	var a := enemy_at("raider", h.global_position + Vector3(0, 0, -8))
	var b := enemy_at("raider", h.global_position + Vector3(10, 0, -8))
	lock(h, a)
	refill(h)
	e.ai_aim = null
	var pf := WorldFormation.spawn(h, "pillar", "stone", h.global_position + Vector3(5, 0, -8), Vector3.RIGHT, 1.4, 3.0, 1.4, 8.0, 200.0, 2.0)
	pf.set_state("fortified")
	e.formations.append(pf)
	await wait(0.6)
	await hold(h, "light", 1.3)
	await wait(0.3)
	check(b.hp == 99999.0, "Stone is NOT conductive by default: no relay")
	b.hp = 99999.0
	a.hp = 99999.0
	pf.set_state("conductive")
	refill(h)
	await wait(0.6)
	inter.clear()
	await hold(h, "light", 1.3)
	await wait(0.3)
	check(inter.has("conductive_anchors") and b.hp < 99999.0, "a conductive anchor relays the chain to a target outside direct range (10m)")
	check(int(e.last_release.get("targets", 0)) <= 3, "the relay does not exceed the 3-target chain")
	check(inter.count("conductive_anchors") == 1, "each anchor relays a given cast once (no loops)")


func test_c_living_bastion() -> void:
	print("\n[C] Life + Stone: Living Bastion")
	var h := await mage(7, true)
	var e := el(h)
	await grant(h, ["stone_ward"])
	e.equip_spell(3, "stone_ward")
	refill(h)
	e.cast_utility("stone_ward")
	var wd: WorldFormation = e.formations[-1]
	var ally: Hero = null
	for o in Game.heroes:
		if o != h:
			ally = o
	ally.global_position = wd.global_position + Vector3(0, 0, 1.5)
	ally.hp = ally.max_hp * 0.3
	e.set_heal_target(ally)
	refill(h)
	await wait(0.6)
	inter.clear()
	tap(h, "heavy")
	await wait(0.6)
	check(not wd.has_state("vitalized"), "a partial Life Bloom does not qualify")
	refill(h)
	await wait(0.6)
	await hold(h, "heavy", 1.3)
	await wait(0.1)
	check(inter.has("living_bastion") and wd.has_state("vitalized"), "a full Life Bloom next to a Fortified Stone formation Vitalizes it")
	var a0 := ally.hp
	ally.hp = ally.max_hp * 0.3
	a0 = ally.hp
	await wait(2.1)
	var pulse_heal := ally.hp - a0
	check(pulse_heal > 0.0, "Vitalized formation gives limited recovery to nearby allies", "+%.0f in 2s" % pulse_heal)
	check(pulse_heal < h.weapon_power * e.spells.life_bloom.power_full * 0.5, "its healing is lower than dedicated Life healing")
	wd.damage_segment(0, 1.0e6, "test")
	check(wd.alive_count() < wd.segments.size(), "the Vitalized formation remains destructible")


# ================================================================== MILESTONE D
func test_d_sanctum() -> void:
	print("\n[D] Arcane Sanctum")
	var h := await mage(4)
	var e := el(h)
	tap(h, "core")
	await wait(0.1)
	check(e.sanctum == null, "Sanctum locked before Level 5")
	Game.set_level("mage", 9)
	await wait(0.7)
	refill(h)
	tap(h, "core")
	await wait(0.4)
	check(e.sanctum != null and is_equal_approx(e.sanctum.radius, 3.5) and is_equal_approx(e.sanctum.duration, 10.0), "Sanctum: 3.5m, 10s")
	check(h.kit.cd("sanctum") > 24.0, "Sanctum cooldown 25s", "%.1f" % h.kit.cd("sanctum"))
	var sp: Vector3 = e.sanctum.global_position
	h.global_position += Vector3(6, 0, 0)
	await wait(0.3)
	check(e.sanctum.global_position.distance_to(sp) < 0.01 and not e.in_sanctum(), "stationary: it does not follow the Mage")
	h.global_position = sp
	await wait(0.1)
	check(e.in_sanctum(), "back inside")
	# Fire: secondary flame wave
	var t := enemy_at("raider", h.global_position + Vector3(0, 0, -9))
	lock(h, t)
	triggered.clear()
	refill(h)
	await hold(h, "light", 1.25)
	await wait(1.3)
	check(triggered.has("sanctum_fire"), "Fire inside: full impact produces a secondary flame wave")
	for z in e.fire_zones:
		z.queue_free()
	# Stone: small defensive formation
	e.equip_spell(0, "earthbreaker")
	triggered.clear()
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.85)
	await wait(0.9)
	check(triggered.has("sanctum_stone") and e.formations.any(func(f): return f.kind == "sanctum_guard" and f.has_state("fortified")), "Stone inside: qualifying impact raises a small defensive formation")
	# Storm: one additional relay
	e.equip_spell(0, "thunder_conduit")
	t.queue_free()
	var es: Array = []
	for i in 4:
		es.append(enemy_at("raider", h.global_position + Vector3(-4.5 + i * 3.0, 0, -10)))
	lock(h, es[1])
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.3)
	await wait(0.3)
	check(int(e.last_release.get("targets", 0)) == 4, "Storm inside: one additional relay (4 targets instead of 3)", str(e.last_release.get("targets", 0)))
	for x in es:
		x.queue_free()
	# Frost: formations connect
	e.clear_world()
	await wait(0.2)
	refill(h)
	tap(h, "core")
	await wait(0.4)
	e.equip_spell(2, "crystal_formation")
	var w1 := enemy_at("raider", h.global_position + Vector3(-3, 0, -10))
	lock(h, w1)
	refill(h)
	await wait(0.6)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	var w2 := enemy_at("raider", h.global_position + Vector3(4, 0, -10))
	lock(h, w2)
	refill(h)
	await wait(0.6)
	triggered.clear()
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	var nf: WorldFormation = e.formations[-1]
	check(triggered.has("sanctum_frost") and nf.alive_count() > 5, "Frost inside: the new ice connects to the other formation (extended barrier)", "%d sections" % nf.alive_count())
	w1.queue_free()
	w2.queue_free()
	# Life: additional ally
	var h2 := await mage(9, true)
	var e2 := el(h2)
	refill(h2)
	tap(h2, "core")
	await wait(0.4)
	var allies: Array = Game.heroes.filter(func(o): return o != h2)
	for o in allies:
		o.hp = o.max_hp * 0.4
		o.global_position = h2.global_position + Vector3(2, 0, 2)
	e2.set_heal_target(allies[0])
	var other0: float = allies[1].hp
	refill(h2)
	await wait(0.6)
	await hold(h2, "heavy", 1.3)
	await wait(0.2)
	check(allies[1].hp > other0, "Life inside: part of the charged heal reaches an additional ally")
	# outside: no enhancement
	h2.global_position += Vector3(8, 0, 0)
	for o in allies:
		o.hp = o.max_hp * 0.4
		o.global_position = h2.global_position + Vector3(2, 0, 2)
	other0 = allies[1].hp
	refill(h2)
	await wait(0.6)
	await hold(h2, "heavy", 1.3)
	await wait(0.2)
	check(is_equal_approx(allies[1].hp, other0), "outside the circle: no enhancement (Mage still fully functional)")


# ================================================================== MILESTONE E
func test_e_progression() -> void:
	print("\n[E] Progression Levels 1-10")
	var h := await mage(1)
	var e := el(h)
	var t: ProgressionTrack = Game.track("mage")
	var expect := {"m_frost": 3, "m_sanctum": 5, "m_stone": 7, "m_renewal": 7, "m_storm": 9, "m_arcane_mastery": 10}
	var ok := true
	for k in expect:
		if t.unlock_level(k) != expect[k]:
			ok = false
	check(ok, "unlock table: Frost 3, Sanctum 5, Stone + Renewal 7, Storm 9, Arcane Mastery 10")
	check(t.draft_levels.keys().size() == 3 and t.draft_levels.has(4) and t.draft_levels.has(8) and t.draft_levels.has(10), "augment drafts at Level 4, 8 and 10 (refoundation spec)", str(t.draft_levels))
	check(t.unlock_level("m_discovery") < 0, "no Level 9 element choice")
	Game.set_level("mage", 10)
	await wait(0.7)
	check(e.known_charged() == ["flame_cataclysm", "crystal_formation", "earthbreaker", "thunder_conduit", "life_bloom"], "Level 10 knows exactly the approved spells", str(e.known_charged()))
	# Arcane Mastery
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -9))
	lock(h, w)
	refill(h)
	await wait(0.6)
	h.press("light")
	await wait(1.0)
	var ct: float = e.charge_t
	h.press("dodge")
	h.release("dodge")
	await wait(0.05)
	h.release("light")
	check(not e.preserved.is_empty() and absf(float(e.preserved.t) - ct * 0.4) < 0.05, "Arcane Mastery preserves 40% of the charge", "%.2f of %.2f" % [float(e.preserved.get("t", 0.0)), ct])
	check(absf(float(e.preserved.until) - Game.time - 2.0) < 0.15 and e.mastery_cd > 14.0, "2s window, 15s internal cooldown")
	check(e.cur == null, "the Mage must start casting again to use it")
	await wait(0.8)
	h.press("light")
	await wait(0.02)
	check(e.cur != null and e.ratio() < 0.5, "resumed charge applies to the same spell and is never an instant full charge", "%.2f" % e.ratio())
	h.release("light")
	await wait(1.0)
	h.press("light")
	await wait(0.6)
	h.press("dodge")
	h.release("dodge")
	await wait(0.05)
	h.release("light")
	check(e.preserved.is_empty(), "internal cooldown prevents a second preservation")


func test_e_augments() -> void:
	print("\n[E] Augments (only the approved list)")
	var h := await mage(4)
	var e := el(h)
	var all: Array = Game.augment_db.for_class("mage").filter(func(a): return Game.augment_db.ineligible_reason(a, Game.prog()) != "legacy Mage core only" and not String(a.params.get("requires_core", "")) in ["weave", "sigils"]).map(func(a): return a.id)
	all.sort()
	check(all == ["crystal_chain", "everlasting_bloom", "infernal_collapse", "living_bastion", "living_thunder", "mountainfall", "second_heart", "storm_lattice", "wandering_sanctum"], "Mage augment pool = the 9 approved augments (refoundation spec)", str(all))
	var elig: Array = Game.augment_db.eligible("mage", Game.prog()).map(func(a): return a.id)
	check(not elig.has("mountainfall") and not elig.has("living_thunder") and not elig.has("living_bastion"), "no augments for locked elements at Level 4", str(elig))
	check(not elig.has("wandering_sanctum"), "no augments with missing prerequisites (Sanctum is Level 5)")
	check(elig.has("infernal_collapse") and elig.has("crystal_chain") and elig.has("everlasting_bloom"), "known-element augments offered")
	var draft: Array = Game.augment_db.roll("mage", Game.prog(), 3, Game.rng, "any").map(func(a): return a.id)
	check(draft.size() == 3, "three-card draft works")
	# Infernal Collapse
	Game.add_augment("mage", "infernal_collapse")
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -8))
	lock(h, w)
	CombatLog.clear()
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.25)
	await wait(2.2)
	check(e.fire_zones.is_empty() and log_has("Infernal Collapse"), "Infernal Collapse: no persistent area, delayed secondary explosion")
	# Everlasting Bloom
	Game.add_augment("mage", "everlasting_bloom")
	h.hp = h.max_hp * 0.2
	var hp0 := h.hp
	refill(h)
	await wait(0.6)
	await hold(h, "heavy", 1.25)
	await wait(0.05)
	check(h.statuses.has("everlasting_bloom"), "Everlasting Bloom: part of the direct heal becomes a HoT")
	var direct := h.hp - hp0
	check(direct < h.weapon_power * e.spells.life_bloom.power_full * 0.7, "the direct part is reduced accordingly (conversion, not a bonus)")
	# Crystal Chain
	Game.add_augment("mage", "crystal_chain")
	var a1 := enemy_at("raider", h.global_position + Vector3(-3, 0, -10))
	lock(h, a1)
	refill(h)
	await wait(0.6)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	var a2 := enemy_at("raider", h.global_position + Vector3(4, 0, -10))
	lock(h, a2)
	triggered.clear()
	refill(h)
	await wait(0.6)
	await hold(h, "skill1", 1.3)
	await wait(0.3)
	check(triggered.has("crystal_chain"), "Crystal Chain connects compatible ice formations")
	# Living Thunder / Mountainfall / Wandering Sanctum
	Game.set_level("mage", 9)
	await wait(0.7)
	Game.add_augment("mage", "living_thunder")
	Game.add_augment("mage", "mountainfall")
	Game.add_augment("mage", "wandering_sanctum")
	e.clear_world()
	e.equip_spell(0, "thunder_conduit")
	var es: Array = []
	for i in 4:
		es.append(enemy_at("raider", h.global_position + Vector3(-4.5 + i * 3.0, 0, -12)))
	lock(h, es[0])
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.3)
	await wait(0.3)
	check(int(e.last_release.get("targets", 0)) == 4 and triggered.has("living_thunder"), "Living Thunder: one additional directed chain target")
	for x in es:
		x.queue_free()
	e.equip_spell(0, "earthbreaker")
	var m := enemy_at("raider", h.global_position + Vector3(0, 0, -9))
	lock(h, m)
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.85)
	await wait(0.4)
	check(m.hp == 99999.0, "Mountainfall: impact is delayed (overhead)")
	await wait(1.0)
	check(m.hp < 99999.0 and triggered.has("mountainfall"), "Mountainfall impact lands")
	refill(h)
	tap(h, "core")
	await wait(0.3)
	var sp: Vector3 = e.sanctum.global_position
	h.global_position += Vector3(5, 0, 0)
	await wait(0.8)
	check(e.sanctum.global_position.distance_to(sp) > 3.0 and is_equal_approx(e.sanctum_mult(), 0.7), "Wandering Sanctum follows the Mage at reduced effectiveness")


func test_e_stats() -> void:
	print("\n[E] Stat scaling follows established formulas")
	var h := await mage(5)
	var e := el(h)
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -8))
	lock(h, w)
	await hold(h, "light", 1.25)
	await wait(0.8)
	var base_full := 99999.0 - w.hp
	for z in e.fire_zones:
		z.queue_free()
	w.hp = 99999.0
	Game.prog().debug_bonus["str"] = 20
	Game.refresh_class_heroes("mage")
	await wait(0.2)
	h = Game.player
	h.stats.crit_chance = 0.0
	lock(h, w)
	refill(h)
	await wait(0.6)
	await hold(h, "light", 1.25)
	await wait(0.8)
	check(99999.0 - w.hp > base_full * 1.3, "STR scales fully charged spell damage")
	Game.prog().debug_bonus["str"] = 0
	Game.prog().debug_bonus["mas"] = 20
	Game.refresh_class_heroes("mage")
	await wait(0.2)
	h = Game.player
	check(h.stats.effect_power() > 1.3, "MAS raises buff / DoT / HoT effect power", "x%.2f" % h.stats.effect_power())
	Game.prog().debug_bonus["mas"] = 0


# ================================================================== MILESTONE F
func test_f_ai_and_save() -> void:
	print("\n[F] AI Mage + save/load")
	var h := await setup("vanguard", true, false, false)
	Game.set_level("vanguard", 5)
	var m: Hero = null
	for o in Game.heroes:
		if o.class_id == "mage":
			m = o
	await wait(0.5)
	h.hp = h.max_hp * 0.3
	var hp0 := h.hp
	released.clear()
	await wait(4.0)
	check(h.hp > hp0, "AI Mage heals a wounded ally with no enemies around", "%.0f -> %.0f" % [hp0, h.hp])
	check(released.any(func(r): return r.c == m and r.id in ["lifeline", "life_bloom"]), "AI uses the same Life spells (Lifeline / Life Bloom)")
	var w := enemy_at("raider", h.global_position + Vector3(0, 0, -12))
	w.sm.set_physics_process(true)
	released.clear()
	await wait(4.0)
	check(released.any(func(r): return r.c == m and r.id == "flame_cataclysm"), "AI uses offensive magic when healing is stable")
	w.queue_free()
	Save.enabled = true
	Save.path = fixture_path("test_mage_save.json")
	Save.delete_save()
	Game.reset_all_progress()
	Game.debug_tainted = false
	Game.create_character("mage", "Lyra")
	Game.prog("mage").set_level(7)
	Game.prog("mage").spell_loadout = ["earthbreaker", "life_bloom", "flame_cataclysm", "protective_renewal"]
	Game.prog("mage").bloom_shared = true
	Save.save_game()
	Game.reset_all_progress()
	Save.load_game()
	check(Game.prog("mage").spell_loadout == ["earthbreaker", "life_bloom", "flame_cataclysm", "protective_renewal"] and Game.prog("mage").bloom_shared, "loadout (incl. utility slot) and Bloom mode are saved")
	Game.prog("mage").debug_unlocks.append("spell:inferno_wave")
	Game.prog("mage").debug_elements.append("storm")
	var dd: Dictionary = Game.prog("mage").to_dict()
	check(not str(dd).contains("inferno_wave") and not Array(dd.elements).has("storm"), "Debug grants are never written to the save")
	Save.delete_save()
	Save.enabled = false
