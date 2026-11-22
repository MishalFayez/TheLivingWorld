extends Node
## Entry point (Update 5):
##   Title  ->  Continue / New Character / Character Selection / Settings / Exit
##   New Character -> choose class (live 3D model, role, strengths, core) -> name -> Level 1
##   Character Selection -> each class is an independent saved character (Play / Training / Reset)
## Also handles Return to Title (discarding debug-only changes) and autosave on quit.

const WORLD_SCENE := "res://scenes/world/ashen_valley.tscn"
const SESSION_LAYERS := ["HUD", "DraftUI", "DebugPanel", "GameMenu", "PauseMenu", "UnlockPopup", "TrainingUI"]

var menu: CanvasLayer
var root: Control
var party: bool = false
var world: Node3D
var screens: Dictionary = {}
var new_class: String = "vanguard"
var preview: ModelPreview
var info_box: VBoxContainer
var name_edit: LineEdit
var confirm: ConfirmationDialog
var name_box: VBoxContainer
var name_msg: Label
var name_confirm_edit: LineEdit
var _confirm_name: String = ""
var class_buttons: Dictionary = {}
var select_list: VBoxContainer


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	if Save.has_save():
		Save.load_game()
	party = bool(Save.settings.get("party_default", false))
	if OS.get_cmdline_user_args().has("--autostart"):
		start_game("reaver", false)
		return
	_show_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _quit() -> void:
	if world != null:
		Game.autosave()
	get_tree().quit()


# ------------------------------------------------------------------ menu shell
func _show_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	UITheme.apply(root)
	UIUtil.ltr(root)
	menu.add_child(root)
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.17, 0.1, 0.08))
	grad.set_color(1, Color(0.025, 0.02, 0.025))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.1, 1.1)
	gt.width = 512
	gt.height = 512
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var embers := MenuEmbers.new()
	embers.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(embers)
	screens.title = _build_title()
	screens.create = _build_create()
	screens.select = _build_select()
	screens.settings = _build_settings()
	for k in screens:
		root.add_child(screens[k])
	confirm = ConfirmationDialog.new()
	confirm.title = "Replace character?"
	confirm.ok_button_text = "Replace"
	confirm.cancel_button_text = "Cancel"
	root.add_child(confirm)
	# 006 review 2 (save safety): destructive Reset / Create over an existing character needs the name typed
	name_box = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 10)
	name_msg = Label.new()
	name_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_msg.custom_minimum_size = Vector2(480, 0)
	name_box.add_child(name_msg)
	name_confirm_edit = LineEdit.new()
	name_confirm_edit.text_changed.connect(_on_confirm_name_changed)
	name_box.add_child(name_confirm_edit)
	name_box.visible = false
	confirm.add_child(name_box)
	_goto("title")


## Shows `msg` and requires the character's name (case-insensitive) before the destructive OK is enabled.
func _arm_name_confirm(msg: String, char_name: String) -> void:
	_confirm_name = char_name.strip_edges() if char_name.strip_edges() != "" else "REPLACE"
	confirm.dialog_text = ""
	name_msg.text = msg + "\n\nA backup of your save is kept automatically.\nType the character's name to confirm:  " + _confirm_name
	name_confirm_edit.text = ""
	name_confirm_edit.placeholder_text = _confirm_name
	name_box.visible = true
	confirm.get_ok_button().disabled = true


func _disarm_name_confirm() -> void:
	_confirm_name = ""
	if name_box:
		name_box.visible = false
	confirm.get_ok_button().disabled = false


func _on_confirm_name_changed(t: String) -> void:
	confirm.get_ok_button().disabled = _confirm_name == "" or t.strip_edges().to_lower() != _confirm_name.to_lower()


func _popup_confirm() -> void:
	confirm.popup_centered()
	if name_box.visible:
		name_confirm_edit.grab_focus()


func _goto(s: String) -> void:
	for k in screens:
		screens[k].visible = k == s
	if s == "select":
		_refresh_select()
	if s == "title":
		_refresh_title()
	if s == "create":
		_pick_new_class(new_class)


func _big_button(text: String, fn: Callable, w: float = 340.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(fn)
	return btn


# ------------------------------------------------------------------ title
var _continue_btn: Button
var _continue_info: Label


func _build_title() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	var t := UITheme.title("THE LIVING WORLD", 72)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UITheme.divider(620, "ASHEN VALLEY"))
	var sub := UITheme.text("playable prototype", 18, UITheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v.add_child(spacer)
	_continue_btn = _big_button("Continue", _continue)
	for b in [_continue_btn, _big_button("New Character", func(): _goto("create")),
			_big_button("Character Selection", func(): _goto("select")), _big_button("Settings", func(): _goto("settings")),
			_big_button("Exit", _quit)]:
		var holder := CenterContainer.new()
		holder.add_child(b)
		v.add_child(holder)
		if b == _continue_btn:
			_continue_info = UITheme.text("", 14, UITheme.TEXT_DIM)
			_continue_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(_continue_info)
	return c


func _refresh_title() -> void:
	var lc := Game.active_class
	var p: ClassProgress = Game.progress.get(lc)
	var ok := p != null and p.created
	if not ok:
		for c in Game.CLASSES:
			if Game.prog(c).created:
				lc = c
				ok = true
				break
	_continue_btn.disabled = not ok
	_continue_info.text = ("%s  ·  %s  ·  Level %d" % [Game.prog(lc).character_name, lc.capitalize(), Game.prog(lc).level]) if ok else "no saved character yet"
	# REVIEW-003: a save that exists but could not be loaded is explained instead of looking like "no save"
	var problem := Save.load_problem != "" and not ok
	_continue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if problem else TextServer.AUTOWRAP_OFF
	_continue_info.custom_minimum_size = Vector2(620, 0) if problem else Vector2.ZERO
	_continue_info.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45) if problem else UITheme.TEXT_DIM)
	if problem:
		_continue_info.text = Save.load_problem


func _continue() -> void:
	var lc := Game.active_class
	if not Game.prog(lc).created:
		for c in Game.CLASSES:
			if Game.prog(c).created:
				lc = c
				break
	if Game.prog(lc).created:
		start_game(lc, party)


# ------------------------------------------------------------------ new character
func _build_create() -> Control:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]:
		m.add_theme_constant_override("margin_" + k, 70)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 40)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	var t := UITheme.title("NEW CHARACTER", 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UITheme.divider(1100, "CHOOSE YOUR PATH"))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 26)
	v.add_child(row)
	# class list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 12)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	for cid in Game.CLASSES:
		var b := Button.new()
		b.text = "   " + cid.to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(300, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick_new_class.bind(cid))
		left.add_child(b)
		class_buttons[cid] = b
	# model
	var mid := PanelContainer.new()
	mid.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD_DIM, 0.55))
	mid.custom_minimum_size = Vector2(420, 520)
	row.add_child(mid)
	preview = ModelPreview.new()
	preview.class_id = new_class
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(preview)
	# info
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD_DIM, 0.85))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	right.add_child(info_box)
	# name + buttons
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	bottom.add_child(_big_button("Back", func(): _goto("title"), 160))
	bottom.add_child(UITheme.text("Name", 18, UITheme.GOLD))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Enter a name"
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(300, 46)
	name_edit.add_theme_font_size_override("font_size", 18)
	bottom.add_child(name_edit)
	_create_btn = _big_button("Create  ·  Level 1", _confirm_create, 300)
	bottom.add_child(_create_btn)
	return m


var _create_btn: Button


func _pick_new_class(cid: String) -> void:
	new_class = cid
	if _create_btn:
		_create_btn.text = "Create  ·  Test Session" if Game.saving_locked() else "Create  ·  Level 1"
	for k in class_buttons:
		class_buttons[k].button_pressed = k == cid
	if preview:
		preview.show_class(cid)
	for c in info_box.get_children():
		c.queue_free()
	var info: Dictionary = MainMenuText.CLASSES[cid]
	var acc: Color = UITheme.CLASS_ACCENT[cid]
	info_box.add_child(UITheme.title(cid.to_upper(), 34, acc.lightened(0.2)))
	info_box.add_child(UITheme.text(info.role, 16, UITheme.GOLD, true))
	info_box.add_child(UITheme.divider(460))
	var d := UITheme.text(info.text, 16)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(440, 0)
	info_box.add_child(d)
	info_box.add_child(UITheme.title("CORE  ·  " + String(info.core).to_upper(), 16, acc))
	info_box.add_child(UITheme.title("STRENGTHS", 16))
	for st in info.strengths:
		var l := UITheme.text("◆  " + st, 15, UITheme.PARCHMENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(440, 0)
		info_box.add_child(l)
	info_box.add_child(UITheme.text("Difficulty: " + info.difficulty, 14, UITheme.TEXT_DIM))
	var t := Game.track(cid)
	if t:
		var path := ""
		for m in t.milestones:
			if m.kind in ["skill", "mechanic", "mastery", "element"] and int(m.level) > 1:
				path += "Lv%d %s   " % [m.level, m.name]
		var pl := UITheme.text("Progression:  " + path, 13, UITheme.TEXT_DIM)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.custom_minimum_size = Vector2(440, 0)
		info_box.add_child(pl)
	var p := Game.prog(cid)
	if Game.saving_locked():
		var lw := UITheme.text("A save from a newer version is protected: this character can only be played as a TEST SESSION. Nothing is saved.", 14, Color(1.0, 0.6, 0.45))
		lw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lw.custom_minimum_size = Vector2(440, 0)
		info_box.add_child(lw)
	elif p.created:
		var w := UITheme.text("Existing %s: %s (Level %d) will be replaced." % [cid.capitalize(), p.character_name, p.level], 14, Color(1.0, 0.6, 0.45))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size = Vector2(440, 0)
		info_box.add_child(w)


## REVIEW-004: while a newer-version save is protected, a character can only start a labelled test session.
func _confirm_test_session() -> void:
	_disarm_name_confirm()
	confirm.title = "Test session - not saved"
	confirm.ok_button_text = "Start Test Session"
	confirm.dialog_text = ("Your save was made by a newer version of the game and is protected: it will not be changed.\n" +
		"This %s will be played as a TEST SESSION. Nothing from it is saved, and it is discarded when you return to the title.") % new_class.capitalize()
	for cn in confirm.confirmed.get_connections():
		confirm.confirmed.disconnect(cn.callable)
	confirm.confirmed.connect(_create_test_now)
	confirm.popup_centered()


func _create_test_now() -> void:
	Game.test_session = true
	Game.create_character(new_class, name_edit.text)
	start_game(new_class, party)


func _confirm_create() -> void:
	if Game.saving_locked():
		_confirm_test_session()
		return
	confirm.title = "Replace character?"
	confirm.ok_button_text = "Replace"
	var p := Game.prog(new_class)
	if p.created:
		_arm_name_confirm("Your %s %s (Level %d) will be permanently replaced by a new Level 1 character.\nOther classes are not affected." % [new_class.capitalize(), p.character_name, p.level], p.character_name)
		for cn in confirm.confirmed.get_connections():
			confirm.confirmed.disconnect(cn.callable)
		confirm.confirmed.connect(_create_now)
		_popup_confirm()
	else:
		_create_now()


func _create_now() -> void:
	Game.create_character(new_class, name_edit.text)
	start_game(new_class, party)


# ------------------------------------------------------------------ character selection
func _build_select() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	var t := UITheme.title("CHARACTER SELECTION", 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UITheme.divider(1000, "EACH CLASS PROGRESSES INDEPENDENTLY"))
	select_list = VBoxContainer.new()
	select_list.add_theme_constant_override("separation", 10)
	v.add_child(select_list)
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 30)
	v.add_child(opts)
	opts.add_child(UIUtil.check("Party Test  (AI controls the other two classes)", party, func(on): party = on))
	opts.add_child(UIUtil.check("Permadeath", Game.permadeath, func(on): Game.permadeath = on))
	var back := CenterContainer.new()
	back.add_child(_big_button("Back", func(): _goto("title"), 200))
	v.add_child(back)
	return c


func _refresh_select() -> void:
	for ch in select_list.get_children():
		ch.queue_free()
	for cid in Game.CLASSES:
		var p := Game.prog(cid)
		var acc: Color = UITheme.CLASS_ACCENT[cid]
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UITheme.panel(acc.darkened(0.3), 0.9))
		pc.custom_minimum_size = Vector2(980, 86)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		pc.add_child(h)
		var ic := GameIcon.new()
		ic.icon_id = cid
		ic.color = acc
		ic.custom_minimum_size = Vector2(60, 60)
		h.add_child(ic)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		if p.created:
			tv.add_child(UITheme.title("%s  ·  %s" % [p.character_name, cid.to_upper()], 22, acc.lightened(0.2)))
			tv.add_child(UITheme.text("Level %d   ·   %d augments   ·   life %d   ·   %s" % [p.level, p.augments.size(), p.life_number, "%d pts unspent" % p.free_points if p.free_points > 0 else "stats allocated"], 15, UITheme.TEXT_DIM))
			h.add_child(_big_button("Play", func(): start_game(cid, party), 140))
			h.add_child(_big_button("Training", func(): start_game(cid, party, true), 140))
			h.add_child(_big_button("Reset", func(): _ask_reset(cid), 120))
		else:
			tv.add_child(UITheme.title(cid.to_upper() + "  ·  empty", 22, UITheme.TEXT_DIM))
			tv.add_child(UITheme.text("No character yet", 15, UITheme.TEXT_DIM))
			h.add_child(_big_button("Create", func():
				new_class = cid
				_goto("create"), 160))
		# LEVEL10-FOUNDATION-005 review: safe Level 1-10 playtest route - never touches the saved character
		var ft := _big_button("Fresh Lv1 Test", func():
			Game.start_fresh_test(cid)
			start_game(cid, party), 170)
		ft.tooltip_text = "A new Level 1 %s that is NOT saved. Your saved character is not changed. Returning to the title discards it." % cid.capitalize()
		h.add_child(ft)
		select_list.add_child(pc)


func _ask_reset(cid: String) -> void:
	var p := Game.prog(cid)
	confirm.title = "Replace character?"
	confirm.ok_button_text = "Replace"
	_arm_name_confirm("Reset %s (Level %d) back to a fresh Level 1 %s?\nThis cannot be undone. Other classes are not affected." % [p.character_name, p.level, cid.capitalize()], p.character_name)
	for cn in confirm.confirmed.get_connections():
		confirm.confirmed.disconnect(cn.callable)
	confirm.confirmed.connect(func():
		Game.reset_character(cid)
		_refresh_select())
	_popup_confirm()


# ------------------------------------------------------------------ settings
func _build_settings() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD, 0.95))
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	v.add_child(SettingsPanel.new())
	var cc := CenterContainer.new()
	cc.add_child(_big_button("Back", func(): _goto("title"), 200))
	v.add_child(cc)
	return c


# ------------------------------------------------------------------ session
func start_game(class_id: String, p_party: bool, training: bool = false) -> void:
	if menu:
		menu.queue_free()
		menu = null
	class_buttons.clear()
	preview = null
	# REVIEW-004: no progression session may save while a newer-version save is protected; every start
	# path (menu, Character Selection, tests, --autostart) becomes a labelled test session
	if Game.saving_locked() and not Game.test_session:
		push_warning("newer-version save is protected - starting a non-saving TEST SESSION")
		Game.test_session = true
	if not Game.prog(class_id).created:
		# direct start (tests / --autostart): a temporary unsaved Level 1 character
		Game.prog(class_id).created = true
		Game.prog(class_id).character_name = class_id.capitalize()
	world = load(WORLD_SCENE).instantiate()
	add_child(world)
	Game.start_session(world, class_id, p_party)
	for name_cls in [["HUD", HUD], ["DraftUI", DraftUI], ["DebugPanel", DebugPanel], ["GameMenu", GameMenu], ["PauseMenu", PauseMenu], ["UnlockPopup", UnlockPopup], ["TrainingUI", TrainingUI]]:
		var n = name_cls[1].new()
		n.name = name_cls[0]
		if "main" in n:
			n.main = self
		add_child(n)
	if training:
		world.teleport_player("training")
	else:
		Events.notify.emit("Valley Outskirts")
	if Game.fresh_test:
		Events.notify.emit("FRESH TEST CHARACTER - nothing is saved (Esc > 'Test session: gain a level')")
		Events.log_message.emit("Fresh Level 1 test session: your saved characters are untouched; returning to the title discards this session.", "system")
	elif Game.test_session:
		Events.notify.emit("TEST SESSION - progress is not saved")
		Events.log_message.emit("Test session: a save from a newer version is protected, so nothing from this session is saved.", "system")


func return_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if Game.debug_tainted or Game.test_session:
		# discard debug-only / test-session changes: reload the characters exactly as last saved
		Game.reset_all_progress()
		if Save.has_save():
			Save.load_game()
		Game.debug_tainted = false
		Game.test_session = false
		Game.fresh_test = false
	else:
		Game.autosave()
	for n in SESSION_LAYERS:
		var c := get_node_or_null(n)
		if c:
			c.queue_free()
	if is_instance_valid(world):
		world.queue_free()
	world = null
	Game.end_session()
	_show_menu()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
