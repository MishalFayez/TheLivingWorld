class_name PauseMenu
extends CanvasLayer
## Esc: pause menu (Resume, Character, Skills, Augments, Inventory, Map, Journal, Settings,
## Debug Panel, Controls, Return to Title, Quit).

var dim: ColorRect
var panel: PanelContainer
var controls_panel: PanelContainer
var is_open: bool = false
var main: Node
var test_level_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply(root)
	UIUtil.ltr(root)
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.015, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD, 0.96))
	UIUtil.place(panel, 0.5, 0.5, 0.5, 0.5, -170, -330, 170, 330)
	panel.visible = false
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var t := UITheme.title("PAUSED", 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UITheme.divider(300))
	var items := [["Resume", resume]]
	for tab in ["Character", "Skills", "Augments", "Inventory", "Map", "Journal", "Settings"]:
		items.append([tab, _tab.bind(tab)])
	items += [["Debug Panel", _debug], ["Controls", _controls], ["Return to Title", _to_menu], ["Quit Game", func():
		Game.autosave()
		get_tree().quit()]]
	for b in items:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(280, 38)
		btn.pressed.connect(b[1])
		btn.focus_mode = Control.FOCUS_NONE
		v.add_child(btn)
	# LEVEL10-FOUNDATION-005 review: only in a fresh non-saving test session - one natural level-up
	# (real EXP path, real drafts at 4 / 8 / 10). Never shown in normal play.
	test_level_btn = Button.new()
	test_level_btn.text = "Test session: gain a level"
	test_level_btn.custom_minimum_size = Vector2(280, 38)
	test_level_btn.focus_mode = Control.FOCUS_NONE
	test_level_btn.pressed.connect(func():
		resume()
		Game.test_gain_level())
	v.add_child(test_level_btn)
	controls_panel = PanelContainer.new()
	controls_panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD, 0.97))
	UIUtil.place(controls_panel, 0.5, 0.5, 0.5, 0.5, 190, -300, 720, 300)
	controls_panel.visible = false
	root.add_child(controls_panel)
	var cv := VBoxContainer.new()
	controls_panel.add_child(cv)
	cv.add_child(UITheme.title("CONTROLS", 20))
	cv.add_child(UITheme.divider(480))
	var txt := UITheme.text(MainMenuText.CONTROLS, 14)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(490, 0)
	cv.add_child(txt)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse") and is_instance_valid(Game.player):
		var dbg = get_parent().get_node_or_null("DebugPanel")
		var gm = get_parent().get_node_or_null("GameMenu")
		if gm and gm.is_open:
			return
		if dbg and dbg.is_open:
			dbg.toggle()
		elif is_open:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	var draft = get_parent().get_node_or_null("DraftUI")
	if draft and draft.is_open:
		return
	is_open = true
	dim.visible = true
	panel.visible = true
	test_level_btn.visible = Game.fresh_test and Game.test_session and Game.prog().level < Game.balance.max_level
	controls_panel.visible = false
	get_tree().paused = true
	Game.ui_block += 1
	UIUtil.set_mouse_for_ui()


func resume() -> void:
	if not is_open:
		return
	is_open = false
	dim.visible = false
	panel.visible = false
	controls_panel.visible = false
	get_tree().paused = false
	Game.ui_block = maxi(0, Game.ui_block - 1)
	UIUtil.set_mouse_for_ui()


func _tab(t: String) -> void:
	resume()
	var gm = get_parent().get_node_or_null("GameMenu")
	if gm:
		gm.open_tab(t)


func _debug() -> void:
	resume()
	var d = get_parent().get_node_or_null("DebugPanel")
	if d and not d.is_open:
		d.toggle()


func _controls() -> void:
	controls_panel.visible = not controls_panel.visible


func _to_menu() -> void:
	resume()
	if main and main.has_method("return_to_menu"):
		main.return_to_menu()
