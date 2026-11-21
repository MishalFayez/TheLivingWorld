class_name AugmentData
extends Resource
## One augment card. Gameplay effects are implemented by the class kits / AugmentRuntime, which query
## the owning hero's augments by id and read tuning values from `params`.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## vanguard / mage / reaver, or "global" (any class; LEVEL10-FOUNDATION-005)
@export var class_id: String = ""
@export_enum("passive", "conditional", "enhancement", "synergy", "mutation") var category: String = "passive"
@export_enum("standard", "advanced", "exotic") var rarity: String = "standard"
@export var stackable: bool = false
@export var max_stacks: int = 1
## "add" = ordinary additive stacking. "mult" = explicitly defined multiplicative interaction.
@export_enum("add", "mult") var stack_mode: String = "add"

@export_group("Eligibility")
## Vanguard skills that must be equipped.
@export var requires_skills: PackedStringArray = PackedStringArray()
## Mage elements that must already be unlocked.
@export var requires_elements: PackedStringArray = PackedStringArray()
## Mage discoveries: the element must NOT be unlocked yet.
@export var requires_missing_elements: PackedStringArray = PackedStringArray()
## Reaver: requires the Bladecraft core to be enabled.
@export var requires_bladecraft: bool = false
## At least one of these augments must be owned (empty = no requirement).
@export var requires_any_augment: PackedStringArray = PackedStringArray()

@export_group("Presentation")
## Build directions (Tempest / Finality / Precision / Bulwark / ...). Informational, not locks.
@export var build_tags: PackedStringArray = PackedStringArray()
@export var interacts_with: String = ""

@export_group("Level 1-10 pool (LEVEL10-FOUNDATION-005)")
## "l10" = part of the curated 60-card Level 1-10 pool (the only cards drafted). "" = legacy card: kept
## working when owned, never drafted.
@export var pool: String = ""
## "" (class-common / global) or bulwark / counterguard / fusion / arcane / dance / edge
@export var path_id: String = ""
## Path-defining anchor: establishes the build direction (anchors of one class are mutually exclusive).
@export var is_anchor: bool = false
## Short stable code from the spec (G01, V-C03, R-E05 ...)
@export var code: String = ""
## Milestone ids that must be unlocked (e.g. "v_intercept", "m_frost") - mechanic accessible check.
@export var requires_unlocks: PackedStringArray = PackedStringArray()
## Classes a global card is NOT offered to, with the reason in params["class_block_reason"].
@export var blocked_classes: PackedStringArray = PackedStringArray()
## Non-empty: the card is in the catalog but never eligible (a design prerequisite is missing).
@export var blocked_reason: String = ""
@export var exclusive_group: String = ""
@export var synergy_tags: PackedStringArray = PackedStringArray()
@export var synergy_partners: PackedStringArray = PackedStringArray()
## partner id -> exact combined behaviour shown under "SYNERGY AVAILABLE"
@export var synergy_text: Dictionary = {}
@export var trigger_summary: String = ""
@export var cooldown: float = 0.0
@export var mechanical_tradeoff: String = ""
## Stats / sources that change this card's effect (shown only when real): str / dex / vit / for / mas / weapon_power / max_hp
@export var scaling_sources: PackedStringArray = PackedStringArray()
## Replaces a base action (Committed Cut, Shield Rush ...) - the draft warns before replacing another one.
@export var transforms: String = ""

@export_group("Tuning")
@export var params: Dictionary = {}


func p(key: String, default_value = 0.0):
	return params.get(key, default_value)


func group() -> String:
	return exclusive_group if exclusive_group != "" else String(params.get("exclusive_group", ""))
