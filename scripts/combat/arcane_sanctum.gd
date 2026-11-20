class_name ArcaneSanctum
extends Node3D
## Arcane Sanctum: one magical circle beneath the Mage (Lv5). While the Mage CASTS from inside it,
## spells gain element-specific behaviour (see MageElementalist). It is not consumed by casting,
## the Mage can leave and return freely, and spells work normally outside it.
## Visual: consistent gold-white high-fantasy circle; its accent glyphs take the colour of the
## element being cast.

var mage = null
var radius: float = 3.5
var duration: float = 10.0
var t: float = 0.0
var follow: bool = false
var accent: Color = Color(1.0, 0.85, 0.5)
var ring_mat: StandardMaterial3D
var glyph_mat: StandardMaterial3D
var disk_mat: StandardMaterial3D
var runes: Node3D
var inner: Node3D
var light: OmniLight3D


static func summon(p_mage, p_radius: float, p_duration: float, p_follow: bool) -> ArcaneSanctum:
	var s := ArcaneSanctum.new()
	s.mage = p_mage
	s.radius = p_radius
	s.duration = p_duration
	s.follow = p_follow
	s.add_to_group("arcane_sanctum")
	Game.fx_root().add_child(s)
	s.global_position = p_mage.global_position + Vector3(0, 0.05, 0)
	s.reset_physics_interpolation()
	s._build()
	return s


func _mat(c: Color, e: float, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.no_depth_test = false
	return m


func _ring(r: float, w: float, m: Material, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - w
	tm.outer_radius = r
	tm.rings = 72
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = m
	mi.scale = Vector3(1, 0.12, 1)
	parent.add_child(mi)


func _build() -> void:
	ring_mat = _mat(Color(1.0, 0.92, 0.7), 2.4, 0.95)
	glyph_mat = _mat(accent, 2.8, 0.9)
	disk_mat = _mat(Color(1.0, 0.85, 0.55), 0.6, 0.1)
	var disk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.01
	cm.radial_segments = 48
	disk.mesh = cm
	disk.material_override = disk_mat
	add_child(disk)
	_ring(radius, 0.07, ring_mat, self)
	_ring(radius - 0.22, 0.03, ring_mat, self)
	# rotating rune band
	runes = Node3D.new()
	add_child(runes)
	for i in 16:
		var a := TAU * i / 16.0
		var r := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.02, 0.22 if i % 2 == 0 else 0.12)
		r.mesh = bm
		r.material_override = glyph_mat
		r.position = Vector3(cos(a), 0.01, sin(a)) * (radius - 0.12)
		r.rotation.y = -a
		runes.add_child(r)
	# inner geometry: two counter-rotating triangles + centre ring
	inner = Node3D.new()
	add_child(inner)
	var ir := radius * 0.62
	for tri in 2:
		for k in 3:
			var a0 := TAU * k / 3.0 + tri * PI / 3.0
			var a1 := TAU * (k + 1) / 3.0 + tri * PI / 3.0
			var p0 := Vector3(cos(a0), 0, sin(a0)) * ir
			var p1 := Vector3(cos(a1), 0, sin(a1)) * ir
			var seg := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(p0.distance_to(p1), 0.015, 0.04)
			seg.mesh = sm
			seg.material_override = ring_mat
			seg.position = (p0 + p1) * 0.5 + Vector3(0, 0.012, 0)
			seg.rotation.y = -atan2(p1.z - p0.z, p1.x - p0.x)
			inner.add_child(seg)
	_ring(radius * 0.3, 0.04, glyph_mat, inner)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 1.4
	light.omni_range = radius * 1.6
	light.position = Vector3(0, 1.0, 0)
	add_child(light)
	scale = Vector3(0.1, 1, 0.1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func contains(pos: Vector3) -> bool:
	var d := pos - global_position
	d.y = 0
	return d.length() <= radius


func time_left() -> float:
	return maxf(0.0, duration - t)


## Accent glyphs take the colour of the element being cast from the circle; brief pulse.
func pulse(element: String) -> void:
	var c: Color = VFX.ELEMENT_COLORS.get(element, Color.WHITE)
	glyph_mat.albedo_color = Color(c.r, c.g, c.b, 0.95)
	glyph_mat.emission = c
	light.light_color = c.lerp(Color.WHITE, 0.3)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 3.5, 0.08)
	tw.tween_property(light, "light_energy", 1.4, 0.4)


func _physics_process(delta: float) -> void:
	t += delta
	runes.rotation.y += delta * 0.5
	inner.rotation.y -= delta * 0.3
	if follow and is_instance_valid(mage):
		var p: Vector3 = mage.global_position
		global_position = global_position.lerp(Vector3(p.x, p.y + 0.05, p.z), minf(1.0, delta * 10.0))
	var fade := clampf((duration - t) / 0.8, 0.0, 1.0)
	ring_mat.albedo_color.a = 0.95 * fade
	disk_mat.albedo_color.a = (0.08 + 0.03 * sin(t * 3.0)) * fade
	if t >= duration or not is_instance_valid(mage) or mage.dead:
		queue_free()
