class_name ReaverBladeDancer
extends RefCounted
## REAVER — BLADE DANCER (REAVER-BLADEDANCER-003, approved spec: collaboration/tasks/REAVER-BLADEDANCER-003.md).
## Pure physical sword fighter. No shield, block, heal, magic, teleport, clones, bleed or resource meter.
##
## Two modes, chosen by holding RMB (no cooldown, no damage buff for switching):
##   DANCE (default)  LMB = directional Dance attack: neutral / forward (W) / lateral (A, D). The movement
##                    input changes the attack AND the real position (collision-bound, no teleport).
##   EDGE  (hold RMB) LMB tap = Precision Cut, LMB hold (>= 0.35s) + release = Committed Cut.
##                    Holding RMB alone costs nothing. Releasing RMB never fires an attack.
##   Space  Combat Weave: Reaver dodge distances by direction (side short, forward short, back far).
##          In Edge the dodge also leaves Edge (press RMB again to return).
##   Q      Dance: Orbit Step (circle the target + quick slash)   Edge: Withdraw & Thrust
##   E      Dance: Whirling Assault (mobile multi-hit)              Edge: Breaking Point (Poise punish)
## Mode changes happen immediately when idle or in a legal cancel window, never inside committed frames.

const HOLD_THRESHOLD := 0.35          ## LMB held this long in Edge = Committed Cut
const COMMIT_MAX := 0.75              ## longer holds add nothing
const COMMIT_DMG_BONUS := 0.4         ## damage_mult added at a full (0.75s) hold, linear from 0.35s
const COMMIT_POISE_BONUS := 10.0      ## poise added at a full hold
const FORWARD_V := 5.7                ## knock impulse: ~0.9m forward (decel 18 m/s^2 -> d = v^2 / 36)
const LATERAL_V := 4.85               ## ~0.65m sideways
const WITHDRAW_V := 5.4               ## ~0.8m back
const ORBIT_SPEED := 5.6              ## m/s along the circle during Orbit Step startup (~1.5m of arc)
const ORBIT_FREE_V := 7.1             ## no target: straight lateral step ~1.4m
const RELENTLESS_TRAVEL := 1.4        ## Relentless Dance: travel x1.4 (neutral: 0.5m forward)
const FORWARD_ANGLE := 50.0           ## input within this angle of the reference = forward
const BACK_ANGLE := 130.0             ## beyond this = backward input (no backward Dance: neutral)
const ENGAGE_RADIUS := 6.0
const BREAK_PUNISH_POISE := 2.0       ## Breaking Point vs a recovering / staggered enemy
const PERFECT_EDGE_POISE := 1.5       ## Perfect Edge Committed Cut vs a recovering enemy
const MASTERY_CANCEL := 0.06          ## Lv7: Precision Cut -> Dance after 0.06s of recovery (normal 0.14)
const STAMINA_REFUND := 1.0
const CHAIN_BLEND := 0.10
const DEFAULT_BLEND := 0.04
## Combat Weave target distances (the shared dodge covers 3.465m; its speed is scaled, its timing and
## i-frames are not touched)
const WEAVE_DIST := {"side": 1.3, "forward": 1.5, "back": 2.5}
const SHARED_DODGE_DIST := 3.465
const STANCE_ANIM := "bd_edge_stance"

var kit
var hero
var mode: String = "dance"
var edge_latched: bool = true         ## false after an Edge dodge until RMB is pressed again
var relentless_ready: bool = false
var last_dodge_kind: String = ""
var _lmb_in_edge: bool = false
var _chaining: bool = false
var _orbit: Dictionary = {}
# diagnostics (tests / measurement only; never shown as a meter)
var started: Dictionary = {}
var mode_switches: int = 0
var stamina_refunded: float = 0.0
var last_attack: String = ""


func _init(p_kit) -> void:
	kit = p_kit
	hero = p_kit.hero


func reset() -> void:
	mode = "dance"
	edge_latched = true
	relentless_ready = false
	_lmb_in_edge = false
	_chaining = false
	_orbit = {}
	if hero:
		if "attack_blend" in hero:
			hero.attack_blend = DEFAULT_BLEND
		if "dodge_scale" in hero:
			hero.dodge_scale = 1.0


# ------------------------------------------------------------------ queries
func in_edge() -> bool:
	return mode == "edge"


func engaged_target():
	var t = hero.lock_target
	if t != null and is_instance_valid(t) and t.is_targetable():
		return t
	var best = null
	var bd := ENGAGE_RADIUS
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_targetable():
			continue
		var d: float = (e.global_position - hero.global_position).length()
		if d < bd:
			bd = d
			best = e
	return best


## Reference "forward": toward the lock-on target, otherwise the way the Reaver faces.
func ref_dir() -> Vector3:
	var t = hero.lock_target
	if t != null and is_instance_valid(t) and t.is_targetable():
		var f: Vector3 = t.global_position - hero.global_position
		f.y = 0
		if f.length() > 0.05:
			return f.normalized()
	return hero.forward()


func _input_dir() -> Vector3:
	var m: Vector3 = hero.move_input
	m.y = 0
	return m.normalized() if m.length() > 0.2 else Vector3.ZERO


## "neutral" / "forward" / "lateral" (+ side sign: +1 right, -1 left) / "back" for a movement input.
func classify(m: Vector3) -> Array:
	if m == Vector3.ZERO:
		return ["neutral", 0]
	var ref := ref_dir()
	var a := rad_to_deg(ref.angle_to(m))
	if a <= FORWARD_ANGLE:
		return ["forward", 0]
	if a >= BACK_ANGLE:
		return ["back", 0]
	var side := -signf(ref.signed_angle_to(m, Vector3.UP))   # +1 = to the Reaver's right
	return ["lateral", int(side)]


# ------------------------------------------------------------------ mode
func _legal_switch() -> bool:
	if hero.dodging or hero.stagger_timer > 0.0 or kit.charging != "":
		return false
	var r: AttackRunner = hero.runner
	return not r.is_busy() or r.can_cancel()


func _set_mode(m: String) -> void:
	if m == mode:
		return
	mode = m
	mode_switches += 1
	if not hero.runner.is_busy() and not hero.dodging:
		if m == "edge":
			_play_stance()
		else:
			hero.play_anim("idle")


func _play_stance() -> void:
	if not hero.anim_lib.has_animation(STANCE_ANIM):
		hero.anim_lib.add_animation(STANCE_ANIM, _build_stance())
	if hero.anim.current_animation != STANCE_ANIM:
		hero.anim.play(STANCE_ANIM, 0.12)


## Edge stance: blade held low and forward, weight lowered (temporary procedural pose).
static func _build_stance() -> Animation:
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR
	var keys := {
		ProcAnim.T_WEAPON_ROT: [Vector3(0.35, 0.75, 0.15), Vector3(0.4, 0.7, 0.15)],
		ProcAnim.T_WEAPON_POS: [Vector3(0.22, 1.0, -0.32), Vector3(0.22, 0.98, -0.32)],
		ProcAnim.T_MODEL_POS: [Vector3(0, -0.14, 0), Vector3(0, -0.16, 0)],
		ProcAnim.T_MODEL_ROT: [Vector3(0, -0.3, 0), Vector3(0, -0.3, 0)],
	}
	for path in keys:
		var i := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(path))
		a.track_insert_key(i, 0.0, keys[path][0])
		a.track_insert_key(i, 0.6, keys[path][1])
		a.track_insert_key(i, 1.2, keys[path][0])
	return a


func overrides_idle() -> bool:
	return _chaining or mode == "edge"


# ------------------------------------------------------------------ input
func on_press(action: String) -> void:
	match action:
		"heavy":
			edge_latched = true          # a fresh RMB press may always enter Edge
			if _legal_switch() and kit.unlocked("bd_edge"):
				_set_mode("edge")
		"light":
			if _mastery_blocks(action):
				hero.buffer(action)
				return
			if not hero.can_act():
				hero.buffer(action)
				return
			if mode == "edge":
				_lmb_in_edge = true
				kit.begin_charge("edge_lmb", COMMIT_MAX)
				if not hero.is_held("light"):
					on_release("light")   # a buffered tap that was already released
			else:
				_dance()
		"footwork":
			_technique(action, "bd_footwork")
		"core":
			_technique(action, "bd_offense")


func on_release(action: String) -> void:
	match action:
		"heavy":
			# leaving Edge never fires an attack: a prepared Edge strike is abandoned
			if kit.charging == "edge_lmb":
				kit.cancel_charge()
				_lmb_in_edge = false
		"light":
			if kit.charging != "edge_lmb" or not _lmb_in_edge:
				return
			var held: float = kit.charge_t
			kit.cancel_charge()
			_lmb_in_edge = false
			if held < HOLD_THRESHOLD:
				_precision()
			else:
				_committed(clampf((held - HOLD_THRESHOLD) / (COMMIT_MAX - HOLD_THRESHOLD), 0.0, 1.0))


func _technique(action: String, unlock_id: String) -> void:
	if not kit.unlocked(unlock_id):
		kit.locked_msg(unlock_id)
		return
	if _mastery_blocks(action) or not hero.can_act():
		hero.buffer(action)
		return
	var footwork := action == "footwork"
	var id: String
	if mode == "edge":
		id = "bd_withdraw" if footwork else "bd_break"
	else:
		id = "bd_orbit" if footwork else "bd_whirl"
	var d: AttackData = kit.load_attack(id).clone()
	if hero.stamina < d.stamina_cost * 0.5:
		if hero.is_player:
			Events.notify.emit("Not enough stamina")
		return
	_go(d, id.trim_prefix("bd_"))


# ------------------------------------------------------------------ attacks
func _dance() -> void:
	var c := classify(_input_dir())
	var kind: String = c[0]
	if kind == "back":
		kind = "neutral"
	var d: AttackData = kit.load_attack("bd_dance_" + kind).clone()
	if kind == "lateral":
		d.anim_style = "bd_lateral_r" if int(c[1]) > 0 else "bd_lateral_l"
	var extra := {"side": int(c[1])}
	if relentless_ready and kit.aug("relentless_dance") > 0:
		relentless_ready = false
		d.anim_style = "bd_relentless"
		d.display_name = "Relentless " + d.display_name
		extra["relentless"] = true
		kit.trigger("relentless_dance", "Relentless Dance follow-up")
	_go(d, "dance_" + kind, extra)


func _precision() -> void:
	_go(kit.load_attack("bd_precision").clone(), "precision")


func _committed(ratio: float) -> void:
	var d: AttackData = kit.load_attack("bd_committed").clone()
	d.damage_mult += COMMIT_DMG_BONUS * ratio
	d.poise_damage += COMMIT_POISE_BONUS * ratio
	var tr := ""
	if kit.aug("perfect_edge") > 0:
		tr = "perfect_edge"
		d.hitbox_size.x *= float(kit.ap(tr, "width_mult", 0.6))
		d.display_name = "Perfect Edge"
		kit.trigger(tr, "Committed Cut narrowed")
	elif kit.aug("twin_tempest") > 0:
		tr = "twin_tempest"
		var n := int(kit.ap(tr, "hits", 4))
		var fs := float(kit.ap(tr, "final_share", 0.55))
		var w := PackedFloat32Array()
		for i in n:
			w.append(fs if i == n - 1 else (1.0 - fs) / float(n - 1))
		d.hits = n
		d.hit_weights = w
		d.anim_style = "bd_twin"
		d.active = maxf(d.active, float(kit.ap(tr, "active", 0.36)))
		d.recovery += float(kit.ap(tr, "extra_recovery", 0.1))
		d.final_hit_heavy = true
		# a multi-hit technique scales with DEX (multi-hit) instead of STR (heavy): keeping both would add
		# the multi-hit bonus on top of the heavy one (+50% at base stats, measured)
		d.is_heavy = false
		d.add_tag("multi")
		d.display_name = "Twin Tempest"
		kit.trigger(tr, "Committed Cut became a %d-hit technique" % n)
	_go(d, "committed", {"charge": ratio, "transform": tr})


func _go(d: AttackData, kind: String, extra: Dictionary = {}) -> bool:
	var r: AttackRunner = hero.runner
	if hero.stamina <= 0.0 and d.stamina_cost > 0.0:
		return false
	var ctx := {"bd": true, "kind": kind, "mode": mode}
	ctx.merge(extra)
	if "attack_blend" in hero:
		hero.attack_blend = CHAIN_BLEND if r.is_busy() else DEFAULT_BLEND
	# chained transitions never pass through the idle pose (no full reset between legal attacks)
	_chaining = true
	r.interrupt()
	var ok: bool = kit.start_attack(d, ctx)
	_chaining = false
	if not ok:
		return false
	started[kind] = int(started.get(kind, 0)) + 1
	last_attack = kind
	_apply_motion(kind, ctx)
	return true


## Movement is a velocity impulse applied through move_and_slide (walls and bodies stop it); the
## direction is fixed when the attack starts (no homing). Orbit Step steers along a circle around the
## engaged target during its startup only.
func _apply_motion(kind: String, ctx: Dictionary) -> void:
	var ref := ref_dir()
	var mult := RELENTLESS_TRAVEL if ctx.get("relentless", false) else 1.0
	match kind:
		"dance_neutral":
			if ctx.get("relentless", false):
				hero.knock_velocity += ref * sqrt(36.0 * 0.5)
		"dance_forward":
			hero.attack_turn_dir = ref
			hero.knock_velocity += ref * FORWARD_V * sqrt(mult)
		"dance_lateral":
			var side := ref.cross(Vector3.UP).normalized() * float(ctx.get("side", 1))
			hero.attack_turn_dir = ref
			hero.knock_velocity += side * LATERAL_V * sqrt(mult)
		"withdraw":
			hero.attack_turn_dir = ref
			hero.knock_velocity -= ref * WITHDRAW_V
		"orbit":
			var t = engaged_target()
			var sgn := 1.0
			var m := _input_dir()
			if m != Vector3.ZERO:
				var c := classify(m)
				if String(c[0]) == "lateral":
					sgn = float(c[1])
			if t == null:
				hero.knock_velocity += ref.cross(Vector3.UP).normalized() * sgn * ORBIT_FREE_V
				_orbit = {}
			else:
				var rv: Vector3 = hero.global_position - t.global_position
				rv.y = 0
				_orbit = {"target": t, "sign": sgn, "radius": maxf(rv.length(), 1.4)}


func _mastery_blocks(action: String) -> bool:
	# Lv7: the early window after a connected Precision Cut is for ONE directional Dance attack only
	var r: AttackRunner = hero.runner
	if not r.is_busy() or not r.ctx.get("mastery_open", false) or r.time_in_recovery() >= r.data.cancel_after:
		return false
	return not (action == "light" and mode == "dance")


# ------------------------------------------------------------------ damage hooks
func modify_outgoing(info: DamageInfo, _d: AttackData, target, _idx: int, ctx: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or not (target is Enemy):
		return
	var kind := String(ctx.get("kind", ""))
	var recovering := ReaverFreeFlow.in_attack_recovery(target)
	if kind == "break" and (recovering or target.is_staggered()):
		info.poise *= BREAK_PUNISH_POISE
		info.tags["punish"] = true
	elif kind == "committed" and String(ctx.get("transform", "")) == "perfect_edge" and recovering:
		info.poise *= float(kit.ap("perfect_edge", "recovery_poise", PERFECT_EDGE_POISE))
		info.tags["punish"] = true


func on_hit_landed(target, info: DamageInfo) -> void:
	var ctx: Dictionary = hero.runner.ctx
	if not ctx.get("bd", false) or not (target is Enemy):
		return
	if not ctx.get("refunded", false):
		ctx["refunded"] = true
		var before: float = hero.stamina
		hero.stamina = minf(hero.max_stamina, hero.stamina + STAMINA_REFUND)
		stamina_refunded += hero.stamina - before
	if ctx.get("hit", false):
		return
	ctx["hit"] = true
	var kind := String(ctx.get("kind", ""))
	if String(ctx.get("mode", "")) == "edge" and kit.aug("relentless_dance") > 0:
		relentless_ready = true
	if kind == "precision" and kit.unlocked("bd_mastery"):
		ctx["mastery"] = true
	if info.tags.get("punish", false):
		VFX.hit_sparks(target.global_position + Vector3(0, 1.1, 0), Color(1.0, 0.55, 0.25), 14, true)
		Events.augment_triggered.emit(hero, "bd_offense", "Breaking Point: %s caught" % target.display_name)


func on_attack_finished(_d: AttackData, _ctx: Dictionary, _interrupted: bool) -> void:
	_orbit = {}


## Combat Weave: the shared dodge (same timing, i-frames and stamina) travels a Reaver distance chosen
## by its direction relative to the engaged enemy. In Edge it also leaves Edge.
func on_dodge() -> void:
	var m := _input_dir()
	var kind := "back"
	if m != Vector3.ZERO:
		var a := rad_to_deg(ref_dir().angle_to(m))
		kind = "forward" if a <= 45.0 else ("back" if a >= 135.0 else "side")
	last_dodge_kind = kind
	hero.dodge_scale = float(WEAVE_DIST[kind]) / SHARED_DODGE_DIST
	if mode == "edge":
		mode = "dance"
		mode_switches += 1
		edge_latched = false
	_lmb_in_edge = false


func process(_delta: float) -> void:
	var r: AttackRunner = hero.runner
	# Orbit Step: circle the target during the startup (collision still applies)
	if not _orbit.is_empty():
		var t = _orbit.get("target")
		if r.is_busy() and r.ctx.get("kind", "") == "orbit" and r.phase == AttackRunner.Phase.STARTUP and is_instance_valid(t) and t.is_targetable():
			var rv: Vector3 = hero.global_position - t.global_position
			rv.y = 0
			if rv.length() > 0.05:
				var tangent := Vector3.UP.cross(rv.normalized()) * float(_orbit.sign)
				var radial: Vector3 = rv.normalized() * (float(_orbit.radius) - rv.length()) * 4.0
				hero.knock_velocity = tangent * ORBIT_SPEED + radial
		else:
			# the circling ends with the startup: the slash itself does not slide
			if r.is_busy() and r.ctx.get("kind", "") == "orbit":
				hero.knock_velocity = Vector3.ZERO
			_orbit = {}
	if r.is_busy() and r.ctx.get("bd", false) and r.phase == AttackRunner.Phase.RECOVERY:
		# Breaking Point: a connecting strike recovers at once; a miss keeps its long recovery
		if r.ctx.get("kind", "") == "break" and r.ctx.get("hit", false):
			r.cancel_override = true
		# Lv7 mastery: connected Precision Cut -> one Dance attack after a shorter recovery
		if r.ctx.get("mastery", false) and not hero.is_held("heavy") and r.time_in_recovery() >= MASTERY_CANCEL:
			r.cancel_override = true
			r.ctx["mastery_open"] = true
	# mode follows RMB, but only changes when legal
	var want := "edge" if hero.is_held("heavy") and edge_latched and kit.unlocked("bd_edge") else "dance"
	if want != mode and _legal_switch():
		_set_mode(want)
	if mode == "edge" and not r.is_busy() and not hero.dodging and kit.charging == "" and hero.stagger_timer <= 0.0:
		_play_stance()


func hud_lines() -> Array:
	return ["Blade Dancer  ·  %s  ·  LMB Dance (W / A / D) · hold RMB Edge: tap / hold LMB · Space Weave · Q Footwork · E Offense" % ("EDGE" if mode == "edge" else "DANCE")]
