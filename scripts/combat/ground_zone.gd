class_name GroundZone
extends Node3D
## Lingering area (burning ground, Phoenix Bloom, Living Flame, Sanctuary...). Calls `on_tick(zone)`
## every `tick` seconds; helpers return combatants inside.

var source = null
var team: int = 0
var radius: float = 2.0
var duration: float = 3.0
var tick: float = 0.5
var t: float = 0.0
var tick_t: float = 0.0
var on_tick: Callable
var mat: StandardMaterial3D


static func spawn(p_source, pos: Vector3, p_radius: float, p_duration: float, color: Color, p_tick: float, p_on_tick: Callable) -> GroundZone:
	var z := GroundZone.new()
	z.source = p_source
	z.team = p_source.team if is_instance_valid(p_source) else 1
	z.radius = p_radius
	z.duration = p_duration
	z.tick = p_tick
	z.on_tick = p_on_tick
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = p_radius
	cm.bottom_radius = p_radius
	cm.height = 0.05
	mi.mesh = cm
	z.mat = StandardMaterial3D.new()
	z.mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	z.mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	z.mat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	mi.material_override = z.mat
	z.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = p_radius * 1.5
	light.position = Vector3(0, 0.6, 0)
	z.add_child(light)
	Game.fx_root().add_child(z)
	z.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	z.reset_physics_interpolation()
	return z


func members(group: String) -> Array:
	var out: Array = []
	for c in get_tree().get_nodes_in_group(group):
		if c is Combatant and c.is_targetable():
			var d: Vector3 = c.global_position - global_position
			d.y = 0
			if d.length() <= radius + 0.4:
				out.append(c)
	return out


func enemies_of_source() -> Array:
	return members("enemies" if team == 0 else "heroes")


func allies_of_source() -> Array:
	return members("heroes" if team == 0 else "enemies")


func _physics_process(delta: float) -> void:
	t += delta
	tick_t += delta
	if tick_t >= tick:
		tick_t -= tick
		if on_tick.is_valid():
			on_tick.call(self)
	mat.albedo_color.a = 0.4 * (1.0 - clampf((t - duration + 0.5) / 0.5, 0.0, 1.0))
	if t >= duration:
		queue_free()
