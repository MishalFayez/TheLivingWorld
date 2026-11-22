class_name UnlockPopup
extends CanvasLayer
## "New ability" popup when a level milestone unlocks something (name, icon, description, input).
## Does not pause; queued if several unlock at once.

var queue: Array = []
var panel: PanelContainer
var t: float = 0.0
var showing: bool = false
var cur_m: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	Events.unlocks_gained.connect(func(_c, ms):
		for m in ms:
			queue.append(m))
	Events.level_up.connect(func(c, lvl):
		var tr := Game.track(c)
		if tr:
			for m in tr.unlocks_at(lvl):
				if m.kind == "stats":
					queue.append(m))


## 006 review 2: never shown while an Augment draft is open (it showed through the draft's dim layer and
## overlapped "CHOOSE AN AUGMENT" after rapid levelling). A popup already on screen steps aside and is shown
## again in full once the draft closes. Progression is unchanged: only the display is scheduled.
func _draft_open() -> bool:
	var p := get_parent()
	if p == null:
		return false
	for n in p.get_children():
		if n is DraftUI and n.is_open:
			return true
	return false


func _process(delta: float) -> void:
	if _draft_open():
		if showing:
			if is_instance_valid(panel):
				panel.queue_free()
			showing = false
			queue.push_front(cur_m)
		return
	if showing:
		t -= delta
		if t <= 0.0:
			var tw := panel.create_tween()
			tw.tween_property(panel, "modulate:a", 0.0, 0.3)
			tw.tween_callback(panel.queue_free)
			showing = false
	elif not queue.is_empty():
		_show(queue.pop_front())


func _show(m: Dictionary) -> void:
	cur_m = m
	var root := Control.new()
	panel = PanelContainer.new()
	var acc: Color = UITheme.CLASS_ACCENT.get(Game.active_class, UITheme.GOLD)
	panel.add_theme_stylebox_override("panel", UITheme.panel(acc, 0.95))
	UITheme.apply(panel)
	UIUtil.place(panel, 0.5, 0, 0.5, 0, -330, 120, 330, 250)
	add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	var ic := GameIcon.new()
	ic.icon_id = String(m.get("icon", "passive")) if String(m.get("icon", "")) != "" else "passive"
	ic.color = acc.lightened(0.2)
	ic.custom_minimum_size = Vector2(72, 72)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var head := "NEW ABILITY" if m.kind in ["skill", "mechanic"] else ("ELEMENTAL DISCOVERY" if m.kind == "element" else ("MASTERY" if m.kind == "mastery" else ("ATTRIBUTE POINTS" if m.kind == "stats" else "UNLOCKED")))
	v.add_child(UITheme.text(head + "  ·  LEVEL %d" % m.level, 13, UITheme.GOLD, true))
	var nm := String(m.name)
	if String(m.get("input", "")) != "":
		nm += "   [%s]" % m.input
	v.add_child(UITheme.title(nm, 24, UITheme.GOLD_BRIGHT))
	var d := UITheme.text(String(m.desc), 15, UITheme.PARCHMENT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(540, 0)
	v.add_child(d)
	if m.kind == "stats":
		v.add_child(UITheme.text("Press C to allocate", 13, UITheme.TEXT_DIM))
	panel.modulate.a = 0.0
	panel.position.y -= 30
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(panel, "position:y", panel.position.y + 30, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t = 4.5
	showing = true
	root.queue_free()
