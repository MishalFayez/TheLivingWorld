class_name Hitbox
extends Area3D
## Melee hitbox (Area3D). The AttackRunner resizes it from AttackData and reads overlaps during
## the ACTIVE window. Visible when "Display attack hitboxes" is enabled in the Debug Panel.

var owner_c = null
var shape: BoxShape3D
var debug_mesh: MeshInstance3D
var _box: BoxMesh


func setup(c: Node) -> void:
	owner_c = c
	monitoring = false
	monitorable = false
	collision_layer = 0
	var cs := CollisionShape3D.new()
	shape = BoxShape3D.new()
	cs.shape = shape
	add_child(cs)
	debug_mesh = MeshInstance3D.new()
	_box = BoxMesh.new()
	debug_mesh.mesh = _box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.1, 0.1, 0.35) if c.team == 1 else Color(0.2, 0.6, 1.0, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	debug_mesh.material_override = mat
	debug_mesh.visible = false
	add_child(debug_mesh)


func configure(size: Vector3, offset: Vector3) -> void:
	shape.size = size
	_box.size = size
	position = offset


func activate(on: bool) -> void:
	collision_mask = Combatant.LAYER_ENEMIES if owner_c.team == 0 else Combatant.LAYER_HEROES
	monitoring = on
	debug_mesh.visible = on and Game.show_hitboxes


func targets() -> Array:
	var out: Array = []
	if not monitoring:
		return out
	for b in get_overlapping_bodies():
		if b is Combatant and b != owner_c and b.team != owner_c.team and b.is_targetable():
			out.append(b)
	return out
