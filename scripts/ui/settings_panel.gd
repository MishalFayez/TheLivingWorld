class_name SettingsPanel
extends VBoxContainer
## Settings shared by the title screen and the in-game menu. Stored in the save file's settings
## block (written even while a debug session blocks character saving).

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UITheme.title("SETTINGS", 24))
	add_child(UITheme.divider(520))
	var s: Dictionary = Save.settings
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 12)
	var sl := UITheme.text("Mouse sensitivity", 16)
	sl.custom_minimum_size = Vector2(220, 0)
	sens_row.add_child(sl)
	var slider := HSlider.new()
	slider.min_value = 0.2
	slider.max_value = 3.0
	slider.step = 0.05
	slider.value = float(s.mouse_sensitivity)
	slider.custom_minimum_size = Vector2(240, 24)
	var val := UITheme.text("x%.2f" % slider.value, 15, UITheme.GOLD)
	slider.value_changed.connect(func(v):
		Save.settings.mouse_sensitivity = v
		val.text = "x%.2f" % v
		_commit())
	sens_row.add_child(slider)
	sens_row.add_child(val)
	add_child(sens_row)
	for opt in [["invert_y", "Invert camera Y"], ["camera_shake", "Camera shake"], ["damage_numbers", "Damage numbers"],
			["fullscreen", "Fullscreen"], ["vsync", "V-Sync"], ["show_fps", "Show FPS"], ["party_default", "Party Test by default"]]:
		var key: String = opt[0]
		add_child(UIUtil.check(opt[1], bool(s.get(key, false)), func(on):
			Save.settings[key] = on
			if key == "fullscreen" and DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_MAXIMIZED)
			_commit()))
	var note := UITheme.text("Base UI layout 1600x900, scales to 1920x1080 / 2560x1440 (16:9 and wider).", 13, UITheme.TEXT_DIM)
	add_child(note)


func _commit() -> void:
	Save.apply_settings()
	Save.save_settings()
