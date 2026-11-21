extends "res://tests/level10_runner.gd"
## COMBAT-BALANCE-UX-006 Milestone A: diagnosis probe (measurement only, NOT pass/fail, not in Test.ps1).
##   godot --headless --fixed-fps 60 res://tests/combat006_probe.tscn
## 1. Enemy tracking: each enemy attack aimed at a Reaver who dodges / walks at several timings before
##    impact. Records the enemy's facing change from the dodge to the impact, whether the hit landed, and
##    whether avoidance came from movement or i-frames.
## 2. Camera: frame-by-frame camera yaw / position during Reaver lateral Dance (locked / unlocked), A walk,
##    A + Space, A + Q; counts abnormal jumps (yaw acceleration / position jerk spikes).

const ATTACKS := [["raider", "raider_combo1"], ["raider", "raider_combo2"], ["raider", "raider_heavy"], ["wolf", "wolf_bite"], ["wolf", "wolf_lunge"],
	["shield_guardian", "guardian_bash"], ["shield_guardian", "guardian_slam"], ["ashen_warden", "warden_slash1"], ["ashen_warden", "warden_breaker"], ["ashen_warden", "warden_execution"]]
const TIMINGS := [0.4, 0.25, 0.12]     # seconds before the hit window opens
var lines: Array = []
var got_hit: bool = false
var dodged: bool = false


func _run_all() -> void:
	Events.damage_applied.connect(func(info): if is_instance_valid(Game.player) and info.target == Game.player and info.final_amount > 0.0: got_hit = true)
	Events.guard_event.connect(func(d, _i, k): if d == Game.player and k == "dodge": dodged = true)
	if OS.get_environment("PROBE_DBG") == "1":
		await _dbg_lock()
	else:
		await tracking()
		await camera()
	print("\n==== 006 PROBE RESULTS ====")
	for l in lines:
		print(l)
	print("==== 006 PROBE: done ====")
	await teardown()


func tracking() -> void:
	var total := {"dodge": 0, "avoided": 0, "walk": 0, "walk_avoided": 0}
	for spec in ATTACKS:
		for how in ["left", "right", "back", "walk_side"]:
			for tb in TIMINGS:
				var h := await bd(10)
				Game.invincible = false
				h.max_hp = 99999
				h.hp = 99999
				var e := dummy(String(spec[0]), h.global_position + Vector3(0, 0, -1.9))
				e.max_hp = 999999
				e.hp = 999999
				e.target = h
				face(e, h)
				h.lock_target = e
				face(h, e)
				await wait(0.1)
				var d: AttackData = e.find_attack(String(spec[1]))
				if d == null:
					d = load("res://data/attacks/%s.tres" % spec[1])
				got_hit = false
				dodged = false
				e.begin_attack(d)
				var startup: float = d.startup / maxf(e.runner.speed, 0.1)
				var acted := false
				var yaw0 := 0.0
				var t := 0.0
				var impact_yaw := 0.0
				var impact_t := -1.0
				while t < startup + d.active + 0.3:
					var remaining: float = startup - t
					if not acted and remaining <= tb:
						acted = true
						yaw0 = e.rotation.y
						var to: Vector3 = e.global_position - h.global_position
						to.y = 0
						var right := to.normalized().cross(Vector3.UP)
						match how:
							"left":
								h.move_input = -right
								h.try_dodge()
							"right":
								h.move_input = right
								h.try_dodge()
							"back":
								h.move_input = -to.normalized()
								h.try_dodge()
							"walk_side":
								h.move_input = right
					if how != "walk_side" and acted and not h.dodging:
						h.move_input = Vector3.ZERO
					if impact_t < 0.0 and e.runner.phase == AttackRunner.Phase.ACTIVE:
						impact_t = t
						impact_yaw = e.rotation.y
					await get_tree().physics_frame
					t += 1.0 / 60.0
				h.move_input = Vector3.ZERO
				var turn := rad_to_deg(absf(wrapf(impact_yaw - yaw0, -PI, PI)))
				var res := "HIT" if got_hit else ("i-frames" if dodged else "moved clear")
				if how == "walk_side":
					total.walk += 1
					if not got_hit:
						total.walk_avoided += 1
				else:
					total.dodge += 1
					if not got_hit:
						total.avoided += 1
				lines.append("TRACK | %-16s | %-9s | %.2fs before | enemy turned %5.1f deg before impact | %s" % [spec[1], how, tb, turn, res])
				e.queue_free()
	lines.append("TRACK SUMMARY | dodges avoided %d / %d | side walks avoided %d / %d" % [total.avoided, total.dodge, total.walk_avoided, total.walk])


func _rig() -> CameraRig:
	for n in Game.world.get_children():
		if n is CameraRig:
			return n
	return null


func _cam_run(label: String, setup_fn: Callable, step_fn: Callable, frames: int) -> void:
	var h := await bd(10)
	var e := target(h, 1.8)
	e.max_poise = 999999
	e.poise = 999999
	await setup_fn.call(h, e)
	var rig := _rig()
	await wait(0.3)
	var yaws: Array = []
	var poss: Array = []
	var hps: Array = []
	for f in frames:
		step_fn.call(h, e, f)
		await get_tree().physics_frame
		await get_tree().process_frame
		yaws.append(rig.yaw)
		poss.append(rig.global_position)
		hps.append(h.global_position)
	h.move_input = Vector3.ZERO
	var max_acc := 0.0
	var yaw_spikes := 0
	var max_jerk := 0.0
	var pos_spikes := 0
	var hero_jerk := 0.0
	for i in range(2, frames):
		var v1: float = wrapf(yaws[i - 1] - yaws[i - 2], -PI, PI)
		var v2: float = wrapf(yaws[i] - yaws[i - 1], -PI, PI)
		var acc := absf(v2 - v1) * 3600.0      # rad/s^2
		max_acc = maxf(max_acc, acc)
		if acc > 60.0:
			yaw_spikes += 1
		var a1: Vector3 = poss[i - 1] - poss[i - 2]
		var a2: Vector3 = poss[i] - poss[i - 1]
		var jerk := (a2 - a1).length() * 3600.0  # m/s^2
		max_jerk = maxf(max_jerk, jerk)
		if jerk > 150.0:
			pos_spikes += 1
		var b1: Vector3 = hps[i - 1] - hps[i - 2]
		var b2: Vector3 = hps[i] - hps[i - 1]
		hero_jerk = maxf(hero_jerk, (b2 - b1).length() * 3600.0)
	lines.append("CAMERA | %-34s | yaw accel max %6.1f rad/s2, spikes>60: %3d | cam pos accel max %6.1f m/s2, spikes>150: %3d | hero accel max %6.1f m/s2" % [label, max_acc, yaw_spikes, max_jerk, pos_spikes, hero_jerk])
	e.queue_free()


func camera() -> void:
	var lat := func(h, e, f):
		if f % 30 == 0:
			var to: Vector3 = e.global_position - h.global_position
			to.y = 0
			h.move_input = to.normalized().cross(Vector3.UP)
			tap(h, "light")
		elif f % 30 == 3:
			h.move_input = Vector3.ZERO
	var noop := func(_h, _e): pass
	var unlock := func(h, _e): h.lock_target = null
	await _cam_run("locked: repeated lateral Dance (A+LMB)", noop, lat, 240)
	await _cam_run("unlocked: repeated lateral Dance (A+LMB)", unlock, lat, 240)
	await _cam_run("locked: A walk", noop, func(h, e, _f):
		var to: Vector3 = e.global_position - h.global_position
		to.y = 0
		h.move_input = to.normalized().cross(Vector3.UP), 240)
	await _cam_run("unlocked: A walk", unlock, func(h, _e, _f): h.move_input = Vector3(-1, 0, 0), 240)
	await _cam_run("locked: A + Space every 0.75s", noop, func(h, e, f):
		if f % 45 == 0:
			var to: Vector3 = e.global_position - h.global_position
			to.y = 0
			h.move_input = to.normalized().cross(Vector3.UP)
			h.try_dodge()
		elif f % 45 == 3:
			h.move_input = Vector3.ZERO, 240)
	await _cam_run("locked: A + Q (Orbit Step) every 1s", noop, func(h, e, f):
		if f % 60 == 0:
			h.stamina = h.max_stamina
			var to: Vector3 = e.global_position - h.global_position
			to.y = 0
			h.move_input = to.normalized().cross(Vector3.UP)
			tap(h, "footwork")
		elif f % 60 == 3:
			h.move_input = Vector3.ZERO, 240)
	# reference: Vanguard strafing around a locked target
	var hv := await setup("vanguard", false, false, false)
	Game.set_level("vanguard", 10)
	await wait(0.2)
	for c in hv.get_children():
		if c is PlayerBrain:
			c.set_physics_process(false)
	var ev := target(hv, 1.8)
	var rig := _rig()
	await wait(0.3)
	var yaws: Array = []
	for f in 240:
		var to: Vector3 = ev.global_position - hv.global_position
		to.y = 0
		hv.move_input = to.normalized().cross(Vector3.UP)
		await get_tree().physics_frame
		await get_tree().process_frame
		yaws.append(rig.yaw)
	var mx := 0.0
	var sp := 0
	for i in range(2, yaws.size()):
		var acc := absf(wrapf(yaws[i] - yaws[i - 1], -PI, PI) - wrapf(yaws[i - 1] - yaws[i - 2], -PI, PI)) * 3600.0
		mx = maxf(mx, acc)
		if acc > 60.0:
			sp += 1
	lines.append("CAMERA | %-34s | yaw accel max %6.1f rad/s2, spikes>60: %3d (reference)" % ["Vanguard locked strafe", mx, sp])


func _dbg_lock() -> void:
	var h := await bd(10)
	var e := target(h, 1.8)
	var rig := _rig()
	await wait(0.5)
	var prev := {}
	var pp: Array = []
	for f in 240:
		var to: Vector3 = e.global_position - h.global_position
		to.y = 0
		h.move_input = to.normalized().cross(Vector3.UP)
		await get_tree().physics_frame
		await get_tree().process_frame
		var d := Vector2(to.x, to.z).length()
		pp.append(rig.global_position)
		var acc := 0.0
		if pp.size() >= 3:
			acc = ((pp[-1] - pp[-2]) - (pp[-2] - pp[-3])).length() * 3600.0
		if acc > 150.0 or f < 2:
			lines.append("DBG acc %.0f f%02d d %.3f yaw %.4f pitch %.4f cur_dist %.3f frame_dist %.3f shift %s offfrac %.3f lift %.3f want %.3f target %.3f blocked %s pos %s" % [acc, f, d, rig.yaw, rig.pitch, rig.cur_dist, rig.frame_dist, str(rig.shift.snapped(Vector3.ONE * 0.001)), rig._offset_frac, rig.cam_lift, rig.dbg_want, rig.dbg_target, str(rig.dbg_blocked), str(rig.global_position.snapped(Vector3.ONE * 0.001))])