class_name GameMenu
extends CanvasLayer
## In-game menu (Update 5). Tabs: Character (model, stats, allocation with REAL previews),
## Skills (learned / locked), Augments, Inventory & Equipment (with comparison), Map, Journal,
## Settings. Hotkeys: C / K / I / M / J. Pauses the game while open.

const TABS := ["Character", "Skills", "Spellbook", "Augments", "Inventory", "Map", "Journal", "Settings"]
const SLOT_ORDER := ["weapon", "head", "chest", "hands", "feet", "accessory"]

var main: Node
var root: Control
var dim: ColorRect
var frame: PanelContainer
var tab_bar: HBoxContainer
var body: Control
var is_open: bool = false
var tab: String = "Character"
var pending: Dictionary = {}
var selected_item: String = ""
var tab_buttons: Dictionary = {}
## LEVEL10-FOUNDATION-005: live skill tooltips ({label, entry, adv}); Shift switches them to DETAILED
var skill_labels: Array = []
var advanced_open: Dictionary = {}
var _shift_was: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 24
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply(root)
	UIUtil.ltr(root)
	root.visible = false
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel(UITheme.GOLD, 0.97))
	UIUtil.place(frame, 0.5, 0.5, 0.5, 0.5, -740, -410, 740, 410)
	root.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	frame.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	tab_bar = top
	for t in TABS:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(140, 40)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(show_tab.bind(t))
		top.add_child(b)
		tab_buttons[t] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var close := Button.new()
	close.text = "Close  [Esc]"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_menu)
	top.add_child(close)
	v.add_child(UITheme.divider(1440))
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	v.add_child(body)
	Events.equipment_changed.connect(func(_c): _refresh_if("Inventory"))
	Events.level_up.connect(func(_c, _l): _refresh_if("Character"))


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(Game.player):
		return
	var map := {"char_sheet": "Character", "menu_skills": "Skills", "menu_spellbook": "Spellbook", "menu_inventory": "Inventory", "menu_map": "Map", "menu_journal": "Journal"}
	for act in map:
		if event.is_action_pressed(act):
			if is_open and tab == map[act]:
				close_menu()
			else:
				open_tab(map[act])
			get_viewport().set_input_as_handled()
			return
	if is_open and event.is_action_pressed("release_mouse"):
		close_menu()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_open or skill_labels.is_empty():
		return
	var sh := Input.is_key_pressed(KEY_SHIFT)
	if sh != _shift_was:
		_shift_was = sh
		_update_skill_labels()


func _tooltip_level(adv: bool) -> int:
	if adv:
		return TooltipText.LEVEL_ADVANCED
	return TooltipText.LEVEL_DETAILED if Input.is_key_pressed(KEY_SHIFT) else TooltipText.LEVEL_SIMPLE


func _calc_source() -> Dictionary:
	if is_instance_valid(Game.player) and Game.player.class_id == cls():
		return TooltipText.source_for_hero(Game.player)
	return TooltipText.source_for_progress(cls(), prog())


func _update_skill_labels() -> void:
	var src := _calc_source()
	for s in skill_labels:
		if is_instance_valid(s.label):
			s.label.text = TooltipText.skill(s.entry, src, _tooltip_level(bool(advanced_open.get(s.entry.id, false))))


func open_tab(t: String) -> void:
	var draft = get_parent().get_node_or_null("DraftUI")
	if draft and draft.is_open:
		return
	if not is_open:
		is_open = true
		Game.ui_block += 1
		get_tree().paused = true
		UIUtil.set_mouse_for_ui()
	root.visible = true
	show_tab(t)


func close_menu() -> void:
	if not is_open:
		return
	pending.clear()
	is_open = false
	root.visible = false
	get_tree().paused = false
	Game.ui_block = maxi(0, Game.ui_block - 1)
	UIUtil.set_mouse_for_ui()


func _refresh_if(t: String) -> void:
	if is_open and tab == t:
		show_tab(t)


func show_tab(t: String) -> void:
	tab = t
	for k in tab_buttons:
		tab_buttons[k].button_pressed = k == t
	tab_buttons.Spellbook.visible = cls() == "mage" and Game.mage_core == "elementalist"
	for c in body.get_children():
		c.queue_free()
	skill_labels.clear()
	var content: Control
	match t:
		"Character":
			content = _character()
		"Skills":
			content = _skills()
		"Augments":
			content = _augments()
		"Spellbook":
			content = _spellbook()
		"Inventory":
			content = _inventory()
		"Map":
			content = _map()
		"Journal":
			content = _journal()
		_:
			var sc := ScrollContainer.new()
			sc.add_child(SettingsPanel.new())
			content = sc
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(content)


func cls() -> String:
	return Game.active_class


func prog() -> ClassProgress:
	return Game.prog()


# ------------------------------------------------------------------ helpers
func _col(w: float = 0.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	if w > 0.0:
		v.custom_minimum_size = Vector2(w, 0)
	return v


func _card(accent: Color = UITheme.GOLD_DIM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel(accent, 0.75))
	return p


func _wrap(text: String, size_px: int, col: Color, w: float) -> Label:
	var l := UITheme.text(text, size_px, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


func _icon(id: String, col: Color, sz: float = 40.0) -> GameIcon:
	var ic := GameIcon.new()
	ic.icon_id = id
	ic.color = col
	ic.custom_minimum_size = Vector2(sz, sz)
	return ic


# ------------------------------------------------------------------ Character
func _character() -> Control:
	var p := prog()
	var c := cls()
	var acc: Color = UITheme.CLASS_ACCENT.get(c, UITheme.GOLD)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	# portrait / model
	var left := _col(330)
	h.add_child(left)
	var mp := ModelPreview.new()
	mp.class_id = c
	mp.custom_minimum_size = Vector2(330, 420)
	left.add_child(mp)
	mp.ready.connect(func(): mp.show_class(c, p))
	left.add_child(UITheme.title(p.character_name if p.character_name != "" else c.capitalize(), 26, acc.lightened(0.2)))
	left.add_child(UITheme.text("%s  ·  Level %d  ·  Life %d" % [c.capitalize(), p.level, p.life_number], 16, UITheme.GOLD))
	var need := p.exp_to_next(Game.balance)
	left.add_child(UITheme.text(("EXP %d / %d" % [p.xp, need]) if p.level < Game.balance.max_level else "MAX LEVEL", 15, UITheme.TEXT_DIM))
	var core: String = MainMenuText.CLASSES[c].core
	if c == "mage" and Game.mage_core != "elementalist":
		core = ("Arcane Weave" if Game.mage_core == "weave" else "Ley Sigils") + " (rejected core - debug comparison)"
	if c == "reaver":
		match Game.reaver_core:
			"bladedancer":
				core = "Blade Dancer"
			"freeflow":
				core = "Free Flow 002 (comparison)"
			"swordmaster":
				core = "Swordmaster / Blade Lines (comparison)"
			"sense":
				core = "Sword Sense (retired - comparison)"
			"bladecraft":
				core = "Bladecraft (legacy core)"
			_:
				core = "No core (comparison)"
	left.add_child(UITheme.text("Core: " + core, 14, UITheme.PARCHMENT))
	if Game.test_session:
		left.add_child(UITheme.text("TEST SESSION - nothing is saved (a newer-version save is protected)", 13, Color(1.0, 0.55, 0.4)))
	elif Game.debug_tainted:
		left.add_child(UITheme.text("DEBUG SESSION - changes are not saved", 13, Color(1.0, 0.55, 0.4)))
	# primary stats + allocation
	var mid := _col(430)
	h.add_child(mid)
	mid.add_child(UITheme.title("ATTRIBUTES", 20))
	var free_left := p.free_points - _pending_total()
	mid.add_child(UITheme.text("Unspent points: %d" % free_left, 16, UITheme.GOLD_BRIGHT if free_left > 0 else UITheme.TEXT_DIM))
	var cur := StatPreview.derived(c, p)
	for k in StatPreview.STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nv := _col(250)
		nv.add_theme_constant_override("separation", 0)
		nv.add_child(UITheme.text("%s  ·  %s" % [StatStyle.STAT[k].abbr, StatPreview.STAT_NAMES[k]], 17, StatStyle.stat_color(k), true))
		nv.add_child(UITheme.text(StatPreview.STAT_ROLE[k], 12, UITheme.TEXT_DIM))
		row.add_child(nv)
		var add := int(pending.get(k, 0))
		var val := UITheme.text("%d%s" % [roundi(cur[k.to_upper()]), "  +%d" % add if add > 0 else ""], 18, UITheme.GOLD_BRIGHT if add > 0 else UITheme.PARCHMENT, true)
		val.custom_minimum_size = Vector2(80, 0)
		row.add_child(val)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(36, 32)
		minus.disabled = add <= 0
		minus.focus_mode = Control.FOCUS_NONE
		minus.pressed.connect(func():
			pending[k] = maxi(0, int(pending.get(k, 0)) - 1)
			show_tab("Character"))
		row.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(36, 32)
		plus.disabled = free_left <= 0
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(func():
			pending[k] = int(pending.get(k, 0)) + 1
			show_tab("Character"))
		row.add_child(plus)
		mid.add_child(row)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var ok := Button.new()
	ok.text = "Confirm allocation"
	ok.disabled = _pending_total() == 0
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_confirm_alloc)
	btns.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.disabled = _pending_total() == 0
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func():
		pending.clear()
		show_tab("Character"))
	btns.add_child(cancel)
	mid.add_child(btns)
	mid.add_child(UITheme.text("Previews use the game's real formulas (StatBlock).", 12, UITheme.TEXT_DIM))
	# milestones
	mid.add_child(UITheme.title("NEXT MILESTONES", 16))
	var t := Game.track(c)
	if t:
		var shown := 0
		for m in t.milestones:
			if int(m.level) > p.level and shown < 3:
				shown += 1
				mid.add_child(UITheme.text("Lv %d  ·  %s" % [m.level, m.name], 14, UITheme.PARCHMENT))
		if shown == 0:
			mid.add_child(UITheme.text("All milestones reached", 14, UITheme.TEXT_DIM))
	# derived stats: before -> after
	var right := _col(600)
	h.add_child(right)
	right.add_child(UITheme.title("DERIVED STATS", 20))
	var after := StatPreview.with_pending(c, p, pending)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	for hd in ["", "Current", "Preview", "Change"]:
		grid.add_child(UITheme.text(hd, 13, UITheme.GOLD, true))
	for key in ["Max HP", "Weapon Power", "Heavy Damage", "Crit Chance", "Crit Damage", "Multi-hit Total", "Physical Reduction", "Magic Reduction", "Effect Power", "Attack Speed", "Cooldown Reduction"]:
		var a: float = cur[key]
		var b: float = after[key]
		grid.add_child(UITheme.text(key, 15, UITheme.PARCHMENT))
		grid.add_child(UITheme.text(StatPreview.fmt(key, a), 15, UITheme.PARCHMENT))
		var changed := absf(b - a) > 0.00001
		grid.add_child(UITheme.text(StatPreview.fmt(key, b), 15, UITheme.GOLD_BRIGHT if changed else UITheme.TEXT_DIM))
		var dl := ""
		if changed:
			dl = ("+" if b > a else "") + StatPreview.fmt(key, b - a)
		grid.add_child(UITheme.text(dl, 15, Color(0.5, 1.0, 0.5) if b > a else Color(1.0, 0.5, 0.45)))
	# LEVEL10-FOUNDATION-005 (Part 8.5): every unlocked skill, before -> after the pending points
	var rows := TooltipText.preview_rows(c, p, StatPreview.clone_with_pending(p, pending))
	if not rows.is_empty():
		right.add_child(UITheme.title("SKILLS  (before crit and armor)", 16))
		var sg := RichTextLabel.new()
		sg.bbcode_enabled = true
		sg.fit_content = true
		sg.scroll_active = false
		sg.custom_minimum_size = Vector2(580, 0)
		sg.add_theme_font_size_override("normal_font_size", 14)
		sg.add_theme_color_override("default_color", UITheme.PARCHMENT)
		var lines: Array = []
		for r in rows:
			var changed: bool = absf(float(r.after) - float(r.before)) >= 0.5
			lines.append("%s: %s%s" % [StatStyle.fx(String(r.kind), String(r.name)), StatStyle.num(r.before),
				("  →  [b]%s[/b] %s" % [StatStyle.num(r.after), StatStyle.delta(r.before, r.after)]) if changed else ""])
		sg.text = "\n".join(lines)
		right.add_child(sg)
	right.add_child(UITheme.title("EQUIPMENT BONUSES", 16))
	var eq_lines: Array = []
	for it in p.equipped_items():
		eq_lines.append("%s: %s" % [it.display_name, ", ".join(it.bonus_lines()) if not it.bonus_lines().is_empty() else "-"])
	right.add_child(_wrap("\n".join(eq_lines) if not eq_lines.is_empty() else "Nothing equipped", 13, UITheme.TEXT_DIM, 580))
	return h


func _pending_total() -> int:
	var n := 0
	for k in pending:
		n += int(pending[k])
	return n


func _confirm_alloc() -> void:
	var p := prog()
	for k in pending:
		for i in int(pending[k]):
			p.allocate(k)
	pending.clear()
	Game.refresh_class_heroes(cls())
	Game.autosave()
	Events.notify.emit("Attributes allocated")
	show_tab("Character")


# ------------------------------------------------------------------ Skills
func _skills() -> Control:
	var sc := ScrollContainer.new()
	var v := _col()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var c := cls()
	var p := prog()
	var t := Game.track(c)
	v.add_child(UITheme.title("%s PROGRESSION  ·  LEVEL %d" % [c.to_upper(), p.level], 20))
	if t == null:
		return sc
	if c == "reaver" and is_instance_valid(Game.player) and Game.player.kit is ReaverKit and Game.player.kit.sword_core():
		var sm: ReaverSwordmaster = Game.player.kit.sm
		v.add_child(UITheme.text("SKILL SLOTS  (Final Stroke is always on F)", 16, UITheme.GOLD, true))
		var row0 := HBoxContainer.new()
		row0.add_theme_constant_override("separation", 18)
		v.add_child(row0)
		var known: Array = ReaverSwordmaster.SKILL_ORDER.filter(func(x): return Game.player.kit.unlocked(x))
		for i in 4:
			var box := _col(240)
			box.add_child(UITheme.text(["1", "2", "3", "E"][i], 14, UITheme.GOLD, true))
			var ob := OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			ob.add_item("(empty)")
			var cur: String = sm.loadout()[i]
			for j in known.size():
				ob.add_item(String(t.milestone(known[j]).get("name", known[j])))
				if known[j] == cur:
					ob.selected = j + 1
			var si := i
			ob.item_selected.connect(func(idx):
				sm.equip(si, "" if idx == 0 else known[idx - 1])
				Game.autosave()
				show_tab("Skills"))
			box.add_child(ob)
			row0.add_child(box)
	_skill_values(v, c, p)
	v.add_child(UITheme.title("PROGRESSION", 18))
	for m in t.milestones:
		var learned: bool = m.kind == "stats" and p.level >= int(m.level) or (m.kind == "augment" and p.level >= int(m.level)) or (m.kind != "stats" and m.kind != "augment" and p.has_unlock(m.id))
		var pc := _card(UITheme.CLASS_ACCENT[c].darkened(0.2) if learned else Color(0.3, 0.28, 0.26))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		pc.add_child(row)
		var lv := UITheme.title("LV %d" % m.level + ("*" if int(m.level) > Game.balance.max_level else ""), 18, UITheme.GOLD_BRIGHT if learned else UITheme.TEXT_DIM)
		lv.custom_minimum_size = Vector2(70, 0)
		row.add_child(lv)
		row.add_child(_icon(String(m.icon) if String(m.icon) != "" else "passive", UITheme.PARCHMENT if learned else Color(0.4, 0.4, 0.4), 40))
		var tv := _col()
		tv.add_theme_constant_override("separation", 2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := String(m.name)
		if String(m.input) != "":
			title += "   [%s]" % m.input
		tv.add_child(UITheme.text(title, 17, UITheme.PARCHMENT if learned else UITheme.TEXT_DIM, true))
		tv.add_child(_wrap(String(m.desc), 14, UITheme.TEXT_DIM, 1000))
		row.add_child(tv)
		var state := "LEARNED" if learned else ("BEYOND LV%d CAP - BUILD SHOWCASE ONLY" % Game.balance.max_level if int(m.level) > Game.balance.max_level else "LOCKED")
		if p.debug_unlocks.has(m.id):
			state = "DEBUG UNLOCK"
		elif p.debug_locks.has(m.id):
			state = "DEBUG LOCK"
		row.add_child(UITheme.text(state, 14, Color(0.55, 1.0, 0.55) if learned else UITheme.TEXT_DIM, true))
		v.add_child(pc)
	return sc


## LEVEL10-FOUNDATION-005 (Part 8.3): every skill with its REAL current values (DamageCalc). SIMPLE by
## default, DETAILED while Shift is held, ADVANCED per card ("Formula & timing").
func _skill_values(v: VBoxContainer, c: String, p: ClassProgress) -> void:
	var entries := SkillCatalog.entries(c, p)
	if entries.is_empty():
		return
	v.add_child(UITheme.title("SKILL VALUES  ·  hold Shift for the calculation", 18))
	var tgt_note := ""
	if is_instance_valid(Game.player) and Game.player.lock_target != null and is_instance_valid(Game.player.lock_target):
		tgt_note = "Locked target: %s (estimates after its armor are shown)" % Game.player.lock_target.display_name
	else:
		tgt_note = "Lock on to an enemy (Tab) to also see estimates after its armor / magic resist."
	v.add_child(UITheme.text("Values use the game's real formulas and your current stats, gear and level. Critical hits are random. " + tgt_note, 13, UITheme.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var src := _calc_source()
	for e in entries:
		var learned: bool = (String(e.get("unlock", "")) == "" or p.has_unlock(String(e.unlock))) if not e.has("known") else bool(e.known)
		var pc := _card(UITheme.CLASS_ACCENT[c].darkened(0.25) if learned else Color(0.3, 0.28, 0.26))
		var col := _col(690)
		col.add_theme_constant_override("separation", 4)
		pc.add_child(col)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.custom_minimum_size = Vector2(690, 0)
		rt.add_theme_font_size_override("normal_font_size", 15)
		rt.add_theme_font_size_override("bold_font_size", 17)
		rt.add_theme_color_override("default_color", UITheme.PARCHMENT if learned else UITheme.TEXT_DIM)
		rt.text = ("" if learned else "[color=#9a8f80]LOCKED[/color]  ") + TooltipText.skill(e, src, _tooltip_level(bool(advanced_open.get(e.id, false))))
		col.add_child(rt)
		var eid: String = e.id
		var adv := Button.new()
		adv.text = "Hide formula & timing" if advanced_open.get(eid, false) else "Formula & timing"
		adv.focus_mode = Control.FOCUS_ALL
		adv.pressed.connect(func():
			advanced_open[eid] = not bool(advanced_open.get(eid, false))
			show_tab("Skills"))
		col.add_child(adv)
		if learned:
			skill_labels.append({"label": rt, "entry": e})
		grid.add_child(pc)


## Elemental Crossroads: choose which IMPLEMENTED interaction is enhanced (availability shown honestly).
func _crossroads_picker(a: AugmentData, p: ClassProgress) -> Control:
	var box := HFlowContainer.new()
	var names := {"thermal_fracture": "Thermal Fracture (Fire on ice, Lv3)", "shattered_winter": "Shattered Winter (Stone on ice, Lv7)",
		"living_bastion": "Living Bastion (Life near fortified Stone, Lv7)", "conductive_anchors": "Conductive Anchors (Storm relay, Lv9)"}
	var need := {"thermal_fracture": "m_frost", "shattered_winter": "m_stone", "living_bastion": "m_stone", "conductive_anchors": "m_storm"}
	var cur := p.crossroads_choice if p.crossroads_choice != "" else String(a.params.get("default_choice", "thermal_fracture"))
	box.add_child(UITheme.text("Enhanced interaction: ", 14, UITheme.GOLD, true))
	for id in String(a.params.get("choices", "thermal_fracture")).split(","):
		var b := Button.new()
		b.text = String(names.get(id, id)) + ("  ✓" if id == cur else "")
		b.disabled = not p.has_unlock(String(need.get(id, ""))) or id == cur
		var cid: String = id
		b.pressed.connect(func():
			p.crossroads_choice = cid
			Game.autosave()
			show_tab("Augments"))
		box.add_child(b)
	return box


# ------------------------------------------------------------------ Augments
func _augments() -> Control:
	var sc := ScrollContainer.new()
	var v := _col()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var p := prog()
	var t := Game.track(cls())
	var lvls := []
	if t:
		lvls = t.draft_levels.keys()
		lvls.sort()
	v.add_child(UITheme.title("AUGMENTS  ·  %d chosen  ·  drafts at levels %s  ·  Major Mutations equipped %d / %d" % [p.augments.size(), ", ".join(lvls.map(func(x): return str(x))), p.active_mutations().size(), Game.balance.max_equipped_mutations], 20))
	if p.pending_drafts > 0:
		var b := Button.new()
		b.text = "Choose augment  (%d pending)" % p.pending_drafts
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(360, 44)
		b.pressed.connect(func():
			close_menu()
			var d = get_parent().get_node_or_null("DraftUI")
			if d:
				d.open(cls()))
		v.add_child(b)
	if p.augments.is_empty():
		v.add_child(UITheme.text("No augments yet - the first draft unlocks at Level %d." % (lvls[0] if not lvls.is_empty() else 4), 16, UITheme.TEXT_DIM))
	var seen := {}
	for id in p.augments:
		if seen.has(id):
			continue
		seen[id] = true
		var a: AugmentData = Game.augment_db.get_augment(id)
		if a == null:
			continue
		var rc: Color = UITheme.RARITY.get(a.rarity, UITheme.PARCHMENT)
		var pc := _card(rc.darkened(0.2))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		pc.add_child(row)
		row.add_child(_icon(a.category, rc, 44))
		var tv := _col()
		tv.add_theme_constant_override("separation", 2)
		var inactive: bool = p.inactive_mutations.has(id)
		if a.pool == "l10":
			# LEVEL10-FOUNDATION-005: generated text (real values), path label, benched state
			tv.add_child(UITheme.text("%s   ·   %s%s" % [a.display_name, AugmentText.header(a), "   ·   BENCHED (kept owned; can return through a later draft)" if inactive else ""], 17, UITheme.TEXT_DIM if inactive else rc.lightened(0.2), true))
			var rtl := RichTextLabel.new()
			rtl.bbcode_enabled = true
			rtl.fit_content = true
			rtl.scroll_active = false
			rtl.custom_minimum_size = Vector2(1180, 0)
			rtl.add_theme_font_size_override("normal_font_size", 14)
			rtl.add_theme_color_override("default_color", UITheme.PARCHMENT)
			# 006: the short sentence by default, everything else behind "Details"
			var det_key := "aug:" + id
			rtl.add_theme_font_size_override("normal_font_size", 16)
			rtl.text = AugmentText.inspect(a, cls(), p) if advanced_open.get(det_key, false) else AugmentText.short(a)
			tv.add_child(rtl)
			var db := Button.new()
			db.text = "Hide details" if advanced_open.get(det_key, false) else "Details"
			db.focus_mode = Control.FOCUS_ALL
			db.pressed.connect(func():
				advanced_open[det_key] = not bool(advanced_open.get(det_key, false))
				show_tab("Augments"))
			tv.add_child(db)
			if a.id == "mf01_elemental_crossroads" and not inactive:
				tv.add_child(_crossroads_picker(a, p))
			row.add_child(tv)
			v.add_child(pc)
			continue
		tv.add_child(UITheme.text("%s%s   ·   %s %s%s" % [a.display_name, "  x%d" % p.augment_stacks(id) if p.augment_stacks(id) > 1 else "", a.rarity.to_upper(), a.category.to_upper(),
			"   ·   INACTIVE (mutation limit %d)" % Game.balance.max_equipped_mutations if inactive else ("   ·   EQUIPPED" if a.category == "mutation" else "")], 17, UITheme.TEXT_DIM if inactive else rc.lightened(0.2), true))
		if Game.augment_db.freeflow_inactive(a):
			tv.add_child(UITheme.text("Incompatible with Free Flow - kept, but has no effect (pending an approved migration design)", 13, Color(1.0, 0.6, 0.45)))
		elif Game.augment_db.bladedancer_inactive(a):
			tv.add_child(UITheme.text("Incompatible with Blade Dancer - kept, but has no effect (pending an approved migration design)", 13, Color(1.0, 0.6, 0.45)))
		if inactive:
			var sw := HFlowContainer.new()
			for act in p.active_mutations():
				var aid: String = id
				var rid: String = act
				var an: AugmentData = Game.augment_db.get_augment(rid)
				sw.add_child(UIUtil.button("Equip, replacing " + an.display_name, func():
					if p.equip_mutation(aid, rid):
						Game.refresh_class_heroes(cls())
						Game.autosave()
					show_tab("Augments")))
			if p.active_mutations().size() < Game.balance.max_equipped_mutations:
				var aid2: String = id
				sw.add_child(UIUtil.button("Equip", func():
					p.equip_mutation(aid2)
					Game.refresh_class_heroes(cls())
					show_tab("Augments")))
			tv.add_child(sw)
		tv.add_child(_wrap(a.description, 14, UITheme.PARCHMENT, 1180))
		if a.interacts_with != "":
			tv.add_child(_wrap("Interacts: " + a.interacts_with, 12, Color(0.6, 0.8, 1.0), 1180))
		row.add_child(tv)
		v.add_child(pc)
	return sc


# ------------------------------------------------------------------ Inventory
func _inventory() -> Control:
	var c := cls()
	var p := prog()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	# equipped slots
	var left := _col(420)
	h.add_child(left)
	left.add_child(UITheme.title("EQUIPPED", 20))
	for slot in SLOT_ORDER:
		var it: ItemData = Game.item(p.equipment.get(slot, ""))
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(410, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.text = "   %s:   %s" % [slot.capitalize(), it.display_name if it else "— empty —"]
		if it:
			b.add_theme_color_override("font_color", UITheme.RARITY.get(it.rarity, UITheme.PARCHMENT))
			b.pressed.connect(func():
				selected_item = it.id
				show_tab("Inventory"))
		left.add_child(b)
	# inventory list
	var mid := _col(380)
	h.add_child(mid)
	mid.add_child(UITheme.title("INVENTORY  (%d)" % p.inventory.size(), 20))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(380, 600)
	var lv := _col()
	sc.add_child(lv)
	mid.add_child(sc)
	if p.inventory.is_empty():
		lv.add_child(_wrap("Empty. Elites and the Warden always drop gear; other enemies sometimes do.", 14, UITheme.TEXT_DIM, 360))
	for id in p.inventory:
		var it: ItemData = Game.item(id)
		if it == null:
			continue
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(370, 46)
		b.focus_mode = Control.FOCUS_NONE
		var usable := it.class_id == "" or it.class_id == c
		b.text = "  %s   (%s, T%d)%s" % [it.display_name, it.slot, it.tier, "" if usable else "  - other class"]
		b.add_theme_color_override("font_color", UITheme.RARITY.get(it.rarity, UITheme.PARCHMENT) if usable else UITheme.TEXT_DIM)
		b.pressed.connect(func():
			selected_item = id
			show_tab("Inventory"))
		lv.add_child(b)
	# details + comparison
	var right := _col(560)
	h.add_child(right)
	var it: ItemData = Game.item(selected_item)
	if it == null:
		right.add_child(UITheme.title("SELECT AN ITEM", 18, UITheme.TEXT_DIM))
		right.add_child(_wrap("Equipment changes real stats. Higher-tier armour and weapons also change your character's appearance.", 14, UITheme.TEXT_DIM, 540))
		return h
	var rc: Color = UITheme.RARITY.get(it.rarity, UITheme.PARCHMENT)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 12)
	hr.add_child(_icon(it.slot if it.slot != "weapon" else ("staff" if c == "mage" else "sword"), rc, 52))
	var tv := _col()
	tv.add_child(UITheme.title(it.display_name, 22, rc.lightened(0.15)))
	tv.add_child(UITheme.text("%s  ·  %s  ·  Tier %d%s" % [it.rarity.capitalize(), it.slot.capitalize(), it.tier, ("  ·  " + it.class_id.capitalize() + " only") if it.class_id != "" else ""], 14, UITheme.TEXT_DIM))
	hr.add_child(tv)
	right.add_child(hr)
	right.add_child(_wrap(it.description, 15, UITheme.PARCHMENT, 540))
	right.add_child(_wrap("Bonuses: " + (", ".join(it.bonus_lines()) if not it.bonus_lines().is_empty() else "none"), 15, UITheme.GOLD, 540))
	var equipped: bool = p.equipment.get(it.slot, "") == it.id
	var usable2 := it.class_id == "" or it.class_id == c
	if not equipped and usable2:
		var cur := StatPreview.derived(c, p)
		var aft := StatPreview.with_item(c, p, it.id)
		right.add_child(UITheme.title("IF EQUIPPED", 16))
		var any := false
		for key in ["Max HP", "Weapon Power", "Heavy Damage", "Crit Chance", "Crit Damage", "Multi-hit Total", "Physical Reduction", "Magic Reduction", "Effect Power", "Attack Speed", "Cooldown Reduction"]:
			var a: float = cur[key]
			var b: float = aft[key]
			if absf(b - a) > 0.00001:
				any = true
				right.add_child(UITheme.text("%s:  %s  →  %s" % [key, StatPreview.fmt(key, a), StatPreview.fmt(key, b)], 15, Color(0.55, 1.0, 0.55) if b > a else Color(1.0, 0.55, 0.45)))
		if not any:
			right.add_child(UITheme.text("No change to derived stats", 14, UITheme.TEXT_DIM))
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(240, 44)
	if equipped:
		btn.text = "Unequip"
		btn.pressed.connect(func():
			Game.unequip(c, it.slot)
			show_tab("Inventory"))
	else:
		btn.text = "Equip" if usable2 else "Cannot equip (other class)"
		btn.disabled = not usable2
		btn.pressed.connect(func():
			Game.equip(c, it.id)
			show_tab("Inventory"))
	right.add_child(btn)
	return h


# ------------------------------------------------------------------ Map + Journal
func _map() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var m := WorldMap.new()
	m.custom_minimum_size = Vector2(1000, 690)
	h.add_child(m)
	var legend := _col(400)
	h.add_child(legend)
	legend.add_child(UITheme.title("ASHEN VALLEY", 22))
	for l in [["◆", Color(1.0, 0.85, 0.4), "You"], ["●", Color(1.0, 0.35, 0.3), "Encounter (not cleared)"], ["●", Color(0.45, 0.9, 0.45), "Encounter cleared"],
			["▲", Color(0.55, 0.85, 1.0), "Rest point / checkpoint"], ["■", Color(1.0, 0.7, 0.3), "Trial Totem / Shrine"], ["✦", Color(1.0, 0.45, 0.2), "The Ashen Warden"], ["▬", Color(1.0, 0.5, 0.2), "Ash gate (opens when the area is cleared)"]]:
		var r := HBoxContainer.new()
		r.add_child(UITheme.text(l[0], 18, l[1]))
		r.add_child(UITheme.text("  " + l[2], 15, UITheme.PARCHMENT))
		legend.add_child(r)
	legend.add_child(UITheme.divider(380))
	legend.add_child(_wrap("Lv 1-3 Valley Outskirts  ·  Lv 4-7 Forgotten Ruins  ·  Lv 8-10 Warden's Keep. The Training Grounds lie south of the valley entrance.", 14, UITheme.TEXT_DIM, 380))
	return h


func _journal() -> Control:
	var sc := ScrollContainer.new()
	var v := _col()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(UITheme.title("JOURNAL", 22))
	for q in Quests.list():
		var pc := _card(Color(0.45, 0.9, 0.45) if q.done else (UITheme.GOLD if q.active else Color(0.3, 0.28, 0.26)))
		var tv := _col()
		pc.add_child(tv)
		tv.add_child(UITheme.text(("✓  " if q.done else ("➤  " if q.active else "    ")) + q.title, 18, UITheme.PARCHMENT if not q.done else Color(0.6, 0.9, 0.6), true))
		tv.add_child(_wrap(q.text, 14, UITheme.TEXT_DIM, 1300))
		if q.has("progress"):
			tv.add_child(UITheme.text(q.progress, 14, UITheme.GOLD))
		v.add_child(pc)
	return sc



# ------------------------------------------------------------------ Spellbook (Mage - Worldweaver)
const SANCTUM_FX := {"fire": "Eligible full Fire impacts produce a secondary flame wave.",
	"frost": "New ice formations connect to your nearest other ice formation (extended barrier).",
	"stone": "Qualifying Stone impacts raise a small temporary defensive formation.",
	"storm": "One additional relay (one more chain jump / one more arc relay).",
	"life": "Part of the charged healing reaches one additional injured ally."}


func _spellbook() -> Control:
	var h = Game.player
	var sc := ScrollContainer.new()
	if not is_instance_valid(h) or h.class_id != "mage" or not (h.kit is MageKit) or not h.kit.elementalist():
		sc.add_child(UITheme.text("The Spellbook belongs to the Mage (Worldweaver).", 16, UITheme.TEXT_DIM))
		return sc
	var e: MageElementalist = h.kit.el
	var v := _col()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var known: Array = Game.prog().known_elements()
	v.add_child(UITheme.title("SPELLBOOK  ·  known elements: " + ", ".join(known.map(func(x): return String(x).capitalize())), 20))
	v.add_child(_wrap("Hold LMB or RMB to charge; while held, that button's casting wheel appears - point the mouse at another spell to switch (its charge starts again from zero). Release before full charge for the PARTIAL version (a tap casts the last spell and waits for the minimum charge); release at full charge for the FULL version. Holding longer adds nothing. Dodge cancels a charge and spends no mana. Formation spells show a placement preview where you aim; the formation's orientation follows your aim.", 14, UITheme.TEXT_DIM, 1400))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	var opts: Array = e.known_charged()
	var uopts: Array = e.known_utility()
	for i in 4:
		var box := _col(300)
		box.add_child(UITheme.text(["LMB", "RMB", "1", "3 (utility)"][i] + " slot", 15, UITheme.GOLD, true))
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.custom_minimum_size = Vector2(290, 38)
		ob.add_item("(empty)")
		var list: Array = uopts if i == 3 else opts
		var cur_id := e.slot_spell(i)
		for j in list.size():
			ob.add_item(e.spells[list[j]].display_name)
			if list[j] == cur_id:
				ob.selected = j + 1
		var slot_i := i
		ob.item_selected.connect(func(idx):
			e.equip_spell(slot_i, "" if idx == 0 else list[idx - 1])
			Game.autosave()
			show_tab("Spellbook"))
		box.add_child(ob)
		row.add_child(box)
	# COMBAT-BALANCE-UX-006: which known spells each casting wheel offers (LMB / RMB). The slot above is the
	# wheel's current (last cast) spell; healing may sit in either wheel.
	v.add_child(UITheme.title("CASTING WHEELS  ·  hold LMB / RMB, point to a spell, release to cast", 16))
	var wgrid := GridContainer.new()
	wgrid.columns = 4
	wgrid.add_theme_constant_override("h_separation", 26)
	v.add_child(wgrid)
	for hd in ["Spell", "Function", "LMB · " + MageElementalist.WHEEL_NAMES[0], "RMB · " + MageElementalist.WHEEL_NAMES[1]]:
		wgrid.add_child(UITheme.text(hd, 14, UITheme.GOLD, true))
	var pr := Game.prog()
	for sid in e.wheel_options():
		var s: ChargedSpellData = e.spells[sid]
		wgrid.add_child(UITheme.text("%s  (%s)" % [s.display_name, s.element.capitalize()], 14, MageElementalist.COLORS.get(s.element, UITheme.PARCHMENT)))
		wgrid.add_child(UITheme.text(String(MageElementalist.SPELL_ROLE.get(sid, "")), 14, UITheme.TEXT_DIM))
		for slot in [0, 1]:
			var cb := CheckBox.new()
			cb.focus_mode = Control.FOCUS_ALL
			cb.button_pressed = e.wheel_options(slot).has(sid)
			cb.disabled = e.slot_spell(slot) == sid      # the wheel's current spell stays in it
			var sl: int = slot
			var id: String = sid
			cb.toggled.connect(func(on):
				# 006 review 2: customizing starts from what the wheel shows now (its default group)
				pr.set_wheel_member(sl, id, on, e.wheel_options(sl))
				Game.autosave()
				show_tab("Spellbook"))
			wgrid.add_child(cb)
	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 16)
	for slot in [0, 1]:
		var sl2: int = slot
		var customized: bool = not pr.wheel_set(slot).is_empty()
		var rb := Button.new()
		rb.text = "%s wheel: %s" % [["LMB", "RMB"][slot], "restore default group" if customized else "default group"]
		rb.disabled = not customized
		rb.pressed.connect(func():
			pr.wheel_sets.erase(str(sl2))
			Game.autosave()
			show_tab("Spellbook"))
		reset_row.add_child(rb)
	v.add_child(reset_row)
	if e.bloom_modes_known():
		var bm := CheckButton.new()
		bm.focus_mode = Control.FOCUS_NONE
		bm.text = "Life Bloom mode: SHARED (distributes among allies near the target, less each)  -  off = FOCUSED (selected target)"
		bm.button_pressed = e.bloom_shared()
		bm.toggled.connect(func(on):
			e.set_bloom_shared(on)
			Game.autosave())
		v.add_child(bm)
	v.add_child(UITheme.divider(1400))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var ids: Array = MageElementalist.CHARGED_ORDER + ["lifeline"] + MageElementalist.UTILITY_ORDER
	for id in ids:
		var sd: ChargedSpellData = e.spells[id]
		var ok: bool = e.spell_known(id)
		if sd.advanced and not ok:
			continue
		var col: Color = UITheme.ELEMENT.get(sd.element, UITheme.PARCHMENT)
		var pc := _card(col.darkened(0.3) if ok else Color(0.3, 0.28, 0.26))
		pc.custom_minimum_size = Vector2(690, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		pc.add_child(hb)
		hb.add_child(_icon(sd.element, col if ok else Color(0.4, 0.4, 0.4), 46))
		var tv := _col()
		tv.add_theme_constant_override("separation", 2)
		var key: String = {"lifeline": "  [F]"}.get(id, "  [3]" if sd.slot_kind == "utility" else "")
		tv.add_child(UITheme.text(sd.display_name.to_upper() + key + ("" if ok else "   -  " + _spell_lock_text(sd)), 17, col.lightened(0.2) if ok else UITheme.TEXT_DIM, true))
		tv.add_child(_wrap(sd.description, 13, UITheme.PARCHMENT if ok else UITheme.TEXT_DIM, 600))
		if sd.cast_type == "charged":
			tv.add_child(_wrap("PARTIAL (from %.2fs, %d mana): %s" % [sd.min_charge, sd.mana_partial, sd.partial_text], 13, UITheme.TEXT_DIM, 600))
			tv.add_child(_wrap("FULL (%.1fs, %d mana, %d%% move while charging): %s" % [sd.full_charge, sd.mana_full, roundi(sd.move_mult * 100.0), sd.full_text], 13, UITheme.GOLD if ok else UITheme.TEXT_DIM, 600))
			tv.add_child(_wrap("In Arcane Sanctum: " + SANCTUM_FX.get(sd.element, ""), 12, Color(1.0, 0.85, 0.55) if ok else UITheme.TEXT_DIM, 600))
		else:
			tv.add_child(_wrap("Instant  ·  %d mana  ·  %.0fs cooldown" % [sd.mana_partial, sd.cooldown], 13, UITheme.TEXT_DIM, 600))
		hb.add_child(tv)
		grid.add_child(pc)
	var sanct := _card(Color(1.0, 0.85, 0.5).darkened(0.3))
	var sv := _col()
	sanct.add_child(sv)
	var bc: BalanceConfig = Game.balance
	sv.add_child(UITheme.text("ARCANE SANCTUM  [E]" + ("" if h.unlocked("m_sanctum") else "   -  Level 5"), 17, Color(1.0, 0.85, 0.55), true))
	sv.add_child(_wrap("A stationary circle beneath you (%.1fm, %.0fs, %.0fs cooldown). Spells CAST FROM INSIDE gain their element's enhancement; it is never required and every spell works outside it." % [bc.ww_sanctum_radius, bc.ww_sanctum_duration, bc.ww_sanctum_cooldown], 13, UITheme.PARCHMENT, 1380))
	v.add_child(sanct)
	v.add_child(_wrap("ELEMENTAL INTERACTIONS (optional, through real formations): Fire on ice = Thermal Fracture (partial: fragments, full: steam that blocks sight). Stone impact on ice = Shattered Winter (directional fragments). Storm near a CONDUCTIVE Stone formation = Conductive Anchors (relay once per cast). Full Life Bloom / Verdant Renewal next to a Fortified Stone formation = Living Bastion (Vitalized: small recovery to nearby allies).", 13, UITheme.TEXT_DIM, 1400))
	v.add_child(_wrap("HEAL TARGET: T cycles you and your allies, 2 selects the most injured ally in range, no selection = yourself. A selected ally out of range is never silently swapped - the cast is refused.", 13, UITheme.TEXT_DIM, 1400))
	return sc


func _spell_lock_text(sd: ChargedSpellData) -> String:
	if sd.advanced:
		return "advanced spell (no approved unlock level - Debug grant only)"
	var lv: int = Game.track("mage").unlock_level(sd.unlock_id) if Game.track("mage") and sd.unlock_id != "" else 1
	return "Level %d" % lv
