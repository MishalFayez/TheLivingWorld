class_name ModelPreview
extends SubViewportContainer
## Live 3D preview of a class model (the same CharModel used in game) in its own small world:
## used by character creation and the Character screen. Slowly turns; drag to rotate.

var vp: SubViewport
var rig: Node3D
var class_id: String = ""
var spin: float = 0.25
var yaw: float = PI + 0.35
var _drag: bool = false
var _t: float = 0.0
var light_col: Color = Color(1.0, 0.92, 0.82)


class PreviewRig extends Node3D:
	var model: Node3D
	var weapon_pivot: Node3D
	var shield_pivot: Node3D
	var body_mesh: MeshInstance3D
	var body_material: StandardMaterial3D
	var velocity: Vector3 = Vector3.ZERO

	func _init() -> void:
		model = Node3D.new()
		add_child(model)
		weapon_pivot = Node3D.new()
		weapon_pivot.position = ProcAnim.REST[ProcAnim.T_WEAPON_POS]
		weapon_pivot.rotation = ProcAnim.REST[ProcAnim.T_WEAPON_ROT]
		model.add_child(weapon_pivot)
		shield_pivot = Node3D.new()
		shield_pivot.position = ProcAnim.REST[ProcAnim.T_SHIELD_POS]
		model.add_child(shield_pivot)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(512, 640)
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0, 1.25, 4.4)
	cam.look_at_from_position(cam.position, Vector3(0, 1.05, 0), Vector3.UP)
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_color = light_col
	key.light_energy = 1.25
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 0.7
	vp.add_child(rim)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.52, 0.5)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.4
	we.environment = e
	vp.add_child(we)
	# pedestal
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.85
	cm.height = 0.14
	ped.mesh = cm
	ped.material_override = CharModel.toon(Color(0.25, 0.22, 0.22), 0.0, 0.3)
	ped.position = Vector3(0, -0.07, 0)
	vp.add_child(ped)
	var ringm := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.78
	tm.outer_radius = 0.83
	ringm.mesh = tm
	ringm.material_override = CharModel.toon(UITheme.GOLD, 1.2, 0.0)
	ringm.scale = Vector3(1, 0.3, 1)
	vp.add_child(ringm)
	if class_id != "":
		show_class(class_id)


func show_class(c: String, p: ClassProgress = null) -> void:
	class_id = c
	if vp == null:
		return
	if rig:
		rig.queue_free()
	rig = PreviewRig.new()
	vp.add_child(rig)
	if p == null:
		p = ClassProgress.new(c)
		for it in Game.starter_items(c):
			p.equipment[it.slot] = it.id
	CharModel.build(rig, c, p)
	rig.rotation.y = yaw


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		yaw += event.relative.x * 0.01


func _process(delta: float) -> void:
	_t += delta
	if not _drag:
		yaw += spin * delta
	if rig and is_instance_valid(rig):
		rig.rotation.y = yaw
		rig.model.position.y = sin(_t * 1.8) * 0.012
		rig.weapon_pivot.rotation.x = ProcAnim.REST[ProcAnim.T_WEAPON_ROT].x + sin(_t * 1.8) * 0.03
