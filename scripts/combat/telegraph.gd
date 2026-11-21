class_name Telegraph
extends Node3D
## Ground indicator for enemy attacks. Rectangles are attached to the attacker (they follow its
## tracking); circles are placed in the world for delayed AoEs. Alpha ramps up as impact nears.

var mat: StandardMaterial3D
var duration: float = 1.0
var t: float = 0.0
var auto_free: bool = true
var base_alpha: float = 0.5


static func _make(color: Color) -> Array:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, 0.1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tg := Telegraph.new()
	tg.mat = m
	tg.base_alpha = maxf(color.a, 0.35)
	return [tg, m]


static func rect(parent: Node3D, size: Vector3, offset: Vector3, p_duration: float, color: Color) -> Telegraph:
	var made := _make(color)
	var tg: Telegraph = made[0]
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	mi.mesh = pm
	mi.material_override = made[1]
	tg.add_child(mi)
	tg.duration = p_duration
	parent.add_child(tg)
	tg.position = Vector3(offset.x, 0.06, offset.z)
	return tg


static func circle(pos: Vector3, radius: float, p_duration: float, color: Color) -> Telegraph:
	var made := _make(color)
	var tg: Telegraph = made[0]
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	mi.mesh = cm
	mi.material_override = made[1]
	tg.add_child(mi)
	tg.duration = p_duration
	Game.fx_root().add_child(tg)
	tg.global_position = Vector3(pos.x, pos.y + 0.06, pos.z)
	tg.reset_physics_interpolation()
	return tg


var committed: bool = false


## COMBAT-BALANCE-UX-006: the attacker's direction is now locked - the area stops turning and brightens.
func commit() -> void:
	if committed or mat == null:
		return
	committed = true
	var c := mat.albedo_color
	mat.albedo_color = Color(lerpf(c.r, 1.0, 0.5), lerpf(c.g, 0.85, 0.4), lerpf(c.b, 0.5, 0.3), c.a)
	base_alpha = minf(base_alpha + 0.2, 0.85)


func _process(delta: float) -> void:
	t += delta
	var k := clampf(t / maxf(duration, 0.01), 0.0, 1.0)
	mat.albedo_color.a = lerpf(0.12, base_alpha, k)
	if k >= 1.0:
		mat.albedo_color = Color(1, 1, 1, 0.7)
	if auto_free and t >= duration + 0.12:
		queue_free()
