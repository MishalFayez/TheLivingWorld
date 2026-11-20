class_name AugmentData
extends Resource
## One augment card. Gameplay effects are implemented by the class kits, which query
## the owning hero's augments by id and read tuning values from `params`.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## vanguard / mage / reaver
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

@export_group("Tuning")
@export var params: Dictionary = {}


func p(key: String, default_value = 0.0):
	return params.get(key, default_value)
