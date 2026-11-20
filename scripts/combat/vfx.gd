class_name VFX
extends RefCounted
## Element-specific effects (Update 5). Each element has its OWN shape language, not a recolor:
##   Fire  = rising embers + expanding flame shell + heat flash light
##   Life  = soft upward petals/motes + gentle ring bloom
##   Frost = angular ice crystals that jut out of the ground + cold mist
##   Storm = jagged branching lightning bolts + bright flash
##   Stone = flying rock chunks + dust ring
## Plus combat feedback: sword arcs, hit sparks, Perfect Guard flash, crit flash.
## All one-shot CPU particles with small counts (performance-conscious).

const FIRE := Color(1.0, 0.45, 0.12)
const LIFE := Color(0.5, 1.0, 0.6)
const FROST := Color(0.65, 0.9, 1.0)
const STORM := Color(0.78, 0.65, 1.0)
const STONE := Color(0.72, 0.56, 0.36)
const ELEMENT_COLORS := {"fire": Color(1.0, 0.45, 0.12), "life": Color(0.5, 1.0, 0.6), "frost": Color(0.65, 0.9, 1.0), "storm": Color(0.78, 0.65, 1.0), "stone": Color(0.72, 0.56, 0.36)}


static func _root() -> Node:
	return Game.fx_root()


static func _unshaded(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	return m


static func _add(n: Node3D, pos: Vector3) -> bool:
	var root := _root()
	if root == null:
		return false
	n.set("physics_interpolation_mode", 2)
	root.add_child(n)
	n.global_position = pos
	return true


static func _free_after(n: Node, t: float) -> void:
	var tw := n.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(n.queue_free)


static func particles(pos: Vector3, mesh: Mesh, mat: Material, amount: int, life: float, opts: Dictionary = {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = bool(opts.get("one_shot", true))
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = float(opts.get("explosiveness", 0.9))
	p.mesh = mesh
	p.material_override = mat
	p.direction = opts.get("direction", Vector3.UP)
	p.spread = float(opts.get("spread", 180.0))
	p.initial_velocity_min = float(opts.get("vmin", 2.0))
	p.initial_velocity_max = float(opts.get("vmax", 5.0))
	p.gravity = opts.get("gravity", Vector3(0, -9.8, 0))
	p.damping_min = float(opts.get("damping", 0.0))
	p.damping_max = float(opts.get("damping", 0.0))
	p.scale_amount_min = float(opts.get("smin", 0.6))
	p.scale_amount_max = float(opts.get("smax", 1.2))
	p.emission_shape = int(opts.get("shape", CPUParticles3D.EMISSION_SHAPE_SPHERE))
	p.emission_sphere_radius = float(opts.get("radius", 0.3))
	p.emission_ring_radius = float(opts.get("ring_radius", 1.0))
	p.emission_ring_inner_radius = float(opts.get("ring_inner", 0.0))
	p.emission_ring_height = 0.1
	p.emission_ring_axis = Vector3.UP
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	if opts.has("color_ramp"):
		p.color_ramp = opts.color_ramp
	if not _add(p, pos):
		return null
	p.emitting = true
	if p.one_shot:
		_free_after(p, life + 0.2)
	return p


static func _ramp(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


static func _quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


static func _billboard(color: Color, emission: float = 2.0) -> StandardMaterial3D:
	var m := _unshaded(color, emission)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


static func flash_light(pos: Vector3, color: Color, energy: float, rng: float, t: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	if not _add(l, pos):
		return
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, t)
	tw.tween_callback(l.queue_free)


static func shell(pos: Vector3, radius: float, color: Color, t: float, squash: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 24
	s.rings = 12
	mi.mesh = s
	var m := _unshaded(Color(color.r, color.g, color.b, 0.5), 1.5)
	mi.material_override = m
	if not _add(mi, pos):
		return
	mi.scale = Vector3(0.2, 0.2 * squash, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * squash, radius), t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, t)
	tw.chain().tween_callback(mi.queue_free)


static func ground_ring(pos: Vector3, radius: float, color: Color, t: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 48
	mi.mesh = tm
	var m := _unshaded(Color(color.r, color.g, color.b, 0.8), 2.0)
	mi.material_override = m
	if not _add(mi, pos + Vector3(0, 0.08, 0)):
		return
	mi.scale = Vector3(0.3, 0.2, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.2, radius), t).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, t)
	tw.chain().tween_callback(mi.queue_free)


# ----------------------------------------------------------------- elements
static func fire_burst(pos: Vector3, radius: float) -> void:
	shell(pos + Vector3(0, 0.3, 0), radius, Color(1.0, 0.55, 0.15), 0.35, 0.7)
	particles(pos + Vector3(0, 0.4, 0), _quad(0.22), _billboard(Color(1, 0.6, 0.2), 3.0), 18 + int(radius * 4), 0.9,
		{"vmin": 1.5, "vmax": 3.5 + radius, "gravity": Vector3(0, 3.0, 0), "damping": 2.0, "radius": radius * 0.4,
		"color_ramp": _ramp(Color(1.0, 0.85, 0.3), Color(0.6, 0.1, 0.02, 0.0))})
	flash_light(pos + Vector3(0, 1, 0), FIRE, 4.0, radius * 3.0, 0.4)


static func frost_burst(pos: Vector3, radius: float) -> void:
	# crystals jut out of the ground in a ring, then shatter
	var root := _root()
	if root == null:
		return
	var m := _unshaded(Color(0.75, 0.93, 1.0, 0.85), 1.2)
	var n := clampi(int(radius * 4), 4, 14)
	for i in n:
		var a := TAU * i / float(n) + randf() * 0.4
		var r := radius * randf_range(0.35, 0.95)
		var c := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.25, randf_range(0.6, 1.2) * clampf(radius * 0.5, 0.6, 1.6), 0.25)
		c.mesh = pm
		c.material_override = m
		if not _add(c, pos + Vector3(cos(a) * r, 0.0, sin(a) * r)):
			return
		c.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		c.scale = Vector3(1, 0.05, 1)
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5)
		tw.tween_property(c, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
		tw.tween_callback(c.queue_free)
	particles(pos + Vector3(0, 0.3, 0), _quad(0.4), _billboard(Color(0.85, 0.95, 1.0, 0.35), 0.5), 10, 1.0,
		{"vmin": 0.5, "vmax": 1.5, "gravity": Vector3.ZERO, "damping": 1.0, "radius": radius * 0.5,
		"color_ramp": _ramp(Color(0.9, 0.97, 1.0, 0.5), Color(0.7, 0.9, 1.0, 0.0))})


static func lightning(from: Vector3, to: Vector3, color: Color = STORM) -> void:
	# jagged polyline of thin boxes + a random side-branch
	var segs := 7
	var pts: Array = [from]
	var perp := (to - from).cross(Vector3.UP)
	if perp.length() < 0.01:
		perp = Vector3.RIGHT
	perp = perp.normalized()
	var perp2 := (to - from).cross(perp).normalized()
	var jitter := from.distance_to(to) * 0.08
	for i in range(1, segs):
		var p := from.lerp(to, i / float(segs))
		p += perp * randf_range(-jitter, jitter) + perp2 * randf_range(-jitter, jitter)
		pts.append(p)
	pts.append(to)
	for i in pts.size() - 1:
		_bolt_seg(pts[i], pts[i + 1], color, 0.07)
	var bi := randi_range(1, segs - 2)
	var bend: Vector3 = pts[bi] + (perp * randf_range(-1, 1) + Vector3(0, -1, 0)).normalized() * from.distance_to(to) * 0.18
	_bolt_seg(pts[bi], bend, color, 0.04)
	flash_light(to, color, 5.0, 6.0, 0.18)
	particles(to, _quad(0.1), _billboard(Color(0.95, 0.9, 1.0), 4.0), 8, 0.3, {"vmin": 3.0, "vmax": 6.0, "gravity": Vector3(0, -6, 0)})


static func _bolt_seg(a: Vector3, b: Vector3, color: Color, w: float) -> void:
	if a.distance_to(b) < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, w, a.distance_to(b))
	mi.mesh = bm
	var m := _unshaded(Color(0.95, 0.92, 1.0, 1.0), 4.0)
	m.emission = color
	mi.material_override = m
	if not _add(mi, (a + b) * 0.5):
		return
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(mi.queue_free)


static func stone_burst(pos: Vector3, radius: float) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.18, 0.2)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.4, 0.3)
	m.roughness = 1.0
	particles(pos + Vector3(0, 0.2, 0), bm, m, 10 + int(radius * 3), 1.0,
		{"direction": Vector3.UP, "spread": 50.0, "vmin": 4.0, "vmax": 7.0, "radius": radius * 0.4, "gravity": Vector3(0, -18, 0), "smin": 0.6, "smax": 1.6})
	particles(pos + Vector3(0, 0.2, 0), _quad(0.7), _billboard(Color(0.7, 0.6, 0.45, 0.4), 0.0), 12, 1.2,
		{"shape": CPUParticles3D.EMISSION_SHAPE_RING, "ring_radius": radius * 0.6, "vmin": 0.5, "vmax": 1.5, "gravity": Vector3(0, 0.4, 0), "damping": 1.0,
		"color_ramp": _ramp(Color(0.75, 0.65, 0.5, 0.5), Color(0.6, 0.55, 0.45, 0.0))})
	ground_ring(pos, radius, STONE, 0.4)


static func life_bloom(pos: Vector3, radius: float) -> void:
	ground_ring(pos, radius, LIFE, 0.7)
	particles(pos + Vector3(0, 0.2, 0), _quad(0.16), _billboard(Color(0.7, 1.0, 0.75), 2.5), 20, 1.6,
		{"shape": CPUParticles3D.EMISSION_SHAPE_RING, "ring_radius": radius * 0.7, "direction": Vector3.UP, "spread": 15.0, "vmin": 1.0, "vmax": 2.2,
		"gravity": Vector3(0, 0.3, 0), "color_ramp": _ramp(Color(0.85, 1.0, 0.8), Color(0.4, 1.0, 0.6, 0.0))})
	flash_light(pos + Vector3(0, 1, 0), LIFE, 2.0, radius * 2.0, 0.6)


static func heal_motes(target) -> void:
	if not is_instance_valid(target):
		return
	particles(target.global_position + Vector3(0, 0.6, 0), _quad(0.12), _billboard(Color(0.7, 1.0, 0.75), 2.5), 8, 1.0,
		{"direction": Vector3.UP, "spread": 25.0, "vmin": 1.0, "vmax": 2.0, "gravity": Vector3.ZERO, "radius": 0.45,
		"color_ramp": _ramp(Color(0.9, 1.0, 0.85), Color(0.4, 1.0, 0.6, 0.0))})


## Continuous ambient motes for a sigil (lives as a child of `parent`).
static func element_motes(parent: Node3D, element: String, radius: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.6
	p.mesh = _quad(0.12 if element != "stone" else 0.16)
	var col: Color = {"fire": FIRE, "life": LIFE, "frost": FROST, "storm": STORM, "stone": STONE}.get(element, Color.WHITE)
	p.material_override = _billboard(col, 2.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius * 0.9
	p.emission_ring_inner_radius = 0.0
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 10.0
	match element:
		"fire":
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0, 1.5, 0)
		"frost":
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.4
			p.gravity = Vector3(0, -0.3, 0)
		"storm":
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.0
			p.spread = 90.0
			p.gravity = Vector3.ZERO
			p.lifetime = 0.4
		"stone":
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.gravity = Vector3(0, 0.2, 0)
		_:
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 1.0
			p.gravity = Vector3(0, 0.2, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	parent.add_child(p)
	p.emitting = true


# ----------------------------------------------------------------- weapons
## A sword arc: a curved ribbon sweeping around `who` in the facing direction.
static func sword_arc(who: Node3D, color: Color, radius: float = 1.6, arc_deg: float = 140.0, height: float = 1.1, tilt: float = 0.0, t: float = 0.18) -> void:
	var root := _root()
	if root == null or not is_instance_valid(who):
		return
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := _unshaded(Color(color.r, color.g, color.b, 0.85), 3.0)
	mi.material_override = m
	var steps := 16
	var a0 := deg_to_rad(-arc_deg * 0.5)
	var a1 := deg_to_rad(arc_deg * 0.5)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in steps + 1:
		var f := i / float(steps)
		var a := lerpf(a0, a1, f)
		var w := sin(f * PI) * 0.35 + 0.03
		var dir := Vector3(sin(a), 0, -cos(a))
		im.surface_set_color(Color(1, 1, 1, f))
		im.surface_add_vertex(dir * (radius - w))
		im.surface_set_color(Color(1, 1, 1, f))
		im.surface_add_vertex(dir * radius + Vector3(0, w * 0.15, 0))
	im.surface_end()
	if not _add(mi, who.global_position + Vector3(0, height, 0)):
		return
	mi.global_rotation = Vector3(0, who.global_rotation.y, tilt)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(m, "albedo_color:a", 0.0, t)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.08, t)
	tw.chain().tween_callback(mi.queue_free)


static func hit_sparks(pos: Vector3, color: Color = Color(1.0, 0.85, 0.5), count: int = 10, crit: bool = false) -> void:
	particles(pos, _quad(0.07 if not crit else 0.1), _billboard(color, 4.0), count * (2 if crit else 1), 0.35,
		{"vmin": 4.0, "vmax": 8.0 if not crit else 11.0, "gravity": Vector3(0, -12, 0), "radius": 0.1, "smin": 0.5, "smax": 1.0})
	if crit:
		shell(pos, 0.9, Color(1.0, 0.9, 0.5), 0.15)
		flash_light(pos, Color(1.0, 0.85, 0.5), 3.0, 4.0, 0.15)


static func guard_flash(pos: Vector3, facing: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.9
	tm.rings = 40
	mi.mesh = tm
	var m := _unshaded(Color(1.0, 0.86, 0.4, 0.95), 4.0)
	mi.material_override = m
	if not _add(mi, pos):
		return
	if facing.length() > 0.01:
		mi.look_at(pos + facing, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	mi.scale = Vector3.ONE * 0.4
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(mi.queue_free)
	hit_sparks(pos, Color(1.0, 0.85, 0.4), 16)
	flash_light(pos, Color(1.0, 0.85, 0.45), 5.0, 6.0, 0.25)


static func opening_glint(pos: Vector3) -> void:
	particles(pos, _quad(0.18), _billboard(Color(1.0, 0.95, 0.75), 5.0), 3, 0.25, {"vmin": 0.0, "vmax": 0.3, "gravity": Vector3.ZERO, "radius": 0.05, "smin": 1.0, "smax": 1.6})
