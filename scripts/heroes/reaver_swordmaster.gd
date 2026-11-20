class_name ReaverSwordmaster
extends RefCounted
## REAVER — THE SWORDMASTER (refoundation spec 7 + design resolution).
## Pure physical swordplay: no magic, no teleport, no clones, no wound meters, no combo damage multiplier.
##
##   LMB                          Forward Cut   ALWAYS, whatever the movement direction
##   Shift + A / D + LMB          Lateral Cut   wide short arc to that side + bounded 0.6m side step
##   RMB                          Heavy Cut     (Lv7: HOLD = Draw Cut)
##   Dodge -> LMB (0.35s)         Slip Cut
##   1 / 2 / 3 / E                skill slots (loadout, Skills menu K): Piercing Lunge (Lv3), Flow Step
##                                (Lv5), Crosscut (Lv7), Tempest Flurry (Lv9), Sunder Edge (Lv12),
##                                Turning Edge (Lv15, A / D chooses the side)
##   F                            Final Stroke (Lv18) - only while a finisher opportunity is open
##
## The attack line is captured when the input is ACCEPTED (also for buffered presses) and never
## changes during the animation.
## Blade Continuity: a DIFFERENT attack started in the previous attack's cancel window (or within
## LINK_GRACE after it) is a LINK: faster start, keeps tracking, can open Final Stroke. Repeating the
## same attack is allowed but is never a link. Lateral left <-> right reversal is illegal (Crosswind /
## Discipline). Flow Step in a link window keeps the sequence alive (expanded continuity, Lv5).

const LINK_GRACE := 0.3
const SLIP_WINDOW := 0.35
const LATERAL_STEP_SPEED := 4.6    ## ~0.6m with the 18 m/s^2 knockback decay (collision-safe move_and_slide)
const FLOW_STEP_SPEED := 5.0       ## ~0.7m
const TURNING_STEP_SPEED := 5.0    ## ~0.7m
const LINK_STARTUP_MULT := 0.75
const FINISHER_WINDOW := 1.5
const FLANK_ANGLE := 60.0
const SLOT_ACTIONS := ["skill1", "skill2", "skill3", "core"]
const SKILL_ATTACK := {"r_lunge": "r_lunge", "r_flurry": "r_flurry", "r_crosscut": "rs_crosscut", "r_sunder_edge": "rs_sunder_edge", "r_turning_edge": "rs_turning_edge"}
const SKILL_LINE := {"r_lunge": "lunge", "r_flurry": "flurry", "r_crosscut": "crosscut", "r_sunder_edge": "sunder", "r_turning_edge": "turning"}
const SKILL_ORDER := ["r_lunge", "r_flow_step", "r_crosscut", "r_flurry", "r_sunder_edge", "r_turning_edge"]

var kit
var hero
var last_line: String = ""
var link_until: float = -10.0
var prev_connected: bool = false       # the previous attack of the sequence landed a hit
var discipline_used: bool = false
var turning_dir: Vector3 = Vector3.ZERO
var measured_until: float = -10.0
var finisher_until: float = -10.0
var finisher_reason: String = ""
var links: int = 0
var invalid_links: int = 0
var repeats: int = 0
var last_feedback: String = ""
var pending_dir: String = ""
var pending_t: float = -10.0
var ai_lateral: String = ""           # AI: "left" / "right" requested for its next LMB


func _init(p_kit) -> void:
	kit = p_kit
	hero = p_kit.hero


func process(_delta: float) -> void:
	refresh_loadout()
	if Game.time > link_until and not hero.runner.is_busy():
		if last_line != "":
			discipline_used = false
		last_line = ""
		prev_connected = false


# ------------------------------------------------------------------ loadout
func loadout() -> Array:
	var p: ClassProgress = hero.prog()
	while p.reaver_loadout.size() < 4:
		p.reaver_loadout.append("")
	return p.reaver_loadout


## New skills fill the first empty slot so they are usable at once.
func refresh_loadout() -> void:
	var lo := loadout()
	for id in SKILL_ORDER:
		if kit.unlocked(id) and not lo.has(id):
			var i := lo.find("")
			if i >= 0:
				lo[i] = id
	for i in lo.size():
		if lo[i] != "" and not kit.unlocked(lo[i]):
			lo[i] = ""


func slot_skill(action: String) -> String:
	var i := SLOT_ACTIONS.find(action)
	if i < 0:
		return ""
	refresh_loadout()
	return String(loadout()[i])


func equip(i: int, id: String) -> void:
	var lo := loadout()
	if id != "":
		for k in lo.size():
			if lo[k] == id:
				lo[k] = ""
	lo[i] = id


# ------------------------------------------------------------------ input
func on_press(action: String) -> void:
	match action:
		"light":
			if kit.charging != "":
				return
			var dir := read_direction()
			if not hero.can_act():
				hero.buffer(action)
				pending_dir = dir           # captured when the input is accepted
				pending_t = Game.time
				return
			_blade_line(dir)
		"heavy":
			if kit.charging != "":
				return
			if not hero.can_act():
				hero.buffer(action)
				return
			if kit.unlocked("r_draw"):
				kit.begin_charge("heavy", kit.load_attack("rs_draw").charge_time)
				if not hero.is_held("heavy"):
					on_release("heavy")
			else:
				_start("rs_heavy", "heavy")
		"skill1", "skill2", "skill3", "core":
			var id := slot_skill(action)
			if id == "":
				if hero.is_player:
					Events.notify.emit("No skill in this slot (Skills menu, K)")
				return
			use_skill(id, action)
		"life":
			final_stroke()


func on_release(action: String) -> void:
	if action != "heavy" or kit.charging != "heavy":
		return
	var charged: bool = kit.charge_t >= Game.balance.charge_min
	var ratio: float = kit.charge_ratio()
	kit.cancel_charge()
	if charged:
		var d: AttackData = kit.apply_charge(kit.load_attack("rs_draw"), ratio)
		if kit.aug("drawn_horizon") > 0:
			d.hitbox_size.z *= float(kit.ap("drawn_horizon", "length_mult", 1.6))
			d.hitbox_size.x *= float(kit.ap("drawn_horizon", "width_mult", 0.55))
			d.hitbox_offset.z = -0.4 - d.hitbox_size.z * 0.5
			d.display_name = "Drawn Horizon"
			kit.trigger("drawn_horizon", "Draw Cut became a long narrow line (%.1fm)" % d.hitbox_size.z)
		_go(d, "draw")
	else:
		_start("rs_heavy", "heavy")


## LMB = forward. Only the deliberate modifier (Shift, "blade_modifier") + A / D selects a lateral cut.
func read_direction() -> String:
	if not hero.is_player and ai_lateral != "":
		var l := ai_lateral
		ai_lateral = ""
		return l
	if hero.is_held("blade_modifier") and absf(hero.strafe_axis) >= 0.5:
		return "right" if hero.strafe_axis > 0.0 else "left"
	return "forward"


func _blade_line(dir: String) -> void:
	if Game.time - pending_t <= Game.balance.input_buffer + 0.05:
		dir = pending_dir
	pending_t = -10.0
	if Game.time - hero.last_dodge_end < SLIP_WINDOW and last_line != "slip" and dir == "forward":
		_start("rs_slip", "slip")
		return
	match dir:
		"left":
			_start("rs_lateral_l", "left")
		"right":
			_start("rs_lateral_r", "right")
		_:
			_start("rs_forward", "forward")


func use_skill(id: String, action: String) -> void:
	if not kit.unlocked(id):
		kit.locked_msg(id)
		return
	if kit.cooldowns.get(id, 0.0) > 0.0:
		if hero.is_player:
			Events.notify.emit("On cooldown (%.1fs)" % kit.cooldowns[id])
		return
	if id == "r_flow_step":
		flow_step()
		return
	if not hero.can_act():
		hero.buffer(action)
		pending_dir = read_direction()
		pending_t = Game.time
		return
	var d: AttackData = kit.load_attack(SKILL_ATTACK[id]).clone()
	if hero.stamina < d.stamina_cost * 0.5:
		if hero.is_player:
			Events.notify.emit("Not enough stamina")
		return
	if id == "r_lunge" and kit.aug("needlepoint") > 0:
		d.hitbox_size.x *= float(kit.ap("needlepoint", "width_mult", 0.6))
		d.crit_chance_bonus += float(kit.ap("needlepoint", "crit", 0.2))
		d.poise_damage *= float(kit.ap("needlepoint", "poise_mult", 1.3))
		d.display_name = "Needlepoint Lunge"
		kit.trigger("needlepoint", "Narrow precise Lunge")
	if d.hits >= 3 and kit.aug("flowing_edge") > 0:
		d.move_during = float(kit.ap("flowing_edge", "move_fraction", 0.55))
		kit.trigger("flowing_edge", "Movement allowed during %s" % d.display_name)
	var side := ""
	if id == "r_turning_edge":
		# direction chosen intentionally when activated (A / D); no direction = no Turning Edge
		var ax: float = hero.strafe_axis
		if not hero.is_player and ai_lateral != "":
			ax = 1.0 if ai_lateral == "right" else -1.0
			ai_lateral = ""
		if absf(ax) < 0.5:
			if hero.is_player:
				Events.notify.emit("Turning Edge: hold A or D to choose the side")
			return
		side = "right" if ax > 0.0 else "left"
	kit.cooldowns[id] = float(kit.SKILL_CD.get(id, 5.0))
	_go(d, SKILL_LINE[id], side)


func _start(id: String, line: String) -> void:
	_go(kit.load_attack(id).clone(), line)


func _target_facing() -> Vector3:
	var t = hero.lock_target
	if t != null and is_instance_valid(t) and t.is_targetable():
		var f: Vector3 = t.global_position - hero.global_position
		f.y = 0
		if f.length() > 0.05:
			return f.normalized()
	return hero.forward()


## Blade Continuity gate + start.
func _go(d: AttackData, line: String, side: String = "") -> void:
	var linking: bool = (hero.runner.is_busy() and hero.runner.can_cancel()) or Game.time <= link_until
	if hero.runner.is_busy() and hero.runner.data and hero.runner.data.has_tag("step"):
		linking = Game.time <= link_until
	var legal := true
	var used_discipline := false
	if linking and last_line in ["left", "right"] and line in ["left", "right"] and line != last_line:
		legal = false
		if kit.aug("crosswind") > 0:
			legal = true
			kit.trigger("crosswind", "Opposite-direction linked cut")
		elif kit.unlocked("r_discipline") and not discipline_used:
			legal = true
			used_discipline = true
	if linking and not legal:
		invalid_links += 1
		last_feedback = "no link: %s -> %s" % [last_line, line]
		if hero.is_player:
			FX.number(hero, "NO LINK", Color(0.75, 0.75, 0.8), 0.6)
		Events.blade_transition.emit(hero, last_line, line, false)
		hero.buffer_action = ""
		return
	# a LINK needs a DIFFERENT attack; repeating the same cut is allowed but gets no transition benefit
	var meaningful: bool = linking and last_line != "" and line != last_line
	if linking and last_line != "" and line == last_line:
		repeats += 1
	var was_connected: bool = prev_connected
	if hero.runner.is_busy() and hero.runner.data and not hero.runner.data.has_tag("step"):
		was_connected = hero.runner.connected_hits() > 0
	var facing := _target_facing()
	if meaningful:
		d.startup *= LINK_STARTUP_MULT
		links += 1
		last_feedback = "linked: %s -> %s" % [last_line, line]
		if used_discipline:
			discipline_used = true
			kit.trigger("r_discipline", "Swordmaster's Discipline: extra directional transition")
		Events.blade_transition.emit(hero, last_line, line, true)
		if hero.is_player:
			VFX.opening_glint(hero.global_position + Vector3(0, 1.3, 0) + hero.forward() * 0.6)
	var ctx := {"kind": "heavy" if d.is_heavy else "light", "line": line, "linked": meaningful, "prev_connected": was_connected, "transforms": [], "form": ""}
	hero.runner.interrupt()
	if not kit.start_attack(d, ctx):
		return
	if line in ["left", "right"] or line == "turning":
		# the input chooses the cut (or the step side), not a turn: keep the target line
		hero.attack_turn_dir = facing
		var right: Vector3 = facing.cross(Vector3.UP).normalized()
		var s := line if line != "turning" else side
		var spd := LATERAL_STEP_SPEED if line != "turning" else TURNING_STEP_SPEED
		hero.knock_velocity += right * (spd if s == "right" else -spd)
		turning_dir = Vector3.ZERO
		if line != "turning" and kit.aug("turning_steel") > 0:
			turning_dir = right if line == "right" else -right
	elif turning_dir != Vector3.ZERO and meaningful and hero.move_input.length() > 0.3:
		hero.attack_turn_dir = hero.move_input
		kit.trigger("turning_steel", "Attack redirected after footwork")
		turning_dir = Vector3.ZERO
	if line == "final":
		# Final Stroke ends the current Blade Continuity sequence
		last_line = ""
		link_until = -10.0
		prev_connected = false
		return
	last_line = line
	link_until = -10.0


# ------------------------------------------------------------------ Flow Step
## Short directional step (0.7m, stamina, cooldown, NO invulnerability, collides with enemies and
## walls). From neutral, or in a link window: then the sequence stays open for the next cut.
func flow_step() -> bool:
	var st: float = kit.load_attack("rs_flow_step").stamina_cost
	if hero.stamina < st:
		if hero.is_player:
			Events.notify.emit("Not enough stamina")
		return false
	var in_window: bool = hero.runner.is_busy() and hero.runner.can_cancel()
	if hero.runner.is_busy() and not in_window:
		return false
	if hero.dodging or hero.stagger_timer > 0.0 or hero.downed:
		return false
	var keep_line := last_line
	var keep_connected: bool = prev_connected
	if hero.runner.is_busy():
		keep_connected = hero.runner.connected_hits() > 0
	var dir: Vector3 = hero.move_input
	dir.y = 0
	if dir.length() < 0.2:
		dir = -hero.forward()
	dir = dir.normalized()
	hero.runner.interrupt()
	var d: AttackData = kit.load_attack("rs_flow_step")
	kit.start_attack(d, {"line": "step", "step": true})
	hero.attack_turn_dir = _target_facing()
	hero.knock_velocity += dir * FLOW_STEP_SPEED
	kit.cooldowns["r_flow_step"] = float(kit.SKILL_CD.get("r_flow_step", 3.0))
	# expanded continuity (Lv5): a step taken from a link window keeps the sequence for the next cut
	if keep_line != "" and (in_window or Game.time <= link_until):
		last_line = keep_line
		prev_connected = keep_connected
		link_until = Game.time + d.total_time() + LINK_GRACE
	Events.blade_transition.emit(hero, keep_line, "step", keep_line != "")
	return true


# ------------------------------------------------------------------ Final Stroke
func open_finisher(reason: String) -> void:
	if not kit.unlocked("r_final_stroke"):
		return
	finisher_until = Game.time + FINISHER_WINDOW
	finisher_reason = reason
	kit.trigger("r_final_stroke", "Final Stroke opportunity: " + reason)
	if hero.is_player:
		FX.number(hero, "FINAL STROKE", Color(1.0, 0.86, 0.45), 0.8)


func finisher_open() -> bool:
	return Game.time < finisher_until


func final_stroke() -> bool:
	if not kit.unlocked("r_final_stroke"):
		kit.locked_msg("r_final_stroke")
		return false
	if not finisher_open():
		if hero.is_player:
			Events.notify.emit("Final Stroke needs an opportunity (linked hits, Sunder Edge break, or a flank hit)")
		return false
	if not hero.can_act():
		hero.buffer("life")
		return false
	var d: AttackData = kit.load_attack("rs_final_stroke").clone()
	if hero.stamina < d.stamina_cost:
		if hero.is_player:
			Events.notify.emit("Not enough stamina")
		return false
	finisher_until = -10.0
	_go(d, "final")
	return true


func on_attack_finished(d: AttackData, ctx: Dictionary, interrupted: bool) -> void:
	if d != null and d.has_tag("step"):
		return
	if not interrupted:
		link_until = Game.time + LINK_GRACE
		prev_connected = hero.runner.connected_hits() > 0
	# Sunder Edge: meaningful miss recovery
	if d != null and d.has_tag("sunder") and not interrupted and hero.runner.connected_hits() == 0:
		var r := AttackData.new()
		r.id = "sunder_miss"
		r.display_name = "Sunder Edge (missed)"
		r.anim_style = "slash_v"
		r.startup = 0.01
		r.active = 0.01
		r.recovery = 0.35
		r.cancel_after = 0.35
		r.hits = 0
		r.stamina_cost = 0.0
		r.dodge_cancel = false
		kit.schedule(0.0, func():
			if is_instance_valid(hero) and not hero.runner.is_busy():
				hero.runner.start(r, {"line": "miss"}))
		link_until = -10.0


func on_dodge() -> void:
	if kit.aug("unbroken_line") > 0 and last_line != "":
		link_until = Game.time + Game.balance.dodge_duration + float(kit.ap("unbroken_line", "window", 0.45))
		kit.trigger("unbroken_line", "Continuation preserved through the dodge")
	elif last_line != "":
		link_until = -10.0


## Real attack angle: how far the attacker is from the target's facing (0 = in front, 180 = behind).
func angle_from_front(target) -> float:
	var to_me: Vector3 = hero.global_position - target.global_position
	to_me.y = 0
	if to_me.length() < 0.05:
		return 0.0
	return rad_to_deg(target.forward().angle_to(to_me.normalized()))


func on_hit_landed(target, info: DamageInfo) -> void:
	var ctx: Dictionary = hero.runner.ctx
	var line := String(ctx.get("line", ""))
	if line == "lunge" and kit.aug("measured_step") > 0:
		measured_until = Game.time + float(kit.ap("measured_step", "window", 0.6))
	if (line == "heavy" or line == "draw") and info.blocked_frontal and kit.aug("sundering_verdict") > 0:
		var st := StatusEffect.make("sundered", "Sundered Guard", "debuff", float(kit.ap("sundering_verdict", "duration", 4.0)), {})
		st.source = hero
		target.statuses.add(st)
		kit.trigger("sundering_verdict", "%s's guard weakened" % target.display_name)
		FX.number(target, "GUARD WEAKENED", Color(1.0, 0.75, 0.4), 0.8)
	if ctx.get("final_checked", false) or not (target is Enemy):
		return
	# Final Stroke preparation (any one is enough)
	if ctx.get("linked", false) and ctx.get("prev_connected", false):
		ctx["final_checked"] = true
		open_finisher("two different linked attacks connected (%s)" % line)
	elif line == "sunder" and target.is_staggered():
		ctx["final_checked"] = true
		open_finisher("Sunder Edge broke %s's poise" % target.display_name)
	elif line in ["turning", "slip", "lunge"] and angle_from_front(target) >= FLANK_ANGLE:
		ctx["final_checked"] = true
		open_finisher("%s hit from a %d deg angle" % [line.capitalize(), roundi(angle_from_front(target))])


## Measured Step: Dodge right after a connecting Lunge = short controlled reposition (no i-frames).
func dodge_override() -> bool:
	if Game.time > measured_until or kit.aug("measured_step") <= 0:
		return false
	var cost := float(kit.ap("measured_step", "stamina", 6.0))
	if hero.stamina < cost:
		return false
	var dir: Vector3 = hero.move_input
	dir.y = 0
	if dir.length() < 0.1:
		dir = -hero.forward()
	measured_until = -10.0
	hero.use_stamina(cost)
	hero.runner.interrupt()
	hero.knock_velocity += dir.normalized() * float(kit.ap("measured_step", "speed", 6.0))
	kit.trigger("measured_step", "Measured Step")
	return true


func hud_lines() -> Array:
	var out: Array = ["LMB forward · Shift+A/D+LMB lateral · RMB heavy" + (" (hold: Draw Cut)" if kit.unlocked("r_draw") else "") + " · Dodge->LMB slip"]
	var lo := loadout()
	out.append("Skills: 1 %s · 2 %s · 3 %s · E %s" % [lo[0], lo[1], lo[2], lo[3]])
	if last_line != "" and (hero.runner.is_busy() or Game.time <= link_until):
		out.append("Line: %s%s" % [last_line, "  ·  link open" if hero.runner.can_cancel() or Game.time <= link_until else ""])
	if finisher_open():
		out.append("FINAL STROKE ready (F) %.1fs" % (finisher_until - Game.time))
	if kit.charging == "heavy":
		out.append("Charging Draw Cut %d%%" % roundi(kit.charge_ratio() * 100))
	return out
