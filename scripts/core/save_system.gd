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
	return FileAccess.file_exists(path)


func _read() -> Dictionary:
	if not has_save():
		return {}
	var data = _read_file(path)
	return data if data is Dictionary else {}


## Parses a save file. Returns null (and sets last_error) when it cannot be opened or is not a JSON object.
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
	return json.data


## Writes `data` to `path` without ever leaving the user with no save:
## temp file -> verified -> previous file moved to .bak -> temp renamed into place -> .bak removed.
## Any failure restores the previous file and returns false with last_error set. An existing file that
## cannot be parsed is moved aside to .corrupt-<unix time> instead of being deleted.
func _write_atomic(data: Dictionary) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	var tmp := abs_path + ".tmp"
	var bak := abs_path + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "cannot write save"
		return false
	var stored := f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if not stored or not (_read_file(tmp) is Dictionary):
		DirAccess.remove_absolute(tmp)
		last_error = "cannot write save"
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
