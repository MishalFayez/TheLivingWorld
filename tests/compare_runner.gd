extends "res://tests/test_runner.gd"
## BUTTON-SPAM INVESTIGATION + OLD vs NEW (design resolution 2, refoundation spec 23).
## Same Lv10 Reaver, same frozen Raider (99999 HP), 6 seconds per run, crits disabled.
## Prints objective numbers only; it does not judge feel.
##   godot --headless --fixed-fps 60 res://tests/compare_runner.tscn

var rows: Array = []
var executed: int = 0
var hits: int = 0
var startups: Array = []
var recoveries: Array = []
var links_n: int = 0


func _run_all() -> void:
	Events.blade_transition.connect(func(_h, _a, _b, legal): if legal: links_n += 1)
	await run("sense", "spam", "OLD Sword Sense: LMB every 0.25s")
	await run("swordmaster", "spam", "NEW: LMB every 0.25s (Forward->Forward)")
	await run("swordmaster", "spam_fast", "NEW: LMB every 0.10s (mash)")
	await run("swordmaster", "paths", "NEW: deliberate paths (F, L, F, R, heavy...)")
	await run("swordmaster", "paths_timed", "NEW: deliberate paths pressed in the link window")
	print("\n==== BUTTON-SPAM INVESTIGATION (Reaver Lv10, frozen Raider, 6s) ====")
	var keys: Array = rows[0].keys()
	for k in keys:
		var line: String = str(k)
		for r in rows:
			line += " | " + str(r[k])
		print(line)
	print("\n==== COMPARE: done ====")
	await teardown()


func run(core: String, mode: String, label: String) -> void:
	var h := await setup("reaver", false, false, false)
	Game.reaver_core = core
	Game.set_level("reaver", 10)
	await wait(0.3)
	h.restore_all()
	h.stats.crit_chance = 0.0
	var r := dummy("raider", h.global_position + Vector3(0, 0, -2.2))
	r.max_hp = 99999
	r.hp = 99999
	h.lock_target = r
	face(h, r)
	executed = 0
	hits = 0
	links_n = 0
	startups.clear()
	recoveries.clear()
	var c1 := func(d, _ctx):
		executed += 1
		startups.append(d.startup)
		recoveries.append(d.recovery)
	var c2 := func(_t, _i): hits += 1
	h.runner.started.connect(c1)
	h.runner.hit_landed.connect(c2)
	var hp0 := r.hp
	var p0 := h.global_position
	var inputs := 0
	var buffered := 0
	var stamina_used := 0.0
	var committed := 0
	var frames := 360
	var seq := ["forward", "left", "forward", "right", "heavy"]
	var si := 0
	var next_press := 0
	var last_st := h.stamina
	for f in frames:
		if f >= next_press:
			var want: String = "forward"
			if mode.begins_with("paths"):
				want = seq[si % seq.size()]
			var ready := h.can_act()
			var press_ok := true
			if mode == "paths_timed":
				# press only when the previous attack can be cancelled (link window) or idle
				press_ok = ready
			if press_ok:
				inputs += 1
				if not ready:
					buffered += 1
				if want == "heavy":
					tap(h, "heavy")
				else:
					if want != "forward":
						h.held["blade_modifier"] = true
						h.strafe_axis = -1.0 if want == "left" else 1.0
					tap(h, "light")
					h.held["blade_modifier"] = false
					h.strafe_axis = 0.0
				si += 1
				next_press = f + (6 if mode == "spam_fast" else (15 if mode in ["spam", "paths"] else 1))
		await get_tree().physics_frame
		if h.runner.is_busy():
			committed += 1
		stamina_used += maxf(0.0, last_st - h.stamina)
		last_st = h.stamina
	await wait(0.6)
	var dmg := hp0 - r.hp
	h.runner.started.disconnect(c1)
	h.runner.hit_landed.disconnect(c2)
	var avg := func(a: Array) -> float:
		var s := 0.0
		for x in a:
			s += float(x)
		return s / maxf(1.0, a.size())
	rows.append({
		"run": label,
		"attack inputs": inputs,
		"executed attacks": executed,
		"successful hits": hits,
		"inputs buffered": buffered,
		"avg startup (s)": "%.3f" % avg.call(startups),
		"avg recovery (s)": "%.3f" % avg.call(recoveries),
		"legal transitions (links)": links_n,
		"total damage": roundi(dmg),
		"DPS": "%.1f" % (dmg / 6.0),
		"damage per stamina": "%.2f" % (dmg / maxf(1.0, stamina_used)),
		"stamina used": roundi(stamina_used),
		"time committed / vulnerable (s)": "%.2f" % (committed / 60.0),
		"displacement (m)": "%.2f" % h.global_position.distance_to(p0),
	})
	r.queue_free()
