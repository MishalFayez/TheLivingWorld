class_name ClassProgress
extends RefCounted
## Current-life progression of ONE class character. Classes never share this object, so resetting
## or a True Death of one class never touches the others. Serialized by the SaveSystem.

const PRIMARY := ["str", "dex", "vit", "for", "mas"]
const EQUIP_SLOTS := ["weapon", "head", "chest", "hands", "feet", "accessory"]

var class_id: String
var created: bool = false
var character_name: String = ""
var level: int = 1
var xp: int = 0                 ## EXP inside the current level
var total_exp: int = 0
var augments: Array[String] = []
## Major Mutations owned beyond the equip limit (kept, not deleted). Saved.
var inactive_mutations: Array[String] = []
var pending_drafts: int = 0
var pending_draft_tiers: Array = []   ## rarity bias for each pending draft ("any"/"advanced"/"exotic")
var drafts_taken: int = 0
var free_points: int = 0
var allocated: Dictionary = {}
var debug_bonus: Dictionary = {}
var life_number: int = 1
var seen_unlocks: Array = []          ## unlock ids already announced to the player
var debug_unlocks: Array = []         ## debug: force-unlocked ids
var debug_locks: Array = []           ## debug: force-locked ids
var equipment: Dictionary = {}        ## slot -> item id
var inventory: Array = []             ## item ids (unequipped)
var play_time: float = 0.0
# Mage-only state
var elements: Array[String] = ["fire", "life"]
var slots: Array[String] = ["fire", ""]
## Worldweaver loadout: charged spells on LMB / RMB / 1, utility spell on 3 (ChargedSpellData ids).
var spell_loadout: Array = ["flame_cataclysm", "life_bloom", "", ""]
## Worldweaver Life Bloom mode (only used once Focused / Shared Bloom is available).
var bloom_shared: bool = false
## Reaver skill slots (keys 1 / 2 / 3 / E); Final Stroke lives on F.
var reaver_loadout: Array = ["", "", "", ""]
var debug_elements: Array[String] = []
var shrine_elements: Array[String] = []
var discipline_casts: Dictionary = {}


func _init(c: String) -> void:
	class_id = c
	_clear()


func _clear() -> void:
	level = 1
	xp = 0
	total_exp = 0
	augments = []
	inactive_mutations = []
	pending_drafts = 0
	pending_draft_tiers = []
	drafts_taken = 0
	free_points = 0
	allocated = {"str": 0, "dex": 0, "vit": 0, "for": 0, "mas": 0}
	debug_bonus = {"str": 0, "dex": 0, "vit": 0, "for": 0, "mas": 0, "crit": 0.0, "critdmg": 0.0, "aspd": 0.0, "cdr": 0.0, "armor": 0.0, "mres": 0.0}
	seen_unlocks = []
	debug_unlocks = []
	debug_locks = []
	equipment = {}
	inventory = []
	elements = ["fire", "life"]
	slots = ["fire", ""]
	debug_elements = []
	shrine_elements = []
	discipline_casts = {}
	spell_loadout = ["flame_cataclysm", "life_bloom", "", ""]
	bloom_shared = false
	reaver_loadout = ["", "", "", ""]
	play_time = 0.0


## Fresh Level 1 character (beginner equipment is granted by Game.create_character).
func reset() -> void:
	var lives := life_number
	var c := created
	var n := character_name
	_clear()
	life_number = lives + 1
	created = c
	character_name = n


func exp_to_next(b: BalanceConfig) -> int:
	if level >= b.max_level:
		return 0
	return b.exp_curve[mini(level - 1, b.exp_curve.size() - 1)]


## Returns the list of levels gained.
func add_exp(amount: int, b: BalanceConfig) -> Array:
	var gained: Array = []
	if level >= b.max_level:
		return gained
	xp += amount
	total_exp += amount
	while level < b.max_level and xp >= exp_to_next(b):
		xp -= exp_to_next(b)
		level += 1
		free_points += b.free_points_per_level
		gained.append(level)
	if level >= b.max_level:
		xp = 0
	return gained


func set_level(lvl: int) -> void:
	var diff := lvl - level
	level = lvl
	xp = 0
	free_points = maxi(0, free_points + diff * Game.balance.free_points_per_level)


## Owned-but-unequipped Major Mutations do nothing until equipped (max 3 equipped, never deleted).
func augment_stacks(id: String) -> int:
	if inactive_mutations.has(id):
		return 0
	return augments.count(id)


func owned_mutations() -> Array:
	var out: Array = []
	for id in augments:
		var a: AugmentData = Game.augment_db.get_augment(id)
		if a and a.category == "mutation" and not out.has(id):
			out.append(id)
	return out


func active_mutations() -> Array:
	return owned_mutations().filter(func(id): return not inactive_mutations.has(id))


## Equip `id` (an owned, inactive mutation), unequipping `replace_id` if the limit is reached.
func equip_mutation(id: String, replace_id: String = "") -> bool:
	if not inactive_mutations.has(id):
		return false
	if active_mutations().size() >= Game.balance.max_equipped_mutations:
		if replace_id == "" or not active_mutations().has(replace_id):
			return false
		inactive_mutations.append(replace_id)
	inactive_mutations.erase(id)
	return true


# ------------------------------------------------------------------ unlocks
func track() -> ProgressionTrack:
	return Game.track(class_id)


func has_unlock(id: String) -> bool:
	if debug_locks.has(id):
		return false
	if debug_unlocks.has(id):
		return true
	var t := track()
	if t == null:
		return true
	var lv := t.unlock_level(id)
	return lv >= 0 and level >= lv


func unlocked_ids() -> Array:
	var out: Array = []
	var t := track()
	if t:
		for m in t.milestones:
			if m.kind != "stats" and m.kind != "augment" and has_unlock(m.id):
				out.append(m.id)
	return out


# ------------------------------------------------------------------ stats
func allocate(stat: String) -> bool:
	if free_points <= 0 or not allocated.has(stat):
		return false
	allocated[stat] += 1
	free_points -= 1
	return true


func reset_allocation() -> void:
	for k in allocated:
		free_points += int(allocated[k])
		allocated[k] = 0


# ------------------------------------------------------------------ equipment
func equipped_items() -> Array:
	var out: Array = []
	for s in equipment:
		var it = Game.item(equipment[s])
		if it:
			out.append(it)
	return out


func equipment_bonus(key: String) -> float:
	var v := 0.0
	for it in equipped_items():
		v += float(it.bonuses.get(key, 0.0))
	return v


func visual_tier(slot: String) -> int:
	var it = Game.item(equipment.get(slot, ""))
	return it.tier if it else 0


# ------------------------------------------------------------------ mage
func unlock_element(el: String) -> bool:
	if elements.has(el):
		return false
	elements.append(el)
	if el != "life":
		if slots[0] == "":
			slots[0] = el
		elif slots[1] == "":
			slots[1] = el
	return true


func lock_element(el: String) -> void:
	if el == "fire" or el == "life":
		return
	elements.erase(el)
	for i in slots.size():
		if slots[i] == el:
			slots[i] = ""


## Elements this Mage actually knows. Worldweaver (approved table): Fire + Life at Lv1, Frost at
## Lv3 (m_frost), Stone at Lv7 (m_stone), Storm at Lv9 (m_storm). Debug grants live in
## debug_elements / debug_unlocks and debug removals in debug_locks ("elem:<id>") - none of these
## are saved, so Debug testing never changes the stored character. Legacy cores use `elements`.
func known_elements() -> Array:
	if class_id != "mage" or Game.mage_core != "elementalist":
		return Array(elements)
	var out: Array = []
	var gate := {"frost": "m_frost", "stone": "m_stone", "storm": "m_storm"}
	for e in ["fire", "life", "frost", "stone", "storm"]:
		if debug_locks.has("elem:" + e):
			continue
		if e in ["fire", "life"] or has_unlock(String(gate[e])) or debug_elements.has(e):
			out.append(e)
	return out


func offensive_elements() -> Array:
	var out: Array = []
	for e in elements:
		if e != "life":
			out.append(e)
	return out


# ------------------------------------------------------------------ serialization
func to_dict() -> Dictionary:
	return {
		"class_id": class_id, "created": created, "name": character_name, "level": level, "xp": xp,
		"total_exp": total_exp, "augments": Array(augments), "inactive_mutations": Array(inactive_mutations), "pending_drafts": pending_drafts,
		"pending_draft_tiers": pending_draft_tiers, "drafts_taken": drafts_taken, "free_points": free_points,
		"allocated": allocated, "life_number": life_number, "seen_unlocks": seen_unlocks,
		"equipment": equipment, "inventory": inventory, "elements": Array(elements), "slots": Array(slots),
		"shrine_elements": Array(shrine_elements), "discipline_casts": discipline_casts, "play_time": play_time, "spell_loadout": spell_loadout.duplicate(), "bloom_shared": bloom_shared, "reaver_loadout": reaver_loadout.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	_clear()
	created = bool(d.get("created", false))
	character_name = String(d.get("name", ""))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	total_exp = int(d.get("total_exp", 0))
	augments.assign(d.get("augments", []))
	inactive_mutations.assign(d.get("inactive_mutations", []))
	pending_drafts = int(d.get("pending_drafts", 0))
	pending_draft_tiers = Array(d.get("pending_draft_tiers", []))
	drafts_taken = int(d.get("drafts_taken", 0))
	free_points = int(d.get("free_points", 0))
	var al: Dictionary = d.get("allocated", {})
	for k in allocated:
		allocated[k] = int(al.get(k, 0))
	life_number = int(d.get("life_number", 1))
	seen_unlocks = Array(d.get("seen_unlocks", []))
	equipment = Dictionary(d.get("equipment", {}))
	inventory = Array(d.get("inventory", []))
	elements.assign(d.get("elements", ["fire", "life"]))
	slots.assign(d.get("slots", ["fire", ""]))
	shrine_elements.assign(d.get("shrine_elements", []))
	discipline_casts = Dictionary(d.get("discipline_casts", {}))
	var sl: Array = d.get("spell_loadout", ["flame_cataclysm", "life_bloom", "", ""])
	spell_loadout = []
	for i in 4:
		spell_loadout.append(String(sl[i]) if i < sl.size() else "")
	bloom_shared = bool(d.get("bloom_shared", false))
	var rl: Array = d.get("reaver_loadout", ["", "", "", ""])
	reaver_loadout = []
	for i in 4:
		reaver_loadout.append(String(rl[i]) if i < rl.size() else "")
	play_time = float(d.get("play_time", 0.0))
