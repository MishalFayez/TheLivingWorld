class_name SkillCatalog
extends RefCounted
## LEVEL10-FOUNDATION-005 (Part 8.3 / 8.5): which real attacks / spells each class skill uses, for the
## Skills-menu tooltips and the Character before/after preview. Numbers are NEVER stored here: every value
## is computed by DamageCalc from the live AttackData / ChargedSpellData resources, the balance config and
## the character's real stats. Charged variants are built by the same static builders the kits use.
##
## Entry: {id, name, unlock, purpose, risk, variants: [{label, attack: AttackData} | {label, spell, full}],
##         heal: {...} (optional), cooldown, cost_kind}


static func _atk(id: String) -> AttackData:
	return load("res://data/attacks/%s.tres" % id) as AttackData


static func _skill(id: String) -> SkillData:
	return load("res://data/skills/%s.tres" % id) as SkillData


static func entries(class_id: String, p: ClassProgress = null) -> Array:
	match class_id:
		"vanguard":
			return _vanguard()
		"reaver":
			return _reaver()
		"mage":
			return _mage(p)
	return []


static func _vanguard() -> Array:
	var rush := _skill("shield_rush")
	var jud := _skill("judgment_strike")
	var sweep := _skill("iron_sweep")
	var b := Game.balance
	return [
		{"id": "v_light", "name": "Sword Cut", "unlock": "", "purpose": "Quick two-step sword combo.", "risk": "Low commitment.",
			"variants": [{"label": "Sword Cut", "attack": _atk("v_light1")}, {"label": "Return Cut", "attack": _atk("v_light2")}]},
		{"id": "v_heavy", "name": "Shieldbreaker Slash", "unlock": "", "purpose": "Heavy strike that pressures Guard and Poise.", "risk": "Long recovery.",
			"variants": [{"label": "Shieldbreaker Slash", "attack": _atk("v_heavy")}]},
		{"id": "v_guard", "name": "Aegis Guard", "unlock": "v_guard", "purpose": "Hold to block frontal attacks; raise just before impact for a Perfect Guard.",
			"risk": "Blocking costs stamina; rear attacks are not covered.",
			"facts": [["Guard reduction", StatStyle.pct(b.guard_reduction)], ["Perfect Guard reduction", StatStyle.pct(b.perfect_guard_reduction)],
				["Perfect Guard window", "%.2fs" % b.perfect_guard_window], ["Frontal arc", "%d°" % roundi(b.guard_frontal_angle)],
				["Stamina per blocked damage", "%.2f" % b.guard_stamina_per_damage], ["Move speed while guarding", StatStyle.pct(b.guard_move_mult)]]},
		{"id": "v_counter", "name": "Aegis Counter", "unlock": "v_counter", "purpose": "After a Perfect Guard, LMB becomes a staggering counter.", "risk": "Only inside the counter window.",
			"variants": [{"label": "Aegis Counter", "attack": _atk("v_counter")}]},
		{"id": "v_guarded_strike", "name": "Guarded Strike", "unlock": "v_guarded_strike", "purpose": "Short strike from Guard.", "risk": "Protection is reduced during the swing.",
			"variants": [{"label": "Guarded Strike", "attack": _atk("v_guarded_strike")}]},
		{"id": "shield_rush", "name": rush.display_name, "unlock": "shield_rush", "purpose": "Charge behind the shield, strike and draw attention.", "risk": "Commits you to a direction.",
			"cooldown": rush.cooldown, "variants": [{"label": rush.display_name, "attack": rush.attack}]},
		{"id": "judgment_strike", "name": jud.display_name, "unlock": "judgment_strike", "purpose": "Hold to charge a crushing strike.", "risk": "Rooted while charging.",
			"cooldown": jud.cooldown, "variants": [{"label": "Uncharged", "attack": ClassKit.charged_attack(jud.attack, 0.0)},
				{"label": "Full charge (%.2fs)" % jud.attack.charge_time, "attack": ClassKit.charged_attack(jud.attack, 1.0)}]},
		{"id": "iron_sweep", "name": sweep.display_name, "unlock": "iron_sweep", "purpose": "Three-hit spin that strikes every nearby enemy.", "risk": "Moderate recovery.",
			"cooldown": sweep.cooldown, "variants": [{"label": sweep.display_name, "attack": sweep.attack}]},
	]


static func _reaver() -> Array:
	if Game.reaver_core != "bladedancer":
		return []
	var lat := _atk("bd_dance_lateral")
	var com := _atk("bd_committed")
	return [
		{"id": "bd_dance", "name": "Dance", "unlock": "bd_dance", "purpose": "LMB attack shaped by your movement input.", "risk": "Moves you for real: you can step out of range.",
			"variants": [{"label": "Neutral", "attack": _atk("bd_dance_neutral")}, {"label": "Forward (W)", "attack": _atk("bd_dance_forward")}, {"label": "Lateral (A / D)", "attack": lat}],
			"motion": [["Forward travel", "%.2fm" % ReaverBladeDancer.forward_distance()], ["Lateral travel", "%.2fm" % ReaverBladeDancer.lateral_distance()]]},
		{"id": "bd_precision", "name": "Precision Cut", "unlock": "bd_edge", "purpose": "Edge (hold RMB) + tap LMB: narrow, fast, longer thrust.", "risk": "Narrow hitbox.",
			"variants": [{"label": "Precision Cut", "attack": _atk("bd_precision")}]},
		{"id": "bd_committed", "name": "Committed Cut", "unlock": "bd_edge", "purpose": "Edge + hold LMB, release: powerful charged sword strike.", "risk": "Long recovery, no dodge during the strike.",
			"variants": [{"label": "Minimum hold (%.2fs)" % ReaverBladeDancer.HOLD_THRESHOLD, "attack": ReaverBladeDancer.committed_attack(com, 0.0)},
				{"label": "Full charge (%.2fs)" % ReaverBladeDancer.COMMIT_MAX, "attack": ReaverBladeDancer.committed_attack(com, 1.0)}]},
		{"id": "bd_orbit", "name": "Orbit Step", "unlock": "bd_footwork", "purpose": "Dance + Q: circle the target, then slash.", "risk": "No invulnerability.",
			"variants": [{"label": "Orbit Step", "attack": _atk("bd_orbit")}]},
		{"id": "bd_withdraw", "name": "Withdraw & Thrust", "unlock": "bd_footwork", "purpose": "Edge + Q: step back, then a long thrust.", "risk": "Misses if the spacing is wrong.",
			"variants": [{"label": "Withdraw & Thrust", "attack": _atk("bd_withdraw")}]},
		{"id": "bd_whirl", "name": "Whirling Assault", "unlock": "bd_offense", "purpose": "Dance + E: mobile multi-hit series.", "risk": "Stamina heavy.",
			"variants": [{"label": "Whirling Assault", "attack": _atk("bd_whirl")}]},
		{"id": "bd_break", "name": "Breaking Point", "unlock": "bd_offense", "purpose": "Edge + E: Poise-breaking strike, x%.1f Poise vs a recovering or staggered enemy." % ReaverBladeDancer.BREAK_PUNISH_POISE,
			"risk": "Long recovery on a miss.", "variants": [{"label": "Breaking Point", "attack": _atk("bd_break")}]},
	]


static func _mage(p: ClassProgress) -> Array:
	var out: Array = []
	var known := {}
	var kit = Game.player.kit if is_instance_valid(Game.player) and Game.player.class_id == "mage" and Game.player.kit is MageKit else null
	for f in DirAccess.get_files_at("res://data/mage_spells"):
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var s = load("res://data/mage_spells/" + file)
		if not (s is ChargedSpellData):
			continue
		var ok := true
		if kit != null and kit.el != null:
			ok = kit.el.spell_known(s.id)
		elif p != null:
			ok = not s.advanced and (s.unlock_id == "" or p.has_unlock(s.unlock_id)) and p.known_elements().has(s.element)
		known[s.id] = ok
		var e := {"id": s.id, "name": s.display_name, "unlock": s.unlock_id, "purpose": s.description, "element": s.element,
			"risk": "Charging slows you to %s speed; a dodge cancels it (no mana spent)." % StatStyle.pct(s.move_mult), "spell": s, "known": ok,
			"cooldown": s.cooldown}
		if s.element == "life":
			e["heal"] = true
		out.append(e)
	out.sort_custom(func(a, b2): return MageElementalist.CHARGED_ORDER.find(a.id) < MageElementalist.CHARGED_ORDER.find(b2.id))
	return out
