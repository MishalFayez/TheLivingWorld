extends "res://tests/test_runner.gd"
## COMBAT-BALANCE-UX-006 review 1, Part 3: Precise Defense (V-K02) +0.03s vs +0.08s (measurement tool, not
## in Test.ps1). A Level 10 Vanguard (Bulwark Mastery: base window 0.20 x 1.35 = 0.27s) raises a FRESH guard
## before a real Raider Combo I hit. The guard lead time follows seeded human-like timing profiles; the same
## leads are replayed for every configuration, so only the window differs. "bonus" rows measure ONE use of the
## card (it applies once, to the next Perfect Guard within 4s, then has a 10s cooldown).
##   godot --headless --fixed-fps 60 res://tests/precise_defense_probe.tscn

const PROFILES := {"skilled": [0.12, 0.06], "average": [0.15, 0.09], "casual": [0.18, 0.13]}
const N := 80

var perfect_seen := false


func _run_all() -> void:
	Events.guard_event.connect(func(d, _i, k): if d == Game.player and k == "perfect": perfect_seen = true)
	var out: Array = []
	for prof in PROFILES:
		var rng := RandomNumberGenerator.new()
		rng.seed = 6
		var leads: Array = []
		for i in N:
			leads.append(rng.randfn(PROFILES[prof][0], PROFILES[prof][1]))
		var res := {}
		for cfg in ["base", "0.03", "0.08"]:
			res[cfg] = await _measure(leads, cfg)
		out.append("PRECISE DEFENSE | %-7s (lead %.2f +/- %.2fs) | Perfect Guards: base %d%% | +0.03 %d%% | +0.08 %d%%" % [prof, PROFILES[prof][0], PROFILES[prof][1], roundi(100.0 * res.base / N), roundi(100.0 * res["0.03"] / N), roundi(100.0 * res["0.08"] / N)])
	print("\n==== PRECISE DEFENSE PROBE ====")
	for l in out:
		print(l)
	check(true, "measurement done")


func _measure(leads: Array, cfg: String) -> int:
	var h := await setup("vanguard", false, false, false)
	Game.set_level("vanguard", 10)
	Game.prog("vanguard").pending_drafts = 0
	Game.prog("vanguard").pending_draft_tiers.clear()
	var a: AugmentData = Game.augment_db.get_augment("vk02_precise_defense")
	var original: float = float(a.params.get("extra_window", 0.03))
	if cfg != "base":
		a.params["extra_window"] = float(cfg)
		Game.prog("vanguard").augments.append("vk02_precise_defense")
	await wait(0.3)
	h.refresh_stats(true)
	for c in h.get_children():
		if c is PlayerBrain:
			c.set_physics_process(false)
	var ok := 0
	for lead in leads:
		h.max_hp = 99999
		h.hp = 99999
		h.stamina = h.max_stamina
		var e := dummy("raider", h.global_position + Vector3(0, 0, -1.9))
		e.target = h
		face(e, h)
		face(h, e)
		await wait(0.1)
		if cfg != "base":
			h.rt.open("vk02", 4.0)
		var d: AttackData = e.find_attack("raider_combo1")
		perfect_seen = false
		e.begin_attack(d)
		var startup: float = d.startup / e.runner.speed
		var pressed := false
		var t := 0.0
		while t < startup + d.active + 0.25:
			if not pressed and t >= startup - float(lead):
				pressed = true
				h.press("guard")
			await get_tree().physics_frame
			t += 1.0 / 60.0
		h.release("guard")
		if perfect_seen:
			ok += 1
		e.queue_free()
		await wait(0.35)
	a.params["extra_window"] = original
	Game.prog("vanguard").augments.erase("vk02_precise_defense")
	return ok
