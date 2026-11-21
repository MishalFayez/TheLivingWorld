class_name Enemy
extends Combatant
## Base enemy: threat table, NavigationAgent3D movement, data-driven attack selection, telegraphs,
## and a node-based EnemyStateMachine (idle / chase / attack / reposition / stagger / dead).
## Subclasses configure stats, model and attacks in setup_type() and may override behaviour hooks.

@export var enemy_type: String = "wolf"
var exp_override: float = -1.0
var is_elite: bool = false
var is_boss: bool = false
## Worldweaver displacement weight (Earthbreaker / Rising Pillar): "light" | "medium" | "heavy".
## Provisional per-type mapping (not defined in the approved spec): set in each setup_type().
var weight_class: String = "medium"
var area_key: String = "outskirts"
var move_speed: float = 4.0
var turn_speed: float = 6.0
var aggro_range: float = 14.0
var leash_range: float = 40.0
var attacks: Array = []
var attack_ready_at: Dictionary = {}
var global_cd_until: float = 0.0
var global_cd: float = 0.6
var cooldown_mult: float = 1.0
var speed_mult: float = 1.0
var target = null
var threat: Dictionary = {}
var nav: NavigationAgent3D
var sm: EnemyStateMachine
var phase: int = 1
var power_scale: float = 1.0
var home_position: Vector3 = Vector3.ZERO
var telegraph: Telegraph
var bar: Label3D
var attack_serial: int = 0
var attack_started_at: float = 0.0
var preferred_range: float = 0.0
var stagger_mult: float = 1.0
var base_hp: float = 100.0
var base_poise: float = 40.0
var base_power: float = 12.0
var armor: float = 10.0
var magic_resist: float = 10.0
var body_scale: float = 1.0
var post_pause: float = 0.35
## Pacing (deliberate, readable combat)
var engage_delay: Vector2 = Vector2(0.35, 0.8)   ## hesitation in range before committing to an attack
var next_engage: float = 0.5
var chain_chance: float = 0.75                    ## chance to continue a combo chain
var max_attackers: int = 2                        ## attack tokens per hero (boss ignores)
var enemy_attack_speed: float = 1.0
var circle_dir: float = 1.0
var alert: Label3D
var _tele_color: Color = Color(1, 0.2, 0.1)
# Reaver Sword Sense (Update 5): a short window where this enemy is exposed.
var opening_until: float = -10.0
var opening_kind: String = ""
var opening_cap: float = -10.0
var _glint: MeshInstance3D
var _glint_mat: StandardMaterial3D


func configure(p_area: String, elite: bool) -> void:
	area_key = p_area
	is_elite = elite
	power_scale = float(Game.balance.area_power.get(p_area, 1.0))


func _ready() -> void:
	team = 1
	add_to_group("enemies")
	super._ready()
	collision_layer = LAYER_ENEMIES
	collision_mask = LAYER_WORLD | LAYER_HEROES | LAYER_ENEMIES | LAYER_FROST
	setup_type()
	var hp_mult := power_scale * (2.6 if is_elite else 1.0)
	stats = StatBlock.new()
	stats.armor = armor
	stats.magic_resist = magic_resist
	stats.crit_chance = 0.0
	stats.attack_speed = enemy_attack_speed
	circle_dir = 1.0 if randf() < 0.5 else -1.0
	roll_engage()
	max_hp = base_hp * hp_mult
	hp = max_hp
	max_poise = base_poise * (1.6 if is_elite else 1.0)
	poise = max_poise
	weapon_power = base_power * power_scale * (1.35 if is_elite else 1.0)
	if is_elite:
		display_name = "Elite " + display_name
		body_scale *= 1.3
		if body_material:
			body_material.albedo_color = base_color.lerp(Color(1.0, 0.8, 0.2), 0.45)
	model.scale = Vector3.ONE * body_scale
	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.8
	nav.target_desired_distance = 1.0
	nav.radius = 0.5
	add_child(nav)
	runner.started.connect(_on_attack_started)
	runner.active_started.connect(_on_attack_active)
	runner.finished.connect(_on_attack_finished)
	runner.recovery_started.connect(_on_recovery_started)
	_make_bar()
	_make_alert()
	sm = EnemyStateMachine.new()
	sm.name = "StateMachine"
	add_child(sm)
	sm.setup(self)
	play_anim("idle")


## Subclasses: set display_name, stats, speeds, attacks and build the model.
func setup_type() -> void:
	pass


func load_attacks(ids: Array) -> void:
	attacks.clear()
	for id in ids:
		var a = load("res://data/attacks/%s.tres" % id)
		if a:
			attacks.append(a)


func find_attack(id: String) -> AttackData:
	for a in attacks:
		if a.id == id:
			return a
	var a2 = load("res://data/attacks/%s.tres" % id)
	return a2


func _make_bar() -> void:
	bar = Label3D.new()
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.pixel_size = 0.005
	bar.font_size = 34
	bar.outline_size = 8
	bar.position = Vector3(0, 2.3 * body_scale + 0.2, 0)
	bar.no_depth_test = false
	add_child(bar)
	bar.visible = false   # screen-space bars are drawn by the HUD WorldOverlay
	_update_bar()
	hp_changed.connect(func(_a, _b): _update_bar())


func _make_alert() -> void:
	alert = Label3D.new()
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.no_depth_test = true
	alert.pixel_size = 0.01
	alert.font_size = 64
	alert.outline_size = 14
	alert.position = Vector3(0, 2.9 * body_scale + 0.3, 0)
	alert.visible = false
	alert.set("physics_interpolation_mode", 2)
	var f = load("res://assets/fonts/Cinzel-Variable.ttf")
	if f:
		alert.font = f
	add_child(alert)


func _show_alert(d: AttackData) -> void:
	if alert == null:
		return
	if d.guard_break:
		alert.text = "!!"
		_tele_color = Color(1.0, 0.55, 0.0)
	elif d.damage_type == AttackData.DamageType.MAGIC:
		alert.text = "!"
		_tele_color = Color(0.75, 0.35, 1.0)
	else:
		alert.text = "!"
		_tele_color = Color(1.0, 0.18, 0.1)
	alert.modulate = _tele_color
	alert.visible = true
	alert.scale = Vector3.ONE * 0.3
	var tw := alert.create_tween()
	tw.tween_property(alert, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(alert, "scale", Vector3.ONE, 0.1)


func roll_engage() -> void:
	next_engage = randf_range(engage_delay.x, engage_delay.y)


## Attack tokens: at most `max_attackers` enemies commit to attacks on the same hero at once.
func may_attack() -> bool:
	if is_boss or target == null:
		return true
	var n := 0
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and not o.dead and o.target == target and o.is_attacking_now():
			n += 1
	return n < max_attackers


func strafe(delta: float, factor: float = 0.4) -> void:
	var to := dir_to_target()
	var tangent := to.cross(Vector3.UP) * circle_dir
	var d := dist_to_target()
	var radial := 0.0
	if d < 2.0:
		radial = -0.4
	elif d > 4.0:
		radial = 0.3
	move_dir(tangent + to * radial, delta, factor)
	turn_toward(to, turn_speed, delta)


func _update_bar() -> void:
	if bar == null:
		return
	var n := 12
	var filled := int(round(n * clampf(hp / max_hp, 0.0, 1.0)))
	var pn := int(round(6 * clampf(poise / max_poise, 0.0, 1.0)))
	bar.text = "%s\n%s%s\n%s" % [display_name, "|".repeat(filled), ".".repeat(n - filled), "-".repeat(pn)]
	bar.modulate = Color(1.0, 0.85, 0.3) if is_elite else Color(1, 0.5, 0.45)


# ------------------------------------------------------------------ threat / targeting
func add_threat(h, amount: float) -> void:
	if h == null or not is_instance_valid(h):
		return
	var k: int = h.get_instance_id()
	threat[k] = float(threat.get(k, 0.0)) + amount


func taunt(h) -> void:
	var top := 0.0
	for v in threat.values():
		top = maxf(top, v)
	threat[h.get_instance_id()] = top + 200.0
	Events.log_message.emit("%s is taunted by %s" % [display_name, h.display_name], "guard")


func update_target(delta: float) -> void:
	for k in threat.keys():
		threat[k] = threat[k] * (1.0 - 0.05 * delta)
	var best = null
	var best_v := -INF
	for h in Game.heroes:
		if not is_instance_valid(h) or not h.is_targetable():
			continue
		var d: float = h.global_position.distance_to(global_position)
		var t: float = float(threat.get(h.get_instance_id(), 0.0))
		if d > aggro_range and t <= 0.0:
			continue
		if d > leash_range:
			continue
		# steam obscures sight: an unseen hero cannot be newly acquired (bosses are exempt)
		if not is_boss and h != target and t <= 0.0 and SteamCloud.blocks(global_position + Vector3(0, 1.5, 0), h.global_position + Vector3(0, 1.2, 0)):
			continue
		var v: float = t + maxf(0.0, aggro_range - d) * 3.0
		if v > best_v:
			best_v = v
			best = h
	target = best


func dist_to_target() -> float:
	if target == null or not is_instance_valid(target):
		return INF
	return global_position.distance_to(target.global_position)


func dir_to_target() -> Vector3:
	if target == null or not is_instance_valid(target):
		return forward()
	var d: Vector3 = target.global_position - global_position
	d.y = 0
	return d.normalized()


# ------------------------------------------------------------------ movement
func current_speed() -> float:
	return move_speed * speed_mult * statuses.mult("move_speed")


func move_to(pos: Vector3, delta: float, speed_factor: float = 1.0) -> void:
	nav.target_position = pos
	var next := pos
	if not nav.is_navigation_finished():
		var np := nav.get_next_path_position()
		if np.distance_to(global_position) > 0.05:
			next = np
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05:
		stop_moving(delta)
		return
	dir = dir.normalized()
	# temporary Worldweaver formations are not in the navmesh: steer around them
	dir = WorldFormation.steer(self, dir, pos)
	var spd := current_speed() * speed_factor
	velocity.x = move_toward(velocity.x, dir.x * spd, 30.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 30.0 * delta)
	turn_toward(dir, turn_speed, delta)


func move_dir(dir: Vector3, delta: float, speed_factor: float = 1.0) -> void:
	dir.y = 0
	var spd := current_speed() * speed_factor
	velocity.x = move_toward(velocity.x, dir.normalized().x * spd, 30.0 * delta)
	velocity.z = move_toward(velocity.z, dir.normalized().z * spd, 30.0 * delta)


func stop_moving(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)


func combat_process(delta: float) -> void:
	_update_glow()
	_update_glint()
	if runner.is_busy():
		var lunge := attack_motion_speed()
		if lunge > 0.0:
			velocity.x = forward().x * lunge
			velocity.z = forward().z * lunge
		else:
			stop_moving(delta)
		if runner.phase == AttackRunner.Phase.STARTUP and target != null and is_instance_valid(target):
			turn_toward(dir_to_target(), turn_speed * 0.6, delta)
	elif stagger_timer > 0.0 or dead:
		stop_moving(delta)


func _update_glow() -> void:
	if body_material == null or flash_timer > 0.0:
		return
	if runner.phase == AttackRunner.Phase.STARTUP and runner.data:
		var p := clampf(runner.t / maxf(runner.data.startup, 0.01), 0.0, 1.0)
		body_material.emission_enabled = true
		body_material.emission = _tele_color
		body_material.emission_energy_multiplier = 0.25 + 2.4 * p * p
	else:
		body_material.emission_enabled = false


# ------------------------------------------------------------------ attacks
func choose_attack():
	var dist := dist_to_target()
	if Game.time < global_cd_until:
		return null
	var pool: Array = []
	var total := 0.0
	var steam_blind := not is_boss and target != null and is_instance_valid(target) and SteamCloud.blocks(global_position + Vector3(0, 1.5, 0), target.global_position + Vector3(0, 1.2, 0))
	for a in attacks:
		if a.ai_min_phase > phase:
			continue
		if steam_blind and a.special in ["projectile", "ground_burst", "lance_far"]:
			continue        # no ranged attacks through steam
		if Game.time < float(attack_ready_at.get(a.id, 0.0)):
			continue
		if dist < a.ai_range.x or dist > a.ai_range.y:
			continue
		pool.append(a)
		total += a.ai_weight
	if pool.is_empty():
		return null
	var r := randf() * total
	for a in pool:
		r -= a.ai_weight
		if r <= 0.0:
			return a
	return pool[0]


func begin_attack(d: AttackData) -> void:
	attack_serial += 1
	attack_started_at = Game.time
	attack_ready_at[d.id] = Game.time + d.ai_cooldown * cooldown_mult
	global_cd_until = Game.time + global_cd * cooldown_mult
	if target != null and is_instance_valid(target):
		face_dir(dir_to_target())
	runner.start(d, {}, attack_speed())


func startup_remaining() -> float:
	if runner.phase != AttackRunner.Phase.STARTUP:
		return 0.0
	return maxf(0.0, (runner.data.startup - runner.t) / runner.speed)


func _on_attack_started(d: AttackData, _ctx: Dictionary) -> void:
	_clear_telegraph()
	_show_alert(d)
	if d.hits > 0 and d.special != "ground_burst":
		var col := d.telegraph_color
		if d.guard_break:
			col = Color(1.0, 0.6, 0.0, 0.6)
		telegraph = Telegraph.rect(self, d.hitbox_size, d.hitbox_offset, d.startup / maxf(runner.speed, 0.1), col)
		telegraph.auto_free = false
	on_attack_start(d)


func _on_attack_active(d: AttackData, _ctx: Dictionary) -> void:
	_clear_telegraph()
	if alert:
		alert.visible = false
	on_attack_active(d)


func _on_attack_finished(d: AttackData, _ctx: Dictionary, interrupted: bool) -> void:
	_clear_telegraph()
	if alert:
		alert.visible = false
	on_attack_end(d, interrupted)


func _clear_telegraph() -> void:
	if telegraph != null and is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null


func on_attack_start(_d: AttackData) -> void:
	pass


func on_attack_active(_d: AttackData) -> void:
	pass


func on_attack_end(_d: AttackData, _interrupted: bool) -> void:
	pass


func post_attack_pause() -> float:
	return post_pause


func extra_states() -> Array:
	return []


## Optional custom chase movement (wolf circling, caster kiting). Return true if handled.
func custom_chase(_delta: float) -> bool:
	return false


func fire_projectile(d: AttackData, at_target = null, speed: float = 16.0, radius: float = 0.35, color: Color = Color(1.0, 0.4, 0.1)) -> void:
	var tgt = at_target if at_target != null else target
	if tgt == null or not is_instance_valid(tgt):
		return
	var from := global_position + Vector3(0, 1.4 * body_scale, 0) + forward() * 0.7
	var aim: Vector3 = tgt.global_position + Vector3(0, 1.0, 0)
	var me := self
	var power := d.damage_mult
	var poise_dmg := d.poise_damage
	var nm := d.display_name
	var cb := func(t, pos):
		if t != null and is_instance_valid(me):
			me.spell_damage(t, power, poise_dmg, nm, {"pos": pos, "projectile": true, "hitstop": 0.04})
		FX.burst(pos, 0.8, color)
	Projectile.spawn(self, from, aim - from, speed, radius, color, cb, 3.0, weapon_power * power)


# ------------------------------------------------------------------ damage hooks
func on_damaged(info: DamageInfo) -> void:
	if info.source != null and is_instance_valid(info.source) and info.source is Hero:
		add_threat(info.source, info.final_amount * info.threat_mult + 5.0)
	_update_bar()


func on_staggered() -> void:
	open_window("stagger", stagger_timer)
	_clear_telegraph()
	if sm:
		sm.change("stagger")


func on_zero_hp(info: DamageInfo) -> void:
	dead = true
	runner.interrupt()
	_clear_telegraph()
	collision_layer = 0
	collision_mask = LAYER_WORLD
	Events.enemy_killed.emit(self, info.source)
	if sm:
		sm.change("dead")


func can_be_launched() -> bool:
	return not is_boss


## Minor reactions keep the per-type multiplier; a Poise Break uses the tier window (Part 9).
func stagger(duration: float, is_break: bool = false) -> void:
	super.stagger(duration if is_break else duration * stagger_mult, is_break)


func poise_break_time() -> float:
	var b := Game.balance
	if is_boss:
		return b.poise_break_boss
	return b.poise_break_elite if is_elite else b.poise_break_normal


## Readable opening: gold impact burst, low thud, and the stagger pose for the whole window.
func on_poise_broken() -> void:
	VFX.shell(global_position + Vector3(0, 1.0, 0), 1.1, Color(1.0, 0.75, 0.25), 0.3, 0.8)
	VFX.hit_sparks(global_position + Vector3(0, 1.2, 0), Color(1.0, 0.8, 0.3), 18, true)
	PlaceholderSfx.play(self, "poise_break")


# ------------------------------------------------------------------ Openings (Reaver Sword Sense)
## Openings only matter to a Reaver using the Sword Sense core, but are tracked for every enemy so the
## HUD/lock-on can show them. Kinds: "recovery" (after an attack), "stagger", "dodge" (Perfect Dodge).
func _on_recovery_started(d: AttackData) -> void:
	if dead:
		return
	AugmentRuntime.enemy_attack_resolved(self, d, runner.targets_hit)
	open_window("recovery", d.recovery / maxf(0.1, runner.speed) + 0.25)


func open_window(kind: String, duration: float) -> void:
	if dead or not Game.reaver_opening_tracking():
		return
	var until := Game.time + duration * Game.opening_mult()
	if until > opening_until:
		opening_until = until
		opening_cap = until + 1.0
		opening_kind = kind


func has_opening() -> bool:
	return not dead and Game.time < opening_until


func consume_opening() -> void:
	opening_until = -10.0
	opening_kind = ""


func extend_opening(sec: float) -> void:
	if has_opening():
		opening_until = minf(opening_until + sec, opening_cap)


func _update_glint() -> void:
	var show := has_opening()
	if show and _glint == null:
		_glint = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		_glint.mesh = q
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glint_mat.no_depth_test = true
		_glint_mat.albedo_texture = _glint_texture()
		_glint_mat.albedo_color = Color(1.0, 0.92, 0.6)
		_glint.material_override = _glint_mat
		_glint.position = Vector3(0.35, 1.5 * body_scale, 0)
		add_child(_glint)
	if _glint:
		_glint.visible = show
		if show:
			var left := opening_until - Game.time
			var pulse := 0.75 + 0.25 * sin(Game.time * 18.0)
			_glint_mat.albedo_color.a = clampf(left / 0.3, 0.2, 1.0) * pulse
			_glint.rotation.z = Game.time * 3.0


static var _glint_tex: Texture2D
static func _glint_texture() -> Texture2D:
	if _glint_tex:
		return _glint_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var dx := absf(x - 31.5) / 32.0
			var dy := absf(y - 31.5) / 32.0
			var core := maxf(0.0, 1.0 - sqrt(dx * dx + dy * dy) * 3.0)
			var lx := maxf(0.0, 1.0 - dy * 14.0) * (1.0 - dx)
			var ly := maxf(0.0, 1.0 - dx * 14.0) * (1.0 - dy)
			var a := clampf(maxf(core, maxf(lx, ly)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_glint_tex = ImageTexture.create_from_image(img)
	return _glint_tex



## Display level (from the area tier; elites +1). Bosses show the area cap.
func enemy_level() -> int:
	var base: int = {"outskirts": 2, "ruins": 5, "keep": 9}.get(area_key, 1)
	if is_boss:
		return 10
	return base + (1 if is_elite else 0)
