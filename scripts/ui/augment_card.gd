class_name AugmentCard
extends Control
## Augment draft card: rarity frame + gem, category icon, name, build tags, description,
## interaction note. Whole card is clickable; hover lifts and glows.

signal chosen(aug_id: String)
signal inspected(id: String)

var aug: AugmentData
var hover: bool = false
var t: float = 0.0
var content: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hover = true)
	mouse_exited.connect(func(): hover = false)
	var rc: Color = UITheme.RARITY.get(aug.rarity, UITheme.PARCHMENT)
	content = VBoxContainer.new()
	content.position = Vector2(24, 104)
	content.size = Vector2(custom_minimum_size.x - 48, custom_minimum_size.y - 130)
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var n := UITheme.title(aug.display_name, 22, rc.lightened(0.15))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(n)
	var head := AugmentText.header(aug) if aug.pool == "l10" else "%s  ·  %s" % [aug.rarity.to_upper(), aug.category.capitalize()]
	var meta := UITheme.text(head + ("  ·  stacks x%d" % aug.max_stacks if aug.stackable else ""), 13, UITheme.GOLD if aug.is_anchor else UITheme.TEXT_DIM, true)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(meta)
	if not aug.build_tags.is_empty():
		var bt := UITheme.text(" · ".join(aug.build_tags), 13, UITheme.GOLD, true)
		bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(bt)
	content.add_child(UITheme.divider(content.size.x))
	var d := UITheme.text(AugmentText.describe(aug), 15, UITheme.PARCHMENT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(content.size.x, 0)
	content.add_child(d)
	# LEVEL10-FOUNDATION-005 7.2: synergy with an owned card / replacement warning, before choosing
	var p := Game.prog(aug.class_id if aug.class_id != "global" else Game.active_class)
	var syn := Game.augment_db.synergy_text(aug, p)
	if syn != "":
		var sl := UITheme.text("SYNERGY AVAILABLE  ·  " + syn, 13, Color(0.55, 0.9, 1.0), true)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(content.size.x, 0)
		content.add_child(sl)
	var rep := Game.augment_db.replaces(aug, p)
	if rep != "":
		var ra: AugmentData = Game.augment_db.get_augment(rep)
		var rl := UITheme.text("REPLACES %s (kept owned, inactive)" % (ra.display_name if ra else rep), 13, Color(1.0, 0.55, 0.45), true)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(content.size.x, 0)
		content.add_child(rl)
	if aug.interacts_with != "":
		var it := UITheme.text("Interacts: " + aug.interacts_with, 12, Color(0.6, 0.8, 1.0))
		it.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		it.custom_minimum_size = Vector2(content.size.x, 0)
		content.add_child(it)
	for c in content.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(aug.id)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		inspected.emit(aug.id)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var rc: Color = UITheme.RARITY.get(aug.rarity, UITheme.PARCHMENT)
	var lift := -8.0 if hover else 0.0
	content.position.y = 104 + lift
	var r := Rect2(Vector2(0, lift), size)
	draw_rect(Rect2(r.position + Vector2(8, 12), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, Color(0.06, 0.05, 0.05, 0.98))
	for i in 24:
		draw_rect(Rect2(r.position + Vector2(0, i * 4), Vector2(r.size.x, 4)), Color(rc.r, rc.g, rc.b, 0.16 * (1.0 - i / 24.0)))
	# outer + inner frames
	draw_rect(r, rc if hover else rc.darkened(0.3), false, 2.0)
	draw_rect(r.grow(-6), Color(UITheme.GOLD_DIM.r, UITheme.GOLD_DIM.g, UITheme.GOLD_DIM.b, 0.7), false, 1.0)
	if hover:
		draw_rect(r.grow(4 + 1.5 * sin(t * 5.0)), Color(rc.r, rc.g, rc.b, 0.4), false, 2.0)
	# category medallion
	var c := r.position + Vector2(r.size.x * 0.5, 56)
	draw_circle(c, 36, Color(0.03, 0.025, 0.03, 1))
	draw_circle(c, 31, rc.darkened(0.7))
	GameIcon.draw_icon(self, aug.category, Rect2(c - Vector2(20, 20), Vector2(40, 40)), rc.lightened(0.2))
	draw_arc(c, 36, 0, TAU, 48, UITheme.GOLD, 2.0, true)
	# rarity gems
	var gems: int = {"standard": 1, "advanced": 2, "exotic": 3}.get(aug.rarity, 1)
	for i in gems:
		var g := c + Vector2((i - (gems - 1) * 0.5) * 14.0, 44)
		draw_colored_polygon(PackedVector2Array([g + Vector2(0, -5), g + Vector2(5, 0), g + Vector2(0, 5), g + Vector2(-5, 0)]), rc)
	# corner ornaments
	for p in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end]:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), UITheme.GOLD)
	# footer
	var f := UITheme.title_font(true)
	var s := "SELECT" if hover else "click to select  ·  right-click inspect"
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(f, Vector2(r.position.x + (r.size.x - tw) * 0.5, r.end.y - 14), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.GOLD_BRIGHT if hover else UITheme.TEXT_DIM)
