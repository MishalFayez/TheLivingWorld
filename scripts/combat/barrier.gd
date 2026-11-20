class_name Barrier
extends Node3D
## Phantom Bulwark barrier. A real defensive object with HP:
## - absorbs damage dealt to allied heroes standing inside it from attackers OUTSIDE it,
## - blocks enemy projectiles entering it,
## - breaks when its HP is depleted or it expires.

var team: int = 0
var radius: float = 3.5
var hp: float = 100.0
var max_hp: float = 100.0
var duration: float = 6.0
var t: float = 0.0
var owner_hero = null
var mat: StandardMaterial3D


static func spawn(p_owner, pos: Vector3, p_radius: float, p_hp: float, p_duration: float) -> Barrier:
	var b := Barrier.new()
	b.owner_hero = p_owner
	b.team = p_owner.team
	b.radius = p_radius
	b.hp = p_hp
	b.max_hp = p_hp
	b.duration = p_duration
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = p_radius
	s.height = p_radius * 2.0
	s.is_hemisphere = true
	mi.mesh = s
	b.mat = StandardMaterial3D.new()
	b.mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b.mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.mat.cull_mode = BaseMaterial3D.CULL_BACK   # no full-screen tint when the camera is inside the dome
	b.mat.albedo_color = Color(0.4, 0.75, 1.0, 0.22)
	mi.material_override = b.mat
	b.add_child(mi)
	var label := Label3D.new()
	label.name = "HP"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, p_radius + 0.4, 0)
	label.pixel_size = 0.004
	label.font_size = 28
	label.outline_size = 8
	label.modulate = Color(0.6, 0.85, 1.0)
	b.add_child(label)
	b.add_to_group("barriers")
	Game.fx_root().add_child(b)
	b.global_position = pos
	b.reset_physics_interpolation()
	b._update_label()
	return b


func contains(pos: Vector3) -> bool:
	var d := pos - global_position
	d.y = 0
	return d.length() <= radius


func blocks_point(pos: Vector3) -> bool:
	return contains(pos) and pos.y - global_position.y < radius + 0.5


## True if this barrier should absorb `info` aimed at `hero`.
func protects(hero, info: DamageInfo) -> bool:
	if hp <= 0.0 or hero.team != team or not contains(hero.global_position):
		return false
	if info.is_dot:
		return false
	return info.is_projectile or not contains(info.source_pos)


func absorb(info: DamageInfo, hero: Node) -> void:
	var take := minf(info.amount, hp)
	var before := info.amount
	hp -= take
	info.amount -= take
	info.absorbed += take
	if before > 0.0:
		info.poise *= info.amount / before
	if info.amount <= 0.01:
		info.cancelled = true
	Events.guard_event.emit(hero, info, "barrier")
	_update_label()
	if hp <= 0.0:
		_break()


func absorb_projectile(dmg: float) -> void:
	hp -= dmg
	Events.log_message.emit("Barrier blocked a projectile (%d)" % roundi(dmg), "guard")
	_update_label()
	if hp <= 0.0:
		_break()


func _update_label() -> void:
	var l: Label3D = get_node_or_null("HP")
	if l:
		l.text = "Bulwark %d" % maxi(0, roundi(hp))


func _break() -> void:
	Events.log_message.emit("Phantom Bulwark barrier shattered", "guard")
	FX.burst(global_position + Vector3(0, 1, 0), radius, Color(0.5, 0.8, 1.0))
	queue_free()


func _physics_process(delta: float) -> void:
	t += delta
	mat.albedo_color.a = 0.22 + 0.08 * sin(t * 6.0)
	if t >= duration:
		Events.log_message.emit("Phantom Bulwark barrier faded", "guard")
		queue_free()
