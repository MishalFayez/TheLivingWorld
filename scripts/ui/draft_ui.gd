class_name DraftUI
extends CanvasLayer
## Augment Draft: three rarity-weighted cards from the active class's ELIGIBLE pool. Pauses the game.

var root: Control
var dim: ColorRect
var holder: VBoxContainer
var cards_box: HBoxContainer
var header: Label
var sub: Label
var is_open: bool = false
var class_id: String = ""
var current_cards: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply(root)
	root.visible = false
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.015, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	holder = VBoxContainer.new()
	holder.add_theme_constant_override("separation", 14)
	center.add_child(holder)
	header = UITheme.title("CHOOSE AN AUGMENT", 34)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(header)
	sub = UITheme.text("", 16, UITheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(sub)
	holder.add_child(UITheme.divider(1080))
	cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 26)
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(cards_box)
	Events.draft_ready.connect(func(_c): _maybe_open.call_deferred())


func _maybe_open() -> void:
	if is_open or not Game.auto_open_drafts:
		return
	if Game.prog().pending_drafts > 0 and is_instance_valid(Game.player):
		open(Game.active_class)


func open(c: String) -> void:
	class_id = c
	if not is_open:
		Game.ui_block += 1
	is_open = true
	current_cards = Game.roll_draft(c)
	get_tree().paused = true
	UIUtil.set_mouse_for_ui()
	var p := Game.prog(c)
	var tier := Game.draft_tier(c)
	header.text = {"advanced": "ADVANCED AUGMENT", "exotic": "MASTERY AUGMENT"}.get(tier, "CHOOSE AN AUGMENT")
	var total: int = Game.track(c).draft_levels.size() if Game.track(c) else 3
	sub.text = "%s  ·  Level %d  ·  Draft %d of %d  ·  %s  ·  game paused  ·  right-click a card to inspect" % [c.capitalize(), p.level, p.drafts_taken + 1, total, {"advanced": "Advanced / Exotic weighted", "exotic": "Exotic weighted"}.get(tier, "any rarity")]
	_close_inspect()
	for ch in cards_box.get_children():
		ch.queue_free()
	if current_cards.is_empty():
		var v := VBoxContainer.new()
		v.add_child(UITheme.text("No eligible augments remain for this class.", 18))
		var b := Button.new()
		b.text = "Continue"
		b.pressed.connect(func(): _pick(""))
		v.add_child(b)
		cards_box.add_child(v)
	_build_replace_row(c)
	var i := 0
	for a in current_cards:
		var card := AugmentCard.new()
		card.aug = a
		card.custom_minimum_size = Vector2(330, 480)
		card.chosen.connect(_pick)
		card.inspected.connect(_inspect)
		cards_box.add_child(card)
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(card, "modulate:a", 1.0, 0.2)
		i += 1
	root.visible = true


func _pick(id: String) -> void:
	if not is_open:
		return
	if id == "":
		Game.skip_draft(class_id)
	elif replace_id != "":
		Game.choose_augment_replacing(class_id, id, replace_id)
	else:
		Game.choose_augment(class_id, id)
	replace_id = ""
	close()


# ------------------------------------------------------------------ replacement (spec 7.4)
var replace_id: String = ""
var replace_row: VBoxContainer


## "Replace instead": choose one owned card to bench (kept owned, inactive) with the pick. Shown from the
## second draft on, only for the Level 1-10 pool. Warns when the benched card has dependent synergies.
func _build_replace_row(c: String) -> void:
	replace_id = ""
	if replace_row and is_instance_valid(replace_row):
		replace_row.queue_free()
	replace_row = null
	var p := Game.prog(c)
	if not AugmentDB.uses_l10_pool(c):
		return
	var owned: Array = []
	for id in p.augments:
		var a: AugmentData = Game.augment_db.get_augment(id)
		if a != null and a.pool == "l10" and p.augment_stacks(id) > 0 and not owned.has(id):
			owned.append(id)
	if owned.is_empty():
		return
	replace_row = VBoxContainer.new()
	replace_row.add_theme_constant_override("separation", 4)
	holder.add_child(replace_row)
	var info := UITheme.text("Build management: pick normally (adds the card), or bench one owned card with this pick (it stays owned but inactive; no extra slot).", 14, UITheme.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replace_row.add_child(info)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	replace_row.add_child(row)
	var warn := UITheme.text("", 14, Color(1.0, 0.6, 0.45))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btns: Array = []
	var none := Button.new()
	none.text = "Keep all (normal pick)"
	none.toggle_mode = true
	none.button_pressed = true
	btns.append(none)
	row.add_child(none)
	for id in owned:
		var a: AugmentData = Game.augment_db.get_augment(id)
		var b := Button.new()
		b.text = "Bench " + a.display_name
		b.toggle_mode = true
		b.set_meta("aug", id)
		btns.append(b)
		row.add_child(b)
	for b in btns:
		var bb: Button = b
		bb.pressed.connect(func():
			for o in btns:
				o.button_pressed = o == bb
			replace_id = String(bb.get_meta("aug", ""))
			var w := ""
			if replace_id != "":
				var ra: AugmentData = Game.augment_db.get_augment(replace_id)
				var deps := Game.dependents_of(c, replace_id)
				if ra.is_anchor:
					w = "%s is your PATH ANCHOR: benching it changes your build direction." % ra.display_name
				if not deps.is_empty():
					w += ("  " if w != "" else "") + "Its synergy with %s will stop working." % ", ".join(deps)
			warn.text = w)
	replace_row.add_child(warn)
	if Game.prog(class_id).pending_drafts > 0:
		_maybe_open.call_deferred()


func close() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	get_tree().paused = false
	Game.ui_block = maxi(0, Game.ui_block - 1)
	UIUtil.set_mouse_for_ui()



# ------------------------------------------------------------------ inspect
var inspect_panel: PanelContainer


func _inspect(id: String) -> void:
	_close_inspect()
	var a: AugmentData = Game.augment_db.get_augment(id)
	if a == null:
		return
	var rc: Color = UITheme.RARITY.get(a.rarity, UITheme.PARCHMENT)
	inspect_panel = PanelContainer.new()
	inspect_panel.add_theme_stylebox_override("panel", UITheme.panel(rc, 0.98))
	UIUtil.place(inspect_panel, 0.5, 1.0, 0.5, 1.0, -520, -330 if a.pool == "l10" else -250, 520, -24)
	root.add_child(inspect_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	inspect_panel.add_child(v)
	if a.pool == "l10":
		# LEVEL10-FOUNDATION-005 8.5: what changes / stays / is sacrificed, before -> after, synergy, replacement
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.custom_minimum_size = Vector2(1000, 0)
		rt.add_theme_font_size_override("normal_font_size", 15)
		rt.add_theme_color_override("default_color", UITheme.PARCHMENT)
		rt.text = AugmentText.inspect(a, class_id, Game.prog(class_id))
		v.add_child(rt)
		var cl := Button.new()
		cl.text = "Close"
		cl.focus_mode = Control.FOCUS_NONE
		cl.pressed.connect(_close_inspect)
		v.add_child(cl)
		return
	v.add_child(UITheme.title("%s  ·  %s %s" % [a.display_name, a.rarity.to_upper(), a.category.to_upper()], 20, rc.lightened(0.2)))
	var d := UITheme.text(a.description, 16)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(1000, 0)
	v.add_child(d)
	var lines: Array = []
	if not a.build_tags.is_empty():
		lines.append("Build tags: " + ", ".join(a.build_tags))
	if a.interacts_with != "":
		lines.append("Interacts with: " + a.interacts_with)
	if a.stackable:
		lines.append("Stacks up to x%d (owned x%d)" % [a.max_stacks, Game.prog(class_id).augment_stacks(a.id)])
	if not a.requires_skills.is_empty():
		lines.append("Requires: " + ", ".join(a.requires_skills))
	var params := []
	for k in a.params:
		if k != "requires_core":
			params.append("%s = %s" % [k, str(a.params[k])])
	if not params.is_empty():
		lines.append("Values: " + ",  ".join(params))
	for l in lines:
		var t := UITheme.text(l, 14, UITheme.TEXT_DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(1000, 0)
		v.add_child(t)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_inspect)
	v.add_child(close)


func _close_inspect() -> void:
	if inspect_panel and is_instance_valid(inspect_panel):
		inspect_panel.queue_free()
	inspect_panel = null
