class_name Scenery
extends RefCounted
## Stylized environment art for Ashen Valley (Update 5). Pure decoration: no collision, no gameplay
## changes. Built from primitives + MultiMesh (grass, flowers, trees, rocks) for performance.
##   Valley Outskirts : green valley, dirt road, scattered ash scars, trees and cliffs.
##   Forgotten Ruins  : mossy stone floor, broken columns, ruined arches, glowing ley crystals.
##   Warden's Keep    : ash-covered courtyard, castle walls with crenellations, towers, braziers.
## Atmosphere (fog / ambient / sky tint) blends with the player's depth into the valley.

static var env: Environment
static var scars: Array = []        ## Vector3(x, radius, z) of ash scars (grass avoids them)
static var _rng := RandomNumberGenerator.new()


static func mat(color: Color, rim: float = 0.0, emissive: float = 0.0) -> StandardMaterial3D:
	var m := CharModel.toon(color, emissive, rim)
	m.roughness = 1.0
	return m


static func _mm(parent: Node3D, mesh: Mesh, material: Material, xforms: Array, colors: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if material:
		var m: StandardMaterial3D = material
		if mm.use_colors:
			m.vertex_color_use_as_albedo = true
		mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mesh is QuadMesh or mesh.get_aabb().size.y < 0.6 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func _xf(pos: Vector3, rot_y: float, scl: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scl), pos)


static func mesh_inst(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.visibility_range_end = 120.0
	mi.visibility_range_end_margin = 10.0
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ atmosphere
static func environment(root: Node3D) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.48, 0.82)
	sm.sky_horizon_color = Color(0.78, 0.82, 0.86)
	sm.ground_bottom_color = Color(0.25, 0.27, 0.22)
	sm.ground_horizon_color = Color(0.7, 0.72, 0.7)
	sm.sun_angle_max = 25.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.65
	e.ambient_light_sky_contribution = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 0.9
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.ssao_enabled = true          # Forward+ only (ignored by the Compatibility renderer)
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.72, 0.8, 0.88)
	e.fog_density = 0.0045
	e.fog_aerial_perspective = 0.35
	e.fog_sky_affect = 0.25
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.04
	we.environment = e
	env = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(sun)


## Blend the atmosphere from bright green valley (z > -30) to ashen keep (z < -130).
static func update_atmosphere(z: float) -> void:
	if env == null:
		return
	var t := clampf((-z - 30.0) / 110.0, 0.0, 1.0)
	env.fog_light_color = Color(0.72, 0.8, 0.88).lerp(Color(0.5, 0.4, 0.36), t)
	env.fog_density = lerpf(0.0045, 0.012, t)
	env.ambient_light_energy = lerpf(0.65, 0.5, t)
	env.adjustment_saturation = lerpf(1.12, 0.95, t)
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	sm.sky_top_color = Color(0.28, 0.48, 0.82).lerp(Color(0.35, 0.3, 0.32), t)
	sm.sky_horizon_color = Color(0.78, 0.82, 0.86).lerp(Color(0.62, 0.48, 0.4), t)


# ------------------------------------------------------------------ props
static func tree_xforms(points: Array) -> Array:
	return points


## Stylized trees (trunk + 2-3 foliage blobs) as MultiMeshes.
static func forest(parent: Node3D, points: Array, autumn: float = 0.0) -> void:
	var trunks: Array = []
	var leaves_a: Array = []
	var leaves_b: Array = []
	var cols_a: Array = []
	var cols_b: Array = []
	for p in points:
		var s := _rng.randf_range(0.8, 1.35)
		var ry := _rng.randf() * TAU
		trunks.append(_xf(p + Vector3(0, 1.6 * s, 0), ry, Vector3(s, s, s)))
		var base := Color(0.3, 0.55, 0.25).lerp(Color(0.75, 0.5, 0.2), autumn * _rng.randf())
		leaves_a.append(_xf(p + Vector3(0, 3.6 * s, 0), ry, Vector3(1.6, 1.25, 1.6) * s))
		cols_a.append(base.lightened(_rng.randf_range(0.0, 0.12)))
		leaves_b.append(_xf(p + Vector3(_rng.randf_range(-0.5, 0.5), 4.7 * s, _rng.randf_range(-0.5, 0.5)), ry, Vector3(1.1, 1.0, 1.1) * s))
		cols_b.append(base.lightened(0.15))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.26
	trunk.height = 3.2
	trunk.radial_segments = 8
	_mm(parent, trunk, mat(Color(0.38, 0.27, 0.18)), trunks)
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 10
	blob.rings = 6
	_mm(parent, blob, mat(Color.WHITE, 0.25), leaves_a, cols_a)
	_mm(parent, blob, mat(Color.WHITE, 0.25), leaves_b, cols_b)


static func pine_forest(parent: Node3D, points: Array) -> void:
	var trunks: Array = []
	var cones: Array = []
	var cols: Array = []
	for p in points:
		var s := _rng.randf_range(0.9, 1.6)
		trunks.append(_xf(p + Vector3(0, 0.8 * s, 0), 0.0, Vector3(s, s, s)))
		for k in 3:
			cones.append(_xf(p + Vector3(0, (1.8 + k * 1.2) * s, 0), _rng.randf() * TAU, Vector3(1.0 - k * 0.25, 1.0, 1.0 - k * 0.25) * s))
			cols.append(Color(0.18, 0.38, 0.25).lightened(k * 0.05 + _rng.randf() * 0.05))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.2
	trunk.height = 1.6
	trunk.radial_segments = 6
	_mm(parent, trunk, mat(Color(0.32, 0.22, 0.15)), trunks)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.3
	cone.height = 2.0
	cone.radial_segments = 8
	_mm(parent, cone, mat(Color.WHITE, 0.2), cones, cols)


static func grass(parent: Node3D, center: Vector3, size: Vector2, count: int, base: Color, avoid_road: bool = false) -> void:
	var xf: Array = []
	var cols: Array = []
	for i in count:
		var p := center + Vector3(_rng.randf_range(-size.x * 0.5, size.x * 0.5), 0.0, _rng.randf_range(-size.y * 0.5, size.y * 0.5))
		if avoid_road and absf(p.x - road_x(p.z)) < 2.6:
			continue
		var in_scar := false
		for sc in scars:
			if Vector2(p.x - sc.x, p.z - sc.z).length() < sc.y:
				in_scar = true
				break
		if in_scar:
			continue
		var s := _rng.randf_range(0.6, 1.3)
		xf.append(_xf(p + Vector3(0, 0.16 * s, 0), _rng.randf() * TAU, Vector3(s, s, s)))
		cols.append(base.lightened(_rng.randf_range(-0.08, 0.15)))
	var blade := PrismMesh.new()
	blade.size = Vector3(0.22, 0.34, 0.02)
	var m := mat(Color.WHITE, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mm(parent, blade, m, xf, cols)
	# crossed second blade set for fuller tufts
	var xf2: Array = []
	for t in xf:
		xf2.append(Transform3D(t.basis.rotated(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(0.8, 0.85, 0.8)), t.origin))
	var m2 := mat(Color.WHITE, 0.0)
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mm(parent, blade, m2, xf2, cols)


static func flowers(parent: Node3D, center: Vector3, size: Vector2, count: int) -> void:
	var xf: Array = []
	var cols: Array = []
	var palette := [Color(1, 1, 0.95), Color(1.0, 0.85, 0.3), Color(0.75, 0.6, 1.0), Color(1.0, 0.55, 0.6)]
	for i in count:
		var p := center + Vector3(_rng.randf_range(-size.x * 0.5, size.x * 0.5), 0.22, _rng.randf_range(-size.y * 0.5, size.y * 0.5))
		if absf(p.x - road_x(p.z)) < 2.6:
			continue
		xf.append(_xf(p, 0.0, Vector3.ONE * _rng.randf_range(0.7, 1.2)))
		cols.append(palette[_rng.randi() % palette.size()])
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.1
	s.radial_segments = 6
	s.rings = 3
	_mm(parent, s, mat(Color.WHITE, 0.0, 0.3), xf, cols)


static func road_x(z: float) -> float:
	return sin(z * 0.06) * 3.5


## Winding dirt road with flagstones down the middle of the valley.
static func road(parent: Node3D, z_from: float, z_to: float) -> void:
	var dirt: Array = []
	var stones: Array = []
	var cols: Array = []
	var z := z_from
	while z > z_to:
		var x := road_x(z)
		dirt.append(_xf(Vector3(x, 0.005, z), atan(cos(z * 0.06) * 0.21), Vector3(4.2, 1, 1.3)))
		for k in 3:
			var sx := x + _rng.randf_range(-1.4, 1.4)
			stones.append(_xf(Vector3(sx, 0.02, z + _rng.randf_range(-0.4, 0.4)), _rng.randf() * TAU, Vector3(_rng.randf_range(0.5, 0.9), 1, _rng.randf_range(0.4, 0.7))))
			cols.append(Color(0.62, 0.58, 0.52).lightened(_rng.randf_range(-0.1, 0.1)))
		z -= 1.1
	var q := BoxMesh.new()
	q.size = Vector3(1, 0.01, 1)
	_mm(parent, q, mat(Color(0.56, 0.45, 0.3)), dirt)
	var st := CylinderMesh.new()
	st.top_radius = 0.5
	st.bottom_radius = 0.55
	st.height = 0.04
	st.radial_segments = 7
	_mm(parent, st, mat(Color.WHITE), stones, cols)


## Burnt ash scars: dark discs, charred stumps and a few drifting embers.
static func ash_scar(parent: Node3D, pos: Vector3, radius: float) -> void:
	scars.append(Vector3(pos.x, radius, pos.z))
	var d := CylinderMesh.new()
	d.top_radius = radius
	d.bottom_radius = radius
	d.height = 0.02
	d.radial_segments = 14
	mesh_inst(parent, d, mat(Color(0.2, 0.19, 0.19)), pos + Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1, 1, _rng.randf_range(0.7, 1.0)))
	var d2 := CylinderMesh.new()
	d2.top_radius = radius * 0.6
	d2.bottom_radius = radius * 0.6
	d2.height = 0.02
	mesh_inst(parent, d2, mat(Color(0.12, 0.11, 0.11)), pos + Vector3(radius * 0.2, 0.02, 0))
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 3.0
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	p.mesh = q
	var em := VFX._billboard(Color(1.0, 0.5, 0.15), 3.0)
	p.material_override = em
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(radius * 0.7, 0.1, radius * 0.7)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.2, 0.15, 0)
	p.position = pos + Vector3(0, 0.1, 0)
	parent.add_child(p)


## Irregular stylized boulder made of a few squashed spheres (decoration over a collision box).
static func boulder(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 8
	s.rings = 5
	var m := mat(color, 0.15)
	mesh_inst(parent, s, m, pos, Vector3(0, _rng.randf() * TAU, 0), size * Vector3(1.15, 1.1, 1.15))
	for k in 2:
		var o := Vector3(_rng.randf_range(-0.4, 0.4) * size.x, -size.y * 0.15, _rng.randf_range(-0.4, 0.4) * size.z)
		mesh_inst(parent, s, mat(color.darkened(0.12), 0.15), pos + o, Vector3(0, _rng.randf() * TAU, 0), size * _rng.randf_range(0.55, 0.8))
	var moss := SphereMesh.new()
	moss.radius = 0.5
	moss.height = 0.5
	moss.is_hemisphere = true
	mesh_inst(parent, moss, mat(Color(0.35, 0.52, 0.27)), pos + Vector3(0, size.y * 0.42, 0), Vector3.ZERO, size * Vector3(0.9, 0.35, 0.9))


## Rocky cliff dressing along a straight wall (x or z aligned).
static func cliff(parent: Node3D, from: Vector3, to: Vector3, color: Color, height: float = 6.0) -> void:
	var xf: Array = []
	var cols: Array = []
	var n := int(from.distance_to(to) / 2.2)
	for i in n + 1:
		var p := from.lerp(to, i / float(maxi(1, n)))
		for k in 2:
			var s := Vector3(_rng.randf_range(2.0, 3.4), _rng.randf_range(height * 0.6, height * 1.1), _rng.randf_range(2.0, 3.2))
			xf.append(_xf(p + Vector3(_rng.randf_range(-0.6, 0.6), s.y * 0.35 - k * 0.8, _rng.randf_range(-0.6, 0.6)), _rng.randf() * TAU, s))
			cols.append(color.lightened(_rng.randf_range(-0.12, 0.06)).lerp(Color(0.4, 0.5, 0.33), 0.25 if _rng.randf() < 0.3 else 0.0))
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 7
	rock.rings = 4
	_mm(parent, rock, mat(Color.WHITE, 0.12), xf, cols)


static func mountains(parent: Node3D, center: Vector3, radius: float, count: int) -> void:
	var xf: Array = []
	var caps: Array = []
	for i in count:
		var a := TAU * i / float(count) + _rng.randf_range(-0.1, 0.1)
		var r := radius * _rng.randf_range(0.9, 1.15)
		var p := center + Vector3(cos(a) * r, -2.0, sin(a) * r * 1.6)
		var h := _rng.randf_range(30.0, 55.0)
		var w := _rng.randf_range(22.0, 34.0)
		xf.append(_xf(p + Vector3(0, h * 0.5, 0), _rng.randf() * TAU, Vector3(w, h, w)))
		caps.append(_xf(p + Vector3(0, h * 0.86, 0), 0.0, Vector3(w * 0.3, h * 0.3, w * 0.3)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	var mm1 := _mm(parent, cone, mat(Color(0.42, 0.47, 0.55)), xf)
	mm1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm2 := _mm(parent, cone, mat(Color(0.93, 0.95, 1.0)), caps)
	mm2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ ruins
static func column(parent: Node3D, base: Vector3, radius: float, height: float, color: Color, broken: bool) -> void:
	var m := mat(color, 0.15)
	var c := CylinderMesh.new()
	c.top_radius = radius * 0.86
	c.bottom_radius = radius * 0.9
	c.height = height
	c.radial_segments = 12
	mesh_inst(parent, c, m, base + Vector3(0, height * 0.5, 0))
	var plinth := BoxMesh.new()
	plinth.size = Vector3(radius * 2.5, 0.35, radius * 2.5)
	mesh_inst(parent, plinth, mat(color.darkened(0.1)), base + Vector3(0, 0.17, 0))
	if not broken:
		mesh_inst(parent, plinth, mat(color.darkened(0.1)), base + Vector3(0, height + 0.15, 0))
	else:
		var chip := PrismMesh.new()
		chip.size = Vector3(radius * 1.7, 0.6, radius * 1.7)
		mesh_inst(parent, chip, m, base + Vector3(0, height + 0.25, 0), Vector3(0, 0, 0.3))
	# ivy
	var ivy := BoxMesh.new()
	ivy.size = Vector3(0.25, height * 0.6, 0.06)
	mesh_inst(parent, ivy, mat(Color(0.3, 0.5, 0.25)), base + Vector3(radius * 0.85, height * 0.3, 0), Vector3(0, 0, 0.05))


static func arch(parent: Node3D, center: Vector3, width: float, height: float, rot_y: float, color: Color) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = rot_y
	parent.add_child(root)
	var m := mat(color, 0.15)
	var leg := BoxMesh.new()
	leg.size = Vector3(1.0, height, 1.0)
	for sx in [-1.0, 1.0]:
		mesh_inst(root, leg, m, Vector3(sx * width * 0.5, height * 0.5, 0))
	# segmented semicircle
	var seg := BoxMesh.new()
	seg.size = Vector3(1.0, 0.7, 1.0)
	var n := 9
	for i in n:
		var a := PI * (i + 0.5) / float(n)
		var p := Vector3(cos(a) * width * 0.5, height + sin(a) * width * 0.5, 0)
		var mi := mesh_inst(root, seg, m, p, Vector3(0, 0, a - PI / 2), Vector3(width * 0.2, 1, 1))
		mi.rotation.z = a - PI / 2
	var key := PrismMesh.new()
	key.size = Vector3(0.6, 0.8, 1.1)
	mesh_inst(root, key, mat(color.lightened(0.1)), Vector3(0, height + width * 0.5 + 0.1, 0), Vector3(0, 0, PI))


static func crystals(parent: Node3D, pos: Vector3, color: Color, light: bool = true) -> void:
	var m := mat(color, 0.0, 2.2)
	m.albedo_color.a = 0.9
	for k in 5:
		var p := PrismMesh.new()
		var h := _rng.randf_range(0.8, 2.2)
		p.size = Vector3(0.35, h, 0.35)
		mesh_inst(parent, p, m, pos + Vector3(_rng.randf_range(-0.6, 0.6), h * 0.5, _rng.randf_range(-0.6, 0.6)), Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf() * TAU, _rng.randf_range(-0.35, 0.35)))
	if light:
		var l := OmniLight3D.new()
		l.light_color = color
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position = pos + Vector3(0, 1.3, 0)
		parent.add_child(l)


# ------------------------------------------------------------------ keep
static func castle_wall(parent: Node3D, from: Vector3, to: Vector3, height: float, color: Color) -> void:
	var m := mat(color, 0.1)
	var len := from.distance_to(to)
	var dir := (to - from).normalized()
	var mid := (from + to) * 0.5
	var w := BoxMesh.new()
	w.size = Vector3(len, height, 1.6)
	var ry := atan2(-dir.z, dir.x)
	mesh_inst(parent, w, m, mid + Vector3(0, height * 0.5, 0), Vector3(0, ry, 0))
	var merlon := BoxMesh.new()
	merlon.size = Vector3(0.9, 0.9, 1.7)
	var n := int(len / 1.8)
	for i in n:
		var p := from.lerp(to, (i + 0.5) / float(n))
		mesh_inst(parent, merlon, m, p + Vector3(0, height + 0.45, 0), Vector3(0, ry, 0))
	# darker base course
	var base := BoxMesh.new()
	base.size = Vector3(len, 1.0, 1.9)
	mesh_inst(parent, base, mat(color.darkened(0.25)), mid + Vector3(0, 0.5, 0), Vector3(0, ry, 0))


static func tower(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, roof: Color) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius * 1.08
	c.height = height
	c.radial_segments = 14
	mesh_inst(parent, c, mat(color, 0.1), pos + Vector3(0, height * 0.5, 0))
	var r := CylinderMesh.new()
	r.top_radius = 0.0
	r.bottom_radius = radius * 1.3
	r.height = radius * 2.2
	r.radial_segments = 14
	mesh_inst(parent, r, mat(roof, 0.2), pos + Vector3(0, height + radius * 1.1, 0))
	var win := BoxMesh.new()
	win.size = Vector3(0.35, 0.7, 0.1)
	for k in 3:
		var a := TAU * k / 3.0
		mesh_inst(parent, win, mat(Color(1.0, 0.65, 0.3), 0.0, 2.5), pos + Vector3(cos(a) * radius, height * 0.72, sin(a) * radius), Vector3(0, -a + PI / 2, 0))
	banner(parent, pos + Vector3(0, height * 0.55, -radius - 0.05), Color(0.55, 0.1, 0.1))


static func banner(parent: Node3D, pos: Vector3, color: Color) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.9, 2.2, 0.04)
	mesh_inst(parent, b, mat(color), pos)
	var t := PrismMesh.new()
	t.size = Vector3(0.9, 0.5, 0.04)
	mesh_inst(parent, t, mat(color), pos + Vector3(0, -1.35, 0), Vector3(0, 0, PI))
	var e := BoxMesh.new()
	e.size = Vector3(0.3, 0.3, 0.05)
	mesh_inst(parent, e, mat(Color(0.95, 0.75, 0.3), 0.0, 0.6), pos + Vector3(0, 0.3, -0.01), Vector3(0, 0, PI / 4))


static func brazier(parent: Node3D, pos: Vector3, with_light: bool) -> void:
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.45
	bowl.bottom_radius = 0.2
	bowl.height = 0.4
	mesh_inst(parent, bowl, mat(Color(0.25, 0.22, 0.2), 0.2), pos + Vector3(0, 0.2, 0))
	var coals := SphereMesh.new()
	coals.radius = 0.36
	coals.height = 0.3
	coals.is_hemisphere = true
	mesh_inst(parent, coals, mat(Color(1.0, 0.45, 0.1), 0.0, 3.0), pos + Vector3(0, 0.38, 0))
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.8
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	p.mesh = q
	p.material_override = VFX._billboard(Color(1.0, 0.55, 0.15), 3.0)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 1.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color_ramp = VFX._ramp(Color(1.0, 0.85, 0.4), Color(0.8, 0.15, 0.02, 0.0))
	p.position = pos + Vector3(0, 0.5, 0)
	parent.add_child(p)
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.25)
		l.light_energy = 2.2
		l.omni_range = 8.0
		l.position = pos + Vector3(0, 1.0, 0)
		parent.add_child(l)


static func ember_air(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 6.0
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	p.mesh = q
	p.material_override = VFX._billboard(Color(1.0, 0.5, 0.18), 3.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = size * 0.5
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0.3, 0.1, 0)
	p.position = center
	parent.add_child(p)
