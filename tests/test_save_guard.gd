extends RefCounted
## Usage: preload("res://tests/test_save_guard.gd").isolate("tool_name")
## Call BEFORE instantiating res://scenes/main.tscn in any test or screenshot tool: main._ready loads the
## save at startup. Points Save at a disposable path under the git-ignored .dev/reports, disables writing,
## restores default settings and clears in-memory progress, so the user's real save is never read or written.


static func isolate(tag: String) -> String:
	var dir := ProjectSettings.globalize_path("res://.dev/reports/qa_fixtures")
	DirAccess.make_dir_recursive_absolute(dir)
	var p := dir.path_join("tool_%s.json" % tag)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	Save.enabled = false
	Save.path = p
	Save.reset_settings()
	Game.reset_all_progress()
	Game.debug_tainted = false
	return p
