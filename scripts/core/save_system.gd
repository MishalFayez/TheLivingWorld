extends Node
## Local save/load (JSON in user://). One save holds every class character independently plus
## settings. Debug sessions never write the save ("debug-tainted"), so testing cannot corrupt a
## normal character. Autoload name: Save.
##
## Data safety rules (QA-001, REVIEW-001..003):
## - a save is replaced atomically (.tmp -> verify -> .bak -> install), never truncated in place;
## - nothing is ever deleted that this build did not write: unreadable files go to .corrupt-*,
##   leftover .tmp / unusable .bak files go to .orphan-*;
## - a save written by a NEWER build (version > VERSION) is never loaded, recovered over, moved or
##   overwritten; while it is the primary save, nothing is written at all (`newer_version` > 0).

const VERSION := 1

const DEFAULT_SETTINGS := {
	"mouse_sensitivity": 1.0, "invert_y": false, "camera_shake": true, "damage_numbers": true,
	"fullscreen": false, "vsync": true, "show_fps": false, "party_default": false,
}

var path: String = "user://living_world_save.json"
var enabled: bool = true
var last_error: String = ""
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## Source file of the last crash recovery (see recover_if_needed).
var recovered_from: String = ""
## Player-readable reason the save on disk could not be loaded ("" when it loaded or there is none).
## Shown on the title screen.
var load_problem: String = ""
## Version of the primary save when it was written by a newer build (0 = not the case).
var newer_version: float = 0.0
var _read_was_newer: bool = false   ## set by _read_file: the last file read was from a newer build
var _read_newer_version: float = 0.0


func _ready() -> void:
	load_settings_only()


## Restores default settings in memory (used to isolate test fixtures from the user's settings).
func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()


func has_save() -> bool:
	recover_if_needed()
	return FileAccess.file_exists(path)


## Crash recovery. While a save is being replaced the previous file lives as <save>.bak and the new one as
## <save>.tmp. If the primary save is missing or unreadable, the newest VALID candidate (.bak or a fully
## written .tmp, compared by saved_at) is copied into place. Nothing is deleted: an unreadable primary is
## moved aside to .corrupt-<time> and the backup itself is kept (copied, not moved). A primary written by
## a newer build is never displaced. Returns true when a recovery happened.
func recover_if_needed() -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	newer_version = 0.0
	if FileAccess.file_exists(abs_path):
		if _read_file(abs_path) is Dictionary:
			return false
		if _read_was_newer:
			newer_version = _read_newer_version
			return false
	var best := ""
	var best_time := ""
	for cand in [abs_path + ".bak", abs_path + ".tmp"]:
		if not FileAccess.file_exists(cand):
			continue
		var d = _read_file(cand)
		if d is Dictionary:
			var t := str(d.get("saved_at", ""))
			if best == "" or t > best_time:
				best = cand
				best_time = t
	if best == "":
		return false
	if FileAccess.file_exists(abs_path):
		var aside := _aside_name(abs_path, ".corrupt-")
		if DirAccess.rename_absolute(abs_path, aside) != OK:
			last_error = "cannot move unreadable save aside - backup not restored"
			push_warning(last_error)
			return false
	if DirAccess.copy_absolute(best, abs_path) != OK or not (_read_file(abs_path) is Dictionary):
		last_error = "backup recovery failed"
		push_warning(last_error)
		return false
	recovered_from = best.get_file()
	last_error = "recovered save from " + recovered_from
	push_warning(last_error)
	return true


func _read() -> Dictionary:
	if not has_save():
		return {}
	var data = _read_file(path)
	return data if data is Dictionary else {}


## Parses a save file. Returns null (and sets last_error) when it cannot be opened, is not a JSON object,
## was written by a newer build, or fails validate_save() (structurally malformed data is treated exactly
## like an unreadable file).
func _read_file(p: String) -> Variant:
	_read_was_newer = false
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		last_error = "cannot open save"
		return null
	var txt := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(txt) != OK or typeof(json.data) != TYPE_DICTIONARY:
		last_error = "corrupt save"
		return null
	if is_newer_version(json.data):
		_read_was_newer = true
		_read_newer_version = float(json.data.version)
		last_error = "save written by a newer version (%s, this build supports %d)" % [_fmt_version(json.data.version), VERSION]
		return null
	var problem := validate_save(json.data)
	if problem != "":
		last_error = "malformed save: " + problem
		return null
	return json.data


## Re-reads the primary save (no recovery, no writes) and refreshes `newer_version`.
func primary_is_newer() -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	newer_version = 0.0
	if FileAccess.file_exists(abs_path) and not (_read_file(abs_path) is Dictionary) and _read_was_newer:
		newer_version = _read_newer_version
	return newer_version > 0.0


static func is_newer_version(d: Dictionary) -> bool:
	return d.has("version") and _is_number(d.version) and float(d.version) > VERSION


static func _fmt_version(v: Variant) -> String:
	return ("%d" % int(v)) if _is_number(v) and float(v) == floorf(float(v)) else str(v)


## Structural validation of a parsed save. Returns "" when ClassProgress.from_dict() and the code that
## reads its result can consume the data, else the first problem found. Only fields that are PRESENT are
## checked: a missing field is legal (older saves lack later fields; from_dict fills defaults), so no
## older save is rejected for that. Mirrors from_dict exactly: GDScript's String() cannot convert numbers,
## int() cannot convert lists, Array[String].assign() rejects non-text entries.
## Entries for unknown classes and unknown fields are ignored (never loaded). Cosmetic top-level fields
## (last_class, saved_at, settings) are never a reason to reject: wrong types are ignored when loading.
const _CHAR_BOOL := ["created", "bloom_shared"]
const _CHAR_STRING := ["class_id", "name"]
const _CHAR_NUMBER := ["level", "xp", "total_exp", "pending_drafts", "drafts_taken", "free_points", "life_number", "play_time"]
## lists whose entries are read as text (assign() into Array[String], String(entry) or Game.item(entry))
const _CHAR_STRING_ARRAY := ["augments", "inactive_mutations", "elements", "slots", "shrine_elements",
	"pending_draft_tiers", "inventory", "spell_loadout", "reaver_loadout"]
## lists whose entries are only compared (Array.has), any JSON value is safe
const _CHAR_ARRAY := ["seen_unlocks"]
const _CHAR_DICT := ["allocated", "equipment", "discipline_casts"]


static func validate_save(d: Dictionary) -> String:
	if d.has("version") and not _is_number(d.version):
		return "version is not a number"
	if is_newer_version(d):
		return "save version %s is newer than supported %d" % [_fmt_version(d.version), VERSION]
	if not (d.get("characters") is Dictionary):
		return "characters missing or not an object"
	for cid in Game.CLASSES:
		if d.characters.has(cid):
			var problem := _validate_character(cid, d.characters[cid])
			if problem != "":
				return "character '%s': %s" % [cid, problem]
	return ""


static func _validate_character(cid: String, c: Variant) -> String:
	if not (c is Dictionary):
		return "not an object"
	for k in _CHAR_BOOL:
		if c.has(k) and typeof(c[k]) != TYPE_BOOL:
			return k + " is not a boolean"
	for k in _CHAR_STRING:
		if c.has(k) and typeof(c[k]) != TYPE_STRING:
			return k + " is not a string"
	for k in _CHAR_NUMBER:
		if c.has(k) and not _is_number(c[k]):
			return k + " is not a number"
	for k in _CHAR_STRING_ARRAY:
		if c.has(k):
			if not (c[k] is Array):
				return k + " is not a list"
			for v in c[k]:
				if typeof(v) != TYPE_STRING:
					return k + " contains a non-text entry"
	for k in _CHAR_ARRAY:
		if c.has(k) and not (c[k] is Array):
			return k + " is not a list"
	for k in _CHAR_DICT:
		if c.has(k) and not (c[k] is Dictionary):
			return k + " is not an object"
	if c.has("class_id") and c.class_id != cid:
		return "class_id '%s' does not match its entry" % c.class_id
	if c.has("level") and float(c.level) < 1.0:
		return "level below 1"
	if c.has("allocated"):
		for k in c.allocated:
			if not _is_number(c.allocated[k]):
				return "allocated." + str(k) + " is not a number"
	if c.has("equipment"):
		for k in c.equipment:
			if typeof(c.equipment[k]) != TYPE_STRING:
				return "equipment." + str(k) + " is not an item id"
	if c.has("discipline_casts"):
		for k in c.discipline_casts:
			if not _is_number(c.discipline_casts[k]):
				return "discipline_casts." + str(k) + " is not a number"
	return ""


static func _is_number(v: Variant) -> bool:
	var t := typeof(v)
	if t == TYPE_INT:
		return true
	return t == TYPE_FLOAT and not is_nan(v) and not is_inf(v)


## A free "<base><tag><unix time>[-n]" path for a file that is moved aside (never overwrites one).
func _aside_name(base: String, tag: String) -> String:
	var stem := base + tag + str(int(Time.get_unix_time_from_system()))
	var p := stem
	var n := 1
	while FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p):
		p = "%s-%d" % [stem, n]
		n += 1
	return p


## Writes `data` to `path` without ever leaving the user with no save:
## temp file -> verified -> previous file moved to .bak -> temp renamed into place -> .bak removed.
## Any failure restores the previous file and returns false with last_error set. An existing file that
## cannot be parsed is moved aside to .corrupt-<unix time> instead of being deleted. Refuses (writes
## nothing) while the primary save was written by a newer build.
func _write_atomic(data: Dictionary) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	var tmp := abs_path + ".tmp"
	var bak := abs_path + ".bak"
	# an interrupted earlier write must be restored first, so it rotates into .bak instead of being lost
	recover_if_needed()
	if newer_version > 0.0:
		last_error = "save written by a newer version (%s) - not overwritten" % _fmt_version(newer_version)
		push_warning(last_error)
		return false
	# any .tmp left by a crash (finished, partial or from another build) is kept, never overwritten
	if FileAccess.file_exists(tmp):
		if DirAccess.rename_absolute(tmp, _aside_name(abs_path, ".orphan-")) != OK:
			last_error = "cannot preserve an earlier unfinished save"
			return false
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "cannot write save"
		return false
	var stored := f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if not stored or not (_read_file(tmp) is Dictionary):
		var why := last_error
		DirAccess.remove_absolute(tmp)
		last_error = ("cannot write save: " + why) if stored else "cannot write save"
		push_warning(last_error)
		return false
	var previous := ""
	var keep_previous := false
	if FileAccess.file_exists(abs_path):
		if _read_file(abs_path) is Dictionary:
			previous = bak
			if FileAccess.file_exists(bak):
				# a valid .bak is an older generation of this save; anything else is kept as .orphan-*
				var bak_ok: bool = _read_file(bak) is Dictionary
				FileAccess.set_read_only_attribute(bak, false)
				var res := DirAccess.remove_absolute(bak) if bak_ok else DirAccess.rename_absolute(bak, _aside_name(abs_path, ".orphan-bak-"))
				if res != OK:
					DirAccess.remove_absolute(tmp)
					last_error = "cannot replace save backup"
					return false
		else:
			previous = _aside_name(abs_path, ".corrupt-")
			keep_previous = true
		if DirAccess.rename_absolute(abs_path, previous) != OK:
			DirAccess.remove_absolute(tmp)
			last_error = "cannot replace save"
			return false
	if DirAccess.rename_absolute(tmp, abs_path) != OK:
		if previous != "":
			DirAccess.rename_absolute(previous, abs_path)
		DirAccess.remove_absolute(tmp)
		last_error = "cannot replace save"
		return false
	last_error = ""
	if keep_previous:
		last_error = "unreadable previous save kept as " + previous.get_file()
		push_warning(last_error)
	elif previous != "":
		FileAccess.set_read_only_attribute(previous, false)
		DirAccess.remove_absolute(previous)
	return true


## Writes every class + settings. Refuses while the session is debug-tainted.
func save_game() -> bool:
	if not enabled:
		return false
	last_error = ""
	if Game.debug_tainted:
		last_error = "debug session - not saved"
		return false
	if Game.test_session:
		last_error = "test session - not saved"
		return false
	var chars := {}
	for c in Game.CLASSES:
		chars[c] = Game.prog(c).to_dict()
	var data := {"version": VERSION, "last_class": Game.active_class, "characters": chars, "settings": settings,
		"saved_at": Time.get_datetime_string_from_system()}
	return _write_atomic(data)


## Settings are written on their own (allowed in debug sessions: they never touch characters).
## Character data is copied from the file on disk; if that file exists but cannot be read, nothing is
## written (the in-memory settings still apply this session) so character data is never replaced.
func save_settings() -> bool:
	if not enabled:
		return false
	last_error = ""
	var data := {"version": VERSION, "characters": {}, "last_class": ""}
	if has_save():
		var existing = _read_file(ProjectSettings.globalize_path(path))
		if not (existing is Dictionary):
			last_error = "existing save not usable (%s) - settings not written" % last_error
			push_warning(last_error)
			return false
		data = existing
	data["settings"] = settings
	return _write_atomic(data)


func load_game() -> bool:
	load_problem = ""
	var data := _read()
	if data.is_empty():
		if FileAccess.file_exists(path):
			load_problem = _describe_problem()
			push_warning("save not loaded: " + last_error)
		return false
	var chars: Dictionary = data.characters
	for c in Game.CLASSES:
		var p := ClassProgress.new(c)
		if chars.has(c):
			p.from_dict(chars[c])
		Game.progress[c] = p
	var lc: Variant = data.get("last_class", "vanguard")
	Game.active_class = lc if typeof(lc) == TYPE_STRING and lc in Game.CLASSES else "vanguard"
	Game.debug_tainted = false
	Game.test_session = false
	_merge_settings(data.get("settings", {}))
	apply_settings()
	return true


## The reason load_game() failed, in words a player can act on.
func _describe_problem() -> String:
	var fname := path.get_file()
	if newer_version > 0.0:
		return ("Your save was made by a newer version of the game (save version %s; this version reads up to %d). " +
			"It was not loaded and will not be changed or overwritten. Until you return to the newer version or move %s " +
			"elsewhere, new characters can only be played in a TEST SESSION that is never saved.") % [_fmt_version(newer_version), VERSION, fname]
	return ("Your save could not be read (%s). It was not loaded. The file is kept: the next time the game saves, " +
		"it is moved to %s.corrupt-<time> instead of being deleted.") % [last_error, fname]


## Copies saved settings over the defaults. A value of the wrong type (which would break apply_settings or
## the camera) is ignored and the default kept; unknown keys are carried along unchanged.
func _merge_settings(raw: Variant) -> void:
	if not (raw is Dictionary):
		return
	for k in raw:
		if not DEFAULT_SETTINGS.has(k):
			settings[k] = raw[k]
		elif typeof(DEFAULT_SETTINGS[k]) == TYPE_BOOL and typeof(raw[k]) == TYPE_BOOL:
			settings[k] = raw[k]
		elif typeof(DEFAULT_SETTINGS[k]) == TYPE_FLOAT and _is_number(raw[k]):
			settings[k] = float(raw[k])


func load_settings_only() -> void:
	var data := _read()
	if not data.is_empty():
		_merge_settings(data.get("settings", {}))


func last_class() -> String:
	return str(_read().get("last_class", ""))


func created_characters() -> Array:
	var out: Array = []
	for c in Game.CLASSES:
		if Game.prog(c).created:
			out.append(c)
	return out


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func apply_settings() -> void:
	if Game.balance:
		Game.balance.damage_numbers = bool(settings.damage_numbers)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
		if settings.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Game.settings_changed.emit()
