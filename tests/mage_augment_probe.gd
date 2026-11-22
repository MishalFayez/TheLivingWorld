extends "res://tests/test_runner.gd"
## COMBAT-BALANCE-UX-006 review 2, Part 3: Worldweaver Augment activation in REAL elemental sequences
## (measurement tool, not in Test.ps1). A Level 10 Mage (natural unlocks, starter gear) repeats one spell
## sequence for 24 s against stationary Raiders 7 m away (huge HP; 3 Raiders for the multi-enemy rows).
## Every spell is charged to FULL unless the sequence says "partial". Crystal Formation rises between the
## Mage and the Raider (its normal intercept placement), so the following spell meets the ice.
##   godot --headless --fixed-fps 60 res://tests/mage_augment_probe.tscn

const SEQS := {
	"Q1 ice>flame>thunder": [["heavy", "crystal_formation", true], ["light", "flame_cataclysm", true], ["light", "thunder_conduit", true]],
	"Q2 ice>earth>flame": [["heavy", "crystal_formation", true], ["light", "earthbreaker", true], ["light", "flame_cataclysm", true]],
	"Q3 ice>thunder>flame": [["heavy", "crystal_formation", true], ["light", "thunder_conduit", true], ["light", "flame_cataclysm", true]],
	"Q4 flame>thunder>earth (no ice)": [["light", "flame_cataclysm", true], ["light", "thunder_conduit", true], ["light", "earthbreaker", true]],
	"Q5 partial thunder x3 (3 foes)": [["light", "thunder_conduit", false]],
	"Q6 ice>flame PARTIAL>thunder": [["heavy", "crystal_formation", true], ["light", "flame_cataclysm", false], ["light", "thunder_conduit", true]],
	"Q7 flame>partial thunder (3 foes)": [["light", "flame_cataclysm", true], ["light", "thunder_conduit", false]],
	"Q8 ice>bloom(self)>flame": [["heavy", "crystal_formation", true], ["heavy", "life_bloom", true], ["light", "flame_cataclysm", true]],
}
## [sequence, build, Crossroads choice ("" = default thermal_fracture)]
const ROWS := [
	["Q1 ice>flame>thunder", "none", ""], ["Q1 ice>flame>thunder", "A1 Crossroads", ""], ["Q1 ice>flame>thunder", "M-F05 Confluence", ""],
	["Q1 ice>flame>thunder", "A3 syn", ""], ["Q1 ice>flame>thunder", "B1 Threading", ""], ["Q1 ice>flame>thunder", "B3 syn", ""],
	["Q6 ice>flame PARTIAL>thunder", "none", ""], ["Q6 ice>flame PARTIAL>thunder", "A1 Crossroads", ""], ["Q6 ice>flame PARTIAL>thunder", "A3 syn", ""],
	["Q2 ice>earth>flame", "none", ""], ["Q2 ice>earth>flame", "A1 Crossroads", "shattered_winter"], ["Q2 ice>earth>flame", "M-F05 Confluence", ""],
	["Q2 ice>earth>flame", "A3 syn", "shattered_winter"], ["Q2 ice>earth>flame", "B1 Threading", ""],
	["Q3 ice>thunder>flame", "none", ""], ["Q3 ice>thunder>flame", "A1 Crossroads", "conductive_anchors"], ["Q3 ice>thunder>flame", "M-F05 Confluence", ""],
	["Q3 ice>thunder>flame", "B1 Threading", ""],
	["Q8 ice>bloom(self)>flame", "none", ""], ["Q8 ice>bloom(self)>flame", "A1 Crossroads", "living_bastion"], ["Q8 ice>bloom(self)>flame", "M-F05 Confluence", ""],
	["Q4 flame>thunder>earth (no ice)", "none", ""], ["Q4 flame>thunder>earth (no ice)", "A3 syn", ""], ["Q4 flame>thunder>earth (no ice)", "B3 syn", ""],
	["Q5 partial thunder x3 (3 foes)", "none", ""], ["Q5 partial thunder x3 (3 foes)", "M-A03 Rewoven", ""], ["Q5 partial thunder x3 (3 foes)", "B3 syn", ""],
	["Q7 flame>partial thunder (3 foes)", "none", ""], ["Q7 flame>partial thunder (3 foes)", "M-A03 Rewoven", ""],
]
const BUILDS := {
	"none": [], "A1 Crossroads": ["mf01_elemental_crossroads"], "M-F05 Confluence": ["mf05_living_confluence"],
	"A3 syn": ["mf01_elemental_crossroads", "mf03_thermal_fracture", "mf05_living_confluence"],
	"B1 Threading": ["ma01_spell_threading"], "M-A03 Rewoven": ["ma03_rewoven_spell"],
	"B3 syn": ["ma01_spell_threading", "mc05_dual_invocation", "ma03_rewoven_spell"],
}
const DUR := 24.0

var inter_n := 0
var trig: Dictionary = {}
var dealt := 0.0
var casts := 0
var charge_sum := 0.0


func _run_all() -> void:
	Events.elemental_interaction.connect(func(c, _id, _d): if c == Game.player: inter_n += 1)
	Events.augment_triggered.connect(func(o, id, _d): if o == Game.player and Game.augment_db.get_augment(id) != null and Game.augment_db.get_augment(id).pool == "l10": trig[id] = int(trig.get(id, 0)) + 1)
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.source == Game.player and info.target is Enemy: dealt += info.final_amount)
	Events.spell_released.connect(func(c, _sid, _e, _full, t, _m): if c == Game.player:
		casts += 1
		charge_sum += float(t))
	var out: Array = []
	for row in ROWS:
		out.append(await _run(String(row[0]), String(row[1]), String(row[2])))
	print("\n==== MAGE AUGMENT PROBE ====")
	for l in out:
		print(l)
	check(true, "measurement done")


func _run(q: String, bname: String, choice: String = "") -> String:
	seed(5)
	Game.rng.seed = 5
	var h := await setup("mage", false, false, false)
	Game.mage_core = "elementalist"
	Game.set_level("mage", 10)
	Game.prog("mage").pending_drafts = 0
	Game.prog("mage").pending_draft_tiers.clear()
	for id in BUILDS[bname]:
		Game.prog("mage").augments.append(id)
	Game.prog("mage").crossroads_choice = choice
	await wait(0.3)
	h.refresh_stats(true)
	h.restore_all()
	for c in h.get_children():
		if c is PlayerBrain:
			c.set_physics_process(false)
	var foes: Array = []
	var n := 3 if q.contains("3 foes") else 1
	for i in n:
		var e := dummy("raider", h.global_position + Vector3(-2.0 + 2.0 * i if n > 1 else 0.0, 0, -7.0))
		e.max_hp = 999999
		e.hp = 999999
		foes.append(e)
	h.lock_target = foes[0]
	face(h, foes[0])
	var el: MageElementalist = h.kit.el
	inter_n = 0
	trig.clear()
	dealt = 0.0
	casts = 0
	charge_sum = 0.0
	var mana_used := 0.0
	var seq: Array = SEQS[q]
	var k := 0
	var t := 0.0
	while t < DUR:
		var step: Array = seq[k % seq.size()]
		k += 1
		await until_idle(h)
		h.kit.mana = maxf(h.kit.mana, 0.0)
		var m0: float = h.kit.mana
		el.ai_spell = {String(step[0]): String(step[1])}
		if String(step[1]) == "life_bloom":
			el.set_heal_target(h)
		h.lock_target = foes[0]
		h.press(String(step[0]))
		var frames := 0
		while frames < 300:
			await get_tree().physics_frame
			frames += 1
			if el.cur == null:
				break
			if bool(step[2]) and el.is_full():
				break
			if not bool(step[2]) and el.charge_t >= el.cur.min_charge * el.cur_mods.get("min", 1.0) + 0.02:
				break
		h.release(String(step[0]))
		await wait(0.05)
		mana_used += maxf(0.0, m0 - h.kit.mana)
		h.kit.mana = 100.0      # mana is measured, not limiting
		t += frames / 60.0 + 0.05 + 0.35
		await wait(0.35)
	var top: Array = trig.keys()
	top.sort()
	var line := "MAGEAUG | %-34s | %-17s %-18s | casts %2d | avg charge %.2fs | mana/cast %4.1f | interactions %2d | DPS %6.1f | triggers %s" % [
		q, bname, choice, casts, charge_sum / maxf(1, casts), mana_used / maxf(1, casts), inter_n, dealt / DUR,
		", ".join(top.map(func(id): return "%s %d" % [String(id).get_slice("_", 0), int(trig[id])]))]
	print(line)
	for e in foes:
		if is_instance_valid(e):
			e.queue_free()
	return line


func until_idle(h: Hero, limit: float = 2.0) -> void:
	var n := 0
	while (h.runner.is_busy() or h.dodging or h.kit.charging != "") and n < int(limit * 60):
		await get_tree().physics_frame
		n += 1
