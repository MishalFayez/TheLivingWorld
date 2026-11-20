class_name FX
extends RefCounted
## Tiny procedural effects: floating numbers, expanding bursts, beams.


static func _mat(color: Color, unshaded: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func damage_number(target, info) -> void:
	if not Game.balance.damage_numbers:
		return
	var col := Color(1.0, 0.96, 0.9)
	if info.damage_type == AttackData.DamageType.MAGIC:
		col = Color(0.82, 0.62, 1.0)
	if info.is_crit:
		col = Color(1.0, 0.8, 0.2)
	if target.team == 0:
		col = Color(1.0, 0.38, 0.32)
	var txt := str(roundi(info.final_amount))
	var sc := 1.0
	if info.is_crit:
		txt = "CRIT  " + txt
		sc = 1.5
	if info.guarded:
		txt = ("PERFECT  " if info.perfect else "BLOCK  ") + txt
		col = Color(1.0, 0.85, 0.35) if info.perfect else Color(0.6, 0.78, 1.0)
		sc = 1.35 if info.perfect else 1.0
	if info.is_dot:
		sc = 0.7
	# numbers not involving the player are smaller and dimmer (less clutter in Party Test)
	var involved: bool = info.source == Game.player or target == Game.player
	if not involved:
		sc *= 0.62
		col.a = 0.6
	number(target, txt, col, sc)


static func number(target, text: String, color: Color, scale: float = 1.0) -> void:
	var root := Game.fx_root()
	if root == null or not target.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font = UITheme.title_font(true)
	l.font_size = int(36 * scale)
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.0045
	l.set("physics_interpolation_mode", 2)
	root.add_child(l)
	l.global_position = target.global_position + Vector3(randf_range(-0.4, 0.4), 2.3, randf_range(-0.4, 0.4))
	l.scale = Vector3.ONE * (1.7 if scale > 1.2 else 1.25)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.1, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


static func burst(pos: Vector3, radius: float, color: Color, time: float = 0.35) -> void:
	var root := Game.fx_root()
	if root == null:
		return
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	mi.mesh = s
	mi.material_override = _mat(Color(color.r, color.g, color.b, 0.55))
	mi.set("physics_interpolation_mode", 2)
	root.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, time)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


static func beam(a: Vector3, b: Vector3, color: Color, time: float = 0.25) -> void:
	var root := Game.fx_root()
	if root == null or a.distance_to(b) < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = _mat(Color(color.r, color.g, color.b, 0.9))
	mi.set("physics_interpolation_mode", 2)
	root.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, time)
	tw.tween_callback(mi.queue_free)


## Perfect Guard flash (gold ring at the shield + sparks + light).
static func guard_flash(hero) -> void:
	if not is_instance_valid(hero):
		return
	var f: Vector3 = hero.forward()
	VFX.guard_flash(hero.global_position + Vector3(0, 1.1, 0) + f * 0.7, f)
