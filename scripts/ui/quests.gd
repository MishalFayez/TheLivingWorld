class_name Quests
extends RefCounted
## Objectives derived from the live world state (no separate quest database needed for the
## prototype): clear each area's encounters, open the ash gates, defeat the Warden, plus the
## class-specific discovery (Mage elements) and the training grounds.

static func list() -> Array:
	var w = Game.world
	var out: Array = []
	if w == null or not ("zones" in w):
		return out
	var order := ["outskirts", "ruins", "keep"]
	var first_open := ""
	for a in order:
		var zs: Array = w.zones.get(a, [])
		var n_done := 0
		for z in zs:
			if z.done:
				n_done += 1
		var cleared: bool = w.cleared.get(a, false)
		if not cleared and first_open == "":
			first_open = a
		var area_name: String = w.AREAS[a].name
		out.append({"id": a, "title": "Clear the " + area_name, "done": cleared, "active": first_open == a,
			"text": "Defeat every encounter in the %s. Clearing it dissolves the ash gate ahead." % area_name,
			"progress": "%d / %d encounters" % [n_done, zs.size()], "area": a})
	var boss_done: bool = w.cleared.get("boss", false)
	out.append({"id": "boss", "title": "Defeat the Ashen Warden", "done": boss_done, "active": first_open == "" and not boss_done,
		"text": "The Warden waits in the burning arena at the heart of the Keep. Three phases; read its telegraphs."})
	if Game.active_class == "mage":
		var p := Game.prog("mage")
		var known: Array = p.known_elements()
		var txt := "Frost and Storm are found in battle; Stone answers at the Elemental Shrine in the Ruins."
		if Game.mage_core == "elementalist":
			txt = "Grand Elementalist: Frost awakens at Level 3; at Level 9 choose Stone or Storm (the other remains obtainable later in the full journey)."
		out.append({"id": "elements", "title": "Discover the elements", "done": known.size() >= 4, "active": false, "text": txt,
			"progress": "Known: " + ", ".join(known.map(func(e): return String(e).capitalize()))})
	out.append({"id": "training", "title": "Optional: Training Grounds", "done": false, "active": false,
		"text": "Test damage, crits and DPS against configurable dummies (south of the valley entrance, or Character Selection > Training)."})
	return out


static func current() -> Dictionary:
	for q in list():
		if q.active:
			return q
	return {}
