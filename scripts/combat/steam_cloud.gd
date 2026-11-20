class_name SteamCloud
extends Node3D
## Thermal Fracture steam (spec 10.1): temporarily obscures sight, for enemies AND players alike.
## Gameplay effect (not only visual): SteamCloud.blocks(a, b) is checked by lock-on, Mage spell
## targeting, enemy target acquisition and enemy ranged attacks. Bosses are exempt (their AI is
## never disabled). Limited duration; never stacks: a new cloud on top of an existing one refreshes
## it, and each Mage has a separate cap (BalanceConfig.ww_max_steam_clouds, oldest removed).

const GROUP := "steam_clouds"

var owner_mage = null
var radius: float = 2.6
var duration: float = 3.0
var t: float = 0.0
var mat: StandardMaterial3D
var puffs: Node3D


static func spawn(p_mage, pos: Vector3) -> SteamCloud:
	var b: BalanceConfig = Game.balance
	for c in Game.get_tree().get_nodes_in_group(GROUP):
		if is_instance_valid(c) and c.t < c.duration and c.global_position.distance_to(pos) < c.radius:
			c.t = 0.0        # refresh instead of stacking
			return c
	var mine: Array = Game.get_tree().get_nodes_in_group(GROUP).filter(func(c): return is_instance_valid(c) and c.owner_mage == p_mage and c.t < c.duration)
	mine.sort_custom(func(x, y): return x.t > y.t)
	while mine.size() >= b.ww_max_steam_clouds:
		var old = mine.pop_front()
		old.t = old.duration
		old.remove_from_group(GROUP)
		old.queue_free()
	var s := SteamCloud.new()
	s.owner_mage = p_mage
	s.radius = b.ww_steam_radius
	s.duration = b.ww_steam_duration
	s.add_to_group(GROUP)
	Game.fx_root().add_child(s)
	s.global_position = Vector3(pos.x, pos.y, pos.z)
	s._build()
	return s


func _build() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 1.4
	sm.radial_segments = 20
	sm.rings = 10
	mi.mesh = sm
	mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.92, 0.95, 1.0, 0.0)
	mi.material_override = mat
	mi.position = Vector3(0, radius * 0.45, 0)
	add_child(mi)
	# soft rolling puffs (translucent spheres) instead of particle quads
	puffs = Node3D.new()
	add_child(puffs)
	for i in 7:
		var p := MeshInstance3D.new()
		var ps := SphereMesh.new()
		var r := radius * randf_range(0.35, 0.55)
		ps.radius = r
		ps.height = r * 1.6
		ps.radial_segments = 14
		ps.rings = 7
		p.mesh = ps
		p.material_override = mat
		var a := TAU * i / 7.0
		p.position = Vector3(cos(a) * radius * 0.45, radius * randf_range(0.3, 0.8), sin(a) * radius * 0.45)
		puffs.add_child(p)


func _process(delta: float) -> void:
	t += delta
	var a := clampf(t / 0.2, 0.0, 1.0) * clampf((duration - t) / 0.5, 0.0, 1.0)
	if mat:
		mat.albedo_color.a = 0.42 * a
	if puffs:
		puffs.rotation.y += delta * 0.4
		puffs.position.y = t * 0.15
	if t >= duration:
		remove_from_group(GROUP)
		queue_free()


## true when the segment a->b passes through any active steam cloud.
static func blocks(a: Vector3, b: Vector3) -> bool:
	for c in Game.get_tree().get_nodes_in_group(GROUP):
		if not is_instance_valid(c) or c.t >= c.duration:
			continue
		var center: Vector3 = c.global_position + Vector3(0, c.radius * 0.45, 0)
		var ab := b - a
		var f := 0.0
		if ab.length_squared() > 0.0001:
			f = clampf((center - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * f).distance_to(center) < c.radius * 0.9:
			return true
	return false


static func count() -> int:
	return Game.get_tree().get_nodes_in_group(GROUP).filter(func(c): return is_instance_valid(c) and c.t < c.duration).size()
