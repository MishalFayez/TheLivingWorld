class_name Projectile
extends Node3D
## Simple swept projectile. Collides with world geometry (ray), opposing combatants (distance)
## and — for enemy projectiles — hero Barriers (Phantom Bulwark).

var team: int = 0
var source = null
var velocity: Vector3 = Vector3.ZERO
var radius: float = 0.35
var life: float = 3.0
var est_damage: float = 10.0
var on_hit: Callable
var _done: bool = false


static func spawn(p_source, pos: Vector3, dir: Vector3, speed: float, p_radius: float, color: Color, p_on_hit: Callable, p_life: float = 3.0, est: float = 10.0) -> Projectile:
	var p := Projectile.new()
	p.team = p_source.team
	p.source = p_source
	p.velocity = dir.normalized() * speed
	p.radius = p_radius
	p.life = p_life
	p.on_hit = p_on_hit
	p.est_damage = est
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = p_radius
	s.height = p_radius * 2.0
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	p.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 3.0
	light.light_energy = 1.5
	p.add_child(light)
	Game.fx_root().add_child(p)
	p.global_position = pos
	p.reset_physics_interpolation()
	return p


func _physics_process(delta: float) -> void:
	if _done:
		return
	var from := global_position
	var to := from + velocity * delta
	# world geometry AND Worldweaver formations (ice is on LAYER_FROST) stop projectiles
	var q := PhysicsRayQueryParameters3D.create(from, to, Combatant.LAYER_WORLD | Combatant.LAYER_FROST)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		if team == 1 and hit.collider is WorldFormation:
			hit.collider.on_projectile(hit.position, est_damage)
		_impact(null, hit.position)
		return
	global_position = to
	if team == 1:
		for b in get_tree().get_nodes_in_group("barriers"):
			if b.team == 0 and b.blocks_point(global_position):
				b.absorb_projectile(est_damage)
				FX.burst(global_position, 0.8, Color(0.5, 0.8, 1.0))
				_done = true
				queue_free()
				return
	var group := "enemies" if team == 0 else "heroes"
	for c in get_tree().get_nodes_in_group(group):
		if c is Combatant and c.is_targetable():
			var center: Vector3 = c.global_position + Vector3(0, 0.9, 0)
			if center.distance_to(global_position) < radius + 0.6:
				_impact(c, global_position)
				return
	life -= delta
	if life <= 0.0:
		_impact(null, global_position)


func _impact(target, pos: Vector3) -> void:
	if _done:
		return
	_done = true
	if on_hit.is_valid():
		on_hit.call(target, pos)
	queue_free()
