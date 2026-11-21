class_name Combatant
extends CharacterBody3D
## Shared base for heroes and enemies: HP, Stamina, Poise, statuses, damage pipeline,
## attack runner + Area3D hitbox, hitstop, knockback and a primitive animated rig.

signal hp_changed(hp: float, max_hp: float)

const LAYER_WORLD := 1
const LAYER_HEROES := 2
const LAYER_ENEMIES := 4
const LAYER_BARRIERS := 8
const LAYER_FROST := 16      ## Mage ice structures: block ENEMIES only (allies walk through)

@export var display_name: String = "Combatant"
var team: int = 0
var stats: StatBlock
var hp: float = 100.0
var max_hp: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_delay: float = 0.0
var poise: float = 50.0
var max_poise: float = 50.0
var poise_delay: float = 0.0
var stagger_timer: float = 0.0
var hitstop: float = 0.0
var dead: bool = false
var downed: bool = false
var weapon_power: float = 20.0
var knock_velocity: Vector3 = Vector3.ZERO
var flash_timer: float = 0.0
var gravity_strength: float = 22.0
var last_attacker: Node = null
## Ward shield (absorbs damage before HP)
var shield_hp: float = 0.0
var shield_until: float = 0.0
var _shield_mesh: MeshInstance3D

var model: Node3D
var body_mesh: MeshInstance3D
var weapon_pivot: Node3D
var shield_pivot: Node3D
var anim: AnimationPlayer
var anim_lib: AnimationLibrary
## Cross-fade into an attack animation. 0.04 for everyone; only the Free Flow Reaver changes it for its
## own attack-to-attack transitions (REAVER-FREEFLOW-002). Default behavior is unchanged.
var attack_blend: float = 0.04
var runner: AttackRunner
var hitbox: Hitbox
var statuses: StatusComponent
var body_material: StandardMaterial3D
var base_color: Color = Color(0.7, 0.7, 0.7)


func _ready() -> void:
	_build_common()


func _build_common() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	cs.name = "Collision"
	add_child(cs)
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = ProcAnim.REST[ProcAnim.T_WEAPON_POS]
	weapon_pivot.rotation = ProcAnim.REST[ProcAnim.T_WEAPON_ROT]
	model.add_child(weapon_pivot)
	shield_pivot = Node3D.new()
	shield_pivot.name = "ShieldPivot"
	shield_pivot.position = ProcAnim.REST[ProcAnim.T_SHIELD_POS]
	model.add_child(shield_pivot)
	statuses = StatusComponent.new()
	statuses.name = "Statuses"
	statuses.owner_c = self
	add_child(statuses)
	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	add_child(hitbox)
	hitbox.setup(self)
	runner = AttackRunner.new()
	runner.name = "Runner"
	runner.c = self
	add_child(runner)
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	add_child(anim)
	anim.playback_default_blend_time = 0.06
	# animate on the physics tick so body movement + animation share one update rate
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_lib = AnimationLibrary.new()
	ProcAnim.add_base_animations(anim_lib)
	anim.add_animation_library("", anim_lib)
	if stats == null:
		stats = StatBlock.new()


# ------------------------------------------------------------------ rig helpers
func make_part(mesh: Mesh, color: Color, pos: Vector3, parent: Node3D = null, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = CharModel.toon(color, emissive)
	mi.position = pos
	(parent if parent else model).add_child(mi)
	return mi


func build_body(color: Color, height: float = 1.6, radius: float = 0.38) -> void:
	base_color = color
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = height
	body_mesh = make_part(cap, color, Vector3(0, height * 0.5 + 0.05, 0))
	body_material = body_mesh.material_override
	var head := SphereMesh.new()
	head.radius = radius * 0.62
	head.height = radius * 1.24
	make_part(head, color.lightened(0.25), Vector3(0, height + 0.18, -0.02))
	var visor := BoxMesh.new()
	visor.size = Vector3(radius * 0.9, 0.08, 0.05)
	make_part(visor, Color(1, 0.9, 0.6), Vector3(0, height + 0.2, -radius * 0.6), null, 2.0)


func play_attack_anim(d: AttackData, spd: float) -> void:
	var hold := team == 1
	var key := d.anim_key() + ("_h" if hold else "")
	if not anim_lib.has_animation(key):
		anim_lib.add_animation(key, ProcAnim.build_attack(d, hold))
	anim.play(key, attack_blend, spd)


func play_anim(n: String, spd: float = 1.0) -> void:
	if anim_lib.has_animation(n):
		anim.play(n, -1, spd)


# ------------------------------------------------------------------ queries
func forward() -> Vector3:
	return -global_transform.basis.z


func face_dir(dir: Vector3) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	rotation.y = atan2(-dir.x, -dir.z)


func turn_toward(dir: Vector3, rate: float, delta: float) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, rate * delta)


func is_frontal(world_pos: Vector3, max_angle_deg: float = 75.0) -> bool:
	var to := world_pos - global_position
	to.y = 0
	if to.length_squared() < 0.01:
		return true
	return forward().angle_to(to.normalized()) <= deg_to_rad(max_angle_deg)


func is_targetable() -> bool:
	return not dead and not downed and visible


func is_attacking_now() -> bool:
	return runner.is_busy() and runner.phase != AttackRunner.Phase.RECOVERY


func is_staggered() -> bool:
	return stagger_timer > 0.0


func attack_speed() -> float:
	return stats.attack_speed * statuses.mult("attack_speed")


func use_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	stamina_delay = Game.balance.stamina_regen_delay


# ------------------------------------------------------------------ damage pipeline
func build_damage(d: AttackData, target, idx: int, ctx: Dictionary) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = self
	info.target = target
	info.attack = d
	info.attack_name = d.display_name
	info.damage_type = d.damage_type
	info.hit_index = idx
	info.hit_count = maxi(1, d.hits)
	# LEVEL10-FOUNDATION-005: the deterministic numbers come from DamageCalc (shared with every tooltip)
	var h := DamageCalc.attack_hit(stats, weapon_power, d, idx, ctx, statuses.mult("damage_dealt"), statuses.mult("poise_damage"))
	var amount: float = h.amount
	info.is_heavy = d.is_heavy or (d.final_hit_heavy and idx == info.hit_count - 1)
	var cc: float = h.crit_chance + situational_crit(d, target, ctx)
	if randf() < cc:
		info.is_crit = true
		amount *= h.crit_mult
	info.amount = amount
	info.raw_amount = amount
	info.poise = h.poise
	info.guard_break = d.guard_break
	info.hitstop = d.hitstop * Game.balance.hitstop_scale
	info.knockback = d.knockback
	info.threat_mult = d.threat_mult
	info.stagger_on_hit = d.stagger_on_hit
	info.source_pos = global_position
	# state of the target BEFORE this hit resolves (the hit itself may interrupt its recovery)
	info.tags["target_recovering"] = ReaverFreeFlow.in_attack_recovery(target)
	modify_outgoing(info, d, target, idx, ctx)
	return info


## Spell / projectile / AoE damage helper (no AttackData hitbox involved).
func spell_damage(target, power: float, poise_dmg: float, attack_name: String, opts: Dictionary = {}) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = self
	info.target = target
	info.attack_name = attack_name
	info.damage_type = int(opts.get("type", AttackData.DamageType.MAGIC))
	var h := DamageCalc.spell_hit(stats, weapon_power, power, float(opts.get("crit_bonus", 0.0)), statuses.mult("damage_dealt"))
	var amount: float = h.amount
	if randf() < h.crit_chance:
		info.is_crit = true
		amount *= h.crit_mult
	info.amount = amount
	info.raw_amount = amount
	info.poise = poise_dmg
	info.is_projectile = bool(opts.get("projectile", false))
	info.guard_break = bool(opts.get("guard_break", false))
	info.source_pos = opts.get("pos", global_position)
	info.hitstop = float(opts.get("hitstop", 0.03))
	info.knockback = float(opts.get("knockback", 1.0))
	info.tags = opts.get("tags", {}).duplicate()
	info.tags["target_recovering"] = ReaverFreeFlow.in_attack_recovery(target)
	target.take_damage(info)
	return info


func take_damage(info: DamageInfo) -> DamageInfo:
	if dead or downed:
		info.cancelled = true
		return info
	if info.raw_amount <= 0.0:
		info.raw_amount = info.amount
	if is_invulnerable() and not info.is_dot:
		info.cancelled = true
		info.dodged = true
		Events.guard_event.emit(self, info, "dodge")
		on_dodged(info)
		return info
	pre_damage(info)
	if info.cancelled:
		return info
	# armor / magic resist (FOR improves effectiveness)
	var red := stats.phys_reduction() if info.damage_type == AttackData.DamageType.PHYSICAL else stats.magic_reduction()
	info.amount *= (1.0 - red) * statuses.mult("damage_taken")
	if is_invincible_debug():
		info.amount = 0.0
		info.poise = 0.0
	if shield_hp > 0.0 and Game.time < shield_until and info.amount > 0.0:
		var absorbed := minf(shield_hp, info.amount)
		shield_hp -= absorbed
		info.amount -= absorbed
		info.absorbed += absorbed
		if shield_hp <= 0.0:
			_update_shield_visual()
	info.final_amount = maxf(0.0, info.amount)
	hp -= info.final_amount
	last_attacker = info.source
	if info.final_amount > 0.0:
		flash_timer = 0.12
		if info.hitstop > 0.0 and not info.is_dot:
			hitstop = maxf(hitstop, info.hitstop)
		if info.knockback > 0.0 and is_instance_valid(info.source):
			var kb: Vector3 = global_position - info.source_pos
			kb.y = 0
			knock_velocity += kb.normalized() * info.knockback * (0.4 if info.guarded else 1.0)
		FX.damage_number(self, info)
	on_damaged(info)
	Events.damage_applied.emit(info)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		hp = 0.0
		info.killed = true
		on_zero_hp(info)
		return info
	# poise (no Poise accumulates during a Poise Break window: a break can never chain into another)
	if info.poise > 0.0 and not info.is_dot and not is_poise_broken():
		var p := info.poise * statuses.mult("poise_taken")
		if is_attacking_now() and runner.data:
			p *= 1.0 - runner.data.poise_armor
		poise -= p
		poise_delay = Game.balance.poise_regen_delay
		if poise <= 0.0:
			info.staggered = true
			info.tags["poise_break"] = true
			poise_break()
		elif info.stagger_on_hit > 0.0 and can_be_launched():
			info.staggered = true
			stagger(info.stagger_on_hit)
	return info


func add_shield(amount: float, duration: float, source = null) -> void:
	shield_hp = maxf(shield_hp if Game.time < shield_until else 0.0, 0.0) + amount
	shield_until = Game.time + duration
	_update_shield_visual()
	Events.log_message.emit("%s gains a Ward (%d)" % [display_name, roundi(amount)], "heal")
	if source != null and is_instance_valid(source):
		FX.number(self, "WARD %d" % roundi(amount), Color(0.75, 0.95, 1.0), 0.9)


func has_shield() -> bool:
	return shield_hp > 0.0 and Game.time < shield_until


func _update_shield_visual() -> void:
	var on := has_shield()
	if on and _shield_mesh == null:
		_shield_mesh = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.95
		sm.height = 2.1
		_shield_mesh.mesh = sm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.6, 0.95, 1.0, 0.16)
		m.rim_enabled = true
		_shield_mesh.material_override = m
		_shield_mesh.position = Vector3(0, 1.0, 0)
		add_child(_shield_mesh)
	if _shield_mesh:
		_shield_mesh.visible = on


func take_poise(amount: float) -> void:
	if dead or downed or is_poise_broken():
		return
	poise -= amount
	poise_delay = Game.balance.poise_regen_delay
	if poise <= 0.0:
		poise_break()


# ------------------------------------------------------------------ Poise Break (LEVEL10-FOUNDATION-005 Part 9)
var poise_break_until: float = -10.0
var poise_breaks: int = 0


## Duration of a full Poise Break (heroes: BalanceConfig.stagger_time; enemies override by tier).
func poise_break_time() -> float:
	return Game.balance.stagger_time


func is_poise_broken() -> bool:
	return Game.time < poise_break_until and stagger_timer > 0.0


## Poise reached 0: a real Poise Break opening (separate from minor hit reactions).
func poise_break() -> void:
	if dead or downed:
		return
	var was := is_staggered()
	stagger(poise_break_time(), true)
	poise_break_until = Game.time + stagger_timer
	poise_breaks += 1
	if not was:
		Events.combat_notice.emit("POISE BROKEN", self)
	on_poise_broken()


func on_poise_broken() -> void:
	pass


func heal(amount: float, source = null, tags: Dictionary = {}) -> float:
	if dead or downed:
		return 0.0
	var missing := max_hp - hp
	var actual := minf(amount, missing)
	var over := maxf(0.0, amount - actual)
	hp += actual
	Events.healed.emit(source, self, actual, over, tags)
	hp_changed.emit(hp, max_hp)
	if actual > 0.5:
		FX.number(self, "+%d" % roundi(actual), Color(0.45, 1.0, 0.55), 1.0 if actual >= 15.0 else 0.8)
	return over


func stagger(duration: float, _is_break: bool = false) -> void:
	if dead or downed:
		return
	runner.interrupt()
	stagger_timer = duration
	poise = max_poise
	play_anim("stagger", 0.6 / maxf(duration, 0.1))
	on_staggered()


# ------------------------------------------------------------------ virtual hooks
func pre_damage(_info: DamageInfo) -> void:
	pass


func modify_outgoing(_info: DamageInfo, _d: AttackData, _target, _idx: int, _ctx: Dictionary) -> void:
	pass


func situational_crit(_d: AttackData, _target, _ctx: Dictionary) -> float:
	return 0.0


func on_damaged(_info: DamageInfo) -> void:
	pass


func on_zero_hp(_info: DamageInfo) -> void:
	pass


func on_staggered() -> void:
	pass


func on_hit_landed(target, info: DamageInfo) -> void:
	if info.final_amount > 0.0 or info.guarded:
		hitstop = maxf(hitstop, info.hitstop)


func is_invulnerable() -> bool:
	return false


## Called when an attack was avoided by invulnerability frames (perfect dodge hooks).
func on_dodged(_info: DamageInfo) -> void:
	pass


func is_invincible_debug() -> bool:
	return false


func can_be_launched() -> bool:
	return true


func attack_motion_speed() -> float:
	if runner.phase == AttackRunner.Phase.ACTIVE and runner.data:
		return runner.data.lunge
	return 0.0


# ------------------------------------------------------------------ per-frame
func _physics_process(delta: float) -> void:
	if _shield_mesh and _shield_mesh.visible and not has_shield():
		_shield_mesh.visible = false
	if flash_timer > 0.0:
		flash_timer -= delta
		if body_material:
			body_material.emission_enabled = flash_timer > 0.0
			body_material.emission = Color(1, 1, 1)
			body_material.emission_energy_multiplier = 2.0
	if hitstop > 0.0:
		hitstop -= delta
		anim.speed_scale = 0.0
		return
	anim.speed_scale = 1.0
	if stagger_timer > 0.0:
		stagger_timer -= delta
	if stamina_delay > 0.0:
		stamina_delay -= delta
	elif stamina < max_stamina:
		stamina = minf(max_stamina, stamina + Game.balance.stamina_regen * stamina_regen_mult() * delta)
	if poise_delay > 0.0:
		poise_delay -= delta
	elif poise < max_poise:
		poise = minf(max_poise, poise + Game.balance.poise_regen * delta)
	combat_process(delta)
	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	velocity += knock_velocity
	move_and_slide()
	velocity -= knock_velocity
	knock_velocity = knock_velocity.move_toward(Vector3.ZERO, 18.0 * delta)
	if global_position.y < -20.0:
		fell_out_of_world()


func stamina_regen_mult() -> float:
	return 1.0


func combat_process(_delta: float) -> void:
	pass


func fell_out_of_world() -> void:
	teleport(Game.world.checkpoint_position() if Game.world else Vector3.ZERO)


## Instant relocation without an interpolation smear.
func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	reset_physics_interpolation()
