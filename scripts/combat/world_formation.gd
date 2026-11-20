class_name WorldFormation
extends StaticBody3D
## WORLDWEAVER world formation (spec section 4): a persistent, physical battlefield object owned by
## one Mage. Built from SEGMENTS (one collision box + visual each) so an interaction can destroy
## "the affected section" (Thermal Fracture / Shattered Winter) without removing the whole thing.
##
##   owner (mage) · element (frost / stone) · kind · lifetime · durability (per segment HP)
##   world position · collision (ice: LAYER_FROST = blocks enemies only; stone: LAYER_WORLD)
##   states (ElementalStates: frozen_structure, fortified, conductive, vitalized)
##   cleanup: destroy() removes collision, groups, references (signal) and VFX.
##
## Navigation: formations are never baked into the navmesh (no permanent blocking). Enemies steer
## around them with WorldFormation.steer() (Enemy.move_to). Bosses break formations on contact, so
## Frost / Stone can never permanently hold a boss.

const GROUP := "world_formations"
const SOLID_KINDS := ["crystal", "bastion", "pillar", "ward", "sanctum_guard"]

var mage = null
var element: String = "frost"
var kind: String = "crystal"
var duration: float = 7.0
var t: float = 0.0
var height: float = 2.2
var depth: float = 0.9
var segments: Array = []          # {shape, vis, xform (local), w, d, hp, max_hp, alive}
var states: Dictionary = {}       # state id -> expiry time (INF = while the formation exists)
var gone: bool = false
var serial: int = 0
var hit_by: Dictionary = {}       # enemy attack instances already applied (no duplicate hits)
var relayed: Dictionary = {}      # storm cast ids already relayed by this anchor
var vital_radius: float = 3.0
var vital_power: float = 0.12
var _vital_t: float = 0.0
var _scan_t: float = 0.0
var mat: StandardMaterial3D
static var _serial_counter: int = 0


static func spawn(p_mage, p_kind: String, p_element: String, center: Vector3, axis: Vector3, width: float, p_height: float,
		p_depth: float, p_duration: float, seg_hp: float, seg_len: float = 0.8) -> WorldFormation:
	var f := WorldFormation.new()
	f.mage = p_mage
	f.kind = p_kind
	f.element = p_element
	f.duration = p_duration
	f.height = p_height
	f.depth = p_depth
	_serial_counter += 1
	f.serial = _serial_counter
	f.collision_layer = Combatant.LAYER_FROST if p_element == "frost" else Combatant.LAYER_WORLD
	f.collision_mask = 0
	f.add_to_group(GROUP)
	Game.fx_root().add_child(f)
	axis.y = 0
	if axis.length() < 0.01:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	f.global_position = center
	f.rotation.y = atan2(-axis.z, axis.x)
	f._make_mat()
	var n := maxi(1, roundi(width / seg_len))
	var w := width / float(n)
	for i in n:
		var x := (i - (n - 1) * 0.5) * w
		f.add_segment(Transform3D(Basis(), Vector3(x, 0, 0)), w, seg_hp)
	if p_element == "frost":
		f.states["frozen_structure"] = INF
	VFX.particles(center + Vector3(0, 0.3, 0), VFX._quad(0.35), VFX._billboard(f._tint(0.5), 0.6), 10, 0.8,
		{"vmin": 0.4, "vmax": 1.5, "gravity": Vector3.ZERO, "radius": maxf(0.5, width * 0.4)})
	Events.formation_changed.emit(f, "created")
	return f


func _tint(a: float = 1.0) -> Color:
	var c := Color(0.72, 0.9, 1.0) if element == "frost" else Color(0.58, 0.48, 0.38)
	return Color(c.r, c.g, c.b, a)


func _make_mat() -> void:
	mat = StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if element == "frost":
		mat.albedo_color = Color(0.72, 0.9, 1.0, 0.82)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.15
		mat.rim_enabled = true
		mat.rim = 0.8
		mat.emission_enabled = true
		mat.emission = Color(0.45, 0.75, 1.0)
		mat.emission_energy_multiplier = 0.5
	else:
		mat.albedo_color = Color(0.55, 0.47, 0.38)
		mat.roughness = 0.9
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.0, 0.0)


## Adds one section. `xf` is local to the formation.
func add_segment(xf: Transform3D, w: float, hp: float) -> int:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, height, depth)
	cs.shape = bs
	cs.transform = xf.translated_local(Vector3(0, height * 0.5, 0))
	add_child(cs)
	var vis := Node3D.new()
	vis.transform = xf
	add_child(vis)
	if element == "frost":
		var k := maxi(2, roundi(w / 0.35))
		for j in k:
			var pm := PrismMesh.new()
			var hh := height * randf_range(0.65, 1.0)
			pm.size = Vector3(randf_range(0.3, 0.45), hh, randf_range(0.3, 0.5))
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mat
			mi.position = Vector3(-w * 0.5 + (j + 0.5) * w / k + randf_range(-0.08, 0.08), hh * 0.5, randf_range(-0.15, 0.15))
			mi.rotation = Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.2, 0.2))
			vis.add_child(mi)
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(w * 0.96, height, depth)
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(0, height * 0.5, 0)
		mi.rotation = Vector3(randf_range(-0.05, 0.05), randf_range(-0.08, 0.08), randf_range(-0.05, 0.05))
		vis.add_child(mi)
		var vein := BoxMesh.new()
		vein.size = Vector3(w * 0.8, 0.05, depth * 1.02)
		var vm := MeshInstance3D.new()
		vm.mesh = vein
		vm.material_override = CharModel.toon(Color(1.0, 0.8, 0.4), 1.5, 0.0)
		vm.position = Vector3(0, height * 0.62, 0)
		vis.add_child(vm)
	vis.scale = Vector3(1, 0.05, 1)
	var tw := vis.create_tween()
	tw.tween_property(vis, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	segments.append({"shape": cs, "vis": vis, "xform": xf, "w": w, "d": depth, "hp": hp, "max_hp": hp, "alive": true})
	return segments.size() - 1


## Section bridging toward a world point (Crystal Chain / Sanctum Frost connection).
func add_segment_at(world_pos: Vector3, along: Vector3, w: float, hp: float) -> int:
	var inv := global_transform.affine_inverse()
	var lp: Vector3 = inv * Vector3(world_pos.x, global_position.y, world_pos.z)
	var la: Vector3 = inv.basis * along
	var b := Basis(Vector3.UP, atan2(-la.z, la.x))
	return add_segment(Transform3D(b, Vector3(lp.x, 0, lp.z)), w, hp)


func is_solid() -> bool:
	return kind in SOLID_KINDS


func alive_count() -> int:
	var n := 0
	for s in segments:
		if s.alive:
			n += 1
	return n


func seg_center(i: int) -> Vector3:
	return global_transform * Vector3(segments[i].xform.origin.x, 0, segments[i].xform.origin.z)


func centers() -> Array:
	var out: Array = []
	for i in segments.size():
		if segments[i].alive:
			out.append(seg_center(i))
	return out


## Horizontal footprint test against alive sections (pad grows the boxes).
func contains_xz(p: Vector3, pad: float = 0.0) -> bool:
	return seg_containing(p, pad) >= 0


func seg_containing(p: Vector3, pad: float = 0.0) -> int:
	for i in segments.size():
		var s: Dictionary = segments[i]
		if not s.alive:
			continue
		var lp: Vector3 = (global_transform * s.xform).affine_inverse() * p
		if absf(lp.x) <= s.w * 0.5 + pad and absf(lp.z) <= s.d * 0.5 + pad:
			return i
	return -1


func segments_within(p: Vector3, r: float) -> Array:
	var out: Array = []
	for i in segments.size():
		if not segments[i].alive:
			continue
		var lp: Vector3 = (global_transform * segments[i].xform).affine_inverse() * p
		var dx := maxf(0.0, absf(lp.x) - segments[i].w * 0.5)
		var dz := maxf(0.0, absf(lp.z) - segments[i].d * 0.5)
		if Vector2(dx, dz).length() <= r:
			out.append(i)
	return out


func distance_to(p: Vector3) -> float:
	var best := INF
	for c in centers():
		best = minf(best, Vector2(c.x - p.x, c.z - p.z).length())
	return best


# ------------------------------------------------------------------ states
func has_state(id: String) -> bool:
	return states.has(id) and Game.time < float(states[id])


func set_state(id: String, dur: float = INF) -> void:
	states[id] = INF if dur == INF else Game.time + dur
	Events.formation_changed.emit(self, "state:" + id)
	_update_tint()


func clear_state(id: String) -> void:
	states.erase(id)
	_update_tint()


func _update_tint() -> void:
	if mat == null or element != "stone":
		return
	if has_state("vitalized"):
		mat.emission = Color(0.25, 0.85, 0.4)
		mat.emission_energy_multiplier = 0.22
	elif has_state("conductive"):
		mat.emission = Color(0.55, 0.45, 1.0)
		mat.emission_energy_multiplier = 0.25
	else:
		mat.emission = Color.BLACK


func state_list() -> Array:
	var out: Array = []
	for k in states.keys():
		if has_state(k):
			out.append(k)
	return out


func time_left() -> float:
	return maxf(0.0, duration - t)


func describe() -> String:
	var hp := 0.0
	var mhp := 0.0
	for s in segments:
		if s.alive:
			hp += s.hp
			mhp += s.max_hp
	return "#%d %s (%s)  %.1fs left  sections %d/%d  HP %d/%d  [%s]" % [serial, kind, element, time_left(), alive_count(), segments.size(),
		roundi(hp), roundi(mhp), ", ".join(state_list())]


# ------------------------------------------------------------------ damage / destruction
func damage_segment(i: int, amount: float, reason: String) -> bool:
	if i < 0 or i >= segments.size() or not segments[i].alive:
		return false
	segments[i].hp -= amount
	if segments[i].hp <= 0.0:
		destroy_segment(i, reason)
		return true
	var vis: Node3D = segments[i].vis
	var tw := vis.create_tween()
	tw.tween_property(vis, "scale", Vector3(1.06, 0.94, 1.06), 0.05)
	tw.tween_property(vis, "scale", Vector3.ONE, 0.08)
	return false


func destroy_segment(i: int, reason: String) -> void:
	if i < 0 or i >= segments.size() or not segments[i].alive:
		return
	var s: Dictionary = segments[i]
	s.alive = false
	if is_instance_valid(s.shape):
		s.shape.queue_free()
	var c := seg_center(i)
	if element == "frost":
		VFX.particles(c + Vector3(0, 0.9, 0), VFX._quad(0.14), VFX._billboard(Color(0.85, 0.95, 1.0), 2.0), 10, 0.6, {"vmin": 1.0, "vmax": 3.0})
	else:
		VFX.stone_burst(c, 0.8)
	var vis: Node3D = s.vis
	if is_instance_valid(vis):
		var tw := vis.create_tween()
		tw.tween_property(vis, "scale", Vector3(1.2, 0.05, 1.2), 0.15)
		tw.tween_callback(vis.queue_free)
	Events.formation_changed.emit(self, "section_destroyed:" + reason)
	if alive_count() == 0:
		destroy(reason)


## Full cleanup: collision, groups (steering / relays / LOS), states, signals, visuals.
func destroy(reason: String) -> void:
	if gone:
		return
	gone = true
	collision_layer = 0
	remove_from_group(GROUP)
	for s in segments:
		if s.alive:
			s.alive = false
			if is_instance_valid(s.shape):
				s.shape.queue_free()
			if is_instance_valid(s.vis):
				var tw: Tween = s.vis.create_tween()
				tw.tween_property(s.vis, "scale", Vector3(1.15, 0.05, 1.15), 0.2)
	states.clear()
	Events.formation_changed.emit(self, "destroyed:" + reason)
	var tw2 := create_tween()
	tw2.tween_interval(0.25)
	tw2.tween_callback(queue_free)


# ------------------------------------------------------------------ simulation
func _physics_process(delta: float) -> void:
	if gone:
		return
	t += delta
	if t >= duration:
		destroy("expired")
		return
	if element == "frost" and mat and t > duration - 0.5:
		mat.albedo_color.a = 0.82 * clampf((duration - t) / 0.5, 0.0, 1.0)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.1
		_scan_enemies()
	if has_state("vitalized"):
		_vital_t -= delta
		if _vital_t <= 0.0:
			_vital_t = 1.0
			_vital_pulse()
	elif states.has("vitalized"):
		clear_state("vitalized")


## Bosses break through (never permanently controlled). Enemy melee strikes that reach a section
## damage it once per attack instance (no duplicate collision hits).
func _scan_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if gone:
			return
		if not (e is Enemy) or not e.is_targetable():
			continue
		if global_position.distance_to(e.global_position) > 12.0:
			continue
		if e.is_boss and contains_xz(e.global_position + e.forward() * 0.6, 0.9):
			Events.formation_changed.emit(self, "boss_break")
			destroy("boss")
			return
		var r = e.runner
		if r.is_busy() and r.phase == AttackRunner.Phase.ACTIVE and r.data and r.data.hits > 0:
			var key := "%d:%d" % [e.get_instance_id(), e.attack_serial]
			if hit_by.has(key):
				continue
			var reach: float = absf(r.data.hitbox_offset.z) + r.data.hitbox_size.z * 0.5
			var i := seg_containing(e.global_position + e.forward() * reach * 0.6, r.data.hitbox_size.x * 0.4)
			if i >= 0:
				hit_by[key] = true
				damage_segment(i, e.weapon_power * r.data.damage_mult, "enemy_attack")


func on_projectile(pos: Vector3, amount: float) -> void:
	var i := seg_containing(pos, 0.4)
	if i < 0:
		var near := segments_within(pos, 1.0)
		if near.is_empty():
			return
		i = near[0]
	damage_segment(i, amount, "projectile")


func _vital_pulse() -> void:
	if not is_instance_valid(mage):
		return
	var c := global_position
	VFX.ground_ring(c, vital_radius, Color(0.45, 1.0, 0.55), 0.5)
	for a in mage.allies(true):
		if a.dead or a.downed:
			continue
		if distance_to(a.global_position) <= vital_radius:
			mage.kit.heal_target(a, mage.weapon_power * vital_power * mage.stats.effect_power(), "Living Bastion")


# ------------------------------------------------------------------ enemy steering (no navmesh rebake)
static func active() -> Array:
	var out: Array = []
	for f in Game.get_tree().get_nodes_in_group(GROUP):
		if is_instance_valid(f) and not f.gone:
			out.append(f)
	return out


## Returns a direction that goes AROUND any formation directly in the way (dir unchanged otherwise).
static func steer(e, dir: Vector3, goal: Vector3) -> Vector3:
	if e.is_boss or dir.length() < 0.01:
		return dir
	var p: Vector3 = e.global_position
	for f in active():
		if f.global_position.distance_to(p) > 10.0:
			continue
		var blocked := false
		for k in [0.8, 1.6]:
			if f.contains_xz(p + dir * k, 0.55):
				blocked = true
				break
		if not blocked:
			continue
		# go around the nearer end of the formation (along its main axis)
		var axis: Vector3 = f.global_transform.basis.x.normalized()
		var lo := INF
		var hi := -INF
		for c in f.centers():
			var proj: float = (c - f.global_position).dot(axis)
			lo = minf(lo, proj)
			hi = maxf(hi, proj)
		var pad := 1.3
		var a: Vector3 = f.global_position + axis * (lo - pad)
		var b: Vector3 = f.global_position + axis * (hi + pad)
		var ca: float = p.distance_to(a) + a.distance_to(goal)
		var cb: float = p.distance_to(b) + b.distance_to(goal)
		var end := a if ca <= cb else b
		var nd := end - p
		nd.y = 0
		if nd.length() > 0.05:
			return nd.normalized()
	return dir
