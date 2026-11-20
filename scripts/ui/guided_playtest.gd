class_name GuidedPlaytest
extends CanvasLayer
## Optional GUIDED PLAYTEST MODE (refoundation spec 16.2). A small panel on the left edge shows the
## class, scenario, mechanic, what YOU do and what should happen mechanically. It never plays for
## you. Restart re-creates the setup; Skip moves to the next scenario; Hide collapses it.
## Setups are session-only (tainted), using the Class Experience Lab helpers.

const SCENARIOS := [
	# ---------------- Vanguard (spec 17)
	{"id": "V1", "class_id": "vanguard", "title": "Basic Frontline Feel", "level": 1, "enemies": [["raider", 1]],
		"mechanic": "Sword attacks, Guard, Perfect Guard, Aegis Counter, Dodge",
		"actions": "Fight with LMB/RMB. Hold Shift to Guard. Raise Guard just before a hit (Perfect Guard), then LMB (Aegis Counter). Dodge and reposition. Compare defensive vs aggressive play.",
		"expected": "Guard reduces frontal damage; Perfect Guard shows PERFECT GUARD + gold flash and opens a counter; the counter staggers."},
	{"id": "V2", "class_id": "vanguard", "title": "Sentinel", "preset": "Sentinel", "enemies": [["shield_guardian", 1], ["raider", 2]],
		"mechanic": "Defensive positioning, Phantom Bulwark, Shield Plant + Rolling Fortress",
		"actions": "Hold ground with Guard. Shield Rush to leave a Phantom Bulwark. Press E (Shield Plant, showcase), then Space while planted for a planted step (Rolling Fortress). E again to leave the plant.",
		"expected": "Barrier dome absorbs attacks on allies inside; the planted step keeps the plant and shield up."},
	{"id": "V3", "class_id": "vanguard", "title": "Interceptor", "preset": "Interceptor", "party": true, "enemies": [["raider", 1], ["ash_caster", 1]],
		"mechanic": "Interception, Last Line, Guardian's Return",
		"actions": "Let an ally get attacked. Shield Rush (1) toward that ally to intercept. Then press LMB within 1.5s.",
		"expected": "You take the blow instead (intercept); Last Line reduces damage; Guardian's Return gives an Aegis Counter."},
	{"id": "V4", "class_id": "vanguard", "title": "Retribution", "preset": "Retribution", "enemies": [["shield_guardian", 1]],
		"mechanic": "Perfect Guard -> counters -> Resolve Judgment (Verdict of Steel)",
		"actions": "Build Resolve with Perfect Guards and counters. Fully charge Judgment (hold 2) with 40+ Resolve. Compare spending at once vs saving.",
		"expected": "Iron Reprisal empowers the next heavy after a Perfect Guard; full Judgment with Resolve becomes Verdict Strike (Verdict of Steel augment: large poise)."},
	# ---------------- Mage (spec 18)
	{"id": "M1", "class_id": "mage", "title": "Basic Spellcasting", "level": 1, "enemies": [["wolf", 1]],
		"mechanic": "Partial vs full charge, moving while charging, dodge-cancel, self-heal, Lifeline",
		"actions": "Tap LMB (partial Flame), hold LMB to full and release. Move while charging. Dodge mid-charge. Hold RMB to heal yourself. Press F when low.",
		"expected": "Partial = small explosion, full = bigger + burning area; dodge cancels with no mana spent; Lifeline heals instantly (12s cooldown)."},
	{"id": "M2", "class_id": "mage", "title": "Frost and Worldshaping", "level": 3, "enemies": [["wolf", 3]],
		"mechanic": "Crystal Formation placement / rotation, Thermal Fracture",
		"actions": "Hold 1, aim with the camera (preview rotates), release partial then full. Watch wolves path around. Fire (LMB) into the ice: partial vs full.",
		"expected": "Partial = 1.5m ice, full = 4m; wolves go around; partial Fire = fragments, full Fire = steam that blocks sight."},
	{"id": "M3", "class_id": "mage", "title": "Cataclysm", "preset": "Cataclysm", "enemies": [["shield_guardian", 1], ["raider", 3]],
		"mechanic": "Direct charged spells, Infernal Collapse / Mountainfall",
		"actions": "Use full Flame on grouped Raiders, Earthbreaker (1) on the Guardian, test the mutations, dodge out of a committed cast.",
		"expected": "Delayed secondary explosion (Infernal Collapse); overhead Earthbreaker (Mountainfall); dodge keeps 40% charge (Arcane Mastery)."},
	{"id": "M4", "class_id": "mage", "title": "Worldcraft", "preset": "Worldcraft", "enemies": [["ash_caster", 2], ["raider", 2]],
		"mechanic": "Formations, Stone cover, Thermal Fracture, Conductive Anchors, Sanctum",
		"actions": "Raise ice (LMB), Stone Ward (3). Full Thunder Conduit (hold 1) past the Stone Ward to make it Conductive, then chain again. Cast E and compare inside/outside.",
		"expected": "CONDUCTIVE ROUTE label on the stone; later chains relay through it (twice with Storm Lattice); Sanctum enhancements only inside the circle."},
	{"id": "M5", "class_id": "mage", "title": "Lifebinding", "preset": "Lifebinding", "party": true, "enemies": [["ashen_warden", 1]],
		"mechanic": "Partial / full Life Bloom, Lifeline, Protective Renewal, Shared Bloom, Living Bastion",
		"actions": "T to target the Vanguard. Partial and full Life Bloom; Lifeline in emergencies; Protective Renewal (3) before the boss slam; switch Shared Bloom in the Spellbook (B).",
		"expected": "Overheal becomes a shield (Second Heart); PROTECTED banner; full Bloom near a Stone Ward Vitalizes it."},
	# ---------------- Reaver (spec 19)
	{"id": "R1", "class_id": "reaver", "title": "Basic Swordsmanship", "level": 1, "enemies": [["raider", 1]],
		"mechanic": "Forward / Lateral / Heavy cut selection, lock-on vs free",
		"actions": "LMB = Forward Cut (even while moving). Shift + A / D + LMB = Lateral Cut left / right. RMB = Heavy Cut. Dodge. Repeat with and without lock-on (Tab).",
		"expected": "Each input gives the named cut; lateral cuts step ~0.6m sideways; no auto-dash to the target."},
	{"id": "R2", "class_id": "reaver", "title": "Blade Continuity", "level": 5, "enemies": [["raider", 1]],
		"mechanic": "Legal links, invalid link, buffered input, dodge windows",
		"actions": "Forward Cut, then Shift+A+LMB during its recovery. Try Shift+A then Shift+D (illegal reversal). Repeat LMB alone. Press early to test buffering.",
		"expected": "Changing line links (gold glint, faster start); repeating the same cut works but never links; reversal shows NO LINK; a buffered press keeps the direction you pressed."},
	{"id": "R3", "class_id": "reaver", "title": "Flowblade", "preset": "Flowblade", "enemies": [["raider", 3]],
		"mechanic": "Linked pressure, Crosswind, Unbroken Line, Flurry steering",
		"actions": "Chain Forward / Shift+A / Shift+D cuts (Crosswind allows reversals). Flow Step (3) inside a link window, then cut. Crosscut (1). Dodge mid-sequence then attack (Unbroken Line). Two different linked hits open Final Stroke (F).",
		"expected": "Links survive Flow Step and a dodge; FINAL STROKE opens after two different linked hits."},
	{"id": "R4", "class_id": "reaver", "title": "Breaker", "preset": "Breaker", "enemies": [["shield_guardian", 1]],
		"mechanic": "Draw Cut, guard pressure, Drawn Horizon",
		"actions": "Draw Cut (hold RMB) into the shield, then Sunder Edge (1). Break its poise, then F for Final Stroke. Miss a Sunder Edge on purpose.",
		"expected": "GUARD WEAKENED; Sunder Edge pushes more through the guard and breaks poise; missed Sunder Edge has a long recovery; Final Stroke opens after the break."},
	{"id": "R5", "class_id": "reaver", "title": "Duelist", "preset": "Duelist", "enemies": [["shield_guardian", 1], ["raider", 1]],
		"mechanic": "Distance, Piercing Lunge, Slip Cut, Measured Step, Turning Steel",
		"actions": "Lunge (1) then Space (Measured Step). Hold A or D and press 2 (Turning Edge) to step and cut at the Guardian's flank. Dodge then LMB (Slip Cut). F when FINAL STROKE appears.",
		"expected": "A flank hit (>=60 deg) avoids the shield and opens Final Stroke; a frontal Turning Edge does not."},
	# ---------------- Design-resolution scenarios (resolution doc section 10)
	{"id": "RA", "class_id": "reaver", "title": "Directional Intent", "level": 5, "enemies": [["raider", 1]],
		"mechanic": "LMB is always Forward Cut; Shift + A/D selects Lateral",
		"actions": "Lock on (Tab) and strafe around the Raider holding A or D while pressing LMB. Then hold Shift + A (or D) and press LMB.",
		"expected": "Strafing + LMB = Forward Cut only. Shift + A / D + LMB = Lateral Cut to that side."},
	{"id": "RB", "class_id": "reaver", "title": "Repetition vs Paths", "level": 10, "enemies": [["raider", 1]],
		"mechanic": "Repeated Forward Cut vs deliberate line changes",
		"actions": "Reset metrics (Lab). Mash LMB for 6s. Reset. Alternate LMB / Shift+A / LMB / Shift+D / RMB for 6s. Compare the training panel (DPS, stamina, links).",
		"expected": "Repeats never link; deliberate paths link (faster starts, wider lateral arcs, heavy poise) and measured higher DPS in the automated comparison."},
	{"id": "RC", "class_id": "reaver", "title": "Flow Step", "level": 5, "enemies": [["raider", 2]],
		"mechanic": "0.7m step, no invulnerability, collisions, continuation",
		"actions": "Flow Step (2) toward a Raider and into a wall. Cut, Flow Step during its recovery, then a different cut.",
		"expected": "Short step in the input direction; you stop at bodies / walls; hits still land on you during it; the next different cut is linked."},
	{"id": "RD", "class_id": "reaver", "title": "Crosscut", "level": 7, "enemies": [["raider", 1]],
		"mechanic": "Two hits, dodge abandons the second",
		"actions": "Crosscut (3): watch both hits. Repeat and Dodge right after the first hit.",
		"expected": "Two hits (wide, then narrow); with the dodge only the first hit lands - damage is never duplicated."},
	{"id": "RE", "class_id": "reaver", "title": "Sunder Edge", "preset": "Breaker", "enemies": [["shield_guardian", 1], ["raider", 1]],
		"mechanic": "Guard + poise pressure vs guarding / non-guarding enemies",
		"actions": "Sunder Edge (1) into the Guardian's shield, then into the Raider. Miss once on purpose.",
		"expected": "More gets through the raised guard than with a normal heavy, high poise damage; long recovery on a miss."},
	{"id": "RF", "class_id": "reaver", "title": "Turning Edge", "preset": "Duelist", "enemies": [["shield_guardian", 1]],
		"mechanic": "Real angle matters",
		"actions": "Turning Edge (2) straight at the shield. Then circle to its side and use Turning Edge (A/D) so you strike its flank.",
		"expected": "Frontal: blocked like any cut. Flank (>=60 deg): not blocked, and FINAL STROKE opens."},
	{"id": "RG", "class_id": "reaver", "title": "Final Stroke", "preset": "Flowblade", "enemies": [["raider", 1]],
		"mechanic": "Opens only when eligible, expires, can miss, costs stamina, ends continuity",
		"actions": "Press F with nothing open. Then link LMB -> Shift+A+LMB (both hit) and press F within 1.5s. Try waiting 2s instead. Try it out of range.",
		"expected": "Refused when not open; opens after two different linked hits; gone after 1.5s; can whiff; costs 25 stamina; the line marks reset."},
	{"id": "VH", "class_id": "vanguard", "title": "Guarded Strike", "level": 5, "enemies": [["raider", 1]],
		"mechanic": "Active guarding vs passive guarding",
		"actions": "Hold Shift and press LMB repeatedly while the Raider attacks. Compare with just holding Shift.",
		"expected": "Short strikes from Guard; you take more damage during the swing (narrower, weaker guard) and Guard returns after; +3 Resolve per valid hit."},
	{"id": "VI", "class_id": "vanguard", "title": "Shield Plant", "preset": "Sentinel", "enemies": [["shield_guardian", 1], ["raider", 2]],
		"mechanic": "Reinforced stance, not immunity",
		"actions": "Press E. Let attacks hit from the front, the side and behind; take a Guardian Guard Breaker. Dodge (Rolling Fortress) while planted. Press E to recover.",
		"expected": "Strong frontal + side-front protection, little knockback, 15% move; rear hits land fully; Guard Breaker still breaks the plant."},
	{"id": "VJ", "class_id": "vanguard", "title": "Resolve Choices", "level": 10, "enemies": [["raider", 3], ["ash_caster", 1]],
		"mechanic": "Empowered Shield Rush (30) / Verdict Strike (40) / Aegis Sweep (25)",
		"actions": "Build Resolve (Perfect Guards). Spend it: HOLD 1, or charge 2 fully, or HOLD 3. Try each against the group and against the caster.",
		"expected": "Rush taunts + staggers at distance, Verdict is a big single poise hit, Aegis Sweep pulls the group onto you - each best in a different situation."},
	# ---------------- Cross-class (spec 20) - same enemies for every class, nothing modified
	{"id": "A", "class_id": "any", "title": "One Raider", "enemies": [["raider", 1]], "mechanic": "Class identity vs a single melee", "actions": "Fight with each class in turn (Lab: switch class, Restart).", "expected": "Vanguard defends/counters, Mage charges/positions, Reaver picks angles."},
	{"id": "B", "class_id": "any", "title": "Three Wolves", "enemies": [["wolf", 3]], "mechanic": "Multiple fast threats", "actions": "Same, with each class.", "expected": "Vanguard controls pressure, Mage controls routes, Reaver handles close threats."},
	{"id": "C", "class_id": "any", "title": "Shield Guardian", "enemies": [["shield_guardian", 1]], "mechanic": "Guarded enemy", "actions": "Same, with each class.", "expected": "Counterpressure / Stone tools / guard-breaking techniques."},
	{"id": "D", "class_id": "any", "title": "Ash Caster", "enemies": [["ash_caster", 1]], "mechanic": "Ranged caster", "actions": "Same, with each class.", "expected": "Protected approach / Storm interruption (Lightning Verdict, showcase) / closing distance."},
	{"id": "E", "class_id": "any", "title": "Ashen Warden", "enemies": [["ashen_warden", 1]], "mechanic": "Boss", "actions": "Same, with each class.", "expected": "Guard / sustained healing / DPS windows."},
	{"id": "F", "class_id": "any", "title": "Party Test", "party": true, "enemies": [["raider", 2], ["ash_caster", 1], ["wolf", 2]], "mechanic": "Synergy, AI, statuses, performance", "actions": "Play any class with AI allies.", "expected": "Vanguard holds attention, Mage supports, Reaver flanks."},
]

static var current: GuidedPlaytest
var scenario: Dictionary = {}
var panel: PanelContainer
var body: RichTextLabel
var collapsed: bool = false


static func find(id: String) -> Dictionary:
	for s in SCENARIOS:
		if s.id == id:
			return s
	return {}


static func start(id: String) -> void:
	var s := find(id)
	if s.is_empty():
		return
	if current == null or not is_instance_valid(current):
		current = GuidedPlaytest.new()
		Game.get_tree().root.add_child(current)
	current.scenario = s
	current._setup()
	current._refresh()


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD.darkened(0.4), 0.82))
	UIUtil.place(panel, 0, 0.5, 0, 0.5, 12, -150, 392, 150)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(370, 0)
	body.add_theme_font_size_override("normal_font_size", 13)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(UIUtil.button("Restart", func():
		_setup()
		_refresh()))
	row.add_child(UIUtil.button("Skip", func(): _skip()))
	row.add_child(UIUtil.button("Hide / Show", func():
		collapsed = not collapsed
		_refresh()))
	row.add_child(UIUtil.button("End", func(): queue_free()))


func _skip() -> void:
	var i := -1
	for k in SCENARIOS.size():
		if SCENARIOS[k].id == scenario.id:
			i = k
	for k in range(i + 1, SCENARIOS.size()):
		var c: String = SCENARIOS[k].class_id
		if c == Game.active_class or c == "any":
			scenario = SCENARIOS[k]
			_setup()
			_refresh()
			return
	queue_free()


func _setup() -> void:
	Game.taint("guided playtest")
	var s := scenario
	if s.class_id != "any" and s.class_id != Game.active_class:
		Game.switch_class(s.class_id)
	if s.get("party", false) != Game.party_mode and s.has("party"):
		Game.set_party_mode(bool(s.party))
	if is_instance_valid(Game.world):
		Game.world.teleport_player("training")
	ClassLab.reset_encounter()
	if s.has("preset"):
		for p in ClassLab.PRESETS.get(Game.active_class, []):
			if p.name == s.preset:
				ClassLab.apply_preset(p)
	elif s.has("level"):
		ClassLab.apply_level(int(s.level))
	for e in s.get("enemies", []):
		ClassLab.spawn(e[0], int(e[1]))
	ClassLab.restore()


func _refresh() -> void:
	var s := scenario
	if collapsed:
		body.text = "[b]%s[/b] %s  (guided)" % [s.id, s.title]
		return
	body.text = "[color=#f2d27f][b]%s  ·  %s[/b][/color]  -  %s%s\n[b]Mechanic:[/b] %s\n[b]You do:[/b] %s\n[b]Expected:[/b] %s\n[color=#9a9a9a]Setup: %s%s · nothing here is saved[/color]" % [
		s.id, s.title, Game.active_class.capitalize(), "  (BUILD SHOWCASE)" if s.has("preset") else "",
		s.mechanic, s.actions, s.expected,
		("preset " + s.preset) if s.has("preset") else ("Level %d" % int(s.get("level", Game.prog().level))),
		"  · party" if s.get("party", false) else ""]
