class_name CharModel
extends Node3D
## Stylized semi-anime hero model built from primitives (Update 5 art pass).
##   * Proportions: slim limbs, slightly large head, defined hair silhouette, big readable shapes.
##   * Toon-lit materials (soft ramp + rim), no thick outlines.
##   * Arms are a live 2-bone IK chain from the shoulders to the hands, so they follow the procedural
##     weapon / shield animation; legs swing with movement speed.
##   * Equipment visual tiers (1-3) change the silhouette: trims, pauldrons, helm/circlet, cape, glow.
## This is still a procedural prototype - not a replacement for authored, rigged character models.

const UPPER := 0.29
const LOWER := 0.29

var hero: Node3D
var class_id: String = "vanguard"
var tiers: Dictionary = {}
var accent: Color = Color.WHITE
var arm_r: Array = []          # [upper, lower, hand]
var arm_l: Array = []
var leg_r: Node3D
var leg_l: Node3D
var left_target: String = "hip"      # "shield" | "staff" | "hip"
var phase: float = 0.0
var hair_root: Node3D
var cape: Node3D


static func toon(color: Color, emissive: float = 0.0, rim: float = 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.75
	m.metallic_specular = 0.25
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.6
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m


static func build(h, p_class: String, p: ClassProgress) -> CharModel:
	var cm := CharModel.new()
	cm.name = "CharModel"
	cm.hero = h
	cm.class_id = p_class
	for s in ["weapon", "head", "chest", "hands", "feet", "accessory"]:
		cm.tiers[s] = p.visual_tier(s) if p else 1
	h.model.add_child(cm)
	cm._build()
	return cm


# ------------------------------------------------------------------ primitives
func part(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	# small details (eyes, trims, gems...) never cast shadows: big saving in shadow passes
	var ext: Vector3 = mesh.get_aabb().size * scl
	if maxf(ext.x, maxf(ext.y, ext.z)) < 0.2:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func sphere(r: float, hemi: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if hemi else 2.0)
	s.is_hemisphere = hemi
	s.radial_segments = 14 if r > 0.1 else 8
	s.rings = 7 if r > 0.1 else 4
	return s


func cyl(top: float, bottom: float, height: float, seg: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = seg
	return c


func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 3
	return c


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func prism(size: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = size
	return p


func ring(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 18
	t.ring_segments = 6
	return t


# ------------------------------------------------------------------ build
func _build() -> void:
	match class_id:
		"vanguard":
			_vanguard()
		"mage":
			_mage()
		"raider":
			_raider()
		"guardian":
			_guardian()
		"caster":
			_caster()
		"warden":
			_warden()
		_:
			_reaver()


func _body(skin: Color, torso_col: Color, leg_col: Color, boot_col: Color, chest_w: float = 0.26, face: bool = true) -> StandardMaterial3D:
	var skin_m := toon(skin, 0.0, 0.25)
	var torso_m := toon(torso_col)
	var leg_m := toon(leg_col)
	var boot_m := toon(boot_col)
	# legs (pivot at hips so they can swing)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.12 * side, 0.92, 0)
		add_child(pivot)
		part(capsule(0.085, 0.62), leg_m, Vector3(0, -0.33, 0), pivot)
		part(capsule(0.075, 0.5), leg_m, Vector3(0, -0.66, 0.0), pivot)
		part(box(Vector3(0.15, 0.13, 0.27)), boot_m, Vector3(0, -0.86, -0.04), pivot)
		part(cyl(0.085, 0.09, 0.22), boot_m, Vector3(0, -0.74, 0), pivot)
		if side < 0:
			leg_l = pivot
		else:
			leg_r = pivot
	# hips + torso + chest
	part(cyl(0.2, 0.21, 0.2), leg_m, Vector3(0, 0.98, 0), null, Vector3.ZERO, Vector3(1, 1, 0.8))
	var torso := part(cyl(chest_w, 0.19, 0.5), torso_m, Vector3(0, 1.3, 0), null, Vector3.ZERO, Vector3(1, 1, 0.72))
	hero.body_mesh = torso
	hero.body_material = torso_m
	# neck + head
	part(cyl(0.05, 0.06, 0.12), skin_m, Vector3(0, 1.6, 0))
	part(sphere(0.155), skin_m, Vector3(0, 1.75, -0.01), null, Vector3.ZERO, Vector3(0.95, 1.05, 1.0))
	if face:
		_face()
	# arms
	arm_r = _arm(1.0, skin_m, torso_m)
	arm_l = _arm(-1.0, skin_m, torso_m)
	return torso_m


func _face() -> void:
	# anime-style eyes: white, large coloured iris, dark pupil, highlight; small brows + mouth
	var white_m := toon(Color(0.98, 0.98, 1.0), 0.15, 0.0)
	var iris := toon(accent, 0.5, 0.0)
	var dark := toon(Color(0.1, 0.07, 0.1), 0.0, 0.0)
	var shine := toon(Color(1, 1, 1), 2.0, 0.0)
	for side in [-1.0, 1.0]:
		var x: float = 0.062 * side
		part(sphere(0.036), white_m, Vector3(x, 1.735, -0.142), null, Vector3.ZERO, Vector3(0.95, 1.2, 0.35))
		part(sphere(0.027), iris, Vector3(x, 1.73, -0.152), null, Vector3.ZERO, Vector3(0.9, 1.25, 0.3))
		part(sphere(0.014), dark, Vector3(x, 1.728, -0.158), null, Vector3.ZERO, Vector3(1.0, 1.3, 0.3))
		part(sphere(0.007), shine, Vector3(x + 0.01, 1.745, -0.161))
		part(box(Vector3(0.072, 0.012, 0.012)), dark, Vector3(x, 1.775, -0.15), null, Vector3(0, 0, -0.08 * side))
		part(box(Vector3(0.05, 0.016, 0.01)), dark, Vector3(x, 1.762, -0.156), null, Vector3(0, 0, 0.12 * side))
	part(box(Vector3(0.03, 0.006, 0.006)), toon(Color(0.6, 0.3, 0.3), 0.0, 0.0), Vector3(0, 1.665, -0.152))
	var blush := toon(Color(1.0, 0.65, 0.6), 0.0, 0.0)
	for side in [-1.0, 1.0]:
		part(sphere(0.02), blush, Vector3(0.085 * side, 1.69, -0.135), null, Vector3.ZERO, Vector3(1.3, 0.6, 0.3))

func _arm(side: float, skin_m: Material, sleeve_m: Material) -> Array:
	var up := part(capsule(0.06, UPPER + 0.08), sleeve_m, Vector3.ZERO)
	var lo := part(capsule(0.052, LOWER + 0.06), sleeve_m, Vector3.ZERO)
	var hand := part(sphere(0.055), skin_m, Vector3.ZERO)
	return [up, lo, hand, side]


func _hair(col: Color) -> StandardMaterial3D:
	hair_root = Node3D.new()
	hair_root.position = Vector3(0, 1.75, -0.01)
	add_child(hair_root)
	var m := toon(col, 0.0, 0.5)
	part(sphere(0.168), m, Vector3(0, 0.035, 0.015), hair_root, Vector3.ZERO, Vector3(1.04, 1.0, 1.06))
	return m


func _spike(m: Material, pos: Vector3, rot: Vector3, size: Vector3) -> void:
	part(prism(size), m, pos, hair_root, rot)


func _pauldron(side: float, m: Material, trim: Material, r: float) -> void:
	part(sphere(r, true), m, Vector3(0.27 * side, 1.47, 0), null, Vector3(0, 0, -0.35 * side), Vector3(1.1, 0.8, 1.0))
	part(ring(r * 0.92, r * 1.04), trim, Vector3(0.27 * side, 1.46, 0), null, Vector3(0, 0, -0.35 * side), Vector3(1.1, 0.4, 1.0))


func _cape(col: Color, trim: Color, length: float = 1.0) -> void:
	cape = Node3D.new()
	cape.position = Vector3(0, 1.5, 0.17)
	add_child(cape)
	var m := toon(col)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(box(Vector3(0.5, length, 0.03)), m, Vector3(0, -length * 0.5, 0.0), cape, Vector3(0.12, 0, 0))
	part(box(Vector3(0.52, 0.05, 0.035)), toon(trim, 0.4), Vector3(0, -length + 0.02, 0.12), cape, Vector3(0.12, 0, 0))


# ------------------------------------------------------------------ classes
func _vanguard() -> void:
	accent = Color(0.35, 0.55, 0.95)
	var steel := Color(0.82, 0.85, 0.92)
	var gold := Color(0.95, 0.75, 0.3)
	var blue := Color(0.16, 0.3, 0.65)
	var t_chest: int = tiers.chest
	_body(Color(0.98, 0.84, 0.74), steel, Color(0.3, 0.32, 0.4), steel.darkened(0.3), 0.29)
	var gold_m := toon(gold, 0.15)
	var steel_m := toon(steel)
	var blue_m := toon(blue)
	# breastplate + gold trims + tabard
	part(sphere(0.25, true), steel_m, Vector3(0, 1.32, -0.08), null, Vector3(-PI / 2, 0, 0), Vector3(1.05, 0.55, 0.9))
	part(ring(0.2, 0.235), gold_m, Vector3(0, 1.06, 0), null, Vector3.ZERO, Vector3(1, 1, 0.8))
	part(ring(0.15, 0.18), gold_m, Vector3(0, 1.55, 0), null, Vector3.ZERO, Vector3(1, 1, 0.85))
	part(box(Vector3(0.26, 0.5, 0.02)), blue_m, Vector3(0, 0.8, -0.17), null, Vector3(0.05, 0, 0))
	part(box(Vector3(0.28, 0.04, 0.025)), gold_m, Vector3(0, 0.56, -0.18))
	part(box(Vector3(0.3, 0.45, 0.02)), blue_m, Vector3(0, 0.82, 0.17), null, Vector3(-0.05, 0, 0))
	if t_chest >= 2:
		part(prism(Vector3(0.1, 0.14, 0.02)), gold_m, Vector3(0, 1.32, -0.215), null, Vector3(0, 0, PI))
	for side in [-1.0, 1.0]:
		_pauldron(side, steel_m, gold_m, 0.15 if t_chest < 2 else 0.18)
	if t_chest >= 3:
		_cape(blue, gold, 1.1)
	# hair: short swept blond-brown
	var hm := _hair(Color(0.72, 0.55, 0.3))
	for i in 6:
		var a := -0.9 + i * 0.36
		_spike(hm, Vector3(sin(a) * 0.12, 0.1, -0.1 + cos(a) * 0.02), Vector3(-0.9, a * 0.4, 0), Vector3(0.09, 0.16, 0.05))
	_spike(hm, Vector3(0.0, 0.12, 0.1), Vector3(0.5, 0, 0), Vector3(0.22, 0.14, 0.06))
	if tiers.head >= 2:
		part(sphere(0.18, true), steel_m, Vector3(0, 0.03, 0.01), hair_root, Vector3.ZERO, Vector3(1.05, 1.0, 1.08))
		part(ring(0.16, 0.19), gold_m, Vector3(0, 0.03, 0.01), hair_root, Vector3.ZERO, Vector3(1.0, 0.6, 1.05))
		part(box(Vector3(0.03, 0.12, 0.26)), toon(Color(0.8, 0.15, 0.15)), Vector3(0, 0.2, 0.02), hair_root)
	# sword
	var wt: int = tiers.weapon
	var blade_m := toon(Color(0.9, 0.93, 1.0), 0.15 + (0.9 if wt >= 3 else 0.0))
	if wt >= 3:
		blade_m.emission = Color(1.0, 0.85, 0.45)
	part(box(Vector3(0.06, 0.13, 1.05 + 0.1 * wt)), blade_m, Vector3(0, 0, -0.62), hero.weapon_pivot)
	part(prism(Vector3(0.13, 0.12, 0.06)), blade_m, Vector3(0, 0, -1.2 - 0.05 * wt), hero.weapon_pivot, Vector3(-PI / 2, 0, 0))
	part(box(Vector3(0.34, 0.07, 0.07)), gold_m, Vector3(0, 0, -0.08), hero.weapon_pivot)
	part(cyl(0.03, 0.03, 0.2), toon(Color(0.25, 0.15, 0.1)), Vector3(0, 0, 0.06), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	part(sphere(0.045), gold_m, Vector3(0, 0, 0.18), hero.weapon_pivot)
	# kite shield
	var shield_m := toon(blue)
	var sh := part(box(Vector3(0.62, 0.8, 0.07)), shield_m, Vector3(0, 0, -0.06), hero.shield_pivot)
	part(prism(Vector3(0.62, 0.3, 0.07)), shield_m, Vector3(0, -0.55, -0.06), hero.shield_pivot, Vector3(0, 0, PI))
	part(box(Vector3(0.66, 0.05, 0.09)), gold_m, Vector3(0, 0.4, -0.06), hero.shield_pivot)
	for sx in [-1.0, 1.0]:
		part(box(Vector3(0.05, 0.8, 0.09)), gold_m, Vector3(0.32 * sx, 0.0, -0.06), hero.shield_pivot)
	# original emblem: a rising sun over a chevron
	part(cyl(0.12, 0.12, 0.03, 16), gold_m, Vector3(0, 0.12, -0.105), hero.shield_pivot, Vector3(PI / 2, 0, 0))
	for i in 7:
		var a := PI * (i / 6.0)
		part(box(Vector3(0.025, 0.1, 0.02)), gold_m, Vector3(cos(a) * 0.19, 0.12 + sin(a) * 0.19, -0.105), hero.shield_pivot, Vector3(0, 0, a - PI / 2))
	part(box(Vector3(0.3, 0.05, 0.03)), gold_m, Vector3(-0.1, -0.18, -0.105), hero.shield_pivot, Vector3(0, 0, -0.5))
	part(box(Vector3(0.3, 0.05, 0.03)), gold_m, Vector3(0.1, -0.18, -0.105), hero.shield_pivot, Vector3(0, 0, 0.5))
	sh.name = "ShieldFace"
	left_target = "shield"


func _mage() -> void:
	accent = Color(0.4, 0.75, 1.0)
	var white := Color(0.95, 0.95, 0.98)
	var blue := Color(0.25, 0.45, 0.85)
	var silver := Color(0.85, 0.88, 0.95)
	var t_chest: int = tiers.chest
	_body(Color(0.98, 0.86, 0.78), white, Color(0.85, 0.86, 0.92), Color(0.35, 0.38, 0.55), 0.22)
	var white_m := toon(white)
	var blue_m := toon(blue)
	var gold_m := toon(Color(0.9, 0.78, 0.45), 0.2)
	# long robe skirt over the legs + hem trim
	var skirt := toon(white)
	skirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(cyl(0.21, 0.4, 0.92, 20), skirt, Vector3(0, 0.56, 0.0), null, Vector3.ZERO, Vector3(1, 1, 0.85))
	part(ring(0.38, 0.42), blue_m, Vector3(0, 0.12, 0), null, Vector3.ZERO, Vector3(1, 1, 0.85))
	part(box(Vector3(0.12, 0.85, 0.02)), blue_m, Vector3(0, 0.56, -0.29), null, Vector3(-0.2, 0, 0))
	part(ring(0.19, 0.225), blue_m, Vector3(0, 1.05, 0), null, Vector3.ZERO, Vector3(1, 1, 0.8))
	# capelet / mantle
	part(sphere(0.3, true), blue_m, Vector3(0, 1.42, 0.0), null, Vector3.ZERO, Vector3(1.0, 0.55, 0.8))
	part(ring(0.27, 0.31), gold_m, Vector3(0, 1.42, 0), null, Vector3.ZERO, Vector3(1.0, 0.5, 0.8))
	if t_chest >= 2:
		part(prism(Vector3(0.12, 0.18, 0.02)), gold_m, Vector3(0, 1.3, -0.17), null, Vector3(0, 0, PI))
	if t_chest >= 3:
		_cape(Color(0.2, 0.3, 0.7), Color(0.9, 0.8, 0.5), 1.3)
	# long silver hair: back mass, side locks, bangs
	var hm := _hair(silver)
	part(capsule(0.13, 0.75), hm, Vector3(0, -0.32, 0.1), hair_root, Vector3(0.12, 0, 0), Vector3(1.15, 1.0, 0.6))
	for side in [-1.0, 1.0]:
		part(capsule(0.045, 0.42), hm, Vector3(0.13 * side, -0.16, -0.06), hair_root, Vector3(0, 0, 0.08 * side))
	for i in 5:
		var x := -0.1 + i * 0.05
		_spike(hm, Vector3(x, 0.05, -0.14), Vector3(-1.25, 0, x * 1.5), Vector3(0.06, 0.13, 0.04))
	if tiers.head >= 2:
		part(ring(0.155, 0.17), gold_m, Vector3(0, 0.07, 0.0), hair_root, Vector3(0.25, 0, 0), Vector3(1, 0.5, 1.05))
		part(sphere(0.025), toon(accent, 2.5), Vector3(0, 0.1, -0.165), hair_root)
	# staff
	var wt: int = tiers.weapon
	var shaft_m := toon(Color(0.92, 0.92, 0.96))
	part(cyl(0.028, 0.035, 1.6), shaft_m, Vector3(0, 0, -0.4), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	part(ring(0.07, 0.1), gold_m, Vector3(0, 0, -1.18), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	part(ring(0.11, 0.135), gold_m, Vector3(0, 0, -1.28), hero.weapon_pivot)
	var crystal := toon(Color(0.55, 0.85, 1.0), 2.0 + wt * 0.8, 0.0)
	part(prism(Vector3(0.12, 0.26, 0.12)), crystal, Vector3(0, 0, -1.36), hero.weapon_pivot, Vector3(-PI / 2, 0, 0))
	part(prism(Vector3(0.12, 0.14, 0.12)), crystal, Vector3(0, 0, -1.2), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	if wt >= 2:
		for i in 3:
			var a := TAU * i / 3.0
			part(prism(Vector3(0.04, 0.12, 0.04)), crystal, Vector3(cos(a) * 0.14, sin(a) * 0.14, -1.3), hero.weapon_pivot, Vector3(-PI / 2, 0, 0))
	left_target = "staff"


func _reaver() -> void:
	accent = Color(0.95, 0.3, 0.25)
	var crimson := Color(0.62, 0.1, 0.12)
	var black := Color(0.11, 0.1, 0.12)
	var t_chest: int = tiers.chest
	_body(Color(0.97, 0.83, 0.72), black, Color(0.15, 0.13, 0.15), Color(0.22, 0.14, 0.12), 0.24)
	var red_m := toon(crimson)
	var black_m := toon(black)
	var amber_m := toon(Color(0.95, 0.65, 0.25), 0.3)
	var red2 := toon(crimson)
	red2.cull_mode = BaseMaterial3D.CULL_DISABLED
	# open long coat: shoulders, lapels, tails
	part(cyl(0.27, 0.22, 0.4), red_m, Vector3(0, 1.36, 0.01), null, Vector3.ZERO, Vector3(1, 1, 0.78))
	for side in [-1.0, 1.0]:
		part(box(Vector3(0.07, 0.42, 0.02)), black_m, Vector3(0.09 * side, 1.3, -0.165), null, Vector3(0, 0, 0.12 * side))
		part(box(Vector3(0.2, 0.72, 0.025)), red2, Vector3(0.12 * side, 0.62, 0.12), null, Vector3(-0.12, 0, 0.08 * side))
		part(box(Vector3(0.2, 0.04, 0.03)), black_m, Vector3(0.12 * side, 0.27, 0.165), null, Vector3(-0.12, 0, 0.08 * side))
		part(box(Vector3(0.13, 0.55, 0.025)), red2, Vector3(0.17 * side, 0.7, -0.12), null, Vector3(0.1, 0, -0.1 * side))
	part(ring(0.2, 0.235), black_m, Vector3(0, 1.04, 0), null, Vector3.ZERO, Vector3(1, 1, 0.8))
	part(box(Vector3(0.07, 0.06, 0.03)), amber_m, Vector3(0, 1.04, -0.18))
	# scarf
	part(ring(0.07, 0.12), red_m, Vector3(0, 1.58, 0), null, Vector3.ZERO, Vector3(1, 1.4, 1))
	part(box(Vector3(0.09, 0.32, 0.025)), red2, Vector3(0.08, 1.45, 0.14), null, Vector3(-0.3, 0, 0.2))
	if t_chest >= 2:
		for side in [-1.0, 1.0]:
			part(box(Vector3(0.14, 0.04, 0.16)), amber_m, Vector3(0.27 * side, 1.52, 0), null, Vector3(0, 0, -0.3 * side))
	if t_chest >= 3:
		_cape(crimson.darkened(0.2), Color(0.95, 0.65, 0.25), 0.9)
	# messy red hair
	var hm := _hair(Color(0.85, 0.18, 0.12))
	var spikes := [
		[Vector3(0.0, 0.14, 0.05), Vector3(0.3, 0, 0)], [Vector3(-0.1, 0.1, 0.06), Vector3(0.4, 0, 0.6)],
		[Vector3(0.1, 0.1, 0.06), Vector3(0.4, 0, -0.6)], [Vector3(-0.14, 0.0, 0.08), Vector3(0.7, 0, 1.2)],
		[Vector3(0.14, 0.0, 0.08), Vector3(0.7, 0, -1.2)], [Vector3(0.0, 0.02, 0.16), Vector3(1.6, 0, 0)],
		[Vector3(-0.06, 0.08, -0.12), Vector3(-1.0, 0, 0.4)], [Vector3(0.05, 0.08, -0.13), Vector3(-1.1, 0, -0.3)],
		[Vector3(0.12, 0.06, -0.08), Vector3(-0.8, 0, -0.9)],
	]
	for s in spikes:
		_spike(hm, s[0], s[1], Vector3(0.1, 0.2, 0.06))
	if tiers.head >= 2:
		part(ring(0.158, 0.172), black_m, Vector3(0, 0.04, 0), hair_root, Vector3(0.15, 0, 0), Vector3(1, 0.35, 1.05))
	# longsword
	var wt: int = tiers.weapon
	var blade_m := toon(Color(0.92, 0.93, 0.97), 0.2 + (0.9 if wt >= 3 else 0.0))
	if wt >= 3:
		blade_m.emission = Color(1.0, 0.45, 0.3)
	part(box(Vector3(0.045, 0.11, 1.15 + 0.08 * wt)), blade_m, Vector3(0, 0, -0.68), hero.weapon_pivot)
	part(prism(Vector3(0.11, 0.12, 0.045)), blade_m, Vector3(0, 0, -1.3 - 0.04 * wt), hero.weapon_pivot, Vector3(-PI / 2, 0, 0))
	part(box(Vector3(0.012, 0.03, 1.0)), toon(crimson, 0.6 if wt >= 2 else 0.0), Vector3(0, 0, -0.66), hero.weapon_pivot, Vector3.ZERO, Vector3(1, 1, 1))
	part(box(Vector3(0.26, 0.05, 0.06)), black_m, Vector3(0, 0, -0.08), hero.weapon_pivot)
	part(cyl(0.028, 0.028, 0.24), red_m, Vector3(0, 0, 0.07), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	part(sphere(0.04), amber_m, Vector3(0, 0, 0.2), hero.weapon_pivot)
	left_target = "hip"


# ------------------------------------------------------------------ enemies (restyled, same gameplay)
func _glow_eyes(col: Color, y: float = 1.76, z: float = -0.15) -> void:
	var m := toon(col, 4.0, 0.0)
	for side in [-1.0, 1.0]:
		part(sphere(0.022), m, Vector3(0.055 * side, y, z), null, Vector3.ZERO, Vector3(1.3, 0.7, 0.6))


func _raider() -> void:
	accent = Color(0.85, 0.5, 0.2)
	var leather := Color(0.42, 0.28, 0.17)
	var cloth := Color(0.45, 0.16, 0.12)
	_body(Color(0.85, 0.66, 0.5), leather, Color(0.28, 0.22, 0.18), Color(0.2, 0.15, 0.12), 0.27)
	var cloth_m := toon(cloth)
	var fur_m := toon(Color(0.55, 0.48, 0.4), 0.0, 0.6)
	var metal := toon(Color(0.62, 0.62, 0.66))
	part(sphere(0.17, true), cloth_m, Vector3(0, 1.78, 0.0), null, Vector3.ZERO, Vector3(1.05, 1.0, 1.1))
	part(box(Vector3(0.24, 0.09, 0.05)), cloth_m, Vector3(0, 1.69, -0.14))
	part(ring(0.18, 0.26), fur_m, Vector3(0, 1.5, 0.0), null, Vector3.ZERO, Vector3(1.1, 1.6, 0.9))
	part(box(Vector3(0.36, 0.08, 0.3)), toon(Color(0.25, 0.18, 0.12)), Vector3(0, 1.04, 0))
	part(box(Vector3(0.24, 0.5, 0.025)), cloth_m, Vector3(0.05, 0.76, -0.16), null, Vector3(0.05, 0, 0.06))
	_pauldron(1.0, metal, toon(Color(0.3, 0.25, 0.2)), 0.14)
	# axe
	part(cyl(0.03, 0.035, 1.1), toon(Color(0.4, 0.28, 0.16)), Vector3(0, 0, -0.45), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	part(box(Vector3(0.05, 0.36, 0.26)), metal, Vector3(0, 0.12, -0.92), hero.weapon_pivot)
	part(prism(Vector3(0.05, 0.14, 0.3)), metal, Vector3(0, 0.33, -0.92), hero.weapon_pivot)
	left_target = "hip"


func _guardian() -> void:
	accent = Color(1.0, 0.5, 0.15)
	var steel := Color(0.32, 0.32, 0.36)
	_body(Color(0.3, 0.3, 0.33), steel, Color(0.22, 0.22, 0.25), Color(0.18, 0.18, 0.2), 0.32, false)
	var steel_m := toon(steel)
	var ember := toon(Color(1.0, 0.45, 0.12), 2.5, 0.0)
	part(sphere(0.2), steel_m, Vector3(0, 1.76, 0), null, Vector3.ZERO, Vector3(1.0, 1.1, 1.05))
	part(box(Vector3(0.2, 0.025, 0.05)), ember, Vector3(0, 1.77, -0.19))
	part(prism(Vector3(0.05, 0.2, 0.32)), steel_m, Vector3(0, 1.98, 0.0))
	for side in [-1.0, 1.0]:
		_pauldron(side, steel_m, ember, 0.2)
	part(box(Vector3(0.05, 0.3, 0.02)), ember, Vector3(0.08, 1.25, -0.2), null, Vector3(0, 0, 0.4))
	part(box(Vector3(0.04, 0.22, 0.02)), ember, Vector3(-0.06, 1.35, -0.2), null, Vector3(0, 0, -0.5))
	part(cyl(0.22, 0.3, 0.55), steel_m, Vector3(0, 0.75, 0), null, Vector3.ZERO, Vector3(1, 1, 0.8))
	# mace + tower shield
	part(cyl(0.035, 0.035, 0.9), toon(Color(0.25, 0.22, 0.2)), Vector3(0, 0, -0.4), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	part(sphere(0.13), steel_m, Vector3(0, 0, -0.9), hero.weapon_pivot)
	for i in 4:
		var a := TAU * i / 4.0
		part(prism(Vector3(0.06, 0.12, 0.06)), steel_m, Vector3(cos(a) * 0.13, sin(a) * 0.13, -0.9), hero.weapon_pivot, Vector3(0, 0, a - PI / 2))
	part(box(Vector3(0.75, 1.15, 0.09)), toon(Color(0.38, 0.33, 0.28)), Vector3(0.05, -0.1, -0.08), hero.shield_pivot)
	part(box(Vector3(0.79, 0.07, 0.11)), steel_m, Vector3(0.05, 0.45, -0.08), hero.shield_pivot)
	part(box(Vector3(0.79, 0.07, 0.11)), steel_m, Vector3(0.05, -0.65, -0.08), hero.shield_pivot)
	part(sphere(0.1), ember, Vector3(0.05, -0.1, -0.14), hero.shield_pivot, Vector3.ZERO, Vector3(1, 1, 0.4))
	left_target = "shield"


func _caster() -> void:
	accent = Color(1.0, 0.45, 0.1)
	var robe := Color(0.2, 0.18, 0.2)
	_body(Color(0.1, 0.08, 0.08), robe, robe, robe, 0.22, false)
	var robe_m := toon(robe, 0.0, 0.5)
	robe_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ember := toon(Color(1.0, 0.45, 0.12), 3.0, 0.0)
	part(cyl(0.2, 0.42, 1.0, 16), robe_m, Vector3(0, 0.52, 0), null, Vector3.ZERO, Vector3(1, 1, 0.85))
	part(ring(0.4, 0.43), ember, Vector3(0, 0.05, 0), null, Vector3.ZERO, Vector3(1, 1, 0.85))
	part(sphere(0.21), robe_m, Vector3(0, 1.78, 0.02), null, Vector3.ZERO, Vector3(1.0, 1.15, 1.1))
	part(prism(Vector3(0.22, 0.3, 0.2)), robe_m, Vector3(0, 2.0, 0.08), null, Vector3(-0.5, 0, 0))
	part(sphere(0.12), toon(Color(0.03, 0.02, 0.02), 0.0, 0.0), Vector3(0, 1.74, -0.1), null, Vector3.ZERO, Vector3(1, 1.1, 0.6))
	_glow_eyes(Color(1.0, 0.55, 0.15), 1.76, -0.17)
	part(box(Vector3(0.08, 0.6, 0.02)), ember, Vector3(0, 1.1, -0.17))
	# staff with ember orb
	part(cyl(0.025, 0.03, 1.4), toon(Color(0.2, 0.15, 0.1)), Vector3(0, 0, -0.5), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	part(ring(0.08, 0.1), toon(Color(0.3, 0.25, 0.2)), Vector3(0, 0, -1.22), hero.weapon_pivot)
	part(sphere(0.09), ember, Vector3(0, 0, -1.25), hero.weapon_pivot)
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.4
	p.mesh = box(Vector3(0.04, 0.04, 0.04))
	p.material_override = toon(Color(1.0, 0.5, 0.15), 3.0, 0.0)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.position = Vector3(0, 0.6, 0)
	add_child(p)
	left_target = "staff"


func _warden() -> void:
	accent = Color(1.0, 0.55, 0.15)
	var dark := Color(0.2, 0.1, 0.08)
	_body(Color(0.15, 0.08, 0.06), dark, Color(0.16, 0.1, 0.08), Color(0.12, 0.08, 0.06), 0.34, false)
	var dark_m := toon(dark, 0.0, 0.45)
	var ember := toon(Color(1.0, 0.5, 0.15), 3.0, 0.0)
	var bone := toon(Color(0.75, 0.68, 0.58))
	part(sphere(0.21), dark_m, Vector3(0, 1.77, 0), null, Vector3.ZERO, Vector3(1.0, 1.1, 1.05))
	part(box(Vector3(0.22, 0.03, 0.05)), ember, Vector3(0, 1.78, -0.2))
	for i in 7:
		var a := -1.2 + i * 0.4
		part(prism(Vector3(0.05, 0.22 + (0.1 if i == 3 else 0.0), 0.05)), ember, Vector3(sin(a) * 0.17, 2.0, cos(a) * 0.05 - 0.02), null, Vector3(0, 0, -a * 0.5))
	for side in [-1.0, 1.0]:
		_pauldron(side, dark_m, ember, 0.24)
		part(prism(Vector3(0.08, 0.3, 0.08)), bone, Vector3(0.36 * side, 1.66, 0.0), null, Vector3(0, 0, -0.6 * side))
	for i in 3:
		part(box(Vector3(0.04, 0.26, 0.02)), ember, Vector3(-0.1 + i * 0.1, 1.28 - i * 0.03, -0.22), null, Vector3(0, 0, 0.3 - i * 0.3))
	_cape(Color(0.16, 0.06, 0.05), Color(1.0, 0.45, 0.12), 1.35)
	# burning greatsword
	part(box(Vector3(0.09, 0.2, 1.7)), toon(Color(0.25, 0.12, 0.08), 0.0), Vector3(0, 0, -1.0), hero.weapon_pivot)
	part(box(Vector3(0.1, 0.06, 1.6)), ember, Vector3(0, 0, -1.0), hero.weapon_pivot)
	part(box(Vector3(0.5, 0.08, 0.1)), bone, Vector3(0, 0, -0.12), hero.weapon_pivot)
	part(cyl(0.04, 0.04, 0.32), dark_m, Vector3(0, 0, 0.08), hero.weapon_pivot, Vector3(PI / 2, 0, 0))
	left_target = "hip"


# ------------------------------------------------------------------ live pose
func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var v: Vector3 = hero.velocity
	v.y = 0
	var spd := v.length()
	phase += delta * clampf(spd, 0.0, 9.0) * 1.7
	var amp := clampf(spd / 6.0, 0.0, 1.0) * 0.65
	if leg_r:
		leg_r.rotation.x = lerpf(leg_r.rotation.x, sin(phase) * amp, minf(1.0, delta * 14.0))
		leg_l.rotation.x = lerpf(leg_l.rotation.x, -sin(phase) * amp, minf(1.0, delta * 14.0))
	if cape:
		cape.rotation.x = lerpf(cape.rotation.x, 0.15 + clampf(spd / 7.0, 0.0, 1.0) * 0.55 + sin(Game.time * 3.0) * 0.04, minf(1.0, delta * 6.0))
	if hair_root and class_id == "mage":
		hair_root.rotation.x = lerpf(hair_root.rotation.x, clampf(spd / 7.0, 0.0, 1.0) * 0.08, minf(1.0, delta * 6.0))
	# arms: IK towards the hands
	var wp: Node3D = hero.weapon_pivot
	var grip := wp.position + wp.basis * Vector3(0, 0, 0.06)
	_solve(arm_r, Vector3(0.24, 1.47, 0.0), grip)
	var lt: Vector3
	match left_target:
		"shield":
			var sp: Node3D = hero.shield_pivot
			lt = sp.position + sp.basis * Vector3(0.0, 0.0, 0.08)
		"staff":
			lt = wp.position + wp.basis * Vector3(0, 0, -0.32)
		_:
			lt = Vector3(-0.3, 1.0 + sin(phase) * 0.03 * amp, -0.05 - sin(phase) * 0.12 * amp)
	_solve(arm_l, Vector3(-0.24, 1.47, 0.0), lt)


func _solve(arm: Array, shoulder: Vector3, hand: Vector3) -> void:
	if arm.is_empty():
		return
	var up: MeshInstance3D = arm[0]
	var lo: MeshInstance3D = arm[1]
	var hd: MeshInstance3D = arm[2]
	var side: float = arm[3]
	var to := hand - shoulder
	var d := clampf(to.length(), 0.05, UPPER + LOWER - 0.005)
	var dir := to.normalized() if to.length() > 0.001 else Vector3.DOWN
	hand = shoulder + dir * d
	var pole := Vector3(side * 0.6, -0.4, 0.8)
	pole = (pole - dir * pole.dot(dir)).normalized()
	var a := (UPPER * UPPER - LOWER * LOWER + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, UPPER * UPPER - a * a))
	var elbow := shoulder + dir * a + pole * h
	_seg(up, shoulder, elbow)
	_seg(lo, elbow, hand)
	hd.position = hand


func _seg(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y := b - a
	var l := y.length()
	if l < 0.001:
		return
	y /= l
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
