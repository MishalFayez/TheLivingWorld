extends Node
## Local save/load (JSON in user://). One save holds every class character independently plus
## settings. Debug sessions never write the save ("debug-tainted"), so testing cannot corrupt a
## normal character. Autoload name: Save.

const VERSION := 1

const DEFAULT_SETTINGS := {
	"mouse_sensitivity": 1.0, "invert_y": false, "camera_shake": true, "damage_numbers": true,
	"fullscreen": false, "vsync": true, "show_fps": false, "party_default": false,
}

var path: String = "user://living_world_save.json"
var enabled: bool = true
var last_error: String = ""
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()


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
## moved aside to .corrupt-<time> and the backup itself is kept (copied, not moved). Returns true when a
## recovery happened; `recovered_from` names the source file.
var recovered_from: String = ""


func recover_if_needed() -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path) and _read_file(abs_path) is Dictionary:
		return false
	var best := ""
	var best_time := ""
	for cand in [abs_path + ".bak", abs_path + ".tmp"]:
		if not FileAccess.file_exists(cand):
			continue
		var d = _read_file(cand)
		if d is Dictionary:
			var t := String(d.get("saved_at", ""))
			if best == "" or t > best_time:
				best = cand
				best_time = t
	if best == "":
		return false
	if FileAccess.file_exists(abs_path):
		var aside := abs_path + ".corrupt-%d" % int(Time.get_unix_time_from_system())
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
## or fails validate_save() (structurally malformed data is treated exactly like an unreadable file).
func _read_file(p: String) -> Variant:
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
	var problem := validate_save(json.data)
	if problem != "":
		last_error = "malformed save: " + problem
		return null
	return json.data


## Structural validation of a parsed save. Returns "" when the data can be loaded safely, else the first
## problem found. Only TYPES of fields that are present are checked: a missing field is legal (older saves
## lack later fields and ClassProgress.from_dict fills defaults), so no older save is rejected for that.
## There are no migration rules, so a save whose version is newer than this build is not accepted.
const _CHAR_BOOL := ["created", "bloom_shared"]
const _CHAR_STRING := ["class_id", "name"]
const _CHAR_NUMBER := ["level", "xp", "total_exp", "pending_drafts", "drafts_taken", "free_points", "life_number", "play_time"]
const _CHAR_STRING_ARRAY := ["augments", "inactive_mutations", "elements", "slots", "shrine_elements"]
const _CHAR_ARRAY := ["pending_draft_tiers", "seen_unlocks", "inventory", "spell_loadout", "reaver_loadout"]
const _CHAR_DICT := ["allocated", "equipment", "discipline_casts"]


static func validate_save(d: Dictionary) -> String:
	if d.has("version"):
		if not _is_number(d.version):
			return "version is not a number"
		if float(d.version) > VERSION:
			return "save version %s is newer than supported %d" % [str(d.version), VERSION]
	if not (d.get("characters") is Dictionary):
		return "characters missing or not an object"
	for key in ["last_class", "saved_at"]:
		if d.has(key) and typeof(d[key]) != TYPE_STRING:
			return key + " is not a string"
	if d.has("settings") and not (d.settings is Dictionary):
		return "settings is not an object"
	for cid in d.characters:
		var problem := _validate_character(String(cid), d.characters[cid])
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
	if c.has("class_id") and String(c.class_id) != cid:
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
	return ""


static func _is_number(v: Variant) -> bool:
	var t := typeof(v)
	if t == TYPE_INT:
		return true
	return t == TYPE_FLOAT and not is_nan(v) and not is_inf(v)


## Writes `data` to `path` without ever leaving the user with no save:
## temp file -> verified -> previous file moved to .bak -> temp renamed into place -> .bak removed.
## Any failure restores the previous file and returns false with last_error set. An existing file that
## cannot be parsed is moved aside to .corrupt-<unix time> instead of being deleted.
func _write_atomic(data: Dictionary) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	var tmp := abs_path + ".tmp"
	var bak := abs_path + ".bak"
	# an interrupted earlier write must be restored first, so it rotates into .bak instead of being lost
	recover_if_needed()
	# a fully written .tmp left by a crash may be newer than the primary: keep it, never overwrite it
	if FileAccess.file_exists(tmp) and _read_file(tmp) is Dictionary:
		if DirAccess.rename_absolute(tmp, abs_path + ".orphan-%d" % int(Time.get_unix_time_from_system())) != OK:
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
				FileAccess.set_read_only_attribute(bak, false)
				if DirAccess.remove_absolute(bak) != OK:
					DirAccess.remove_absolute(tmp)
					last_error = "cannot replace save backup"
					return false
		else:
			previous = abs_path + ".corrupt-%d" % int(Time.get_unix_time_from_system())
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
			last_error = "existing save unreadable - settings not written"
			push_warning(last_error)
			return false
		data = existing
	data["settings"] = settings
	return _write_atomic(data)


func load_game() -> bool:
	var data := _read()
	if data.is_empty():
		return false
	var chars: Dictionary = data.get("characters", {})
	for c in Game.CLASSES:
		var p := ClassProgress.new(c)
		if chars.has(c):
			p.from_dict(chars[c])
		Game.progress[c] = p
	var lc := String(data.get("last_class", "vanguard"))
	Game.active_class = lc if lc in Game.CLASSES else "vanguard"
	Game.debug_tainted = false
	settings.merge(Dictionary(data.get("settings", {})), true)
	apply_settings()
	return true


func load_settings_only() -> void:
	var data := _read()
	if not data.is_empty():
		settings.merge(Dictionary(data.get("settings", {})), true)


func last_class() -> String:
	return String(_read().get("last_class", ""))


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
