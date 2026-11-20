class_name TrainingUI
extends CanvasLayer
## Training Grounds panel (visible inside the training yard). Shows the Training autoload stats:
## total, hits, per hit, crit rate, DPS, healing, resources spent, per-skill breakdown, augment /
## core activations and a before/after comparison against a saved baseline.
## Keys: F5 reset  ·  F6 save baseline  ·  F7 dummy armour  ·  F8 dummy swings on/off

const ARMOR_STEPS := [[0.0, 0.0], [40.0, 40.0], [120.0, 120.0]]

var panel: PanelContainer
var text: RichTextLabel
var armor_i: int = 0
var swing: bool = false
var _t: float = 0.0


func _ready() -> void:
	layer = 6
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD_DIM, 0.88))
	UITheme.apply(panel)
	UIUtil.place(panel, 1, 0, 1, 0, -430, 130, -16, 160)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 15)
	panel.add_child(text)
	panel.visible = false


func in_training() -> bool:
	return is_instance_valid(Game.player) and is_instance_valid(Game.world) and Game.world.has_method("area_at") and Game.world.area_at(Game.player.global_position) == "training"


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F5:
			Training.reset()
		KEY_F6:
			Training.save_baseline()
			Events.notify.emit("Baseline saved")
		KEY_F7:
			armor_i = (armor_i + 1) % ARMOR_STEPS.size()
			for d in get_tree().get_nodes_in_group("training_dummy"):
				d.set_defenses(ARMOR_STEPS[armor_i][0], ARMOR_STEPS[armor_i][1])
			Events.notify.emit("Dummy armour / resist: %d" % ARMOR_STEPS[armor_i][0])
		KEY_F8:
			swing = not swing
			for d in get_tree().get_nodes_in_group("training_dummy"):
				d.swing_mode = swing
			Events.notify.emit("Dummy swings " + ("ON" if swing else "OFF"))
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	panel.visible = in_training()
	_t -= delta
	if not panel.visible or _t > 0.0:
		return
	_t = 0.25
	var s := "[b][color=#f2d27f]TRAINING  ·  %s[/color][/b]\n" % Game.active_class.to_upper()
	s += "Dummy armour/resist [color=#f2d27f]%d[/color]  ·  swings %s\n\n" % [ARMOR_STEPS[armor_i][0], "ON" if swing else "off"]
	s += "Total damage  [b]%d[/b]\nHits  %d   ·   per hit  %.1f   ·   biggest  %d\n" % [roundi(Training.total), Training.hits, Training.per_hit(), roundi(Training.biggest)]
	s += "Crit rate  %.0f%%   ·   DPS  [b]%.1f[/b]  (%.1fs)\n" % [Training.crit_rate() * 100.0, Training.dps(), Training.duration()]
	s += "Healing  %d   ·   Stamina spent  %d   ·   Mana spent  %d\n" % [roundi(Training.healed), roundi(Training.stamina_spent), roundi(Training.mana_spent)]
	if not Training.cuts.is_empty():
		s += "Cuts: " + ",  ".join(Training.cuts.keys().map(func(k): return "%s %d" % [k, Training.cuts[k]])) + "\n"
	if not Training.spell_casts.is_empty() or Training.casts_interrupted > 0:
		s += "\n[color=#f2d27f]SPELLCASTING[/color]\n"
		s += "Casts %d  ·  interrupted %d  ·  completion %.0f%%\n" % [Training.casts_done, Training.casts_interrupted, Training.completion_rate() * 100.0]
		for k in Training.spell_casts:
			var c: Dictionary = Training.spell_casts[k]
			var n: int = c.partial + c.full
			s += "%s  ·  partial %d / full %d  ·  avg charge %.2fs\n" % [String(k).capitalize(), c.partial, c.full, c.charge / maxf(1, n)]
		s += "Heal / cast %.0f  ·  Poise dealt %d  ·  Control %.1fs\n" % [Training.heal_per_cast(), roundi(Training.poise_dealt), Training.control_time]
		if Training.sanctum_active_t > 0.0:
			s += "Sanctum uptime %.1fs  (inside %.0f%%)\n" % [Training.sanctum_active_t, 100.0 * Training.sanctum_inside_t / maxf(0.01, Training.sanctum_active_t)]
	s += "\n[color=#f2d27f]PER SKILL[/color]\n"
	var keys: Array = Training.per_skill.keys()
	keys.sort_custom(func(a, b): return Training.per_skill[a].damage > Training.per_skill[b].damage)
	for k in keys.slice(0, 8):
		var e: Dictionary = Training.per_skill[k]
		s += "%s  ·  %d dmg  ·  %d hits  ·  %d crit\n" % [k, roundi(e.damage), e.hits, e.crits]
	if not Training.activations.is_empty():
		s += "\n[color=#f2d27f]ACTIVATIONS[/color]\n"
		for k in Training.activations.keys().slice(0, 10):
			s += "%s x%d\n" % [k, Training.activations[k]]
	if not Training.interaction_events.is_empty():
		s += "\n[color=#f2d27f]ELEMENTAL INTERACTIONS[/color]\n"
		for k in Training.interaction_events:
			s += "%s x%d\n" % [String(k).replace("_", " ").capitalize(), Training.interaction_events[k]]
	if not Training.baseline.is_empty():
		s += "\n[color=#f2d27f]VS BASELINE[/color]\n"
		for row in Training.comparison():
			s += "%s  %s  (base %s)  [b]%s[/b]\n" % [row[0], _f(row[1]), _f(row[2]), row[3]]
	s += "\n[color=#a89f90]F5 reset · F6 baseline · F7 armour · F8 swings[/color]"
	text.text = s


func _f(v) -> String:
	if v == null:
		return "-"
	return "%.1f" % float(v) if float(v) < 10.0 else str(roundi(float(v)))
