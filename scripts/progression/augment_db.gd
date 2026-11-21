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
		if a.class_id == class_id or a.class_id == "global":
			out.append(a)
	out.sort_custom(func(x, y): return x.display_name < y.display_name)
	return out


## LEVEL10-FOUNDATION-005: the curated Level 1-10 pool applies to the approved cores (Vanguard, Worldweaver,
## Blade Dancer Reaver). Comparison / legacy cores keep their old draft behaviour.
static func uses_l10_pool(class_id: String) -> bool:
	match class_id:
		"vanguard":
			return true
		"mage":
			return Game.mage_core == "elementalist"
		"reaver":
			return Game.reaver_core == "bladedancer"
	return false


## Path of a progression's build (owned anchor first, otherwise the path with most owned path cards).
func chosen_path(p: ClassProgress) -> String:
	var cnt := {}
	for id in p.augments:
		var a: AugmentData = all.get(id)
		if a == null or a.path_id == "" or p.augment_stacks(id) <= 0:
			continue
		if a.is_anchor:
			return a.path_id
		cnt[a.path_id] = int(cnt.get(a.path_id, 0)) + 1
	var best := ""
	var bn := 0
	for k in cnt:
		if cnt[k] > bn:
			bn = cnt[k]
			best = k
	return best


const PATHS := {"vanguard": ["bulwark", "counterguard"], "mage": ["fusion", "arcane"], "reaver": ["dance", "edge"]}
const PATH_NAMES := {"bulwark": "Bulwark", "counterguard": "Counterguard", "fusion": "Elemental Fusion", "arcane": "Arcane Weaving", "dance": "Dance Mastery", "edge": "Edge Mastery"}


## Returns "" when eligible, otherwise the reason it is hidden from drafts.
func ineligible_reason(a: AugmentData, p: ClassProgress) -> String:
	if a.class_id != p.class_id and a.class_id != "global":
		return "wrong class"
	if a.blocked_reason != "":
		return "blocked: " + a.blocked_reason
	if a.class_id == "global" and a.blocked_classes.has(p.class_id):
		return "not for this class: " + String(a.params.get("class_block_reason", ""))
	if uses_l10_pool(p.class_id) and a.pool != "l10":
		return "outside the Level 1-10 pool (kept working when owned)"
	if a.pool == "l10" and not uses_l10_pool(p.class_id):
		return "Level 1-10 pool card (approved cores only)"
	for u in a.requires_unlocks:
		if not p.has_unlock(u):
			var lv := p.track().unlock_level(u) if p.track() else -1
			return "requires %s%s" % [u, " (Lv %d)" % lv if lv > 0 else ""]
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
		if core in ["sense", "bladecraft", "swordmaster", "freeflow", "bladedancer"] and Game.reaver_core != core:
			# REAVER-FREEFLOW-001: a Swordmaster augment that does not depend on Blade Lines / directional
			# links is explicitly flagged compatible; every other one is incompatible with Free Flow
			# pending an approved migration design.
			# REAVER-BLADEDANCER-003: Blade Dancer accepts only its own augments (nothing is ported).
			if not (core == "swordmaster" and Game.reaver_core == "freeflow" and freeflow_compatible(a)):
				if Game.reaver_core == "bladedancer":
					return "incompatible with Blade Dancer (pending migration design)"
				return ("incompatible with Free Flow (pending migration design)" if Game.reaver_core == "freeflow" else "requires Reaver core " + core)
	if a.params.get("legacy_reaver", false) and Game.reaver_core in ["swordmaster", "freeflow", "bladedancer"]:
		return "legacy Reaver core only"
	# REAVER-FREEFLOW-001: the Decisive Cut transformations are mutually exclusive (one per run).
	if a.group() != "":
		var other := owned_in_group(p, a.group(), a.id)
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
		if o != null and o.group() == group and p.augment_stacks(id) > 0:
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


## REAVER-BLADEDANCER-003: true when an owned Reaver augment has no effect under Blade Dancer (it belongs
## to another core). Such augments stay in the save untouched; no conversion without approval.
func bladedancer_inactive(a: AugmentData) -> bool:
	if a == null or a.class_id != "reaver" or Game.reaver_core != "bladedancer":
		return false
	if a.params.get("legacy_reaver", false) or a.requires_bladecraft:
		return true
	return String(a.params.get("requires_core", "")) != "bladedancer"


## Draft for the Level 1-10 pool (spec 7.3). `level` = the milestone level of this draft (4 / 8 / 10).
##   4: one anchor of each path + one class-common card
##   8: favour the chosen path + synergy partners + compatible common; no path yet -> both anchors again
##  10: build completion: synergy partners first, then chosen path, then common; always 3 when possible
## Weighted by rarity with the seeded RNG (reproducible); no duplicates, no ineligible cards.
func roll_l10(class_id: String, p: ClassProgress, level: int, rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool := eligible(class_id, p)
	var picked: Array = []
	var paths: Array = PATHS.get(class_id, [])
	var path := chosen_path(p)
	var owned_ids: Array = []
	for id in p.augments:
		if p.augment_stacks(id) > 0:
			owned_ids.append(id)
	var anchors := func(pth): return pool.filter(func(a): return a.is_anchor and a.path_id == pth)
	var of_path := func(pth): return pool.filter(func(a): return a.path_id == pth and not a.is_anchor)
	var common := pool.filter(func(a): return a.path_id == "")
	var class_common := common.filter(func(a): return a.class_id == class_id)
	var synergy := pool.filter(func(a): return _synergy_with(a, owned_ids) != "")
	var take_from := func(arr: Array) -> bool:
		var cands := arr.filter(func(a): return not picked.has(a))
		if cands.is_empty():
			return false
		picked.append(_weighted(cands, rng))
		return true
	if level <= 4 or (level <= 8 and path == ""):
		for pth in paths:
			if not take_from.call(anchors.call(pth)):
				take_from.call(of_path.call(pth))
		if not take_from.call(class_common):
			take_from.call(common)
	elif level <= 8:
		if not take_from.call(synergy.filter(func(a): return a.path_id == path or a.path_id == "")):
			take_from.call(of_path.call(path))
		take_from.call(of_path.call(path))
		if not take_from.call(class_common):
			take_from.call(common)
	else:
		take_from.call(synergy)
		take_from.call(of_path.call(path) if path != "" else common)
		take_from.call(pool.filter(func(a): return a.path_id == path or a.path_id == ""))
	# fill: never fewer than `count` legitimate options when the eligible pool allows
	while picked.size() < count and take_from.call(pool.filter(func(a): return a.path_id == path or a.path_id == "" or path == "")):
		pass
	while picked.size() < count and take_from.call(pool):
		pass
	return picked.slice(0, count)


func _weighted(cands: Array, rng: RandomNumberGenerator) -> AugmentData:
	var weights: Dictionary = Game.balance.rarity_weights
	var total := 0.0
	for a in cands:
		total += float(weights.get(a.rarity, 1.0))
	var r := rng.randf() * total
	for a in cands:
		r -= float(weights.get(a.rarity, 1.0))
		if r <= 0.0:
			return a
	return cands[0]


## Id of an owned augment `a` synergises with (either direction), or "".
func _synergy_with(a: AugmentData, owned_ids: Array) -> String:
	for id in owned_ids:
		if a.synergy_partners.has(id):
			return id
		var o: AugmentData = all.get(id)
		if o != null and o.synergy_partners.has(a.id):
			return id
	return ""


## Text of the combined behaviour of `a` with an owned card, or "".
func synergy_text(a: AugmentData, p: ClassProgress) -> String:
	var owned_ids: Array = []
	for id in p.augments:
		if p.augment_stacks(id) > 0:
			owned_ids.append(id)
	var with := _synergy_with(a, owned_ids)
	if with == "":
		return ""
	var o: AugmentData = all.get(with)
	var txt := String(a.synergy_text.get(with, ""))
	if txt == "" and o != null:
		txt = String(o.synergy_text.get(a.id, ""))
	return "%s + %s: %s" % [a.display_name, o.display_name if o else with, txt]


## Owned card that `a` would replace (same transformation target or exclusive group), or "".
func replaces(a: AugmentData, p: ClassProgress) -> String:
	for id in p.augments:
		if id == a.id or p.augment_stacks(id) <= 0:
			continue
		var o: AugmentData = all.get(id)
		if o == null:
			continue
		if (a.transforms != "" and o.transforms == a.transforms) or (a.group() != "" and o.group() == a.group()):
			return id
	return ""


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
