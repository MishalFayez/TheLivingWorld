extends Node
## Game state autoload: settings, per-class progression, hero/enemy spawning, EXP, drafts, death.

signal settings_changed

const CLASSES := ["vanguard", "mage", "reaver"]
const HERO_SCENES := {
	"vanguard": "res://scenes/heroes/vanguard.tscn",
	"mage": "res://scenes/heroes/mage.tscn",
	"reaver": "res://scenes/heroes/reaver.tscn",
}
const ENEMY_SCENES := {
	"wolf": "res://scenes/enemies/wolf.tscn",
	"raider": "res://scenes/enemies/raider.tscn",
	"shield_guardian": "res://scenes/enemies/shield_guardian.tscn",
	"ash_caster": "res://scenes/enemies/ash_caster.tscn",
	"ashen_warden": "res://scenes/enemies/ashen_warden.tscn",
	"training_dummy": "res://scenes/enemies/training_dummy.tscn",
}

var balance: BalanceConfig
var augment_db: AugmentDB
var progress: Dictionary = {}
var active_class: String = "vanguard"
var party_mode: bool = false

# --- Class cores (new + legacy kept for comparison) ---
## Mage core: "sigils" = Ley Sigils (Update 5) | "weave" = legacy Arcane Weave / Elemental Echo
var mage_core: String = "elementalist"   ## "elementalist" (default) | "sigils" / "weave" (rejected legacy, debug comparison only)
## Reaver core: "bladedancer" = Blade Dancer (REAVER-BLADEDANCER-003, default) | "freeflow" = Free Flow 002
## (Debug comparison) | "swordmaster" = Blade Lines (Debug comparison) | "sense" = Sword Sense (retired,
## Debug comparison) | "bladecraft" = legacy | "off" = no core
const DEFAULT_REAVER_CORE := "bladedancer"
var reaver_core: String = DEFAULT_REAVER_CORE
var bladecraft_enabled: bool:
	get:
		return reaver_core == "bladecraft"
	set(v):
		if v:
			reaver_core = "bladecraft"
		elif reaver_core == "bladecraft":
			reaver_core = "off"

# --- Test toggles (Debug Panel) ---
var permadeath: bool = true
## Any debug change to progression taints the session: it is never written to the save file.
var debug_tainted: bool = false
## REVIEW-004: a labelled non-saving test session (the only kind allowed while a newer-version save is
## protected on disk). Nothing is written while it is set; progress is discarded on return to the title.
var test_session: bool = false
## true for the fresh Level 1-10 playtest route (Character Selection "Fresh Lv1 Test"); cleared on title return
var fresh_test: bool = false
var invincible: bool = false
var show_hitboxes: bool = false
var auto_open_drafts: bool = true

var player: Hero
var heroes: Array = []
var world: Node3D
var ui_block: int = 0
## Worldweaver spell wheel open: mouse motion moves the wheel cursor instead of the camera (game keeps running)
var wheel_open: bool = false
var time: float = 0.0
var rng := RandomNumberGenerator.new()
var _respawn_queue: Array = []
var tracks: Dictionary = {}
var items: Dictionary = {}
var _companion_progs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The UI is designed left-to-right. On Windows set to Arabic (or another RTL language) Godot mirrors
	# Controls automatically and pushes the HUD off the right edge. LTR is forced by the project setting
	# internationalization/rendering/root_node_layout_direction and on every UI root (UIUtil.ltr).
	TranslationServer.set_locale("en")   # English digits/formatting regardless of the Windows language
	rng.randomize()
	balance = load("res://data/balance/balance.tres")
	if balance == null:
		push_warning("balance.tres missing, using defaults")
		balance = BalanceConfig.new()
	augment_db = AugmentDB.new()
	augment_db.load_dir("res://data/augments")
	_load_tracks_and_items()
	reset_all_progress()
	_setup_inputs()
	Events.enemy_killed.connect(_on_enemy_killed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	time += delta
	for i in range(_respawn_queue.size() - 1, -1, -1):
		var r: Dictionary = _respawn_queue[i]
		r.t -= delta
		if r.t <= 0.0:
			_respawn_queue.remove_at(i)
			if is_instance_valid(r.hero) and is_instance_valid(world):
				var pos: Vector3 = player.global_position + Vector3(1.5, 0, 1.5) if is_instance_valid(player) else world.checkpoint_position()
				r.hero.respawn(pos)


# ------------------------------------------------------------------ data
func _load_tracks_and_items() -> void:
	for c in CLASSES:
		var t = load("res://data/progression/%s.tres" % c)
		if t is ProgressionTrack:
			tracks[c] = t
	# REAVER-FREEFLOW-001: the Free Flow core has its own Level 1-10 track; the Swordmaster track stays
	# for the comparison / legacy cores.
	var ff = load("res://data/progression/reaver_freeflow.tres")
	if ff is ProgressionTrack:
		tracks["reaver_freeflow"] = ff
	var bdt = load("res://data/progression/reaver_bladedancer.tres")
	if bdt is ProgressionTrack:
		tracks["reaver_bladedancer"] = bdt
	var dir := DirAccess.open("res://data/items")
	if dir:
		for f in dir.get_files():
			var file := f.trim_suffix(".remap")
			if file.ends_with(".tres"):
				var it = load("res://data/items/" + file)
				if it is ItemData:
					items[it.id] = it


func track(c: String) -> ProgressionTrack:
	if c == "reaver" and reaver_core == "freeflow" and tracks.has("reaver_freeflow"):
		return tracks["reaver_freeflow"]
	if c == "reaver" and reaver_core == "bladedancer" and tracks.has("reaver_bladedancer"):
		return tracks["reaver_bladedancer"]
	return tracks.get(c)


func item(id) -> ItemData:
	if id == null or String(id) == "":
		return null
	return items.get(String(id))


# ------------------------------------------------------------------ progression
func reset_all_progress() -> void:
	for c in CLASSES:
		progress[c] = ClassProgress.new(c)
	_companion_progs.clear()


## AI companions in Party Test use a non-saved progression mirroring the player's level
## (auto-allocated stats, tiered beginner gear) so they never touch the player's saved characters.
func companion_prog(c: String) -> ClassProgress:
	var lvl := prog().level if progress.has(active_class) else 1
	var p: ClassProgress = _companion_progs.get(c)
	if p == null or p.level != lvl:
		p = ClassProgress.new(c)
		p.created = true
		p.set_level(lvl)
		var order := ["vit", "for", "str", "mas", "dex"] if c == "vanguard" else (["mas", "vit", "for"] if c == "mage" else ["str", "dex", "vit"])
		var i := 0
		while p.free_points > 0:
			p.allocate(order[i % order.size()])
			i += 1
		for it in starter_items(c):
			p.equipment[it.slot] = it.id
		_companion_progs[c] = p
	if progress.has(c):
		p.debug_unlocks = progress[c].debug_unlocks
		p.debug_locks = progress[c].debug_locks
	return p


## Debug: force every milestone ability of a class unlocked (or clear the overrides). Taints the session.
func debug_unlock_all(c: String, on: bool = true) -> void:
	var p := prog(c)
	p.debug_unlocks.clear()
	p.debug_locks.clear()
	if on:
		var t := track(c)
		if t:
			for m in t.milestones:
				if m.kind != "stats" and m.kind != "augment":
					p.debug_unlocks.append(m.id)
	taint("unlock all" if on else "clear unlock overrides")
	refresh_class_heroes(c)


## Debug: cycle one ability between natural -> forced unlocked -> forced locked.
func debug_toggle_unlock(c: String, id: String) -> String:
	var p := prog(c)
	var state := "natural"
	if p.debug_unlocks.has(id):
		p.debug_unlocks.erase(id)
		p.debug_locks.append(id)
		state = "locked"
	elif p.debug_locks.has(id):
		p.debug_locks.erase(id)
	else:
		p.debug_unlocks.append(id)
		state = "unlocked"
	taint("toggle " + id)
	refresh_class_heroes(c)
	return state


func starter_items(c: String) -> Array:
	var out: Array = []
	for it in items.values():
		if it.id.begins_with("starter_") and (it.class_id == c or it.class_id == ""):
			out.append(it)
	return out


## Switch a class core at runtime (legacy cores stay available for comparison).
func set_core(cls_id: String, core: String) -> void:
	if cls_id == "mage":
		mage_core = core
	else:
		reaver_core = core
		# REAVER-FREEFLOW-001 comparison mode: playing another Reaver core never writes to the save, so
		# augments / loadouts of the comparison core cannot end up in the Free Flow character.
		if core != DEFAULT_REAVER_CORE:
			taint("Reaver comparison core: " + core)
	for h in heroes:
		if is_instance_valid(h) and h.class_id == cls_id:
			h.kit.restore()
	Events.log_message.emit("%s core: %s" % [cls_id.capitalize(), core], "system")
	Events.player_changed.emit(player)


## Sword Sense: openings are tracked when any Reaver in play uses the "sense" core.
func reaver_opening_tracking() -> bool:
	return reaver_core == "sense"


## Opening duration multiplier from the PLAYER Reaver's progression / augments.
func opening_mult() -> float:
	var m := 1.0
	var h = player
	if h == null or not is_instance_valid(h) or h.class_id != "reaver":
		for x in get_tree().get_nodes_in_group("heroes"):
			if x.class_id == "reaver":
				h = x
				break
	if h == null or not is_instance_valid(h) or h.class_id != "reaver":
		return m
	if h.unlocked("r_edge_master"):
		m *= 1.4
	if h.kit.aug("predators_patience") > 0:
		m *= float(h.kit.ap("predators_patience", "duration_mult", 1.5))
	return m


## New Level 1 character for one class (other classes untouched).
func create_character(c: String, char_name: String) -> void:
	var p := ClassProgress.new(c)
	var old: ClassProgress = progress.get(c)
	if old and old.created:
		p.life_number = old.life_number + 1
	p.created = true
	p.character_name = char_name if char_name.strip_edges() != "" else c.capitalize()
	for it in starter_items(c):
		p.equipment[it.slot] = it.id
	progress[c] = p
	active_class = c
	debug_tainted = false
	Save.save_game()


func reset_character(c: String) -> void:
	var p: ClassProgress = progress[c]
	var nm := p.character_name
	create_character(c, nm)


## LEVEL10-FOUNDATION-005 review: a fresh Level 1 character for one class as a labelled NON-SAVING test
## session. The saved character stays untouched on disk; returning to the title reloads the save.
func start_fresh_test(c: String) -> void:
	test_session = true
	fresh_test = true
	create_character(c, "Test " + c.capitalize())    # in memory only: Save.save_game refuses test sessions


## One level through the real EXP path (drafts at the track's levels), test sessions only.
func test_gain_level() -> void:
	if not (test_session and fresh_test):
		return
	var p := prog()
	if p.level >= balance.max_level:
		return
	gain_exp(p.exp_to_next(balance) - p.xp, "test session")


func taint(reason: String) -> void:
	if not debug_tainted:
		debug_tainted = true
		Events.log_message.emit("Debug change (%s): this session will not be saved" % reason, "system")
		Events.notify.emit("DEBUG SESSION - progress not saved")


## REVIEW-004: true when a save written by a newer version is protected on disk; no session may save then.
func saving_locked() -> bool:
	return Save.primary_is_newer()


func autosave() -> void:
	if Save.save_game():
		Events.saved.emit()
	elif Save.enabled and not debug_tainted and not test_session:
		# a real failure (not "saving disabled" / "debug session"): never report it as saved
		push_warning("autosave failed: " + Save.last_error)


func prog(class_id: String = "") -> ClassProgress:
	return progress[class_id if class_id != "" else active_class]


func gain_exp(amount: float, reason: String) -> void:
	var p := prog()
	var amt := int(round(amount))
	if amt <= 0 or p.level >= balance.max_level:
		return
	var gained: Array = p.add_exp(amt, balance)
	Events.exp_gained.emit(active_class, amt, reason)
	var t := track(active_class)
	for lvl in gained:
		Events.level_up.emit(active_class, lvl)
		Events.notify.emit("LEVEL %d" % lvl)
		if t and t.draft_levels.has(lvl):
			p.pending_drafts += 1
			p.pending_draft_tiers.append(t.draft_levels[lvl])
			Events.draft_ready.emit(active_class)
		if t:
			var new_unlocks: Array = []
			for m in t.unlocks_at(lvl):
				if m.kind != "augment" and not p.seen_unlocks.has(m.id):
					p.seen_unlocks.append(m.id)
					new_unlocks.append(m)
			if not new_unlocks.is_empty():
				Events.unlocks_gained.emit(active_class, new_unlocks)
	if not gained.is_empty():
		refresh_class_heroes(active_class)
		autosave()


func set_level(class_id: String, lvl: int) -> void:
	var p := prog(class_id)
	p.set_level(clampi(lvl, 1, balance.max_level))
	var t := track(class_id)
	var owed: Array = []
	if t:
		var lv_keys: Array = t.draft_levels.keys()
		lv_keys.sort()
		for d in lv_keys:
			if int(d) <= p.level:
				owed.append(t.draft_levels[d])
		for m in t.milestones:
			if int(m.level) <= p.level and not p.seen_unlocks.has(m.id):
				p.seen_unlocks.append(m.id)
	p.pending_draft_tiers = owed.slice(mini(p.drafts_taken, owed.size()))
	p.pending_drafts = p.pending_draft_tiers.size()
	refresh_class_heroes(class_id)
	if p.pending_drafts > 0:
		Events.draft_ready.emit(class_id)


func draft_tier(class_id: String) -> String:
	var p := prog(class_id)
	return String(p.pending_draft_tiers[0]) if not p.pending_draft_tiers.is_empty() else "any"


func roll_draft(class_id: String) -> Array:
	if AugmentDB.uses_l10_pool(class_id):
		return augment_db.roll_l10(class_id, prog(class_id), draft_level(class_id), rng, balance.draft_choices)
	return augment_db.roll(class_id, prog(class_id), balance.draft_choices, rng, draft_tier(class_id))


## Milestone level of the next pending draft (4 / 8 / 10 on the current tracks), from the class track.
func draft_level(class_id: String) -> int:
	var p := prog(class_id)
	var t := track(class_id)
	if t == null:
		return 4
	var lv_keys: Array = t.draft_levels.keys()
	lv_keys.sort()
	var i := clampi(p.drafts_taken, 0, maxi(0, lv_keys.size() - 1))
	return int(lv_keys[i]) if not lv_keys.is_empty() else 4


func _consume_draft(p: ClassProgress) -> void:
	p.pending_drafts = maxi(0, p.pending_drafts - 1)
	if not p.pending_draft_tiers.is_empty():
		p.pending_draft_tiers.pop_front()
	p.drafts_taken += 1


func choose_augment(class_id: String, aug_id: String) -> void:
	_consume_draft(prog(class_id))
	add_augment(class_id, aug_id)
	autosave()


func skip_draft(class_id: String) -> void:
	_consume_draft(prog(class_id))


## LEVEL10-FOUNDATION-005 7.4: safe replacement at a draft (the documented build-management opportunity).
## The new card is added and `replace_id` becomes OWNED BUT INACTIVE (kept in the save, never deleted).
## Uses the draft (no free extra slot, no duplicate draft, no rarity upgrade).
func choose_augment_replacing(class_id: String, aug_id: String, replace_id: String) -> bool:
	var p := prog(class_id)
	if replace_id == "" or p.augment_stacks(replace_id) <= 0 or replace_id == aug_id:
		choose_augment(class_id, aug_id)
		return false
	_consume_draft(p)
	if not p.inactive_mutations.has(replace_id):
		p.inactive_mutations.append(replace_id)
	var ra: AugmentData = augment_db.get_augment(replace_id)
	Events.log_message.emit("Augment benched: %s (kept owned, inactive)" % (ra.display_name if ra else replace_id), "augment")
	add_augment(class_id, aug_id)
	autosave()
	return true


## Cards that depend on `id` through a listed synergy (warning before benching a path anchor / partner).
func dependents_of(class_id: String, id: String) -> Array:
	var out: Array = []
	var p := prog(class_id)
	for oid in p.augments:
		if oid == id or p.augment_stacks(oid) <= 0:
			continue
		var o: AugmentData = augment_db.get_augment(oid)
		if o != null and augment_db.pair_kind(o, augment_db.get_augment(id)) == "mechanical":
			out.append(o.display_name)
	return out


func add_augment(class_id: String, aug_id: String) -> void:
	var a: AugmentData = augment_db.get_augment(aug_id)
	if a == null:
		return
	var p := prog(class_id)
	var stacks := p.augment_stacks(aug_id)
	if (stacks > 0 and not a.stackable) or (a.stackable and stacks >= a.max_stacks):
		Events.log_message.emit("%s already owned / at max stacks" % a.display_name, "system")
		return
	if a.group() != "":
		var other := augment_db.owned_in_group(p, a.group(), aug_id)
		if other != "":
			Events.log_message.emit("%s not added: mutually exclusive with %s" % [a.display_name, other], "system")
			return
	p.augments.append(aug_id)
	if a.category == "mutation" and p.active_mutations().size() > balance.max_equipped_mutations:
		p.inactive_mutations.append(aug_id)
		Events.notify.emit("%s kept INACTIVE: %d Major Mutations already equipped. Swap it in from Augments." % [a.display_name, balance.max_equipped_mutations])
	if a.params.has("unlock_element"):
		unlock_element(String(a.params["unlock_element"]), a.display_name)
	Events.augment_added.emit(class_id, aug_id)
	Events.log_message.emit("Augment acquired: %s (%s)" % [a.display_name, class_id], "augment")
	refresh_class_heroes(class_id)


func remove_augment(class_id: String, aug_id: String) -> void:
	var p := prog(class_id)
	var idx := p.augments.find(aug_id)
	if idx < 0:
		return
	p.augments.remove_at(idx)
	if not p.augments.has(aug_id):
		p.inactive_mutations.erase(aug_id)
	var a: AugmentData = augment_db.get_augment(aug_id)
	if a and a.params.has("unlock_element") and p.augment_stacks(aug_id) == 0:
		var el := String(a.params["unlock_element"])
		if not p.debug_elements.has(el) and not p.shrine_elements.has(el):
			p.lock_element(el)
	Events.augment_removed.emit(class_id, aug_id)
	refresh_class_heroes(class_id)


func unlock_element(el: String, source: String) -> void:
	var p := prog("mage")
	if p.unlock_element(el):
		Events.element_unlocked.emit(el)
		Events.log_message.emit("Mage discovered the %s element (%s)" % [el.capitalize(), source], "fusion")
		Events.notify.emit("%s ELEMENT DISCOVERED" % el.to_upper())
	refresh_class_heroes("mage")


func refresh_class_heroes(class_id: String) -> void:
	for h in heroes:
		if is_instance_valid(h) and h.class_id == class_id:
			h.refresh_stats(false)


# ------------------------------------------------------------------ equipment
func equip(class_id: String, item_id: String) -> bool:
	var p := prog(class_id)
	var it := item(item_id)
	if it == null or not p.inventory.has(item_id):
		return false
	if it.class_id != "" and it.class_id != class_id:
		return false
	p.inventory.erase(item_id)
	var old = p.equipment.get(it.slot, "")
	if old != "":
		p.inventory.append(old)
	p.equipment[it.slot] = item_id
	_after_equip(class_id)
	return true


func unequip(class_id: String, slot: String) -> bool:
	var p := prog(class_id)
	var cur = p.equipment.get(slot, "")
	if cur == "":
		return false
	p.equipment.erase(slot)
	p.inventory.append(cur)
	_after_equip(class_id)
	return true


func _after_equip(class_id: String) -> void:
	for h in heroes:
		if is_instance_valid(h) and h.class_id == class_id and h.is_player:
			h.refresh_stats(false)
			h.rebuild_model()
	Events.equipment_changed.emit(class_id)
	autosave()


func give_item(class_id: String, item_id: String) -> void:
	if item(item_id) == null:
		return
	prog(class_id).inventory.append(item_id)
	Events.item_found.emit(class_id, item_id)


func _roll_loot(e) -> void:
	var chance := 0.07
	if e.is_elite:
		chance = 1.0
	if e.is_boss:
		chance = 1.0
	var area_idx := ["outskirts", "ruins", "keep"].find(e.area_key)
	var rolls := 2 if e.is_boss else 1
	for r in rolls:
		if rng.randf() > chance:
			continue
		var pool: Array = []
		var total := 0.0
		for it in items.values():
			if it.id.begins_with("starter_") or it.min_area > maxi(area_idx, 0):
				continue
			if it.class_id != "" and it.class_id != active_class:
				continue
			pool.append(it)
			total += it.drop_weight
		if pool.is_empty():
			return
		var roll := rng.randf() * total
		for it in pool:
			roll -= it.drop_weight
			if roll <= 0.0:
				give_item(active_class, it.id)
				Events.notify.emit("ITEM FOUND: %s" % it.display_name.to_upper())
				break


# ------------------------------------------------------------------ session / spawning
func start_session(world_node: Node3D, class_id: String, party: bool) -> void:
	world = world_node
	active_class = class_id
	party_mode = party
	spawn_player(world.checkpoint_position())
	if party_mode:
		spawn_companions()


func spawn_hero(class_id: String, pos: Vector3, as_player: bool) -> Hero:
	var h: Hero = load(HERO_SCENES[class_id]).instantiate()
	h.is_player = as_player
	world.add_child(h)
	h.global_position = pos
	h.reset_physics_interpolation()
	if as_player:
		var brain := PlayerBrain.new()
		brain.name = "Brain"
		h.add_child(brain)
	else:
		var ai := AIBrain.new()
		ai.name = "Brain"
		h.add_child(ai)
	return h


func spawn_player(pos: Vector3) -> void:
	player = spawn_hero(active_class, pos, true)
	Events.player_changed.emit(player)


func spawn_companions() -> void:
	if not is_instance_valid(player):
		return
	var i := 0
	for c in CLASSES:
		if c == active_class:
			continue
		i += 1
		spawn_hero(c, player.global_position + Vector3(2.0 * i - 3.0, 0, 2.0), false)


func end_session() -> void:
	heroes.clear()
	player = null
	world = null
	ui_block = 0
	wheel_open = false
	_respawn_queue.clear()
	get_tree().paused = false


func despawn_companions() -> void:
	for h in heroes.duplicate():
		if is_instance_valid(h) and not h.is_player:
			h.queue_free()
	_respawn_queue.clear()


func set_party_mode(on: bool) -> void:
	if on == party_mode:
		return
	party_mode = on
	if on:
		spawn_companions()
	else:
		despawn_companions()
	settings_changed.emit()


func switch_class(class_id: String) -> void:
	if not CLASSES.has(class_id):
		push_warning("switch_class: unknown class id '%s' ignored" % class_id)
		return
	if world == null:
		active_class = class_id
		return
	var pos: Vector3 = player.global_position if is_instance_valid(player) else world.checkpoint_position()
	var had_party := party_mode
	despawn_companions()
	if is_instance_valid(player):
		player.queue_free()
	active_class = class_id
	spawn_player(pos)
	if had_party:
		spawn_companions()
	Events.log_message.emit("Switched class to %s" % class_id.capitalize(), "system")


func spawn_enemy(type: String, pos: Vector3, area_key: String = "outskirts", elite: bool = false) -> Enemy:
	if not ENEMY_SCENES.has(type) or world == null:
		return null
	var e: Enemy = load(ENEMY_SCENES[type]).instantiate()
	e.configure(area_key, elite)
	world.add_child(e)
	e.global_position = pos
	e.home_position = pos
	e.reset_physics_interpolation()
	if type == "ashen_warden":
		Events.boss_spawned.emit(e)
	return e


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func living_heroes() -> Array:
	var out: Array = []
	for h in heroes:
		if is_instance_valid(h) and not h.dead and not h.downed and h.visible:
			out.append(h)
	return out


func fx_root() -> Node:
	if is_instance_valid(world):
		return world
	return get_tree().current_scene


func current_area_key() -> String:
	if is_instance_valid(world) and is_instance_valid(player) and world.has_method("area_at"):
		var a: String = world.area_at(player.global_position)
		return "outskirts" if a == "training" else a
	return "outskirts"


func set_flag(flag: String, value) -> void:
	set(flag, value)
	if flag == "bladecraft_enabled" or flag == "reaver_core":
		Events.log_message.emit("Reaver core: %s" % reaver_core, "system")
	if flag == "mage_core":
		Events.log_message.emit("Mage core: %s" % mage_core, "system")
	settings_changed.emit()


# ------------------------------------------------------------------ death
func on_hero_true_death(h: Hero) -> void:
	Events.hero_true_death.emit(h)
	if h == player:
		if world and world.has_method("on_player_true_death"):
			world.on_player_true_death()
		if permadeath:
			prog().reset()
			for it in starter_items(active_class):
				prog().equipment[it.slot] = it.id
			autosave()
			Events.notify.emit("TRUE DEATH - %s life progression reset" % active_class.capitalize())
			Events.log_message.emit("%s progression reset to level 1 (other classes untouched)" % active_class.capitalize(), "death")
		else:
			Events.notify.emit("TRUE DEATH (permadeath disabled - progression kept)")
		h.respawn(world.checkpoint_position() if world else h.global_position)
		for c in heroes:
			if is_instance_valid(c) and c != h and (c.downed or not c.visible):
				c.respawn(h.global_position + Vector3(1.5, 0, 1.0))
	else:
		h.hide_dead()
		_respawn_queue.append({"hero": h, "t": balance.companion_respawn_time})


func _on_enemy_killed(e, _killer) -> void:
	if not is_instance_valid(e):
		return
	var base: float = float(balance.enemy_exp.get(e.enemy_type, 20))
	if e.is_elite:
		base *= balance.elite_exp_mult
	base *= float(balance.area_exp_mult.get(e.area_key, 1.0))
	if e.exp_override >= 0:
		base = e.exp_override
	gain_exp(base, e.display_name)
	_roll_loot(e)


# ------------------------------------------------------------------ input map
func _setup_inputs() -> void:
	_key("move_forward", [KEY_W])
	_key("move_back", [KEY_S])
	_key("move_left", [KEY_A])
	_key("move_right", [KEY_D])
	_mouse("light", MOUSE_BUTTON_LEFT)
	_mouse("heavy", MOUSE_BUTTON_RIGHT)
	_key("dodge", [KEY_SPACE])
	_key("guard", [KEY_SHIFT])
	# Reaver directional-attack modifier (design resolution 1). Same physical key as Vanguard Guard:
	# the Reaver has no Guard action, so nothing conflicts; a separate action keeps it rebindable
	# and controller-ready (add a joypad event to "blade_modifier" to support pads).
	_key("blade_modifier", [KEY_SHIFT])
	_key("life", [KEY_F])
	_key("core", [KEY_E])
	# Blade Dancer Reaver footwork technique (REAVER-BLADEDANCER-003). Q was unbound; no other class uses
	# this action, so no existing mapping changes.
	_key("footwork", [KEY_Q])
	# (006: the Q / V spell-wheel actions of package 005 are removed - the casting wheels open on LMB / RMB)

	_key("skill1", [KEY_1])
	_key("skill2", [KEY_2])
	_key("skill3", [KEY_3])
	_key("heal_target", [KEY_T])
	_key("lock_on", [KEY_TAB])
	_mouse("lock_on", MOUSE_BUTTON_MIDDLE)
	# target switching while locked (rebindable in Project Settings > Input Map)
	_mouse("lock_switch_right", MOUSE_BUTTON_WHEEL_UP)
	_key("lock_switch_right", [KEY_X])
	_mouse("lock_switch_left", MOUSE_BUTTON_WHEEL_DOWN)
	_key("lock_switch_left", [KEY_Z])
	_key("revive", [KEY_R])
	_key("interact", [KEY_G])
	_key("toggle_debug", [KEY_F1])
	_key("toggle_log", [KEY_F2])
	_key("char_sheet", [KEY_C])
	_key("menu_skills", [KEY_K])
	_key("menu_spellbook", [KEY_B])
	_key("menu_inventory", [KEY_I])
	_key("menu_map", [KEY_M])
	_key("menu_journal", [KEY_J])
	_key("release_mouse", [KEY_ESCAPE])
	_key("toggle_fullscreen", [KEY_F11])


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
