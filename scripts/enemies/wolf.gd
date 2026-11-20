class_name Wolf
extends Enemy
## Fast, low HP. Lunges from mid range, quick bite up close, circles while attacks recover.


func setup_type() -> void:
	display_name = "Wolf"
	enemy_type = "wolf"
	weight_class = "light"
	base_hp = 55.0
	base_poise = 20.0
	base_power = 10.0
	armor = 5.0
	magic_resist = 5.0
	move_speed = 7.2
	turn_speed = 9.0
	aggro_range = 16.0
	global_cd = 1.0
	post_pause = 0.5
	engage_delay = Vector2(0.25, 0.6)
	load_attacks(["wolf_lunge", "wolf_bite"])
	_build_wolf()


func _build_wolf() -> void:
	base_color = Color(0.42, 0.4, 0.42)
	var fur := base_color
	var dark := fur.darkened(0.35)
	var light_fur := Color(0.78, 0.74, 0.7)
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 1.35
	body_mesh = make_part(body, fur, Vector3(0, 0.78, 0.0))
	body_mesh.rotation.x = PI / 2
	body_material = body_mesh.material_override
	var chest := SphereMesh.new()
	chest.radius = 0.33
	chest.height = 0.66
	make_part(chest, light_fur, Vector3(0, 0.74, -0.42)).scale = Vector3(0.9, 1.0, 0.9)
	var mane := SphereMesh.new()
	mane.radius = 0.34
	mane.height = 0.68
	make_part(mane, dark, Vector3(0, 0.92, -0.38)).scale = Vector3(1.0, 0.85, 0.75)
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	make_part(head, fur, Vector3(0, 1.0, -0.78))
	var snout := PrismMesh.new()
	snout.size = Vector3(0.2, 0.36, 0.18)
	make_part(snout, light_fur, Vector3(0, 0.94, -1.0)).rotation.x = -PI / 2
	var nose := SphereMesh.new()
	nose.radius = 0.04
	nose.height = 0.08
	make_part(nose, Color(0.08, 0.06, 0.06), Vector3(0, 0.95, -1.18))
	for side in [-1.0, 1.0]:
		var ear := PrismMesh.new()
		ear.size = Vector3(0.1, 0.18, 0.06)
		make_part(ear, dark, Vector3(0.1 * side, 1.23, -0.72)).rotation.z = -0.25 * side
		var eye := SphereMesh.new()
		eye.radius = 0.03
		eye.height = 0.06
		make_part(eye, Color(1.0, 0.6, 0.1), Vector3(0.09 * side, 1.05, -0.97), null, 4.0)
	var tail := CapsuleMesh.new()
	tail.radius = 0.08
	tail.height = 0.6
	make_part(tail, dark, Vector3(0, 0.92, 0.78)).rotation.x = 1.0
	for x in [-0.17, 0.17]:
		for z in [-0.4, 0.4]:
			var leg := CapsuleMesh.new()
			leg.radius = 0.07
			leg.height = 0.6
			make_part(leg, dark, Vector3(x, 0.3, z))
			var paw := SphereMesh.new()
			paw.radius = 0.08
			paw.height = 0.12
			make_part(paw, Color(0.25, 0.22, 0.22), Vector3(x, 0.05, z - 0.03))


func custom_chase(delta: float) -> bool:
	var d := dist_to_target()
	if d < 6.5 and d > 1.8 and Game.time < global_cd_until + 1.2:
		var to := dir_to_target()
		var tangent := to.cross(Vector3.UP) * circle_dir
		move_dir(tangent * 0.8 + to * 0.3, delta, 0.65)
		turn_toward(to, turn_speed, delta)
		return true
	return false
