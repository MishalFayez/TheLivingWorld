class_name DebugPanel
extends CanvasLayer
## F1 Debug Panel: class / level / EXP / stats / spawns / elements / augments / toggles / combat log.

var panel: PanelContainer
var tabs: TabContainer
var content: VBoxContainer
var log_view: RichTextLabel
var log_filter: String = "all"
var is_open: bool = false
var spawn_type: String = "wolf"
var spawn_elite: bool = false
var spawn_count: int = 1
var aug_box: VBoxContainer
var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.CLASS_ACCENT.vanguard.darkened(0.2), 0.95))
	UIUtil.place(panel, 1, 0, 1, 1, -600, 12, -12, -12)
	panel.visible = false
	UITheme.apply(panel)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UITheme.title("DEBUG PANEL", 20, Color(0.6, 0.8, 1.0)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.text("F1 to close", 13, UITheme.TEXT_DIM))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	Events.player_changed.connect(func(_h): _mark_dirty())
	Events.augment_added.connect(func(_c, _a): _mark_dirty())
	Events.augment_removed.connect(func(_c, _a): _mark_dirty())
	Events.element_unlocked.connect(func(_e): _mark_dirty())
	Events.level_up.connect(func(_c, _l): _mark_dirty())
	CombatLog.line_added.connect(_on_log)


func _tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	sc.add_child(box)
	return box


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty and is_open:
		_dirty = false
		_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		toggle()


func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	Game.ui_block = Game.ui_block + 1 if is_open else maxi(0, Game.ui_block - 1)
	UIUtil.set_mouse_for_ui()
	if is_open:
		_build()


func _build() -> void:
	var keep_tab := tabs.current_tab if tabs.get_tab_count() > 0 else 0
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	var p := Game.prog()
	# ================= Character
	content = _tab("Character")
	content.add_child(UIUtil.header("Class  (debug changes are never saved: %s)" % ("session TAINTED" if Game.debug_tainted else "clean so far")))
	var row := HBoxContainer.new()
	content.add_child(row)
	for c in Game.CLASSES:
		var cid: String = c
		row.add_child(UIUtil.button(("> " if cid == Game.active_class else "") + cid.capitalize(), func(): _taint_do("switch class", func(): Game.switch_class(cid))))
	content.add_child(UIUtil.header("%s  ·  %s  ·  Lv %d" % [p.character_name, Game.active_class.capitalize(), p.level]))
	var cr := HBoxContainer.new()
	content.add_child(cr)
	cr.add_child(UIUtil.button("Fresh Level 1 test character", func(): _taint_do("fresh L1", func():
		var nm := p.character_name
		var np := ClassProgress.new(Game.active_class)
		np.created = true
		np.character_name = nm
		for it in Game.starter_items(Game.active_class):
			np.equipment[it.slot] = it.id
		Game.progress[Game.active_class] = np
		Game.refresh_class_heroes(Game.active_class)
		for h in Game.heroes:
			if is_instance_valid(h):
				h.rebuild_model()
				h.restore_all())))
	cr.add_child(UIUtil.button("Rebuild model", func():
		if is_instance_valid(Game.player):
			Game.player.rebuild_model()))
	content.add_child(UIUtil.header("Give item"))
	var ir := HFlowContainer.new()
	content.add_child(ir)
	for id in Game.items:
		var it: ItemData = Game.items[id]
		if it.class_id == "" or it.class_id == Game.active_class:
			var iid: String = id
			ir.add_child(UIUtil.button(it.display_name, func(): _taint_do("give item", func(): Game.give_item(Game.active_class, iid))))
	# ================= Stats
	content = _tab("Stats")
	var st := HBoxContainer.new()
	content.add_child(st)
	st.add_child(UIUtil.button("Reset allocated stats", func(): _taint_do("reset stats", func():
		Game.prog().reset_allocation()
		Game.refresh_class_heroes(Game.active_class))))
	st.add_child(UIUtil.button("Clear debug bonuses", func(): _taint_do("clear bonuses", func():
		Game.prog().debug_bonus.clear()
		Game.refresh_class_heroes(Game.active_class))))
	content.add_child(UIUtil.header("Stat modifiers (debug bonus on top of class stats)"))
	var sg := GridContainer.new()
	sg.columns = 4
	content.add_child(sg)
	for k in ["str", "dex", "vit", "for", "mas", "crit", "critdmg", "aspd", "cdr", "armor", "mres"]:
		var key: String = k
		sg.add_child(UIUtil.label(key.to_upper()))
		var sb := SpinBox.new()
		var frac := key in ["crit", "critdmg", "aspd", "cdr"]
		sb.step = 0.05 if frac else 1.0
		sb.min_value = -1.0 if frac else -50
		sb.max_value = 5.0 if frac else 200
		sb.value = float(p.debug_bonus.get(key, 0))
		sb.value_changed.connect(func(v):
			Game.taint("stat bonus")
			Game.prog().debug_bonus[key] = v
			Game.refresh_class_heroes(Game.active_class))
		sg.add_child(sb)
	if is_instance_valid(Game.player) and Game.player.stats:
		var sm: Dictionary = Game.player.stats.summary()
		var txt := ""
		for k in sm:
			txt += "%s %.2f   " % [k, sm[k]]
		var sl := UIUtil.label(txt, 11, Color(0.75, 0.75, 0.75))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(520, 0)
		content.add_child(sl)
	# ================= Combat
	content = _tab("Combat")
	var g := GridContainer.new()
	g.columns = 2
	content.add_child(g)
	g.add_child(UIUtil.check("Invincibility", Game.invincible, func(on):
		if on:
			Game.taint("invincibility")
		Game.set_flag("invincible", on)))
	g.add_child(UIUtil.check("Permadeath", Game.permadeath, func(on): Game.set_flag("permadeath", on)))
	g.add_child(UIUtil.check("Display attack hitboxes", Game.show_hitboxes, func(on): Game.set_flag("show_hitboxes", on)))
	g.add_child(UIUtil.check("Damage numbers", Game.balance.damage_numbers, func(on): Game.balance.damage_numbers = on))
	content.add_child(UIUtil.header("Class cores (legacy cores kept for comparison)"))
	var mc := HBoxContainer.new()
	content.add_child(mc)
	mc.add_child(UIUtil.label("Mage:"))
	for c in [["elementalist", "Worldweaver (current)"], ["sigils", "Ley Sigils (retired)"], ["weave", "Arcane Weave (retired)"]]:
		var cv: String = c[0]
		mc.add_child(UIUtil.button(("> " if Game.mage_core == cv else "") + c[1], func(): _set_core("mage", cv)))
	var rc := HBoxContainer.new()
	content.add_child(rc)
	rc.add_child(UIUtil.label("Reaver:"))
	for c in [["swordmaster", "Swordmaster / Blade Lines (current)"], ["sense", "Sword Sense (retired)"], ["bladecraft", "Bladecraft (retired)"], ["off", "No core"]]:
		var cv: String = c[0]
		rc.add_child(UIUtil.button(("> " if Game.reaver_core == cv else "") + c[1], func(): _set_core("reaver", cv)))
	content.add_child(UIUtil.header("Enemy defenses (all living enemies)"))
	var ed := HBoxContainer.new()
	content.add_child(ed)
	for v in [[0.0, "0"], [0.5, "x0.5"], [1.0, "x1 (default)"], [2.0, "x2"], [4.0, "x4"]]:
		var mult: float = v[0]
		ed.add_child(UIUtil.button(v[1], func():
			for e in Game.enemies():
				e.stats.armor = e.armor * mult
				e.stats.magic_resist = e.magic_resist * mult
			Events.log_message.emit("Enemy armor / MR set to x%.1f" % mult, "system")))
	var ts := HBoxContainer.new()
	content.add_child(ts)
	ts.add_child(UIUtil.label("Time scale"))
	for v in [0.25, 0.5, 1.0, 1.5]:
		var val: float = v
		ts.add_child(UIUtil.button("x%.2f" % val, func(): Engine.time_scale = val))
	var rr := HBoxContainer.new()
	content.add_child(rr)
	rr.add_child(UIUtil.button("Restore all", func():
		for h in Game.heroes:
			if is_instance_valid(h):
				if h.downed:
					h.revive(h)
				h.restore_all()))
	rr.add_child(UIUtil.button("Kill all enemies", func():
		Game.taint("kill all")
		for e in Game.enemies():
			if e.is_targetable() and not e.is_in_group("training_dummy"):
				var info := DamageInfo.new()
				info.source = Game.player
				info.amount = 999999.0
				info.raw_amount = 999999.0
				e.take_damage(info)))
	# ================= Progression
	content = _tab("Progression")
	content.add_child(UIUtil.header("Level / EXP  (%s: Lv %d, %d/%d EXP, drafts %d taken / %d pending)" % [Game.active_class, p.level, p.xp, p.exp_to_next(Game.balance), p.drafts_taken, p.pending_drafts]))
	var lr := HBoxContainer.new()
	content.add_child(lr)
	var lvl := SpinBox.new()
	lvl.min_value = 1
	lvl.max_value = Game.balance.max_level
	lvl.value = p.level
	lr.add_child(lvl)
	lr.add_child(UIUtil.button("Set Level", func(): _taint_do("set level", func(): _set_level(int(lvl.value)))))
	for amt in [50, 250, 1000]:
		var a: int = amt
		lr.add_child(UIUtil.button("+%d EXP" % a, func(): _taint_do("exp", func(): _add_exp(a))))
	var dr := HBoxContainer.new()
	content.add_child(dr)
	dr.add_child(UIUtil.button("Open pending draft", func(): _open_draft()))
	dr.add_child(UIUtil.button("Grant extra draft", func(): _taint_do("extra draft", func(): _grant_draft())))
	content.add_child(UIUtil.header("Abilities (click: natural -> unlocked -> locked)"))
	var ur := HBoxContainer.new()
	content.add_child(ur)
	ur.add_child(UIUtil.button("Unlock all", func():
		Game.debug_unlock_all(Game.active_class, true)
		_mark_dirty()))
	ur.add_child(UIUtil.button("Clear overrides", func():
		Game.debug_unlock_all(Game.active_class, false)
		_mark_dirty()))
	var t := Game.track(Game.active_class)
	if t:
		var fl := HFlowContainer.new()
		content.add_child(fl)
		for m in t.milestones:
			if m.kind == "stats" or m.kind == "augment":
				continue
			var mid: String = m.id
			var state := "ON" if p.has_unlock(mid) else "off"
			if p.debug_unlocks.has(mid):
				state = "FORCED ON"
			elif p.debug_locks.has(mid):
				state = "FORCED OFF"
			fl.add_child(UIUtil.button("Lv%d %s [%s]" % [m.level, m.name, state], func():
				Game.debug_toggle_unlock(Game.active_class, mid)
				_mark_dirty()))
	content.add_child(UIUtil.header("Mage elements (Worldweaver: Fire + Life Lv1, Frost Lv3, Stone Lv7, Storm Lv9)"))
	var mp := Game.prog("mage")
	var er := HFlowContainer.new()
	content.add_child(er)
	for el in ["fire", "life", "frost", "stone", "storm"]:
		var e2: String = el
		var known_now: bool = mp.known_elements().has(e2)
		er.add_child(UIUtil.button("%s: %s  (%s)" % [e2.capitalize(), "KNOWN" if known_now else "-", "remove" if known_now else "grant"], func():
			Game.taint("elements")
			if mp.known_elements().has(e2):
				mp.debug_elements.erase(e2)
				if not mp.debug_locks.has("elem:" + e2):
					mp.debug_locks.append("elem:" + e2)
				if Game.mage_core != "elementalist":
					mp.lock_element(e2)
			else:
				mp.debug_locks.erase("elem:" + e2)
				if not mp.debug_elements.has(e2):
					mp.debug_elements.append(e2)
				if Game.mage_core != "elementalist":
					Game.unlock_element(e2, "Debug")
			Game.refresh_class_heroes("mage")
			_mark_dirty()))
	content.add_child(UIUtil.button("Simulate True Death", func():
		if is_instance_valid(Game.player):
			Game.player.downed = false
			Game.player.dead = true
			Game.on_hero_true_death(Game.player)
		_mark_dirty()))
	# ================= Augments
	content = _tab("Augments")
	content.add_child(UIUtil.header("Augments - %s  (Add ignores draft eligibility)" % Game.active_class.capitalize()))
	content.add_child(UIUtil.check("Auto-open drafts", Game.auto_open_drafts, func(on): Game.set_flag("auto_open_drafts", on)))
	for a in Game.augment_db.for_class(Game.active_class):
		var aug: AugmentData = a
		var owned := p.augment_stacks(aug.id)
		var reason := Game.augment_db.ineligible_reason(aug, p)
		var ar := HBoxContainer.new()
		content.add_child(ar)
		var lab := UIUtil.label("%s%s [%s/%s]%s" % [aug.display_name, "  x%d" % owned if owned > 0 else "", aug.rarity, aug.category, "" if reason == "" else "  (draft: %s)" % reason], 13, Color(0.6, 1.0, 0.6) if owned > 0 else Color(0.85, 0.85, 0.85))
		lab.custom_minimum_size = Vector2(380, 0)
		lab.tooltip_text = aug.description
		lab.mouse_filter = Control.MOUSE_FILTER_PASS
		ar.add_child(lab)
		var aid := aug.id
		ar.add_child(UIUtil.button("Add", func(): _taint_do("augment", func(): Game.add_augment(Game.active_class, aid))))
		ar.add_child(UIUtil.button("Remove", func(): _taint_do("augment", func(): Game.remove_augment(Game.active_class, aid))))
	# ================= Spawning
	content = _tab("Spawning")
	var sr := HBoxContainer.new()
	content.add_child(sr)
	var ob := OptionButton.new()
	var types := ["wolf", "raider", "shield_guardian", "ash_caster", "training_dummy"]
	for ty in types:
		ob.add_item(ty)
	ob.selected = maxi(0, types.find(spawn_type))
	ob.item_selected.connect(func(i): spawn_type = types[i])
	sr.add_child(ob)
	sr.add_child(UIUtil.check("Elite", spawn_elite, func(on): spawn_elite = on))
	var cnt := SpinBox.new()
	cnt.min_value = 1
	cnt.max_value = 10
	cnt.value = spawn_count
	cnt.value_changed.connect(func(v): spawn_count = int(v))
	sr.add_child(cnt)
	sr.add_child(UIUtil.button("Spawn", func(): _spawn(spawn_type, spawn_count, spawn_elite)))
	sr.add_child(UIUtil.button("Spawn Boss", func(): _spawn("ashen_warden", 1, false)))
	var tp := HBoxContainer.new()
	content.add_child(tp)
	tp.add_child(UIUtil.label("Teleport:"))
	for a in ["outskirts", "ruins", "keep", "boss", "training"]:
		var area: String = a
		tp.add_child(UIUtil.button(area.capitalize(), func(): Game.world.teleport_player(area)))
	# ================= AI
	content = _tab("AI")
	content.add_child(UIUtil.check("AI Companions (Party Test)", Game.party_mode, func(on): Game.set_party_mode(on)))
	content.add_child(UIUtil.label("Companions mirror the player's level with auto-allocated stats and starter gear;\nthey never write to saved characters.", 12, UITheme.TEXT_DIM))
	content.add_child(UIUtil.button("Freeze / unfreeze enemy AI", func():
		for e in Game.enemies():
			e.sm.set_physics_process(not e.sm.is_physics_processing())))
	# ================= Testing
	content = _tab("Testing")
	content.add_child(UIUtil.header("Training / performance comparison"))
	var tr := HBoxContainer.new()
	content.add_child(tr)
	tr.add_child(UIUtil.button("Go to Training Grounds", func(): Game.world.teleport_player("training")))
	tr.add_child(UIUtil.button("Reset training stats", func(): Training.reset()))
	tr.add_child(UIUtil.button("Save baseline", func(): Training.save_baseline()))
	var cmp := ""
	for r in Training.comparison():
		cmp += "%s: %s  (baseline %s)  %s\n" % [r[0], str(r[1]), str(r[2]), r[3]]
	content.add_child(UIUtil.label("Current vs baseline:\n" + cmp + "\nTypical use: Save baseline -> change a stat / augment / core / enemy defense -> hit the dummy again.", 12))
	_worldweaver_tools(content)
	# ================= Class Experience Lab
	content = _tab("Lab")
	ClassLab.build(self, content)
	# ================= Log
	content = _tab("Log")
	var fr := HBoxContainer.new()
	content.add_child(fr)
	var cats := ["all", "damage", "crit", "guard", "heal", "fusion", "augment", "status", "death", "exp", "system"]
	var fo := OptionButton.new()
	for c in cats:
		fo.add_item(c)
	fo.selected = cats.find(log_filter)
	fo.item_selected.connect(func(i): _set_filter(cats[i]))
	fr.add_child(fo)
	fr.add_child(UIUtil.button("Clear", func(): _clear_log()))
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.custom_minimum_size = Vector2(540, 600)
	log_view.add_theme_font_size_override("normal_font_size", 11)
	content.add_child(log_view)
	_refill_log()
	tabs.current_tab = clampi(keep_tab, 0, tabs.get_tab_count() - 1)


## Worldweaver Mage test tools (spec section 19). Every change here taints the session, so the
## stored character is never overwritten by Debug testing.
func _worldweaver_tools(content: VBoxContainer) -> void:
	content.add_child(UIUtil.header("Mage - Worldweaver testing"))
	var mk = Game.player.kit if is_instance_valid(Game.player) and Game.player.kit is MageKit else null
	var mt := HFlowContainer.new()
	content.add_child(mt)
	mt.add_child(UIUtil.button("Fresh Level 1 Mage (session only)", func(): _taint_do("mage_reset", func():
		var mp: ClassProgress = Game.prog("mage")
		Game.set_level("mage", 1)
		mp.debug_unlocks.clear()
		mp.debug_locks.clear()
		mp.debug_elements.clear()
		mp.augments.clear()
		mp.reset_allocation()
		mp.spell_loadout = ["flame_cataclysm", "life_bloom", "", ""]
		Game.refresh_class_heroes("mage"))))
	mt.add_child(UIUtil.button("Refill mana + reset cooldowns", func():
		for hh in Game.heroes:
			if is_instance_valid(hh) and hh.kit is MageKit:
				hh.kit.mana = Game.balance.mana_max
				hh.kit.cooldowns.clear()))
	mt.add_child(UIUtil.button("Wound allies (healing test)", func():
		for hh in Game.heroes:
			if is_instance_valid(hh) and not hh.downed:
				hh.hp = hh.max_hp * 0.35))
	mt.add_child(UIUtil.button("Wound self only (no enemies needed)", func():
		if is_instance_valid(Game.player):
			Game.player.hp = Game.player.max_hp * 0.3))
	for pair in [["Wolf pack", "wolf", 3], ["Raiders", "raider", 3], ["Shield Guardian", "shield_guardian", 1], ["Ash Casters", "ash_caster", 3], ["Training dummy", "dummy", 1]]:
		var pp: Array = pair
		mt.add_child(UIUtil.button("Spawn " + pp[0], func():
			if pp[1] == "dummy":
				Game.world.teleport_player("training")
			else:
				_spawn(pp[1], pp[2], false)))
	if mk == null or not mk.elementalist():
		content.add_child(UIUtil.label("Play the Mage (Worldweaver core) for spell, formation and interaction tools.", 12))
		return
	var el: MageElementalist = mk.el
	var mp2: ClassProgress = Game.prog("mage")
	content.add_child(UIUtil.label("Spells (grant / remove). Advanced spells have no level in the approved table: Debug grant only.", 12))
	var sg := HFlowContainer.new()
	content.add_child(sg)
	var all_ids: Array = MageElementalist.CHARGED_ORDER + MageElementalist.UTILITY_ORDER + ["lifeline", MageElementalist.BLOOM_MODES_ID]
	for id in all_ids:
		var sid: String = id
		var nm: String = el.spells[sid].display_name if el.spells.has(sid) else "Focused / Shared Bloom"
		var known_now: bool = el.bloom_modes_known() if sid == MageElementalist.BLOOM_MODES_ID else el.spell_known(sid)
		sg.add_child(UIUtil.button("%s %s" % ["[x]" if known_now else "[ ]", nm], func(): _taint_do("spells", func():
			var k := "spell:" + sid
			if known_now:
				mp2.debug_unlocks.erase(k)
				if not mp2.debug_locks.has(k):
					mp2.debug_locks.append(k)
			else:
				mp2.debug_locks.erase(k)
				if not mp2.debug_unlocks.has(k):
					mp2.debug_unlocks.append(k))))
	var st := HFlowContainer.new()
	content.add_child(st)
	st.add_child(UIUtil.check("Arcane Sanctum enabled (force unlock)", mk.unlocked("m_sanctum"), func(on): _taint_do("sanctum", func():
		var lk: Array = mp2.debug_locks
		var ul: Array = mp2.debug_unlocks
		if on:
			lk.erase("m_sanctum")
			if not ul.has("m_sanctum"):
				ul.append("m_sanctum")
		else:
			ul.erase("m_sanctum")
			if not lk.has("m_sanctum"):
				lk.append("m_sanctum")
			if el.sanctum and is_instance_valid(el.sanctum):
				el.sanctum.queue_free())))
	st.add_child(UIUtil.button("Summon Sanctum now", func():
		mk.cooldowns.erase("sanctum")
		mk.mana = Game.balance.mana_max
		el.cast_sanctum()))
	st.add_child(UIUtil.check("New Stone formations are Conductive (NO approved source - test only)", el.conductive_debug, func(on): _taint_do("conductive", func(): el.conductive_debug = on)))
	st.add_child(UIUtil.button("Make existing Stone formations Conductive", func(): _taint_do("conductive", func():
		for f in WorldFormation.active():
			if f.element == "stone":
				f.set_state("conductive"))))
	st.add_child(UIUtil.button("Clear my formations", func():
		el.clear_world()
		_mark_dirty()))
	content.add_child(UIUtil.header("Formation inspector (%d solid owned, %d fire areas, %d steam)" % [el.solid_count(), el.fire_zones.size(), SteamCloud.count()]))
	var ftxt := ""
	for f in WorldFormation.active():
		ftxt += ("[mine] " if f.mage == Game.player else "") + f.describe() + "\n"
	content.add_child(UIUtil.label(ftxt if ftxt != "" else "(no active formations)", 11))
	content.add_child(UIUtil.header("Elemental interactions (latest first)"))
	var itxt := ""
	for i in range(el.interactions.size() - 1, maxi(-1, el.interactions.size() - 13), -1):
		var it: Dictionary = el.interactions[i]
		itxt += "%.1fs  %s  -  %s\n" % [it.time, String(it.id).replace("_", " ").capitalize(), it.detail]
	content.add_child(UIUtil.label(itxt if itxt != "" else "(none yet)", 11))
	var last: Dictionary = el.last_release
	if not last.is_empty():
		content.add_child(UIUtil.label("Last release: %s  (%s)%s" % [last.spell, "FULL" if last.full else "partial", "  in Sanctum" if last.get("sanctum", false) else ""], 12))
	content.add_child(UIUtil.button("Refresh", func(): _mark_dirty()))


func _taint_do(reason: String, fn: Callable) -> void:
	Game.taint(reason)
	fn.call()
	_mark_dirty()


func _set_core(cls_id: String, core: String) -> void:
	Game.set_core(cls_id, core)
	_mark_dirty()


func _refill_log() -> void:
	if log_view == null or not is_instance_valid(log_view):
		return
	log_view.clear()
	for e in CombatLog.lines:
		if log_filter == "all" or e.cat == log_filter:
			log_view.append_text(CombatLog.bbcode(e) + "\n")


func _on_log(entry: Dictionary) -> void:
	if is_open and log_view and is_instance_valid(log_view) and (log_filter == "all" or entry.cat == log_filter):
		log_view.append_text(CombatLog.bbcode(entry) + "\n")


func _open_draft() -> void:
	var d := get_parent().get_node_or_null("DraftUI")
	if d and Game.prog().pending_drafts > 0:
		d.open(Game.active_class)


func _spawn(type: String, count: int, elite: bool) -> void:
	if not is_instance_valid(Game.player):
		return
	var base := Game.player.global_position + Game.player.forward() * 7.0
	for i in count:
		var off := Vector3(randf_range(-3, 3), 0.3, randf_range(-3, 3))
		var e := Game.spawn_enemy(type, base + off, Game.current_area_key(), elite)
		if e:
			e.update_target(0.0)
	Events.log_message.emit("Debug spawned %d x %s%s" % [count, type, " (elite)" if elite else ""], "system")


func _set_level(l: int) -> void:
	Game.set_level(Game.active_class, l)
	_mark_dirty()


func _add_exp(a: int) -> void:
	Game.gain_exp(a, "Debug")
	_mark_dirty()


func _grant_draft() -> void:
	Game.prog().pending_drafts += 1
	_open_draft()


func _set_filter(f: String) -> void:
	log_filter = f
	_refill_log()


func _clear_log() -> void:
	CombatLog.clear()
	_refill_log()
