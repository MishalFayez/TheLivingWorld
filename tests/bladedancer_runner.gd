extends "res://tests/freeflow_runner.gd"
## REAVER — BLADE DANCER (REAVER-BLADEDANCER-003): focused FUNCTIONAL checks (spec section 14).
##   godot --headless --fixed-fps 60 res://tests/bladedancer_runner.tscn
## Mechanics only. Combat feel and "how differently the player can fight" need human playtesting.


func _run_all() -> void:
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.source == Game.player: dmg.append(info))
	await test_default_and_progression()
	await test_dance_directions()
	await test_dance_collision()
	await test_edge_mode_and_inputs()
	await test_tap_vs_hold()
	await test_mode_transitions()
	await test_no_duplication()
	await test_commitment()
	await test_combat_weave()
	await test_footwork_techniques()
	await test_offense_techniques()
	await test_technique_differences()
	await test_mastery()
	await test_stamina()
	await test_augments()
	await test_existing_character()
	await test_legacy_cores()
	await test_other_classes()
	await test_startup_and_hud()
	await teardown()


# ------------------------------------------------------------------ helpers
func bd(level: int) -> Hero:
	var h := await setup("reaver", false, false, false)
	Game.reaver_core = "bladedancer"
	Game.debug_tainted = false
	Game.set_level("reaver", level)
	Game.prog("reaver").pending_drafts = 0
	Game.prog("reaver").pending_draft_tiers.clear()
	await wait(0.2)
	h.refresh_stats(true)
	h.restore_all()
	h.stats.crit_chance = 0.0
	# the headless PlayerBrain rewrites move_input every frame from the (absent) keyboard: switch it off so
	# scripted movement input stays applied during an attack
	for c in h.get_children():
		if c is PlayerBrain:
			c.set_physics_process(false)
	h.move_input = Vector3.ZERO
	dmg.clear()
	return h


func bk(h: Hero) -> ReaverBladeDancer:
	return (h.kit as ReaverKit).bd


func flat(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func flat_v(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func hit_on(r) -> DamageInfo:
	for i in dmg:
		if i.target == r:
			return i
	return null


func place(h: Hero, r: Enemy, dist: float) -> void:
	h.global_position = r.global_position + Vector3(0, 0, dist)
	h.velocity = Vector3.ZERO
	h.knock_velocity = Vector3.ZERO
	h.lock_target = r
	face(h, r)


## Taps an action with a movement input held, waits until the attack ends, returns the displacement.
func act(h: Hero, action: String, input: Vector3 = Vector3.ZERO) -> Vector3:
	var p0 := h.global_position
	h.move_input = input
	tap(h, action)
	await wait(0.03)
	await until_idle(h)
	h.move_input = Vector3.ZERO
	await wait(0.3)
	return h.global_position - p0


func enemy_swing(r: Enemy, startup: float, recovery: float) -> void:
	var d := AttackData.new()
	d.id = "test_swing"
	d.startup = startup
	d.active = 0.05
	d.recovery = recovery
	d.hits = 0
	r.runner.start(d, {})


# ------------------------------------------------------------------ 0. default / progression
func test_default_and_progression() -> void:
	print("\n[Blade Dancer is the default Reaver core; Level 1-10 prototype track]")
	check(Game.DEFAULT_REAVER_CORE == "bladedancer", "default Reaver core = Blade Dancer")
	var h := await bd(1)
	var kit: ReaverKit = h.kit
	check(kit.dancer_core() and not kit.flow_core(), "Blade Dancer kit path active")
	var t := Game.track("reaver")
	check(t != null and t.resource_path.ends_with("reaver_bladedancer.tres"), "own progression track", t.resource_path if t else "")
	var lv := {}
	for id in ["bd_dance", "bd_edge", "bd_weave", "bd_footwork", "bd_offense", "bd_mastery"]:
		lv[id] = t.unlock_level(id)
	check(lv == {"bd_dance": 1, "bd_edge": 1, "bd_weave": 1, "bd_footwork": 3, "bd_offense": 5, "bd_mastery": 7}, "unlock levels 1 / 1 / 1 / 3 / 5 / 7", str(lv))
	var dl: Array = t.draft_levels.keys()
	dl.sort()
	check(dl == [4, 8, 10] and t.milestone("stats_2").get("level", 0) == 2 and t.milestone("stats_6").get("level", 0) == 6, "drafts 4 / 8 / 10, attributes 2 / 6")
	var r := target(h)
	tap(h, "footwork")
	await wait(0.05)
	check(not h.runner.is_busy(), "Lv1: Q locked")
	tap(h, "core")
	await wait(0.05)
	check(not h.runner.is_busy(), "Lv1: E locked")
	for a in ["skill1", "skill2", "skill3"]:
		tap(h, a)
		await wait(0.03)
	check(not h.runner.is_busy(), "keys 1 / 2 / 3 do nothing (not needed)")
	Game.set_level("reaver", 3)
	await wait(0.1)
	check(kit.unlocked("bd_footwork") and not kit.unlocked("bd_offense"), "Lv3 unlocks Q only")
	Game.set_level("reaver", 5)
	await wait(0.1)
	check(kit.unlocked("bd_offense") and not kit.unlocked("bd_mastery"), "Lv5 unlocks E, mastery not yet")
	r.queue_free()


# ------------------------------------------------------------------ 1. Dance
func test_dance_directions() -> void:
	print("\n[Dance: neutral / forward (W) / lateral (A, D) change the attack and the real position]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h, 4.0)
	var toward := (r.global_position - h.global_position).normalized()
	var right := toward.cross(Vector3.UP).normalized()
	# neutral
	place(h, r, 2.0)
	var mv := await act(h, "light")
	check(f.last_attack == "dance_neutral", "LMB without input = Neutral Dance", f.last_attack)
	check(flat_v(mv) < 0.35, "minimal displacement", "%.2fm" % flat_v(mv))
	var dn := load("res://data/attacks/bd_dance_neutral.tres") as AttackData
	var dfw := load("res://data/attacks/bd_dance_forward.tres") as AttackData
	var dla := load("res://data/attacks/bd_dance_lateral.tres") as AttackData
	check(is_equal_approx(dn.startup, 0.12) and is_equal_approx(dfw.startup, 0.14) and is_equal_approx(dla.startup, 0.15), "startups 0.12 / 0.14 / 0.15")
	check(dn.recovery >= 0.22 and dn.recovery <= 0.28 and dfw.recovery >= 0.22 and dfw.recovery <= 0.28 and dla.recovery >= 0.22 and dla.recovery <= 0.28, "Dance recovery inside 0.22-0.28s")
	# forward (target far enough not to collide)
	place(h, r, 4.0)
	await wait(0.3)
	mv = await act(h, "light", toward)
	check(f.last_attack == "dance_forward", "W + LMB = Forward Dance", f.last_attack)
	var fwd := mv.dot(toward)
	check(fwd >= 1.1 and fwd <= 1.45, "visible forward travel ~1.3m with room to close (004; 003 was 0.9m)", "%.2fm" % fwd)
	# lateral right / left
	place(h, r, 2.2)
	await wait(0.3)
	var d0 := flat(h, r)
	mv = await act(h, "light", right)
	check(f.last_attack == "dance_lateral", "D + LMB = Lateral Dance", f.last_attack)
	var lat := mv.dot(right)
	check(lat >= 0.85 and lat <= 1.15, "lateral travel ~1.0m (004; 003 was ~0.65m)", "%.2fm" % lat)
	check(absf(flat(h, r) - d0) < 0.35, "the sidestep changes the angle, not the range", "%.2f -> %.2fm" % [d0, flat(h, r)])
	place(h, r, 2.2)
	await wait(0.3)
	tap_dir(h, -right)
	await wait(0.03)
	var anim_l: String = h.runner.data.anim_style if h.runner.is_busy() else ""
	await until_idle(h)
	await wait(0.3)
	place(h, r, 2.2)
	tap_dir(h, right)
	await wait(0.03)
	var anim_r: String = h.runner.data.anim_style if h.runner.is_busy() else ""
	await until_idle(h)
	check(anim_l == "bd_lateral_l" and anim_r == "bd_lateral_r", "left and right have mirrored motions", "%s / %s" % [anim_l, anim_r])
	var styles := {dn.anim_style: 1, dfw.anim_style: 1, "bd_lateral_l": 1, "bd_lateral_r": 1}
	check(styles.size() == 4, "neutral / forward / lateral motions all differ")
	# repeated directions are legal
	await wait(0.5)
	place(h, r, 2.0)
	var all_ok := true
	var seq := []
	for i in 4:
		await until_can_act(h)
		refill(h)
		var tr := (r.global_position - h.global_position).normalized()
		h.move_input = tr.cross(Vector3.UP).normalized()     # "D" relative to the target each time
		tap(h, "light")
		await wait(0.02)
		seq.append(f.last_attack if h.runner.is_busy() else "none")
		all_ok = all_ok and h.runner.is_busy() and f.last_attack == "dance_lateral"
		h.move_input = Vector3.ZERO
	check(all_ok, "the same direction four times in a row is always legal", str(seq))
	await until_idle(h)
	check(h.kit.situational_crit(dn, r, {}) == 0.0 and dn.crit_chance_bonus == 0.0 and dla.crit_chance_bonus == 0.0, "no critical bonus for choosing a direction")
	r.queue_free()


func tap_dir(h: Hero, input: Vector3) -> void:
	h.move_input = input
	tap(h, "light")
	h.move_input = Vector3.ZERO


func test_dance_collision() -> void:
	print("\n[Dance movement respects collision; no teleport]")
	var h := await bd(1)
	var r := target(h, 1.4)
	var toward := (r.global_position - h.global_position).normalized()
	place(h, r, 1.4)
	var mx := 0.0
	var last := h.global_position
	h.move_input = toward
	tap(h, "light")
	for i in 30:
		await get_tree().physics_frame
		mx = maxf(mx, (h.global_position - last).length())
		last = h.global_position
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check(flat(h, r) > 0.55, "Forward Dance into an adjacent enemy stops at its body", "%.2fm" % flat(h, r))
	check(mx < 0.25, "continuous motion (largest frame step)", "%.3fm" % mx)
	# lateral into a body
	var b := dummy("raider", h.global_position + toward.cross(Vector3.UP).normalized() * 0.9)
	await wait(0.3)
	var p0 := h.global_position
	var right := toward.cross(Vector3.UP).normalized()
	h.move_input = right
	tap(h, "light")
	await wait(0.03)
	h.move_input = Vector3.ZERO
	await until_idle(h)
	check((h.global_position - p0).dot(right) < 0.45, "Lateral Dance into a body is stopped by it", "%.2fm" % (h.global_position - p0).dot(right))
	b.queue_free()
	r.queue_free()


# ------------------------------------------------------------------ 3. Edge
func test_edge_mode_and_inputs() -> void:
	print("\n[Edge: hold RMB enters, release returns; holding costs no stamina]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h)
	h.press("heavy")
	await wait(0.05)
	check(f.in_edge(), "holding RMB (idle) enters Edge immediately")
	var st0 := h.stamina
	await wait(1.0)
	check(is_equal_approx(h.stamina, st0) and not h.runner.is_busy(), "holding RMB alone costs no stamina and attacks nothing")
	check(h.anim.current_animation == ReaverBladeDancer.STANCE_ANIM, "Edge has its own stance pose")
	h.release("heavy")
	await wait(0.05)
	check(not f.in_edge(), "releasing RMB returns to Dance")
	check(not h.runner.is_busy(), "releasing RMB fires nothing")
	r.queue_free()


func test_tap_vs_hold() -> void:
	print("\n[Edge LMB: tap = Precision Cut, hold >= 0.35s + release = Committed Cut]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	h.press("light")
	await wait(0.05)
	h.release("light")
	await wait(0.02)
	check(f.last_attack == "precision", "tap = Precision Cut", f.last_attack)
	var pc: AttackData = h.runner.data
	check(absf(pc.startup - 0.18) < 0.001, "Precision startup 0.18s after release (confirmation)")
	await until_idle(h)
	var hp_pc := hit_on(r)
	await wait(0.4)
	h.press("light")
	await wait(0.2)
	h.release("light")
	await wait(0.02)
	check(f.last_attack == "precision", "0.2s is still a tap (threshold 0.35s)")
	await until_idle(h)
	await wait(0.4)
	refill(h)
	dmg.clear()
	h.press("light")
	await wait(0.2)
	check(not h.runner.is_busy() and h.kit.charging == "edge_lmb", "while LMB is held the strike is being prepared (nothing fires yet)")
	await wait(0.3)
	h.release("light")
	await wait(0.02)
	check(f.last_attack == "committed", "held 0.5s + release = Committed Cut", f.last_attack)
	var cc: AttackData = h.runner.data
	check(cc.anim_style != pc.anim_style and cc.recovery > pc.recovery * 2.0 and cc.poise_damage > pc.poise_damage * 1.8, "visibly and mechanically different from Precision Cut", "recovery %.2f vs %.2f, poise %.0f vs %.0f" % [cc.recovery, pc.recovery, cc.poise_damage, pc.poise_damage])
	await until_idle(h)
	# no unlimited charging advantage
	await wait(0.4)
	refill(h)
	h.press("light")
	await wait(0.75)
	h.release("light")
	await wait(0.02)
	var full: float = h.runner.data.damage_mult
	await until_idle(h)
	await wait(0.4)
	refill(h)
	h.press("light")
	await wait(2.0)
	h.release("light")
	await wait(0.02)
	var long: float = h.runner.data.damage_mult
	await until_idle(h)
	check(is_equal_approx(full, long) and full > cc.damage_mult, "holding past 0.75s adds nothing", "0.5s x%.2f, 0.75s x%.2f, 2.0s x%.2f" % [cc.damage_mult, full, long])
	h.release("heavy")
	r.queue_free()


# ------------------------------------------------------------------ 4. transitions
func test_mode_transitions() -> void:
	print("\n[Mode switch: immediate when idle / legal, waits through committed frames, no loops]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h)
	var n0: int = f.mode_switches
	for i in 6:
		h.press("heavy")
		await get_tree().physics_frame
		h.release("heavy")
		await get_tree().physics_frame
	await wait(0.1)
	check(not h.runner.is_busy() and f.mode_switches == n0 + 12 and not f.in_edge(), "rapid RMB press / release: one clean switch each way, no attack, no loop", "%d switches" % (f.mode_switches - n0))
	# committed attack: releasing RMB does not switch until the cancel point
	h.press("heavy")
	await wait(0.05)
	h.press("light")
	await wait(0.45)
	h.release("light")
	await wait(0.05)
	check(f.last_attack == "committed", "(Committed Cut running)")
	h.release("heavy")
	await wait(0.05)
	check(f.in_edge() and h.runner.is_busy() and not h.runner.can_cancel(), "RMB released during committed frames: still Edge (switch waits)")
	await until_can_act(h)
	await wait(0.03)
	check(not f.in_edge(), "switches to Dance as soon as the attack can legally transition")
	await until_idle(h)
	# entering Edge during a Dance attack waits for its cancel window, then applies
	await wait(0.4)
	tap(h, "light")
	await wait(0.03)
	h.press("heavy")
	await wait(0.02)
	check(not f.in_edge(), "RMB pressed in Dance startup: switch waits")
	await until_can_act(h)
	await wait(0.03)
	check(f.in_edge(), "Edge applied in the legal window")
	h.release("heavy")
	await until_idle(h)
	r.queue_free()


func test_no_duplication() -> void:
	print("\n[No attack from input release; leaving Edge never fires]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h)
	var s0: int = f.started.values().reduce(func(a, b): return a + b, 0)
	h.press("light")
	await wait(0.03)
	h.release("light")
	await until_idle(h)
	var s1: int = f.started.values().reduce(func(a, b): return a + b, 0)
	check(s1 == s0 + 1, "a Dance LMB press = exactly one attack (its release adds nothing)")
	await wait(0.4)
	h.press("heavy")
	await wait(0.05)
	h.press("light")
	await wait(0.4)
	h.release("heavy")      # RMB released while the Committed Cut is being prepared
	await wait(0.05)
	check(not h.runner.is_busy() and h.kit.charging == "", "releasing RMB during preparation abandons the strike (no attack)")
	h.release("light")
	await wait(0.1)
	var s2: int = f.started.values().reduce(func(a, b): return a + b, 0)
	check(s2 == s1 and not h.runner.is_busy(), "the later LMB release fires nothing either")
	# LMB pressed in Dance, RMB pressed while holding: the release is not an Edge attack
	h.press("light")
	await wait(0.03)
	h.press("heavy")
	await until_idle(h)
	h.release("light")
	await wait(0.1)
	var s3: int = f.started.values().reduce(func(a, b): return a + b, 0)
	check(s3 == s2 + 1 and not h.runner.is_busy(), "an LMB press that began in Dance never becomes an Edge strike on release")
	h.release("heavy")
	r.queue_free()


# ------------------------------------------------------------------ 7. commitment
func test_commitment() -> void:
	print("\n[Commitment and cancel rules]")
	var h := await bd(1)
	var r := target(h)
	tap(h, "light")
	await wait(0.04)
	h.move_input = Vector3(1, 0, 0)
	h.try_dodge()
	h.move_input = Vector3.ZERO
	check(h.dodging, "a Dance attack can be dodge-cancelled in its startup (light)")
	await until_idle(h)
	await wait(0.4)
	h.press("heavy")
	await wait(0.05)
	h.press("light")
	await wait(0.45)
	h.release("light")
	var blocked := true
	var n := 0
	while h.runner.is_busy() and n < 80:
		if h.runner.phase != AttackRunner.Phase.STARTUP or h.runner.t > 0.05:
			h.try_dodge()
			blocked = blocked and not h.dodging
		await get_tree().physics_frame
		n += 1
	check(blocked, "Committed Cut cannot be dodge-cancelled (startup, impact and recovery)")
	h.buffer_action = ""
	await until_idle(h)
	await wait(0.3)
	tap(h, "light")
	await wait(0.05)
	h.release("light")
	n = 0
	while h.runner.is_busy() and h.runner.phase != AttackRunner.Phase.RECOVERY and n < 60:
		await get_tree().physics_frame
		n += 1
	h.try_dodge()
	check(h.dodging, "Precision Cut recovery can be dodge-cancelled (lower commitment)")
	h.release("heavy")
	await until_idle(h)
	var cc := load("res://data/attacks/bd_committed.tres") as AttackData
	var pc := load("res://data/attacks/bd_precision.tres") as AttackData
	check(cc.cancel_after > pc.cancel_after * 2.0 and not cc.dodge_cancel and pc.dodge_cancel, "Committed recovery is far more committed than Precision", "cancel after %.2f vs %.2f" % [cc.cancel_after, pc.cancel_after])
	r.queue_free()


# ------------------------------------------------------------------ 8. Combat Weave
func _dodge_travel(h: Hero, input: Vector3) -> float:
	h.velocity = Vector3.ZERO
	h.knock_velocity = Vector3.ZERO
	await wait(0.4)
	var p0 := h.global_position
	h.move_input = input
	h.try_dodge()
	h.move_input = Vector3.ZERO
	while h.dodging:
		await get_tree().physics_frame
	return flat_v(h.global_position - p0)


func test_combat_weave() -> void:
	print("\n[Combat Weave (006): side ~2.8m, forward ~2.6m, back ~3.6m; i-frames unchanged; Edge dodge leaves Edge]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h, 9.0)     # reference direction only (far away)
	var toward := (r.global_position - h.global_position).normalized()
	var right := toward.cross(Vector3.UP).normalized()
	var side := await _dodge_travel(h, right)
	check(f.last_dodge_kind == "side" and absf(side - 2.8) < 0.15, "side dodge ~2.8m (006; 004 was 2.0m)", "%.2fm" % side)
	var fw := await _dodge_travel(h, toward)
	check(f.last_dodge_kind == "forward" and absf(fw - 2.6) < 0.15, "forward dodge ~2.6m (006; 004 was 2.0m)", "%.2fm" % fw)
	var back := await _dodge_travel(h, -toward)
	check(f.last_dodge_kind == "back" and absf(back - 3.6) < 0.15 and back > side, "backward disengagement ~3.6m (006; 004 was 2.7m), farther than a side dodge", "%.2fm" % back)
	# 006: the longer back dodge would reach scenery from where the previous dodges ended: start in the open again
	# (scenery stands ~4m behind the start point, so face away from the far target and dodge toward open ground)
	h.global_position = r.global_position + Vector3(0, 0, 6.0)
	h.lock_target = null
	h.face_dir(h.global_position - r.global_position)
	await wait(0.1)
	var none := await _dodge_travel(h, Vector3.ZERO)
	check(f.last_dodge_kind == "back" and absf(none - 3.6) < 0.15, "no input = backward disengagement (shared rule: dodge away)", "%.2fm" % none)
	# defensive i-frames unchanged
	h.try_dodge()
	await wait(0.1)
	check(h.is_invulnerable(), "i-frames still present (shared timing)")
	await until_idle(h)
	check(is_equal_approx(Game.balance.dodge_iframe_start, 0.03) and is_equal_approx(Game.balance.dodge_iframes, 0.28) and is_equal_approx(Game.balance.dodge_duration, 0.42), "shared dodge timing / i-frame values unchanged")
	# side dodge can be followed by a directional Dance attack
	await wait(0.3)
	place(h, r, 2.0)
	h.move_input = right
	h.try_dodge()
	h.move_input = Vector3.ZERO
	await until_idle(h)
	# 004: a 2.0m side dodge from 2.0m ends ~2.83m away (geometry), one forward Dance step from weapon range
	# 006: a 2.8m side dodge from 2.0m ends ~3.45m away (geometry), one forward Dance (1.3m) from weapon range
	check(flat(h, r) < 3.6, "after a side dodge the Reaver is still close (one Dance step from melee range)", "%.2fm" % flat(h, r))
	var t2 := (r.global_position - h.global_position)
	t2.y = 0
	h.move_input = -t2.normalized().cross(Vector3.UP)
	tap(h, "light")
	await wait(0.03)
	h.move_input = Vector3.ZERO
	check(f.last_attack == "dance_lateral", "side dodge -> directional Dance attack")
	await until_idle(h)
	# Edge dodge: leaves Edge, back to Dance even while RMB stays held
	await wait(0.3)
	h.press("heavy")
	await wait(0.05)
	check(f.in_edge(), "(in Edge)")
	h.try_dodge()
	await wait(0.02)
	check(not f.in_edge(), "dodge in Edge leaves Edge")
	await until_idle(h)
	await wait(0.2)
	check(not f.in_edge(), "still Dance while RMB stays held (press RMB again to re-enter)")
	h.release("heavy")
	await wait(0.03)
	h.press("heavy")
	await wait(0.05)
	check(f.in_edge(), "a new RMB press re-enters Edge")
	h.release("heavy")
	r.queue_free()


# ------------------------------------------------------------------ 9. Q
func test_footwork_techniques() -> void:
	print("\n[Q: Orbit Step (Dance) circles the target; Withdraw & Thrust (Edge) steps back + thrusts]")
	var h := await bd(3)
	var f := bk(h)
	var r := target(h, 2.0)
	var toward := (r.global_position - h.global_position).normalized()
	var right := toward.cross(Vector3.UP).normalized()
	var a0 := (h.global_position - r.global_position)
	a0.y = 0
	var d0 := a0.length()
	var st0 := h.stamina
	h.move_input = right
	tap(h, "footwork")
	await wait(0.02)
	h.move_input = Vector3.ZERO
	check(f.last_attack == "orbit", "Dance + Q = Orbit Step", f.last_attack)
	check(absf(st0 - h.stamina - 10.0) < 0.5, "costs 10 stamina", "%.1f" % (st0 - h.stamina))
	var inv := false
	for i in 20:
		inv = inv or h.is_invulnerable()
		await get_tree().physics_frame
	await until_idle(h)
	var a1 := (h.global_position - r.global_position)
	a1.y = 0
	var ang := rad_to_deg(a0.angle_to(a1))
	check(ang >= 25.0, "circles around the target (new attacking angle)", "%.0f deg" % ang)
	check(absf(a1.length() - d0) < 0.5, "keeps roughly the same range while circling", "%.2f -> %.2fm" % [d0, a1.length()])
	check(not inv, "no invulnerability")
	var lat_dance := 0.65
	check((a1 - a0).length() > lat_dance + 0.3, "a larger repositioning than Lateral Dance", "%.2fm" % (a1 - a0).length())
	check(ang < 90.0, "does not guarantee reaching the flank (bounded arc)", "%.0f deg" % ang)
	# Withdraw & Thrust
	await wait(0.4)
	place(h, r, 2.4)
	h.press("heavy")
	await wait(0.05)
	var p0 := h.global_position
	dmg.clear()
	refill(h)
	tap(h, "footwork")
	await wait(0.02)
	check(f.last_attack == "withdraw", "Edge + Q = Withdraw & Thrust", f.last_attack)
	inv = false
	var back_max := 0.0
	for i in 18:
		inv = inv or h.is_invulnerable()
		back_max = maxf(back_max, -(h.global_position - p0).dot(toward))
		await get_tree().physics_frame
	await until_idle(h)
	check(back_max > 0.5, "steps back (creates space)", "%.2fm" % back_max)
	check(hit_on(r) != null, "the long thrust reaches from the new spacing")
	check(not inv, "no invulnerability")
	await wait(0.4)
	place(h, r, 4.6)
	dmg.clear()
	refill(h)
	tap(h, "footwork")
	await until_idle(h)
	check(hit_on(r) == null, "the thrust can miss (spacing matters)")
	h.release("heavy")
	r.queue_free()


# ------------------------------------------------------------------ 10. E
func test_offense_techniques() -> void:
	print("\n[E: Whirling Assault (Dance) / Breaking Point (Edge)]")
	var h := await bd(5)
	var f := bk(h)
	var r := target(h, 2.0)
	var toward := (r.global_position - h.global_position).normalized()
	var right := toward.cross(Vector3.UP).normalized()
	var r2 := dummy("raider", r.global_position + right * 1.3)
	r2.max_hp = 99999
	r2.hp = 99999
	await wait(0.2)
	var p0 := h.global_position
	dmg.clear()
	h.move_input = right
	tap(h, "core")
	await wait(0.02)
	check(f.last_attack == "whirl", "Dance + E = Whirling Assault", f.last_attack)
	await until_idle(h)
	h.move_input = Vector3.ZERO
	var on_r := dmg.filter(func(i): return i.target == r).size()
	var on_r2 := dmg.filter(func(i): return i.target == r2).size()
	check(on_r >= 3 and on_r2 >= 1, "a series of slashes that also catches a nearby second enemy", "%d hits / %d hits" % [on_r, on_r2])
	check((h.global_position - p0).dot(right) > 0.3, "controlled directional movement while slashing", "%.2fm" % (h.global_position - p0).dot(right))
	# Breaking Point
	await wait(0.4)
	place(h, r, 2.0)
	h.press("heavy")
	await wait(0.05)
	dmg.clear()
	refill(h)
	tap(h, "core")
	await wait(0.02)
	check(f.last_attack == "break", "Edge + E = Breaking Point", f.last_attack)
	await until_idle(h)
	var base := hit_on(r)
	check(base != null and hit_on(r2) == null, "narrow: hits the target, not the neighbour", "neighbour hit: %s" % str(hit_on(r2) != null))
	await wait(0.4)
	enemy_swing(r, 0.05, 3.0)
	await wait(0.15)
	place(h, r, 2.0)
	dmg.clear()
	refill(h)
	tap(h, "core")
	await until_idle(h)
	var pun := hit_on(r)
	if base and pun:
		check(pun.tags.get("punish", false) and absf(pun.poise / base.poise - ReaverBladeDancer.BREAK_PUNISH_POISE) < 0.05, "against a recovering enemy: x2 Poise (punish identity)", "x%.2f" % (pun.poise / base.poise))
		check(absf(pun.raw_amount / base.raw_amount - 1.0) < 0.01, "Poise, not damage", "x%.3f" % (pun.raw_amount / base.raw_amount))
	r.runner.interrupt()
	# hit vs miss recovery
	await wait(0.5)
	place(h, r, 2.0)
	refill(h)
	tap(h, "core")
	var hit_t := await _time_to_act(h)
	await until_idle(h)
	await wait(0.4)
	place(h, r, 5.0)
	refill(h)
	tap(h, "core")
	var miss_t := await _time_to_act(h)
	await until_idle(h)
	check(miss_t > hit_t + 0.3, "noticeable recovery when it misses", "free to act after %.2fs (hit) vs %.2fs (miss)" % [hit_t, miss_t])
	h.release("heavy")
	r2.queue_free()
	r.queue_free()


func _time_to_act(h: Hero) -> float:
	await get_tree().physics_frame
	var n := 1
	while not h.can_act() and n < 120:
		await get_tree().physics_frame
		n += 1
	return n / 60.0


# ------------------------------------------------------------------ 11. differences
func test_technique_differences() -> void:
	print("\n[Each technique is mechanically distinct (not the same attack with another animation)]")
	var w := load("res://data/attacks/bd_whirl.tres") as AttackData
	var b := load("res://data/attacks/bd_break.tres") as AttackData
	var c := load("res://data/attacks/bd_committed.tres") as AttackData
	var o := load("res://data/attacks/bd_orbit.tres") as AttackData
	var wt := load("res://data/attacks/bd_withdraw.tres") as AttackData
	var p := load("res://data/attacks/bd_precision.tres") as AttackData
	check(w.hits > 1 and b.hits == 1 and w.hitbox_size.x > b.hitbox_size.x * 3.0 and w.move_during > 0.0 and b.move_during == 0.0, "Whirling Assault vs Breaking Point: multi-hit wide mobile vs single narrow static")
	check(b.damage_mult < c.damage_mult * 0.6 and b.poise_damage / b.damage_mult > c.poise_damage / c.damage_mult * 1.3, "Breaking Point is not an expensive Committed Cut: low damage, Poise-focused", "poise/dmg %.0f vs %.0f" % [b.poise_damage / b.damage_mult, c.poise_damage / c.damage_mult])
	check(b.hitbox_size.x < c.hitbox_size.x and b.stamina_cost > c.stamina_cost, "Breaking Point is narrower than Committed Cut")
	check(o.hitbox_size.z < wt.hitbox_size.z and wt.hitbox_size.x < o.hitbox_size.x, "Orbit Step vs Withdraw & Thrust: wide close slash vs narrow long thrust (and opposite movement, checked above)")
	check(p.startup > 0.0 and p.hitbox_size.z > (load("res://data/attacks/bd_dance_neutral.tres") as AttackData).hitbox_size.z, "Precision Cut out-reaches Neutral Dance")
	var styles := {}
	for id in ["bd_dance_neutral", "bd_dance_forward", "bd_precision", "bd_committed", "bd_orbit", "bd_withdraw", "bd_whirl", "bd_break"]:
		styles[(load("res://data/attacks/%s.tres" % id) as AttackData).anim_style] = true
	check(styles.size() == 8, "nine attacks, nine motions (lateral has left / right on top)", str(styles.keys()))


# ------------------------------------------------------------------ Lv7 mastery
func test_mastery() -> void:
	print("\n[Lv7 Blade Dancer Mastery: connected Precision Cut -> one Dance attack from an earlier window]")
	for lvl in [5, 7]:
		var h := await bd(lvl)
		var f := bk(h)
		var r := target(h)
		h.press("heavy")
		await wait(0.05)
		tap(h, "light")
		await wait(0.02)
		h.release("heavy")
		var n := 0
		while not h.can_act() and n < 60:
			await get_tree().physics_frame
			n += 1
		var rec: float = h.runner.time_in_recovery() if h.runner.is_busy() else 9.0
		var early := h.runner.is_busy() and rec < 0.14 - 0.02
		if lvl == 5:
			check(not early, "Lv5: normal Precision cancel window", "%.2fs into recovery" % rec)
		else:
			check(early, "Lv7: Dance transition opens earlier", "%.2fs into recovery (normal 0.14s)" % rec)
			tap(h, "footwork")
			await wait(0.02)
			check(f.last_attack == "precision", "the early window is for a Dance attack only (Q waits)")
			h.buffer_action = ""
			h.move_input = Vector3(1, 0, 0)
			tap(h, "light")
			await wait(0.02)
			h.move_input = Vector3.ZERO
			check(f.last_attack.begins_with("dance_"), "one directional Dance attack follows", f.last_attack)
		await until_idle(h)
		r.queue_free()


# ------------------------------------------------------------------ 12. stamina
func test_stamina() -> void:
	print("\n[Stamina: approved costs, +1 once per connecting attack, nothing for misses]")
	var expect := {"bd_dance_neutral": 5.0, "bd_dance_forward": 5.0, "bd_dance_lateral": 5.0, "bd_precision": 10.0, "bd_committed": 20.0,
		"bd_orbit": 10.0, "bd_withdraw": 12.0, "bd_whirl": 18.0, "bd_break": 22.0}
	var bad := ""
	for id in expect:
		var a := load("res://data/attacks/%s.tres" % id) as AttackData
		if not is_equal_approx(a.stamina_cost, expect[id]):
			bad += "%s=%.0f " % [id, a.stamina_cost]
	check(bad == "", "costs match the approved table", bad)
	check(is_equal_approx(Game.balance.dodge_cost, 22.0) and is_equal_approx(Game.balance.stamina_regen, 30.0) and is_equal_approx(Game.balance.reaver_dodge_cost_mult, 0.8), "shared dodge cost / regeneration unchanged")
	var h := await bd(5)
	var f := bk(h)
	var r := target(h)
	h.stamina = 50.0
	tap(h, "light")
	await wait(0.02)
	check(is_equal_approx(h.stamina, 45.0), "Dance attack costs 5", "%.1f" % h.stamina)
	await until_idle(h)
	h.stamina_delay = 99.0
	check(absf(h.stamina - 46.0) < 0.5, "connecting: +1", "%.1f" % h.stamina)
	await wait(0.3)
	h.stamina = 60.0
	var ref0: float = f.stamina_refunded
	dmg.clear()
	tap(h, "core")
	await wait(0.02)
	h.stamina_delay = 99.0
	await until_idle(h)
	var hits := dmg.filter(func(i): return i.target == r).size()
	check(hits >= 3 and absf(f.stamina_refunded - ref0 - 1.0) < 0.01, "multi-hit Whirling Assault refunds 1 once", "%d hits, +%.1f" % [hits, f.stamina_refunded - ref0])
	await wait(0.3)
	h.lock_target = null
	h.face_dir(Vector3(0, 0, 1))
	await wait(0.05)
	h.stamina = 50.0
	tap(h, "light")
	await until_idle(h)
	h.stamina_delay = 99.0
	check(absf(h.stamina - 45.0) < 0.5, "a miss refunds nothing", "%.1f" % h.stamina)
	r.queue_free()


# ------------------------------------------------------------------ 13. augments
func _committed_hits(h: Hero, r: Enemy, hold: float = 0.5) -> Array:
	place(h, r, 2.2)
	refill(h)
	dmg.clear()
	h.press("heavy")
	await wait(0.05)
	h.press("light")
	await wait(hold)
	h.release("light")
	await wait(0.02)
	var d: AttackData = h.runner.data
	await until_idle(h)
	h.release("heavy")
	await wait(0.4)
	return [d, dmg.filter(func(i): return i.target == r)]


func test_augments() -> void:
	print("\n[Augments: Relentless Dance / Perfect Edge / Twin Tempest; draft pool; old augments incompatible]")
	var h := await bd(8)
	var f := bk(h)
	var p := Game.prog("reaver")
	var r := target(h)
	var pool: Array = Game.augment_db.eligible("reaver", p).map(func(a): return a.id)
	pool.sort()
	# LEVEL10-FOUNDATION-005 replaces the draft pool with the curated Level 1-10 cards; the three 003 cards stay working when owned
	check(not pool.is_empty() and pool.all(func(id): return Game.augment_db.get_augment(id).pool == "l10") and not pool.has("perfect_edge") and not pool.has("twin_tempest") and not pool.has("relentless_dance"), "Blade Dancer drafts only from the Level 1-10 pool (005); 003 cards kept when owned", str(pool.size()))
	for id in ["crosswind", "needlepoint", "turning_steel", "sundering_verdict", "precision_edge", "tempest_edge", "momentum_edge", "rising_crescent", "ghost_step"]:
		var a: AugmentData = Game.augment_db.get_augment(id)
		check(Game.augment_db.ineligible_reason(a, p) != "" and Game.augment_db.bladedancer_inactive(a), "%s: incompatible with Blade Dancer, never drafted" % id, Game.augment_db.ineligible_reason(a, p))
	# base Committed Cut
	var base := await _committed_hits(h, r)
	var base_d: AttackData = base[0]
	var base_total: float = base[1].reduce(func(a, i): return a + i.raw_amount, 0.0)
	# Relentless Dance
	Game.add_augment("reaver", "relentless_dance")
	h.stats.crit_chance = 0.0
	await wait(0.1)
	place(h, r, 2.0)
	dmg.clear()
	refill(h)
	tap(h, "light")
	await until_idle(h)
	var plain := hit_on(r)
	await wait(0.4)
	h.press("heavy")
	await wait(0.05)
	tap(h, "light")
	await until_idle(h)
	h.release("heavy")
	await wait(0.1)
	check(f.relentless_ready, "a connecting Edge attack readies Relentless Dance")
	place(h, r, 2.0)
	dmg.clear()
	refill(h)
	tap(h, "light")
	await wait(0.02)
	var rel_style: String = h.runner.data.anim_style
	await until_idle(h)
	var rel := hit_on(r)
	check(rel_style == "bd_relentless", "the returning Dance attack has its own mobile follow-up motion", rel_style)
	if plain and rel:
		check(absf(rel.raw_amount / plain.raw_amount - 1.0) < 0.01, "no bonus damage", "x%.3f" % (rel.raw_amount / plain.raw_amount))
	check(not f.relentless_ready, "only the first returning Dance attack")
	Game.remove_augment("reaver", "relentless_dance")
	# Perfect Edge
	Game.add_augment("reaver", "perfect_edge")
	h.stats.crit_chance = 0.0
	await wait(0.1)
	var pe := await _committed_hits(h, r)
	var pe_d: AttackData = pe[0]
	check(pe_d.hitbox_size.x < base_d.hitbox_size.x * 0.7, "Perfect Edge: narrower Committed Cut", "%.2f vs %.2f" % [pe_d.hitbox_size.x, base_d.hitbox_size.x])
	enemy_swing(r, 0.05, 3.0)
	await wait(0.15)
	var pe_rec := await _committed_hits(h, r)
	r.runner.interrupt()
	if not pe[1].is_empty() and not pe_rec[1].is_empty():
		check(absf(pe_rec[1][0].poise / pe[1][0].poise - 1.5) < 0.05, "x1.5 Poise against a recovering target", "x%.2f" % (pe_rec[1][0].poise / pe[1][0].poise))
	else:
		check(false, "Perfect Edge hits connected")
	Game.add_augment("reaver", "twin_tempest")
	check(p.augment_stacks("twin_tempest") == 0 and Game.augment_db.owned_in_group(p, "committed_transform", "twin_tempest") == "perfect_edge", "Perfect Edge excludes Twin Tempest")
	Game.remove_augment("reaver", "perfect_edge")
	# Twin Tempest
	Game.add_augment("reaver", "twin_tempest")
	h.stats.crit_chance = 0.0
	await wait(0.1)
	var tt := await _committed_hits(h, r)
	var tt_d: AttackData = tt[0]
	var tt_total: float = tt[1].reduce(func(a, i): return a + i.raw_amount, 0.0)
	check(tt_d.hits == 4 and is_equal_approx(tt_d.hit_weights[3], 0.55) and tt[1].size() == 4, "Twin Tempest: 4 hits, strong final strike (55%)", "%d hits landed" % tt[1].size())
	check(tt_total >= base_total * 0.9 and tt_total <= base_total * 1.35, "total damage stays competitive with the default", "%.0f vs %.0f" % [tt_total, base_total])
	check(tt_d.total_time() > base_d.total_time(), "longer exposure to interruption", "%.2fs vs %.2fs" % [tt_d.total_time(), base_d.total_time()])
	check(p.active_mutations().has("twin_tempest") and Game.augment_db.get_augment("twin_tempest").category == "mutation", "uses the existing mutation slots")
	Game.remove_augment("reaver", "twin_tempest")
	r.queue_free()


# ------------------------------------------------------------------ 14. existing characters
func test_existing_character() -> void:
	print("\n[Existing Lv10 Reaver save (Swordmaster-era augments, spent drafts) loads and plays Blade Dancer]")
	var path := fixture_path("bd_compat_save.json")
	clear_fixture(path)
	var old_path: String = Save.path
	Save.path = path
	Save.enabled = true
	var rv := {"class_id": "reaver", "created": true, "name": "Old Blade", "level": 10, "xp": 0, "total_exp": 9000, "augments": ["crosswind", "turning_steel", "needlepoint"],
		"inactive_mutations": [], "pending_drafts": 0, "pending_draft_tiers": [], "drafts_taken": 3, "free_points": 0,
		"allocated": {"str": 0, "dex": 14, "vit": 0, "for": 0, "mas": 0}, "life_number": 1, "seen_unlocks": ["r_flow_strikes", "stats_2"],
		"equipment": {"weapon": "starter_r_sword"}, "inventory": [], "reaver_loadout": ["r_lunge", "r_flow_step", "r_crosscut", "r_flurry"], "play_time": 900.0}
	var doc := {"version": 1, "last_class": "reaver", "characters": {"reaver": rv}}
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(doc))
	fa.close()
	check(Save.validate_save(doc) == "", "the existing save passes the unchanged validator")
	Game.reaver_core = "bladedancer"
	Save.load_game()
	var p := Game.prog("reaver")
	check(p.level == 10 and p.allocated.dex == 14 and p.drafts_taken == 3 and p.augments == ["crosswind", "turning_steel", "needlepoint"], "level, attributes, drafts and augments preserved (no migration)")
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
	await wait(0.5)
	h.press("heavy")
	await wait(0.05)
	tap(h, "light")
	await wait(0.6)
	h.release("heavy")
	tap(h, "core")
	await wait(1.2)
	check(r.hp < hp0 and h.kit.dancer_core(), "the Lv10 Reaver plays Blade Dancer (Dance, Edge, E unlocked)", "%.0f dmg" % (hp0 - r.hp))
	check(p.reaver_loadout == ["r_lunge", "r_flow_step", "r_crosscut", "r_flurry"] and p.level == 10, "nothing rewritten, nothing reset")
	Save.enabled = true
	var ok := Save.save_game()
	var fr := FileAccess.open(path, FileAccess.READ)
	var back = JSON.parse_string(fr.get_as_text())
	fr.close()
	var kept := back is Dictionary and rv.keys().all(func(k): return back.characters.reaver.has(k))
	check(ok and back is Dictionary and Save.validate_save(back) == "" and back.characters.reaver.level == 10 and back.characters.reaver.augments == ["crosswind", "turning_steel", "needlepoint"] and kept, "re-saved: valid, every original field kept, nothing lost")
	if back is Dictionary:
		var txt := JSON.stringify(back)
		check(not txt.contains("bladedancer") and not txt.contains("edge_mode"), "no Blade Dancer combat state written to the save")
	Save.enabled = false
	Save.path = old_path
	clear_fixture(path)
	r.queue_free()


# ------------------------------------------------------------------ 15. legacy cores
func test_legacy_cores() -> void:
	print("\n[Legacy comparison: Free Flow 002 / Swordmaster / Sword Sense, never saved]")
	var h := await bd(5)
	var r := target(h)
	Game.debug_tainted = false
	Game.set_core("reaver", "freeflow")
	check(Game.debug_tainted and Save.save_game() == false, "Free Flow 002 comparison: non-saving session")
	await wait(0.1)
	tap(h, "light")
	await wait(0.03)
	check(cur(h).begins_with("ff_strike"), "Free Flow 002 still plays", cur(h))
	check(Game.track("reaver").resource_path.ends_with("reaver_freeflow.tres"), "Free Flow keeps its own track")
	await until_idle(h)
	await wait(0.5)
	Game.set_core("reaver", "swordmaster")
	await wait(0.1)
	tap(h, "light")
	await wait(0.03)
	check(cur(h) == "rs_forward", "Swordmaster still plays", cur(h))
	await until_idle(h)
	await wait(0.5)
	Game.set_core("reaver", "sense")
	await wait(0.1)
	tap(h, "light")
	await wait(0.03)
	check(cur(h).begins_with("r_light"), "Sword Sense still plays", cur(h))
	await until_idle(h)
	await wait(0.5)
	Game.set_core("reaver", "bladedancer")
	await wait(0.1)
	tap(h, "light")
	await wait(0.03)
	check(cur(h).begins_with("bd_dance"), "back to Blade Dancer", cur(h))
	Game.debug_tainted = false
	Game.set_core("reaver", "bladedancer")
	check(not Game.debug_tainted, "selecting Blade Dancer (the default) does not taint")
	await until_idle(h)
	Game.set_core("reaver", "freeflow")
	h.move_input = Vector3(1, 0, 0)
	h.try_dodge()
	h.move_input = Vector3.ZERO
	check(is_equal_approx(h.dodge_scale, 1.0), "comparison cores use the normal dodge distance")
	await until_idle(h)
	Game.set_core("reaver", "bladedancer")
	Game.debug_tainted = false
	r.queue_free()


# ------------------------------------------------------------------ 16. other classes
func test_other_classes() -> void:
	print("\n[Vanguard / Worldweaver unchanged: dodge distance, inputs, Q does nothing]")
	for cls in ["vanguard", "mage"]:
		var h := await setup(cls, false, false, false)
		for c in h.get_children():
			if c is PlayerBrain:
				c.set_physics_process(false)
		await wait(0.3)
		var p0 := h.global_position
		h.move_input = Vector3(1, 0, 0)
		h.try_dodge()
		h.move_input = Vector3.ZERO
		while h.dodging:
			await get_tree().physics_frame
		var d := flat_v(h.global_position - p0)
		check(absf(d - 3.465) < 0.15 and is_equal_approx(h.dodge_scale, 1.0), "%s dodge unchanged (~3.46m)" % cls, "%.2fm" % d)
		await wait(0.4)
		tap(h, "footwork")
		await wait(0.1)
		check(not h.runner.is_busy() and h.kit.charging == "", "%s: Q (footwork) does nothing" % cls)
		check(is_equal_approx(h.attack_blend, 0.04), "%s keeps the shared attack blend" % cls)
	check(InputMap.action_has_event(&"core", _key_ev(KEY_E)) and InputMap.action_has_event(&"guard", _key_ev(KEY_SHIFT)) and InputMap.action_has_event(&"skill1", _key_ev(KEY_1)), "existing bindings unchanged (E core, Shift guard, 1-3 skills)")
	check(InputMap.action_has_event(&"footwork", _key_ev(KEY_Q)), "Q bound to the new footwork action")


func _key_ev(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	return ev


# ------------------------------------------------------------------ 17. startup / HUD / companion
func test_startup_and_hud() -> void:
	print("\n[Real main scene: HUD skill bar (no meter), Party companion, save safety]")
	await teardown()
	Game.reset_all_progress()
	for c in Game.CLASSES:
		Game.prog(c).created = true
	Game.reaver_core = "bladedancer"
	Game.mage_core = "elementalist"
	Game.debug_tainted = false
	check(not Save.enabled, "tests never write the real save (Save.enabled = false)")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.2)
	main.start_game("reaver", false)
	Game.set_level("reaver", 5)
	Game.prog("reaver").pending_drafts = 0
	Game.prog("reaver").pending_draft_tiers.clear()
	await wait(0.6)
	var hud = main.find_child("HUD", true, false)
	check(hud != null and hud.slots.has("light") and hud.slots.has("heavy") and hud.slots.has("footwork") and hud.slots.has("core") and hud.slots.has("dodge"), "HUD: LMB / RMB / Q / E / Space", str(hud.slots.keys()) if hud else "no HUD")
	if hud:
		check(not hud.slots.has("skill1") and not hud.slots.has("life"), "no 1/2/3 slots and no extra meter")
	var seen := {}
	main.return_to_menu()
	await wait(0.3)
	Game.reaver_core = "bladedancer"
	main.start_game("vanguard", true)
	await wait(0.5)
	var comp: Hero = null
	for x in Game.heroes:
		if is_instance_valid(x) and x.class_id == "reaver" and not x.is_player:
			comp = x
	check(comp != null and comp.kit.dancer_core(), "the Reaver Party companion runs Blade Dancer")
	if comp:
		comp.runner.started.connect(func(d, _c): seen[d.id] = true)
		var e := Game.spawn_enemy("raider", comp.global_position + Vector3(0, 0, -3.0))
		e.max_hp = 99999
		e.hp = 99999
		await wait(6.0)
		check(seen.keys().any(func(k): return String(k).begins_with("bd_")), "the companion fights with Blade Dancer attacks", str(seen.keys()))
		if is_instance_valid(e):
			e.queue_free()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Game.end_session()
