extends Node
## Local save/load (JSON in user://). One save holds every class character independently plus
## settings. Debug sessions never write the save ("debug-tainted"), so testing cannot corrupt a
## normal character. Autoload name: Save.

const VERSION := 1

var path: String = "user://living_world_save.json"
var enabled: bool = true
var last_error: String = ""
var settings: Dictionary = {
	"mouse_sensitivity": 1.0, "invert_y": false, "camera_shake": true, "damage_numbers": true,
	"fullscreen": false, "vsync": true, "show_fps": false, "party_default": false,
}


func _ready() -> void:
	load_settings_only()


func has_save() -> bool:
	return FileAccess.file_exists(path)


func _read() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "cannot open save"
		return {}
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		last_error = "corrupt save"
		return {}
	return data


## Writes every class + settings. Refuses while the session is debug-tainted.
func save_game() -> bool:
	if not enabled:
		return false
	if Game.debug_tainted:
		last_error = "debug session - not saved"
		return false
	var chars := {}
	for c in Game.CLASSES:
		chars[c] = Game.prog(c).to_dict()
	var data := {"version": VERSION, "last_class": Game.active_class, "characters": chars, "settings": settings,
		"saved_at": Time.get_datetime_string_from_system()}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "cannot write save"
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# atomic-ish replace so a crash mid-write never destroys the previous save
	var dir := DirAccess.open(path.get_base_dir())
	if dir:
		if FileAccess.file_exists(path):
			dir.remove(path.get_file())
		dir.rename(tmp.get_file(), path.get_file())
	return true


## Settings are written on their own (allowed in debug sessions: they never touch characters).
func save_settings() -> void:
	if not enabled:
		return
	var data := _read()
	if data.is_empty():
		data = {"version": VERSION, "characters": {}, "last_class": ""}
	data["settings"] = settings
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


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
