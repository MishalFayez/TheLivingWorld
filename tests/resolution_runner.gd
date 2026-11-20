extends "res://tests/test_runner.gd"
## DESIGN RESOLUTION: automated FUNCTIONAL checks (Reaver input / skills, Vanguard Guarded Strike,
## Shield Plant, Resolve economy, progression data).
##   godot --headless --fixed-fps 60 res://tests/resolution_runner.tscn
## Mechanics only - whether it is fun needs human playtesting.

var links: Array = []
var trig: Array = []


func _run_all() -> void:
	Events.blade_transition.connect(func(h, a, b, legal): links.append({"from": a, "to": b, "legal": legal}))
	Events.augment_triggered.connect(func(o, id, d): trig.append(id))
	await test_progression_data()
	await test_directional_intent()
	await test_repetition()
	await test_flow_step()
	await test_crosscut()
	await test_sunder_edge()
	await test_turning_edge()
	await test_final_stroke()
	await test_guarded_strike()
	await test_shield_plant()
	await test_resolve_economy()
	await teardown()


func reaver(level: int, unlocks: Array = []) -> Hero:
	var h := await setup("reaver", false, false, false)
	Game.reaver_core = "swordmaster"
	Game.set_level("reaver", level)
	for u in unlocks:
		Game.prog("reaver").debug_unlocks.append(u)
	await wait(0.2)
	h.restore_all()
	h.stats.crit_chance = 0.0
	links.clear()
	trig.clear()
	return h


func raider_at(h: Hero, off: Vector3, type: String = "raider") -> Enemy:
	var r := dummy(type, h.global_position + off)
	r.max_hp = 99999
	r.hp = 99999
	return r


func lateral(h: Hero, side: String) -> void:
	h.held["blade_modifier"] = true
	h.strafe_axis = -1.0 if side == "left" else 1.0
	tap(h, "light")
	h.held["blade_modifier"] = false
	h.strafe_axis = 0.0


func slot_of(h: Hero, id: String) -> String:
	h.kit.sm.refresh_loadout()
	var lo: Array = h.kit.sm.loadout()
	var i := lo.find(id)
	return ReaverSwordmaster.SLOT_ACTIONS[i] if i >= 0 else ""


# ------------------------------------------------------------------
func test_progression_data() -> void:
	print("\n[Progression data]")
	# REAVER-FREEFLOW-001: the Reaver track depends on the core; this checks the Swordmaster track
	Game.reaver_core = "swordmaster"
	var rt: ProgressionTrack = Game.track("reaver")
	var want := {"r_lunge": 3, "r_flow_step": 5, "r_crosscut": 7, "r_draw": 7, "r_flurry": 9, "r_discipline": 10, "r_sunder_edge": 12, "r_turning_edge": 15, "r_final_stroke": 18}
	var ok := true
	for k in want:
		if rt.unlock_level(k) != want[k]:
			ok = false
	check(ok, "Reaver milestones: Lunge 3, Flow Step 5, Crosscut + Draw Cut 7, Flurry 9, Discipline 10, Sunder Edge 12, Turning Edge 15, Final Stroke 18")
	check(rt.milestone("r_flow_step").kind != "pending" and rt.milestone("r_crosscut").kind != "pending", "no 'design pending' placeholders left")
	var vt: ProgressionTrack = Game.track("vanguard")
	check(vt.unlock_level("v_guarded_strike") == 1 and vt.unlock_level("v_shield_plant") == 12 and vt.unlock_level("v_resolve") == 5, "Vanguard: Guarded Strike Lv1, Resolve Spending Lv5, Shield Plant Lv12")
	check(Game.balance.max_level == 10, "level cap stays 10: Lv12+ skills are Build Showcase only")


func test_directional_intent() -> void:
	print("\n[Reaver - directional intent]")
	check(InputMap.has_action("blade_modifier") and InputMap.has_action("guard"), "separate 'blade_modifier' action (Shift); Vanguard 'guard' binding untouched")
	var h := await reaver(5)
	var r := raider_at(h, Vector3(0, 0, -2.3))
	h.lock_target = r
	face(h, r)
	var ids: Array = []
	for i in 4:
		h.move_input = Vector3(-1 if i % 2 == 0 else 1, 0, 0)
		h.strafe_axis = h.move_input.x
		tap(h, "light")
		await wait(0.02)
		ids.append(h.runner.data.id)
		await wait(0.7)
	h.move_input = Vector3.ZERO
	h.strafe_axis = 0.0
	check(ids.all(func(x): return x == "rs_forward"), "strafing (A/D, no Shift) + LMB = Forward Cut only", str(ids))
	lateral(h, "left")
	await wait(0.02)
	check(h.runner.data.id == "rs_lateral_l", "Shift + A + LMB = Lateral Cut left")
	await wait(0.8)
	lateral(h, "right")
	await wait(0.02)
	check(h.runner.data.id == "rs_lateral_r", "Shift + D + LMB = Lateral Cut right")
	# captured at accept: buffered during the cut, released keys before it fires
	await wait(0.1)
	lateral(h, "right")
	await wait(0.5)
	check(h.runner.data.id == "rs_lateral_r", "a buffered Shift+D+LMB keeps its direction even after the keys are released")
	await wait(0.6)
	tap(h, "light")
	await wait(0.05)
	h.held["blade_modifier"] = true
	h.strafe_axis = -1.0
	await wait(0.05)
	check(h.runner.data.id == "rs_forward", "holding Shift + A after the press does not change the cut mid-animation")
	h.held["blade_modifier"] = false
	h.strafe_axis = 0.0
	r.queue_free()


func test_repetition() -> void:
	print("\n[Reaver - repetition vs deliberate paths]")
	var h := await reaver(10)
	var r := raider_at(h, Vector3(0, 0, -2.3))
	h.lock_target = r
	face(h, r)
	tap(h, "light")
	await wait(0.37)
	tap(h, "light")
	await wait(0.02)
	check(h.runner.data.id == "rs_forward" and not h.runner.ctx.get("linked", false) and is_equal_approx(h.runner.data.startup, 0.14), "Forward -> Forward is allowed but gets NO transition benefit")
	await wait(0.3)
	lateral(h, "left")
	await wait(0.15)
	check(h.runner.ctx.get("linked", false) and h.runner.data.startup < 0.12, "Forward -> Lateral = link (faster start, keeps tracking)")
	await wait(0.32)
	tap(h, "heavy")
	await wait(0.4)
	check(h.runner.ctx.get("linked", false) and h.runner.data.id == "rs_heavy", "Lateral -> Heavy = link")
	check(not h.runner.ctx.has("damage_mult") or float(h.runner.ctx.damage_mult) == 1.0, "no damage multiplier for alternating")
	await wait(1.0)
	h.try_dodge()
	await wait(Game.balance.dodge_duration + 0.05)
	tap(h, "light")
	await wait(0.02)
	check(h.runner.data.id == "rs_slip", "Dodge -> Slip Cut")
	r.queue_free()


func test_flow_step() -> void:
	print("\n[Reaver - Flow Step]")
	var h := await reaver(5)
	var act := slot_of(h, "r_flow_step")
	check(act != "", "Flow Step auto-equipped at Lv5", str(h.kit.sm.loadout()))
	var r := raider_at(h, Vector3(0, 0, -3.0))
	h.lock_target = r
	face(h, r)
	var p0 := h.global_position
	var st := h.stamina
	h.move_input = Vector3(1, 0, 0)
	tap(h, act)
	await wait(0.5)
	h.move_input = Vector3.ZERO
	var step := Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z)
	check(step.x > 0.4 and step.length() >= 0.5 and step.length() <= 0.9, "0.7m step in the input direction (from neutral)", "%.2fm" % step.length())
	check(h.stamina < st and h.kit.skill_cd("r_flow_step") > 2.0, "costs stamina, 3s cooldown")
	check(not h.dodging and not h.is_invulnerable(), "no invulnerability frames (not a dodge)")
	# into a body: stops at the enemy
	h.kit.cooldowns.clear()
	h.global_position = r.global_position + Vector3(0, 0, 1.1)
	face(h, r)
	await wait(0.1)
	h.move_input = Vector3(0, 0, -1)
	tap(h, act)
	await wait(0.5)
	h.move_input = Vector3.ZERO
	check(h.global_position.distance_to(r.global_position) > 0.5, "cannot pass through a solid enemy", "%.2fm" % h.global_position.distance_to(r.global_position))
	# linked continuation
	h.kit.cooldowns.clear()
	h.global_position = r.global_position + Vector3(0, 0, 2.3)
	face(h, r)
	await wait(0.6)
	links.clear()
	tap(h, "light")
	await wait(0.38)
	h.move_input = Vector3(-1, 0, 0)
	tap(h, act)
	h.move_input = Vector3.ZERO
	await wait(0.3)
	lateral(h, "right")
	await wait(0.05)
	check(h.runner.data.id == "rs_lateral_r" and h.runner.ctx.get("linked", false), "Flow Step in a link window keeps the sequence: the next different cut is linked")
	check(not h.runner.data.has_tag("step") and h.runner.data.hits > 0, "Flow Step does not attack by itself")
	r.queue_free()


func test_crosscut() -> void:
	print("\n[Reaver - Crosscut]")
	var h := await reaver(7)
	var act := slot_of(h, "r_crosscut")
	check(act != "", "Crosscut auto-equipped at Lv7")
	var r := raider_at(h, Vector3(0, 0, -2.0))
	h.lock_target = r
	face(h, r)
	var hits: Array = []
	var cb := func(info): if info.target == r and info.attack_name.begins_with("Crosscut"): hits.append(info.final_amount)
	Events.damage_applied.connect(cb)
	tap(h, act)
	await wait(1.2)
	check(hits.size() == 2, "both hits land (two separate hit windows)", str(hits))
	var full := 0.0
	for x in hits:
		full += x
	hits.clear()
	h.kit.cooldowns.clear()
	await wait(0.3)
	tap(h, act)
	await wait(0.30)       # inside the first hit window, after it connected
	h.try_dodge()
	await wait(0.8)
	Events.damage_applied.disconnect(cb)
	check(hits.size() == 1, "a dodge after the first hit abandons the second", str(hits))
	var cc: AttackData = load("res://data/attacks/rs_crosscut.tres")
	check(cc.hit_weights.size() == 2 and cc.crit_chance_bonus == 0.0 and cc.hits == 2, "damage split 55/45 by the multi-hit rules, no crit bonus, no third hit")
	r.queue_free()


func test_sunder_edge() -> void:
	print("\n[Reaver - Sunder Edge]")
	var h := await reaver(10, ["r_sunder_edge"])
	h.kit.sm.equip(0, "r_sunder_edge")
	var g := raider_at(h, Vector3(0, 0, -2.2), "shield_guardian")
	face(g, h)
	h.lock_target = g
	face(h, g)
	var p0: float = g.poise
	var hp0 := g.hp
	tap(h, "skill1")
	await wait(0.9)
	var se_dmg := hp0 - g.hp
	var se_poise := p0 - g.poise
	await wait(1.5)
	g.poise = g.max_poise
	face(g, h)
	face(h, g)
	hp0 = g.hp
	p0 = g.poise
	tap(h, "heavy")
	await wait(1.3)
	var hv_dmg := hp0 - g.hp
	var hv_poise := p0 - g.poise
	check(se_poise > hv_poise * 1.3, "vs a raised guard: Sunder Edge deals much more Poise damage than a Heavy Cut", "%.0f vs %.0f" % [se_poise, hv_poise])
	check(se_dmg > 0.0 and se_dmg < 99999.0, "the guard still reduces it (no full bypass)", "%.0f dmg" % se_dmg)
	g.queue_free()
	var rr := raider_at(h, Vector3(0, 0, -2.2))
	h.lock_target = rr
	face(h, rr)
	h.kit.cooldowns.clear()
	await wait(0.5)
	tap(h, "skill1")
	await wait(0.9)
	check(rr.hp < 99999.0, "also works against a non-guarding enemy (moderate direct damage)")
	rr.queue_free()
	var boss := raider_at(h, Vector3(0, 0, -2.6), "ashen_warden")
	h.lock_target = boss
	face(h, boss)
	h.kit.cooldowns.clear()
	await wait(0.5)
	tap(h, "skill1")
	await wait(0.9)
	check(not boss.is_staggered(), "does not automatically stagger the boss")
	boss.queue_free()
	await wait(0.5)
	# miss recovery
	h.kit.cooldowns.clear()
	h.lock_target = null
	h.face_dir(Vector3(1, 0, 0))
	tap(h, "skill1")
	var busy := 0
	for i in 120:
		await get_tree().physics_frame
		if h.runner.is_busy():
			busy += 1
	var d: AttackData = load("res://data/attacks/rs_sunder_edge.tres")
	check(busy / 60.0 > d.total_time() + 0.25, "a miss has meaningful extra recovery", "%.2fs busy" % (busy / 60.0))


func test_turning_edge() -> void:
	print("\n[Reaver - Turning Edge]")
	var h := await reaver(10, ["r_turning_edge", "r_final_stroke"])
	h.kit.sm.equip(1, "r_turning_edge")
	var g := raider_at(h, Vector3(0, 0, -2.0), "shield_guardian")
	face(g, h)
	h.lock_target = g
	face(h, g)
	tap(h, "skill2")
	await wait(0.05)
	check(not h.runner.is_busy() or h.runner.data.id != "rs_turning_edge", "no side chosen (A / D) = no Turning Edge (direction is intentional)")
	var p0 := h.global_position
	h.strafe_axis = 1.0
	var hp0 := g.hp
	tap(h, "skill2")
	h.strafe_axis = 0.0
	await wait(0.8)
	var front_dmg := hp0 - g.hp
	var side := Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	check(side > 0.4 and side < 1.0, "short collision-safe lateral step before the slash", "%.2fm" % side)
	check(not h.kit.sm.finisher_open(), "frontal Turning Edge: no positional benefit, no Final Stroke")
	# flank: stand at the guardian's side
	await wait(0.6)
	h.kit.cooldowns.clear()
	g.face_dir(Vector3(0, 0, 1))
	h.global_position = g.global_position + Vector3(1.8, 0, 0.3)
	face(h, g)
	h.lock_target = g
	await wait(0.1)
	hp0 = g.hp
	h.strafe_axis = 1.0      # step further round its side (away from the shield)
	tap(h, "skill2")
	h.strafe_axis = 0.0
	await wait(0.8)
	var flank_dmg := hp0 - g.hp
	check(flank_dmg > front_dmg * 1.5, "from a real flank the shield does not block it", "%.0f vs %.0f" % [flank_dmg, front_dmg])
	check(h.kit.sm.finisher_open() or trig.has("r_final_stroke"), "a flank hit prepares Final Stroke")
	g.queue_free()


func test_final_stroke() -> void:
	print("\n[Reaver - Final Stroke]")
	var h := await reaver(10, ["r_final_stroke", "r_sunder_edge"])
	var sm: ReaverSwordmaster = h.kit.sm
	var r := raider_at(h, Vector3(0, 0, -2.2))
	h.lock_target = r
	face(h, r)
	check(not sm.final_stroke(), "refused when no opportunity is open")
	# condition 1: two different linked attacks connect
	tap(h, "light")
	await wait(0.37)
	lateral(h, "left")
	await wait(0.45)
	check(sm.finisher_open(), "opens after two different linked attacks connect (" + sm.finisher_reason + ")")
	await wait(1.6)
	check(not sm.finisher_open(), "expires after 1.5s")
	tap(h, "light")
	await wait(0.37)
	lateral(h, "right")
	await wait(0.45)
	var st := h.stamina
	var lk := sm.links
	check(sm.final_stroke(), "Final Stroke usable while open")
	await wait(0.02)
	check(h.stamina <= st - 24.0, "costs stamina (25)")
	check(sm.last_line == "" and not sm.finisher_open(), "ends the current Blade Continuity sequence")
	await wait(1.4)
	# can miss: open by hand, nobody in front
	sm.open_finisher("test")
	h.lock_target = null
	h.face_dir(Vector3(1, 0, 0))
	var hp0 := r.hp
	sm.final_stroke()
	await wait(1.3)
	check(is_equal_approx(r.hp, hp0), "can miss")
	# condition 2: Sunder Edge poise break
	h.kit.sm.equip(0, "r_sunder_edge")
	h.kit.cooldowns.clear()
	r.poise = 1.0
	h.lock_target = r
	face(h, r)
	tap(h, "skill1")
	await wait(0.8)
	check(sm.finisher_open() and sm.finisher_reason.contains("Sunder"), "opens after a Sunder Edge poise break")
	var fs: AttackData = load("res://data/attacks/rs_final_stroke.tres")
	check(fs.crit_chance_bonus == 0.0 and fs.startup >= 0.35 and fs.recovery >= 0.5, "no guaranteed crit; meaningful startup and recovery")
	r.queue_free()


# ------------------------------------------------------------------ Vanguard
func vanguard(level: int, party: bool = false) -> Hero:
	var h := await setup("vanguard", party, false, false)
	Game.set_level("vanguard", level)
	await wait(0.2)
	h.restore_all()
	trig.clear()
	return h


func hit_from(h: Hero, e: Enemy, amount: float, guard_break: bool = false) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = e
	info.target = h
	info.amount = amount
	info.raw_amount = amount
	info.poise = 20.0
	info.knockback = 4.0
	info.guard_break = guard_break
	info.source_pos = e.global_position
	e.attack_serial += 1
	h.take_damage(info)
	return info


func test_guarded_strike() -> void:
	print("\n[Vanguard - Guarded Strike]")
	var h := await vanguard(5)
	var kit: VanguardKit = h.kit
	var e := raider_at(h, Vector3(0, 0, -2.0))
	h.lock_target = e
	face(h, e)
	h.press("guard")
	await wait(0.4)
	var hp0 := h.hp
	hit_from(h, e, 100.0)
	var guarded_loss := hp0 - h.hp
	kit.resolve = 0.0
	tap(h, "light")
	await wait(0.2)
	check(h.runner.is_busy() and h.runner.data.id == "v_guarded_strike", "Shift + LMB from Guard = Guarded Strike (Lv1 skill)")
	hp0 = h.hp
	hit_from(h, e, 100.0)
	var strike_loss := hp0 - h.hp
	check(strike_loss > guarded_loss * 1.5, "protection is reduced during the swing", "%.0f vs %.0f" % [strike_loss, guarded_loss])
	await wait(0.6)
	check(kit.guarding, "normal Guard returns after the recovery while Shift is held")
	check(kit.resolve >= 3.0 - 0.01, "a valid enemy hit generates Resolve", "%.1f" % kit.resolve)
	var r0 := kit.resolve
	hp0 = h.hp
	hit_from(h, e, 100.0)
	check(hp0 - h.hp < strike_loss, "after recovery the full Guard protects again")
	var hv: AttackData = load("res://data/attacks/v_heavy.tres")
	var gs: AttackData = load("res://data/attacks/v_guarded_strike.tres")
	check(gs.damage_mult < hv.damage_mult and gs.stamina_cost > 0.0, "less damage than the Heavy, costs stamina")
	h.release("guard")
	e.queue_free()
	# Resolve only from enemies, once per attack
	var h1 := await vanguard(5)
	var k1: VanguardKit = h1.kit
	k1.resolve = 0.0
	var e2 := raider_at(h1, Vector3(0, 0, -2.0))
	var info := DamageInfo.new()
	info.source = h1
	info.target = e2
	h1.runner.start(load("res://data/attacks/v_guarded_strike.tres"), {"guarded_strike": true})
	for i in 3:
		k1.on_hit_landed(e2, info)
	check(is_equal_approx(k1.resolve, 3.0), "one Resolve gain per strike (no repeated collisions)", "%.1f" % k1.resolve)
	k1.resolve = 0.0
	var ally: Hero = Game.heroes[0]
	h1.runner.start(load("res://data/attacks/v_guarded_strike.tres"), {"guarded_strike": true})
	k1.on_hit_landed(ally, info)
	check(k1.resolve == 0.0, "no Resolve from allies / non-enemies")
	var h2 := await vanguard(1)
	var k2: VanguardKit = h2.kit
	var e3 := raider_at(h2, Vector3(0, 0, -2.0))
	h2.runner.start(load("res://data/attacks/v_guarded_strike.tres"), {"guarded_strike": true})
	k2.on_hit_landed(e3, info)
	check(k2.resolve == 0.0, "no Resolve before the Resolve system unlocks (Lv5)")


func test_shield_plant() -> void:
	print("\n[Vanguard - Shield Plant]")
	var h := await vanguard(10)
	var kit: VanguardKit = h.kit
	tap(h, "core")
	check(not kit.planted, "locked before Lv12 (natural)")
	Game.prog("vanguard").debug_unlocks.append("v_shield_plant")
	h.restore_all()
	var st := h.stamina
	tap(h, "core")
	check(kit.planted and h.stamina <= st - 14.9 and kit.cd("v_shield_plant") > 17.0, "plants: 15 stamina, 18s cooldown")
	check(is_equal_approx(kit.move_mult(), 0.15), "15% movement while planted")
	var front := raider_at(h, h.forward() * 2.0 + Vector3(0, 0, 0))
	var side := raider_at(h, h.forward().cross(Vector3.UP) * 2.0 + h.forward() * 0.4)
	var back := raider_at(h, -h.forward() * 2.0)
	var hp0 := h.hp
	var i1 := hit_from(h, front, 30.0)
	var f_loss := hp0 - h.hp
	h.stamina = h.max_stamina
	hp0 = h.hp
	hit_from(h, side, 30.0)
	var s_loss := hp0 - h.hp
	h.stamina = h.max_stamina
	hp0 = h.hp
	hit_from(h, back, 30.0)
	var b_loss := hp0 - h.hp
	h.stamina = h.max_stamina
	check(f_loss <= b_loss * 0.2, "frontal: reinforced protection (85%)", "%.1f vs unprotected %.1f" % [f_loss, b_loss])
	check(s_loss <= b_loss * 0.2, "side-front (wider 90 deg arc) protected too", "%.1f" % s_loss)
	var hp1 := h.hp
	kit.planted = false
	kit.guarding = false
	hit_from(h, back, 30.0)
	var raw_loss := hp1 - h.hp
	kit.planted = true
	kit.guarding = true
	check(absf(b_loss - raw_loss) < 0.5, "attacks from behind are NOT protected (same as unguarded)", "%.1f vs %.1f" % [b_loss, raw_loss])
	check(i1.knockback < 1.0, "displacement resistance", "%.2f" % i1.knockback)
	check(kit.planted, "still planted after the hits")
	hit_from(h, front, 100.0, true)
	check(not kit.planted, "a Guard Break still breaks the plant (no universal immunity)")
	await wait(1.5)
	h.restore_all()
	kit.cooldowns.clear()
	tap(h, "core")
	await wait(0.2)
	tap(h, "core")
	await wait(0.05)
	check(not kit.planted and h.runner.is_busy() and h.runner.data.id == "v_plant_exit", "voluntary exit through a recovery")
	await wait(0.6)
	kit.cooldowns.clear()
	tap(h, "core")
	await wait(4.2)
	check(not kit.planted, "ends after 4s")
	# Rolling Fortress modifies Shield Plant
	Game.add_augment("vanguard", "rolling_fortress")
	await wait(0.2)
	h = Game.player
	kit = h.kit
	kit.cooldowns.clear()
	h.restore_all()
	tap(h, "core")
	var p0 := h.global_position
	h.move_input = Vector3(1, 0, 0)
	h.try_dodge()
	await wait(0.35)
	h.move_input = Vector3.ZERO
	check(kit.planted and not h.dodging and h.global_position.distance_to(p0) > 0.5, "Rolling Fortress: Dodge while planted = reposition, still planted")
	for x in [front, side, back]:
		x.queue_free()


func test_resolve_economy() -> void:
	print("\n[Vanguard - Resolve economy]")
	var h := await vanguard(4)
	var kit: VanguardKit = h.kit
	kit.resolve = 100.0
	h.press("skill1")
	await wait(0.5)
	h.release("skill1")
	check(is_equal_approx(kit.resolve, 100.0), "no Resolve spending before Lv5")
	await wait(1.5)
	h = await vanguard(5)
	kit = h.kit
	check(not kit.unlocked("judgment_strike") and not kit.unlocked("iron_sweep"), "Lv5: only Shield Rush can spend (Verdict Lv7, Aegis Sweep Lv9)")
	check(not str(kit.hud_lines()).contains("Verdict") and not str(kit.hud_lines()).contains("Aegis Sweep"), "unavailable spenders are not shown")
	var e := raider_at(h, Vector3(0, 0, -5.0))
	h.lock_target = e
	face(h, e)
	kit.resolve = 100.0
	tap(h, "skill1")
	await wait(0.05)
	check(is_equal_approx(kit.resolve, 100.0) and not h.runner.ctx.get("empowered", false), "TAP 1 = normal Shield Rush (no spend)")
	await wait(1.2)
	kit.cooldowns.clear()
	h.press("skill1")
	await wait(0.45)
	h.release("skill1")
	await wait(0.02)
	check(is_equal_approx(kit.resolve, 70.0) and h.runner.ctx.get("empowered", false), "HOLD 1 = Empowered Shield Rush (30)")
	await wait(1.5)
	h = await vanguard(9)
	kit = h.kit
	kit.resolve = 100.0
	h.press("skill2")
	await wait(1.6)
	h.release("skill2")
	await wait(0.02)
	check(is_equal_approx(kit.resolve, 60.0) and h.runner.data.display_name == "Verdict Strike", "full Judgment = Verdict Strike (40)")
	await wait(1.6)
	kit.cooldowns.clear()
	h.press("skill3")
	await wait(0.45)
	h.release("skill3")
	await wait(0.02)
	check(is_equal_approx(kit.resolve, 35.0) and h.runner.data.display_name == "Aegis Sweep" and h.runner.ctx.get("taunt", false), "HOLD 3 = Aegis Sweep (25): area threat control")
	var sw: SkillData = load("res://data/skills/iron_sweep.tres")
	check(h.runner.data.damage_mult <= sw.attack.damage_mult + 0.001, "Aegis Sweep adds threat control, not damage")
	await wait(1.5)
	# sources: PG strongest, one gain per defended attack
	kit.resolve = 0.0
	var e2 := raider_at(h, Vector3(0, 0, -2.0))
	face(h, e2)
	h.press("guard")
	await wait(0.5)
	var info := DamageInfo.new()
	info.source = e2
	info.target = h
	info.amount = 30.0
	info.source_pos = e2.global_position
	e2.attack_serial += 1
	h.take_damage(info)
	var info2 := info.copy()
	h.take_damage(info2)
	check(is_equal_approx(kit.resolve, Game.balance.resolve_on_guard), "normal Guard: small gain, once per defended attack", "%.1f" % kit.resolve)
	check(Game.balance.resolve_on_perfect > Game.balance.resolve_on_counter and Game.balance.resolve_on_perfect > Game.balance.resolve_on_intercept and Game.balance.resolve_on_perfect > Game.balance.resolve_on_guarded_strike, "Perfect Guard is the strongest source")
	h.release("guard")
	# Guardian's Reserve
	var hv := await vanguard(10, true)
	var kv: VanguardKit = hv.kit
	Game.add_augment("vanguard", "guardians_reserve")
	await wait(0.2)
	hv = Game.player
	kv = hv.kit
	var ally: Hero = null
	for o in Game.heroes:
		if o != hv:
			ally = o
	ally.global_position = hv.global_position + Vector3(1.5, 0, 0)
	var e3 := raider_at(hv, Vector3(1.5, 0, -1.5))
	kv.resolve = 50.0
	var inf := DamageInfo.new()
	inf.source = e3
	inf.target = ally
	inf.amount = 10.0
	inf.source_pos = e3.global_position
	var sh0: float = ally.shield_hp
	kv.try_intercept(inf, ally)
	check(trig.has("guardians_reserve"), "Guardian's Reserve spends 20 Resolve after the interception", "%.1f left" % kv.resolve)
	check(ally.shield_hp > sh0 and ally.shield_hp <= ally.max_hp * 0.12 + 0.5, "brief limited protection on the intercepted ally (not healing)")
