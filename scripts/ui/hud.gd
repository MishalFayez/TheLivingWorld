class_name HUD
extends CanvasLayer
## Fantasy ARPG HUD.
##  Bottom-centre: class core widget, buffs/debuffs, HP / Stamina / Mana bars, level emblem,
##                 ability bar with icons + cooldown sweeps; thin EXP bar along the screen bottom.
##  Top-centre: boss frame (name, phase pips, HP chip bar, poise) and notification banner.
##  Left: party frames. Bottom-left: compact combat log (F2 cycles compact / expanded / hidden).
##  WorldOverlay: enemy bars, lock-on reticle, downed markers, Perfect Guard feedback.

const W := 660.0

var root: Control
var overlay: WorldOverlay
var hp_bar: FancyBar
var st_bar: FancyBar
var res_bar: FancyBar
var exp_bar: FancyBar
var emblem: Control
var class_widget: ClassWidget
var buff_row: HBoxContainer
var slot_row: HBoxContainer
var slots: Dictionary = {}
var party_box: VBoxContainer
var party_frames: Dictionary = {}
var boss_root: Control
var boss_bar: FancyBar
var boss_poise: FancyBar
var boss_name: Label
var boss_phase: Label
var banner: Control
var banner_label: Label
var banner_t: float = 0.0
var prompt: PanelContainer
var prompt_label: Label
var log_panel: PanelContainer
var log_text: RichTextLabel
var log_mode: int = 1     # 0 hidden, 1 compact, 2 expanded
var boss = null
var _built_for: Node = null
var _loadout_sig: String = ""
var cast_ring: Control
var tframe: PanelContainer
var tf_name: Label
var tf_tag: Label
var tf_hp: FancyBar
var tf_poise: FancyBar
var tf_target = null
var quest_box: PanelContainer
var quest_title: Label
var quest_prog: Label
var status_label: Label
var fps_label: Label
var _saved_t: float = 0.0
var _quest_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply(root)
	add_child(root)
	overlay = WorldOverlay.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	_build_bottom()
	_build_boss()
	_build_banner()
	_build_party()
	_build_log()
	_build_misc()
	_build_target_frame()
	CombatLog.line_added.connect(_on_log)
	Events.notify.connect(notify)
	Events.combat_notice.connect(_combat_notice)
	Events.guard_event.connect(func(d, _info, kind):
		if not is_instance_valid(d) or d.team != 0:
			return
		if kind == "perfect":
			Events.combat_notice.emit("PERFECT GUARD", d)
		elif kind == "break":
			Events.combat_notice.emit("GUARD BROKEN", d))
	Events.boss_spawned.connect(func(b): boss = b)
	Events.player_changed.connect(func(_h): _built_for = null)
	_rebuild_log()


func _ignore(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ------------------------------------------------------------------ combat notices (throttled)
var _notice_box: VBoxContainer
var _reaver_sig: String = ""
var _notice_last: Dictionary = {}
const NOTICE_THROTTLE := 1.2
const NOTICE_MAX := 3


func _combat_notice(text: String, who) -> void:
	# only the player's own events and their party (no spam from every enemy)
	if who != null and is_instance_valid(who) and "team" in who and who.team != 0 and text != "POISE BROKEN" and text != "INTERRUPTED":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_notice_last.get(text, -10.0)) < NOTICE_THROTTLE:
		return
	_notice_last[text] = now
	if _notice_box == null:
		_notice_box = VBoxContainer.new()
		_notice_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIUtil.place(_notice_box, 0.5, 0.0, 0.5, 0.0, -220, 150, 220, 270)
		add_child(_notice_box)
	while _notice_box.get_child_count() >= NOTICE_MAX:
		var old := _notice_box.get_child(0)
		_notice_box.remove_child(old)
		old.queue_free()
	var col: Color = {"PERFECT GUARD": UITheme.GOLD, "GUARD BROKEN": Color(1.0, 0.45, 0.35), "INTERRUPTED": Color(0.8, 0.7, 1.0),
		"PROTECTED": Color(0.6, 0.9, 1.0), "CLEANSED": Color(0.7, 1.0, 0.8), "POISE BROKEN": Color(1.0, 0.75, 0.4)}.get(text, UITheme.PARCHMENT)
	var l := UITheme.text(text, 22, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ construction
func _build_bottom() -> void:
	var base := Control.new()
	_ignore(base)
	UIUtil.place(base, 0.5, 1, 0.5, 1, -W * 0.5, -232, W * 0.5, -10)
	root.add_child(base)
	class_widget = ClassWidget.new()
	_ignore(class_widget)
	class_widget.position = Vector2(0, 0)
	class_widget.size = Vector2(W, 48)
	base.add_child(class_widget)
	buff_row = HBoxContainer.new()
	buff_row.position = Vector2(64, 54)
	buff_row.size = Vector2(W - 64, 26)
	buff_row.add_theme_constant_override("separation", 4)
	base.add_child(buff_row)
	emblem = Control.new()
	_ignore(emblem)
	emblem.position = Vector2(0, 80)
	emblem.size = Vector2(56, 56)
	emblem.draw.connect(_draw_emblem)
	base.add_child(emblem)
	hp_bar = FancyBar.new()
	_ignore(hp_bar)
	hp_bar.position = Vector2(64, 84)
	hp_bar.size = Vector2(W - 64, 20)
	hp_bar.fill_color = UITheme.HP
	base.add_child(hp_bar)
	st_bar = FancyBar.new()
	_ignore(st_bar)
	st_bar.position = Vector2(64, 108)
	st_bar.size = Vector2(W - 64, 8)
	st_bar.fill_color = UITheme.STAMINA
	st_bar.chip_color = Color(0.8, 1.0, 0.7, 0.5)
	st_bar.caps = false
	base.add_child(st_bar)
	res_bar = FancyBar.new()
	_ignore(res_bar)
	res_bar.position = Vector2(64, 120)
	res_bar.size = Vector2(W - 64, 10)
	res_bar.fill_color = UITheme.MANA
	res_bar.caps = false
	res_bar.font_size = 10
	base.add_child(res_bar)
	slot_row = HBoxContainer.new()
	slot_row.position = Vector2(0, 144)
	slot_row.size = Vector2(W, 58)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 8)
	base.add_child(slot_row)
	exp_bar = FancyBar.new()
	_ignore(exp_bar)
	UIUtil.place(exp_bar, 0, 1, 1, 1, 0, -5, 0, 0)
	exp_bar.fill_color = UITheme.EXP
	exp_bar.caps = false
	exp_bar.chip_color = Color(1, 1, 0.8, 0.4)
	root.add_child(exp_bar)



func _build_boss() -> void:
	boss_root = Control.new()
	_ignore(boss_root)
	UIUtil.place(boss_root, 0.5, 0, 0.5, 0, -340, 14, 340, 92)
	boss_root.visible = false
	root.add_child(boss_root)
	boss_name = UITheme.title("", 22, Color(1.0, 0.72, 0.45))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.size = Vector2(680, 30)
	boss_root.add_child(boss_name)
	var div := UITheme.divider(680)
	div.position = Vector2(0, 28)
	div.size = Vector2(680, 12)
	boss_root.add_child(div)
	boss_bar = FancyBar.new()
	_ignore(boss_bar)
	boss_bar.position = Vector2(20, 42)
	boss_bar.size = Vector2(640, 18)
	boss_bar.fill_color = Color(0.85, 0.32, 0.06)
	boss_root.add_child(boss_bar)
	boss_poise = FancyBar.new()
	_ignore(boss_poise)
	boss_poise.position = Vector2(20, 64)
	boss_poise.size = Vector2(640, 5)
	boss_poise.fill_color = UITheme.POISE
	boss_poise.caps = false
	boss_root.add_child(boss_poise)
	boss_phase = UITheme.text("", 13, UITheme.TEXT_DIM, true)
	boss_phase.position = Vector2(20, 70)
	boss_root.add_child(boss_phase)


func _build_banner() -> void:
	banner = Control.new()
	_ignore(banner)
	UIUtil.place(banner, 0.5, 0, 0.5, 0, -360, 176, 360, 236)
	banner.modulate.a = 0.0
	root.add_child(banner)
	var top := UITheme.divider(720)
	top.size = Vector2(720, 12)
	banner.add_child(top)
	banner_label = UITheme.title("", 30)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.position = Vector2(0, 10)
	banner_label.size = Vector2(720, 40)
	banner.add_child(banner_label)
	var bot := UITheme.divider(720)
	bot.position = Vector2(0, 50)
	bot.size = Vector2(720, 12)
	banner.add_child(bot)


func _build_target_frame() -> void:
	tframe = PanelContainer.new()
	tframe.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.035, 0.035, 0.82), Color(1.0, 0.45, 0.3, 0.8), 1, 4, 10.0))
	tframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIUtil.place(tframe, 0.5, 0, 0.5, 0, -190, 100, 190, 168)
	tframe.visible = false
	root.add_child(tframe)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	tframe.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	var lab := UITheme.text("TARGET", 11, Color(1.0, 0.55, 0.4), true)
	row.add_child(lab)
	tf_name = UITheme.title("", 16, Color(1.0, 0.85, 0.75))
	tf_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tf_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(tf_name)
	tf_tag = UITheme.text("", 11, UITheme.GOLD, true)
	row.add_child(tf_tag)
	tf_hp = FancyBar.new()
	tf_hp.custom_minimum_size = Vector2(350, 12)
	tf_hp.caps = false
	tf_hp.font_size = 10
	v.add_child(tf_hp)
	tf_poise = FancyBar.new()
	tf_poise.custom_minimum_size = Vector2(350, 4)
	tf_poise.caps = false
	tf_poise.fill_color = UITheme.POISE
	v.add_child(tf_poise)


func _update_target_frame(h: Hero) -> void:
	var lt = h.lock_target
	var show: bool = lt != null and is_instance_valid(lt) and lt.is_targetable() and not lt.is_boss
	tframe.visible = show
	if not show:
		tf_target = null
		return
	if tf_target != lt:
		# new target: reset bars immediately (no trail from the previous enemy)
		tf_target = lt
		tf_hp._initialized = false
		tf_poise._initialized = false
		var tw := tframe.create_tween()
		tframe.modulate = Color(1.6, 1.4, 1.2)
		tw.tween_property(tframe, "modulate", Color(1, 1, 1), 0.25)
	tf_name.text = lt.display_name.to_upper()
	var tags: Array = ["Lv %d" % lt.enemy_level()]
	if lt.is_elite:
		tags.append("ELITE")
	if lt.is_staggered():
		tags.append("STAGGERED")
	if lt.has_opening() and h.class_id == "reaver":
		tags.append("OPENING")
	for e in lt.statuses.effects:
		if tags.size() < 6:
			tags.append(String(e.display_name).to_upper())
	tf_tag.text = "  ·  ".join(tags)
	tf_hp.set_values(lt.hp, lt.max_hp)
	tf_hp.label_text = "%d / %d" % [roundi(lt.hp), roundi(lt.max_hp)]
	tf_poise.set_values(lt.poise, lt.max_poise)


func _build_party() -> void:
	party_box = VBoxContainer.new()
	UIUtil.place(party_box, 0, 0.5, 0, 0.5, 18, -120, 258, 120)
	party_box.add_theme_constant_override("separation", 8)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(party_box)


func _build_log() -> void:
	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.025, 0.025, 0.55), Color(0.4, 0.32, 0.2, 0.5), 1, 4, 8.0))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_panel)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 13)
	log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_child(log_text)
	_layout_log()


func _layout_log() -> void:
	log_panel.visible = log_mode != 0
	if log_mode == 2:
		UIUtil.place(log_panel, 0, 1, 0, 1, 14, -520, 620, -16)
	else:
		UIUtil.place(log_panel, 0, 1, 0, 1, 14, -150, 400, -16)


func _build_misc() -> void:
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.04, 0.04, 0.85), UITheme.GOLD, 1, 4, 12.0))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIUtil.place(prompt, 0.5, 1, 0.5, 1, -260, -290, 260, -254)
	prompt.visible = false
	root.add_child(prompt)
	prompt_label = UITheme.text("", 16, UITheme.PARCHMENT, true)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(prompt_label)
	var hint := UITheme.text("Tab Lock-on  ·  Wheel/Z X Switch  ·  Esc Menu  ·  C Character  ·  K Skills  ·  I Inventory  ·  M Map  ·  J Journal  ·  F1 Debug", 12, Color(0.75, 0.7, 0.62, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIUtil.place(hint, 1, 0, 1, 0, -860, 10, -16, 30)
	root.add_child(hint)
	# spell charge indicator by the reticle (small, subtle)
	cast_ring = Control.new()
	cast_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIUtil.place(cast_ring, 0.5, 0.5, 0.5, 0.5, -60, 34, 60, 94)
	cast_ring.draw.connect(_draw_cast_ring)
	root.add_child(cast_ring)
	# quest tracker (top-right)
	quest_box = PanelContainer.new()
	quest_box.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.04, 0.04, 0.6), UITheme.GOLD_DIM, 1, 4, 10.0))
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIUtil.place(quest_box, 1, 0, 1, 0, -330, 40, -16, 120)
	root.add_child(quest_box)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 2)
	quest_box.add_child(qv)
	quest_title = UITheme.text("", 15, UITheme.GOLD_BRIGHT, true)
	qv.add_child(quest_title)
	quest_prog = UITheme.text("", 13, UITheme.PARCHMENT)
	qv.add_child(quest_prog)
	# save / debug status + fps (top-left)
	status_label = UITheme.text("", 13, Color(1.0, 0.55, 0.4), true)
	UIUtil.place(status_label, 0, 0, 0, 0, 16, 10, 520, 30)
	root.add_child(status_label)
	fps_label = UITheme.text("", 12, UITheme.TEXT_DIM)
	UIUtil.place(fps_label, 0, 0, 0, 0, 16, 30, 300, 48)
	root.add_child(fps_label)
	Events.saved.connect(func(): _saved_t = 2.0)


func _make_slots(h: Hero) -> void:
	for c in slot_row.get_children():
		c.queue_free()
	slots.clear()
	var acc: Color = UITheme.CLASS_ACCENT.get(h.class_id, UITheme.GOLD)
	var defs: Array = []
	match h.class_id:
		"vanguard":
			defs = [["light", "sword", "LMB", "Light Attack (Aegis Counter in counter window)"], ["heavy", "heavy", "RMB", "Heavy Attack"],
				["guard", "guard", "SHIFT", "Aegis Guard - raise just before impact for a Perfect Guard"],
				["skill1", "shield_rush", "1", "Shield Rush"], ["skill2", "judgment", "2", "Judgment Strike (hold)"], ["skill3", "sweep", "3", "Iron Sweep"], ["dodge", "dodge", "SPACE", "Dodge"]]
		"mage":
			if Game.mage_core == "elementalist":
				var mk0: MageKit = h.kit
				defs = []
				for pair in [["light", 0, "LMB"], ["heavy", 1, "RMB"], ["skill1", 2, "1"]]:
					var sid: String = mk0.el.slot_spell(pair[1])
					var icon: String = mk0.el.spells[sid].element if sid != "" else "passive"
					var tipt: String = ("%s (hold: partial -> full)" % mk0.el.spells[sid].display_name) if sid != "" else "Empty slot - equip a spell in the Spellbook (B)"
					defs.append([pair[0], icon, pair[2], tipt])
				var uid: String = mk0.el.utility_spell()
				var uicon: String = "ward" if uid == "" or uid == "protective_renewal" else mk0.el.spells[uid].element
				defs += [["life", "life", "F", "Lifeline - instant emergency heal on your heal target"], ["core", "sigil", "E", "Arcane Sanctum"],
					["skill3", uicon, "3", (mk0.el.spells[uid].display_name + (" (hold 3 to aim)" if mk0.el.spells[uid].places_formation else "")) if uid != "" else "Utility slot (Spellbook)"], ["dodge", "dodge", "SPACE", "Dodge (cancels a charge)"]]
				_loadout_sig = str(Game.prog("mage").spell_loadout) + str(mk0.el.known_charged()) + str(mk0.el.known_utility())
			elif Game.mage_core == "weave":
				defs = [["light", "fire", "LMB", "Element slot 1 (tap quick / hold charged)"], ["heavy", "frost", "RMB", "Element slot 2"],
					["life", "life", "F", "Life (always available)"], ["core", "weave", "E", "Arcane Weave"], ["dodge", "dodge", "SPACE", "Dodge"]]
			else:
				defs = [["light", "fire", "LMB", "Element slot 1 (tap quick / hold charged)"], ["heavy", "frost", "RMB", "Element slot 2"],
					["life", "life", "F", "Life: Mend (tap) / Renewal (hold) - heals without attacking"], ["core", "sigil", "E", "Ley Sigil: inscribe the last-cast element / consume"],
					["skill3", "ward", "3", "Ward: shield the most wounded ally"], ["dodge", "dodge", "SPACE", "Dodge"]]
		"reaver":
			if Game.reaver_core == "swordmaster":
				var rk0: ReaverKit = h.kit
				defs = [["light", "sword", "LMB", "Forward Cut · Shift+A/D+LMB Lateral Cut · after a Dodge: Slip Cut"], ["heavy", "heavy", "RMB", "Heavy Cut (Lv7: hold for Draw Cut)"]]
				var icons := {"r_lunge": "lunge", "r_flow_step": "dodge", "r_crosscut": "split", "r_flurry": "flurry", "r_sunder_edge": "heavy", "r_turning_edge": "precision"}
				var keys := ["1", "2", "3", "E"]
				for i in 4:
					var act: String = ReaverSwordmaster.SLOT_ACTIONS[i]
					var sid: String = rk0.sm.slot_skill(act)
					defs.append([act, icons.get(sid, "passive"), keys[i], (Game.track("reaver").milestone(sid).get("name", sid) if sid != "" else "Empty skill slot (Skills menu, K)")])
				if rk0.unlocked("r_final_stroke"):
					defs.append(["life", "reaver", "F", "Final Stroke (only while the opportunity is open)"])
				defs.append(["dodge", "dodge", "SPACE", "Dodge"])
			elif Game.reaver_core == "sense":
				defs = [["light", "sword", "LMB", "Light combo - Tempo Cut on an Opening"], ["heavy", "heavy", "RMB", "Heavy / hold for Draw Cut - Sunder Cut on an Opening"],
					["skill1", "lunge", "1", "Piercing Lunge - Vital Cut on an Opening"], ["skill2", "flurry", "2", "Tempest Flurry"], ["dodge", "dodge", "SPACE", "Dodge - Perfect Dodge opens the attacker"]]
			else:
				defs = [["light", "sword", "LMB", "Light combo"], ["heavy", "heavy", "RMB", "Heavy / hold for Draw Cut"],
					["skill1", "split", "1", "Bladecraft: Split"], ["skill2", "focus", "2", "Bladecraft: Focus"], ["skill3", "precision", "3", "Bladecraft: Precision"], ["dodge", "dodge", "SPACE", "Dodge"]]
	for d in defs:
		var s := SkillSlot.new().setup(d[1], d[2], UITheme.PARCHMENT, acc, d[3])
		slot_row.add_child(s)
		slots[d[0]] = s


# ------------------------------------------------------------------ events
func notify(text: String) -> void:
	banner_label.text = text.to_upper()
	banner_t = 2.4
	banner.modulate.a = 0.0
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.18)


func _on_log(entry: Dictionary) -> void:
	if log_mode == 0:
		return
	_rebuild_log()


func _rebuild_log() -> void:
	log_text.clear()
	var n := 300 if log_mode == 2 else 7
	var start := maxi(0, CombatLog.lines.size() - n)
	for i in range(start, CombatLog.lines.size()):
		log_text.append_text(CombatLog.bbcode(CombatLog.lines[i]) + "\n")


func _unhandled_input(event: InputEvent) -> void:
	# clicking the game view recaptures the mouse (e.g. after alt-tab) when no menu is open
	if event is InputEventMouseButton and event.pressed and Game.ui_block == 0 \
			and DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_log"):
		log_mode = (log_mode + 1) % 3
		_layout_log()
		_rebuild_log()


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	_status(delta)
	if banner_t > 0.0:
		banner_t -= delta
		if banner_t < 0.5:
			banner.modulate.a = clampf(banner_t / 0.5, 0.0, 1.0)
	banner.visible = Game.ui_block == 0
	var h := Game.player
	if not is_instance_valid(h) or h.kit == null:
		return
	if h.class_id == "mage" and Game.mage_core == "elementalist" and _loadout_sig != str(Game.prog("mage").spell_loadout) + str(h.kit.el.known_charged()) + str(h.kit.el.known_utility()):
		_built_for = null
	if _built_for != h:
		_built_for = h
		_make_slots(h)
		class_widget.hero = h
		var acc: Color = UITheme.CLASS_ACCENT.get(h.class_id, UITheme.GOLD)
		emblem.set_meta("accent", acc)
	var p := Game.prog()
	hp_bar.set_values(h.hp, h.max_hp)
	hp_bar.label_text = "%d / %d" % [roundi(h.hp), roundi(h.max_hp)]
	st_bar.set_values(h.stamina, h.max_stamina)
	exp_bar.set_values(p.xp, maxf(1.0, p.exp_to_next(Game.balance)))
	if h.class_id == "mage":
		res_bar.visible = true
		res_bar.set_values(h.kit.resource_value(), h.kit.resource_max())
		res_bar.label_text = "MANA %d" % roundi(h.kit.resource_value())
	else:
		res_bar.visible = false
	emblem.queue_redraw()
	_update_slots(h)
	_update_buffs(h)
	_update_party()
	_update_boss()
	_update_target_frame(h)
	_update_prompt(h)


func _draw_emblem() -> void:
	var h := Game.player
	if not is_instance_valid(h):
		return
	var acc: Color = emblem.get_meta("accent", UITheme.GOLD)
	var c := emblem.size * 0.5
	emblem.draw_circle(c, 27, Color(0.04, 0.035, 0.035, 0.95))
	emblem.draw_circle(c, 23, acc.darkened(0.6))
	GameIcon.draw_icon(emblem, h.class_id, Rect2(c - Vector2(15, 17), Vector2(30, 30)), acc.lightened(0.3))
	emblem.draw_arc(c, 27, 0, TAU, 48, UITheme.GOLD, 2.0, true)
	var p := Game.prog()
	var frac := float(p.xp) / maxf(1.0, p.exp_to_next(Game.balance))
	emblem.draw_arc(c, 30, -PI / 2, -PI / 2 + TAU * frac, 48, UITheme.EXP, 2.5, true)
	var f := UITheme.title_font(true)
	var lv := str(p.level)
	var lr := Rect2(Vector2(c.x - 12, emblem.size.y - 10), Vector2(24, 16))
	emblem.draw_rect(lr, Color(0.05, 0.04, 0.03, 1.0))
	emblem.draw_rect(lr, UITheme.GOLD, false, 1.0)
	var tw := f.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	emblem.draw_string(f, Vector2(c.x - tw * 0.5, lr.position.y + 13), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.GOLD_BRIGHT)
	if p.free_points > 0:
		# unspent stat points badge (open the character sheet with C)
		var bc := Vector2(emblem.size.x - 4, 6)
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
		emblem.draw_circle(bc, 10 * pulse, Color(0.05, 0.04, 0.03))
		emblem.draw_circle(bc, 8 * pulse, UITheme.GOLD_BRIGHT)
		var pt := "+%d" % p.free_points
		var pw := f.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		emblem.draw_string(f, bc + Vector2(-pw * 0.5, 4), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.1, 0.06, 0.02))


func _update_slots(h: Hero) -> void:
	var k = h.kit
	var no_stam := h.stamina <= 1.0
	if slots.has("dodge"):
		slots.dodge.set_state(0.0, 1.0, h.dodging, no_stam)
	match h.class_id:
		"vanguard":
			var vk: VanguardKit = k
			var counter := Game.time < vk.counter_until
			slots.light.icon_id = "counter" if counter else "sword"
			slots.light.set_state(0.0, 1.0, counter, no_stam)
			slots.heavy.set_state(0.0, 1.0, Game.time < vk.reprisal_until, no_stam)
			slots.guard.set_state(0.0, 1.0, vk.guarding, false)
			var keys := ["skill1", "skill2", "skill3"]
			var unlock_ids := ["shield_rush", "judgment_strike", "iron_sweep"]
			for i in 3:
				slots[keys[i]].locked_level = _lock_lv(h, unlock_ids[i])
			for i in 3:
				var sk: SkillData = vk.skills[i]
				var c: float = vk.cd(sk.id)
				var full := sk.cooldown * (1.0 - h.stats.cdr)
				var act: bool = (i == 1 and vk.charging == "skill2") or (h.runner.is_busy() and h.runner.ctx.get("skill", "") == sk.id)
				slots[keys[i]].set_state(c, full, act, false)
		"mage":
			var mk: MageKit = k
			var p := Game.prog("mage")
			if mk.elementalist():
				var e := mk.el
				for pair in [["light", 0], ["heavy", 1], ["skill1", 2]]:
					var sid: String = e.slot_spell(pair[1])
					var s2: SkillSlot = slots[pair[0]]
					var elc: String = e.spells[sid].element if sid != "" else ""
					s2.icon_color = UITheme.ELEMENT.get(elc, UITheme.ELEMENT[""])
					var charging_this: bool = e.cur != null and e.cur_action == pair[0]
					s2.charge = e.ratio() if charging_this else -1.0
					s2.charge_full = charging_this and e.is_full()
					s2.charge_color = s2.icon_color
					s2.set_state(0.0, 1.0, charging_this, sid == "" or (sid != "" and mk.mana < e.spells[sid].mana_partial))
				slots.life.icon_color = UITheme.ELEMENT.life
				slots.life.set_state(mk.cd("lifeline"), e.spells.lifeline.cooldown, false, mk.mana < e.spells.lifeline.mana_partial or not e.heal_target_in_range())
				slots.core.icon_color = Color(1.0, 0.85, 0.5)
				slots.core.set_state(mk.cd("sanctum"), Game.balance.ww_sanctum_cooldown, e.sanctum != null, mk.mana < Game.balance.ww_sanctum_mana)
				slots.core.locked_level = _lock_lv(h, "m_sanctum")
				var u: String = e.utility_spell()
				if u == "":
					slots.skill3.icon_color = Color(0.5, 0.5, 0.5)
					slots.skill3.set_state(0.0, 1.0, false, true)
					slots.skill3.locked_level = _lock_lv(h, "m_renewal") if e.known_utility().is_empty() else 0
				else:
					var us: ChargedSpellData = e.spells[u]
					slots.skill3.icon_color = UITheme.ELEMENT.get(us.element, Color(0.75, 1.0, 0.85))
					slots.skill3.locked_level = 0
					slots.skill3.set_state(mk.cd(u), us.cooldown * (1.0 - h.stats.cdr), e.util_aiming == u, mk.mana < us.mana_partial or (us.element == "life" and not e.heal_target_in_range()))
				return
			for pair in [["light", 0], ["heavy", 1]]:
				var el: String = p.slots[pair[1]]
				var s: SkillSlot = slots[pair[0]]
				s.icon_id = el if el != "" else "passive"
				s.icon_color = UITheme.ELEMENT.get(el, UITheme.ELEMENT[""])
				s.set_state(0.0, 1.0, mk.charging == pair[0], el == "" or mk.mana < 8.0)
			slots.life.icon_color = UITheme.ELEMENT.life
			slots.life.set_state(0.0, 1.0, mk.charging == "life", mk.mana < 12.0)
			if mk.sigil_core():
				slots.core.icon_color = UITheme.ELEMENT.get(mk.last_element, Color(0.85, 0.65, 1.0))
				slots.core.set_state(0.0, 1.0, mk.sigils.size() >= mk.sigil_limit(), mk.mana < MageKit.SIGIL_MANA and mk.sigils.size() < mk.sigil_limit())
				slots.core.locked_level = _lock_lv(h, "m_sigil")
				slots.skill3.icon_color = Color(0.75, 0.95, 1.0)
				slots.skill3.set_state(mk.ward_cd, MageKit.WARD_CD, false, mk.mana < MageKit.WARD_MANA)
				slots.skill3.locked_level = _lock_lv(h, "m_ward")
			else:
				slots.core.icon_color = Color(0.85, 0.65, 1.0)
				slots.core.set_state(mk.weave_cd, Game.balance.weave_cooldown, mk.echoes.size() == 2 and mk.weave_cd <= 0.0, mk.echoes.size() < 2)
		"reaver":
			var rk: ReaverKit = k
			slots.light.set_state(0.0, 1.0, false, no_stam)
			slots.heavy.set_state(0.0, 1.0, rk.charging == "heavy", no_stam)
			if rk.sword_core():
				# minimal continuity feedback: the light slot lights up while a link window is open
				slots.light.active = rk.sm.last_line != "" and (h.runner.can_cancel() or Game.time <= rk.sm.link_until)
				for act in ReaverSwordmaster.SLOT_ACTIONS:
					if not slots.has(act):
						continue
					var sid: String = rk.sm.slot_skill(act)
					if sid == "":
						slots[act].set_state(0.0, 1.0, false, true)
					else:
						slots[act].set_state(rk.skill_cd(sid), float(ReaverKit.SKILL_CD.get(sid, 1.0)), false, no_stam)
				if slots.has("life"):
					slots.life.set_state(0.0, 1.0, rk.sm.finisher_open(), not rk.sm.finisher_open())
				var sig := str(rk.sm.loadout()) + str(rk.unlocked("r_final_stroke"))
				if sig != _reaver_sig:
					_reaver_sig = sig
					_built_for = null
				return
			if rk.sense_core():
				var lt = h.lock_target
				var opening: bool = lt != null and is_instance_valid(lt) and lt.has_method("has_opening") and lt.has_opening()
				slots.light.active = opening
				slots.heavy.active = opening or rk.charging == "heavy"
				slots.skill1.set_state(rk.skill_cd("r_lunge"), ReaverKit.SKILL_CD.r_lunge, opening, no_stam)
				slots.skill1.locked_level = _lock_lv(h, "r_lunge")
				slots.skill2.set_state(rk.skill_cd("r_flurry"), ReaverKit.SKILL_CD.r_flurry, false, no_stam)
				slots.skill2.locked_level = _lock_lv(h, "r_flurry")
				return
			var forms := ["split", "focus", "precision"]
			var keys := ["skill1", "skill2", "skill3"]
			for i in 3:
				slots[keys[i]].set_state(0.0, 1.0, rk.armed_form == forms[i], not Game.bladecraft_enabled)


## Ordered by priority (CC / danger first, then protection, buffs, secondary), then by time left.
static func sorted_statuses(list: Array) -> Array:
	var effs: Array = list.duplicate()
	effs.sort_custom(func(a, b2): return a.priority() < b2.priority() or (a.priority() == b2.priority() and a.remaining < b2.remaining))
	return effs


func _update_buffs(h: Hero) -> void:
	var effs: Array = sorted_statuses(h.statuses.effects)
	while buff_row.get_child_count() < effs.size():
		var b := StatusIcon.new()
		buff_row.add_child(b)
	for i in buff_row.get_child_count():
		var b: StatusIcon = buff_row.get_child(i)
		if i < effs.size():
			b.visible = true
			b.effect = effs[i]
			b.queue_redraw()
		else:
			b.visible = false


func _update_party() -> void:
	var seen := {}
	for o in Game.heroes:
		if not is_instance_valid(o) or o == Game.player:
			continue
		var key: int = o.get_instance_id()
		seen[key] = true
		if not party_frames.has(key):
			party_frames[key] = _make_party_frame(o)
		var fr: Dictionary = party_frames[key]
		fr.bar.set_values(o.hp, o.max_hp)
		fr.bar.label_text = "DOWNED %.0fs" % o.downed_timer if o.downed else ("respawning" if not o.visible else "%d / %d" % [roundi(o.hp), roundi(o.max_hp)])
		fr.bar.fill_color = UITheme.HP if not o.downed else Color(0.35, 0.1, 0.1)
		fr.name.text = "%s  ·  Lv %d" % [o.class_id.capitalize(), o.level]
	for key in party_frames.keys():
		if not seen.has(key):
			party_frames[key].panel.queue_free()
			party_frames.erase(key)


func _make_party_frame(o: Hero) -> Dictionary:
	var acc: Color = UITheme.CLASS_ACCENT.get(o.class_id, UITheme.GOLD)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.035, 0.035, 0.75), acc.darkened(0.3), 1, 4, 8.0))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_box.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	var ic := GameIcon.new()
	ic.icon_id = o.class_id
	ic.color = acc
	ic.custom_minimum_size = Vector2(30, 30)
	hb.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	hb.add_child(v)
	var nm := UITheme.text("", 13, acc.lightened(0.35), true)
	v.add_child(nm)
	var bar := FancyBar.new()
	bar.custom_minimum_size = Vector2(170, 12)
	bar.caps = false
	bar.font_size = 10
	v.add_child(bar)
	return {"panel": pc, "bar": bar, "name": nm}


func _update_boss() -> void:
	if boss == null or not is_instance_valid(boss) or boss.dead:
		boss_root.visible = false
		return
	boss_root.visible = true
	boss_name.text = boss.display_name.to_upper()
	boss_bar.set_values(boss.hp, boss.max_hp)
	boss_bar.label_text = "%d%%" % roundi(100.0 * boss.hp / boss.max_hp)
	boss_poise.set_values(boss.poise, boss.max_poise)
	var pips := ""
	for i in 3:
		pips += ("◆ " if i < boss.phase else "◇ ")
	boss_phase.text = "PHASE %d    %s" % [boss.phase, "STAGGERED" if boss.is_staggered() else ""]


func _update_prompt(h: Hero) -> void:
	var t := ""
	if h.downed:
		t = "DOWNED  -  %.1fs until True Death%s" % [h.downed_timer, "" if Game.party_mode else "   (no allies in Solo)"]
	else:
		for o in Game.heroes:
			if is_instance_valid(o) and o != h and o.downed and o.global_position.distance_to(h.global_position) < 2.6:
				t = "[R]  Hold to revive %s   %d%%" % [o.display_name, roundi(o.revive_progress / Game.balance.revive_time * 100)]
		if t == "" and Game.world and Game.world.has_method("nearest_interactable"):
			var it: Dictionary = Game.world.nearest_interactable(h.global_position)
			if not it.is_empty():
				t = "[G]  " + String(it.label)
	prompt.visible = t != ""
	prompt_label.text = t



## Unlock level of an ability if the hero has not learned it yet (0 = learned).
func _lock_lv(h: Hero, id: String) -> int:
	if h.unlocked(id):
		return 0
	var t := Game.track(h.class_id)
	return maxi(1, t.unlock_level(id)) if t else 0



func _draw_cast_ring() -> void:
	var h := Game.player
	if not is_instance_valid(h) or h.class_id != "mage" or not (h.kit is MageKit) or not h.kit.elementalist():
		return
	var e: MageElementalist = h.kit.el
	var c := Vector2(cast_ring.size.x * 0.5, 14)
	if e.cur != null:
		var col: Color = UITheme.ELEMENT.get(e.cur.element, Color.WHITE)
		var r := e.ratio()
		var minr := e.cur.min_charge / maxf(e.cur.full_charge, 0.01)
		cast_ring.draw_arc(c, 12, 0, TAU, 32, Color(0, 0, 0, 0.45), 4.0, true)
		cast_ring.draw_arc(c, 12, -PI / 2, -PI / 2 + TAU * r, 32, col if r < 1.0 else Color(1, 1, 1), 3.0, true)
		# tick where the minimum charge is reached
		var a := -PI / 2 + TAU * minr
		cast_ring.draw_line(c + Vector2(cos(a), sin(a)) * 8, c + Vector2(cos(a), sin(a)) * 16, UITheme.GOLD, 1.5)
		var f := UITheme.body_font(true)
		var txt := ("FULL" if e.is_full() else ("PARTIAL" if e.charge_t >= e.cur.min_charge else "...")) + "  " + e.cur.display_name
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		cast_ring.draw_string_outline(f, Vector2(c.x - tw * 0.5, c.y + 32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.8))
		cast_ring.draw_string(f, Vector2(c.x - tw * 0.5, c.y + 32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col.lightened(0.3))
	elif not e.preserved.is_empty() and Game.time < float(e.preserved.until):
		var f2 := UITheme.body_font(true)
		var t2 := "CHARGE PRESERVED - hold again"
		var tw2 := f2.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		cast_ring.draw_string(f2, Vector2(c.x - tw2 * 0.5, c.y + 4), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.GOLD_BRIGHT)


func _status(delta: float) -> void:
	cast_ring.queue_redraw()
	_saved_t = maxf(0.0, _saved_t - delta)
	if Game.test_session:
		status_label.text = "TEST SESSION  ·  progress is not saved (a newer-version save is protected)"
		status_label.modulate = Color(1, 1, 1)
	elif Game.debug_tainted:
		status_label.text = "DEBUG SESSION  ·  progress is not saved"
		status_label.modulate = Color(1, 1, 1)
	elif _saved_t > 0.0:
		status_label.text = "✓ Saved"
		status_label.modulate = Color(0.6, 1.0, 0.6, minf(1.0, _saved_t))
	else:
		status_label.text = ""
	fps_label.visible = bool(Save.settings.get("show_fps", false))
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_quest_t -= delta
	if _quest_t <= 0.0:
		_quest_t = 0.5
		var q := Quests.current()
		var in_tr: bool = is_instance_valid(Game.player) and is_instance_valid(Game.world) and Game.world.area_at(Game.player.global_position) == "training"
		quest_box.visible = not q.is_empty() and not in_tr
		if not q.is_empty():
			quest_title.text = "➤ " + q.title
			quest_prog.text = q.get("progress", "")
