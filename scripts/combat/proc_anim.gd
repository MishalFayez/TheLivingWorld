class_name ProcAnim
extends RefCounted
## Builds AnimationPlayer animations from AttackData timings, so every attack animation is
## automatically in sync with its startup / active / recovery windows (and with balance edits).
## Tracks animate the primitive rig: Model (body), WeaponPivot (sword/staff/claws), ShieldPivot.

const T_MODEL_ROT := "Model:rotation"
const T_MODEL_POS := "Model:position"
const T_WEAPON_ROT := "Model/WeaponPivot:rotation"
const T_WEAPON_POS := "Model/WeaponPivot:position"
const T_SHIELD_POS := "Model/ShieldPivot:position"
const T_SHIELD_ROT := "Model/ShieldPivot:rotation"

const REST := {
	T_MODEL_ROT: Vector3.ZERO,
	T_MODEL_POS: Vector3.ZERO,
	T_WEAPON_ROT: Vector3(-0.6, 0, 0),
	T_WEAPON_POS: Vector3(0.38, 1.15, -0.1),
	T_SHIELD_POS: Vector3(-0.42, 1.1, -0.25),
	T_SHIELD_ROT: Vector3.ZERO,
}


static func _new_anim(length: float) -> Array:
	var a := Animation.new()
	a.length = maxf(length, 0.05)
	var tracks := {}
	for path in REST.keys():
		var idx := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(idx, NodePath(path))
		a.track_insert_key(idx, 0.0, REST[path])
		a.track_insert_key(idx, a.length, REST[path])
		tracks[path] = idx
	return [a, tracks]


static func _k(a: Animation, tracks: Dictionary, path: String, time: float, value) -> void:
	a.track_insert_key(tracks[path], clampf(time, 0.0, a.length), value)


## hold_windup: the wind-up pose is reached at 55% of startup and HELD (slightly exaggerated) until
## the swing — enemies use this so their attacks are readable before the damage window.
static func build_attack(d: AttackData, hold_windup: bool = false) -> Animation:
	var made := _new_anim(d.total_time())
	var a: Animation = made[0]
	var tr: Dictionary = made[1]
	var s := d.startup
	var e := d.startup + d.active
	var wp: Vector3 = REST[T_WEAPON_POS]
	var sp: Vector3 = REST[T_SHIELD_POS]
	match d.anim_style:
		"slash_h":
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.1, 1.7, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.1, -1.7, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.35, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -0.35, 0))
		"sweep":
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.2, 2.3, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.2, -2.3, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.7, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -0.7, 0))
			_k(a, tr, T_MODEL_POS, s, Vector3(0, -0.15, 0))
		"slash_v", "slam":
			_k(a, tr, T_WEAPON_ROT, s, Vector3(2.4, 0, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-1.3, 0, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0.25, 0, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.3 if d.anim_style == "slam" else -0.15, 0, 0))
			if d.anim_style == "slam":
				_k(a, tr, T_MODEL_POS, s, Vector3(0, 0.15, 0.1))
				_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.3, -0.25))
		"rising":
			_k(a, tr, T_WEAPON_ROT, s, Vector3(-1.5, 0.4, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(2.1, -0.2, 0))
			_k(a, tr, T_MODEL_POS, s, Vector3(0, -0.3, 0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, 0.5, -0.2))
		"thrust":
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0, 0, 0))
			_k(a, tr, T_WEAPON_POS, s, wp + Vector3(0, 0, 0.45))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0, 0, 0))
			_k(a, tr, T_WEAPON_POS, e, wp + Vector3(-0.2, 0, -1.0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, 0, -0.35))
		"spin":
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0, 1.57, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0, 1.57, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3.ZERO)
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -TAU, 0))
			_k(a, tr, T_MODEL_ROT, minf(e + 0.001, a.length), Vector3.ZERO)
		"flurry":
			var n := maxi(d.hits, 2)
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.1, 1.4, 0))
			for i in n:
				var ti := s + d.active * (float(i) + 0.9) / float(n)
				var side := -1.4 if i % 2 == 0 else 1.4
				_k(a, tr, T_WEAPON_ROT, ti, Vector3(0.1 + 0.15 * (i % 3), side, 0))
				_k(a, tr, T_MODEL_ROT, ti, Vector3(0, side * 0.2, 0))
		"bash":
			_k(a, tr, T_SHIELD_POS, s, sp + Vector3(0.1, 0, 0.25))
			_k(a, tr, T_SHIELD_POS, e, sp + Vector3(0.25, 0, -0.75))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.45, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -0.1, 0))
		"cast":
			_k(a, tr, T_WEAPON_ROT, s, Vector3(1.6, 0, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.1, 0, 0))
		# Grand Elementalist release + recovery: each element has its own body language
		"cast_fire":     # explosive forward thrust
			_k(a, tr, T_WEAPON_ROT, s, Vector3(1.3, 0.7, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-0.3, -0.3, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.35, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.12, -0.2, 0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, 0, -0.18))
		"cast_frost":    # precise: staff planted, structure rises
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.5, 0, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-1.05, 0, 0))
			_k(a, tr, T_WEAPON_POS, e, wp + Vector3(-0.1, -0.25, -0.2))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.14, 0))
		"cast_stone":    # heavy overhead slam
			_k(a, tr, T_WEAPON_ROT, s, Vector3(2.7, 0, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-1.1, 0, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(-0.15, 0, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0.3, 0, 0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.2, -0.12))
		"cast_storm":    # sharp, unstable snap from raised staff
			_k(a, tr, T_WEAPON_ROT, s, Vector3(2.9, 0, 0.35))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.1, 0, -0.25))
			_k(a, tr, T_WEAPON_POS, s, wp + Vector3(0, 0.35, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.08, 0.15, 0))
		"cast_life":     # controlled, restorative lift
			_k(a, tr, T_WEAPON_ROT, s, Vector3(1.5, 0, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(1.9, 0, 0))
			_k(a, tr, T_WEAPON_POS, s, wp + Vector3(-0.22, 0.1, -0.25))
			_k(a, tr, T_WEAPON_POS, e, wp + Vector3(-0.22, 0.35, -0.25))
		"lunge":
			_k(a, tr, T_MODEL_POS, s, Vector3(0, -0.2, 0.35))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0.25, 0, 0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, 0.3, -0.5))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.3, 0, 0))
		"bite":
			_k(a, tr, T_MODEL_ROT, s, Vector3(0.4, 0, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.45, 0, 0))
		# REAVER-FREEFLOW-002 (used only by Free Flow Reaver attacks; temporary procedural motion)
		"ff_pursuit_slash":   # low forward lean, blade drawn from low-left across to high-right
			_k(a, tr, T_MODEL_POS, s * 0.5, Vector3(0, -0.22, 0.05))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0.3, -0.3, 0))
			_k(a, tr, T_WEAPON_ROT, s, Vector3(1.0, -1.6, 0.4))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.05, -0.35))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.1, 0.35, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-0.9, 1.7, -0.3))
		"ff_counter":         # sharp turn-in: body snaps round, quick reverse horizontal cut
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, -0.55, 0))
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.1, -1.9, 0))
			_k(a, tr, T_MODEL_POS, s, Vector3(0, -0.12, 0.1))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, 0.45, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.1, 1.9, 0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, 0, -0.3))
	if d.anim_style.begins_with("bd_"):
		_blade_dancer(a, tr, d, s, e, wp)
	if hold_windup and s > 0.1:
		_hold_windup(a, s)
	return a


## REAVER-BLADEDANCER-003 motions (used only by Blade Dancer attacks; temporary procedural animation).
## Each attack has its own body language so the nine techniques read differently.
static func _blade_dancer(a: Animation, tr: Dictionary, d: AttackData, s: float, e: float, wp: Vector3) -> void:
	match d.anim_style:
		"bd_neutral":       # compact diagonal cut, feet planted
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.9, 1.2, 0.3))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-0.5, -1.3, -0.2))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.2, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -0.2, 0))
		"bd_forward":       # lunge-step: body leans in, blade sweeps low to high across the advance
			_k(a, tr, T_MODEL_POS, s, Vector3(0, -0.15, 0.1))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0.25, 0.25, 0))
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.5, 1.5, 0.5))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.05, -0.4))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.1, -0.3, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-0.4, -1.6, -0.3))
		"bd_lateral_r", "bd_lateral_l":   # body leans into the side step, cut travels with it
			var sd := 1.0 if d.anim_style == "bd_lateral_r" else -1.0
			_k(a, tr, T_MODEL_POS, s, Vector3(-0.2 * sd, -0.12, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.45 * sd, 0.18 * sd))
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.2, 1.8 * sd, 0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0.25 * sd, -0.05, -0.1))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -0.35 * sd, -0.12 * sd))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.2, -1.6 * sd, 0))
		"bd_precision":     # still, exact: short draw back then a straight, narrow extension
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.05, 0.1, 0))
			_k(a, tr, T_WEAPON_POS, s, wp + Vector3(0.05, 0.05, 0.35))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.35, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.0, 0.0, 0))
			_k(a, tr, T_WEAPON_POS, e, wp + Vector3(-0.3, 0.05, -1.15))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -0.1, 0))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.08, -0.25))
		"bd_committed":     # big two-handed rising-to-crashing diagonal, weight drops through the target
			_k(a, tr, T_MODEL_POS, s, Vector3(0, 0.08, 0.15))
			_k(a, tr, T_MODEL_ROT, s, Vector3(-0.15, 0.55, 0))
			_k(a, tr, T_WEAPON_ROT, s, Vector3(2.6, 0.9, 0.4))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.32, -0.35))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0.35, -0.45, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-1.4, -0.9, -0.3))
		"bd_orbit":         # turning step around the target, blade trailing, then a snap cut
			_k(a, tr, T_MODEL_ROT, s * 0.5, Vector3(0, 0.6, 0))
			_k(a, tr, T_MODEL_POS, s * 0.5, Vector3(0, -0.18, 0))
			_k(a, tr, T_WEAPON_ROT, s * 0.5, Vector3(0.1, 2.0, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0, 0.3, 0))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0, -0.5, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(0.2, -1.8, 0))
		"bd_withdraw":      # body pulls back and down, blade held level, then a long thrust
			_k(a, tr, T_MODEL_POS, s * 0.6, Vector3(0, -0.2, 0.3))
			_k(a, tr, T_MODEL_ROT, s * 0.6, Vector3(-0.2, 0, 0))
			_k(a, tr, T_WEAPON_ROT, s * 0.6, Vector3(0, 0, 0))
			_k(a, tr, T_WEAPON_POS, s, wp + Vector3(0, -0.05, 0.5))
			_k(a, tr, T_WEAPON_POS, e, wp + Vector3(-0.3, 0, -1.35))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.1, -0.45))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0.2, 0, 0))
		"bd_whirl":         # continuous turning slashes
			var n := maxi(d.hits, 2)
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.1, 1.57, 0))
			for i in n:
				var ti := s + d.active * (float(i) + 1.0) / float(n)
				_k(a, tr, T_MODEL_ROT, ti, Vector3(0, -TAU * float(i + 1) / float(n) * 0.5, 0))
				_k(a, tr, T_WEAPON_ROT, ti, Vector3(0.1 + 0.2 * (i % 2), 1.57 if i % 2 == 0 else -1.2, 0))
			_k(a, tr, T_MODEL_ROT, minf(e + 0.001, a.length), Vector3.ZERO)
		"bd_break":         # deliberate overhead set, then a narrow downward drive through the guard
			_k(a, tr, T_WEAPON_ROT, s * 0.7, Vector3(2.9, 0, 0))
			_k(a, tr, T_WEAPON_POS, s * 0.7, wp + Vector3(-0.2, 0.35, 0.1))
			_k(a, tr, T_MODEL_POS, s, Vector3(0, 0.12, 0.1))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-0.9, 0, 0))
			_k(a, tr, T_WEAPON_POS, e, wp + Vector3(-0.3, -0.25, -0.75))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.35, -0.3))
			_k(a, tr, T_MODEL_ROT, e, Vector3(0.4, 0, 0))
		"bd_relentless":    # Relentless Dance: low spinning re-entry cut
			_k(a, tr, T_MODEL_POS, s, Vector3(0, -0.28, 0))
			_k(a, tr, T_MODEL_ROT, s, Vector3(0.2, 0.9, 0))
			_k(a, tr, T_WEAPON_ROT, s, Vector3(0.3, 2.1, 0.6))
			_k(a, tr, T_MODEL_ROT, e, Vector3(-0.1, -0.6, 0))
			_k(a, tr, T_WEAPON_ROT, e, Vector3(-0.6, -1.9, -0.4))
			_k(a, tr, T_MODEL_POS, e, Vector3(0, -0.05, -0.3))
		"bd_twin":          # Twin Tempest: alternating heavy cuts, the last one overhead
			var n2 := maxi(d.hits, 2)
			for i in n2:
				var ti2 := s + d.active * (float(i) + 0.9) / float(n2)
				var last := i == n2 - 1
				_k(a, tr, T_WEAPON_ROT, ti2, Vector3(-1.3, 0, 0) if last else Vector3(0.3, -1.6 if i % 2 == 0 else 1.6, 0))
				_k(a, tr, T_MODEL_ROT, ti2, Vector3(0.3, 0, 0) if last else Vector3(0, 0.3 if i % 2 == 0 else -0.3, 0))
			_k(a, tr, T_WEAPON_ROT, s, Vector3(2.4, 0.6, 0))


static func _hold_windup(a: Animation, s: float) -> void:
	for idx in a.get_track_count():
		for k in a.track_get_key_count(idx):
			if absf(a.track_get_key_time(idx, k) - s) < 0.0005:
				var v = a.track_get_key_value(idx, k)
				var rest = a.track_get_key_value(idx, 0)
				# reach the pose early, then lean further into it (anticipation)
				a.track_insert_key(idx, s * 0.55, v)
				if v is Vector3 and rest is Vector3:
					a.track_set_key_value(idx, k, rest + (v - rest) * 1.12)
				break


static func add_base_animations(lib: AnimationLibrary) -> void:
	# idle
	var m := _new_anim(1.2)
	var a: Animation = m[0]
	_k(a, m[1], T_MODEL_POS, 0.6, Vector3(0, 0.04, 0))
	a.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("idle", a)
	# stagger
	m = _new_anim(0.6)
	a = m[0]
	_k(a, m[1], T_MODEL_ROT, 0.1, Vector3(0.45, 0.2, 0))
	_k(a, m[1], T_WEAPON_ROT, 0.1, Vector3(1.0, 0.8, 0))
	lib.add_animation("stagger", a)
	# dodge roll
	m = _new_anim(0.42)
	a = m[0]
	_k(a, m[1], T_MODEL_ROT, 0.36, Vector3(-TAU, 0, 0))
	_k(a, m[1], T_MODEL_ROT, 0.361, Vector3.ZERO)
	_k(a, m[1], T_MODEL_POS, 0.18, Vector3(0, -0.35, 0))
	lib.add_animation("dodge", a)
	# downed (held)
	m = _new_anim(0.5)
	a = m[0]
	_hold(a, m[1], T_MODEL_ROT, Vector3(1.45, 0, 0))
	_hold(a, m[1], T_MODEL_POS, Vector3(0, 0.25, 0))
	lib.add_animation("downed", a)
	# guard pose (held)
	m = _new_anim(0.12)
	a = m[0]
	_hold(a, m[1], T_SHIELD_POS, REST[T_SHIELD_POS] + Vector3(0.3, 0.05, -0.35))
	_hold(a, m[1], T_WEAPON_ROT, Vector3(0.6, 0.4, 0))
	lib.add_animation("guard", a)
	# charge pose (held)
	m = _new_anim(0.25)
	a = m[0]
	_hold(a, m[1], T_WEAPON_ROT, Vector3(2.4, 0.3, 0))
	_hold(a, m[1], T_MODEL_POS, Vector3(0, -0.12, 0.1))
	lib.add_animation("charge", a)
	# cast hold (held)
	m = _new_anim(0.25)
	a = m[0]
	_hold(a, m[1], T_WEAPON_ROT, Vector3(1.8, 0, 0))
	lib.add_animation("cast_hold", a)
	# Grand Elementalist charge poses (held): energy is gathered differently per element
	var wp: Vector3 = REST[T_WEAPON_POS]
	var poses := {
		"fire": [[T_WEAPON_ROT, Vector3(1.3, 0.7, 0)], [T_MODEL_ROT, Vector3(0, 0.35, 0)], [T_MODEL_POS, Vector3(0, -0.08, 0.08)]],
		"frost": [[T_WEAPON_ROT, Vector3(0.5, 0, 0)], [T_WEAPON_POS, wp + Vector3(-0.12, 0.0, -0.2)], [T_MODEL_POS, Vector3(0, -0.06, 0)]],
		"stone": [[T_WEAPON_ROT, Vector3(2.7, 0, 0)], [T_MODEL_ROT, Vector3(-0.15, 0, 0)], [T_MODEL_POS, Vector3(0, -0.12, 0.06)]],
		"storm": [[T_WEAPON_ROT, Vector3(2.9, 0, 0.35)], [T_WEAPON_POS, wp + Vector3(0, 0.35, 0)]],
		"life": [[T_WEAPON_ROT, Vector3(1.5, 0, 0)], [T_WEAPON_POS, wp + Vector3(-0.22, 0.1, -0.25)]],
	}
	for el in poses:
		m = _new_anim(0.3)
		a = m[0]
		for kv in poses[el]:
			_hold(a, m[1], kv[0], kv[1])
		lib.add_animation("charge_" + el, a)


static func _hold(a: Animation, tr: Dictionary, path: String, value) -> void:
	var idx: int = tr[path]
	# replace the end key with the held value, ramp in over the first 40%
	a.track_remove_key(idx, a.track_get_key_count(idx) - 1)
	a.track_insert_key(idx, a.length * 0.4, value)
	a.track_insert_key(idx, a.length, value)
