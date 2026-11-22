extends "res://tests/test_runner.gd"
## COMBAT-BALANCE-UX-006 review 2, Part 2: Worldweaver stat-scaling comparison (CALCULATION tool, not in
## Test.ps1; changes no game formula). Real Mages are built with ClassProgress + StatBlock (levels 1/4/8/10,
## starter gear, all free points spent by one strategy). Option A uses the LIVE formulas (DamageCalc /
## StatBlock). Options B and C apply the alternative rules written below to the same stat blocks.
##   godot --headless res://tests/mage_scaling_compare.tscn
##
## A (current): full-charge damage x (1 + 0.03 STR); partial damage unscaled; Thunder chains x (1 + 0.03 DEX);
##   DoT / HoT / shields x (1 + 0.04 MAS); direct heals unscaled.
## B (MAS magic): ALL direct charged damage (partial and full) x (1 + 0.025 MAS) instead of STR; DoT / HoT /
##   shields keep x (1 + 0.04 MAS); direct heals unscaled. (0.025 < 0.03: safeguard because MAS also powers support.)
## C (five roles): STR -> full-charge damage x (1 + 0.03 STR) (unchanged: "charged power"); DEX -> PARTIAL
##   (quick) release damage x (1 + 0.03 DEX) and chains (unchanged); MAS -> elemental effects: DoT / HoT /
##   shields x (1 + 0.04 MAS) AND direct heals x (1 + 0.02 MAS); VIT HP; FOR defence (unchanged).

const LEVELS := [1, 4, 8, 10]
const PLANS := ["none", "STR", "DEX", "MAS", "VIT", "FOR", "STR+MAS"]


func _run_all() -> void:
	var sp := {}
	for id in ["flame_cataclysm", "earthbreaker", "thunder_conduit", "life_bloom", "protective_renewal"]:
		sp[id] = load("res://data/mage_spells/%s.tres" % id)
	var b := Game.balance
	var rows: Array = []
	for lvl in LEVELS:
		for plan in PLANS:
			if lvl == 1 and plan != "none":
				continue
			var p := ClassProgress.new("mage")
			p.created = true
			p.set_level(lvl)
			for it in Game.starter_items("mage"):
				p.equipment[it.slot] = it.id
			var pts := p.free_points
			var order: Array = []
			match plan:
				"none": order = []
				"STR+MAS": order = ["str", "mas"]
				_: order = [plan.to_lower()]
			var i := 0
			while pts > 0 and not order.is_empty():
				p.allocate(order[i % order.size()])
				pts -= 1
				i += 1
			var s := StatBlock.for_class("mage", p, b)
			var wp := StatPreview.weapon_power("mage", p)
			for opt in ["A", "B", "C"]:
				var full_m := s.heavy_mult()
				var part_m := 1.0
				var heal_m := 1.0
				var eff := s.effect_power()
				if opt == "B":
					full_m = 1.0 + 0.025 * s.mastery
					part_m = full_m
				elif opt == "C":
					part_m = 1.0 + 0.03 * s.dexterity
					heal_m = 1.0 + 0.02 * s.mastery
				var fl_p: float = wp * sp.flame_cataclysm.power_partial * part_m
				var fl_f: float = wp * sp.flame_cataclysm.power_full * full_m
				var eb_f: float = wp * sp.earthbreaker.power_full * full_m
				var th_f: float = wp * sp.thunder_conduit.power_full * full_m
				var chain: float = 0.0
				for j in sp.thunder_conduit.chains_full:
					chain += wp * DamageCalc.chain_power(s, sp.thunder_conduit.power_full * full_m, sp.thunder_conduit.chain_falloff, j) / sp.thunder_conduit.power_full / full_m * full_m
				var dot: float = wp * 1.0 * eff          # Burning Area / interaction DoT per unit power
				var bloom: float = wp * sp.life_bloom.power_full * heal_m
				var hot: float = wp * 1.0 * eff
				var shield: float = wp * sp.protective_renewal.power_partial * eff
				var line := "SCALE | %s | Lv%-2d | %-7s | STR %2d DEX %2d MAS %2d VIT %2d FOR %2d | Flame partial %5.1f full %5.1f | Earthbreaker %5.1f | Thunder %5.1f +chains %5.1f | DoT/unit %5.1f | Bloom heal %5.1f | HoT/unit %5.1f | Shield %5.1f | HP %4d | MR red %2d%%" % [
					opt, lvl, plan, roundi(s.strength), roundi(s.dexterity), roundi(s.mastery), roundi(s.vitality), roundi(s.fortitude),
					fl_p, fl_f, eb_f, th_f, chain, dot, bloom, hot, shield, roundi(s.max_hp()), roundi(100.0 * s.magic_reduction())]
				rows.append(line)
	print("\n==== MAGE SCALING COMPARISON ====")
	for r in rows:
		print(r)
	check(true, "calculation done")
