class_name TrainingDummy
extends Enemy
## Training dummy (Update 5). Never dies, never moves. Armor / magic resist can be changed from
## the Training panel. Optional "swing" mode: a slow, telegraphed overhead every few seconds so
## Guard / Perfect Guard / Perfect Dodge / Openings can be practised.

var swing_mode: bool = false
var swing_every: float = 3.0
var _swing_t: float = 2.0


func setup_type() -> void:
	display_name = "Training Dummy"
	enemy_type = "training_dummy"
	base_hp = 20000.0
	base_poise = 60.0
	base_power = 6.0
	armor = 0.0
	magic_resist = 0.0
	move_speed = 0.0
	turn_speed = 4.0
	aggro_range = 0.0
	exp_override = 0.0
	load_attacks(["raider_heavy"])
	_build_dummy()
	add_to_group("training_dummy")


func _build_dummy() -> void:
	var wood := Color(0.55, 0.38, 0.22)
	var straw := Color(0.85, 0.72, 0.4)
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.11
	post.height = 1.9
	make_part(post, wood, Vector3(0, 0.95, 0))
	var body := CylinderMesh.new()
	body.top_radius = 0.32
	body.bottom_radius = 0.36
	body.height = 0.8
	var b := make_part(body, straw, Vector3(0, 1.25, 0))
	body_material = b.material_override
	base_color = straw
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	make_part(head, Color(0.8, 0.7, 0.5), Vector3(0, 1.9, 0))
	var arm := CylinderMesh.new()
	arm.top_radius = 0.05
	arm.bottom_radius = 0.05
	arm.height = 1.3
	var a := make_part(arm, wood, Vector3(0, 1.45, 0))
	a.rotation.z = PI / 2
	for y in [1.05, 1.45]:
		var band := TorusMesh.new()
		band.inner_radius = 0.33
		band.outer_radius = 0.38
		make_part(band, Color(0.45, 0.2, 0.15), Vector3(0, y, 0))
	# practice blade on the weapon pivot, only visible in swing mode
	var blade := BoxMesh.new()
	blade.size = Vector3(0.06, 0.1, 0.9)
	make_part(blade, wood, Vector3(0, 0, -0.45), weapon_pivot)


func _ready() -> void:
	super._ready()
	sm.set_physics_process(false)
	sm.set_process(false)


func set_defenses(p_armor: float, p_mres: float) -> void:
	armor = p_armor
	magic_resist = p_mres
	stats.armor = p_armor
	stats.magic_resist = p_mres
	_update_bar()


func on_damaged(info: DamageInfo) -> void:
	super.on_damaged(info)
	if hp < max_hp * 0.3:
		hp = max_hp


func on_zero_hp(_info: DamageInfo) -> void:
	hp = max_hp       # cannot die


func combat_process(delta: float) -> void:
	super.combat_process(delta)
	if stagger_timer > 0.0:
		return
	if not swing_mode or runner.is_busy():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.global_position.distance_to(global_position) > 3.2:
		return
	turn_toward(p.global_position - global_position, turn_speed, delta)
	_swing_t -= delta
	if _swing_t <= 0.0:
		_swing_t = swing_every
		target = p
		begin_attack(find_attack("raider_heavy"))
