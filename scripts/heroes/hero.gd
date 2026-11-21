class_name Hero
extends Combatant
## Player-or-AI controlled hero. Shared systems (movement, dodge + i-frames, lock-on, input buffer,
## downed / revive, interception, barriers) live here; class mechanics live in the ClassKit child.
## A "brain" (PlayerBrain or AIBrain) drives the hero only through move_input / press() / release().

@export var class_id: String = "vanguard"
var kit: ClassKit
var rt: AugmentRuntime
var is_player: bool = false
var move_input: Vector3 = Vector3.ZERO
var lock_target = null
var held: Dictionary = {}
## Raw left / right input (-1..1), independent of camera: Reaver Shift + A/D + LMB, Turning Edge.
var strafe_axis: float = 0.0

var dodging: bool = false
var dodge_t: float = 0.0
var dodge_dir: Vector3 = Vector3.ZERO
var last_dodge_end: float = -10.0
## Dodge travel scale (speed only; timing and i-frames unchanged). 1.0 for everyone; only the Blade
## Dancer Reaver's Combat Weave sets it per dodge (REAVER-BLADEDANCER-003).
var dodge_scale: float = 1.0
var buffer_action: String = ""
var buffer_t: float = 0.0

var downed_timer: float = 0.0
var revive_progress: float = 0.0
var revive_target: Node = null
var revive_tick: float = -10.0
var protector = null
var protector_until: float = 0.0
var threat_mult: float = 1.0
var level: int = 1
var approach: MeleeApproach = MeleeApproach.new()
var attack_turn_dir: Vector3 = Vector3.ZERO
const ATTACK_TURN_SPEED := 22.0
const FACE_TURN_SPEED := 12.0


func _ready() -> void:
	team = 0
	add_to_group("heroes")
	super._ready()
	collision_layer = LAYER_HEROES
	collision_mask = LAYER_WORLD | LAYER_ENEMIES
	kit = get_node_or_null("Kit")
	if kit == null:
		push_error("Hero scene is missing its Kit child")
		return
	kit.setup(self)
	kit.build_model()
	# LEVEL10-FOUNDATION-005: runtime of the Level 1-10 augment pool (one per hero)
	rt = AugmentRuntime.new()
	add_child(rt)
	rt.setup(self)
	refresh_stats(true)
	runner.started.connect(kit.on_attack_started)
	runner.active_started.connect(kit.on_attack_active)
	runner.active_started.connect(_weapon_trail)
	runner.hit_landed.connect(_hit_spark)
	runner.finished.connect(_on_attack_finished)
	runner.hit_landed.connect(kit.on_hit_landed)
	if not Game.heroes.has(self):
		Game.heroes.append(self)
	play_anim("idle")
	_add_marker()


func _exit_tree() -> void:
	Game.heroes.erase(self)


func _add_marker() -> void:
	var l := Label3D.new()
	l.name = "Marker"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 2.45, 0)
	l.pixel_size = 0.005
	l.font_size = 40
	l.outline_size = 8
	l.modulate = Color(0.6, 1.0, 0.6) if is_player else Color(0.6, 0.85, 1.0)
	add_child(l)


## Saved progression for the player; mirrored non-saved progression for AI companions.
func prog() -> ClassProgress:
	return Game.prog(class_id) if is_player else Game.companion_prog(class_id)


func unlocked(id: String) -> bool:
	return prog().has_unlock(id)


func rebuild_model() -> void:
	for c in model.get_children():
		if c != weapon_pivot and c != shield_pivot:
			c.queue_free()
	for c in weapon_pivot.get_children():
		c.queue_free()
	for c in shield_pivot.get_children():
		c.queue_free()
	kit.build_model()


func refresh_stats(full_heal: bool) -> void:
	var p := prog()
	level = p.level
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	stats = StatBlock.for_class(class_id, p, Game.balance)
	max_hp = stats.max_hp()
	hp = max_hp if full_heal else clampf(max_hp * ratio, 1.0, max_hp)
	max_stamina = Game.balance.stamina_max
	weapon_power = StatPreview.weapon_power(class_id, p)
	max_poise = float(Game.balance.class_base.get(class_id, {}).get("poise", 50.0))
	poise = minf(poise, max_poise) if not full_heal else max_poise
	threat_mult = kit.threat_mult() if kit else 1.0
	if kit:
		kit.on_stats_refreshed()
	hp_changed.emit(hp, max_hp)


func restore_all() -> void:
	hp = max_hp
	stamina = max_stamina
	poise = max_poise
	if kit:
		kit.restore()
	hp_changed.emit(hp, max_hp)


# ------------------------------------------------------------------ input interface (brains)
func press(action: String) -> void:
	held[action] = true
	if downed or dead:
		return
	if action == "dodge":
		try_dodge()
		return
	if action == "lock_on":
		return
	kit.on_press(action)


func release(action: String) -> void:
	held[action] = false
	if downed or dead:
		return
	kit.on_release(action)


func is_held(action: String) -> bool:
	return held.get(action, false)


func buffer(action: String) -> void:
	buffer_action = action
	buffer_t = Game.balance.input_buffer


func can_act() -> bool:
	if downed or dead or dodging or stagger_timer > 0.0:
		return false
	return not runner.is_busy() or runner.can_cancel()


# ------------------------------------------------------------------ movement / dodge
func try_dodge() -> void:
	if dodging or downed or stagger_timer > 0.0:
		return
	if kit.has_method("dodge_override") and kit.dodge_override():
		return
	if runner.is_busy() and not runner.can_dodge_cancel():
		buffer("dodge")
		return
	var cost := Game.balance.dodge_cost * kit.dodge_cost_mult()
	if stamina <= 1.0:
		return
	use_stamina(cost)
	runner.interrupt()
	kit.on_dodge()
	dodging = true
	dodge_t = 0.0
	dodge_dir = move_input.normalized() if move_input.length() > 0.2 else -forward()
	dodge_dir.y = 0
	attack_turn_dir = Vector3.ZERO
	# roll toward the input direction (also while locked); facing returns to the target afterwards
	if move_input.length() > 0.2:
		face_dir(dodge_dir)
	play_anim("dodge")


func is_invulnerable() -> bool:
	if not dodging:
		return false
	var s := Game.balance.dodge_iframe_start
	return dodge_t >= s and dodge_t <= s + Game.balance.dodge_iframes * kit.iframe_mult()


func is_invincible_debug() -> bool:
	return is_player and Game.invincible


## Attacks orient quickly toward the lock target / input direction during startup instead of an
## instant snap (ATTACK_TURN_SPEED), so the hit still lands where intended.
func face_for_attack() -> void:
	if is_instance_valid(lock_target) and lock_target.is_targetable():
		attack_turn_dir = lock_target.global_position - global_position
	elif move_input.length() > 0.2:
		attack_turn_dir = move_input
	else:
		attack_turn_dir = Vector3.ZERO
	attack_turn_dir.y = 0.0
	# tiny corrections are applied immediately; larger turns happen over the startup window
	if attack_turn_dir.length_squared() > 0.001 and forward().angle_to(attack_turn_dir.normalized()) < 0.35:
		face_dir(attack_turn_dir)


func combat_process(delta: float) -> void:
	if downed:
		_downed_process(delta)
		velocity.x = 0
		velocity.z = 0
		return
	if dead or not visible:
		velocity = Vector3.ZERO
		return
	kit.process(delta)
	if buffer_t > 0.0:
		buffer_t -= delta
		if buffer_t <= 0.0:
			buffer_action = ""
	# AI heroes drop dead targets here; the player's LockOnSystem handles death / re-targeting.
	if not is_player and lock_target != null and (not is_instance_valid(lock_target) or not lock_target.is_targetable()):
		lock_target = null
	if stagger_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
		return
	if dodging:
		dodge_t += delta
		var dur := Game.balance.dodge_duration
		var spd := Game.balance.dodge_speed * dodge_scale * (1.0 - 0.5 * dodge_t / dur)
		velocity.x = dodge_dir.x * spd
		velocity.z = dodge_dir.z * spd
		if dodge_t >= dur:
			dodging = false
			last_dodge_end = Game.time
			play_anim("idle")
		return
	# buffered input
	if buffer_action != "" and can_act():
		var a := buffer_action
		buffer_action = ""
		if a == "dodge":
			try_dodge()
		else:
			kit.on_press(a)
	var spd_mult := statuses.mult("move_speed") * kit.move_mult()
	var desired := move_input * Game.balance.move_speed * spd_mult
	if runner.is_busy():
		var lunge := attack_motion_speed()
		desired *= runner.data.move_during
		if lunge > 0.0:
			desired += forward() * lunge
		if runner.phase == AttackRunner.Phase.STARTUP and approach.active:
			var av := approach.step(self, delta)
			if av != Vector3.ZERO:
				# the step is part of the attack animation: applied directly, not through acceleration
				velocity.x = av.x + desired.x
				velocity.z = av.z + desired.z
				return
		elif approach.active:
			approach.active = false
		if runner.phase == AttackRunner.Phase.STARTUP:
			if is_instance_valid(lock_target) and lock_target.is_targetable():
				turn_toward(lock_target.global_position - global_position, ATTACK_TURN_SPEED, delta)
			elif attack_turn_dir.length_squared() > 0.001:
				turn_toward(attack_turn_dir, ATTACK_TURN_SPEED, delta)
		elif runner.data.move_during > 0.0 and move_input.length() > 0.2:
			turn_toward(move_input, 4.0, delta)
	else:
		# facing is independent from camera smoothing: lock -> face target (strafe), else face movement
		if is_instance_valid(lock_target) and lock_target.is_targetable():
			turn_toward(lock_target.global_position - global_position, FACE_TURN_SPEED, delta)
		elif move_input.length() > 0.1:
			turn_toward(move_input, FACE_TURN_SPEED, delta)
		if not kit.overrides_idle_anim():
			if anim.current_animation == "" or (not anim.is_playing()):
				play_anim("idle")
	velocity.x = move_toward(velocity.x, desired.x, 60 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 60 * delta)


func stamina_regen_mult() -> float:
	return kit.stamina_regen_mult() if kit else 1.0


func _on_attack_finished(d: AttackData, ctx: Dictionary, interrupted: bool) -> void:
	kit.on_attack_finished(d, ctx, interrupted)
	if rt:
		rt.on_attack_finished(d, ctx, interrupted)
	if not runner.is_busy() and not downed and stagger_timer <= 0.0 and not dodging:
		if not kit.overrides_idle_anim():
			play_anim("idle")


# ------------------------------------------------------------------ damage hooks
func pre_damage(info: DamageInfo) -> void:
	# Interception: a Vanguard who rushed to protect this hero takes the blow instead.
	if protector != null and is_instance_valid(protector) and protector != self and Game.time < protector_until and not info.is_dot:
		if protector.kit is VanguardKit and protector.kit.try_intercept(info, self):
			info.cancelled = true
			info.intercepted = true
			return
	# Defender's Oath (Vanguard augment): part of the hit goes to the protecting Vanguard
	if has_meta("oath_guard"):
		AugmentRuntime.oath_split(self, info)
	# Phantom Bulwark barriers
	for b in get_tree().get_nodes_in_group("barriers"):
		if b.protects(self, info):
			b.absorb(info, self)
			if info.cancelled:
				return
	kit.modify_incoming(info)
	if rt:
		rt.modify_incoming(info)


func modify_outgoing(info: DamageInfo, d: AttackData, target, idx: int, ctx: Dictionary) -> void:
	info.threat_mult *= threat_mult
	kit.modify_outgoing(info, d, target, idx, ctx)
	if rt:
		rt.modify_outgoing(info, d, target, idx, ctx)


func situational_crit(d: AttackData, target, ctx: Dictionary) -> float:
	return kit.situational_crit(d, target, ctx)


func on_hit_landed(target, info: DamageInfo) -> void:
	super.on_hit_landed(target, info)
	if rt:
		rt.on_hit_landed(target, info)
	if is_player and info.final_amount > 0.0 and Game.world and Game.world.has_method("shake"):
		Game.world.shake(0.08 if not info.is_heavy else 0.2)


func on_damaged(info: DamageInfo) -> void:
	kit.on_damaged(info)


func on_dodged(info: DamageInfo) -> void:
	if dodging:
		kit.on_perfect_dodge(info)
		if rt:
			rt.on_perfect_dodge(info)


func on_staggered() -> void:
	dodging = false
	kit.on_staggered()


# ------------------------------------------------------------------ downed / revive / death
func on_zero_hp(_info: DamageInfo) -> void:
	downed = true
	hp = 0.0
	downed_timer = Game.balance.downed_window
	revive_progress = 0.0
	runner.interrupt()
	statuses.clear()
	dodging = false
	lock_target = null
	kit.on_downed()
	play_anim("downed")
	Events.combatant_downed.emit(self)


func _downed_process(delta: float) -> void:
	downed_timer -= delta
	if revive_progress > 0.0 and Game.time - revive_tick > 0.25:
		revive_progress = maxf(0.0, revive_progress - delta * 0.5)
	if downed_timer <= 0.0:
		downed = false
		dead = true
		Game.on_hero_true_death(self)


func add_revive_progress(amount: float, by: Node) -> void:
	if not downed:
		return
	revive_progress += amount
	revive_tick = Game.time
	if revive_progress >= Game.balance.revive_time:
		revive(by)


func revive(by: Node) -> void:
	downed = false
	dead = false
	hp = max_hp * Game.balance.revive_hp_pct
	poise = max_poise
	revive_progress = 0.0
	play_anim("idle")
	hp_changed.emit(hp, max_hp)
	Events.combatant_revived.emit(self, by)


## Called by brains every frame the revive input is held.
func try_revive(delta: float) -> Node:
	for h in Game.heroes:
		if is_instance_valid(h) and h != self and h.downed and h.global_position.distance_to(global_position) < 2.6:
			h.add_revive_progress(delta, self)
			revive_target = h
			return h
	revive_target = null
	return null


func hide_dead() -> void:
	visible = false
	collision_layer = 0
	set_physics_process(false)


func respawn(pos: Vector3) -> void:
	dead = false
	downed = false
	visible = true
	collision_layer = LAYER_HEROES
	set_physics_process(true)
	teleport(pos)
	statuses.clear()
	refresh_stats(true)
	restore_all()
	play_anim("idle")
	Events.log_message.emit("%s respawned" % display_name, "system")


# ------------------------------------------------------------------ helpers for kits / AI
func allies(include_self: bool = true) -> Array:
	var out: Array = []
	for h in Game.heroes:
		if is_instance_valid(h) and h.visible and not h.dead and not h.downed and (include_self or h != self):
			out.append(h)
	return out


func enemies_within(radius: float, center: Vector3 = Vector3.INF) -> Array:
	var c := global_position if center == Vector3.INF else center
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_targetable() and e.global_position.distance_to(c) <= radius:
			out.append(e)
	return out


func find_enemy_target(max_dist: float = 25.0, cone_deg: float = 50.0) -> Node:
	if is_instance_valid(lock_target) and lock_target.is_targetable() and lock_target.team != team:
		return lock_target
	var best = null
	var best_score := INF
	var fwd := forward()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_targetable():
			continue
		var to: Vector3 = e.global_position - global_position
		var d := to.length()
		if d > max_dist:
			continue
		to.y = 0
		var ang := rad_to_deg(fwd.angle_to(to.normalized())) if d > 0.1 else 0.0
		if ang > cone_deg:
			continue
		var score := d + ang * 0.15
		if score < best_score:
			best_score = score
			best = e
	return best


func lowest_ally(max_dist: float = 20.0) -> Node:
	var best = null
	var best_ratio := 2.0
	for h in allies(true):
		if h.global_position.distance_to(global_position) > max_dist:
			continue
		var r: float = h.hp / h.max_hp
		if r < best_ratio:
			best_ratio = r
			best = h
	return best


# ------------------------------------------------------------------ weapon feedback (Update 5)
const TRAIL_COLORS := {"vanguard": Color(1.0, 0.85, 0.45), "mage": Color(0.6, 0.85, 1.0), "reaver": Color(1.0, 0.4, 0.32)}


## Sword arcs shaped by the attack style (horizontal, sweep, vertical, thrust, flurry).
func _weapon_trail(d: AttackData, _ctx: Dictionary) -> void:
	if d.has_tag("spell") or d.hits == 0:
		return
	var col: Color = TRAIL_COLORS.get(class_id, Color.WHITE)
	if d.is_heavy or d.is_charged:
		col = col.lightened(0.2)
	match d.anim_style:
		"sweep", "spin":
			VFX.sword_arc(self, col, 2.1, 300.0, 1.0, 0.0, 0.25)
		"slash_v", "slam", "rising":
			VFX.sword_arc(self, col, 1.7, 150.0, 1.2, PI / 2, 0.2)
		"thrust", "lunge":
			VFX.sword_arc(self, col, 2.4, 22.0, 1.15, 0.0, 0.16)
		"flurry":
			for i in mini(d.hits, 4):
				var tilt := (0.6 if i % 2 == 0 else -0.6)
				get_tree().create_timer(d.active * i / maxf(1.0, mini(d.hits, 4))).timeout.connect(func():
					if is_instance_valid(self):
						VFX.sword_arc(self, col, 1.6, 110.0, 1.1, tilt, 0.14))
		_:
			VFX.sword_arc(self, col, 1.7, 140.0, 1.1, 0.25 if d.id.ends_with("2") else -0.25, 0.18)


func _hit_spark(target, info: DamageInfo) -> void:
	if not is_instance_valid(target) or info.final_amount <= 0.0:
		return
	var pos: Vector3 = target.global_position + Vector3(0, 1.1, 0) + (global_position - target.global_position).normalized() * 0.4
	var col := Color(1.0, 0.9, 0.6) if not info.is_crit else Color(1.0, 0.75, 0.3)
	VFX.hit_sparks(pos, col, 6 if not info.is_heavy else 12, info.is_crit)
