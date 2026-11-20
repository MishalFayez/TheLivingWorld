class_name AshCaster
extends Enemy
## Ranged magic: Ash Bolt projectiles, delayed Ash Burst ground AoE, keeps its distance.
## Readability pass: long, visible casts (glowing orb grows at the staff tip + rune circle under
## the caster), slower projectiles, a long gap between casts and a delayed burst marked on the ground.

const BOLT_SPEED := 10.0
const BURST_DELAY := 0.9

var burst_pos: Vector3
var charge_orb: MeshInstance3D
var cast_ring: Telegraph


func setup_type() -> void:
	display_name = "Ash Caster"
	enemy_type = "ash_caster"
	weight_class = "light"
	base_hp = 65.0
	base_poise = 25.0
	base_power = 12.0
	armor = 5.0
	magic_resist = 35.0
	move_speed = 3.6
	turn_speed = 6.0
	aggro_range = 18.0
	preferred_range = 10.0
	global_cd = 1.8
	post_pause = 0.8
	engage_delay = Vector2(0.3, 0.7)
	enemy_attack_speed = 0.9
	load_attacks(["caster_bolt", "caster_burst"])
	base_color = Color(0.2, 0.18, 0.2)
	CharModel.build(self, "caster", null)


func on_attack_start(d: AttackData) -> void:
	var cast_time := d.startup / maxf(runner.speed, 0.1)
	_clear_cast_fx()
	# growing orb at the staff tip
	charge_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	charge_orb.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.45, 0.9) if d.special == "ground_burst" else Color(1.0, 0.5, 0.15)
	m.emission_enabled = true
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 4.0
	charge_orb.material_override = m
	weapon_pivot.add_child(charge_orb)
	charge_orb.position = Vector3(0, 0, -1.3)
	charge_orb.scale = Vector3.ONE * 0.2
	var light := OmniLight3D.new()
	light.light_color = m.albedo_color
	light.omni_range = 4.0
	charge_orb.add_child(light)
	var tw := charge_orb.create_tween()
	tw.tween_property(charge_orb, "scale", Vector3.ONE * 1.6, cast_time).set_ease(Tween.EASE_IN)
	# rune circle under the caster for the whole cast
	cast_ring = Telegraph.circle(global_position, 1.3, cast_time, Color(0.8, 0.35, 1.0, 0.55))
	cast_ring.auto_free = true
	if d.special == "ground_burst" and target != null and is_instance_valid(target):
		burst_pos = target.global_position
		var tg := Telegraph.circle(burst_pos, d.hitbox_size.x * 0.5, cast_time + BURST_DELAY, Color(1.0, 0.3, 0.1, 0.6))
		tg.auto_free = true


func _clear_cast_fx() -> void:
	if charge_orb != null and is_instance_valid(charge_orb):
		charge_orb.queue_free()
	charge_orb = null


func on_attack_end(_d: AttackData, _interrupted: bool) -> void:
	_clear_cast_fx()


func on_attack_active(d: AttackData) -> void:
	_clear_cast_fx()
	match d.special:
		"projectile":
			fire_projectile(d, null, BOLT_SPEED, 0.45, Color(1.0, 0.45, 0.15))
		"ground_burst":
			var me := self
			var pos := burst_pos
			var r := d.hitbox_size.x * 0.5
			var power := d.damage_mult
			var poise_dmg := d.poise_damage
			var nm := d.display_name
			var cb := func(z):
				FX.burst(pos + Vector3(0, 0.3, 0), r, Color(1.0, 0.35, 0.1))
				if not is_instance_valid(me):
					return
				for h in z.members("heroes"):
					me.spell_damage(h, power, poise_dmg, nm, {"pos": pos})
			GroundZone.spawn(self, pos, r, BURST_DELAY + 0.02, Color(1.0, 0.3, 0.1), BURST_DELAY, cb)
