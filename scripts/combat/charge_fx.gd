class_name ChargeFX
extends Node3D
## Spell-charge feedback on the Mage (not just a bar): energy gathers at the staff tip in an
## element-specific form and a ground ring grows under the caster. A flash marks FULL charge.
##   Fire  = flickering flame core + rising embers        Frost = orbiting crystal shards + mist
##   Stone = rock fragments converging into a mass         Storm = crackling unstable arcs
##   Life  = soft bloom + circling petals of light

var element: String = "fire"
var ratio: float = 0.0
var full: bool = false
var tip: Node3D
var ground: MeshInstance3D
var ground_mat: StandardMaterial3D
var core: MeshInstance3D
var core_mat: StandardMaterial3D
var orbit: Node3D
var parts: CPUParticles3D
var arcs: Array = []
var t: float = 0.0
var col: Color


static func attach(hero, p_element: String) -> ChargeFX:
	var f := ChargeFX.new()
	f.element = p_element
	f.col = VFX.ELEMENT_COLORS.get(p_element, Color.WHITE)
	hero.add_child(f)
	f._build(hero)
	return f


func _m(c: Color, e: float, a: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _build(hero) -> void:
	tip = Node3D.new()
	tip.position = Vector3(0, 0, -1.36)
	hero.weapon_pivot.add_child(tip)
	core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	core.mesh = sm
	core_mat = _m(col.lightened(0.3), 3.0, 0.9)
	core.material_override = core_mat
	tip.add_child(core)
	orbit = Node3D.new()
	tip.add_child(orbit)
	match element:
		"frost":
			for i in 4:
				var pm := PrismMesh.new()
				pm.size = Vector3(0.06, 0.18, 0.06)
				var mi := MeshInstance3D.new()
				mi.mesh = pm
				mi.material_override = _m(Color(0.8, 0.95, 1.0), 1.5, 0.9)
				var a := TAU * i / 4.0
				mi.position = Vector3(cos(a), sin(a), 0) * 0.28
				mi.rotation.z = a
				orbit.add_child(mi)
		"stone":
			for i in 5:
				var bm := BoxMesh.new()
				bm.size = Vector3(0.09, 0.08, 0.09)
				var mi := MeshInstance3D.new()
				mi.mesh = bm
				mi.material_override = CharModel.toon(Color(0.55, 0.45, 0.35))
				var a := TAU * i / 5.0
				mi.position = Vector3(cos(a), sin(a), 0) * 0.45
				orbit.add_child(mi)
		"life":
			for i in 6:
				var qm := QuadMesh.new()
				qm.size = Vector2(0.08, 0.16)
				var mi := MeshInstance3D.new()
				mi.mesh = qm
				var pm := _m(Color(0.75, 1.0, 0.8), 2.0, 0.85)
				pm.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.material_override = pm
				var a := TAU * i / 6.0
				mi.position = Vector3(cos(a), sin(a), 0) * 0.3
				mi.rotation.z = a
				orbit.add_child(mi)
		"storm":
			for i in 3:
				var bm := BoxMesh.new()
				bm.size = Vector3(0.02, 0.02, 0.3)
				var mi := MeshInstance3D.new()
				mi.mesh = bm
				mi.material_override = _m(Color(0.95, 0.9, 1.0), 4.0)
				orbit.add_child(mi)
				arcs.append(mi)
	parts = CPUParticles3D.new()
	parts.amount = 10
	parts.lifetime = 0.7
	parts.mesh = VFX._quad(0.06)
	parts.material_override = VFX._billboard(col, 3.0)
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 0.25
	parts.gravity = Vector3(0, 1.5 if element == "fire" else (-0.5 if element == "frost" else 0.0), 0)
	parts.initial_velocity_min = 0.1
	parts.initial_velocity_max = 0.6 if element != "storm" else 2.0
	parts.spread = 180.0
	tip.add_child(parts)
	# ground ring
	ground = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 40
	ground.mesh = tm
	ground_mat = _m(col, 2.0, 0.0)
	ground.material_override = ground_mat
	ground.scale = Vector3(0.4, 0.15, 0.4)
	ground.position = Vector3(0, 0.06, 0)
	add_child(ground)
	set_ratio(0.0, false)


func set_ratio(r: float, is_full: bool) -> void:
	ratio = r
	var s := 0.35 + r * 1.0
	core.scale = Vector3.ONE * s
	orbit.scale = Vector3.ONE * (1.3 - r * 0.5) if element == "stone" else Vector3.ONE * (0.6 + r * 0.6)
	ground.scale = Vector3(0.4 + r * 0.9, 0.15, 0.4 + r * 0.9)
	ground_mat.albedo_color.a = 0.25 + r * 0.55
	parts.amount = 10
	parts.emitting = true
	if is_full and not full:
		full = true
		VFX.ground_ring(get_parent().global_position, 1.8, col, 0.3)
		VFX.flash_light(tip.global_position, col, 3.0, 4.0, 0.2)
		core_mat.emission_energy_multiplier = 5.0


func _process(delta: float) -> void:
	t += delta
	orbit.rotation.z += delta * (2.0 if element != "stone" else 1.2) * (1.0 + ratio)
	core.scale *= 1.0 + (0.06 * sin(t * 30.0) if element == "fire" else 0.0)
	for a in arcs:
		a.position = Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.1, 0.1))
		a.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		a.visible = randf() < 0.4 + ratio * 0.5


func finish() -> void:
	if is_instance_valid(tip):
		tip.queue_free()
	queue_free()
