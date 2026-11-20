class_name AttackRunner
extends Node
## Executes one AttackData through STARTUP -> ACTIVE -> RECOVERY with configurable cancel windows.
## Multi-hit attacks divide the ACTIVE window into `hits` sub-windows; every sub-window can hit each
## target once. Damage is built by the owning Combatant (so class kits can modify it).

signal started(data: AttackData, ctx: Dictionary)
signal active_started(data: AttackData, ctx: Dictionary)
signal hit_window(index: int)
signal hit_landed(target: Node, info: DamageInfo)
signal recovery_started(data: AttackData)
signal finished(data: AttackData, ctx: Dictionary, interrupted: bool)

enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

var c = null
var data: AttackData = null
var ctx: Dictionary = {}
var phase: int = Phase.NONE
var t: float = 0.0
var speed: float = 1.0
var hit_index: int = -1
var registry: Dictionary = {}
var connected_indices: Dictionary = {}
var targets_hit: Dictionary = {}
var cancel_override: bool = false


func is_busy() -> bool:
	return phase != Phase.NONE


func in_phase(p: int) -> bool:
	return phase == p


func start(d: AttackData, p_ctx: Dictionary = {}, spd: float = 1.0) -> void:
	if phase != Phase.NONE:
		_finish(true)
	data = d
	ctx = p_ctx
	speed = maxf(0.1, spd)
	t = 0.0
	phase = Phase.STARTUP
	hit_index = -1
	registry = {}
	connected_indices = {}
	targets_hit = {}
	cancel_override = false
	if d.hits > 0:
		c.hitbox.configure(d.hitbox_size, d.hitbox_offset)
	c.play_attack_anim(d, speed)
	started.emit(d, ctx)


func interrupt() -> void:
	if phase != Phase.NONE:
		_finish(true)


func time_in_recovery() -> float:
	return t - data.startup - data.active if data else 0.0


func can_cancel() -> bool:
	if phase == Phase.NONE:
		return true
	if phase == Phase.RECOVERY:
		return cancel_override or time_in_recovery() >= data.cancel_after
	return false


func can_dodge_cancel() -> bool:
	if phase == Phase.NONE:
		return true
	if phase == Phase.RECOVERY:
		return data.dodge_cancel
	# multi-hit techniques that allow it (Crosscut): a dodge after the first hit abandons the rest
	if phase == Phase.ACTIVE and data.has_tag("dodge_between_hits") and data.hits > 1:
		var per := data.active / float(data.hits)
		return hit_index == 0 and (t - data.startup) >= per * 0.5
	# light attacks may be dodge-cancelled during startup (commitment for heavies)
	return phase == Phase.STARTUP and data.has_tag("light")


func connected_hits() -> int:
	return connected_indices.size()


func _physics_process(delta: float) -> void:
	if phase == Phase.NONE or c == null or c.hitstop > 0.0:
		return
	t += delta * speed
	if phase == Phase.STARTUP and t >= data.startup:
		phase = Phase.ACTIVE
		if data.hits > 0:
			c.hitbox.activate(true)
		active_started.emit(data, ctx)
		if phase != Phase.ACTIVE:
			return
	if phase == Phase.ACTIVE:
		if data.hits > 0:
			var per := data.active / float(data.hits)
			var idx := clampi(int((t - data.startup) / maxf(per, 0.0001)), 0, data.hits - 1)
			if idx != hit_index:
				hit_index = idx
				registry[idx] = {}
				hit_window.emit(idx)
			_check_hits()
		if t >= data.startup + data.active:
			phase = Phase.RECOVERY
			c.hitbox.activate(false)
			recovery_started.emit(data)
	if phase == Phase.RECOVERY and t >= data.total_time():
		_finish(false)


func _check_hits() -> void:
	for target in c.hitbox.targets():
		var key: int = target.get_instance_id()
		if registry[hit_index].has(key):
			continue
		registry[hit_index][key] = true
		var info: DamageInfo = c.build_damage(data, target, hit_index, ctx)
		target.take_damage(info)
		if info.cancelled and not info.guarded and not info.intercepted and info.absorbed <= 0.0:
			continue
		connected_indices[hit_index] = true
		targets_hit[key] = target
		hit_landed.emit(target, info)
		c.on_hit_landed(target, info)
		if phase == Phase.NONE:
			return


func _finish(interrupted: bool) -> void:
	var d := data
	var x := ctx
	phase = Phase.NONE
	if c and c.hitbox:
		c.hitbox.activate(false)
	finished.emit(d, x, interrupted)
