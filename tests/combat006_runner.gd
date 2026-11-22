extends "res://tests/level10_runner.gd"
## COMBAT-BALANCE-UX-006: regression checks for the combat corrections (enemy commitment, Combat Weave,
## camera lock heading / collision smoothing) and, later milestones, the casting wheels and UI text.
##   godot --headless --fixed-fps 60 res://tests/combat006_runner.tscn
## Automated checks only: they verify the rules, not the feel.

var got_hit: bool = false
var dodged_n: int = 0


func _run_all() -> void:
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.target == Game.player and info.final_amount > 0.0: got_hit = true)
	Events.guard_event.connect(func(d, _i, k): if d == Game.player and k == "dodge": dodged_n += 1)
	await test_enemy_commitment()
	await test_dodge_vs_attacks()
	await test_weave_distances()
	await test_camera_heading_blend()
	await _extra()
	await teardown()




func _rig() -> CameraRig:
	for n in Game.world.get_children():
		if n is CameraRig:
			return n
	return null


func test_enemy_commitment() -> void:
	print("\n[Enemy commitment: tracks early, fades late, locked before impact; lunges commit earlier]")
	var h := await bd(10)
	var e := dummy("raider", h.global_position + Vector3(0, 0, -1.9))
	e.target = h
	face(e, h)
	var d: AttackData = e.find_attack("raider_combo1")
	check(is_equal_approx(d.track_full, 0.4) and is_equal_approx(d.commit_at, 0.7), "ordinary melee: full tracking to 40%, locked from 70% of the windup")
	var wl := load("res://data/attacks/wolf_lunge.tres") as AttackData
	check(wl.commit_at < d.commit_at, "fast lunge commits earlier (%.0f%%)" % (wl.commit_at * 100.0))
	e.begin_attack(d)
	var startup: float = d.startup / e.runner.speed
	var ks: Array = []
	var t := 0.0
	var moved := false
	var yaw_at_commit := 0.0
	var committed_seen := false
	while e.runner.phase == AttackRunner.Phase.STARTUP:
		ks.append(e.tracking_factor())
		if not moved and t >= startup * 0.5:
			moved = true
			h.global_position += Vector3(2.2, 0, 0)     # the player steps aside
		if not committed_seen and e.is_committed():
			committed_seen = true
			yaw_at_commit = e.rotation.y
		await get_tree().physics_frame
		t += 1.0 / 60.0
	check(ks[0] == 1.0 and ks[ks.size() - 1] == 0.0, "tracking factor 1 at the start, 0 at the end")
	var mono := true
	for i in range(1, ks.size()):
		if ks[i] > ks[i - 1] + 0.0001:
			mono = false
	check(mono, "tracking only fades (never re-acquires during the windup)")
	check(committed_seen and absf(wrapf(e.rotation.y - yaw_at_commit, -PI, PI)) < 0.001, "no rotation after the commit point")
	check(e.telegraph == null or not is_instance_valid(e.telegraph) or e.telegraph.committed, "the ground telegraph shows the lock")
	e.queue_free()


func test_dodge_vs_attacks() -> void:
	print("\n[A correctly timed side dodge avoids every melee attack; a late side WALK stays punishable]")
	var ok := 0
	var total := 0
	for spec in [["raider", "raider_combo1"], ["raider", "raider_heavy"], ["wolf", "wolf_lunge"], ["shield_guardian", "guardian_slam"], ["ashen_warden", "warden_slash1"], ["ashen_warden", "warden_execution"]]:
		for tb in [0.4, 0.25, 0.12]:
			var h := await bd(10)
			h.max_hp = 99999
			h.hp = 99999
			var e := dummy(String(spec[0]), h.global_position + Vector3(0, 0, -1.9))
			e.max_hp = 999999
			e.hp = 999999
			e.target = h
			face(e, h)
			h.lock_target = e
			await wait(0.05)
			var d: AttackData = e.find_attack(String(spec[1]))
			got_hit = false
			e.begin_attack(d)
			var startup: float = d.startup / e.runner.speed
			var acted := false
			var t := 0.0
			while t < startup + d.active + 0.3:
				if not acted and startup - t <= tb:
					acted = true
					var to: Vector3 = e.global_position - h.global_position
					to.y = 0
					h.move_input = to.normalized().cross(Vector3.UP)
					h.try_dodge()
				if acted and not h.dodging:
					h.move_input = Vector3.ZERO
				await get_tree().physics_frame
				t += 1.0 / 60.0
			total += 1
			if not got_hit:
				ok += 1
			else:
				print("    hit: %s side dodge %.2fs before" % [spec[1], tb])
			e.queue_free()
	check(ok == total, "side dodges 0.12-0.4s before impact avoid the hit: %d / %d" % [ok, total])
	await test_boss_avoidability()


## Every Ashen Warden attack has a correct answer that takes no damage (measurement for Part 11:
## "repeated deaths caused by unavoidable tracking / hitboxes are unacceptable"). Wide or multi-hit
## attacks: dodge back and keep moving away; Burning Ground: leave the 2.8m circle; others: side dodge.
func test_boss_avoidability() -> void:
	print("\n[Boss: every Ashen Warden attack is avoidable with its correct response (Reaver Lv10, 2.2m)]")
	var plan := {"warden_slash1": "side", "warden_slash2": "side", "warden_breaker": "side", "warden_execution": "side",
		"warden_ember_lance": "side", "warden_sweep": "back", "warden_flame_combo": "back", "warden_roar": "back",
		"warden_burning_ground": "leave"}
	var ok := 0
	for id in plan:
		var how: String = plan[id]
		var h := await bd(10)
		h.max_hp = 99999
		h.hp = 99999
		var e := dummy("ashen_warden", h.global_position + Vector3(0, 0, -2.2))
		e.max_hp = 999999
		e.hp = 999999
		e.target = h
		face(e, h)
		h.lock_target = e
		await wait(0.05)
		var d: AttackData = e.find_attack(id)
		if d == null:
			check(false, "warden has attack %s" % id)
			e.queue_free()
			continue
		got_hit = false
		e.begin_attack(d)
		var startup: float = d.startup / e.runner.speed
		var lead := 0.3 if how != "leave" else 0.45
		if id == "warden_ember_lance":
			lead = -0.02     # aimed at the hero's position on release (not homing): answer it on the release
		var acted := false
		var away := Vector3.ZERO
		var t := 0.0
		while t < startup + d.active + (1.6 if how == "leave" else 0.4):
			var to: Vector3 = e.global_position - h.global_position
			to.y = 0
			if not acted and startup - t <= lead:
				acted = true
				away = -to.normalized() if how != "side" else to.normalized().cross(Vector3.UP)
				h.move_input = away
				h.try_dodge()
			if acted and not h.dodging:
				h.move_input = away if how != "side" and t < startup + d.active + 0.6 else Vector3.ZERO
			await get_tree().physics_frame
			t += 1.0 / 60.0
		if not got_hit:
			ok += 1
		else:
			print("    hit: %s (%s)" % [id, how])
		e.queue_free()
		await wait(0.05)
		for z in get_tree().root.find_children("*", "GroundZone", true, false):
			z.queue_free()
	check(ok == plan.size(), "every warden attack avoided by its correct response: %d / %d" % [ok, plan.size()])


func test_weave_distances() -> void:
	print("\n[Combat Weave 006: side 2.8 / forward 2.6 / back 3.6m, same timing and i-frames, readable feedback]")
	var h := await bd(1)
	var f := bk(h)
	var r := target(h, 9.0)
	var toward := (r.global_position - h.global_position).normalized()
	var right := toward.cross(Vector3.UP).normalized()
	var side := await _dodge_travel(h, right)
	var fw := await _dodge_travel(h, toward)
	var back := await _dodge_travel(h, -toward)
	check(absf(side - 2.8) < 0.15 and absf(fw - 2.6) < 0.15 and absf(back - 3.6) < 0.15, "distances %.2f / %.2f / %.2fm" % [side, fw, back])
	await wait(0.05)
	check(is_equal_approx(Game.balance.dodge_duration, 0.42) and is_equal_approx(Game.balance.dodge_iframes, 0.28), "shared timing and i-frames unchanged")
	check(f.weave_completions >= 3, "every Weave ends with its completion cue (%d)" % f.weave_completions)
	# evade feedback on a real attack
	var h2 := await bd(10)
	var e := dummy("raider", h2.global_position + Vector3(0, 0, -1.9))
	h2.try_dodge()
	await wait(0.08)
	enemy_hit(h2, e)
	check(bk(h2).evades == 1, "a real attack through the i-frames gives the EVADED cue")
	h2.try_dodge()
	await until_idle(h2)
	check(bk(h2).evades == 1, "an empty dodge gives no evade cue")
	# committed strike stays committed
	var cc := load("res://data/attacks/bd_committed.tres") as AttackData
	check(not cc.dodge_cancel, "Committed Cut remains non-cancelable")


func test_camera_heading_blend() -> void:
	print("\n[Camera: no hard heading switch around 1.9m; rising collision limit is smoothed]")
	var h := await bd(10)
	var e := target(h, 1.5)
	var rig := _rig()
	await wait(0.6)
	var maxacc := 0.0
	var yaws: Array = []
	# walk sideways AND outward, crossing 1.9m with lock-on
	for fr in 150:
		var to: Vector3 = e.global_position - h.global_position
		to.y = 0
		h.move_input = (to.normalized().cross(Vector3.UP) - to.normalized() * 0.35).normalized()
		await get_tree().physics_frame
		await get_tree().process_frame
		yaws.append(rig.yaw)
	h.move_input = Vector3.ZERO
	for i in range(2, yaws.size()):
		maxacc = maxf(maxacc, absf(wrapf(yaws[i] - yaws[i - 1], -PI, PI) - wrapf(yaws[i - 1] - yaws[i - 2], -PI, PI)) * 3600.0)
	check(flat(h, e) > 2.2 and maxacc < 120.0, "crossing the hold distance: yaw acceleration max %.0f rad/s^2 (was ~1100 with the hard switch), ended %.2fm away" % [maxacc, flat(h, e)])
	check(rig.limit_rise_rate > 0.0 and rig.hold_blend_width > 0.0, "smoothing parameters present")


func _extra() -> void:
	await test_casting_wheels()
	await test_wheel_cancellations()
	await test_ui_clarity()


func castw(level: int) -> Hero:
	var h := await ww(level)
	h.stats.crit_chance = 0.0
	h.kit.mana = 100.0
	return h


func test_casting_wheels() -> void:
	print("\n[Casting wheels: hold LMB / RMB = charge + wheel; point = switch (charge restarts); release = cast; tap = last spell]")
	check(not InputMap.has_action("wheel_primary") and not InputMap.has_action("wheel_secondary"), "the Q / V spell-wheel actions are gone")
	var h := await castw(9)
	var el: MageElementalist = h.kit.el
	var released: Array = []
	var cb := func(c, sid, _e, full, _t, _m): if c == h: released.append([sid, full])
	Events.spell_released.connect(cb)
	var lmb0 := el.slot_spell(0)
	# quick tap: last LMB spell, no wheel flash
	var opened := false
	h.press("light")
	for i in 3:
		await get_tree().physics_frame
		opened = opened or el.wheel_open
	h.release("light")
	for i in 40:
		await get_tree().physics_frame
		opened = opened or el.wheel_open
	check(not opened and released.size() == 1 and released[0][0] == lmb0, "quick tap casts the last LMB spell (%s) without showing the wheel" % lmb0)
	await until_idle(h)
	h.kit.mana = 100.0
	# hold: charging at once, wheel after the short delay
	h.press("light")
	await get_tree().physics_frame
	check(el.cur != null and el.cur.id == lmb0 and not el.wheel_open, "hold: the LMB spell starts charging at once")
	await wait(0.2)
	check(el.wheel_open and Game.wheel_open and el.wheel_slot == 0, "the LMB wheel is open while held (camera input paused)")
	var opts := el.wheel_options(0)
	var other := -1
	for i in opts.size():
		if opts[i] != lmb0 and el.spells[opts[i]].element != "life":
			other = i
	await wait(0.3)
	var mana0: float = h.kit.mana
	var t_before := el.charge_t
	el.wheel_select(other)
	check(el.cur != null and el.cur.id == opts[other] and el.charge_t < 0.05 and t_before > 0.3, "pointing at another spell switches to it; charge restarts from zero (was %.2fs)" % t_before)
	check(absf(h.kit.mana - mana0) < 0.01 and released.size() == 1, "switching casts nothing and spends no mana")
	check(el.slot_spell(0) == opts[other], "the button remembers the new spell (next tap)")
	await wait(0.2)
	var t_mid := el.charge_t
	el.wheel_select(other)
	await wait(0.1)
	check(el.charge_t > t_mid, "staying on the same sector keeps charging")
	await wait(1.6)
	h.release("light")
	await wait(0.05)
	check(released.size() == 2 and released[1][0] == opts[other] and released[1][1], "release casts the selected spell (full charge)")
	check(not el.wheel_open and not Game.wheel_open, "the wheel closes and the camera is restored")
	await until_idle(h)
	# min charge after a switch cannot be skipped
	h.kit.mana = 100.0
	h.press("light")
	await wait(0.25)
	el.wheel_select(opts.find(lmb0))
	h.release("light")
	await get_tree().physics_frame
	check(el.cur != null, "releasing right after a switch waits for the new spell's minimum charge (no instant cast)")
	await wait(0.6)
	check(released.size() == 3 and released[2][0] == lmb0 and not released[2][1], "... then casts the partial version")
	await until_idle(h)
	# RMB has its own wheel and set; healing can be in either wheel
	var pr := Game.prog("mage")
	pr.wheel_sets = {"0": [lmb0]}
	# 006 review 2 (approved): the wheels have DIFFERENT default groups; customizing one leaves the other's default
	check(el.wheel_options(0).size() == 1 and _same(el.wheel_options(1), el.default_wheel(1)), "LMB and RMB wheels have independent spell sets (Spellbook)")
	pr.wheel_sets = {}
	check(el.wheel_options(1).has("life_bloom") and not el.wheel_options(0).has("life_bloom"), "healing sits in the RMB (Life & Control) wheel by default")
	pr.set_wheel_member(0, "life_bloom", true, el.wheel_options(0))
	check(el.wheel_options(0).has("life_bloom") and el.wheel_options(1).has("life_bloom"), "the player may also put healing in the LMB wheel (Spellbook)")
	pr.wheel_sets = {}
	h.kit.mana = 100.0
	h.press("heavy")
	await wait(0.2)
	check(el.wheel_slot == 1 and el.cur_action == "heavy", "RMB opens the RMB wheel")
	h.release("heavy")
	await wait(1.0)
	Events.spell_released.disconnect(cb)


func test_wheel_cancellations() -> void:
	print("\n[Wheel cancellations: dodge, stagger, UI, mana, no double cast, no stuck wheel]")
	var h := await castw(9)
	var el: MageElementalist = h.kit.el
	var released := [0]
	var cb := func(c, _sid, _e, _f, _t, _m): if c == h: released[0] += 1
	Events.spell_released.connect(cb)
	var cases := ["dodge", "stagger", "ui", "mana"]
	for k in cases:
		h.kit.mana = 100.0
		await until_idle(h)
		var r0: int = released[0]
		h.press("light")
		await wait(0.3)
		var mana0: float = h.kit.mana
		match k:
			"dodge":
				h.try_dodge()
			"stagger":
				h.stagger(0.3)
			"ui":
				Game.ui_block += 1
				h.release("light")
				Game.ui_block -= 1
			"mana":
				h.kit.mana = 0.0
				var o := el.wheel_options(0)
				el.wheel_select((o.find(el.cur.id) + 1) % o.size())
		await wait(0.1)
		if k == "mana":
			check(el.cur != null, "mana: switching to a spell you cannot afford is refused (current keeps charging)")
			h.release("light")
			await wait(0.6)
			check(released[0] == r0, "mana: releasing without enough mana casts nothing")
		else:
			check(el.cur == null and released[0] == r0 and absf(h.kit.mana - mana0) < 0.01, "%s during the charge: cancelled, no cast, no mana spent" % k)
		h.release("light")
		await wait(0.5)
		check(not el.wheel_open and not Game.wheel_open and el.wheel_slot == -1, "%s: no stuck wheel" % k)
	Events.spell_released.disconnect(cb)
	# no double cast on release
	h.kit.mana = 100.0
	await until_idle(h)
	var n0: int = released[0]
	Events.spell_released.connect(cb)
	h.press("light")
	await wait(0.6)
	h.release("light")
	h.release("light")
	await wait(0.5)
	check(released[0] == n0 + 1, "one release = one cast")
	Events.spell_released.disconnect(cb)
	# F / E / heal target untouched
	h.hp = h.max_hp * 0.4
	h.kit.mana = 100.0
	h.kit.cooldowns.clear()
	await until_idle(h)
	var hp0 := h.hp
	h.press("life")
	h.release("life")
	await wait(0.1)
	check(h.hp > hp0, "F (Lifeline) still heals")
	await test_wheel_review1()
	await test_wheel_defaults_review2()
	await test_instant_spell_augments_review2()
	await test_popup_waits_for_draft()


## 006 review 2: the Attribute Points / unlock popup never overlaps an open Augment draft; it is shown after.
func test_popup_waits_for_draft() -> void:
	print("\n[006 review 2: level-up popups wait while an Augment draft is open]")
	var holder := Node.new()
	add_child(holder)
	var draft := DraftUI.new()
	holder.add_child(draft)
	var pop := UnlockPopup.new()
	holder.add_child(pop)
	await get_tree().process_frame
	var m := {"kind": "stats", "level": 2, "name": "Attribute Points", "desc": "test", "icon": ""}
	pop.queue.append(m)
	await get_tree().process_frame
	await get_tree().process_frame
	check(pop.showing, "control: with no draft the popup shows at once")
	draft.is_open = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(not pop.showing and pop.queue.size() == 1, "a draft opening hides the popup and keeps it queued")
	await wait(0.5)
	check(not pop.showing, "nothing is shown while the draft stays open")
	draft.is_open = false
	await get_tree().process_frame
	await get_tree().process_frame
	check(pop.showing and pop.cur_m == m, "after the draft closes the same popup is shown in full")
	holder.queue_free()
	await get_tree().process_frame


## 006 review 2 bug fix: instant spells are known to the Augment runtime BEFORE their effect lands.
## Rewoven Spell judged a partial Thunder Conduit by the previous cast; Living Confluence never paid out on it.
func test_instant_spell_augments_review2() -> void:
	print("\n[006 review 2: Rewoven Spell / Living Confluence see the instant Thunder Conduit itself]")
	var fired: Array = []
	var cb := func(o, id, _d): if o == Game.player: fired.append(id)
	Events.augment_triggered.connect(cb)
	for case in ["ma03", "mf05"]:
		var h := await castw(10)
		Game.prog("mage").augments.append("ma03_rewoven_spell" if case == "ma03" else "mf05_living_confluence")
		h.refresh_stats(true)
		var el: MageElementalist = h.kit.el
		var a := dummy("raider", h.global_position + Vector3(0, 0, -6))
		var b2 := dummy("raider", h.global_position + Vector3(1.5, 0, -6.5))
		for e in [a, b2]:
			e.max_hp = 99999
			e.hp = 99999
		h.lock_target = a
		face(h, a)
		await wait(0.1)
		# a FULL Flame first (so the "previous spell" is not a partial Thunder Conduit)
		el.ai_spell = {"light": "flame_cataclysm"}
		h.press("light")
		await wait(1.4)
		h.release("light")
		await until_idle(h)
		await wait(0.8)
		h.kit.mana = 100.0
		if case == "mf05":
			h.rt.open("mf05", 4.0, {"element": "fire", "id": "thermal_fracture"})   # an interaction just happened
		fired.clear()
		el.ai_spell = {"light": "thunder_conduit"}
		h.press("light")
		await wait(0.35)
		h.release("light")
		await wait(0.3)
		var id := "ma03_rewoven_spell" if case == "ma03" else "mf05_living_confluence"
		check(fired.has(id), "%s activates on a partial Thunder Conduit cast right after a full Flame" % id)
		a.queue_free()
		b2.queue_free()
		el.ai_spell = {}
	Events.augment_triggered.disconnect(cb)


## 006 review 2: LMB = Offensive Elements, RMB = Life & Control by default; distinct at every level 1-10,
## never empty, grows with unlocks, Debug-only spells excluded, customization saved and resettable.
func test_wheel_defaults_review2() -> void:
	print("\n[006 review 2: distinct default wheels at every unlock level]")
	var expect := {1: [["flame_cataclysm"], ["life_bloom"]], 3: [["flame_cataclysm"], ["life_bloom", "crystal_formation"]],
		7: [["flame_cataclysm", "earthbreaker"], ["life_bloom", "crystal_formation"]],
		9: [["flame_cataclysm", "earthbreaker", "thunder_conduit"], ["life_bloom", "crystal_formation"]],
		10: [["flame_cataclysm", "earthbreaker", "thunder_conduit"], ["life_bloom", "crystal_formation"]]}
	for lvl in expect:
		var h := await castw(lvl)
		var el: MageElementalist = h.kit.el
		Game.prog("mage").wheel_sets = {}
		var l0: Array = el.wheel_options(0)
		var l1: Array = el.wheel_options(1)
		var ok: bool = l0.size() == expect[lvl][0].size() and l1.size() == expect[lvl][1].size()
		for id in expect[lvl][0]:
			ok = ok and l0.has(id)
		for id in expect[lvl][1]:
			ok = ok and l1.has(id)
		var shared := l0.filter(func(x): return l1.has(x))
		check(ok and shared.is_empty() and not l0.is_empty() and not l1.is_empty(), "Lv%d: LMB %s | RMB %s (distinct, none empty)" % [lvl, l0, l1])
		check(not (l0 + l1).any(func(x): return el.spells[x].advanced), "Lv%d: no Debug-only spell in the normal wheels" % lvl)
	# customization: saved, reloaded, and the default can be restored
	var h2 := await castw(9)
	var e2: MageElementalist = h2.kit.el
	var pr := Game.prog("mage")
	pr.wheel_sets = {}
	pr.set_wheel_member(1, "thunder_conduit", true, e2.wheel_options(1))
	var d := pr.to_dict()
	var p2 := ClassProgress.new("mage")
	p2.from_dict(d)
	check(p2.wheel_set(1).has("thunder_conduit") and p2.wheel_set(1).has("life_bloom") and p2.wheel_set(0).is_empty(), "a customized RMB wheel is saved and loaded (LMB stays default)")
	pr.wheel_sets.erase("1")
	check(_same(e2.wheel_options(1), e2.default_wheel(1)), "restoring the default group")
	# quick tap still casts each button's last spell; RMB's default is the heal
	check(e2.slot_spell(0) == "flame_cataclysm" and e2.slot_spell(1) == "life_bloom", "fresh loadout: LMB Flame, RMB Life Bloom")


## 006 review 1, Part 4: switching does not delay quick casts; the camera does not turn or snap around the
## wheel; emergency healing (F) stays usable while a wheel charge is held.
func test_wheel_review1() -> void:
	print("\n[006 review 1: quick casts after a switch, camera around the wheel, Lifeline during a held charge]")
	var h := await castw(9)
	var el: MageElementalist = h.kit.el
	var rel_t := [-1.0]
	var cb := func(c, _sid, _e, _f, _t, _m): if c == h and rel_t[0] < 0.0: rel_t[0] = Game.time
	Events.spell_released.connect(cb)
	var opts := el.wheel_options(0)
	var lmb0 := el.slot_spell(0)
	var other := ""
	for id in opts:
		if id != lmb0 and el.spells[id].element != "life":
			other = id
	# baseline: a quick tap of `other` when it is ALREADY the button's spell (no wheel involved)
	el.apply_slot(0, other, "wheel")
	h.kit.mana = 100.0
	await until_idle(h)
	rel_t[0] = -1.0
	var t0 := Game.time
	tap(h, "light")
	for i in 120:
		await get_tree().physics_frame
		if rel_t[0] >= 0.0:
			break
	var base_delay: float = rel_t[0] - t0
	# switch away and back through the wheel, then quick-tap again
	el.apply_slot(0, lmb0, "wheel")
	await until_idle(h)
	h.kit.mana = 100.0
	h.press("light")
	await wait(0.2)
	el.wheel_select(opts.find(other))
	await wait(0.6)
	h.release("light")
	await until_idle(h)
	await wait(0.3)
	h.kit.mana = 100.0
	rel_t[0] = -1.0
	t0 = Game.time
	tap(h, "light")
	for i in 120:
		await get_tree().physics_frame
		if rel_t[0] >= 0.0:
			break
	var after_delay: float = rel_t[0] - t0
	check(base_delay >= 0.0 and after_delay >= 0.0 and absf(after_delay - base_delay) < 0.02, "a quick tap after a wheel switch casts as fast as a normal tap (%.2fs vs %.2fs)" % [after_delay, base_delay])
	Events.spell_released.disconnect(cb)
	# camera: mouse motion while the wheel is open does not turn it; no snap when it closes
	await until_idle(h)
	var rig := _rig()
	h.kit.mana = 100.0
	h.press("light")
	await wait(0.25)
	var yaw0: float = rig.yaw
	var pitch0: float = rig.pitch
	for i in 10:
		var ev := InputEventMouseMotion.new()
		ev.relative = Vector2(40, 15)
		rig._unhandled_input(ev)
		await get_tree().physics_frame
	check(el.wheel_open and absf(wrapf(rig.yaw - yaw0, -PI, PI)) < 0.01 and absf(rig.pitch - pitch0) < 0.01, "mouse motion while the wheel is open does not turn the camera")
	h.release("light")
	var max_step := 0.0
	var prev: float = rig.yaw
	for i in 20:
		await get_tree().physics_frame
		max_step = maxf(max_step, absf(wrapf(rig.yaw - prev, -PI, PI)))
		prev = rig.yaw
	check(max_step < 0.02, "no camera snap when the wheel closes (largest yaw step %.3f rad)" % max_step)
	await until_idle(h)
	# Lifeline (F) while a wheel charge is held
	h.hp = h.max_hp * 0.4
	h.kit.mana = 100.0
	h.kit.cooldowns.clear()
	h.press("light")
	await wait(0.3)
	var hp1 := h.hp
	h.press("life")
	h.release("life")
	await wait(0.15)
	check(h.hp > hp1, "Lifeline (F) heals while a wheel charge is held")
	h.release("light")
	await wait(0.6)
	check(not el.wheel_open and not Game.wheel_open, "no stuck wheel after using Lifeline mid-charge")

func test_ui_clarity() -> void:
	print("\n[UI clarity: short skill tooltips with real +1 previews; one-sentence augment cards]")
	var h := await bd(10)
	var p := Game.prog("reaver")
	p.free_points = 2
	h.refresh_stats(true)
	var src := TooltipText.source_for_hero(h)
	var ent: Dictionary = {}
	for e in SkillCatalog.entries("reaver"):
		if e.id == "bd_committed":
			ent = e
	var full: AttackData = ent.variants[1].attack
	var predicted: float = TooltipText.breakdown_attack(TooltipText.with_stat(src, "str", 1.0), full).noncrit
	p.allocate("str")
	h.refresh_stats(true)
	var real: float = TooltipText.breakdown_attack(TooltipText.source_for_hero(h), full).noncrit
	check(absf(predicted - real) < 0.01, "'+1 STR' preview %.2f = value after really allocating the point %.2f" % [predicted, real])
	var simple := TooltipText.skill(ent, TooltipText.source_for_hero(h), TooltipText.LEVEL_SIMPLE)
	check(simple.split("\n").size() <= 7, "Committed Cut simple tooltip: %d lines" % simple.split("\n").size())
	check(simple.contains("[color=#%s]STR" % StatStyle.hex(StatStyle.stat_color("str"))), "the STR scaling numbers are written in the STR colour (with the STR label)")
	check(not simple.contains("Phases") and not simple.contains("Formula") and not simple.contains("Critical"), "no formula / phases / crit text in the default tooltip")
	var det := TooltipText.skill(ent, TooltipText.source_for_hero(h), TooltipText.LEVEL_DETAILED)
	check(det.contains("Weapon Power") and det.length() > simple.length(), "Shift adds the calculation")
	var bad := 0
	var long := 0
	for a in Game.augment_db.all.values():
		if a.pool != "l10":
			continue
		var s := AugmentText.short(a, false)
		if a.short_text == "" or s.contains("{"):
			bad += 1
		if s.split(" ").size() > 24:
			long += 1
			print("    long: ", a.id, " (", s.split(" ").size(), " words)")
	check(bad == 0, "every card has a resolved one-sentence text")
	check(long == 0, "every card sentence is 24 words or fewer")
	var g01: AugmentData = Game.augment_db.get_augment("g01_second_wind")
	var col := AugmentText.short(g01)
	check(col.contains(StatStyle.hex(StatStyle.EFFECT.stamina)) and col.contains("25%") and col.contains("Stamina"), "values are coloured by meaning (Stamina value in the Stamina colour) and still labelled")
	g01.params["stamina_off"] = 0.3
	check(AugmentText.short(g01, false).contains("30%"), "the card number comes from the resource (30% after changing it)")
	g01.params["stamina_off"] = 0.25

func _same(a: Array, b: Array) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.sort()
	y.sort()
	return x == y
