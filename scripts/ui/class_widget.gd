class_name ClassWidget
extends Control
## Class-specific core display above the HUD bars.
##  Vanguard: Resolve as five diamond shards + guard / counter / reprisal states.
##  Mage: two Elemental Echo orbs fusing into the Arcane Weave preview.
##  Reaver: Bladecraft forms Split / Focus / Precision with armed timer, combo pips, OFF state.

var hero: Hero
var t: float = 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if hero == null or not is_instance_valid(hero) or hero.kit == null:
		return
	match hero.class_id:
		"vanguard":
			_draw_vanguard()
		"mage":
			_draw_mage()
		"reaver":
			_draw_reaver()


func _txt(p: Vector2, s: String, size_px: int, col: Color, title: bool = true, centered: bool = false) -> void:
	var f := UITheme.title_font(true) if title else UITheme.body_font(true)
	var x := p.x
	if centered:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	draw_string_outline(f, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(0, 0, 0, 0.85))
	draw_string(f, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _diamond(c: Vector2, rx: float, ry: float, col: Color, filled: bool = true, w: float = 1.5) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, w, true)


# ------------------------------------------------------------------ Vanguard
func _draw_vanguard() -> void:
	var k: VanguardKit = hero.kit
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 2
	var frac := k.resolve / maxf(k.b.resolve_max, 1.0)
	var n := 5
	var spacing := 34.0
	var x0 := cx - spacing * (n - 1) * 0.5
	for i in n:
		var c := Vector2(x0 + i * spacing, cy)
		var seg := clampf(frac * n - i, 0.0, 1.0)
		_diamond(c, 13, 17, Color(0.05, 0.04, 0.03, 0.9))
		if seg > 0.0:
			var col := UITheme.RESOLVE if seg >= 1.0 else UITheme.RESOLVE.darkened(0.35)
			_diamond(c + Vector2(0, 17 * (1.0 - seg) * 0.5), 13 * (0.35 + 0.65 * seg), 17 * seg, col)
			if seg >= 1.0 and frac >= 0.999:
				_diamond(c, 16 + 2 * sin(t * 5), 21 + 2 * sin(t * 5), Color(1, 0.8, 0.3, 0.35), false, 2.0)
		_diamond(c, 13, 17, UITheme.GOLD, false, 1.5)
	_txt(Vector2(x0 - 62, cy + 5), "RESOLVE", 12, UITheme.GOLD, true, true)
	_txt(Vector2(x0 + spacing * (n - 1) + 34, cy + 6), str(roundi(k.resolve)), 16, UITheme.GOLD_BRIGHT, true, true)
	# state ribbon
	var tag := ""
	var col := UITheme.PARCHMENT
	if Game.time < k.counter_until:
		tag = "COUNTER!  LMB / 2"
		col = Color(1.0, 0.85, 0.35).lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(t * 12.0))
	elif k.guarding:
		tag = "AEGIS GUARD"
		col = UITheme.CLASS_ACCENT.vanguard.lightened(0.3)
	elif Game.time < k.reprisal_until:
		tag = "IRON REPRISAL READY"
		col = UITheme.RESOLVE
	elif k.crushing_ready:
		tag = "CRUSHING RHYTHM"
		col = UITheme.RESOLVE
	if tag != "":
		_txt(Vector2(cx, cy - 24), tag, 14, col, true, true)


# ------------------------------------------------------------------ Mage
func _draw_mage() -> void:
	var k: MageKit = hero.kit
	if k.elementalist():
		_draw_elementalist(k)
		return
	if k.sigil_core():
		_draw_sigils(k)
		return
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 2
	var slots := [Vector2(cx - 70, cy), Vector2(cx - 22, cy)]
	for i in 2:
		var el: String = k.echoes[i] if i < k.echoes.size() else ""
		var col: Color = UITheme.ELEMENT.get(el, UITheme.ELEMENT[""])
		draw_circle(slots[i], 19, Color(0.04, 0.035, 0.04, 0.95))
		if el != "":
			draw_circle(slots[i], 17, col.darkened(0.55))
			draw_circle(slots[i], 17 * (0.85 + 0.05 * sin(t * 4 + i)), Color(col.r, col.g, col.b, 0.25))
			GameIcon.draw_icon(self, el, Rect2(slots[i] - Vector2(12, 12), Vector2(24, 24)), col.lightened(0.2))
		draw_arc(slots[i], 19, 0, TAU, 32, UITheme.GOLD if el != "" else UITheme.GOLD_DIM, 1.5, true)
	_txt(Vector2(cx - 46, cy + 6), "+", 16, UITheme.GOLD, true, true)
	_txt(Vector2(cx - 130, cy + 5), "ECHOES", 12, UITheme.GOLD, true, true)
	# fusion preview
	var key := k.fusion_key()
	var arrow_x := cx + 6
	draw_line(Vector2(arrow_x, cy), Vector2(arrow_x + 22, cy), UITheme.GOLD_DIM, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(arrow_x + 22, cy - 5), Vector2(arrow_x + 30, cy), Vector2(arrow_x + 22, cy + 5)]), UITheme.GOLD_DIM)
	if key != "":
		var f: FusionData = k.fusions.get(key, k.fusions.get("discord"))
		var can_weave := k.weave_cd <= 0.0 and k.mana >= (f.mana_cost if f else 0.0)
		var col := Color(0.85, 0.65, 1.0) if can_weave else UITheme.TEXT_DIM
		if can_weave:
			col = col.lerp(Color(1, 1, 1), 0.25 + 0.25 * sin(t * 6))
		_txt(Vector2(arrow_x + 38, cy + 1), (f.display_name if f else "?").to_upper(), 15, col)
		_txt(Vector2(arrow_x + 38, cy + 17), "[E] Arcane Weave" if can_weave else ("weave %.1fs" % k.weave_cd if k.weave_cd > 0 else "need mana"), 11, UITheme.TEXT_DIM, false)
	else:
		_txt(Vector2(arrow_x + 38, cy + 5), "cast spells to store Echoes", 12, UITheme.TEXT_DIM, false)


# ------------------------------------------------------------------ Reaver (Swordmaster)
## No combo meter: three small marks show the CURRENT line (left / forward / right) and glow
## gold while a link window is open. That is the only continuity feedback.
func _draw_swordmaster(k: ReaverKit) -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 2
	var sm: ReaverSwordmaster = k.sm
	var open: bool = sm.last_line != "" and (hero.runner.can_cancel() or Game.time <= sm.link_until)
	var marks := [["left", Vector2(cx - 34, cy)], ["forward", Vector2(cx, cy - 8)], ["right", Vector2(cx + 34, cy)]]
	for m in marks:
		var on: bool = sm.last_line == m[0] or (m[0] == "forward" and sm.last_line in ["slip", "heavy", "draw", "lunge", "flurry"])
		var col := (UITheme.GOLD if open else UITheme.CLASS_ACCENT.reaver) if on else Color(0.25, 0.22, 0.22)
		_diamond(m[1], 6, 8, col, on)
	_txt(Vector2(cx, cy + 22), ("LINK" if open else "BLADE LINES"), 11, UITheme.GOLD if open else Color(0.6, 0.55, 0.5), true, true)


# ------------------------------------------------------------------ Reaver
func _draw_reaver() -> void:
	var k: ReaverKit = hero.kit
	if k.flow_core():
		return      # Free Flow: no visible Flow meter, stacks or combo counter (REAVER-FREEFLOW-001)
	if k.sword_core():
		_draw_swordmaster(k)
		return
	if k.sense_core():
		_draw_sense(k)
		return
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 2
	var forms := ["split", "focus", "precision"]
	var names := ["SPLIT", "FOCUS", "PRECISION"]
	var on := Game.bladecraft_enabled
	var spacing := 96.0
	for i in 3:
		var c := Vector2(cx - spacing + i * spacing, cy)
		var armed: bool = on and k.armed_form == forms[i]
		var base := UITheme.CLASS_ACCENT.reaver if armed else (UITheme.GOLD_DIM if on else Color(0.3, 0.3, 0.3))
		_diamond(c, 17, 19, Color(0.05, 0.035, 0.035, 0.95))
		if armed:
			_diamond(c, 21 + 2 * sin(t * 8), 23 + 2 * sin(t * 8), Color(1.0, 0.4, 0.3, 0.4), true)
			_diamond(c, 17, 19, Color(0.25, 0.06, 0.05, 1.0))
			var left := clampf((k.armed_until - Game.time) / k.b.bladecraft_arm_duration, 0.0, 1.0)
			draw_arc(c, 25, -PI / 2, -PI / 2 + TAU * left, 32, UITheme.GOLD_BRIGHT, 2.0, true)
		GameIcon.draw_icon(self, forms[i], Rect2(c - Vector2(11, 11), Vector2(22, 22)), UITheme.PARCHMENT if on else Color(0.4, 0.4, 0.4))
		_diamond(c, 17, 19, base, false, 2.0 if armed else 1.3)
		_txt(Vector2(c.x, cy + 34), "%d  %s" % [i + 1, names[i]], 10, UITheme.GOLD_BRIGHT if armed else UITheme.TEXT_DIM, true, true)
	# combo pips
	for i in 4:
		var c := Vector2(cx + spacing + 48 + i * 12, cy)
		_diamond(c, 4, 5, UITheme.CLASS_ACCENT.reaver if i < k.combo else Color(0.2, 0.2, 0.2))
	_txt(Vector2(cx - spacing - 80, cy + 5), "BLADECRAFT", 12, UITheme.GOLD if on else Color(0.5, 0.5, 0.5), true, true)
	if not on:
		_txt(Vector2(cx, cy - 26), "BLADECRAFT DISABLED", 13, Color(0.75, 0.5, 0.45), true, true)
	elif Game.time < k.crescent_until:
		_txt(Vector2(cx, cy - 26), "CRESCENT FOLLOW", 13, UITheme.GOLD_BRIGHT, true, true)


# ------------------------------------------------------------------ Mage: Ley Sigils
func _draw_sigils(k: MageKit) -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 2
	var el := k.last_element
	var col: Color = UITheme.ELEMENT.get(el, UITheme.ELEMENT[""])
	# next sigil element
	var nc := Vector2(cx - 120, cy)
	draw_circle(nc, 20, Color(0.04, 0.035, 0.04, 0.95))
	draw_circle(nc, 18, col.darkened(0.6))
	GameIcon.draw_icon(self, el, Rect2(nc - Vector2(12, 12), Vector2(24, 24)), col.lightened(0.15))
	draw_arc(nc, 20, 0, TAU, 32, UITheme.GOLD, 1.5, true)
	_txt(Vector2(nc.x, cy + 34), "NEXT: " + el.to_upper(), 10, col.lightened(0.3), true, true)
	if not k.unlocked("m_sigil"):
		_txt(Vector2(cx, cy + 5), "Ley Sigils locked", 12, UITheme.TEXT_DIM, false, true)
		return
	# active sigils
	var lim := k.sigil_limit()
	for i in 2:
		var c := Vector2(cx - 40 + i * 64, cy)
		var avail := i < lim
		draw_circle(c, 22, Color(0.04, 0.035, 0.04, 0.95 if avail else 0.5))
		if i < k.sigils.size() and is_instance_valid(k.sigils[i]):
			var sg: LeySigil = k.sigils[i]
			var sc: Color = UITheme.ELEMENT.get(sg.element, Color.WHITE)
			var left := clampf(1.0 - sg.t / sg.duration, 0.0, 1.0)
			draw_circle(c, 19, sc.darkened(0.55))
			GameIcon.draw_icon(self, "sigil", Rect2(c - Vector2(15, 15), Vector2(30, 30)), sc.lightened(0.2))
			draw_arc(c, 24, -PI / 2, -PI / 2 + TAU * left, 32, sc, 2.5, true)
			_txt(Vector2(c.x, cy + 36), sg.element.to_upper(), 10, sc, true, true)
		elif avail:
			GameIcon.draw_icon(self, "sigil", Rect2(c - Vector2(13, 13), Vector2(26, 26)), Color(0.35, 0.33, 0.3))
		else:
			GameIcon.draw_icon(self, "lock", Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(0.35, 0.33, 0.3))
			_txt(Vector2(c.x, cy + 36), "LV 9", 9, UITheme.TEXT_DIM, true, true)
		draw_arc(c, 22, 0, TAU, 32, UITheme.GOLD_DIM, 1.3, true)
	var full := k.sigils.size() >= lim
	_txt(Vector2(cx + 110, cy + 1), "[E] CONSUME" if full else "[E] INSCRIBE", 13, UITheme.GOLD_BRIGHT if full else UITheme.PARCHMENT)
	_txt(Vector2(cx + 110, cy + 17), ("Resonance active" if k.unlocked("m_resonance") else "Resonance at Lv 5"), 10, UITheme.TEXT_DIM, false)
	_txt(Vector2(cx - 190, cy + 5), "LEY SIGILS", 12, UITheme.GOLD, true, true)


# ------------------------------------------------------------------ Reaver: Sword Sense
func _draw_sense(k: ReaverKit) -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 2
	var t_node = hero.lock_target
	var open := false
	var left := 0.0
	var kind := ""
	if t_node and is_instance_valid(t_node) and t_node.has_method("has_opening") and t_node.has_opening():
		open = true
		left = t_node.opening_until - Game.time
		kind = t_node.opening_kind
	# central eye / glint
	var c := Vector2(cx, cy)
	var gc := Color(1.0, 0.85, 0.45) if open else Color(0.35, 0.3, 0.28)
	if open:
		var pulse := 0.5 + 0.5 * sin(t * 14.0)
		draw_circle(c, 26 + pulse * 3, Color(1.0, 0.8, 0.4, 0.18))
	_diamond(c, 22, 22, Color(0.05, 0.035, 0.035, 0.95))
	GameIcon.draw_icon(self, "opening", Rect2(c - Vector2(16, 16), Vector2(32, 32)), gc)
	_diamond(c, 22, 22, gc, false, 2.0 if open else 1.2)
	if open:
		draw_arc(c, 30, -PI / 2, -PI / 2 + TAU * clampf(left / 1.5, 0.0, 1.0), 32, UITheme.GOLD_BRIGHT, 2.0, true)
		_txt(Vector2(cx, cy - 32), "OPENING - " + kind.to_upper(), 13, UITheme.GOLD_BRIGHT, true, true)
	elif not k.unlocked("r_openings"):
		_txt(Vector2(cx, cy - 32), "SWORD SENSE LOCKED", 12, UITheme.TEXT_DIM, true, true)
	# cut legend
	var cuts := [["LMB", "TEMPO", "light"], ["RMB", "SUNDER", "heavy"], ["1", "VITAL", "r_lunge"]]
	var xs := [cx - 150.0, cx + 150.0, cx + 270.0]
	for i in 3:
		var x: float = xs[i]
		var col := UITheme.PARCHMENT if open else UITheme.TEXT_DIM
		if i == 2 and not k.unlocked("r_lunge"):
			col = Color(0.35, 0.33, 0.3)
		_txt(Vector2(x, cy + 1), cuts[i][1] + " CUT", 12, col, true, true)
		_txt(Vector2(x, cy + 16), "[" + cuts[i][0] + "]", 10, UITheme.GOLD if open else UITheme.GOLD_DIM, false, true)
	if Game.time < k.ghost_until:
		_txt(Vector2(cx, cy + 40), "GHOST STEP READY", 11, Color(0.8, 0.85, 1.0), true, true)
	_txt(Vector2(cx - 300, cy + 5), "SWORD SENSE", 12, UITheme.GOLD, true, true)


# ------------------------------------------------------------------ Mage: Grand Elementalist
## Heal target (who will be healed, HP, range) + Arcane Sanctum state (ready / active / cooldown,
## inside or outside) + the Sanctum effect of the spell being charged.
func _draw_elementalist(k: MageKit) -> void:
	var e: MageElementalist = k.el
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 2
	# --- heal target (left)
	var ht = e.current_heal_target()
	var explicit = e.heal_target
	var hx := cx - 250
	var life_col: Color = UITheme.ELEMENT.life
	draw_circle(Vector2(hx, cy), 20, Color(0.04, 0.035, 0.04, 0.95))
	GameIcon.draw_icon(self, "life", Rect2(Vector2(hx - 12, cy - 12), Vector2(24, 24)), life_col if ht != null else Color(1.0, 0.4, 0.35))
	draw_arc(Vector2(hx, cy), 20, 0, TAU, 32, UITheme.GOLD_DIM, 1.3, true)
	var nm := ""
	var hpct := 0.0
	if ht != null:
		nm = "YOU" if ht == hero else String(ht.display_name).to_upper()
		hpct = ht.hp / ht.max_hp
		draw_arc(Vector2(hx, cy), 24, -PI / 2, -PI / 2 + TAU * hpct, 32, life_col, 2.5, true)
	elif explicit != null and is_instance_valid(explicit):
		nm = String(explicit.display_name).to_upper()
	_txt(Vector2(hx + 30, cy - 4), "HEAL  " + nm, 12, UITheme.PARCHMENT if ht != null else Color(1.0, 0.5, 0.45))
	_txt(Vector2(hx + 30, cy + 12), ("%d%%  ·  in range" % roundi(hpct * 100.0)) if ht != null else "OUT OF RANGE", 10, UITheme.TEXT_DIM if ht != null else Color(1.0, 0.5, 0.45), false)
	_txt(Vector2(hx + 30, cy + 25), "T cycle · 2 most injured", 9, UITheme.TEXT_DIM, false)
	# --- Arcane Sanctum (right)
	var sx := cx + 170
	var sc := Color(1.0, 0.85, 0.5)
	draw_circle(Vector2(sx, cy), 20, Color(0.04, 0.035, 0.04, 0.95))
	if not k.unlocked("m_sanctum"):
		GameIcon.draw_icon(self, "lock", Rect2(Vector2(sx - 9, cy - 9), Vector2(18, 18)), Color(0.4, 0.38, 0.35))
		_txt(Vector2(sx + 30, cy + 4), "ARCANE SANCTUM  ·  LV 5", 11, UITheme.TEXT_DIM)
		return
	GameIcon.draw_icon(self, "sigil", Rect2(Vector2(sx - 14, cy - 14), Vector2(28, 28)), sc)
	var state := ""
	if e.sanctum != null and is_instance_valid(e.sanctum):
		var left: float = e.sanctum.time_left()
		draw_arc(Vector2(sx, cy), 24, -PI / 2, -PI / 2 + TAU * left / e.sanctum.duration, 32, sc, 2.5, true)
		var inside := e.in_sanctum()
		state = "%s  ·  %.0fs" % ["INSIDE" if inside else "OUTSIDE", left]
		_txt(Vector2(sx + 30, cy - 4), "SANCTUM " + state, 12, UITheme.GOLD_BRIGHT if inside else UITheme.PARCHMENT)
		var hint := ""
		if e.cur != null:
			hint = {"fire": "Infernal Surge (full)", "frost": "Crystal Dominion", "stone": "Earthen Bulwark", "storm": "Conductive Path", "life": "Overflowing Grace"}.get(e.cur.element, "")
			if not inside:
				hint = "step inside for " + hint
		_txt(Vector2(sx + 30, cy + 12), hint, 10, UITheme.ELEMENT.get(e.cur.element if e.cur else "", UITheme.TEXT_DIM), false)
	elif k.cd("sanctum") > 0.0:
		_txt(Vector2(sx + 30, cy - 4), "SANCTUM  %.0fs" % k.cd("sanctum"), 12, UITheme.TEXT_DIM)
	else:
		draw_arc(Vector2(sx, cy), 24, 0, TAU, 32, sc, 1.5, true)
		_txt(Vector2(sx + 30, cy - 4), "SANCTUM READY  [E]", 12, UITheme.GOLD)
	_txt(Vector2(sx + 30, cy + 25), "", 9, UITheme.TEXT_DIM, false)
