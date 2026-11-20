extends "res://tests/test_runner.gd"
## REAVER FREE FLOW (REAVER-FREEFLOW-001): automated FUNCTIONAL checks of the approved spec, section 11.
##   godot --headless --fixed-fps 60 res://tests/freeflow_runner.tscn
## These prove mechanics only. Combat feel must come from human playtesting.

var transitions: Array = []
var trig: Array = []
var dmg: Array = []


func _run_all() -> void:
	Events.blade_transition.connect(func(_h, a, b, legal): transitions.append([a, b, legal]))
	Events.augment_triggered.connect(func(_o, id, d): trig.append([id, d]))
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.source == Game.player: dmg.append(info))
	await test_default_and_progression()
	await test_free_transitions()
	await test_buffer_and_commitment()
	await test_continuation()
	await test_opportunity_from_attacks()
	await test_opportunity_consumption()
	await test_perfect_dodge()
	await test_pursuit_cut()
	await test_pivot_cut()
	await test_decisive_cut()
	await test_transformations()
	await test_augment_pool_and_exclusion()
	await test_compatible_augment()
	await test_save_compatibility()
	await test_comparison_mode()
	await test_hud_and_companion()
	await teardown()


func ff(level: int) -> Hero:
	var h := await setup("reaver", false, false, false)
	Game.reaver_core = "freeflow"
	Game.debug_tainted = false
	Game.set_level("reaver", level)
	Game.prog("reaver").pending_drafts = 0
	Game.prog("reaver").pending_draft_tiers.clear()
	await wait(0.2)
	h.refresh_stats(true)
	h.restore_all()
	h.stats.crit_chance = 0.0
	h.move_input = Vector3.ZERO
	transitions.clear()
	trig.clear()
	dmg.clear()
	return h


func target(h: Hero, dist: float = 2.2, type: String = "raider") -> Enemy:
	var r := dummy(type, h.global_position + Vector3(0, 0, -dist))
	r.max_hp = 99999
	r.hp = 99999
	r.max_poise = 99999
	r.poise = 99999
	face(r, h)
	h.lock_target = r
	face(h, r)
	return r


func fk(h: Hero) -> ReaverFreeFlow:
	return (h.kit as ReaverKit).ff


## Waits until the hero can start the next action (the current attack's cancel window), max `limit`s.
func until_can_act(h: Hero, limit: float = 1.5) -> void:
	var n := 0
	while not h.can_act() and n < int(limit * 60):
		await get_tree().physics_frame
		n += 1


func until_idle(h: Hero, limit: float = 2.0) -> void:
	var n := 0
	while (h.runner.is_busy() or h.dodging) and n < int(limit * 60):
		await get_tree().physics_frame
		n += 1


func cur(h: Hero) -> String:
	return h.runner.data.id if h.runner.is_busy() and h.runner.data else ""


func refill(h: Hero) -> void:
	h.stamina = h.max_stamina
	h.kit.cooldowns.clear()


## Enemy attack that reaches the hero through the real damage pipeline (take_damage).
func enemy_hit(h: Hero, src: Enemy, attack_id: String = "raider_heavy") -> DamageInfo:
	var info := DamageInfo.new()
	info.source = src
	info.target = h
	info.attack = load("res://data/attacks/%s.tres" % attack_id)
	info.attack_name = info.attack.display_name
	info.amount = 10.0
	info.raw_amount = 10.0
	info.poise = 0.0
	info.source_pos = src.global_position
	return h.take_damage(info)


# ------------------------------------------------------------------ default core / progression
func test_default_and_progression() -> void:
	print("\n[Free Flow is the default Reaver core; Level 1-10 track]")
	check(Game.DEFAULT_REAVER_CORE == "freeflow", "the default Reaver core is Free Flow")
	var h := await ff(1)
	var kit: ReaverKit = h.kit
	check(kit.flow_core() and not kit.sword_core(), "Free Flow kit path active")
	var t := Game.track("reaver")
	check(t != null and t.resource_path.ends_with("reaver_freeflow.tres"), "Free Flow uses its own progression track", t.resource_path if t else "null")
	var lv := {}
	for id in ["r_flow_strikes", "r_free_flow", "r_pursuit_cut", "r_pivot_cut", "r_decisive_cut", "r_flow_mastery"]:
		lv[id] = t.unlock_level(id)
	check(lv == {"r_flow_strikes": 1, "r_free_flow": 1, "r_pursuit_cut": 3, "r_pivot_cut": 5, "r_decisive_cut": 7, "r_flow_mastery": 9}, "unlock levels match the spec table (1/1/3/5/7/9)", str(lv))
	var dl: Array = t.draft_levels.keys()
	dl.sort()
	check(dl == [4, 8, 10] and t.draft_levels[8] == "advanced", "existing drafts at 4 / 8 (Advanced) / 10", str(t.draft_levels))
	Game.reaver_core = "swordmaster"
	check(Game.track("reaver").resource_path.ends_with("reaver.tres"), "the Swordmaster track is kept for comparison")
	Game.reaver_core = "freeflow"
	var r := target(h)
	tap(h, "light")
	await wait(0.05)
	check(cur(h) == "ff_strike_1", "Lv1: LMB = Flow Strike", cur(h))
	await until_idle(h)
	await wait(0.8)
	tap(h, "heavy")
	await wait(0.05)
	check(cur(h) == "ff_heavy", "Lv1: RMB = Heavy Cut (no unlock condition, no charge)", cur(h))
	check(kit.charging == "", "Heavy Cut has no charge mechanic")
	await until_idle(h)
	for a in ["skill1", "skill2", "skill3"]:
		tap(h, a)
		await wait(0.05)
		check(not h.runner.is_busy(), "Lv1: %s is locked" % a)
	Game.set_level("reaver", 3)
	await wait(0.1)
	check(kit.unlocked("r_pursuit_cut") and not kit.unlocked("r_pivot_cut"), "Lv3 unlocks Pursuit Cut only")
	Game.set_level("reaver", 7)
	await wait(0.1)
	check(kit.unlocked("r_pivot_cut") and kit.unlocked("r_decisive_cut") and not kit.unlocked("r_flow_mastery"), "Lv7: Pivot (Lv5) and Decisive Cut unlocked, Mastery not yet")
	var lt := load("res://data/attacks/ff_strike_1.tres") as AttackData
	var sm_fw := load("res://data/attacks/rs_forward.tres") as AttackData
	check(lt.startup >= 0.12 and lt.startup <= 0.16 and is_equal_approx(lt.active, 0.1) and lt.recovery >= 0.22 and lt.recovery <= 0.28, "Flow Strike timing inside the spec ranges", "%.2f/%.2f/%.2f" % [lt.startup, lt.active, lt.recovery])
	check(lt.total_time() < sm_fw.total_time() and lt.move_during > 0.0, "Flow Strikes are faster than the Swordmaster Forward Cut and allow movement", "%.2fs vs %.2fs" % [lt.total_time(), sm_fw.total_time()])
	var hv := load("res://data/attacks/ff_heavy.tres") as AttackData
	check(is_equal_approx(hv.startup, 0.32) and is_equal_approx(hv.active, 0.14) and is_equal_approx(hv.recovery, 0.43), "Heavy Cut timing 0.32 / 0.14 / 0.43")
	r.queue_free()


# ------------------------------------------------------------------ free transitions
func test_free_transitions() -> void:
	print("\n[Free-form transitions: any order, no forbidden combination, no NO LINK]")
	var h := await ff(7)
	var r := target(h)
	var seqs := [["light", "light", "heavy", "light"], ["skill1", "light", "skill2", "skill3"], ["heavy", "light", "light", "light"],
		["skill2", "heavy", "skill1", "light"], ["light", "skill3", "light", "skill2"]]
	var expect := {"light": "ff_strike", "heavy": "ff_heavy", "skill1": "ff_pursuit", "skill2": "ff_pivot", "skill3": "ff_decisive"}
	var all_ok := true
	var detail := ""
	for s in seqs:
		await until_idle(h)
		await wait(1.0)
		refill(h)
		h.global_position = r.global_position + Vector3(0, 0, 2.2)
		face(h, r)
		for a in s:
			await until_can_act(h)
			refill(h)
			tap(h, a)
			await wait(0.03)
			var ok := cur(h).begins_with(String(expect[a]))
			if not ok:
				all_ok = false
				detail += "%s -> %s; " % [a, cur(h)]
	check(all_ok, "5 arbitrary orders of Light / Heavy / Pursuit / Pivot / Decisive all start in the previous cancel window", detail)
	check(transitions.is_empty() and not log_has("NO LINK"), "no Blade Lines transition gate and no NO LINK feedback")
	# the three Flow Strike variations rotate; they are equal (not a combo with a finisher)
	await until_idle(h)
	await wait(1.0)
	var ids: Array = []
	for i in 4:
		await until_can_act(h)
		refill(h)
		tap(h, "light")
		await wait(0.03)
		ids.append(cur(h))
	check(ids == ["ff_strike_1", "ff_strike_2", "ff_strike_3", "ff_strike_1"], "three visually distinct Flow Strike variations in rotation", str(ids))
	var a1 := load("res://data/attacks/ff_strike_1.tres") as AttackData
	var a2 := load("res://data/attacks/ff_strike_2.tres") as AttackData
	var a3 := load("res://data/attacks/ff_strike_3.tres") as AttackData
	check(a1.anim_style != a2.anim_style and a2.anim_style != a3.anim_style and a1.anim_style != a3.anim_style, "each variation has its own animation", "%s/%s/%s" % [a1.anim_style, a2.anim_style, a3.anim_style])
	check(a1.damage_mult == a2.damage_mult and a2.damage_mult == a3.damage_mult and a1.poise_damage == a3.poise_damage, "variations are equal in damage (no mandatory 3-hit combo)")
	r.queue_free()


func test_buffer_and_commitment() -> void:
	print("\n[Shared input buffer, recovery-window transitions, committed Heavy]")
	var h := await ff(1)
	var r := target(h)
	tap(h, "light")
	await wait(0.25)            # before the Flow Strike cancel window: the press is buffered
	tap(h, "heavy")
	check(h.buffer_action == "heavy", "a press during the attack is stored by the shared input buffer")
	await wait(0.2)
	check(cur(h) == "ff_heavy", "the buffered Heavy starts in the Flow Strike's recovery cancel window", cur(h))
	await wait(0.1)
	tap(h, "light")             # inside the committed Heavy startup
	await wait(0.1)
	check(cur(h) == "ff_heavy", "a light press cannot cancel the committed Heavy Cut startup")
	await wait(1.0)
	check(cur(h) != "ff_strike_1" or h.runner.t > 0.3, "the stale press expired with the 0.15s buffer instead of firing late")
	r.queue_free()


# ------------------------------------------------------------------ continuation
func test_continuation() -> void:
	print("\n[Flow continuation: grace 0.65s, 0.80s after a dodge, misses expire it]")
	var h := await ff(1)
	var f := fk(h)
	var r := target(h)
	tap(h, "light")
	await until_idle(h)
	check(f.last_connected and f.in_sequence(), "a connecting Flow Strike keeps the sequence open")
	await wait(0.5)
	check(f.in_sequence(), "still open 0.5s after the attack (grace 0.65s)")
	await wait(0.25)
	check(not f.in_sequence(), "expired after the 0.65s grace")
	# dodge preserves it for 0.80s after the dodge ends
	tap(h, "light")
	await until_idle(h)
	h.move_input = Vector3(1, 0, 0)
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await until_idle(h)
	var end := Game.time
	check(f.in_sequence() and f.last_connected, "a dodge inside the sequence does not reset it")
	await wait(0.7)
	check(f.in_sequence(), "still open 0.70s after the dodge (grace 0.80s)", "%.2fs" % (Game.time - end))
	await wait(0.2)
	check(not f.in_sequence(), "expired after the 0.80s post-dodge grace")
	# a missed attack does not reset the sequence, but does not extend it either
	h.global_position = r.global_position + Vector3(0, 0, 2.2)
	face(h, r)
	tap(h, "light")
	await until_idle(h)
	var until0: float = f.flow_until
	h.lock_target = null
	h.face_dir(Vector3(0, 0, 1))      # turn away: the next strike misses
	await wait(0.05)
	tap(h, "light")
	await until_idle(h)
	check(f.flow_until == until0 and not f.last_connected, "a missed attack neither resets nor extends the window")
	tap(h, "light")
	await until_idle(h)
	tap(h, "light")
	await until_idle(h)
	await wait(0.2)
	check(not f.in_sequence(), "repeated misses let the continuation expire naturally")
	r.queue_free()


# ------------------------------------------------------------------ opportunity
func test_opportunity_from_attacks() -> void:
	print("\n[Precision Opportunity from two consecutive connecting attacks]")
	var h := await ff(1)
	var f := fk(h)
	var r := target(h)
	tap(h, "light")
	await until_idle(h)
	check(not f.has_opportunity(), "one connecting attack alone creates no opportunity")
	tap(h, "light")
	await wait(0.3)
	check(f.has_opportunity() and f.opportunities_created == 1, "the second consecutive connecting attack creates one", f.last_reason)
	await until_idle(h)
	tap(h, "light")
	await until_idle(h)
	check(f.opportunities_created == 1 and f.opportunities_refreshed >= 1, "a further connecting attack refreshes it (one maximum, no stacking)", "created %d refreshed %d" % [f.opportunities_created, f.opportunities_refreshed])
	var t0: float = f.opportunity_until
	check(absf(t0 - Game.time - 1.75) < 0.6, "duration about 1.75s", "%.2fs left" % (t0 - Game.time))
	await wait(t0 - Game.time + 0.05)
	check(not f.has_opportunity(), "the opportunity expires naturally if unused")
	# misses never generate it
	await wait(1.0)
	var c0: int = f.opportunities_created + f.opportunities_refreshed
	h.lock_target = null
	h.face_dir(Vector3(0, 0, 1))
	for i in 4:
		await until_can_act(h)
		refill(h)
		tap(h, "light")
	await until_idle(h)
	check(f.opportunities_created + f.opportunities_refreshed == c0 and not f.has_opportunity(), "repeated missed attacks never generate an opportunity")
	# Lv9 Free Flow Mastery: +0.25s
	Game.set_level("reaver", 9)
	await wait(0.1)
	check(is_equal_approx(f.opportunity_duration(), 2.0), "Lv9 Free Flow Mastery extends the duration by 0.25s", "%.2fs" % f.opportunity_duration())
	Game.set_level("reaver", 8)
	await wait(0.1)
	check(is_equal_approx(f.opportunity_duration(), 1.75), "1.75s before Lv9")
	r.queue_free()


func _heavy_hit(h: Hero, r: Enemy) -> DamageInfo:
	dmg.clear()
	h.global_position = r.global_position + Vector3(0, 0, 2.2)
	face(h, r)
	h.lock_target = r
	refill(h)
	tap(h, "heavy")
	await until_idle(h)
	for i in dmg:
		if i.target == r:
			return i
	return null


func test_opportunity_consumption() -> void:
	print("\n[Heavy Cut consumes the opportunity: ~+20% damage, ~+35% Poise; misses still consume]")
	var h := await ff(1)
	var f := fk(h)
	var r := target(h)
	var base := await _heavy_hit(h, r)
	await wait(1.0)
	f.grant("test")
	check(f.has_opportunity(), "opportunity open")
	var lt0: int = f.opportunities_consumed
	tap(h, "light")
	await until_idle(h)
	check(f.opportunities_consumed == lt0, "a Flow Strike does not consume it")
	await wait(0.05)
	var boosted := await _heavy_hit(h, r)
	check(base != null and boosted != null, "both Heavy Cuts connected")
	if base and boosted:
		var dr: float = boosted.raw_amount / base.raw_amount
		var pr: float = boosted.poise / base.poise
		check(absf(dr - 1.2) < 0.02, "consumed Heavy Cut: +20% damage", "x%.3f" % dr)
		check(absf(pr - 1.35) < 0.02, "consumed Heavy Cut: +35% Poise damage", "x%.3f" % pr)
		check(boosted.hitstop > base.hitstop, "consumed Heavy Cut: stronger impact (longer hitstop)", "%.3f vs %.3f" % [boosted.hitstop, base.hitstop])
	check(not f.has_opportunity() and f.opportunities_consumed == lt0 + 1, "consumed exactly once")
	check(not f.has_opportunity(), "the consuming attack does not create a new opportunity from itself")
	# missed consuming attack
	await wait(1.0)
	f.grant("test")
	h.lock_target = null
	h.face_dir(Vector3(0, 0, 1))
	await wait(0.05)
	dmg.clear()
	tap(h, "heavy")
	await until_idle(h)
	check(dmg.is_empty() and not f.has_opportunity(), "a missed consuming Heavy Cut still consumes the opportunity")
	# no duplicated rewards: one opportunity boosts one attack only
	await wait(1.0)
	f.grant("a")
	f.grant("b")
	var b1 := await _heavy_hit(h, r)
	await wait(1.0)
	var b2 := await _heavy_hit(h, r)
	if b1 and b2:
		check(b1.raw_amount > b2.raw_amount * 1.1, "two grants do not stack: only the first Heavy afterwards is boosted", "%.1f vs %.1f" % [b1.raw_amount, b2.raw_amount])
	r.queue_free()


func test_perfect_dodge() -> void:
	print("\n[Perfect Dodge: an actual enemy attack avoided in the i-frames]")
	var h := await ff(1)
	var f := fk(h)
	var r := target(h, 3.0)
	# ordinary dodge, nothing avoided
	h.move_input = Vector3(1, 0, 0)
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(not f.has_opportunity(), "an ordinary dodge (nothing avoided) creates no opportunity")
	await wait(0.5)
	# attack inside the i-frames
	h.try_dodge()
	await wait(0.08)
	check(h.is_invulnerable(), "inside the dodge i-frames")
	var hp0 := h.hp
	var info := enemy_hit(h, r)
	check(info.dodged and h.hp == hp0, "the enemy attack was avoided by the i-frames (no damage)")
	check(f.has_opportunity() and f.last_reason.begins_with("Perfect Dodge"), "Perfect Dodge creates a Precision Opportunity", f.last_reason)
	var n0: int = f.opportunities_created + f.opportunities_refreshed
	enemy_hit(h, r)                      # the same attack event (multi-hit / repeated contact)
	enemy_hit(h, r, "raider_combo1")      # another attack during the same dodge
	check(f.opportunities_created + f.opportunities_refreshed == n0, "one dodge never grants repeated opportunities", "%d -> %d" % [n0, f.opportunities_created + f.opportunities_refreshed])
	await until_idle(h)
	await wait(2.2)
	check(not f.has_opportunity(), "(expired)")
	# hit outside the i-frames: not a Perfect Dodge
	h.try_dodge()
	var nf := 0
	while h.dodging and (h.dodge_t < 0.1 or h.is_invulnerable()) and nf < 60:
		await get_tree().physics_frame
		nf += 1
	check(h.dodging and not h.is_invulnerable(), "late in the dodge, after the (Reaver x1.2) i-frames", "t=%.2fs" % h.dodge_t)
	var late := enemy_hit(h, r)
	check(not late.dodged and not f.has_opportunity(), "an attack outside the i-frames is not a Perfect Dodge")
	await until_idle(h)
	# Perfect Dodge -> Heavy consumes it
	await wait(0.5)
	h.try_dodge()
	await wait(0.08)
	enemy_hit(h, r)
	await until_idle(h)
	var c0: int = f.opportunities_consumed
	h.global_position = r.global_position + Vector3(0, 0, 2.2)
	face(h, r)
	tap(h, "heavy")
	await wait(0.05)
	check(f.opportunities_consumed == c0 + 1 and h.runner.ctx.get("consumed", false), "Perfect Dodge -> Heavy Cut consumes the opportunity")
	r.queue_free()


# ------------------------------------------------------------------ skills
func test_pursuit_cut() -> void:
	print("\n[Pursuit Cut: gap closer, cooldown 5s, stamina, collision, no homing]")
	var h := await ff(3)
	var r := target(h, 5.0)
	var p0 := h.global_position
	var st0 := h.stamina
	tap(h, "skill1")
	await wait(0.03)
	check(cur(h) == "ff_pursuit", "1 = Pursuit Cut", cur(h))
	check(absf(st0 - h.stamina - 16.0) < 0.5, "stamina cost (16)", "%.1f" % (st0 - h.stamina))
	check(absf(h.kit.skill_cd("r_pursuit_cut") - 5.0) < 0.1, "5s cooldown started")
	var hp0 := r.hp
	await until_idle(h)
	var moved := Vector2(h.global_position.x - p0.x, h.global_position.z - p0.z).length()
	check(moved >= 2.0 and moved <= 3.6, "closes a moderate distance (2-3.6m)", "%.2fm" % moved)
	check(r.hp < hp0, "the strike connects after closing the gap")
	var gap := Vector2(h.global_position.x - r.global_position.x, h.global_position.z - r.global_position.z).length()
	check(gap > 0.5, "stops at the enemy body (collision), never passes through it", "%.2fm" % gap)
	tap(h, "skill1")
	await wait(0.05)
	check(cur(h) != "ff_pursuit", "cannot be used again during its cooldown")
	await wait(5.0)
	# no homing: the direction is fixed when the skill starts
	h.global_position = r.global_position + Vector3(0, 0, 5)
	face(h, r)
	refill(h)
	tap(h, "skill1")
	await wait(0.02)
	r.global_position += Vector3(3.0, 0, 0)     # the enemy moves aside after the rush started
	await until_idle(h)
	check(absf(h.global_position.x - (r.global_position.x - 3.0)) < 0.35, "the rush keeps its start direction (no homing onto a moving enemy)", "x drift %.2f" % (h.global_position.x - (r.global_position.x - 3.0)))
	# walls
	r.queue_free()
	await wait(0.2)
	h.teleport(Vector3(28.0, 0.2, 0.0))
	h.lock_target = null
	h.face_dir(Vector3(1, 0, 0))
	await wait(0.2)
	for i in 3:
		refill(h)
		tap(h, "skill1")
		await until_idle(h)
	var q := PhysicsPointQueryParameters3D.new()
	q.position = h.global_position + Vector3(0, 0.9, 0)
	q.collision_mask = Combatant.LAYER_WORLD
	check(h.get_world_3d().direct_space_state.intersect_point(q).is_empty(), "repeated Pursuit Cuts into a wall never push the Reaver inside geometry")


func test_pivot_cut() -> void:
	print("\n[Pivot Cut: directional step + slash, cooldown 4s, NO i-frames, flank opportunity]")
	var h := await ff(5)
	var f := fk(h)
	var r := target(h, 2.2)
	var p0 := h.global_position
	h.move_input = Vector3(1, 0, 0)
	var st0 := h.stamina
	tap(h, "skill2")
	await wait(0.02)
	check(cur(h) == "ff_pivot", "2 = Pivot Cut", cur(h))
	check(absf(st0 - h.stamina - 16.0) < 0.5 and absf(h.kit.skill_cd("r_pivot_cut") - 4.0) < 0.1, "stamina cost (16) and 4s cooldown")
	var inv := false
	var hp_before := h.hp
	var took := false
	for i in 30:
		inv = inv or h.is_invulnerable()
		if i == 10:
			var info := enemy_hit(h, r, "raider_combo1")
			took = not info.dodged and h.hp < hp_before
		await get_tree().physics_frame
	h.move_input = Vector3.ZERO
	check(not inv and took, "Pivot Cut grants no invulnerability (an enemy hit during it lands)")
	await until_idle(h)
	var step := h.global_position - p0
	check(step.x > 0.4 and step.x < 1.0, "steps toward the movement input (~0.7m)", "%.2fm" % step.x)
	await wait(4.2)
	p0 = h.global_position
	refill(h)
	tap(h, "skill2")
	await until_idle(h)
	var back := (h.global_position - p0).dot(-(r.global_position - p0).normalized())
	check(back > 0.3, "without input: conservative backward reposition", "%.2fm back" % back)
	# flank: enemy facing away 90 degrees -> opportunity
	await wait(4.2)
	await wait(1.0)
	r.global_position = h.global_position + Vector3(0, 0, -2.0)
	r.face_dir(Vector3(1, 0, 0))
	h.lock_target = r
	face(h, r)
	f.opportunity_until = -10.0
	f.flow_until = -10.0
	refill(h)
	h.move_input = Vector3(-1, 0, 0)     # step further round the flank
	tap(h, "skill2")
	await wait(0.05)
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(f.has_opportunity() and f.last_reason.begins_with("Pivot Cut"), "Pivot Cut connecting from 60+ deg off the enemy's facing creates an opportunity", f.last_reason)
	# frontal: no positional opportunity
	await wait(4.2)
	await wait(2.2)
	face(r, h)
	f.opportunity_until = -10.0
	f.flow_until = -10.0
	refill(h)
	var hp1 := r.hp
	h.move_input = Vector3(1, 0, 0)
	tap(h, "skill2")
	await wait(0.05)
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(r.hp < hp1 and not f.has_opportunity(), "a frontal Pivot Cut hit creates no positional opportunity")
	r.queue_free()


func test_decisive_cut() -> void:
	print("\n[Decisive Cut: Lv7, cooldown 8s, high stamina, works with and without an opportunity]")
	var h := await ff(7)
	var f := fk(h)
	var r := target(h)
	var st0 := h.stamina
	dmg.clear()
	tap(h, "skill3")
	await wait(0.03)
	check(cur(h) == "ff_decisive" and not h.runner.ctx.get("consumed", true), "3 = Decisive Cut, usable without an opportunity")
	check(absf(st0 - h.stamina - 25.0) < 0.5 and absf(h.kit.skill_cd("r_decisive_cut") - 8.0) < 0.1, "high stamina cost (25) and 8s cooldown")
	await until_idle(h)
	var base: DamageInfo = dmg[0] if not dmg.is_empty() else null
	check(base != null and base.raw_amount > 0.0, "the base Decisive Cut connects")
	var d := load("res://data/attacks/ff_decisive.tres") as AttackData
	var lt := load("res://data/attacks/ff_strike_1.tres") as AttackData
	check(d.recovery > lt.recovery and d.total_time() > lt.total_time(), "more commitment and recovery than Flow Strikes")
	check(d.stagger_on_hit == 0.0 and d.crit_chance_bonus == 0.0 and h.kit.situational_crit(d, r, {}) == 0.0, "no automatic stagger and no guaranteed / bonus crit")
	check(d.startup <= (load("res://data/attacks/ff_heavy.tres") as AttackData).startup, "not slower to start than Heavy Cut")
	await wait(8.2)
	f.grant("test")
	refill(h)
	dmg.clear()
	tap(h, "skill3")
	await wait(0.03)
	check(h.runner.ctx.get("consumed", false) and not f.has_opportunity(), "with an opportunity: Decisive Cut consumes it")
	await until_idle(h)
	if base and not dmg.is_empty():
		check(absf(dmg[0].raw_amount / base.raw_amount - 1.2) < 0.02 and absf(dmg[0].poise / base.poise - 1.35) < 0.02, "consumed Decisive Cut: +20% damage, +35% Poise", "x%.3f / x%.3f" % [dmg[0].raw_amount / base.raw_amount, dmg[0].poise / base.poise])
	r.queue_free()


# ------------------------------------------------------------------ augments
func test_transformations() -> void:
	print("\n[Decisive Cut transformations change the actual attack]")
	var h := await ff(8)
	var f := fk(h)
	var r := target(h)
	Game.add_augment("reaver", "precision_edge")
	h.stats.crit_chance = 0.0      # add_augment refreshes stats: keep crits off for ratio checks
	await wait(0.1)
	refill(h)
	tap(h, "skill3")
	await wait(0.03)
	var base := load("res://data/attacks/ff_decisive.tres") as AttackData
	var d: AttackData = h.runner.data
	check(d.display_name == "Precision Edge" and d.anim_style == "thrust" and d.hitbox_size.x < base.hitbox_size.x * 0.6 and d.poise_damage > base.poise_damage, "Precision Edge: single narrow thrust, higher Poise", "w %.2f poise %.0f" % [d.hitbox_size.x, d.poise_damage])
	await until_idle(h)
	# positional reward: from the flank
	await wait(8.2)
	dmg.clear()
	refill(h)
	face(r, h)
	tap(h, "skill3")
	await until_idle(h)
	var front: DamageInfo = dmg[0] if not dmg.is_empty() else null
	await wait(8.2)
	r.face_dir(Vector3(1, 0, 0))
	dmg.clear()
	refill(h)
	face(h, r)
	tap(h, "skill3")
	await until_idle(h)
	var flank: DamageInfo = dmg[0] if not dmg.is_empty() else null
	if front and flank:
		check(flank.tags.get("positioned", false) and absf(flank.raw_amount / front.raw_amount - 1.2) < 0.02, "Precision Edge rewards the flank (+20%)", "x%.3f" % (flank.raw_amount / front.raw_amount))
	else:
		check(false, "Precision Edge hits connected")
	Game.remove_augment("reaver", "precision_edge")
	# Tempest Edge
	Game.add_augment("reaver", "tempest_edge")
	h.stats.crit_chance = 0.0      # add_augment refreshes stats: keep crits off for ratio checks
	face(r, h)
	await wait(8.2)
	refill(h)
	dmg.clear()
	tap(h, "skill3")
	await wait(0.03)
	d = h.runner.data
	check(d.display_name == "Tempest Edge" and d.hits == 4 and is_equal_approx(d.hit_weights[3], 0.55) and d.total_time() > base.total_time(), "Tempest Edge: 4 rapid hits, final hit 55%, longer commitment")
	await until_idle(h)
	var on_r := dmg.filter(func(i): return i.target == r)
	check(on_r.size() == 4 and on_r[3].raw_amount > on_r[0].raw_amount * 3.0, "all four hits land; the final hit carries the most damage", "%d hits" % on_r.size())
	# group arc: two enemies side by side
	var r2 := dummy("raider", r.global_position + Vector3(1.0, 0, 0))
	r2.max_hp = 99999
	r2.hp = 99999
	await wait(8.2)
	refill(h)
	dmg.clear()
	face(h, r)
	tap(h, "skill3")
	await until_idle(h)
	var hit_targets := {}
	for i in dmg:
		hit_targets[i.target] = true
	check(hit_targets.size() >= 2, "Tempest Edge connects against nearby enemies in its arc", "%d targets" % hit_targets.size())
	r2.queue_free()
	Game.remove_augment("reaver", "tempest_edge")
	# Momentum Edge
	Game.add_augment("reaver", "momentum_edge")
	h.stats.crit_chance = 0.0      # add_augment refreshes stats: keep crits off for ratio checks
	await wait(8.2)
	h.global_position = r.global_position + Vector3(0, 0, 4.0)
	h.lock_target = null
	face(h, r)
	refill(h)
	var p0 := h.global_position
	tap(h, "skill3")
	await wait(0.03)
	d = h.runner.data
	check(d.display_name == "Momentum Edge", "Momentum Edge: Decisive Cut becomes a moving strike")
	await until_idle(h)
	var mv := (h.global_position - p0).length()
	check(mv > 1.0, "controlled forward rush (collision-bound)", "%.2fm" % mv)
	await wait(8.2)
	h.global_position = r.global_position + Vector3(0, 0, 3.0)
	face(h, r)
	refill(h)
	h.move_input = Vector3(1, 0, 0)      # badly aimed: rush sideways
	var hp0 := r.hp
	tap(h, "skill3")
	await wait(0.05)
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(r.hp == hp0, "a badly aimed Momentum Edge misses")
	Game.remove_augment("reaver", "momentum_edge")
	r.queue_free()


func test_augment_pool_and_exclusion() -> void:
	print("\n[Draft integration, mutual exclusion, incompatible Swordmaster augments]")
	var h := await ff(8)
	var p := Game.prog("reaver")
	var pool: Array = Game.augment_db.eligible("reaver", p).map(func(a): return a.id)
	pool.sort()
	check(pool == ["momentum_edge", "precision_edge", "sundering_verdict", "tempest_edge"], "Free Flow Lv8 pool: the three transformations + the compatible Sundering Verdict", str(pool))
	Game.set_level("reaver", 6)
	await wait(0.1)
	var pool6: Array = Game.augment_db.eligible("reaver", p).map(func(a): return a.id)
	check(not pool6.has("precision_edge"), "transformations need Decisive Cut (Lv7)", str(pool6))
	Game.set_level("reaver", 8)
	await wait(0.1)
	for id in ["crosswind", "drawn_horizon", "flowing_edge", "measured_step", "needlepoint", "turning_steel", "unbroken_line"]:
		var a: AugmentData = Game.augment_db.get_augment(id)
		var why := Game.augment_db.ineligible_reason(a, p)
		check(why != "" and Game.augment_db.freeflow_inactive(a), "%s marked incompatible with Free Flow and never drafted" % id, why)
	for id in ["rising_crescent", "splintering_steel", "one_perfect_cut", "ghost_step", "execution_line"]:
		check(Game.augment_db.ineligible_reason(Game.augment_db.get_augment(id), p) != "", "legacy / retired-core augment %s never drafted under Free Flow" % id)
	Game.add_augment("reaver", "precision_edge")
	h.stats.crit_chance = 0.0      # add_augment refreshes stats: keep crits off for ratio checks
	var reason := Game.augment_db.ineligible_reason(Game.augment_db.get_augment("tempest_edge"), p)
	check(reason == "excluded by precision_edge", "owning one transformation excludes the others from drafts", reason)
	Game.add_augment("reaver", "momentum_edge")
	h.stats.crit_chance = 0.0      # add_augment refreshes stats: keep crits off for ratio checks
	check(p.augment_stacks("momentum_edge") == 0 and p.augment_stacks("precision_edge") == 1, "a second transformation can never be added to the same character")
	check(f_transform(h) == "precision_edge", "the kit uses the single owned transformation")
	Game.remove_augment("reaver", "precision_edge")
	# random drafts never guarantee a specific transformation
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var missing := {"precision_edge": 0, "tempest_edge": 0, "momentum_edge": 0}
	for i in 200:
		var ids: Array = Game.augment_db.roll("reaver", p, Game.balance.draft_choices, rng, "advanced").map(func(a): return a.id)
		for k in missing:
			if not ids.has(k):
				missing[k] += 1
	check(missing.values().min() > 0, "ordinary drafts do not guarantee any specific transformation", str(missing))
	check(Game.balance.max_equipped_mutations == 3 and (Game.augment_db.get_augment("tempest_edge") as AugmentData).category == "mutation", "transformations obey the existing Major Mutation limit")


func f_transform(h: Hero) -> String:
	return fk(h).transform()


func test_compatible_augment() -> void:
	print("\n[Compatible augment keeps working under Free Flow: Sundering Verdict on Heavy Cut]")
	var h := await ff(4)
	var g := dummy("shield_guardian", h.global_position + Vector3(0, 0, -2.2))
	g.max_hp = 99999
	g.hp = 99999
	face(g, h)
	h.lock_target = g
	face(h, g)
	Game.add_augment("reaver", "sundering_verdict")
	tap(h, "heavy")
	await wait(1.4)
	check(g.statuses.has("sundered"), "Sundering Verdict: Heavy Cut on the raised guard weakens it")
	g.queue_free()


# ------------------------------------------------------------------ saves
func test_save_compatibility() -> void:
	print("\n[Existing Swordmaster-era Reaver saves load and play safely under Free Flow]")
	var path := fixture_path("ff_compat_save.json")
	clear_fixture(path)
	var old_path: String = Save.path
	Save.path = path
	Save.enabled = true
	var rv := {"class_id": "reaver", "created": true, "name": "Old Blade", "level": 2, "xp": 40, "total_exp": 120, "augments": ["needlepoint"],
		"inactive_mutations": [], "pending_drafts": 0, "pending_draft_tiers": [], "drafts_taken": 0, "free_points": 1,
		"allocated": {"str": 2, "dex": 1, "vit": 0, "for": 0, "mas": 0}, "life_number": 1, "seen_unlocks": ["r_blade_lines", "r_continuity", "stats_2"],
		"equipment": {"weapon": "starter_r_sword"}, "inventory": ["r_crimson_blade"], "reaver_loadout": ["r_lunge", "r_flow_step", "", ""], "play_time": 300.0}
	var doc := {"version": 1, "last_class": "reaver", "characters": {"reaver": rv}}
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(doc))
	fa.close()
	check(Save.validate_save(doc) == "", "the Swordmaster-era save passes the unchanged validator")
	Game.reaver_core = "freeflow"
	Save.load_game()
	var p := Game.prog("reaver")
	check(p.level == 2 and p.allocated.str == 2 and p.allocated.dex == 1 and p.free_points == 1, "level and attributes preserved")
	check(p.equipment.get("weapon", "") == "starter_r_sword" and p.inventory == ["r_crimson_blade"], "equipment and inventory preserved")
	check(p.augments == ["needlepoint"] and p.reaver_loadout == ["r_lunge", "r_flow_step", "", ""], "obsolete Swordmaster augment / loadout references kept untouched")
	Save.enabled = false
	Game.active_class = "reaver"
	await teardown()
	world = load("res://scenes/world/ashen_valley.tscn").instantiate()
	add_child(world)
	Game.start_session(world, "reaver", false)
	Game.player.global_position = Vector3(0, 0.2, 26)
	await wait(0.3)
	var h: Hero = Game.player
	var r := target(h)
	var hp0 := r.hp
	tap(h, "light")
	await wait(0.4)
	tap(h, "light")
	await wait(0.6)
	tap(h, "skill1")
	await wait(0.6)
	check(r.hp < hp0 and h.kit.flow_core(), "the Level 2 Reaver plays Free Flow normally", "%.0f dmg" % (hp0 - r.hp))
	check(p.reaver_loadout == ["r_lunge", "r_flow_step", "", ""], "playing Free Flow never rewrites the Swordmaster loadout")
	check(p.level == 2 and p.created, "the character was not reset")
	Save.enabled = true
	var ok := Save.save_game()
	var fr := FileAccess.open(path, FileAccess.READ)
	var back = JSON.parse_string(fr.get_as_text())
	fr.close()
	check(ok and back is Dictionary and Save.validate_save(back) == "" and back.characters.reaver.level == 2 and back.characters.reaver.inventory == ["r_crimson_blade"], "re-saved under Free Flow: valid, nothing lost")
	Save.enabled = false
	Save.path = old_path
	clear_fixture(path)
	r.queue_free()


func test_comparison_mode() -> void:
	print("\n[Human comparison mode: Swordmaster / Sword Sense from the Debug Panel, never saved]")
	var h := await ff(3)
	var r := target(h)
	Game.debug_tainted = false
	Game.set_core("reaver", "swordmaster")
	check(Game.debug_tainted, "switching to the Swordmaster comparison core makes the session non-saving")
	check(Save.save_game() == false, "nothing can be written while comparing")
	await wait(0.1)
	tap(h, "light")
	await wait(0.05)
	check(cur(h) == "rs_forward", "Swordmaster (Blade Lines) still plays for comparison", cur(h))
	await until_idle(h)
	await wait(0.6)
	Game.set_core("reaver", "sense")
	await wait(0.1)
	tap(h, "light")
	await wait(0.05)
	check(cur(h).begins_with("r_light"), "Sword Sense still accessible for technical comparison", cur(h))
	await until_idle(h)
	await wait(0.6)
	Game.set_core("reaver", "freeflow")
	await wait(0.1)
	tap(h, "light")
	await wait(0.05)
	check(cur(h).begins_with("ff_strike"), "back to Free Flow", cur(h))
	Game.debug_tainted = false
	Game.set_core("reaver", "freeflow")
	check(not Game.debug_tainted, "selecting Free Flow (the default) does not taint the session")
	r.queue_free()


func test_hud_and_companion() -> void:
	print("\n[HUD skill bar (no meter) and the Free Flow Party companion, in the real main scene]")
	await teardown()
	Game.reset_all_progress()
	for c in Game.CLASSES:
		Game.prog(c).created = true
	Game.reaver_core = "freeflow"
	Game.mage_core = "elementalist"
	Game.debug_tainted = false
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.2)
	main.start_game("reaver", false)
	Game.set_level("reaver", 7)
	Game.prog("reaver").pending_drafts = 0
	Game.prog("reaver").pending_draft_tiers.clear()
	await wait(0.6)
	var hud = main.find_child("HUD", true, false)
	check(hud != null and hud.slots.has("skill1") and hud.slots.has("skill2") and hud.slots.has("skill3") and hud.slots.has("heavy"), "HUD shows the existing skill bar: LMB / RMB / 1 Pursuit / 2 Pivot / 3 Decisive / Space", str(hud.slots.keys()) if hud else "no HUD")
	if hud:
		check(not hud.slots.has("core") and not hud.slots.has("life"), "no extra Free Flow slot or meter on E / F")
		check(hud.slots.skill1.locked_level == 0 and hud.slots.skill3.locked_level == 0, "Lv7: skill slots unlocked on the HUD")
	var seen := {}
	var cb := func(d, _ctx): seen[d.id] = true
	# Party companion: a Vanguard player with a Free Flow Reaver AI
	main.return_to_menu()
	await wait(0.3)
	Game.reaver_core = "freeflow"
	main.start_game("vanguard", true)
	await wait(0.5)
	var comp: Hero = null
	for h in Game.heroes:
		if is_instance_valid(h) and h.class_id == "reaver" and not h.is_player:
			comp = h
	check(comp != null and comp.kit.flow_core(), "the Reaver Party companion runs Free Flow")
	if comp:
		comp.runner.started.connect(cb)
		var e := Game.spawn_enemy("raider", comp.global_position + Vector3(0, 0, -3.0))
		e.max_hp = 99999
		e.hp = 99999
		await wait(6.0)
		var ff_ids := seen.keys().filter(func(k): return String(k).begins_with("ff_"))
		check(not ff_ids.is_empty(), "the companion fights with Free Flow attacks", str(seen.keys()))
		if is_instance_valid(e):
			e.queue_free()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Game.end_session()