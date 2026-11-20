extends SceneTree
## Regenerates every data Resource (.tres) under res://data from the tables below.
## Run:  godot --headless --script res://tools/generate_data.gd
## After generation the .tres files are the source of truth — edit them in the Inspector.
## (Re-running this tool overwrites them with these defaults.)



func _init() -> void:
	_balance()
	_attacks()
	_skills()
	_spells()
	_mage_spells()
	_fusions()
	_augments()
	_progression()
	_items()
	print("Data generation complete.")
	quit()


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (%d)" % [path, err])


# ------------------------------------------------------------------ balance
func _balance() -> void:
	var b := BalanceConfig.new()
	b.class_base = {
		"vanguard": {"str": 8, "dex": 5, "vit": 12, "for": 12, "mas": 4, "hp": 200, "crit": 0.05, "critdmg": 1.5, "aspd": 1.0, "cdr": 0.0, "armor": 40, "mres": 25, "power": 18.0, "poise": 90.0},
		"mage": {"str": 3, "dex": 4, "vit": 6, "for": 5, "mas": 12, "hp": 140, "crit": 0.08, "critdmg": 1.5, "aspd": 1.0, "cdr": 0.0, "armor": 12, "mres": 35, "power": 20.0, "poise": 40.0},
		"reaver": {"str": 10, "dex": 10, "vit": 7, "for": 5, "mas": 3, "hp": 160, "crit": 0.12, "critdmg": 1.6, "aspd": 1.1, "cdr": 0.0, "armor": 22, "mres": 15, "power": 21.0, "poise": 55.0},
	}
	b.class_growth = {
		"vanguard": {"str": 1, "dex": 0, "vit": 2, "for": 2, "mas": 0, "armor": 3, "mres": 2},
		"mage": {"str": 0, "dex": 0, "vit": 1, "for": 1, "mas": 2, "armor": 1, "mres": 2},
		"reaver": {"str": 1, "dex": 1, "vit": 1, "for": 0, "mas": 0, "armor": 1, "mres": 1},
	}
	_save(b, "res://data/balance/balance.tres")


# ------------------------------------------------------------------ attacks
func atk(id: String, nm: String, style: String, s: float, a: float, r: float, dmg: float, poise: float, extra: Dictionary = {}) -> AttackData:
	var d := AttackData.new()
	d.id = id
	d.display_name = nm
	d.anim_style = style
	d.startup = s
	d.active = a
	d.recovery = r
	d.damage_mult = dmg
	d.poise_damage = poise
	for k in extra:
		d.set(k, extra[k])
	_save(d, "res://data/attacks/%s.tres" % id)
	return d


func _attacks() -> void:
	var T := func(arr: Array) -> PackedStringArray: return PackedStringArray(arr)
	# ---------------- Vanguard
	atk("v_light1", "Sword Cut", "slash_h", 0.2, 0.12, 0.32, 0.9, 12, {"approach_max": 1.2, "approach_range": 1.6, "cancel_after": 0.12, "stamina_cost": 10, "tags": T.call(["light"])})
	atk("v_light2", "Return Cut", "slash_h", 0.18, 0.12, 0.36, 1.0, 14, {"approach_max": 0.8, "approach_range": 1.6, "cancel_after": 0.12, "stamina_cost": 10, "tags": T.call(["light"])})
	atk("v_heavy", "Shieldbreaker Slash", "slash_v", 0.45, 0.15, 0.5, 2.0, 40, {"approach_max": 1.8, "approach_range": 1.8, "approach_window": 0.8, "is_heavy": true, "stamina_cost": 20, "hitstop": 0.1, "poise_armor": 0.5, "knockback": 4.0, "cancel_after": 0.3, "tags": T.call(["heavy"]), "hitbox_size": Vector3(2.2, 1.8, 2.2), "hitbox_offset": Vector3(0, 1, -1.4)})
	# Guarded Strike (design resolution 6): short sword attack FROM Guard; lower damage than the heavy;
	# protection is reduced during the motion (see VanguardKit.modify_incoming)
	atk("v_guarded_strike", "Guarded Strike", "slash_h", 0.16, 0.1, 0.3, 0.8, 10, {"approach_max": 0.4, "approach_range": 1.6, "cancel_after": 0.14, "stamina_cost": 12, "tags": T.call(["light", "guarded_strike"]), "hitbox_size": Vector3(1.8, 1.6, 2.0), "hitbox_offset": Vector3(0, 1, -1.3)})
	atk("v_plant_exit", "Shield Plant (recover)", "bash", 0.02, 0.02, 0.35, 0.0, 0, {"hits": 0, "stamina_cost": 0, "dodge_cancel": false, "tags": T.call(["plant_exit"])})
	atk("v_counter", "Aegis Counter", "bash", 0.1, 0.15, 0.3, 1.6, 55, {"approach_max": 0.8, "approach_range": 1.6, "stamina_cost": 5, "hitstop": 0.12, "knockback": 5.0, "tags": T.call(["counter"]), "hitbox_size": Vector3(2.2, 1.8, 1.8)})
	atk("v_shield_rush", "Shield Rush", "bash", 0.15, 0.45, 0.35, 0.9, 30, {"lunge": 14.0, "stamina_cost": 15, "threat_mult": 4.0, "knockback": 6.0, "frontal_guard": 0.3, "dodge_cancel": false, "tags": T.call(["skill", "charge_attack"]), "hitbox_size": Vector3(2.0, 1.8, 1.6), "hitbox_offset": Vector3(0, 1, -1.0)})
	atk("v_shield_rush_emp", "Shield Rush (Empowered)", "bash", 0.15, 0.5, 0.35, 1.4, 60, {"lunge": 17.0, "stamina_cost": 15, "threat_mult": 5.0, "knockback": 9.0, "frontal_guard": 0.4, "stagger_on_hit": 0.6, "dodge_cancel": false, "tags": T.call(["skill", "charge_attack"]), "hitbox_size": Vector3(2.4, 1.8, 1.8), "hitbox_offset": Vector3(0, 1, -1.0)})
	atk("v_judgment", "Judgment Strike", "slam", 0.45, 0.15, 0.6, 2.4, 55, {"approach_max": 1.5, "approach_range": 1.9, "approach_window": 0.8, "is_heavy": true, "charge_time": 1.2, "charge_damage_bonus": 1.6, "charge_poise_bonus": 50.0, "stamina_cost": 22, "hitstop": 0.14, "poise_armor": 0.7, "knockback": 5.0, "tags": T.call(["skill", "heavy", "charge_attack"]), "hitbox_size": Vector3(2.4, 1.8, 2.6), "hitbox_offset": Vector3(0, 1, -1.6)})
	atk("v_judgment_riposte", "Judgment Strike: Riposte", "slam", 0.15, 0.15, 0.45, 3.2, 80, {"approach_max": 1.2, "approach_range": 1.9, "is_heavy": true, "crit_chance_bonus": 1.0, "stamina_cost": 10, "hitstop": 0.16, "knockback": 6.0, "tags": T.call(["skill", "heavy", "riposte"]), "hitbox_size": Vector3(2.4, 1.8, 2.6), "hitbox_offset": Vector3(0, 1, -1.6)})
	atk("v_iron_sweep", "Iron Sweep", "spin", 0.25, 0.45, 0.4, 1.8, 36, {"hits": 3, "stamina_cost": 18, "threat_mult": 2.0, "tags": T.call(["skill", "multi"]), "hitbox_size": Vector3(4.6, 1.6, 4.6), "hitbox_offset": Vector3(0, 1, 0)})
	atk("v_iron_sweep_guarded", "Guarded Sweep", "spin", 0.25, 0.4, 0.4, 1.4, 30, {"hits": 2, "stamina_cost": 18, "threat_mult": 2.5, "frontal_guard": 0.6, "tags": T.call(["skill", "multi", "guarded"]), "hitbox_size": Vector3(4.2, 1.6, 4.2), "hitbox_offset": Vector3(0, 1, 0)})
	# ---------------- Reaver: SWORDMASTER (refoundation spec 7) - only the specified augments.
	# Finality is NOT implemented: it modifies Final Stroke, which has no approved definition.
	aug("flowing_edge", "Flowing Edge", "reaver", "enhancement", "standard",
		"Movement during eligible multi-hit techniques: you can move at 55% speed (and steer) during attacks with 3 or more hits (Tempest Flurry).",
		{"move_fraction": 0.55, "requires_core": "swordmaster"},
		{"requires_skills": ["r_flurry"], "build_tags": ["Flowblade"], "interacts_with": "Tempest Flurry."})
	aug("crosswind", "Crosswind", "reaver", "enhancement", "standard",
		"Allows a LINKED opposite-direction cut: Lateral Cut left can link into Lateral Cut right (and back), normally an illegal transition.",
		{"requires_core": "swordmaster"},
		{"build_tags": ["Flowblade"], "interacts_with": "Lateral Cuts, Blade Continuity."})
	aug("unbroken_line", "Unbroken Line", "reaver", "synergy", "advanced",
		"Preserves one attack continuation through a Dodge: dodging out of a sequence keeps your next attack LINKED (within 0.45s after the dodge).",
		{"window": 0.45, "requires_core": "swordmaster"},
		{"build_tags": ["Flowblade", "Duelist"], "interacts_with": "Dodge, Blade Continuity, Slip Cut."})
	aug("sundering_verdict", "Sundering Verdict", "reaver", "conditional", "advanced",
		"Heavy Cut or Draw Cut hitting a RAISED GUARD weakens it for 4s: the guard blocks much less of your attacks (Shield Guardian).",
		{"duration": 4.0, "requires_core": "swordmaster"},
		{"build_tags": ["Breaker"], "interacts_with": "Heavy Cut, Draw Cut vs guarding enemies (only the Shield Guardian has a guard)."})
	aug("drawn_horizon", "Drawn Horizon", "reaver", "mutation", "advanced",
		"MUTATION: Draw Cut becomes a longer (x1.6), narrower (x0.55) line.",
		{"length_mult": 1.6, "width_mult": 0.55, "requires_core": "swordmaster"},
		{"requires_skills": ["r_draw"], "build_tags": ["Breaker"], "interacts_with": "Draw Cut (hold RMB, Lv7)."})
	aug("measured_step", "Measured Step", "reaver", "enhancement", "standard",
		"After a Piercing Lunge connects, Dodge within 0.6s becomes a short controlled step (no invulnerability, 6 Stamina) instead of a roll.",
		{"window": 0.6, "stamina": 6.0, "speed": 6.0, "requires_core": "swordmaster"},
		{"requires_skills": ["r_lunge"], "build_tags": ["Duelist"], "interacts_with": "Piercing Lunge, Dodge."})
	aug("turning_steel", "Turning Steel", "reaver", "synergy", "advanced",
		"After a Lateral Cut's footwork, your next LINKED attack turns toward your movement input instead of staying on the target line.",
		{"requires_core": "swordmaster"},
		{"build_tags": ["Duelist", "Flowblade"], "interacts_with": "Lateral Cut footwork, Blade Continuity."})
	aug("needlepoint", "Needlepoint", "reaver", "mutation", "advanced",
		"MUTATION: Piercing Lunge becomes narrower (x0.6 width) with +20% Crit Chance and x1.3 Poise Damage.",
		{"width_mult": 0.6, "crit": 0.2, "poise_mult": 1.3, "requires_core": "swordmaster"},
		{"requires_skills": ["r_lunge"], "build_tags": ["Duelist"], "interacts_with": "Piercing Lunge."})
	# ---------------- Reaver legacy cores (Sword Sense / Bladecraft): Debug comparison only
	atk("r_light1", "Quick Cut", "slash_h", 0.11, 0.1, 0.24, 0.75, 8, {"cancel_after": 0.08, "stamina_cost": 8, "tags": T.call(["light"]), "hitbox_size": Vector3(2.0, 1.6, 2.0), "hitbox_offset": Vector3(0, 1, -1.3)})
	atk("r_light2", "Back Cut", "slash_h", 0.1, 0.1, 0.24, 0.8, 8, {"cancel_after": 0.08, "stamina_cost": 8, "tags": T.call(["light"]), "hitbox_size": Vector3(2.0, 1.6, 2.0), "hitbox_offset": Vector3(0, 1, -1.3)})
	atk("r_light3", "Piercing Step", "thrust", 0.12, 0.1, 0.26, 0.85, 9, {"cancel_after": 0.08, "stamina_cost": 8, "lunge": 4.0, "tags": T.call(["light"]), "hitbox_size": Vector3(1.0, 1.5, 2.6), "hitbox_offset": Vector3(0, 1, -1.6)})
	atk("r_light4", "Whirling Finisher", "spin", 0.18, 0.25, 0.4, 1.5, 22, {"cancel_after": 0.2, "stamina_cost": 12, "tags": T.call(["light", "finisher"]), "hitbox_size": Vector3(3.8, 1.6, 3.8), "hitbox_offset": Vector3(0, 1, 0)})
	atk("r_dodge_slash", "Evasive Slash", "thrust", 0.08, 0.12, 0.28, 1.0, 10, {"cancel_after": 0.1, "stamina_cost": 8, "lunge": 8.0, "tags": T.call(["light", "dodge_attack"]), "hitbox_size": Vector3(1.4, 1.5, 2.4), "hitbox_offset": Vector3(0, 1, -1.4)})
	atk("r_heavy", "Cleaving Strike", "slash_v", 0.38, 0.14, 0.45, 2.0, 35, {"is_heavy": true, "stamina_cost": 18, "hitstop": 0.1, "poise_armor": 0.4, "cancel_after": 0.25, "tags": T.call(["heavy"]), "hitbox_size": Vector3(2.0, 1.8, 2.4), "hitbox_offset": Vector3(0, 1, -1.4)})
	atk("r_heavy_combo", "Cross Cut", "slash_h", 0.26, 0.14, 0.42, 1.8, 30, {"is_heavy": true, "stamina_cost": 16, "hitstop": 0.1, "cancel_after": 0.22, "tags": T.call(["heavy", "finisher"]), "hitbox_size": Vector3(2.8, 1.6, 2.2), "hitbox_offset": Vector3(0, 1, -1.3)})
	atk("r_charged", "Draw Cut", "slash_h", 0.18, 0.14, 0.5, 2.0, 30, {"is_heavy": true, "charge_time": 1.2, "charge_damage_bonus": 1.6, "charge_poise_bonus": 30.0, "lunge": 9.0, "stamina_cost": 22, "hitstop": 0.12, "tags": T.call(["heavy", "charged"]), "hitbox_size": Vector3(3.0, 1.6, 2.4), "hitbox_offset": Vector3(0, 1, -1.4)})
	# ---------------- Reaver: SWORDMASTER Blade Lines (refoundation spec 7). MEASURE: each line has its own
	# reach / width / tracking. Footwork steps are bounded (0.6m) and collision-safe; approach steps <= 0.6m.
	atk("rs_forward", "Forward Cut", "slash_h", 0.14, 0.1, 0.28, 1.0, 10, {"cancel_after": 0.12, "stamina_cost": 9, "approach_max": 0.6, "approach_range": 2.0, "tags": T.call(["light", "blade_line"]), "hitbox_size": Vector3(1.7, 1.6, 2.4), "hitbox_offset": Vector3(0, 1, -1.5)})
	atk("rs_lateral_l", "Lateral Cut (left)", "slash_h", 0.12, 0.1, 0.26, 0.9, 8, {"cancel_after": 0.11, "stamina_cost": 10, "tags": T.call(["light", "blade_line", "lateral"]), "hitbox_size": Vector3(3.0, 1.6, 1.8), "hitbox_offset": Vector3(-0.5, 1, -1.1)})
	atk("rs_lateral_r", "Lateral Cut (right)", "slash_h", 0.12, 0.1, 0.26, 0.9, 8, {"cancel_after": 0.11, "stamina_cost": 10, "tags": T.call(["light", "blade_line", "lateral"]), "hitbox_size": Vector3(3.0, 1.6, 1.8), "hitbox_offset": Vector3(0.5, 1, -1.1)})
	atk("rs_heavy", "Heavy Cut", "slash_v", 0.38, 0.14, 0.5, 2.0, 35, {"is_heavy": true, "stamina_cost": 18, "hitstop": 0.11, "poise_armor": 0.4, "cancel_after": 0.32, "approach_max": 0.5, "approach_range": 2.2, "tags": T.call(["heavy", "blade_line"]), "hitbox_size": Vector3(1.5, 1.8, 2.9), "hitbox_offset": Vector3(0, 1, -1.65)})
	atk("rs_draw", "Draw Cut", "slash_h", 0.18, 0.14, 0.5, 2.0, 30, {"is_heavy": true, "charge_time": 1.2, "charge_damage_bonus": 1.6, "charge_poise_bonus": 30.0, "lunge": 5.0, "stamina_cost": 22, "hitstop": 0.12, "cancel_after": 0.35, "tags": T.call(["heavy", "charged", "blade_line"]), "hitbox_size": Vector3(3.0, 1.6, 2.4), "hitbox_offset": Vector3(0, 1, -1.4)})
	atk("rs_slip", "Slip Cut", "thrust", 0.08, 0.12, 0.28, 1.0, 10, {"cancel_after": 0.12, "stamina_cost": 8, "lunge": 3.0, "tags": T.call(["light", "blade_line", "dodge_attack"]), "hitbox_size": Vector3(1.4, 1.5, 2.4), "hitbox_offset": Vector3(0, 1, -1.4)})
	# ---------------- Reaver design resolution: Flow Step, Crosscut, Sunder Edge, Turning Edge, Final Stroke
	atk("rs_flow_step", "Flow Step", "lunge", 0.02, 0.16, 0.08, 0.0, 0, {"hits": 0, "stamina_cost": 12, "cancel_after": 0.0, "tags": T.call(["step"])})
	atk("rs_crosscut", "Crosscut", "slash_h", 0.16, 0.4, 0.32, 1.9, 22, {"hits": 2, "hit_weights": PackedFloat32Array([0.55, 0.45]), "stamina_cost": 16, "move_during": 0.15, "cancel_after": 0.16, "hitstop": 0.06, "approach_max": 0.4, "approach_range": 1.9, "tags": T.call(["skill", "multi", "crosscut", "dodge_between_hits"]), "hitbox_size": Vector3(3.0, 1.6, 2.0), "hitbox_offset": Vector3(0, 1, -1.2)})
	atk("rs_sunder_edge", "Sunder Edge", "slash_v", 0.34, 0.12, 0.5, 1.2, 55, {"is_heavy": true, "stamina_cost": 20, "hitstop": 0.1, "poise_armor": 0.3, "cancel_after": 0.4, "approach_max": 0.5, "approach_range": 2.0, "tags": T.call(["skill", "sunder"]), "hitbox_size": Vector3(1.6, 1.8, 2.5), "hitbox_offset": Vector3(0, 1, -1.45)})
	atk("rs_turning_edge", "Turning Edge", "slash_h", 0.22, 0.1, 0.32, 1.3, 18, {"stamina_cost": 16, "cancel_after": 0.14, "hitstop": 0.07, "tags": T.call(["skill", "turning"]), "hitbox_size": Vector3(2.4, 1.6, 2.0), "hitbox_offset": Vector3(0, 1, -1.2)})
	atk("rs_final_stroke", "Final Stroke", "thrust", 0.4, 0.12, 0.6, 3.0, 40, {"stamina_cost": 25, "hitstop": 0.14, "cancel_after": 0.5, "approach_max": 0.4, "approach_range": 1.9, "tags": T.call(["skill", "finisher"]), "hitbox_size": Vector3(1.1, 1.6, 2.6), "hitbox_offset": Vector3(0, 1, -1.5)})
	atk("r_lunge", "Piercing Lunge", "thrust", 0.22, 0.14, 0.42, 2.2, 30, {"lunge": 13.0, "stamina_cost": 16, "hitstop": 0.12, "crit_chance_bonus": 0.15, "tags": T.call(["skill", "precision"]), "hitbox_size": Vector3(0.9, 1.5, 2.8), "hitbox_offset": Vector3(0, 1, -1.7)})
	atk("r_flurry", "Tempest Flurry", "flurry", 0.18, 0.7, 0.45, 2.8, 30, {"hits": 6, "stamina_cost": 22, "move_during": 0.3, "hitstop": 0.04, "tags": T.call(["skill", "multi"]), "hitbox_size": Vector3(2.8, 1.6, 2.4), "hitbox_offset": Vector3(0, 1, -1.3)})
	atk("r_rising", "Rising Crescent", "rising", 0.3, 0.16, 0.45, 2.0, 50, {"is_heavy": true, "stagger_on_hit": 0.9, "stamina_cost": 18, "hitstop": 0.12, "knockback": 1.0, "tags": T.call(["heavy", "rising"]), "hitbox_size": Vector3(2.0, 2.6, 2.2), "hitbox_offset": Vector3(0, 1.2, -1.3)})
	# ---------------- Enemies
	var red := Color(1.0, 0.15, 0.1, 0.5)
	atk("wolf_lunge", "Lunge", "lunge", 0.8, 0.25, 0.7, 1.0, 20, {"lunge": 13.0, "ai_range": Vector2(2.5, 7.5), "ai_weight": 1.5, "ai_cooldown": 3.5, "hitbox_size": Vector3(1.4, 1.2, 1.6), "hitbox_offset": Vector3(0, 0.8, -1.2), "telegraph_color": red})
	atk("wolf_bite", "Bite", "bite", 0.45, 0.1, 0.5, 0.8, 12, {"ai_range": Vector2(0, 2.2), "ai_cooldown": 1.5, "hitbox_size": Vector3(1.2, 1.2, 1.4), "hitbox_offset": Vector3(0, 0.8, -1.1)})
	atk("raider_combo1", "Raider Combo I", "slash_h", 0.65, 0.12, 0.3, 0.8, 15, {"chain_next": "raider_combo2", "ai_range": Vector2(0, 2.4), "ai_cooldown": 5.0, "hitbox_size": Vector3(2.2, 1.6, 2.0), "hitbox_offset": Vector3(0, 1, -1.3)})
	atk("raider_combo2", "Raider Combo II", "slash_h", 0.5, 0.12, 0.3, 0.8, 15, {"chain_next": "raider_combo3", "lunge": 3.0, "hitbox_size": Vector3(2.2, 1.6, 2.0), "hitbox_offset": Vector3(0, 1, -1.3), "ai_range": Vector2(99, 99)})
	atk("raider_combo3", "Raider Combo III", "slash_v", 0.6, 0.14, 1.1, 1.2, 25, {"lunge": 3.0, "hitbox_size": Vector3(1.8, 1.6, 2.4), "hitbox_offset": Vector3(0, 1, -1.4), "ai_range": Vector2(99, 99)})
	atk("raider_heavy", "Overhead Smash", "slam", 1.25, 0.15, 1.4, 2.0, 45, {"ai_range": Vector2(0, 2.8), "ai_cooldown": 6.0, "hitstop": 0.1, "knockback": 4.0, "hitbox_size": Vector3(1.8, 1.6, 2.4), "hitbox_offset": Vector3(0, 1, -1.4)})
	atk("guardian_bash", "Shield Bash", "bash", 0.75, 0.15, 0.8, 1.0, 25, {"ai_range": Vector2(0, 2.4), "ai_cooldown": 3.5, "knockback": 5.0, "hitbox_size": Vector3(2.0, 1.8, 1.8), "hitbox_offset": Vector3(0, 1, -1.2)})
	atk("guardian_slam", "Mace Slam", "slam", 1.25, 0.18, 1.2, 2.0, 50, {"ai_range": Vector2(0, 3.0), "ai_cooldown": 5.5, "hitstop": 0.12, "knockback": 4.0, "hitbox_size": Vector3(2.4, 1.8, 3.0), "hitbox_offset": Vector3(0, 1, -1.8)})
	atk("guardian_breaker", "Guard Breaker", "slam", 1.5, 0.18, 1.4, 1.6, 70, {"guard_break": true, "ai_range": Vector2(0, 3.0), "ai_cooldown": 9.0, "hitstop": 0.14, "knockback": 6.0, "hitbox_size": Vector3(2.0, 1.8, 2.8), "hitbox_offset": Vector3(0, 1, -1.6)})
	atk("caster_bolt", "Ash Bolt", "cast", 1.05, 0.05, 0.8, 1.0, 10, {"interruptible": true, "hits": 0, "special": "projectile", "damage_type": AttackData.DamageType.MAGIC, "ai_range": Vector2(3, 18), "ai_cooldown": 3.5})
	atk("caster_burst", "Ash Burst", "cast", 1.3, 0.05, 1.0, 1.6, 25, {"interruptible": true, "hits": 0, "special": "ground_burst", "damage_type": AttackData.DamageType.MAGIC, "ai_range": Vector2(2, 16), "ai_cooldown": 8.0, "hitbox_size": Vector3(6, 2, 6)})
	atk("warden_slash1", "Warden Slash", "slash_h", 0.75, 0.14, 0.35, 1.2, 25, {"chain_next": "warden_slash2", "ai_range": Vector2(0, 3.6), "ai_cooldown": 2.5, "hitbox_size": Vector3(3.0, 1.8, 2.6), "hitbox_offset": Vector3(0, 1, -1.8)})
	atk("warden_slash2", "Warden Return Slash", "slash_v", 0.55, 0.14, 1.0, 1.4, 30, {"lunge": 4.0, "ai_range": Vector2(99, 99), "hitbox_size": Vector3(2.4, 1.8, 3.0), "hitbox_offset": Vector3(0, 1, -2.0)})
	atk("warden_sweep", "Ashen Sweep", "sweep", 1.15, 0.2, 1.1, 1.6, 40, {"ai_range": Vector2(0, 4.8), "ai_cooldown": 6.0, "knockback": 6.0, "hitbox_size": Vector3(8.0, 1.8, 5.0), "hitbox_offset": Vector3(0, 1, -1.2)})
	atk("warden_breaker", "Warden Guard Crusher", "slam", 1.35, 0.18, 1.2, 2.0, 60, {"guard_break": true, "ai_range": Vector2(0, 3.8), "ai_cooldown": 8.0, "hitstop": 0.14, "knockback": 6.0, "hitbox_size": Vector3(2.6, 2.0, 3.4), "hitbox_offset": Vector3(0, 1, -2.0)})
	atk("warden_flame_combo", "Flame Combination", "flurry", 0.85, 0.9, 1.0, 2.4, 40, {"hits": 4, "ai_min_phase": 2, "ai_range": Vector2(0, 3.6), "ai_cooldown": 7.0, "hitbox_size": Vector3(3.0, 1.8, 3.0), "hitbox_offset": Vector3(0, 1, -1.8)})
	atk("warden_burning_ground", "Burning Ground", "cast", 1.2, 0.05, 0.8, 0.35, 0, {"hits": 0, "special": "burning_ground", "damage_type": AttackData.DamageType.MAGIC, "ai_min_phase": 2, "ai_range": Vector2(0, 30), "ai_cooldown": 10.0, "ai_weight": 0.8})
	atk("warden_ember_lance", "Ember Lance", "cast", 1.1, 0.05, 0.7, 1.6, 30, {"hits": 0, "special": "lance_far", "damage_type": AttackData.DamageType.MAGIC, "ai_min_phase": 2, "ai_range": Vector2(0, 40), "ai_cooldown": 6.0})
	atk("warden_execution", "Execution Strike", "slam", 1.9, 0.25, 1.5, 5.0, 100, {"guard_break": true, "special": "execution", "lunge": 10.0, "ai_min_phase": 3, "ai_range": Vector2(0, 9), "ai_cooldown": 14.0, "hitstop": 0.2, "knockback": 8.0, "hitbox_size": Vector3(2.6, 2.0, 3.2), "hitbox_offset": Vector3(0, 1, -1.8), "telegraph_color": Color(0.6, 0.0, 0.0, 0.7)})
	atk("warden_roar", "Ashen Roar", "spin", 1.2, 0.2, 0.8, 0.5, 60, {"knockback": 9.0, "ai_range": Vector2(99, 99), "hitbox_size": Vector3(9, 3, 9), "hitbox_offset": Vector3(0, 1, 0)})


# ------------------------------------------------------------------ skills
func _skills() -> void:
	var defs := [
		["shield_rush", "Shield Rush", "Forward shield charge that damages, generates heavy threat and can INTERCEPT: aimed toward an endangered ally it rushes to them and takes the next blow aimed at them. With 30 Resolve it becomes an Empowered Rush (staggering impact).", "v_shield_rush", "v_shield_rush_emp", 6.0, 30.0, false, ["Interception (ally in danger)", "Empowered (30 Resolve)"]],
		["judgment_strike", "Judgment Strike", "Chargeable heavy sword strike with massive Poise damage. Right after a Perfect Guard it becomes an instant Riposte (guaranteed crit). At full charge with 40 Resolve it becomes Verdict (wider shockwave).", "v_judgment", "v_judgment_riposte", 8.0, 40.0, true, ["Riposte (after Perfect Guard)", "Verdict (full charge + 40 Resolve)"]],
		["iron_sweep", "Iron Sweep", "Multi-hit sword-and-shield spin hitting all nearby enemies. Used while holding Guard it becomes a Guarded Sweep (frontal protection). With 25 Resolve: +1 hit and taunts everything hit.", "v_iron_sweep", "v_iron_sweep_guarded", 7.0, 25.0, false, ["Guarded Sweep (hold Guard)", "Resolve Sweep: +1 hit + taunt"]],
	]
	for d in defs:
		var s := SkillData.new()
		s.id = d[0]
		s.display_name = d[1]
		s.description = d[2]
		s.attack = load("res://data/attacks/%s.tres" % d[3])
		s.alt_attack = load("res://data/attacks/%s.tres" % d[4])
		s.cooldown = d[5]
		s.resolve_cost = d[6]
		s.chargeable = d[7]
		s.variations = PackedStringArray(d[8])
		_save(s, "res://data/skills/%s.tres" % s.id)


# ------------------------------------------------------------------ spells
func spell(id: String, nm: String, el: String, charged: bool, mana: float, cast: float, rec: float, power: float, extra: Dictionary, desc: String) -> void:
	var s := SpellData.new()
	s.id = id
	s.display_name = nm
	s.element = el
	s.charged = charged
	s.mana_cost = mana
	s.cast_time = cast
	s.recovery = rec
	s.power = power
	s.description = desc
	for k in extra:
		s.set(k, extra[k])
	_save(s, "res://data/spells/%s.tres" % id)


func _spells() -> void:
	spell("firebolt", "Firebolt", "fire", false, 8, 0.22, 0.25, 0.9, {"speed": 24.0, "max_range": 24.0, "poise_damage": 8.0, "status_power": 0.12}, "Fast fire projectile, applies Burn.")
	spell("fireball", "Fireball", "fire", true, 20, 0.35, 0.45, 2.0, {"radius": 3.5, "speed": 14.0, "max_range": 24.0, "poise_damage": 45.0, "status_power": 0.18}, "Slow projectile that EXPLODES in an area, burning everything caught.")
	spell("mend", "Mend", "life", false, 12, 0.25, 0.3, 1.6, {"max_range": 20.0}, "Instant direct heal on the most wounded ally in range.")
	spell("renewal", "Renewal Wave", "life", true, 28, 0.7, 0.4, 1.4, {"radius": 9.0, "status_duration": 6.0, "status_power": 0.25}, "Slow channel, then heals EVERY ally around the Mage and leaves a HoT.")
	spell("ice_shard", "Ice Shard", "frost", false, 8, 0.2, 0.25, 0.8, {"speed": 28.0, "max_range": 24.0, "poise_damage": 10.0, "status_duration": 3.0, "status_power": 0.4}, "Fast shard that Chills (slows movement and attack speed).")
	spell("frost_nova", "Frost Nova", "frost", true, 22, 0.4, 0.45, 1.3, {"radius": 5.0, "poise_damage": 35.0, "status_duration": 2.5, "status_power": 0.7}, "Point-blank ring that FREEZES nearby enemies (near-stop).")
	spell("spark", "Spark", "storm", false, 9, 0.15, 0.25, 0.7, {"max_range": 16.0, "poise_damage": 6.0, "bounces": 1}, "Instant arc that jumps to a second target.")
	spell("thunder", "Thunder Strike", "storm", true, 24, 0.35, 0.4, 2.6, {"radius": 2.6, "poise_damage": 60.0, "max_range": 22.0, "delay": 0.6}, "Marks the ground, then a delayed lightning bolt hits hard.")
	spell("stone_shard", "Stone Shard", "stone", false, 10, 0.28, 0.3, 1.0, {"speed": 20.0, "max_range": 22.0, "poise_damage": 40.0}, "Heavy physical shard with big Poise damage and knockback.")
	spell("earthen_ward", "Earthen Ward", "stone", true, 25, 0.45, 0.4, 0.8, {"radius": 7.0, "poise_damage": 30.0, "status_duration": 6.0, "status_power": 0.25}, "Stoneskin for nearby allies; shoves adjacent enemies away.")


# ------------------------------------------------------------------ Grand Elementalist spells
func mspell(id: String, nm: String, el: String, unlock: String, desc: String, partial: String, full: String, v: Dictionary) -> void:
	var c := ChargedSpellData.new()
	c.id = id
	c.display_name = nm
	c.element = el
	c.unlock_id = unlock
	c.description = desc
	c.partial_text = partial
	c.full_text = full
	for k in v:
		c.set(k, v[k])
	_save(c, "res://data/mage_spells/%s.tres" % id)


## WORLDWEAVER spell book. Timing values follow spec section 3 (provisional): minimum release
## 0.25s, standard full charge 1.20s, major full charge 1.80s, 65% movement while charging,
## 45% for heavy spells. Every number below is editable data (data/mage_spells/*.tres).
func _mage_spells() -> void:
	var std := {"min_charge": 0.25, "full_charge": 1.2, "move_mult": 0.65}
	var major := {"min_charge": 0.25, "full_charge": 1.8, "move_mult": 0.45}
	# ---------------- FIRE
	mspell("flame_cataclysm", "Flame Cataclysm", "fire", "",
		"Charged fire projectile. Explosive damage and area denial.",
		"Compact projectile, small explosion (Magic Damage). No burning area.",
		"Larger projectile, wider explosion and ONE temporary burning area (2.5m, 5s, damage every 1s).",
		_m(std, {"root_on_full": 0.15, "mana_partial": 10.0, "mana_full": 22.0,
		"recovery_partial": 0.28, "recovery_full": 0.5, "power_partial": 1.15, "power_full": 1.6, "poise_partial": 12.0, "poise_full": 40.0,
		"radius_partial": 1.5, "radius_full": 3.0, "speed_partial": 24.0, "speed_full": 17.0, "max_range": 26.0,
		"duration_full": 5.0, "width_full": 2.5, "status_power": 0.28}))
	mspell("inferno_wave", "Inferno Wave", "fire", "",
		"ADVANCED. A forward-moving wave of flame across the ground that pressures enemies holding a path. Each enemy is hit once per wave.",
		"Shorter, narrower wave.", "Longer, wider wave.",
		_m(std, {"advanced": true, "mana_partial": 14.0, "mana_full": 26.0, "recovery_partial": 0.3, "recovery_full": 0.5,
		"power_partial": 0.9, "power_full": 1.4, "poise_partial": 10.0, "poise_full": 25.0, "radius_partial": 1.0, "radius_full": 1.6,
		"max_range": 10.0, "speed_partial": 11.0, "speed_full": 11.0, "duration_partial": 0.8, "duration_full": 1.2, "status_power": 0.2}))
	mspell("cinderfall", "Cinderfall", "fire", "",
		"ADVANCED. Targets a location; a delayed overhead fire impact lands after a visible warning. Punishes stationary or predictable enemies.",
		"Smaller impact area.", "Larger, stronger impact.",
		_m(std, {"advanced": true, "places_formation": true, "mana_partial": 14.0, "mana_full": 26.0, "recovery_partial": 0.3, "recovery_full": 0.45,
		"power_partial": 1.4, "power_full": 2.2, "poise_partial": 15.0, "poise_full": 35.0, "radius_partial": 2.0, "radius_full": 3.0,
		"max_range": 22.0, "duration_partial": 1.2, "duration_full": 1.2}))
	# ---------------- FROST
	mspell("crystal_formation", "Crystal Formation", "frost", "m_frost",
		"Raises a temporary ice formation at the aimed location (placement preview; orientation follows your aim). Ice blocks enemy movement and is a Frozen Structure.",
		"One small ice obstruction (1.5m) + limited Chill on nearby enemies.",
		"A larger connected formation (4m) with more path-blocking coverage + Chill within range.",
		_m(std, {"places_formation": true, "mana_partial": 12.0, "mana_full": 22.0,
		"recovery_partial": 0.3, "recovery_full": 0.45, "power_partial": 0.3, "power_full": 0.5, "poise_partial": 8.0, "poise_full": 15.0,
		"radius_partial": 2.0, "radius_full": 3.5, "max_range": 18.0, "duration_partial": 7.0, "duration_full": 7.0, "status_power": 0.45,
		"width_partial": 1.5, "width_full": 4.0}))
	mspell("glacial_spear", "Glacial Spear", "frost", "",
		"ADVANCED. A concentrated ice projectile: reliable single-target Magic Damage and moderate Chill.",
		"Lighter spear.", "Heavier spear.",
		_m(std, {"advanced": true, "mana_partial": 12.0, "mana_full": 22.0, "recovery_partial": 0.25, "recovery_full": 0.4,
		"power_partial": 1.3, "power_full": 2.1, "poise_partial": 10.0, "poise_full": 22.0, "speed_partial": 30.0, "speed_full": 30.0,
		"max_range": 26.0, "duration_partial": 1.5, "duration_full": 2.5, "status_power": 0.35}))
	mspell("frozen_bastion", "Frozen Bastion", "frost", "",
		"ADVANCED utility. Rapidly raises a short-lived ice wall at the aimed point. Hold [3] to aim, release to raise. Never permanent; bosses break it.",
		"", "",
		{"advanced": true, "slot_kind": "utility", "cast_type": "instant", "places_formation": true, "mana_partial": 18.0, "mana_full": 18.0,
		"recovery_partial": 0.25, "cooldown": 16.0, "max_range": 14.0, "duration_partial": 4.0, "width_partial": 5.0})
	# ---------------- STONE
	mspell("earthbreaker", "Earthbreaker", "stone", "m_stone",
		"Charged heavy stone mass (MAJOR spell: 1.8s, 45% movement). Magic Damage and Poise Damage. Displacement depends on enemy weight: light displaced, medium limited, heavy and bosses resist.",
		"Compact stone mass: Magic Damage + moderate Poise Damage.",
		"Heavier stone mass: stronger Poise Damage + limited area disruption.",
		_m(major, {"root_on_full": 0.3, "mana_partial": 14.0, "mana_full": 26.0,
		"recovery_partial": 0.4, "recovery_full": 0.65, "power_partial": 1.2, "power_full": 2.3, "poise_partial": 45.0, "poise_full": 110.0,
		"radius_partial": 0.0, "radius_full": 2.6, "speed_partial": 20.0, "speed_full": 15.0, "max_range": 24.0}))
	mspell("rising_pillar", "Rising Pillar", "stone", "",
		"ADVANCED utility. A destructible stone pillar rises at the aimed point: temporary cover, limited displacement of enemies standing there. Fortified (defensive) formation.",
		"", "",
		{"advanced": true, "slot_kind": "utility", "cast_type": "instant", "places_formation": true, "mana_partial": 16.0, "mana_full": 16.0,
		"recovery_partial": 0.3, "cooldown": 12.0, "max_range": 16.0, "duration_partial": 8.0, "width_partial": 1.4, "poise_partial": 20.0, "radius_partial": 1.6})
	mspell("stone_ward", "Stone Ward", "stone", "",
		"ADVANCED utility. Temporary directional stone cover in front of you (aim sets the facing). Destructible, Fortified. Blocks projectiles and line of sight; it does not make anyone invulnerable.",
		"", "",
		{"advanced": true, "slot_kind": "utility", "cast_type": "instant", "places_formation": true, "mana_partial": 16.0, "mana_full": 16.0,
		"recovery_partial": 0.3, "cooldown": 14.0, "max_range": 3.0, "duration_partial": 6.0, "width_partial": 3.5})
	# ---------------- STORM
	mspell("thunder_conduit", "Thunder Conduit", "storm", "m_storm",
		"Charged lightning on your target. Conductivity and distributed attacks.",
		"Strikes one eligible target with focused Magic Damage.",
		"Strikes the target and CHAINS: max 3 total targets, max 6m per jump, never the same target twice in one chain.",
		_m(std, {"mana_partial": 12.0, "mana_full": 24.0,
		"recovery_partial": 0.25, "recovery_full": 0.45, "power_partial": 1.3, "power_full": 1.75, "poise_partial": 10.0, "poise_full": 28.0,
		"max_range": 22.0, "chains_partial": 0, "chains_full": 2, "chain_range": 6.0, "chain_falloff": 0.75}))
	mspell("lightning_verdict", "Lightning Verdict", "storm", "",
		"ADVANCED. Concentrated bolt that cancels an ELIGIBLE enemy preparation (only enemies that expose an interruptible window, e.g. Ash Caster spells). Bosses resist. Not a universal interrupt.",
		"Lighter bolt; still interrupts eligible preparations.", "Stronger bolt; still interrupts eligible preparations.",
		_m(std, {"advanced": true, "mana_partial": 14.0, "mana_full": 24.0, "recovery_partial": 0.25, "recovery_full": 0.4,
		"power_partial": 0.9, "power_full": 1.5, "poise_partial": 15.0, "poise_full": 30.0, "max_range": 24.0}))
	mspell("storm_arc", "Storm Arc", "storm", "",
		"ADVANCED. Electricity along a controlled directional path (your aim). Hits enemies on the route; a CONDUCTIVE anchor on the route relays the arc (each anchor once per cast).",
		"Shorter path.", "Longer path.",
		_m(std, {"advanced": true, "mana_partial": 12.0, "mana_full": 22.0, "recovery_partial": 0.25, "recovery_full": 0.4,
		"power_partial": 0.8, "power_full": 1.3, "poise_partial": 8.0, "poise_full": 18.0, "max_range": 14.0, "radius_partial": 8.0, "radius_full": 14.0,
		"chain_range": 6.0, "width_partial": 1.4, "width_full": 1.4}))
	# ---------------- LIFE
	mspell("life_bloom", "Life Bloom", "life", "",
		"Charged heal on your HEAL TARGET (T cycles party, 2 picks the most injured, default yourself). Works without enemies.",
		"Moderate direct heal.",
		"Greater direct heal, better efficiency per mana.",
		_m(std, {"mana_partial": 12.0, "mana_full": 22.0,
		"recovery_partial": 0.25, "recovery_full": 0.4, "power_partial": 1.4, "power_full": 3.4, "max_range": 22.0, "status_power": 0.45}))
	mspell("verdant_renewal", "Verdant Renewal", "life", "",
		"ADVANCED. Charged Healing over Time on your heal target: sustained recovery, not a rescue. HoT scales with MAS.",
		"Shorter, weaker HoT.", "Longer, stronger HoT.",
		_m(std, {"advanced": true, "mana_partial": 12.0, "mana_full": 22.0, "recovery_partial": 0.25, "recovery_full": 0.4,
		"power_partial": 1.5, "power_full": 3.2, "duration_partial": 6.0, "duration_full": 8.0, "max_range": 22.0}))
	mspell("lifeline", "Lifeline", "life", "",
		"Emergency heal: instant, on your heal target, dedicated 12s cooldown. Less healing than a full Life Bloom.",
		"", "",
		{"slot_kind": "emergency", "cast_type": "instant", "mana_partial": 15.0, "mana_full": 15.0, "recovery_partial": 0.2, "cooldown": 12.0, "power_partial": 1.6, "max_range": 22.0})
	mspell("protective_renewal", "Protective Renewal", "life", "m_renewal",
		"Utility. Preventive protection on your heal target for 6s: a limited shield, and part of the damage taken while it lasts is healed back. Never blocks all damage.",
		"", "",
		{"slot_kind": "utility", "cast_type": "instant", "mana_partial": 20.0, "mana_full": 20.0, "recovery_partial": 0.3, "cooldown": 14.0, "power_partial": 1.2,
		"duration_partial": 6.0, "status_power": 0.4, "max_range": 22.0})


func _m(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := a.duplicate()
	o.merge(b, true)
	return o


func _fusions() -> void:
	var defs := [
		["phoenix_bloom", "Phoenix Bloom", "fire+life", "Blooming zone that burns enemies and heals allies inside.", {"mana_cost": 25.0, "power": 0.35, "heal_power": 0.35, "radius": 5.0, "duration": 6.0, "tick": 0.5, "poise_damage": 3.0}],
		["sanctuary", "Sanctuary", "life+life", "Powerful group heal + HoT + damage reduction around the Mage.", {"mana_cost": 30.0, "heal_power": 2.2, "radius": 12.0, "status_duration": 6.0, "status_power": 0.3}],
		["thermal_fracture", "Thermal Fracture", "fire+frost", "Thermal explosion: high damage and huge Poise damage.", {"mana_cost": 25.0, "power": 3.2, "poise_damage": 120.0, "radius": 5.0}],
		["winters_embrace", "Winter's Embrace", "frost+life", "Heals allies, grants Frost Armor, slows nearby enemies.", {"mana_cost": 25.0, "power": 0.8, "heal_power": 1.2, "radius": 10.0, "status_duration": 6.0, "status_power": 0.25, "poise_damage": 15.0}],
		["plasma_surge", "Plasma Surge", "fire+storm", "Burning chain lightning jumping across up to 6 enemies.", {"mana_cost": 25.0, "power": 1.3, "bounces": 5, "poise_damage": 15.0, "status_power": 0.15}],
		["vital_current", "Vital Current", "life+storm", "Chain lightning where every jump heals the most wounded ally.", {"mana_cost": 25.0, "power": 0.9, "heal_power": 0.6, "bounces": 3, "poise_damage": 10.0}],
		["discord", "Arcane Discord", "discord", "Unlisted element pair: an unstable arcane burst.", {"mana_cost": 15.0, "power": 1.2, "radius": 3.5, "poise_damage": 20.0}],
	]
	for d in defs:
		var f := FusionData.new()
		f.id = d[0]
		f.display_name = d[1]
		f.key = d[2]
		f.description = d[3]
		for k in d[4]:
			f.set(k, d[4][k])
		_save(f, "res://data/fusions/%s.tres" % f.id)


# ------------------------------------------------------------------ augments
func aug(id: String, nm: String, cls: String, cat: String, rarity: String, desc: String, params: Dictionary, extra: Dictionary = {}) -> void:
	var a := AugmentData.new()
	a.id = id
	a.display_name = nm
	a.class_id = cls
	a.category = cat
	a.rarity = rarity
	a.description = desc
	a.params = params
	for k in extra:
		var v = extra[k]
		if v is Array:
			v = PackedStringArray(v)
		a.set(k, v)
	_save(a, "res://data/augments/%s.tres" % id)


func _augments() -> void:
	# ---------------- Vanguard
	aug("iron_reprisal", "Iron Reprisal", "vanguard", "conditional", "advanced",
		"After a Perfect Guard, your next Heavy Attack (Heavy, Judgment Strike, Riposte) within 6s is empowered: +60% damage, +50% Poise damage and a wider hitbox.",
		{"duration": 6.0, "damage_bonus": 0.6, "poise_bonus": 0.5},
		{"build_tags": ["Bulwark", "Punisher"], "interacts_with": "Perfect Guard -> Heavy Attacks. Poise bonus multiplies with Crushing Rhythm (explicit multiplicative)."})
	aug("last_line", "Last Line", "vanguard", "conditional", "standard",
		"Successfully intercepting an attack aimed at an ally grants Last Line: -35% damage taken and -60% Poise taken for 5s (scales with MAS). 6s internal cooldown.",
		{"damage_reduction": 0.35, "duration": 5.0, "icd": 6.0},
		{"requires_skills": ["v_intercept"], "build_tags": ["Protector"], "interacts_with": "Shield Rush interception."})
	aug("steadfast", "Steadfast", "vanguard", "passive", "standard",
		"Guarding (normal and perfect) costs 25% less Stamina. Stacks additively up to 2 times.",
		{"stamina_reduction": 0.25},
		{"stackable": true, "max_stacks": 2, "build_tags": ["Bulwark"], "interacts_with": "Aegis Guard stamina cost (additive stacking)."})
	aug("crushing_rhythm", "Crushing Rhythm", "vanguard", "synergy", "advanced",
		"When a multi-hit attack (Iron Sweep, Guarded Sweep, Light chain hits) lands ALL of its hits, your next attack deals x1.75 Poise damage.",
		{"poise_mult": 1.75},
		{"stack_mode": "mult", "build_tags": ["Breaker"], "interacts_with": "Iron Sweep -> Judgment Strike / Heavy. Explicitly multiplies with Iron Reprisal's Poise bonus."})
	aug("unyielding_charge", "Unyielding Charge", "vanguard", "enhancement", "standard",
		"While charging Judgment Strike or executing Shield Rush / Judgment Strike, frontal hits deal 50% less damage and cannot break your Poise.",
		{"reduction": 0.5},
		{"requires_skills": ["judgment_strike"], "build_tags": ["Breaker"], "interacts_with": "Charge attacks (Judgment Strike charge, Shield Rush)."})
	aug("phantom_bulwark", "Phantom Bulwark", "vanguard", "mutation", "exotic",
		"MUTATION: Shield Rush leaves a Phantom Bulwark where it ends: a 3.5m dome with HP (40% of your max HP, +2% per FOR) for 6s. It absorbs damage dealt to allies inside from attackers outside, and blocks enemy projectiles.",
		{"radius": 3.5, "hp_pct": 0.4, "duration": 6.0},
		{"requires_skills": ["shield_rush"], "build_tags": ["Protector"], "interacts_with": "Shield Rush (incl. interception rush) -> functional barrier."})
	aug("guardians_return", "Guardian's Return", "vanguard", "conditional", "advanced",
		"A successful INTERCEPTION opens a contextual counter: for 1.5s your Light Attack becomes an Aegis Counter (as after a Perfect Guard).",
		{"window": 1.5},
		{"requires_skills": ["v_intercept", "v_counter"], "build_tags": ["Interceptor"], "interacts_with": "Interception (Shield Rush toward an endangered ally), Aegis Counter."})
	aug("verdict_of_steel", "Verdict of Steel", "vanguard", "mutation", "advanced",
		"MUTATION: a Resolve-powered (fully charged) Judgment Strike becomes a POISE finisher: x2.2 Poise Damage but x0.7 damage.",
		{"poise_mult": 2.2, "damage_mult": 0.7},
		{"requires_skills": ["judgment_strike", "v_resolve"], "build_tags": ["Retribution"], "interacts_with": "Judgment Strike Verdict (full charge + Resolve)."})
	aug("rolling_fortress", "Rolling Fortress", "vanguard", "enhancement", "standard",
		"Modifies Shield Plant: while planted, Dodge becomes a short reposition (about 1.4m) WITHOUT leaving the planted stance. 10 stamina, 0.6s internal cooldown.",
		{"distance_speed": 7.0, "stamina": 10.0, "icd": 0.6},
		{"requires_skills": ["v_shield_plant"], "build_tags": ["Sentinel"], "interacts_with": "Shield Plant (Lv12; Build Showcase in the Lv10 prototype)."})
	aug("guardians_reserve", "Guardian's Reserve", "vanguard", "conditional", "advanced",
		"After a successful INTERCEPTION, if you have 20 Resolve it is spent to give the intercepted ally brief limited protection (a guard that absorbs up to 12% of their max HP for 3s). Not healing.",
		{"cost": 20.0, "hp_frac": 0.12, "duration": 3.0},
		{"requires_skills": ["v_intercept", "v_resolve"], "build_tags": ["Interceptor"], "interacts_with": "Interception, Resolve."})
	# ---------------- Mage
	aug("frost_discovery", "Frost Discovery", "mage", "enhancement", "standard",
		"DISCOVERY: unlock the Frost element (Ice Shard / Frost Nova) and the Thermal Fracture (Fire+Frost) and Winter's Embrace (Frost+Life) weaves.",
		{"requires_core": "weave", "unlock_element": "frost"},
		{"requires_missing_elements": ["frost"], "build_tags": ["Discovery"], "interacts_with": "Arcane Weave combinations."})
	aug("storm_discovery", "Storm Discovery", "mage", "enhancement", "standard",
		"DISCOVERY: unlock the Storm element (Spark / Thunder Strike) and the Plasma Surge (Fire+Storm) and Vital Current (Storm+Life) weaves.",
		{"requires_core": "weave", "unlock_element": "storm"},
		{"requires_missing_elements": ["storm"], "build_tags": ["Discovery"], "interacts_with": "Arcane Weave combinations."})
	aug("living_flame", "Living Flame", "mage", "mutation", "advanced",
		"MUTATION: Fire spells leave lingering flames where they land (Firebolt: small 3s patch, Fireball: large 4s patch) that burn enemies every 0.5s.",
		{"requires_core": "weave", "tick_power": 0.25},
		{"requires_elements": ["fire"], "build_tags": ["Pyromancy"], "interacts_with": "Firebolt, Fireball (and Spell Echo copies)."})
	aug("spell_echo", "Spell Echo", "mage", "synergy", "advanced",
		"Quick-casting a DIFFERENT element within 1.5s of a quick cast re-casts the earlier spell at 40% power (e.g. Firebolt -> Mend fires a weak second Firebolt). Echo copies never trigger Spell Echo or store Elemental Echoes.",
		{"requires_core": "weave", "window": 1.5, "power": 0.4},
		{"build_tags": ["Weaver"], "interacts_with": "Quick casts of any element incl. Life. Non-recursive."})
	aug("gentle_restoration", "Gentle Restoration", "mage", "passive", "standard",
		"50% of excess (over)healing from your heals is converted into a 4s HoT on the target (scales with MAS). The HoT itself never converts again.",
		{"conversion": 0.5, "duration": 4.0, "legacy_only": true},
		{"build_tags": ["Healer"], "interacts_with": "Mend, Renewal, Sanctuary, Phoenix Bloom, Vital Current, Winter's Embrace."})
	aug("living_current", "Living Current", "mage", "synergy", "exotic",
		"Storm damage heals your most wounded ally for 25% of the damage dealt. Vital Current (Storm+Life) gains +2 jumps and heals x1.5.",
		{"requires_core": "weave", "heal_ratio": 0.25, "vital_bounces": 2, "vital_heal_mult": 1.5},
		{"requires_elements": ["storm"], "build_tags": ["Healer", "Storm"], "interacts_with": "Spark, Thunder Strike, Plasma Surge, Vital Current."})
	aug("resonant_ground", "Resonant Ground", "mage", "enhancement", "advanced",
		"Ley Sigils are 30% wider and their elemental pulses happen 50% faster.",
		{"radius_mult": 1.3, "pulse_mult": 1.5, "requires_core": "sigils"},
		{"build_tags": ["Sigilist"], "interacts_with": "Every Ley Sigil element (passive pulses)."})
	aug("sanctified_ward", "Sanctified Ward", "mage", "synergy", "advanced",
		"Consuming a Life Sigil grants allies inside a Ward shield 50% stronger, and cleanses their debuffs.",
		{"ward_mult": 1.5, "requires_core": "sigils"},
		{"requires_skills": ["m_ward"], "build_tags": ["Healer", "Sigilist"], "interacts_with": "Life Sigil consume + Ward."})
	# ---------------- Mage: WORLDWEAVER (only the augments approved in spec section 15)
	aug("infernal_collapse", "Infernal Collapse", "mage", "mutation", "advanced",
		"MUTATION: a fully charged Flame Cataclysm creates NO persistent burning area; instead the impact point collapses in a delayed secondary explosion (1s, telegraphed).",
		{"delay": 1.0, "radius": 3.0, "power": 1.5, "requires_core": "elementalist"},
		{"requires_elements": ["fire"], "build_tags": ["Primal Sorcery"], "interacts_with": "Flame Cataclysm (full)."})
	aug("crystal_chain", "Crystal Chain", "mage", "synergy", "standard",
		"A new ice formation CONNECTS to your nearest other ice formation within 8m: ice fills the gap so the two become one extended barrier.",
		{"link_range": 8.0, "requires_core": "elementalist"},
		{"requires_elements": ["frost"], "build_tags": ["Worldcraft"], "interacts_with": "Crystal Formation, Frozen Bastion."})
	aug("mountainfall", "Mountainfall", "mage", "mutation", "advanced",
		"MUTATION: a fully charged Earthbreaker becomes a delayed OVERHEAD impact at the aimed point (1s warning, larger area, x1.6 Poise Damage).",
		{"delay": 1.0, "radius": 3.6, "poise_mult": 1.6, "requires_core": "elementalist"},
		{"requires_elements": ["stone"], "build_tags": ["Primal Sorcery"], "interacts_with": "Earthbreaker (full); still a Stone impact (Shattered Winter)."})
	aug("living_thunder", "Living Thunder", "mage", "synergy", "advanced",
		"A full Thunder Conduit gains ONE additional chain target that YOU direct: the enemy closest to your aim (screen centre) within 15m.",
		{"range": 15.0, "requires_core": "elementalist"},
		{"requires_elements": ["storm"], "build_tags": ["Primal Sorcery"], "interacts_with": "Thunder Conduit (full)."})
	aug("everlasting_bloom", "Everlasting Bloom", "mage", "passive", "standard",
		"35% of Life Bloom's direct healing is converted into Healing over Time (6s). Same total; HoT scales with MAS.",
		{"convert": 0.35, "duration": 6.0, "requires_core": "elementalist"},
		{"requires_elements": ["life"], "build_tags": ["Lifebinding"], "interacts_with": "Life Bloom (Focused and Shared)."})
	aug("wandering_sanctum", "Wandering Sanctum", "mage", "mutation", "exotic",
		"MUTATION: Arcane Sanctum FOLLOWS you, but its element enhancements are 30% weaker.",
		{"effect_mult": 0.7, "requires_core": "elementalist"},
		{"requires_skills": ["m_sanctum"], "build_tags": ["Worldcraft"], "interacts_with": "Arcane Sanctum (all elements)."})
	aug("storm_lattice", "Storm Lattice", "mage", "synergy", "advanced",
		"Enhances conductive Stone routing: a Conductive formation stays conductive 50% longer (9s) and can relay the same Thunder Conduit one additional time.",
		{"duration_mult": 1.5, "extra_relays": 1, "requires_core": "elementalist"},
		{"requires_elements": ["storm", "stone"], "requires_skills": ["m_storm"], "build_tags": ["Worldcraft"], "interacts_with": "Conductive Anchors (full Thunder Conduit near a Stone formation)."})
	aug("second_heart", "Second Heart", "mage", "passive", "advanced",
		"Limited overhealing becomes temporary protection: 30% of the overheal from your heals becomes a shield (max 15% of the target's max HP, 4s).",
		{"conversion": 0.3, "max_hp_frac": 0.15, "duration": 4.0, "requires_core": "elementalist"},
		{"requires_elements": ["life"], "build_tags": ["Lifebinding"], "interacts_with": "Life Bloom, Lifeline, Verdant Renewal, Living Bastion."})
	aug("living_bastion", "Living Bastion", "mage", "synergy", "advanced",
		"Enhances the Life + Stone interaction: a Vitalized defensive Stone formation stays Vitalized 50% longer and its recovery reaches allies within 4.5m (instead of 3m).",
		{"duration_mult": 1.5, "radius": 4.5, "requires_core": "elementalist"},
		{"requires_elements": ["stone", "life"], "requires_skills": ["m_stone"], "build_tags": ["Lifebinding", "Worldcraft"], "interacts_with": "Living Bastion interaction (Life Bloom / Verdant Renewal near a Fortified Stone formation)."})
	# ---------------- Reaver
	aug("predators_patience", "Predator's Patience", "reaver", "passive", "standard",
		"Enemy Openings you can exploit last 50% longer.",
		{"duration_mult": 1.5, "requires_core": "sense"},
		{"build_tags": ["Precision", "Finality"], "interacts_with": "Sword Sense Openings (recovery / stagger / dodge)."})
	aug("sense_sundering_verdict", "Sundering Verdict (Sword Sense)", "reaver", "conditional", "advanced",
		"Sunder Cuts (heavy attacks on an Opening) stagger non-boss enemies and refund the attack's Stamina.",
		{"stagger": 0.8, "requires_core": "sense"},
		{"build_tags": ["Finality"], "interacts_with": "Heavy / Charged / Combo Heavy on Openings."})
	aug("ghost_step", "Ghost Step", "reaver", "mutation", "exotic",
		"MUTATION: after a Perfect Dodge, your next attack within 1.2s becomes an instant Vital Cut with +50% Critical Damage, whatever its type.",
		{"window": 1.2, "crit_damage": 0.5, "requires_core": "sense"},
		{"requires_skills": ["r_perfect_dodge"], "build_tags": ["Precision", "Tempest"], "interacts_with": "Perfect Dodge -> any attack."})
	aug("splintering_steel", "Splintering Steel", "reaver", "mutation", "advanced",
		"MUTATION: Heavy, Combo Heavy and Charged strikes become 3-hit sequences (DEX scales the total instead of STR). Split adds +2 more hits.",
		{"legacy_reaver": true, "hits": 3, "total_mult": 1.0},
		{"build_tags": ["Tempest"], "interacts_with": "Heavy family. Not applied to Focused attacks. Uncharged Heavy goes to Rising Crescent if owned."})
	aug("one_perfect_cut", "One Perfect Cut", "reaver", "synergy", "advanced",
		"Any attack with 3+ hits concentrates 45% of its total damage into the FINAL hit, which counts as a Heavy strike with +50% Critical Damage.",
		{"legacy_reaver": true, "final_share": 0.45, "final_crit_damage": 0.5},
		{"build_tags": ["Finality", "Tempest"], "interacts_with": "Split, Splintering Steel, Whirling Finisher with Split, Iron... any 3+ hit sequence."})
	aug("legacy_flowing_edge", "Flowing Edge (legacy)", "reaver", "enhancement", "standard",
		"You can move at 55% speed (and steer) during attacks with 3 or more hits.",
		{"move_fraction": 0.55, "legacy_reaver": true},
		{"build_tags": ["Tempest"], "interacts_with": "Split / Splintering Steel sequences."})
	aug("execution_line", "Execution Line", "reaver", "mutation", "advanced",
		"MUTATION: Precision attacks become a long, narrow line (x1.8 reach, x0.55 width) that pierces everything on it, with +30% Critical Damage.",
		{"length_mult": 1.8, "width_mult": 0.55, "crit_damage": 0.3},
		{"requires_bladecraft": true, "build_tags": ["Precision"], "interacts_with": "Bladecraft: Precision."})
	aug("rising_crescent", "Rising Crescent", "reaver", "mutation", "exotic",
		"MUTATION: your uncharged Heavy Attack becomes a rising crescent that launches (staggers) non-boss enemies; the next Light within 1s gains +25% Crit Chance.",
		{"legacy_reaver": true},
		{"build_tags": ["Finality", "Precision"], "interacts_with": "Heavy Attack; Split/Focus/Precision still apply on top."})
	aug("unbroken_form", "Unbroken Form", "reaver", "synergy", "advanced",
		"Arming a DIFFERENT Bladecraft form during a transformed attack lets you cancel its recovery immediately into the next attack, for 15 extra Stamina.",
		{"stamina": 15.0},
		{"requires_bladecraft": true, "build_tags": ["Tempest", "Precision", "Finality"], "interacts_with": "Bladecraft form chains (Split -> Focus etc.)."})


# ------------------------------------------------------------------ progression tracks
func _track(c: String, ms: Array, drafts: Dictionary = {}) -> void:
	var t := ProgressionTrack.new()
	t.class_id = c
	if not drafts.is_empty():
		t.draft_levels = drafts
	var arr: Array[Dictionary] = []
	for m in ms:
		arr.append({"level": m[0], "id": m[1], "kind": m[2], "name": m[3], "desc": m[4], "input": m[5], "icon": m[6]})
	t.milestones = arr
	_save(t, "res://data/progression/%s.tres" % c)


func _progression() -> void:
	var stats := "Attribute points: spend 2 points per level in the Character screen (C)."
	_track("vanguard", [
		[1, "v_guard", "ability", "Aegis Guard", "Hold to block frontal attacks with your shield. Raise it just before impact for a Perfect Guard.", "Shift", "guard"],
		[1, "v_counter", "technique", "Aegis Counter", "After a Perfect Guard, Light Attack becomes a staggering shield-and-sword counter.", "LMB after Perfect Guard", "counter"],
		[1, "v_guarded_strike", "technique", "Guarded Strike", "While holding Guard, LMB is a short sword strike. Your protection is reduced during the swing and returns afterwards.", "Shift + LMB", "sword"],
		[2, "stats_2", "stats", "Attributes", stats, "C", "buff"],
		[3, "shield_rush", "skill", "Shield Rush", "Charge forward behind your shield, striking and drawing enemy attention.", "1", "shield_rush"],
		[4, "draft_4", "augment", "First Augment", "Choose one of three augments.", "", "passive"],
		[5, "v_resolve", "mechanic", "Resolve Spending", "Resolve choices: HOLD 1 = Empowered Shield Rush (30), fully charged 2 = Verdict Strike (40, Lv7), HOLD 3 = Aegis Sweep (25, Lv9). Only skills you have unlocked can spend.", "hold 1 / full 2 / hold 3", "guard"],
		[6, "stats_6", "stats", "Attributes", stats, "C", "buff"],
		[7, "judgment_strike", "skill", "Judgment Strike", "Hold to charge a crushing strike. Right after a Perfect Guard it becomes an instant Riposte.", "2 (hold)", "judgment"],
		[7, "v_intercept", "technique", "Interception", "Shield Rush toward an ally under attack: you take the blow in their place.", "1 toward ally", "shield_rush"],
		[8, "draft_8", "augment", "Advanced Augment", "Choose an Advanced or Exotic augment.", "", "mutation"],
		[9, "iron_sweep", "skill", "Iron Sweep", "A three-hit spin that strikes every nearby enemy. Hold Guard while using it for a Guarded Sweep.", "3", "sweep"],
		[10, "v_bulwark_mastery", "mastery", "Aegis Mastery", "Perfect Guard window +35% and counter windows +40% (existing mechanic; the spec's wording is not yet defined in detail). Plus an augment draft.", "", "guard"],
		[12, "v_shield_plant", "skill", "Shield Plant", "Plant the shield for 4s: reinforced frontal protection and displacement resistance, 15% movement, no rear protection. Press E again (or Dodge) to recover. 15 stamina, 18s cooldown. (Beyond the Lv10 prototype cap: Build Showcase.)", "E", "guard"],
	])
	_track("mage", [
		[1, "m_fire_life", "ability", "Worldweaver", "Fire and Life. Charged spellcasting: hold to prepare, release early for a partial cast or at full charge for the full spell. Flame Cataclysm, Life Bloom, Lifeline.", "LMB / RMB (hold) / F", "fire"],
		[2, "stats_2", "stats", "Attributes", stats, "C", "buff"],
		[3, "m_frost", "element", "Frost", "Frost and Crystal Formation: temporary ice formations that block enemy movement and Chill. Aim to place, orientation follows your aim.", "1 (hold)", "frost"],
		[4, "draft_4", "augment", "First Augment", "Choose one of three augments.", "", "passive"],
		[5, "m_sanctum", "skill", "Arcane Sanctum", "A stationary 3.5m circle under you (10s, 25s cooldown). Spells cast from inside gain one element enhancement each. Never required.", "E", "sigil"],
		[6, "stats_6", "stats", "Attributes", stats, "C", "buff"],
		[7, "m_stone", "element", "Stone", "Stone and Earthbreaker: heavy charged impact with Poise Damage; displacement depends on enemy weight.", "Spellbook", "stone"],
		[7, "m_renewal", "skill", "Protective Renewal", "Preventive protection on your heal target: a limited shield, and part of the damage taken is healed back.", "3", "ward"],
		[8, "draft_8", "augment", "Advanced Augment", "Choose an Advanced or Exotic augment.", "", "mutation"],
		[9, "m_storm", "element", "Storm", "Storm and Thunder Conduit: focused strike, or a full-charge chain (max 3 targets, 6m jumps).", "Spellbook", "storm"],
		[10, "m_arcane_mastery", "mastery", "Arcane Mastery", "Dodging during a releasable charge preserves 40% of that charge for 2s (same spell only, 15s internal cooldown). You must start casting again to use it. Plus an augment draft.", "Space while charging", "mage"],
	], {4: "any", 8: "advanced", 10: "exotic"})
	_track("reaver", [
		[1, "r_blade_lines", "ability", "Blade Lines", "LMB = Forward Cut (always, whatever you are moving). Shift + A / D + LMB = Lateral Cut left / right (short side step). RMB = Heavy Cut. Dodge then LMB = Slip Cut.", "LMB / Shift+A/D+LMB / RMB", "reaver"],
		[1, "r_continuity", "mechanic", "Blade Continuity", "Changing line during the previous cut's recovery is a LINK (Forward<->Lateral, Lateral->Heavy, Dodge->Slip Cut...): faster start, keeps tracking, opens follow-ups. Repeating the same cut is allowed but is not a link. Lateral left<->right reversal is not legal.", "", "split"],
		[2, "stats_2", "stats", "Attributes", stats, "C", "buff"],
		[3, "r_lunge", "skill", "Piercing Lunge", "A precise forward thrust.", "skill slot", "precision"],
		[4, "draft_4", "augment", "First Augment", "Choose one of three augments.", "", "passive"],
		[5, "r_flow_step", "skill", "Flow Step + expanded Continuity", "Short 0.7m directional step (12 stamina, 3s cooldown, NO invulnerability). Used in a link window it keeps your sequence alive for the next cut.", "skill slot", "dodge"],
		[6, "stats_6", "stats", "Attributes", stats, "C", "buff"],
		[7, "r_draw", "technique", "Draw Cut", "Heavy Cut gains a charged form: HOLD RMB for Draw Cut.", "RMB (hold)", "heavy"],
		[7, "r_crosscut", "skill", "Crosscut", "Two-hit technique: wide diagonal, then a narrow reverse slash you can steer slightly. Dodge after the first hit abandons the second.", "skill slot", "split"],
		[8, "draft_8", "augment", "Advanced Augment", "Choose an Advanced or Exotic augment.", "", "mutation"],
		[9, "r_flurry", "skill", "Tempest Flurry", "A six-hit flurry you can steer slightly.", "skill slot", "split"],
		[10, "r_discipline", "mastery", "Swordmaster's Discipline", "Once per sequence, one otherwise illegal directional transition (left <-> right reversal) is allowed as a link. Plus an augment draft.", "", "reaver"],
		[12, "r_sunder_edge", "skill", "Sunder Edge", "Committed angled strike: moderate damage, high Poise damage, extra effect on a raised guard. Long recovery if it misses. (Beyond the Lv10 prototype cap: Build Showcase.)", "skill slot", "heavy"],
		[15, "r_turning_edge", "skill", "Turning Edge", "Short lateral step (A or D held) then a slash. Hitting from a real flank angle prepares Final Stroke. (Build Showcase.)", "skill slot + A/D", "precision"],
		[18, "r_final_stroke", "skill", "Final Stroke", "Finisher, only during a 1.5s opportunity opened by: two different linked cuts that both hit, a Sunder Edge poise break, or a Duelist hit from a flank angle. Costs stamina, can miss, ends the sequence. (Build Showcase.)", "F (when opened)", "reaver"],
	])


# ------------------------------------------------------------------ items
func _item(id: String, nm: String, slot: String, cls: String, rarity: String, tier: int, icon: String, bonuses: Dictionary, desc: String, weight: float = 1.0, min_area: int = 0) -> void:
	var it := ItemData.new()
	it.id = id
	it.display_name = nm
	it.slot = slot
	it.class_id = cls
	it.rarity = rarity
	it.tier = tier
	it.icon = icon
	it.bonuses = bonuses
	it.description = desc
	it.drop_weight = weight
	it.min_area = min_area
	_save(it, "res://data/items/%s.tres" % id)


func _items() -> void:
	# beginner equipment (granted at character creation)
	_item("starter_v_sword", "Squire's Arming Sword", "weapon", "vanguard", "standard", 1, "sword", {}, "A plain but honest blade.")
	_item("starter_v_chest", "Padded Brigandine", "chest", "vanguard", "standard", 1, "shield", {"armor": 6}, "Quilted cloth over riveted plates.")
	_item("starter_m_staff", "Apprentice Staff", "weapon", "mage", "standard", 1, "mage", {}, "Ash wood with a faint ley-crystal.")
	_item("starter_m_chest", "Novice Robes", "chest", "mage", "standard", 1, "life", {"mres": 6}, "Simple robes with embroidered sigils.")
	_item("starter_r_sword", "Traveler's Longsword", "weapon", "reaver", "standard", 1, "sword", {}, "Light, balanced, well cared for.")
	_item("starter_r_chest", "Leather Jerkin", "chest", "reaver", "standard", 1, "reaver", {"armor": 4}, "Supple leather that never slows a cut.")
	_item("starter_boots", "Traveler's Boots", "feet", "", "standard", 1, "dodge", {}, "Worn soles, many roads.")
	# Vanguard
	_item("v_knight_sword", "Knight-Captain's Blade", "weapon", "vanguard", "advanced", 2, "sword", {"power": 0.12, "str": 2}, "Gold-chased steel of the valley guard.", 1.0, 1)
	_item("v_lion_plate", "Lionguard Plate", "chest", "vanguard", "advanced", 2, "shield", {"armor": 22, "vit": 3}, "Polished plate with gold lion filigree.", 1.0, 1)
	_item("v_aegis_plate", "Aegis of the Warden", "chest", "vanguard", "exotic", 3, "shield", {"armor": 35, "vit": 4, "for": 3}, "Ceremonial plate that hums when struck.", 0.4, 2)
	# Mage
	_item("m_ley_staff", "Leycrystal Staff", "weapon", "mage", "advanced", 2, "mage", {"power": 0.12, "mas": 2}, "A crystal that drinks moonlight.", 1.0, 1)
	_item("m_sage_robes", "Robes of the Sage Circle", "chest", "mage", "advanced", 2, "life", {"mres": 18, "mas": 3}, "Layered silk woven with warding thread.", 1.0, 1)
	_item("m_astral_regalia", "Astral Regalia", "chest", "mage", "exotic", 3, "storm", {"mres": 28, "mas": 4, "cdr": 0.08}, "Starlight stitched into living cloth.", 0.4, 2)
	# Reaver
	_item("r_crimson_blade", "Crimson Edge", "weapon", "reaver", "advanced", 2, "sword", {"power": 0.12, "crit": 0.05}, "A red-lacquered blade that sings on the draw.", 1.0, 1)
	_item("r_duelist_coat", "Duelist's Longcoat", "chest", "reaver", "advanced", 2, "reaver", {"armor": 14, "dex": 3, "aspd": 0.05}, "Reinforced at the shoulders, free at the hips.", 1.0, 1)
	_item("r_swiftblade_garb", "Swiftblade Garb", "chest", "reaver", "exotic", 3, "reaver", {"armor": 20, "dex": 3, "str": 3, "critdmg": 0.15}, "The attire of a master who never wastes a motion.", 0.4, 2)
	# shared
	_item("iron_helm", "Ironbound Helm", "head", "", "standard", 1, "shield", {"armor": 6}, "Dented but reliable.", 1.2)
	_item("circlet_of_insight", "Circlet of Insight", "head", "", "advanced", 2, "precision", {"crit": 0.04, "mas": 2}, "A silver band set with a tiny clear stone.", 0.8, 1)
	_item("grip_gloves", "Swordsman's Grips", "hands", "", "standard", 1, "sword", {"dex": 2}, "Leather grips that never slip.", 1.2)
	_item("gauntlets_of_might", "Gauntlets of Might", "hands", "", "advanced", 2, "heavy", {"str": 3, "armor": 5}, "Heavy knuckles for heavy blows.", 0.8, 1)
	_item("windstep_boots", "Windstep Boots", "feet", "", "advanced", 2, "dodge", {"aspd": 0.04, "dex": 1}, "Light as a breeze.", 0.8, 1)
	_item("amulet_of_vigor", "Amulet of Vigor", "accessory", "", "standard", 1, "life", {"vit": 3}, "A warm amber pendant.", 1.2)
	_item("ring_of_ruin", "Ring of Ruin", "accessory", "", "advanced", 2, "fire", {"critdmg": 0.12, "str": 1}, "It bites the finger that wears it.", 0.7, 1)
	_item("ley_charm", "Ley Charm", "accessory", "", "advanced", 2, "weave", {"mas": 3, "cdr": 0.05}, "Threads of ley-light knotted in glass.", 0.7, 1)
	_item("warden_seal", "Seal of the Ashen Warden", "accessory", "", "exotic", 3, "guard", {"vit": 3, "for": 3, "str": 2, "armor": 10}, "Taken from the Warden's gauntlet.", 0.3, 2)
