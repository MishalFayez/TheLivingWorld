class_name AshenWarden
extends Enemy
## THE ASHEN WARDEN — three-phase boss.
## P1: sword strikes, wide sweep, guard breaker.
## P2 (60% HP): + burning ground, flame combination, Ember Lance aimed at the most DISTANT hero.
## P3 (25% HP): faster, shorter openings, Execution Strike on the lowest-HP hero.

var burn_spots: Array = []


func setup_type() -> void:
	display_name = "The Ashen Warden"
	enemy_type = "ashen_warden"
	weight_class = "heavy"
	is_boss = true
	base_hp = 1400.0
	base_poise = 260.0
	base_power = 15.0
	armor = 40.0
	magic_resist = 35.0
	move_speed = 4.6
	turn_speed = 4.0
	aggro_range = 30.0
	leash_range = 80.0
	global_cd = 1.1
	post_pause = 1.0
	engage_delay = Vector2(0.2, 0.5)
	chain_chance = 0.85
	body_scale = 1.55
	stagger_mult = 0.55
	load_attacks(["warden_slash1", "warden_sweep", "warden_breaker", "warden_flame_combo",
		"warden_burning_ground", "warden_ember_lance", "warden_execution"])
	base_color = Color(0.2, 0.1, 0.08)
	CharModel.build(self, "warden", null)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.omni_range = 6.0
	light.position = Vector3(0, 2, 0)
	model.add_child(light)


func _ready() -> void:
	super._ready()
	stats.attack_speed = 1.0


func on_damaged(info: DamageInfo) -> void:
	super.on_damaged(info)
	if dead:
		return
	var ratio := hp / max_hp
	if phase == 1 and ratio <= 0.6:
		_enter_phase(2)
	elif phase == 2 and ratio <= 0.25:
		_enter_phase(3)


func _enter_phase(p: int) -> void:
	phase = p
	Events.boss_phase.emit(self, p)
	Events.notify.emit("THE ASHEN WARDEN - PHASE %d" % p)
	if p == 3:
		stats.attack_speed = 1.15
		cooldown_mult = 0.75
		post_pause = 0.45
		speed_mult = 1.15
		engage_delay = Vector2(0.1, 0.3)
	else:
		cooldown_mult = 0.9
		post_pause = 0.8
	if body_material:
		body_material.albedo_color = base_color.lerp(Color(1.0, 0.3, 0.05), 0.3 * (p - 1))
	var roar := find_attack("warden_roar")
	if roar and sm:
		runner.interrupt()
		sm.change("attack", {"attack": roar})


func on_attack_start(d: AttackData) -> void:
	match d.special:
		"burning_ground":
			burn_spots.clear()
			for h in Game.living_heroes():
				burn_spots.append(h.global_position)
				var tg := Telegraph.circle(h.global_position, 2.8, d.startup / maxf(runner.speed, 0.1), Color(1.0, 0.35, 0.0, 0.6))
				tg.auto_free = true
		"execution":
			var low = null
			var lr := 2.0
			for h in Game.living_heroes():
				var r: float = h.hp / h.max_hp
				if r < lr and h.global_position.distance_to(global_position) < 14.0:
					lr = r
					low = h
			if low:
				target = low
				face_dir(dir_to_target())
				Events.log_message.emit("Ashen Warden marks %s for EXECUTION" % low.display_name, "death")
		"lance_far":
			var far = null
			var fd := -1.0
			for h in Game.living_heroes():
				var dd: float = h.global_position.distance_to(global_position)
				if dd > fd:
					fd = dd
					far = h
			if far:
				face_dir(far.global_position - global_position)
				runner.ctx["lance_target"] = far


func on_attack_active(d: AttackData) -> void:
	match d.special:
		"burning_ground":
			var me := self
			var nm := d.display_name
			var power := d.damage_mult
			for pos in burn_spots:
				var cb := func(z):
					if not is_instance_valid(me):
						return
					for h in z.members("heroes"):
						me.spell_damage(h, power, 0.0, nm, {"pos": z.global_position, "hitstop": 0.0, "knockback": 0.0})
				GroundZone.spawn(self, pos, 2.8, 6.0, Color(1.0, 0.35, 0.05), 0.5, cb)
		"lance_far":
			var tgt = runner.ctx.get("lance_target", target)
			fire_projectile(d, tgt, 16.0, 0.5, Color(1.0, 0.5, 0.1))


func extra_states() -> Array:
	return []
