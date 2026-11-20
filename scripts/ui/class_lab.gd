class_name ClassLab
extends RefCounted
## CLASS EXPERIENCE LAB (refoundation spec 16). Lives in the Debug Panel (F1 -> "Lab" tab).
## Every action taints the session (Game.taint) so NOTHING here is ever written to a normal save.
## The Lab only changes temporary session state: level, unlocks, augments, spells, enemies.

## Build presets. "natural" presets respect progression (Level 10 + 3 pending drafts for the
## player to pick). "showcase" presets give the build's approved augments/abilities at once and
## are labelled BUILD SHOWCASE: they are NOT a naturally obtainable Level 10 build.
const PRESETS := {
	"vanguard": [
		{"name": "Sentinel", "level": 10, "unlocks": ["v_shield_plant"], "augments": ["steadfast", "rolling_fortress", "phantom_bulwark", "unyielding_charge"],
			"note": "Holding ground: Shield Plant (Lv12 skill, showcase) + Rolling Fortress."},
		{"name": "Interceptor", "level": 10, "augments": ["last_line", "guardians_return", "guardians_reserve", "unyielding_charge"], "party": true,
			"note": "Ally rescue with Shield Rush interception (Lv7), Guardian's Return / Reserve."},
		{"name": "Retribution", "level": 10, "augments": ["iron_reprisal", "crushing_rhythm", "verdict_of_steel"],
			"note": "Perfect Guard -> counters -> Resolve Judgment finisher."},
	],
	"mage": [
		{"name": "Cataclysm", "level": 10, "augments": ["infernal_collapse", "mountainfall", "living_thunder"],
			"spells": ["inferno_wave", "cinderfall", "lightning_verdict"], "loadout": ["flame_cataclysm", "life_bloom", "earthbreaker", "protective_renewal"],
			"note": "Direct high-impact charged spells."},
		{"name": "Worldcraft", "level": 10, "augments": ["crystal_chain", "storm_lattice", "living_bastion"],
			"spells": ["stone_ward", "rising_pillar", "frozen_bastion", "storm_arc"], "loadout": ["crystal_formation", "life_bloom", "thunder_conduit", "stone_ward"],
			"note": "Formations + interactions + Sanctum. Stone Ward / Rising Pillar have no approved level (showcase only)."},
		{"name": "Lifebinding", "level": 10, "augments": ["everlasting_bloom", "second_heart", "living_bastion"], "party": true,
			"spells": ["verdant_renewal", "bloom_modes", "stone_ward"], "loadout": ["flame_cataclysm", "life_bloom", "verdant_renewal", "protective_renewal"],
			"note": "Healing, protection, recovery."},
	],
	"reaver": [
		{"name": "Flowblade", "level": 10, "unlocks": ["r_final_stroke"], "augments": ["flowing_edge", "crosswind", "unbroken_line"],
			"reaver_loadout": ["r_crosscut", "r_flurry", "r_flow_step", "r_lunge"],
			"note": "Linked lines + Flow Step + Crosscut; Final Stroke (Lv18) opened by linked hits."},
		{"name": "Breaker", "level": 10, "unlocks": ["r_sunder_edge", "r_final_stroke"], "augments": ["sundering_verdict", "drawn_horizon"],
			"reaver_loadout": ["r_sunder_edge", "r_crosscut", "r_flow_step", "r_lunge"],
			"note": "Draw Cut, Sunder Edge (Lv12), Final Stroke (Lv18). Finality augment not specified."},
		{"name": "Duelist", "level": 10, "unlocks": ["r_turning_edge", "r_final_stroke"], "augments": ["measured_step", "turning_steel", "needlepoint"],
			"reaver_loadout": ["r_lunge", "r_turning_edge", "r_flow_step", "r_crosscut"],
			"note": "Lunge, Turning Edge (Lv15), Slip Cut, Measured Step; Final Stroke from flank hits."},
	],
}

const CONTROLS := {
	"vanguard": "LMB sword · RMB heavy · Shift (hold) Guard - raise just before a hit = Perfect Guard · Shift + LMB = Guarded Strike · LMB after Perfect Guard = Aegis Counter · 1 Shield Rush (HOLD = Empowered, 30 Resolve) · 2 (hold) Judgment Strike (full + 40 Resolve = Verdict Strike) · 3 Iron Sweep (HOLD = Aegis Sweep, 25 Resolve) · E Shield Plant (Lv12) · Space Dodge",
	"mage": "LMB / RMB / 1 (hold, release) charged spell slots · 3 utility (hold to aim formations) · F Lifeline · E Arcane Sanctum · T cycle heal target · 2 most injured ally · B Spellbook · Space Dodge (cancels a charge, no mana spent)",
	"reaver": "LMB Forward Cut (always) · Shift + A/D + LMB Lateral Cut · RMB Heavy Cut (Lv7: hold = Draw Cut) · Dodge then LMB = Slip Cut · 1/2/3/E skill slots (Skills menu K) · F Final Stroke when opened · links: change cut during the previous cut's recovery",
}

const ENEMIES := [["Raider", "raider", 1], ["3 Wolves", "wolf", 3], ["Shield Guardian", "shield_guardian", 1], ["Ash Caster", "ash_caster", 1],
	["Raiders (3)", "raider", 3], ["Ashen Warden (boss)", "ashen_warden", 1]]


static func build(panel, content: VBoxContainer) -> void:
	content.add_child(UIUtil.header("CLASS EXPERIENCE LAB  ·  session only - never saved (%s)" % ("tainted" if Game.debug_tainted else "clean")))
	content.add_child(UIUtil.label("Compare class identities and build directions. Presets marked BUILD SHOWCASE unlock a whole build at once and are NOT obtainable naturally by Level 10.", 12))
	var cr := HFlowContainer.new()
	content.add_child(cr)
	for c in Game.CLASSES:
		var cid: String = c
		cr.add_child(UIUtil.button(("> " if cid == Game.active_class else "") + cid.capitalize(), func(): panel._taint_do("lab class", func(): Game.switch_class(cid))))
	cr.add_child(UIUtil.button("Mode: " + ("PARTY" if Game.party_mode else "SOLO") + " (toggle)", func(): panel._taint_do("lab party", func(): Game.set_party_mode(not Game.party_mode))))
	cr.add_child(UIUtil.check("Temporary invincibility", Game.invincible, func(on): panel._taint_do("lab invincible", func(): Game.invincible = on)))
	content.add_child(UIUtil.label("Controls (%s): %s" % [Game.active_class.capitalize(), CONTROLS.get(Game.active_class, "")], 12))
	content.add_child(UIUtil.header("Presets"))
	var pr := HFlowContainer.new()
	content.add_child(pr)
	for lv in [1, 5, 10]:
		var l: int = lv
		pr.add_child(UIUtil.button("Fresh Level %d%s" % [l, " (3 drafts pending)" if l == 10 else (" (1 draft pending)" if l == 5 else "")], func(): panel._taint_do("lab level", func(): apply_level(l))))
	for p in PRESETS.get(Game.active_class, []):
		var pp: Dictionary = p
		pr.add_child(UIUtil.button("BUILD SHOWCASE: " + pp.name, func(): panel._taint_do("lab preset", func(): apply_preset(pp))))
	for p in PRESETS.get(Game.active_class, []):
		content.add_child(UIUtil.label("%s: %s  [%s]" % [p.name, p.note, ", ".join(p.augments)], 11))
	content.add_child(UIUtil.header("Encounter (Training Grounds)"))
	var er := HFlowContainer.new()
	content.add_child(er)
	for e in ENEMIES:
		var ee: Array = e
		er.add_child(UIUtil.button(ee[0], func(): panel._taint_do("lab spawn", func(): spawn(ee[1], ee[2]))))
	var rr := HFlowContainer.new()
	content.add_child(rr)
	rr.add_child(UIUtil.button("Restore resources", func(): restore()))
	rr.add_child(UIUtil.button("Reset encounter", func(): reset_encounter()))
	rr.add_child(UIUtil.button("Reset training metrics", func(): Training.reset()))
	rr.add_child(UIUtil.button("Save baseline", func(): Training.save_baseline()))
	for a in [["Training Grounds", "training"], ["Valley Outskirts", "outskirts"], ["Forgotten Ruins", "ruins"], ["Warden's Keep", "keep"]]:
		var aa: Array = a
		rr.add_child(UIUtil.button("Teleport: " + aa[0], func(): Game.world.teleport_player(aa[1])))
	var cmp := ""
	for r in Training.comparison():
		cmp += "%s: %s (baseline %s) %s\n" % [r[0], str(r[1]), str(r[2]), r[3]]
	content.add_child(UIUtil.label("Metrics vs baseline:\n" + (cmp if cmp != "" else "(hit the dummy / fight to collect metrics)"), 11))
	content.add_child(UIUtil.label("Skill unlocks and single augments: Character tab -> Abilities / Augments. Mage spells: Character tab -> Worldweaver testing.", 11))
	content.add_child(UIUtil.header("Guided playtest scenarios (you play - nothing is automated)"))
	var cls := Game.active_class
	var gl := HFlowContainer.new()
	content.add_child(gl)
	for sc in GuidedPlaytest.SCENARIOS:
		var s2: Dictionary = sc
		if s2.class_id == cls or s2.class_id == "any":
			gl.add_child(UIUtil.button(s2.id + "  " + s2.title, func(): GuidedPlaytest.start(s2.id)))
	# wrap long Lab text so the panel keeps its width (new scenario buttons stay on screen)
	for c in content.get_children():
		if c is Label:
			c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c.custom_minimum_size.x = 0


static func apply_level(lv: int) -> void:
	var c := Game.active_class
	var p: ClassProgress = Game.prog(c)
	p.debug_unlocks.clear()
	p.debug_locks.clear()
	p.debug_elements.clear()
	p.augments.clear()
	p.inactive_mutations.clear()
	if c == "mage":
		p.spell_loadout = ["flame_cataclysm", "life_bloom", "", ""]
	p.reaver_loadout = ["", "", "", ""]
	Game.set_level(c, lv)
	p.pending_drafts = 0
	p.drafts_taken = 0
	var t := Game.track(c)
	if t:
		for k in t.draft_levels.keys():
			if int(k) <= lv:
				p.pending_drafts += 1
	Game.refresh_class_heroes(c)
	restore()


static func apply_preset(pp: Dictionary) -> void:
	var c := Game.active_class
	apply_level(int(pp.level))
	var p: ClassProgress = Game.prog(c)
	p.pending_drafts = 0
	for id in pp.get("spells", []):
		p.debug_unlocks.append("spell:" + String(id))
	for id in pp.get("unlocks", []):
		p.debug_unlocks.append(String(id))
	if pp.has("reaver_loadout"):
		p.reaver_loadout = Array(pp.reaver_loadout)
	for a in pp.augments:
		Game.add_augment(c, a)
	if pp.has("loadout"):
		p.spell_loadout = Array(pp.loadout)
	if pp.get("party", false) and not Game.party_mode:
		Game.set_party_mode(true)
	Game.refresh_class_heroes(c)
	restore()
	Events.notify.emit("BUILD SHOWCASE: %s (not a natural Level 10 build)" % pp.name)


static func spawn(type: String, count: int) -> void:
	if not is_instance_valid(Game.player):
		return
	var base: Vector3 = Game.player.global_position + Game.player.forward() * 8.0
	for i in count:
		var off := Vector3((i - (count - 1) * 0.5) * 2.5, 0.3, randf_range(-1.0, 1.0))
		var e := Game.spawn_enemy(type, base + off, Game.current_area_key(), false)
		if e:
			e.update_target(0.0)


static func restore() -> void:
	for h in Game.heroes:
		if not is_instance_valid(h):
			continue
		if h.downed:
			h.revive(null)
		h.restore_all()
		h.kit.cooldowns.clear()
		if h.kit is MageKit:
			h.kit.mana = Game.balance.mana_max


static func reset_encounter() -> void:
	for e in Game.enemies():
		if is_instance_valid(e) and not (e is TrainingDummy):
			e.queue_free()
	for h in Game.heroes:
		if is_instance_valid(h) and h.kit is MageKit and h.kit.elementalist():
			h.kit.el.clear_world()
	restore()
