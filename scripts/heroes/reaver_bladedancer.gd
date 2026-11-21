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
## --- BLADE DANCER 004 refinement (LEVEL10-FOUNDATION-005 Part 2). Movement is a knock impulse through
## move_and_slide (decel 18 m/s^2 -> free-space distance d = v^2 / 36); collision always applies.
const FORWARD_MAX := 1.3              ## forward Dance travel with room to close (003: ~0.9m)
const FORWARD_MIN := 0.35             ## already inside weapon range: a short step only
const FORWARD_STOP := 1.15            ## centre distance the forward step aims to stop at (bodies collide at ~0.9m)
const LATERAL_DIST := 1.0             ## lateral Dance travel (003: ~0.65m)
const WITHDRAW_DIST := 1.5            ## Withdraw & Thrust retreat (003: ~0.8m)
const FORWARD_V := 6.84               ## sqrt(36 x 1.3): no-target forward impulse
const LATERAL_V := 6.0                ## sqrt(36 x 1.0)
const WITHDRAW_V := 7.35              ## sqrt(36 x 1.5)
const ORBIT_SPEED := 6.4              ## m/s along the circle during Orbit Step startup
const ORBIT_ANGLE := 75.0             ## target sweep (003: ~40 deg); owner range 70-80
const ORBIT_MIN_T := 0.24             ## Orbit Step startup bounds (duration follows the arc length)
const ORBIT_MAX_T := 0.42
const ORBIT_FREE_V := 7.1             ## no target: straight lateral step ~1.4m
const WHIRL_ENGAGE_GAP := 2.0         ## Whirling Assault: beyond this gap to the locked target ...
const WHIRL_ENGAGE_SPEED := 1.2       ## ... drift toward it at up to this speed during the hits (never through it)
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
## 006 (from measured enemy reach; 004 was 2.0 / 2.0 / 2.7): side clears the widest frontal hitbox half-width
## + body (~1.95m) with margin, back clears a wolf / execution lunge started at ~1.9m. Same 0.42s timing and
## the same i-frames: only the speed curve is scaled.
const WEAVE_DIST := {"side": 2.8, "forward": 2.6, "back": 3.6}
const WEAVE_ANIM := "bd_weave"
const FULL_POSE_ANIM := "bd_charge_full"
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
var _lateral: Dictionary = {}          ## Phantom Footwork curved lateral state (Dance Mastery augment)
var _weave: bool = false
var _cfx: ChargeFX = null
var _blade_glow: MeshInstance3D = null
var _full_cued: bool = false
# diagnostics (tests / measurement only; never shown as a meter)
var started: Dictionary = {}
var mode_switches: int = 0
var stamina_refunded: float = 0.0
var last_attack: String = ""
var full_charge_cues: int = 0
var evades: int = 0
var weave_completions: int = 0
var _last_evade_fx: float = -10.0
var last_orbit: Dictionary = {}        ## {radius, startup, target_angle, swept}
var last_forward_plan: float = 0.0


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
	_lateral = {}
	_weave = false
	_end_charge_fx()
	if hero:
		if "attack_blend" in hero:
			hero.attack_blend = DEFAULT_BLEND
		if "dodge_scale" in hero:
			hero.dodge_scale = 1.0


# ------------------------------------------------------------------ queries
## Free-space travel of a knock impulse (Combatant decelerates knock_velocity at 18 m/s^2: d = v^2 / 36).
static func impulse_distance(v: float) -> float:
	return v * v / 36.0


static func forward_distance() -> float:
	return FORWARD_MAX


static func lateral_distance() -> float:
	return LATERAL_DIST


## Forward Dance travel for a centre-to-centre gap (no target: the full step).
static func forward_travel(gap: float) -> float:
	if gap < 0.0:
		return FORWARD_MAX
	return clampf(gap - FORWARD_STOP, FORWARD_MIN, FORWARD_MAX)


## Lateral direction with a locked target: the chord of the circle around it, so a step of LATERAL_DIST
## starts and ends at the same radius (repeated lateral attacks do not drift out of range). Straight line,
## no steering, no snapping.
static func lateral_chord(tangent: Vector3, to_target: Vector3, radius: float, dist: float) -> Vector3:
	var r := maxf(radius, 0.8)
	var half := asin(clampf(dist / (2.0 * r), 0.0, 1.0))
	return (tangent * cos(half) + to_target * sin(half)).normalized()


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
			if _follow_up():
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
				_committed(clampf((held - HOLD_THRESHOLD) / (COMMIT_MAX - HOLD_THRESHOLD), 0.0, 1.0), held)


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
	if id == "bd_orbit":
		# 004: the circling time follows the arc needed for ORBIT_ANGLE at the current radius (bounded)
		var t = engaged_target()
		if t != null:
			var rad: float = maxf(_flat(hero.global_position - t.global_position).length(), 1.4)
			# 0.88: the circling starts one physics tick late and collision / radius correction cost some
			# arc; the sweep itself stops at the target angle (process), so the margin never over-rotates
			d.startup = clampf(deg_to_rad(orbit_angle()) * rad / (ORBIT_SPEED * 0.88), ORBIT_MIN_T, ORBIT_MAX_T)
	if hero.rt:
		hero.rt.bd_technique(id, d)
	_go(d, id.trim_prefix("bd_"))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Orbit Step sweep target (Extended Orbit augment adds to it; see augment_runtime).
func orbit_angle() -> float:
	var m := 1.0
	if hero.rt and hero.rt.has("rd04_extended_orbit"):
		m = float(hero.rt.pv("rd04_extended_orbit", "angle_mult", 1.2))
	return ORBIT_ANGLE * m


## Augment follow-ups that replace the next LMB (Circling Predator, Blade Reflex). True when one started.
func _follow_up() -> bool:
	if hero.rt == null:
		return false
	var fu: Dictionary = hero.rt.bd_follow_up(mode)
	if fu.is_empty():
		return false
	kit.trigger(String(fu.aug), "%s" % fu.attack.display_name)
	_go(fu.attack, String(fu.kind), {"follow_up": true})
	return true


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
	if hero.rt:
		hero.rt.bd_dance(kind, d, extra)
	_go(d, "dance_" + kind, extra)


func _precision() -> void:
	var d: AttackData = kit.load_attack("bd_precision").clone()
	if hero.rt:
		hero.rt.bd_precision(d)
	_go(d, "precision")


## Committed Cut at a charge ratio (0 = 0.35s hold, 1 = 0.75s), before transformations. Shared with the
## tooltips (LEVEL10-FOUNDATION-005) so the displayed value is the attack the kit actually starts.
static func committed_attack(base: AttackData, ratio: float) -> AttackData:
	var d: AttackData = base.clone()
	d.damage_mult += COMMIT_DMG_BONUS * ratio
	d.poise_damage += COMMIT_POISE_BONUS * ratio
	return d


func _committed(ratio: float, held: float = -1.0) -> void:
	var d: AttackData = committed_attack(kit.load_attack("bd_committed"), ratio)
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
	if hero.rt:
		tr = hero.rt.bd_committed(d, held, tr)
	_go(d, "committed", {"charge": ratio, "transform": tr})


func _go(d: AttackData, kind: String, extra: Dictionary = {}) -> bool:
	var r: AttackRunner = hero.runner
	if hero.stamina <= 0.0 and d.stamina_cost > 0.0:
		return false
	var ctx := {"bd": true, "kind": kind, "mode": mode, "start_pos": hero.global_position}
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
	mult *= float(ctx.get("travel_mult", 1.0))      # Close Pursuit / Dancer's Reversal (augment_runtime)
	var lt = hero.lock_target if hero.lock_target != null and is_instance_valid(hero.lock_target) and hero.lock_target.is_targetable() else null
	match kind:
		"dance_neutral":
			if ctx.get("relentless", false):
				hero.knock_velocity += ref * sqrt(36.0 * 0.5)
		"dance_forward":
			hero.attack_turn_dir = ref
			# 004: meaningful travel when there is room, a short step when already in weapon range
			var gap := -1.0
			var t = lt if lt != null else engaged_target()
			if t != null:
				var to := _flat(t.global_position - hero.global_position)
				if lt != null or rad_to_deg(ref.angle_to(to.normalized())) <= FORWARD_ANGLE:
					gap = to.length()
			var dist := forward_travel(gap) * mult
			last_forward_plan = dist
			hero.knock_velocity += ref * sqrt(36.0 * dist)
		"dance_lateral":
			var side := ref.cross(Vector3.UP).normalized() * float(ctx.get("side", 1))
			hero.attack_turn_dir = ref
			var dist := LATERAL_DIST * mult
			var dir := side
			if lt != null:
				var rv := _flat(hero.global_position - lt.global_position)
				if ctx.get("phantom", false):
					# Phantom Footwork: a curved path around the target (steered in process(), radius kept)
					_lateral = {"target": lt, "radius": maxf(rv.length(), 1.2), "sign": float(ctx.get("side", 1))}
				else:
					dir = lateral_chord(side, -rv.normalized(), rv.length(), dist)
			hero.knock_velocity += dir * sqrt(36.0 * dist)
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
				_orbit = {"target": t, "sign": sgn, "radius": maxf(rv.length(), 1.4), "start": rv.normalized(), "angle": orbit_angle()}
				last_orbit = {"radius": rv.length(), "startup": hero.runner.data.startup, "target_angle": orbit_angle(), "swept": 0.0}


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
	if String(ctx.get("kind", "")) == "whirl" and not ctx.get("whirl_cue_%d" % info.hit_index, false):
		ctx["whirl_cue_%d" % info.hit_index] = true
		PlaceholderSfx.play(hero, "bd_whirl_hit")
		VFX.sword_arc(hero, Color(0.85, 0.92, 1.0), 1.5, 160.0, 1.0, 0.25 * float(info.hit_index % 2 * 2 - 1), 0.14)
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
	_lateral = {}


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
	if _weave and not hero.dodging:
		# chained Weave: the previous one ended this same frame, before process() saw it - still mark it
		weave_completions += 1
		VFX.ground_ring(hero.global_position, 0.7, Color(0.62, 0.78, 1.0), 0.25)
	_weave = true
	_end_charge_fx()
	if mode == "edge":
		mode = "dance"
		mode_switches += 1
		edge_latched = false
	_lmb_in_edge = false


## Combat Weave pose: low crouch, blade swept back along the body (temporary procedural pose).
static func _build_weave() -> Animation:
	var a := Animation.new()
	a.length = 0.42
	var keys := {
		ProcAnim.T_MODEL_POS: [Vector3(0, 0, 0), Vector3(0, -0.3, 0), Vector3(0, -0.08, 0)],
		ProcAnim.T_MODEL_ROT: [Vector3(0, 0, 0), Vector3(-0.25, 0.0, 0.18), Vector3(0, 0, 0)],
		ProcAnim.T_WEAPON_ROT: [Vector3(0.3, 0.6, 0.2), Vector3(1.2, 1.4, 0.4), Vector3(0.4, 0.7, 0.2)],
		ProcAnim.T_WEAPON_POS: [Vector3(0.3, 1.0, -0.2), Vector3(0.35, 0.8, 0.25), Vector3(0.3, 0.95, -0.15)],
	}
	for path in keys:
		var i := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(path))
		a.track_insert_key(i, 0.0, keys[path][0])
		a.track_insert_key(i, 0.16, keys[path][1])
		a.track_insert_key(i, 0.42, keys[path][2])
	return a


## Committed Cut at full charge: blade drawn high and back, weight on the rear foot.
static func _build_full_pose() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	var keys := {
		ProcAnim.T_WEAPON_ROT: [Vector3(-0.6, 1.1, 0.5), Vector3(-0.65, 1.1, 0.5)],
		ProcAnim.T_WEAPON_POS: [Vector3(0.38, 1.35, 0.18), Vector3(0.38, 1.37, 0.18)],
		ProcAnim.T_MODEL_POS: [Vector3(0, -0.2, 0.06), Vector3(0, -0.21, 0.06)],
		ProcAnim.T_MODEL_ROT: [Vector3(0, -0.55, 0), Vector3(0, -0.55, 0)],
	}
	for path in keys:
		var i := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(path))
		a.track_insert_key(i, 0.0, keys[path][0])
		a.track_insert_key(i, 0.3, keys[path][1])
		a.track_insert_key(i, 0.6, keys[path][0])
	return a


## Committed Cut charge feedback (004 Part 2.7): a restrained glow grows from the 0.35s threshold; at the
## 0.75s maximum ONE short cue, a blade highlight and the drawn pose. Cancelling clears everything. Purely
## presentational: damage still comes only from the existing charge ratio.
func _update_charge_fx() -> void:
	if kit.charging != "edge_lmb":
		_end_charge_fx()
		return
	var t: float = kit.charge_t
	if t < HOLD_THRESHOLD:
		return
	if not is_instance_valid(_cfx):
		_cfx = ChargeFX.attach(hero, "steel")
	var full := t >= COMMIT_MAX
	_cfx.set_ratio(clampf((t - HOLD_THRESHOLD) / (COMMIT_MAX - HOLD_THRESHOLD), 0.0, 1.0) * 0.6, full)
	if full and not _full_cued:
		_full_cued = true
		full_charge_cues += 1
		PlaceholderSfx.play(hero, "bd_full_charge")
		_blade_glow = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 1.15)
		_blade_glow.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.92, 0.75, 0.75)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.85, 0.6)
		m.emission_energy_multiplier = 4.0
		_blade_glow.material_override = m
		_blade_glow.position = Vector3(0, 0, -0.78)
		hero.weapon_pivot.add_child(_blade_glow)
		if not hero.anim_lib.has_animation(FULL_POSE_ANIM):
			hero.anim_lib.add_animation(FULL_POSE_ANIM, _build_full_pose())
		hero.anim.play(FULL_POSE_ANIM, 0.08)


func _end_charge_fx() -> void:
	if is_instance_valid(_cfx):
		_cfx.finish()
	_cfx = null
	if is_instance_valid(_blade_glow):
		_blade_glow.queue_free()
	_blade_glow = null
	_full_cued = false


func charge_fx_active() -> bool:
	return is_instance_valid(_cfx)


func blade_highlight_active() -> bool:
	return is_instance_valid(_blade_glow)


## 006 dodge clarity: a real enemy attack passed through the Combat Weave i-frames. One short, restrained cue
## (afterimage burst + "EVADED" + soft tone); no meter, no reward state.
func on_evade(info: DamageInfo) -> void:
	evades += 1
	if Game.time - _last_evade_fx < 0.25:
		return
	_last_evade_fx = Game.time
	VFX.particles(hero.global_position + Vector3(0, 1.0, 0), VFX._quad(0.18), VFX._billboard(Color(0.7, 0.85, 1.0), 2.5), 14, 0.3,
		{"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE, "radius": 0.45, "vmin": 0.5, "vmax": 1.5, "gravity": Vector3.ZERO})
	if hero.is_player:
		FX.number(hero, "EVADED", Color(0.7, 0.9, 1.0), 0.8)
		PlaceholderSfx.play(hero, "evade")


func process(_delta: float) -> void:
	var r: AttackRunner = hero.runner
	# Orbit Step: circle the target during the startup (collision still applies)
	if not _orbit.is_empty():
		var t = _orbit.get("target")
		var swept := 0.0
		if is_instance_valid(t):
			var cur := _flat(hero.global_position - t.global_position)
			if cur.length() > 0.05:
				swept = rad_to_deg(Vector3(_orbit.start).angle_to(cur.normalized()))
				last_orbit["swept"] = swept
		if r.is_busy() and r.ctx.get("kind", "") == "orbit" and r.phase == AttackRunner.Phase.STARTUP and is_instance_valid(t) and t.is_targetable() and swept < float(_orbit.angle):
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
	# Phantom Footwork: keep the lateral impulse on the circle (its speed still decays normally)
	if not _lateral.is_empty():
		var lt = _lateral.get("target")
		var sp := _flat(hero.knock_velocity).length()
		if r.is_busy() and r.ctx.get("kind", "") == "dance_lateral" and is_instance_valid(lt) and lt.is_targetable() and sp > 0.2:
			var rv := _flat(hero.global_position - lt.global_position)
			if rv.length() > 0.05:
				var tangent := Vector3.UP.cross(rv.normalized()) * -float(_lateral.sign)
				var radial: Vector3 = rv.normalized() * (float(_lateral.radius) - rv.length()) * 3.0
				hero.knock_velocity = tangent * sp + radial
		else:
			_lateral = {}
	# Whirling Assault: stay engaged - a bounded drift toward the locked target while the hits run
	if r.is_busy() and r.ctx.get("kind", "") == "whirl" and r.phase == AttackRunner.Phase.ACTIVE:
		var wt = hero.lock_target
		if wt != null and is_instance_valid(wt) and wt.is_targetable():
			var to := _flat(wt.global_position - hero.global_position)
			if to.length() > WHIRL_ENGAGE_GAP and to.length() < ENGAGE_RADIUS:
				hero.knock_velocity = hero.knock_velocity.move_toward(to.normalized() * WHIRL_ENGAGE_SPEED, 30.0 * _delta)
	# Combat Weave: its own defensive motion (crouched slip, blade held back) instead of the generic dodge
	if _weave:
		if hero.dodging:
			if hero.anim.current_animation == "dodge":
				if not hero.anim_lib.has_animation(WEAVE_ANIM):
					hero.anim_lib.add_animation(WEAVE_ANIM, _build_weave())
				hero.anim.play(WEAVE_ANIM, 0.05, 1.0)
				VFX.particles(hero.global_position + Vector3(0, 0.15, 0), VFX._quad(0.12), VFX._billboard(Color(0.62, 0.78, 1.0), 2.0), 10, 0.35,
					{"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE, "radius": 0.35, "vmin": 0.2, "vmax": 0.8, "gravity": Vector3(0, 0.6, 0)})
		else:
			_weave = false
			# completion: control is back - a small dust ring where the Weave ended
			weave_completions += 1
			VFX.ground_ring(hero.global_position, 0.7, Color(0.62, 0.78, 1.0), 0.25)
	_update_charge_fx()
	# Twin Verdict: the second impact may correct its angle slightly toward the locked target (not homing)
	if r.is_busy() and r.ctx.get("transform", "") == "twin_verdict" and r.phase == AttackRunner.Phase.ACTIVE and r.hit_index == 1 and not r.ctx.get("tv_corrected", false):
		r.ctx["tv_corrected"] = true
		var tl = hero.lock_target
		if tl != null and is_instance_valid(tl) and tl.is_targetable():
			var to := _flat(tl.global_position - hero.global_position)
			var lim := deg_to_rad(float(hero.rt.pv("re05_twin_verdict", "correction_deg", 15.0)) if hero.rt else 15.0)
			var ang: float = hero.forward().signed_angle_to(to.normalized(), Vector3.UP)
			hero.rotation.y += clampf(ang, -lim, lim)
	# Tempest Waltz: exactly one controlled redirection of the Whirling Assault movement
	if r.is_busy() and r.ctx.get("kind", "") == "whirl" and r.phase == AttackRunner.Phase.ACTIVE and hero.rt and hero.rt.has("rd05_tempest_waltz"):
		var m := _input_dir()
		if not r.ctx.has("tw_dir"):
			r.ctx["tw_dir"] = m
		elif not r.ctx.get("tw_used", false) and m != Vector3.ZERO and (Vector3(r.ctx.tw_dir) == Vector3.ZERO or rad_to_deg(Vector3(r.ctx.tw_dir).angle_to(m)) > 60.0):
			r.ctx["tw_used"] = true
			hero.knock_velocity = m * sqrt(36.0 * 0.6)
			kit.trigger("rd05_tempest_waltz", "Whirling Assault redirected")
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
