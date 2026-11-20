class_name AshenValley
extends Node3D
## ASHEN VALLEY test stage, built procedurally from primitives:
##   Valley Outskirts (Lv 1-3)  ->  Forgotten Ruins (Lv 4-7)  ->  Warden's Keep (Lv 8-10) + boss arena.
## Areas are connected by corridors with ash gates that open when the previous area's objectives are
## cleared. Includes checkpoints, repeatable Trial Totems (extra EXP / testing), and an Elemental
## Shrine (Stone discovery for the Mage). Navigation mesh is baked at load.

const AREAS := {
	"outskirts": {"name": "Valley Outskirts", "center": Vector3(0, 0, 0), "size": Vector2(64, 60), "color": Color(0.36, 0.55, 0.27), "checkpoint": Vector3(0, 0.5, 24)},
	"ruins": {"name": "Forgotten Ruins", "center": Vector3(0, 0, -85), "size": Vector2(70, 60), "color": Color(0.42, 0.48, 0.36), "checkpoint": Vector3(0, 0.5, -60)},
	"keep": {"name": "Warden's Keep", "center": Vector3(0, 0, -165), "size": Vector2(64, 60), "color": Color(0.3, 0.27, 0.26), "checkpoint": Vector3(0, 0.5, -140)},
}
const TRIAL_POOLS := {
	"outskirts": [[["wolf"], ["wolf"], ["wolf"]], [["raider"], ["wolf"], ["wolf"]]],
	"ruins": [[["raider"], ["ash_caster"], ["wolf"], ["wolf"]], [["shield_guardian"], ["ash_caster"]]],
	"keep": [[["raider", true], ["ash_caster"]], [["shield_guardian", true], ["wolf"], ["wolf"]]],
}

var nav_region: NavigationRegion3D
var zones: Dictionary = {}      # area -> Array[EncounterZone]
var gates: Dictionary = {}
var cleared: Dictionary = {}
var checkpoint_area: String = "outskirts"
var current_area: String = ""
var interactables: Array = []
var boss_zone: Dictionary = {}
var boss: Node = null
var boss_gate: Node3D = null
var trial_alive: Array = []
var decor: Node3D


func _ready() -> void:
	Scenery._rng.seed = 1337
	decor = Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	_environment()
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.6
	nm.agent_height = 1.75
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.agent_max_climb = 0.5
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	_build_outskirts()
	_build_ruins()
	_build_keep()
	_build_training()
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.3)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.25)
	nav_region.bake_navigation_mesh(false)
	_build_gates()
	_build_encounters()
	_dress()
	Events.enemy_killed.connect(_on_enemy_killed)


# ------------------------------------------------------------------ helpers
func _mat(color: Color) -> StandardMaterial3D:
	return Scenery.mat(color, 0.08)


func box(pos: Vector3, size: Vector3, color: Color, parent: Node = null, nav: bool = true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = Combatant.LAYER_WORLD
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	(parent if parent else (nav_region if nav else self)).add_child(sb)
	sb.position = pos
	return sb


func pillar(pos: Vector3, radius: float, height: float, color: Color) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = Combatant.LAYER_WORLD
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.85
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _mat(color)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	sb.add_child(cs)
	nav_region.add_child(sb)
	sb.position = pos + Vector3(0, height * 0.5, 0)
	return sb


func _ground(area: String) -> void:
	var a: Dictionary = AREAS[area]
	var c: Vector3 = a.center
	var s: Vector2 = a.size
	box(c + Vector3(0, -0.5, 0), Vector3(s.x, 1, s.y), a.color)
	var wall_c := Color(a.color).darkened(0.35)
	var hx := s.x * 0.5
	var hz := s.y * 0.5
	# side walls
	_wall(area, c + Vector3(-hx - 0.5, 2, 0), Vector3(1, 5, s.y), wall_c, Vector3(-1, 0, 0))
	_wall(area, c + Vector3(hx + 0.5, 2, 0), Vector3(1, 5, s.y), wall_c, Vector3(1, 0, 0))
	# end walls with a 10m opening in the middle
	for zsign in [-1.0, 1.0]:
		var z: float = c.z + zsign * (hz + 0.5)
		var seg := (s.x - 10.0) * 0.5
		_wall(area, Vector3(c.x - 5.0 - seg * 0.5, 2, z), Vector3(seg, 5, 1), wall_c, Vector3(0, 0, zsign))
		_wall(area, Vector3(c.x + 5.0 + seg * 0.5, 2, z), Vector3(seg, 5, 1), wall_c, Vector3(0, 0, zsign))
	# close the outer ends of the level
	if area == "outskirts":
		_wall(area, Vector3(0, 2, c.z + hz + 0.5), Vector3(10, 5, 1), wall_c, Vector3(0, 0, 1))
	if area == "keep":
		_wall(area, Vector3(0, 2, c.z - hz - 0.5), Vector3(10, 5, 1), wall_c, Vector3(0, 0, -1))


## Collision wall + stylized dressing: rocky cliffs (valley / ruins / corridors) or castle walls (keep).
func _wall(area: String, pos: Vector3, size: Vector3, color: Color, outward: Vector3) -> void:
	_hide_mesh(box(pos, size, color))
	var along := Vector3(size.x * 0.5, 0, 0) if size.x > size.z else Vector3(0, 0, size.z * 0.5)
	var base := Vector3(pos.x, 0, pos.z) + outward * 0.9
	if area == "keep":
		Scenery.castle_wall(decor, base - along + outward * 0.1, base + along + outward * 0.1, 6.5, Color(0.5, 0.46, 0.43))
	else:
		var rock := Color(0.47, 0.45, 0.41) if area == "outskirts" else Color(0.5, 0.49, 0.47)
		Scenery.cliff(decor, base - along, base + along, rock, 6.5)


func _corridor(z_from: float, z_to: float, color: Color) -> void:
	var len := absf(z_to - z_from)
	var zc := (z_from + z_to) * 0.5
	box(Vector3(0, -0.5, zc), Vector3(10, 1, len + 2), color)
	_wall("corridor", Vector3(-5.5, 2, zc), Vector3(1, 5, len), color.darkened(0.4), Vector3(-1, 0, 0))
	_wall("corridor", Vector3(5.5, 2, zc), Vector3(1, 5, len), color.darkened(0.4), Vector3(1, 0, 0))


func _environment() -> void:
	Scenery.environment(self)


## Collision stays the simple box/cylinder; the visible mesh is replaced by stylized decoration.
func _hide_mesh(sb: StaticBody3D) -> void:
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false


# ------------------------------------------------------------------ areas
func _build_outskirts() -> void:
	_ground("outskirts")
	var rock := Color(0.42, 0.38, 0.33)
	for p in [Vector3(-18, 0, 12), Vector3(16, 0, 8), Vector3(-10, 0, -14), Vector3(20, 0, -18), Vector3(-22, 0, -4)]:
		_hide_mesh(box(p + Vector3(0, 0.9, 0), Vector3(3, 1.8, 2.5), rock))
		Scenery.boulder(decor, p + Vector3(0, 0.8, 0), Vector3(3.1, 1.9, 2.6), Color(0.55, 0.53, 0.5))
	var trees: Array = []
	for p in [Vector3(-26, 0, 20), Vector3(25, 0, 22), Vector3(8, 0, -24), Vector3(-25, 0, -22), Vector3(26, 0, -2)]:
		_hide_mesh(pillar(p, 0.35, 4.5, Color(0.2, 0.16, 0.13)))
		trees.append(p)
	Scenery.forest(decor, trees)
	_corridor(-30.0, -55.0, Color(0.38, 0.52, 0.3))


func _build_ruins() -> void:
	_ground("ruins")
	var stone := Color(0.5, 0.5, 0.52)
	for x in [-20.0, -10.0, 10.0, 20.0]:
		for z in [-70.0, -100.0]:
			var hgt := 3.0 + Scenery._rng.randf() * 3.0
			_hide_mesh(pillar(Vector3(x, 0, z), 0.8, hgt, stone))
			Scenery.column(decor, Vector3(x, 0, z), 0.8, hgt, Color(0.6, 0.58, 0.53), hgt < 4.5)
	box(Vector3(-14, 0.6, -85), Vector3(8, 1.2, 1), stone.darkened(0.2))
	box(Vector3(14, 0.6, -85), Vector3(8, 1.2, 1), stone.darkened(0.2))
	box(Vector3(0, 0.75, -92), Vector3(1, 1.5, 7), stone.darkened(0.25))
	_corridor(-115.0, -135.0, Color(0.36, 0.34, 0.32))


func _build_keep() -> void:
	_ground("keep")
	var dark := Color(0.25, 0.17, 0.15)
	for p in [Vector3(-26, 0, -140), Vector3(26, 0, -140), Vector3(-26, 0, -190), Vector3(26, 0, -190)]:
		_hide_mesh(box(p + Vector3(0, 4, 0), Vector3(6, 8, 6), dark))
		Scenery.tower(decor, p, 3.2, 9.0, Color(0.5, 0.47, 0.45), Color(0.45, 0.14, 0.12))
	# boss arena ring (entrance at the near side, z = -160)
	var c := Vector3(0, 0, -178)
	var r := 15.0
	for i in 24:
		var ang := TAU * i / 24.0
		var p := c + Vector3(sin(ang), 0, cos(ang)) * r
		if p.z > c.z + r * 0.8 and absf(p.x) < 5.0:
			continue
		_hide_mesh(pillar(p, 1.2, 4.0, dark.lightened(0.1)))
		Scenery.column(decor, p, 1.2, 4.0, Color(0.45, 0.4, 0.38), false)
		Scenery.brazier(decor, p + Vector3(0, 4.3, 0), i % 4 == 0)
	boss_zone = {"center": c, "radius": r - 1.5}


# ------------------------------------------------------------------ training grounds
const TRAINING_CENTER := Vector3(0, 0, 59)


func _build_training() -> void:
	var c := TRAINING_CENTER
	box(c + Vector3(0, -0.5, 0), Vector3(28, 1, 22), Color(0.5, 0.6, 0.38))
	var wood := Color(0.45, 0.32, 0.2)
	for w in [[Vector3(0, 1, -11.5), Vector3(28, 2, 1)], [Vector3(0, 1, 11.5), Vector3(28, 2, 1)], [Vector3(-14.5, 1, 0), Vector3(1, 2, 22)], [Vector3(14.5, 1, 0), Vector3(1, 2, 22)]]:
		var sb := box(c + w[0], w[1], wood)
		_hide_mesh(sb)
		_fence(c + w[0], w[1])
	# sand sparring circle
	var d := CylinderMesh.new()
	d.top_radius = 8.0
	d.bottom_radius = 8.0
	d.height = 0.02
	Scenery.mesh_inst(decor, d, Scenery.mat(Color(0.78, 0.7, 0.5)), c + Vector3(0, 0.012, 2))
	Scenery.banner(decor, c + Vector3(-9, 3.2, 11.0), Color(0.2, 0.3, 0.6))
	Scenery.banner(decor, c + Vector3(9, 3.2, 11.0), Color(0.55, 0.1, 0.1))
	Scenery.brazier(decor, c + Vector3(-12, 0, -9), true)
	Scenery.brazier(decor, c + Vector3(12, 0, -9), false)
	_interactable(c + Vector3(-10, 0, -8), "Valley Road - return to the Valley Outskirts", func(_h): teleport_player("outskirts"))
	_interactable(Vector3(10, 0, 26), "Training Grounds - practice against dummies", func(_h): teleport_player("training"))


func _fence(pos: Vector3, size: Vector3) -> void:
	var long_x := size.x > size.z
	var n := int((size.x if long_x else size.z) / 2.0)
	var post := CylinderMesh.new()
	post.top_radius = 0.1
	post.bottom_radius = 0.12
	post.height = 1.6
	var rail := BoxMesh.new()
	rail.size = Vector3(size.x, 0.12, 0.08) if long_x else Vector3(0.08, 0.12, size.z)
	var m := Scenery.mat(Color(0.5, 0.35, 0.22))
	for i in n + 1:
		var f := -0.5 + i / float(n)
		var off := Vector3(f * size.x, 0, 0) if long_x else Vector3(0, 0, f * size.z)
		Scenery.mesh_inst(decor, post, m, Vector3(pos.x, 0.8, pos.z) + off)
	for y in [0.6, 1.2]:
		Scenery.mesh_inst(decor, rail, m, Vector3(pos.x, y, pos.z))


var training_dummies: Array = []


func ensure_training_dummies() -> void:
	training_dummies = training_dummies.filter(func(d): return is_instance_valid(d))
	if not training_dummies.is_empty():
		return
	for off in [Vector3(-6, 0.2, 4), Vector3(0, 0.2, 6), Vector3(6, 0.2, 4)]:
		var d := Game.spawn_enemy("training_dummy", TRAINING_CENTER + off, "outskirts")
		if d:
			d.face_dir(Vector3(0, 0, -1))
			training_dummies.append(d)


func _build_gates() -> void:
	gates["outskirts"] = _gate(Vector3(0, 2, -42), "Clear the Valley Outskirts")
	gates["ruins"] = _gate(Vector3(0, 2, -125), "Clear the Forgotten Ruins")


func _gate(pos: Vector3, label: String) -> Node3D:
	var g := box(pos, Vector3(10, 4.5, 0.8), Color(0.8, 0.35, 0.15), self, false)
	var mi: MeshInstance3D = g.get_child(0)
	var m: StandardMaterial3D = mi.material_override
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.4, 0.15, 0.45)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.1)
	var l := Label3D.new()
	l.text = "ASH GATE\n" + label
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 3.0, 0)
	l.pixel_size = 0.01
	g.add_child(l)
	return g


func open_gate(area: String) -> void:
	if gates.has(area) and is_instance_valid(gates[area]):
		gates[area].queue_free()
		Events.notify.emit("The ash gate dissolves")
		Events.log_message.emit("Gate opened after clearing %s" % AREAS[area].name, "system")
	gates.erase(area)


func _build_encounters() -> void:
	# Outskirts — basics (Lv 1-3)
	_zone("outskirts", "Wolf Pack", Vector3(0, 0, 8), [[["wolf"], ["wolf"], ["wolf"]]], 13.0)
	_zone("outskirts", "Raider Scouts", Vector3(-14, 0, -6), [[["wolf"], ["wolf"], ["raider"]]])
	_zone("outskirts", "Raider Camp", Vector3(14, 0, -18), [[["raider"], ["wolf"]], [["raider"], ["wolf"]]])
	# Ruins — mixed groups (Lv 4-7)
	_zone("ruins", "Ruin Ambush", Vector3(0, 0, -64), [[["raider"], ["raider"], ["ash_caster"]]])
	_zone("ruins", "Shieldwall", Vector3(-18, 0, -80), [[["shield_guardian"], ["ash_caster"], ["ash_caster"]]])
	_zone("ruins", "Hunting Party", Vector3(18, 0, -80), [[["wolf"], ["wolf"], ["wolf"], ["raider"], ["ash_caster"]]])
	_zone("ruins", "Ruin Garrison", Vector3(-12, 0, -102), [[["shield_guardian"], ["raider"]], [["shield_guardian"], ["raider"]]])
	_zone("ruins", "Ashen Choir", Vector3(14, 0, -104), [[["ash_caster"], ["ash_caster"], ["raider"], ["raider"], ["wolf"], ["wolf"]]])
	# Keep — elites (Lv 8-10)
	_zone("keep", "Keep Vanguard", Vector3(-14, 0, -146), [[["raider", true], ["ash_caster"], ["ash_caster"], ["shield_guardian"]]])
	_zone("keep", "Warden's Elite", Vector3(14, 0, -148), [[["shield_guardian", true], ["ash_caster", true], ["wolf"], ["wolf"]]])
	# interactables
	_interactable(Vector3(-8, 0, 20), "Trial Totem (Outskirts) - spawn a repeatable pack", func(_h): _trial("outskirts", Vector3(-8, 0, 14)))
	_interactable(Vector3(26, 0, -66), "Trial Totem (Ruins) - spawn a repeatable pack", func(_h): _trial("ruins", Vector3(22, 0, -66)))
	_interactable(Vector3(-24, 0, -152), "Trial Totem (Keep) - spawn a repeatable pack", func(_h): _trial("keep", Vector3(-20, 0, -158)))
	_interactable(Vector3(0, 0, -112), "Elemental Shrine - Mage: discover STONE", func(h): _shrine(h))
	for k in AREAS:
		cleared[k] = false


func _zone(area: String, nm: String, pos: Vector3, waves: Array, trig: float = 14.0) -> void:
	var z := EncounterZone.new().setup(nm, area, waves, trig)
	z.name = nm.replace(" ", "")
	z.objective_exp = Game.balance.pack_objective_exp
	add_child(z)
	z.global_position = pos
	if not zones.has(area):
		zones[area] = []
	zones[area].append(z)
	z.completed.connect(_on_zone_completed)


# ------------------------------------------------------------------ art dressing (decoration only)
func _dress() -> void:
	# --- Valley Outskirts: green valley, road, ash scars, forest beyond the cliffs
	Scenery.scars.clear()
	for p in [Vector3(12, 0, 14), Vector3(-6, 0, -20), Vector3(22, 0, -10), Vector3(-20, 0, 6)]:
		Scenery.ash_scar(decor, p, Scenery._rng.randf_range(2.0, 3.5))
	Scenery.road(decor, 31.0, -128.0)
	Scenery.grass(decor, Vector3(0, 0, 0), Vector2(62, 58), 2600, Color(0.4, 0.62, 0.3), true)
	Scenery.flowers(decor, Vector3(0, 0, 0), Vector2(60, 56), 260)
	var pts: Array = []
	for i in 90:
		var side := -1.0 if i % 2 == 0 else 1.0
		pts.append(Vector3(side * Scenery._rng.randf_range(38.0, 60.0), 0, Scenery._rng.randf_range(-120.0, 45.0)))
	for i in 30:
		pts.append(Vector3(Scenery._rng.randf_range(-40.0, 40.0), 0, Scenery._rng.randf_range(36.0, 60.0)))
	Scenery.forest(decor, pts)
	var pines: Array = []
	for i in 50:
		var side := -1.0 if i % 2 == 0 else 1.0
		pines.append(Vector3(side * Scenery._rng.randf_range(40.0, 62.0), 0, Scenery._rng.randf_range(-130.0, -55.0)))
	Scenery.pine_forest(decor, pines)
	Scenery.mountains(decor, Vector3(0, 0, -80), 150.0, 22)
	# --- Forgotten Ruins: mossy grass, arches, crystals
	Scenery.grass(decor, Vector3(0, 0, -85), Vector2(68, 58), 900, Color(0.42, 0.55, 0.32))
	Scenery.arch(decor, Vector3(0, 0, -70), 8.0, 4.0, 0.0, Color(0.6, 0.58, 0.53))
	Scenery.arch(decor, Vector3(0, 0, -100), 8.0, 4.0, 0.0, Color(0.58, 0.56, 0.51))
	Scenery.arch(decor, Vector3(-27, 0, -85), 6.0, 3.5, PI / 2, Color(0.57, 0.55, 0.5))
	Scenery.arch(decor, Vector3(27, 0, -85), 6.0, 3.5, PI / 2, Color(0.57, 0.55, 0.5))
	for c in [[Vector3(-30, 0, -60), Color(0.35, 0.85, 1.0)], [Vector3(30, 0, -110), Color(0.45, 0.95, 0.9)], [Vector3(29, 0, -58), Color(0.6, 0.55, 1.0)], [Vector3(-29, 0, -110), Color(0.35, 0.85, 1.0)]]:
		Scenery.crystals(decor, c[0], c[1])
	# --- Warden's Keep: ash ground, castle walls, keep facade, embers
	for i in 14:
		Scenery.ash_scar(decor, Vector3(Scenery._rng.randf_range(-28, 28), 0, Scenery._rng.randf_range(-192, -138)), Scenery._rng.randf_range(2.0, 4.5))
	Scenery.tower(decor, Vector3(-12, 0, -203), 4.0, 16.0, Color(0.5, 0.46, 0.43), Color(0.45, 0.14, 0.12))
	Scenery.tower(decor, Vector3(12, 0, -203), 4.0, 16.0, Color(0.5, 0.46, 0.43), Color(0.45, 0.14, 0.12))
	Scenery.tower(decor, Vector3(0, 0, -210), 6.0, 24.0, Color(0.46, 0.42, 0.4), Color(0.4, 0.12, 0.1))
	for x in [-20.0, -8.0, 8.0, 20.0]:
		Scenery.banner(decor, Vector3(x, 5.0, -195.1), Color(0.5, 0.08, 0.08))
	for p in [Vector3(-6, 0, -138), Vector3(6, 0, -138)]:
		Scenery.brazier(decor, p, true)
	Scenery.ember_air(decor, Vector3(0, 3, -165), Vector3(60, 6, 60))


func _interactable(pos: Vector3, label: String, fn: Callable) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.6
	cm.height = 2.2
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0) if label.begins_with("Elemental") else Color(1.0, 0.7, 0.3)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.5
	m.material_override = mat
	add_child(m)
	m.position = pos + Vector3(0, 1.1, 0)
	var l := Label3D.new()
	l.text = label.split(" - ")[0]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.006
	l.position = Vector3(0, 1.6, 0)
	m.add_child(l)
	interactables.append({"pos": pos, "label": label, "fn": fn})


func nearest_interactable(pos: Vector3) -> Dictionary:
	for it in interactables:
		if pos.distance_to(it.pos) < 3.0:
			return it
	return {}


func try_interact(h: Hero) -> void:
	var it := nearest_interactable(h.global_position)
	if not it.is_empty():
		it.fn.call(h)


func _trial(area: String, pos: Vector3) -> void:
	for i in range(trial_alive.size() - 1, -1, -1):
		if not is_instance_valid(trial_alive[i]) or trial_alive[i].dead:
			trial_alive.remove_at(i)
	if trial_alive.size() > 0:
		Events.notify.emit("Finish the current trial first (%d left)" % trial_alive.size())
		return
	var pack: Array = TRIAL_POOLS[area].pick_random()
	for i in pack.size():
		var entry: Array = pack[i]
		var ang := TAU * i / float(pack.size())
		var e := Game.spawn_enemy(entry[0], pos + Vector3(cos(ang), 0.2, sin(ang)) * 4.0, area, entry.size() > 1 and entry[1])
		if e:
			trial_alive.append(e)
	Events.notify.emit("Trial begins")


func _shrine(h: Hero) -> void:
	if h.class_id != "mage":
		Events.notify.emit("The shrine only answers to a Mage")
		return
	var p := Game.prog("mage")
	if Game.mage_core == "elementalist":
		# Worldweaver: elements come with experience (approved table: Lv3 Frost, Lv7 Stone, Lv9 Storm)
		var known: Array = p.known_elements()
		Events.notify.emit("The shrine resonates with your %s. Further disciplines awaken with experience (Lv 3 Frost, Lv 7 Stone, Lv 9 Storm)." % ", ".join(known.map(func(e): return String(e).capitalize())))
		return
	if p.elements.has("stone"):
		Events.notify.emit("Stone is already attuned")
		return
	p.shrine_elements.append("stone")
	Game.unlock_element("stone", "Elemental Shrine")


func _on_zone_completed(z: EncounterZone) -> void:
	var area := z.area_key
	if cleared.get(area, false):
		return
	for other in zones.get(area, []):
		if not other.done:
			return
	cleared[area] = true
	Events.objective_completed.emit("%s cleared" % AREAS[area].name, Game.balance.area_objective_exp)
	Game.gain_exp(Game.balance.area_objective_exp, "Area cleared: " + AREAS[area].name)
	Events.notify.emit("%s CLEARED" % AREAS[area].name.to_upper())
	open_gate(area)


# ------------------------------------------------------------------ boss
func _physics_process(_delta: float) -> void:
	var p := Game.player
	if not is_instance_valid(p):
		return
	Scenery.update_atmosphere(p.global_position.z)
	var area := area_at(p.global_position)
	if area != current_area:
		current_area = area
		var an: String = AREAS[area].name if area != "training" else "Training Grounds"
		Events.area_entered.emit(an)
		Events.notify.emit(an)
		if area != "training" and _area_order(area) > _area_order(checkpoint_area):
			checkpoint_area = area
	if boss == null and not cleared.get("boss", false) and p.visible and not boss_zone.is_empty():
		if p.global_position.distance_to(boss_zone.center) < boss_zone.radius - 2.0:
			start_boss()


func start_boss() -> void:
	if boss != null and is_instance_valid(boss):
		return
	boss = Game.spawn_enemy("ashen_warden", boss_zone.center + Vector3(0, 0.3, -6), "keep", false)
	boss_gate = _gate(Vector3(0, 2, boss_zone.center.z + boss_zone.radius + 1.5), "Defeat the Warden")
	Events.notify.emit("THE ASHEN WARDEN")
	Events.log_message.emit("Boss encounter started", "system")


func end_boss_attempt() -> void:
	if is_instance_valid(boss):
		boss.queue_free()
	boss = null
	if is_instance_valid(boss_gate):
		boss_gate.queue_free()
	boss_gate = null


func _on_enemy_killed(e, _k) -> void:
	if e == boss:
		cleared["boss"] = true
		boss = null
		if is_instance_valid(boss_gate):
			boss_gate.queue_free()
		Events.objective_completed.emit("The Ashen Warden defeated", 0)
		Events.notify.emit("ASHEN VALLEY CLEARED")


func _area_order(a: String) -> int:
	return ["outskirts", "ruins", "keep"].find(a)


func area_at(pos: Vector3) -> String:
	if pos.z > 44.0:
		return "training"
	if pos.z > -42.0:
		return "outskirts"
	if pos.z > -125.0:
		return "ruins"
	return "keep"


func checkpoint_position() -> Vector3:
	return AREAS[checkpoint_area].checkpoint


func on_player_true_death() -> void:
	if boss != null:
		end_boss_attempt()


func teleport_player(area: String) -> void:
	if not is_instance_valid(Game.player):
		return
	var pos: Vector3
	if area == "training":
		ensure_training_dummies()
		pos = TRAINING_CENTER + Vector3(0, 0.5, -6)
	else:
		pos = AREAS[area].checkpoint if area != "boss" else boss_zone.center + Vector3(0, 0.5, 10)
	Game.player.teleport(pos)
	for h in Game.heroes:
		if is_instance_valid(h) and h != Game.player:
			h.teleport(pos + Vector3(randf_range(-2, 2), 0, 2))
	var brain = Game.player.get_node_or_null("Brain")
	if brain and is_instance_valid(brain.rig):
		brain.rig.snap_to_target()


func shake(amount: float) -> void:
	if is_instance_valid(Game.player):
		var brain = Game.player.get_node_or_null("Brain")
		if brain and "rig" in brain and is_instance_valid(brain.rig):
			brain.rig.add_shake(amount)
