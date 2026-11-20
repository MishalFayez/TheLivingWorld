class_name FireWave
extends Node3D
## Inferno Wave: a forward-moving wall of flame across the ground. Hits each enemy once per wave,
## stops at world geometry, and contacts Frost formations it passes (Thermal Fracture via the Mage).

var el = null                 # MageElementalist that cast it
var dir: Vector3 = Vector3.FORWARD
var speed: float = 11.0
var half_width: float = 1.6
var life: float = 1.2
var power: float = 1.0
var poise: float = 10.0
var burn_power: float = 0.2
var full: bool = false
var label: String = "Inferno Wave"
var hit: Dictionary = {}
var touched: Dictionary = {}
var t: float = 0.0
var parts: CPUParticles3D


static func launch(p_el, from: Vector3, p_dir: Vector3, p_speed: float, p_half_width: float, p_life: float, p_power: float, p_poise: float, p_burn: float, p_full: bool, p_label: String) -> FireWave:
	var w := FireWave.new()
	w.el = p_el
	p_dir.y = 0
	w.dir = p_dir.normalized() if p_dir.length() > 0.01 else Vector3.FORWARD
	w.speed = p_speed
	w.half_width = p_half_width
	w.life = p_life
	w.power = p_power
	w.poise = p_poise
	w.burn_power = p_burn
	w.full = p_full
	w.label = p_label
	Game.fx_root().add_child(w)
	w.global_position = from
	w.look_at(from + w.dir, Vector3.UP)
	w._build()
	return w


func _build() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(half_width * 2.0, 1.1, 0.35)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.5, 0.15, 0.55)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.1)
	m.emission_energy_multiplier = 2.5
	mi.material_override = m
	mi.position = Vector3(0, 0.55, 0)
	add_child(mi)
	parts = CPUParticles3D.new()
	parts.amount = 36
	parts.lifetime = 0.5
	parts.mesh = VFX._quad(0.35)
	parts.material_override = VFX._billboard(Color(1.0, 0.55, 0.2), 3.0)
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(half_width, 0.2, 0.2)
	parts.gravity = Vector3(0, 3.0, 0)
	parts.initial_velocity_min = 0.5
	parts.initial_velocity_max = 2.0
	parts.position = Vector3(0, 0.3, 0)
	add_child(parts)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = half_width * 2.5
	light.light_energy = 1.6
	light.position = Vector3(0, 1.0, 0)
	add_child(light)


func _physics_process(delta: float) -> void:
	t += delta
	var from := global_position + Vector3(0, 0.6, 0)
	var to := from + dir * speed * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Combatant.LAYER_WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty() or t >= life or el == null or not is_instance_valid(el.hero):
		_finish()
		return
	global_position += dir * speed * delta
	var h = el.hero
	var side := dir.cross(Vector3.UP).normalized()
	for e in h.enemies_within(half_width + 1.0, global_position):
		if hit.has(e):
			continue
		var d: Vector3 = e.global_position - global_position
		if absf(d.dot(side)) <= half_width + 0.4 and absf(d.dot(dir)) <= 0.9:
			hit[e] = true
			h.spell_damage(e, power, poise, label, {"pos": global_position - dir, "knockback": 1.5, "hitstop": 0.03})
			ElementalStates.apply_burning(e, h, 2.0, burn_power)
	# Fire contacting Frost structures (Thermal Fracture) - each formation once per wave
	for f in WorldFormation.active():
		if f.element != "frost" or touched.has(f):
			continue
		if not f.segments_within(global_position, half_width).is_empty():
			touched[f] = true
			el.thermal_fracture(f, global_position, half_width, full)


func _finish() -> void:
	set_physics_process(false)
	if parts:
		parts.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1, 0.05, 1), 0.2)
	tw.tween_callback(queue_free)
