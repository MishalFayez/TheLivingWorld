extends Node
## Writes collaboration/results/LEVEL10-FOUNDATION-005-CATALOG.md from the real .tres cards (no hand copy).
##   godot --headless --path . res://tools/print_l10_catalog.tscn

const ORDER := ["global", "vanguard", "mage", "reaver"]
const PATHS := {"": "Common", "bulwark": "Bulwark", "counterguard": "Counterguard", "fusion": "Elemental Fusion", "arcane": "Arcane Weaving", "dance": "Dance Mastery", "edge": "Edge Mastery"}


func _ready() -> void:
	var cards: Array = []
	for f in DirAccess.get_files_at("res://data/augments"):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var a = load("res://data/augments/" + file)
			if a is AugmentData and a.pool == "l10":
				cards.append(a)
	cards.sort_custom(func(x, y): return x.code < y.code)
	var lines: Array = []
	lines.append("# LEVEL10-FOUNDATION-005: Augment catalog (60 cards: 57 playable, 3 blocked)")
	lines.append("")
	lines.append("Generated from `data/augments/*.tres` by `tools/print_l10_catalog.gd`. The description is the in-game text, filled from the card's params.")
	lines.append("")
	lines.append("**Status legend**")
	lines.append("")
	lines.append("| Status | Meaning |")
	lines.append("|---|---|")
	lines.append("| ACTIVE | Implemented and drafted |")
	lines.append("| BLOCKED | In the catalog, never offered; a design prerequisite is missing |")
	lines.append("| PARTIAL | Not offered to some classes, with the reason |")
	for cls in ORDER:
		lines.append("")
		lines.append("## " + cls.capitalize())
		lines.append("")
		lines.append("| Code | Card | Path | Rarity | Requires | Party | Cooldown | Status | Effect (in-game text) |")
		lines.append("|---|---|---|---|---|---|---|---|---|")
		for a in cards:
			if a.class_id != cls:
				continue
			var status := "ACTIVE"
			if a.blocked_reason != "":
				status = "BLOCKED: " + a.blocked_reason
			elif not a.blocked_classes.is_empty():
				status = "PARTIAL (not %s): %s" % [", ".join(a.blocked_classes), String(a.params.get("class_block_reason", ""))]
			var path: String = PATHS.get(a.path_id, a.path_id) + (" (ANCHOR)" if a.is_anchor else "")
			lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [a.code, a.display_name, path, a.rarity, ", ".join(a.requires_unlocks) if not a.requires_unlocks.is_empty() else "-",
				"party only" if a.requires_party else "-", ("%ss" % a.cooldown) if a.cooldown > 0.0 else "-", status, AugmentText.describe(a).replace("|", "/")])
	lines.append("")
	lines.append("## Synergies (listed pairs)")
	lines.append("")
	lines.append("Kind: **synergy** = a real extra gameplay effect (only these are announced as SYNERGY AVAILABLE); **visual feedback only**; **rule, no extra benefit** = a limit or clarification; **inactive** = the partner is blocked.")
	lines.append("")
	lines.append("| Card | Partner | Kind | Combined behaviour |")
	lines.append("|---|---|---|---|")
	var seen := {}
	for a in cards:
		for pid in a.synergy_partners:
			var key := [a.id, pid]
			key.sort()
			if seen.has(str(key)):
				continue
			seen[str(key)] = true
			var o = load("res://data/augments/%s.tres" % pid)
			lines.append("| %s | %s | %s | %s |" % [a.display_name, o.display_name if o else pid, AugmentText.kind_name(Game.augment_db.pair_kind(a, o)), String(a.synergy_text.get(pid, "")).replace("|", "/")])
	var f := FileAccess.open("res://collaboration/results/LEVEL10-FOUNDATION-005-CATALOG.md", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("catalog written: %d cards" % cards.size())
	get_tree().quit(0)
