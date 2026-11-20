class_name AugmentDB
extends RefCounted
## Loads every AugmentData resource and runs eligibility checks + rarity-weighted drafts.

var all: Dictionary = {}   # id -> AugmentData


func load_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Augment dir missing: " + path)
		return
	for f in dir.get_files():
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var a = load(path.path_join(file))
		if a is AugmentData:
			all[a.id] = a


func get_augment(id: String) -> AugmentData:
	return all.get(id)


func for_class(class_id: String) -> Array:
	var out: Array = []
	for a in all.values():
		if a.class_id == class_id:
			out.append(a)
	out.sort_custom(func(x, y): return x.display_name < y.display_name)
	return out


## Returns "" when eligible, otherwise the reason it is hidden from drafts.
func ineligible_reason(a: AugmentData, p: ClassProgress) -> String:
	if a.class_id != p.class_id:
		return "wrong class"
	var stacks := p.augment_stacks(a.id)
	if stacks > 0 and not a.stackable:
		return "already owned"
	if a.stackable and stacks >= a.max_stacks:
		return "max stacks"
	for s in a.requires_skills:
		if not p.has_unlock(s):
			var lv := p.track().unlock_level(s) if p.track() else -1
			return "requires %s%s" % [s, " (Lv %d)" % lv if lv > 0 else ""]
	if a.params.has("requires_core"):
		var core: String = a.params["requires_core"]
		if core in ["sigils", "weave", "elementalist"] and Game.mage_core != core:
			return "requires Mage core " + core
		if core in ["sense", "bladecraft", "swordmaster", "freeflow"] and Game.reaver_core != core:
			# REAVER-FREEFLOW-001: a Swordmaster augment that does not depend on Blade Lines / directional
			# links is explicitly flagged compatible; every other one is incompatible with Free Flow
			# pending an approved migration design.
			if not (core == "swordmaster" and Game.reaver_core == "freeflow" and freeflow_compatible(a)):
				return ("incompatible with Free Flow (pending migration design)" if Game.reaver_core == "freeflow" else "requires Reaver core " + core)
	if a.params.get("legacy_reaver", false) and Game.reaver_core in ["swordmaster", "freeflow"]:
		return "legacy Reaver core only"
	# REAVER-FREEFLOW-001: the Decisive Cut transformations are mutually exclusive (one per run).
	if a.params.has("exclusive_group"):
		var other := owned_in_group(p, String(a.params["exclusive_group"]), a.id)
		if other != "":
			return "excluded by " + other
	if a.params.get("legacy_only", false) and a.class_id == "mage" and Game.mage_core == "elementalist":
		return "legacy Mage core only"
	if a.params.has("excludes") and p.augment_stacks(String(a.params["excludes"])) > 0:
		return "excluded by " + String(a.params["excludes"])
	var known: Array = p.known_elements()
	for e in a.requires_elements:
		if not known.has(e):
			return "requires element " + e
	for e in a.requires_missing_elements:
		if known.has(e):
			return "element already discovered"
	if a.requires_bladecraft and Game.reaver_core != "bladecraft":
		return "requires Bladecraft core"
	if not a.requires_any_augment.is_empty():
		var ok := false
		for r in a.requires_any_augment:
			if p.augment_stacks(r) > 0:
				ok = true
		if not ok:
			return "requires one of " + ", ".join(a.requires_any_augment)
	return ""


static func freeflow_compatible(a: AugmentData) -> bool:
	return a != null and bool(a.params.get("freeflow_compatible", false))


## Id of an augment of `group` that `p` already owns (other than `except_id`), or "".
func owned_in_group(p: ClassProgress, group: String, except_id: String = "") -> String:
	for id in p.augments:
		if id == except_id:
			continue
		var o: AugmentData = all.get(id)
		if o != null and String(o.params.get("exclusive_group", "")) == group:
			return id
	return ""


## REAVER-FREEFLOW-001: true when an owned Reaver augment has no effect under the Free Flow core
## (it belongs to another core and is not flagged compatible). Such augments stay in the save.
func freeflow_inactive(a: AugmentData) -> bool:
	if a == null or a.class_id != "reaver" or Game.reaver_core != "freeflow":
		return false
	if a.params.get("legacy_reaver", false) or a.requires_bladecraft:
		return true
	var core := String(a.params.get("requires_core", ""))
	return core != "" and core != "freeflow" and not freeflow_compatible(a)


func eligible(class_id: String, p: ClassProgress) -> Array:
	var out: Array = []
	for a in for_class(class_id):
		if ineligible_reason(a, p) == "":
			out.append(a)
	return out


## tier: "any" | "advanced" (no Standard if alternatives exist) | "exotic" (Exotic weighted x4)
func roll(class_id: String, p: ClassProgress, count: int, rng: RandomNumberGenerator, tier: String = "any") -> Array:
	var pool := eligible(class_id, p)
	var picked: Array = []
	var weights: Dictionary = Game.balance.rarity_weights.duplicate()
	if tier == "advanced" or tier == "exotic":
		var better := pool.filter(func(a): return a.rarity != "standard")
		if better.size() >= count:
			pool = better
	if tier == "exotic":
		weights["exotic"] = float(weights.get("exotic", 10.0)) * 4.0
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for a in pool:
			total += float(weights.get(a.rarity, 1.0))
		var r := rng.randf() * total
		var chosen = pool[0]
		for a in pool:
			r -= float(weights.get(a.rarity, 1.0))
			if r <= 0.0:
				chosen = a
				break
		picked.append(chosen)
		pool.erase(chosen)
	return picked
