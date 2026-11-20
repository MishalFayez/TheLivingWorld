class_name ProgressionTrack
extends Resource
## Level 1-10 milestones for one class (res://data/progression/<class>.tres).
## Each milestone: {level, id, kind, name, desc, input, icon}
##   kind: ability / skill / technique / mechanic / mastery / augment / stats
## Unlock ids are queried by the class kits (ClassProgress.has_unlock) — gating is real gameplay.

@export var class_id: String = ""
@export var milestones: Array[Dictionary] = []
## Levels that grant an augment draft, and the rarity bias of that draft.
@export var draft_levels: Dictionary = {4: "any", 8: "advanced", 10: "exotic"}
## Levels 11-30 FRAMEWORK (refoundation spec 9): milestone SLOTS only. The approved design names the
## slot types but no content, so every slot is empty until the design defines it. The level cap
## (BalanceConfig.max_level) stays 10 until content exists; raising it only exposes empty slots.
@export var future_slots: Dictionary = {15: "advanced_technique", 20: "build_synergy", 25: "major_mutation", 30: "capstone"}


## Content-free slot description for UI ("design pending").
func future_slot_text(level: int) -> String:
	var k: String = future_slots.get(level, "")
	if k == "":
		return ""
	return "%s (design pending)" % k.replace("_", " ").capitalize()


func unlocks_at(level: int) -> Array:
	var out: Array = []
	for m in milestones:
		if int(m.level) == level:
			out.append(m)
	return out


func unlock_level(id: String) -> int:
	for m in milestones:
		if m.id == id:
			return int(m.level)
	return -1


func milestone(id: String) -> Dictionary:
	for m in milestones:
		if m.id == id:
			return m
	return {}
