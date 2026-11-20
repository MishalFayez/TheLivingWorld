class_name ReaverFreeFlow
extends RefCounted
## REAVER — FREE FLOW (REAVER-FREEFLOW-001, approved spec: collaboration/tasks/REAVER-FREEFLOW-001.md).
## Pure physical swordplay: no magic, teleport, clones, bleed, meters, stacks or combo counter.
##
##   LMB    Flow Strikes  three animation variations in rotation; NOT a fixed combo (all equal)
##   RMB    Heavy Cut     always available, no charge
##   Space  Combat Dodge  (shared Hero dodge: same stamina cost, collision and i-frames)
##   1      Pursuit Cut   Lv3  short forward rush (fixed direction, collision) + one strike
##   2      Pivot Cut     Lv5  short step toward the movement input (backward without input) + slash,
##                             NO invulnerability
##   3      Decisive Cut  Lv7  committed single-target strike; transformed by one of the Decisive
##                             augments (Precision / Tempest / Momentum Edge, mutually exclusive)
##
## Any order is legal. The SEQUENCE stays open while attacks connect (CONTINUE_GRACE after a connecting
## attack ends) and across a dodge started inside it (DODGE_GRACE after the dodge ends). A missed attack
## neither resets nor extends it, so repeated misses let it expire naturally.
##
## Precision Opportunity (hidden, internal, at most one, never stacks): created by two consecutive
## connecting attacks, a Perfect Dodge (an enemy attack avoided inside the dodge i-frames), or a Pivot
## Cut connecting from 60+ degrees off the enemy's facing. A Heavy Cut or Decisive Cut STARTED while it
## is open consumes it (hit or miss) for +20% damage / +35% Poise and stronger impact feedback.

const CONTINUE_GRACE := 0.65
const DODGE_GRACE := 0.80
const OPPORTUNITY_TIME := 1.75
const MASTERY_BONUS := 0.25
const OPP_DAMAGE := 1.20
const OPP_POISE := 1.35
const OPP_HITSTOP := 1.4          ## consumed strike: longer impact freeze (feedback only)
const FLANK_ANGLE := 60.0
const PURSUIT_SPEED := 10.0       ## impulse through move_and_slide: ~2.8m, stops on collision
const PIVOT_SPEED := 5.0          ## ~0.7m (same step as the previous Flow Step / Turning Edge)
const STRIKES := ["ff_strike_1", "ff_strike_2", "ff_strike_3"]
const SLOT_SKILL := {"skill1": "r_pursuit_cut", "skill2": "r_pivot_cut", "skill3": "r_decisive_cut"}
const SKILL_ATTACK := {"r_pursuit_cut": "ff_pursuit", "r_pivot_cut": "ff_pivot", "r_decisive_cut": "ff_decisive"}
const SKILL_KIND := {"r_pursuit_cut": "pursuit", "r_pivot_cut": "pivot", "r_decisive_cut": "decisive"}
const SKILL_CD := {"r_pursuit_cut": 5.0, "r_pivot_cut": 4.0, "r_decisive_cut": 8.0}
const TRANSFORMS := ["precision_edge", "tempest_edge", "momentum_edge"]
const CONSUMERS := ["heavy", "decisive"]

var kit
var hero
var strike_i: int = 0
var flow_until: float = -10.0
var last_connected: bool = false
var opportunity_until: float = -10.0
var dodge_count: int = 0
var _dodge_keeps: bool = false
var _pd_dodge: int = -1
var _pd_key: String = ""
var _pd_until: float = -10.0
# diagnostics (tests / debug, never shown as a HUD meter)
var opportunities_created: int = 0
var opportunities_refreshed: int = 0
var opportunities_consumed: int = 0
var last_reason: String = ""


func _init(p_kit) -> void:
	kit = p_kit
	hero = p_kit.hero


func reset() -> void:
	strike_i = 0
	flow_until = -10.0
	last_connected = false
	opportunity_until = -10.0
	_dodge_keeps = false


# ------------------------------------------------------------------ state queries
func has_opportunity() -> bool:
	return Game.time < opportunity_until


func opportunity_duration() -> float:
	return OPPORTUNITY_TIME + (MASTERY_BONUS if kit.unlocked("r_flow_mastery") else 0.0)


## The offensive sequence is open: inside the continuation grace, or inside the cancel window of a
## Free Flow attack that is still running.
func in_sequence() -> bool:
	if Game.time <= flow_until:
		return true
	var r: AttackRunner = hero.runner
	return r.is_busy() and r.ctx.get("ff", false) and r.can_cancel()


func transform() -> String:
	for id in TRANSFORMS:
		if kit.aug(id) > 0:
			return id
	return ""


# ------------------------------------------------------------------ opportunity
func grant(reason: String) -> void:
	if has_opportunity():
		opportunities_refreshed += 1
	else:
		opportunities_created += 1
	opportunity_until = Game.time + opportunity_duration()
	last_reason = reason
	Events.augment_triggered.emit(hero, "r_free_flow", "Precision Opportunity: " + reason)
	# feedback: brief weapon glint + small flash; restrained placeholder chime (player only)
	var wp: Vector3 = hero.weapon_pivot.global_position if hero.weapon_pivot else hero.global_position + Vector3(0, 1.3, 0)
	VFX.opening_glint(wp)
	VFX.flash_light(wp, Color(1.0, 0.9, 0.6), 1.5, 2.5, 0.12)
	if hero.is_player:
		PlaceholderSfx.play(hero, "opportunity")


func _consume() -> void:
	opportunity_until = -10.0
	opportunities_consumed += 1
	if hero.is_player:
		PlaceholderSfx.play(hero, "consume")


# ------------------------------------------------------------------ input
func on_press(action: String) -> void:
	match action:
		"light":
			if not hero.can_act():
				hero.buffer(action)
				return
			if not in_sequence():
				strike_i = 0
			var d: AttackData = kit.load_attack(STRIKES[strike_i % STRIKES.size()]).clone()
			strike_i += 1
			_go(d, "light")
		"heavy":
			if not hero.can_act():
				hero.buffer(action)
				return
			_go(kit.load_attack("ff_heavy").clone(), "heavy")
		"skill1", "skill2", "skill3":
			use_skill(String(SLOT_SKILL[action]), action)


func use_skill(id: String, action: String) -> bool:
	if not kit.unlocked(id):
		kit.locked_msg(id)
		return false
	if kit.cooldowns.get(id, 0.0) > 0.0:
		if hero.is_player:
			Events.notify.emit("On cooldown (%.1fs)" % kit.cooldowns[id])
		return false
	if not hero.can_act():
		hero.buffer(action)
		return false
	var d: AttackData = kit.load_attack(SKILL_ATTACK[id]).clone()
	var kind: String = SKILL_KIND[id]
	var tr := ""
	if kind == "decisive":
		tr = transform()
		_apply_transform(d, tr)
	if hero.stamina < d.stamina_cost * 0.5:
		if hero.is_player:
			Events.notify.emit("Not enough stamina")
		return false
	if not _go(d, kind, tr):
		return false
	kit.cooldowns[id] = float(SKILL_CD[id])
	return true


# ------------------------------------------------------------------ attack start
func _go(d: AttackData, kind: String, tr: String = "") -> bool:
	var r: AttackRunner = hero.runner
	if hero.stamina <= 0.0 and d.stamina_cost > 0.0:
		return false
	var chain := in_sequence()
	var prev_conn := last_connected
	if r.is_busy() and r.ctx.get("ff", false):
		prev_conn = r.connected_hits() > 0
	var consumed := false
	if CONSUMERS.has(kind) and has_opportunity():
		_consume()
		consumed = true
		d.hitstop *= OPP_HITSTOP
	var ctx := {"ff": true, "kind": kind, "consecutive": chain and prev_conn, "consumed": consumed,
		"transform": tr, "transforms": [tr] if tr != "" else [], "form": ""}
	if consumed:
		ctx["damage_mult"] = OPP_DAMAGE
		ctx["poise_mult"] = OPP_POISE
	r.interrupt()   # a legal cancel-window transition (can_act was true)
	if not kit.start_attack(d, ctx):
		return false
	_apply_motion(kind, tr)
	return true


func _target_dir() -> Vector3:
	var t = hero.lock_target
	if t != null and is_instance_valid(t) and t.is_targetable():
		var f: Vector3 = t.global_position - hero.global_position
		f.y = 0
		if f.length() > 0.05:
			return f.normalized()
	return Vector3.ZERO


func _input_dir() -> Vector3:
	var m: Vector3 = hero.move_input
	m.y = 0
	return m.normalized() if m.length() > 0.2 else Vector3.ZERO


## Skill movement goes through knock_velocity (applied by move_and_slide, so walls and enemies stop
## it). The direction is fixed when the skill starts: no homing, no snapping, no teleport.
func _apply_motion(kind: String, tr: String) -> void:
	match kind:
		"pursuit":
			var dir := _target_dir()
			if dir == Vector3.ZERO:
				dir = _input_dir()
			if dir == Vector3.ZERO:
				dir = hero.forward()
			hero.attack_turn_dir = dir
			hero.knock_velocity += dir * PURSUIT_SPEED
		"pivot":
			var dir := _input_dir()
			if dir == Vector3.ZERO:
				dir = -hero.forward()     # conservative backward reposition
			var face := _target_dir()
			hero.attack_turn_dir = face if face != Vector3.ZERO else hero.forward()
			hero.knock_velocity += dir * PIVOT_SPEED
		"decisive":
			if tr == "momentum_edge":
				var dir := _input_dir()
				if dir == Vector3.ZERO:
					dir = hero.forward()
				hero.attack_turn_dir = dir
				hero.knock_velocity += dir * float(kit.ap("momentum_edge", "speed", 8.0))
				kit.trigger("momentum_edge", "Decisive Cut became a moving strike")


func _apply_transform(d: AttackData, tr: String) -> void:
	match tr:
		"precision_edge":
			d.anim_style = "thrust"
			d.hitbox_size.x *= float(kit.ap(tr, "width_mult", 0.55))
			d.hitbox_size.z *= float(kit.ap(tr, "length_mult", 1.25))
			d.hitbox_offset.z = -0.4 - d.hitbox_size.z * 0.5
			d.poise_damage *= float(kit.ap(tr, "poise_mult", 1.3))
			d.display_name = "Precision Edge"
			kit.trigger(tr, "Decisive Cut became a narrow thrust")
		"tempest_edge":
			var n := int(kit.ap(tr, "hits", 4))
			var fs := float(kit.ap(tr, "final_share", 0.55))
			var w := PackedFloat32Array()
			for i in n:
				w.append(fs if i == n - 1 else (1.0 - fs) / float(n - 1))
			d.hits = n
			d.hit_weights = w
			d.anim_style = "flurry"
			d.active = maxf(d.active, 0.09 * n)
			d.recovery += float(kit.ap(tr, "extra_recovery", 0.1))
			d.hitbox_size.x *= float(kit.ap(tr, "arc_mult", 2.0))
			d.final_hit_heavy = true
			d.add_tag("multi")
			d.display_name = "Tempest Edge"
			kit.trigger(tr, "Decisive Cut became a %d-hit sequence" % n)
		"momentum_edge":
			d.anim_style = "slash_h"
			d.approach_max = 0.0       # the strike's own rush replaces the approach step
			d.display_name = "Momentum Edge"


# ------------------------------------------------------------------ damage hooks
func modify_outgoing(info: DamageInfo, _d: AttackData, target, _idx: int, ctx: Dictionary) -> void:
	var tr := String(ctx.get("transform", ""))
	if target == null or not is_instance_valid(target) or not (tr in ["precision_edge", "momentum_edge"]):
		return
	var positioned := angle_from_front(target) >= FLANK_ANGLE
	if tr == "precision_edge" and not positioned:
		positioned = target.is_staggered() or (target.runner.is_busy() and target.runner.phase == AttackRunner.Phase.RECOVERY)
	if not positioned:
		return
	info.amount *= float(kit.ap(tr, "position_damage", 1.2))
	info.raw_amount = info.amount
	info.poise *= float(kit.ap(tr, "position_poise", 1.35))
	info.tags["positioned"] = true


func on_hit_landed(target, info: DamageInfo) -> void:
	var ctx: Dictionary = hero.runner.ctx
	if not ctx.get("ff", false):
		return
	var kind := String(ctx.get("kind", ""))
	if kind == "heavy" and info.blocked_frontal and kit.aug("sundering_verdict") > 0:
		var st := StatusEffect.make("sundered", "Sundered Guard", "debuff", float(kit.ap("sundering_verdict", "duration", 4.0)), {})
		st.source = hero
		target.statuses.add(st)
		kit.trigger("sundering_verdict", "%s's guard weakened" % target.display_name)
	if ctx.get("hit_checked", false) or not (target is Enemy):
		return
	ctx["hit_checked"] = true
	if ctx.get("consumed", false):
		# stronger impact feedback for the prepared strike (temporary, replaceable)
		var pos: Vector3 = target.global_position + Vector3(0, 1.1, 0)
		VFX.hit_sparks(pos, Color(1.0, 0.8, 0.4), 18, true)
		VFX.opening_glint(pos)
		if hero.is_player and Game.world and Game.world.has_method("shake"):
			Game.world.shake(0.3)
		return       # a consuming attack never creates a new opportunity from itself
	if kind == "pivot" and angle_from_front(target) >= FLANK_ANGLE:
		grant("Pivot Cut from %d deg" % roundi(angle_from_front(target)))
	elif ctx.get("consecutive", false):
		grant("two consecutive connecting attacks")


func on_attack_finished(_d: AttackData, ctx: Dictionary, _interrupted: bool) -> void:
	if not ctx.get("ff", false):
		return
	last_connected = hero.runner.connected_hits() > 0
	if last_connected:
		flow_until = Game.time + CONTINUE_GRACE


func on_dodge() -> void:
	# called after the dodge interrupted the current attack (which already updated the sequence)
	dodge_count += 1
	_dodge_keeps = Game.time <= flow_until


## Perfect Dodge = an actual enemy attack avoided inside the dodge i-frames (Combatant.take_damage ->
## Hero.on_dodged while dodging). One opportunity per dodge and per attack event.
func on_perfect_dodge(info: DamageInfo) -> void:
	var src = info.source
	if src == null or not is_instance_valid(src) or not ("team" in src) or src.team == hero.team:
		return
	if _pd_dodge == dodge_count:
		return
	var key := "%d:%s" % [src.get_instance_id(), info.attack.id if info.attack else info.attack_name]
	if key == _pd_key and Game.time < _pd_until:
		return
	_pd_dodge = dodge_count
	_pd_key = key
	_pd_until = Game.time + (info.attack.total_time() if info.attack else 1.0)
	grant("Perfect Dodge (%s)" % (src.display_name if "display_name" in src else "?"))
	if hero.is_player:
		Events.notify.emit("Perfect Dodge")


func process(_delta: float) -> void:
	if _dodge_keeps and not hero.dodging:
		_dodge_keeps = false
		flow_until = maxf(flow_until, hero.last_dodge_end + DODGE_GRACE)


## Real attack angle: how far the attacker is from the target's facing (0 = in front, 180 = behind).
func angle_from_front(target) -> float:
	var to_me: Vector3 = hero.global_position - target.global_position
	to_me.y = 0
	if to_me.length() < 0.05:
		return 0.0
	return rad_to_deg(target.forward().angle_to(to_me.normalized()))


func hud_lines() -> Array:
	return ["Free Flow  ·  LMB Flow Strikes · RMB Heavy Cut · Space Dodge · 1 Pursuit · 2 Pivot · 3 Decisive"]
