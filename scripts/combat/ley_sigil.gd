class_name LeySigil
extends Node3D
## MAGE CORE (Update 5): Ley Sigil — a circle of one element inscribed on the ground.
##   * Pulses its element every second (Life heals allies, Fire burns, Frost chills, Storm zaps,
##     Stone hardens allies).
##   * Resonance (Lv5): Mage spells hitting enemies inside trigger the element (see resonate()).
##   * Consume (press E again): element-specific burst (Life = group heal + Ward).
## Positioning matters: Life where allies fight, Fire/Frost/Storm where enemies stand.

const COLORS := {
	"fire": Color(1.0, 0.45, 0.15), "life": Color(0.45, 1.0, 0.55), "frost": Color(0.6, 0.88, 1.0),
	"storm": Color(0.75, 0.6, 1.0), "stone": Color(0.85, 0.65, 0.38),
}

var element: String = "life"
var mage: Hero
var radius: float = 4.0
var duration: float = 10.0
var pulse_every: float = 1.0
var t: float = 0.0
var pulse_t: float = 0.0
var glyph: Node3D
var ring_mat: StandardMaterial3D
var disk_mat: StandardMaterial3D
var consumed: bool = false


static func inscribe(p_mage: Hero, p_element: String, pos: Vector3, p_radius: float, p_duration: float, p_pulse: float) -> LeySigil:
	var s := LeySigil.new()
	s.mage = p_mage
	s.element = p_element
	s.radius = p_radius
	s.duration = p_duration
	s.pulse_every = p_pulse
	s.add_to_group("ley_sigils")
	Game.fx_root().add_child(s)
	s.global_position = Vector3(pos.x, pos.y + 0.04, pos.z)
	s.reset_physics_interpolation()
	s._build()
	return s


func _build() -> void:
	var col: Color = COLORS.get(element, Color.WHITE)
	var disk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	disk.mesh = cm
	disk_mat = StandardMaterial3D.new()
	disk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disk_mat.albedo_color = Color(col.r, col.g, col.b, 0.12)
	disk.material_override = disk_mat
	add_child(disk)
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	ring_mat.emission_enabled = true
	ring_mat.emission = col
	ring_mat.emission_energy_multiplier = 2.5
	for r in [radius, radius * 0.62]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.05
		tm.outer_radius = r
		tm.rings = 64
		ring.mesh = tm
		ring.material_override = ring_mat
		ring.scale = Vector3(1, 0.15, 1)
		add_child(ring)
	# rotating glyph: element-specific number of spokes + rune stones
	glyph = Node3D.new()
	add_child(glyph)
	var spokes: int = {"fire": 3, "life": 6, "frost": 6, "storm": 4, "stone": 8}.get(element, 5)
	for i in spokes:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.02, radius * 1.2)
		bar.mesh = bm
		bar.material_override = ring_mat
		bar.rotation.y = PI * i / float(spokes)
		glyph.add_child(bar)
		var rune := MeshInstance3D.new()
		var rm := PrismMesh.new()
		rm.size = Vector3(0.22, 0.32, 0.06)
		rune.mesh = rm
		rune.material_override = ring_mat
		var a: float = TAU * i / float(spokes)
		rune.position = Vector3(cos(a) * radius * 0.8, 0.25, sin(a) * radius * 0.8)
		glyph.add_child(rune)
	var light := OmniLight3D.new()
	light.light_color = col
	light.omni_range = radius * 1.4
	light.light_energy = 1.2
	light.position = Vector3(0, 0.8, 0)
	add_child(light)
	VFX.element_motes(self, element, radius)


func contains(pos: Vector3) -> bool:
	var d := pos - global_position
	d.y = 0
	return d.length() <= radius + 0.3


func _members(group: String) -> Array:
	var out: Array = []
	for c in get_tree().get_nodes_in_group(group):
		if c is Combatant and c.is_targetable() and contains(c.global_position):
			out.append(c)
	return out


func enemies_inside() -> Array:
	return _members("enemies")


func allies_inside() -> Array:
	return _members("heroes")


func _physics_process(delta: float) -> void:
	t += delta
	pulse_t += delta
	glyph.rotation.y += delta * (1.2 if element != "stone" else 0.4)
	var fade := clampf((duration - t) / 0.6, 0.0, 1.0)
	ring_mat.albedo_color.a = 0.85 * fade
	disk_mat.albedo_color.a = (0.12 + 0.05 * sin(t * 4.0)) * fade
	if pulse_t >= pulse_every:
		pulse_t -= pulse_every
		pulse()
	if t >= duration or not is_instance_valid(mage):
		queue_free()


func _wp() -> float:
	return mage.weapon_power if is_instance_valid(mage) else 20.0


func _tag() -> Dictionary:
	return {"hitstop": 0.0, "knockback": 0.0, "tags": {"sigil": true}}


## Passive elemental pulse.
func pulse() -> void:
	if not is_instance_valid(mage):
		return
	var wp := _wp()
	match element:
		"life":
			for a in allies_inside():
				mage.kit.heal_target(a, wp * 0.16, "Life Sigil", {"no_fx": true})
		"fire":
			for e in enemies_inside():
				mage.spell_damage(e, 0.22, 2.0, "Fire Sigil", _tag())
		"frost":
			for e in enemies_inside():
				mage.kit._chill(e, 0.6, 1.4, "sigil_chill", "Sigil Chill")
		"storm":
			var es := enemies_inside()
			if not es.is_empty():
				var e = es.pick_random()
				VFX.lightning(global_position + Vector3(0, 6, 0), e.global_position + Vector3(0, 1, 0))
				mage.spell_damage(e, 0.5, 8.0, "Storm Sigil", _tag())
		"stone":
			for a in allies_inside():
				var st := StatusEffect.make("stone_sigil", "Stone Sigil", "buff", 1.6, {"damage_taken": 0.82, "poise_taken": 0.6})
				st.source = mage
				a.statuses.add(st.scaled_by(mage.stats.effect_power()))


## Resonance: a Mage spell hit `target` inside this sigil.
func resonate(target, info: DamageInfo) -> void:
	if not is_instance_valid(mage) or not is_instance_valid(target):
		return
	var wp := _wp()
	match element:
		"fire":
			VFX.fire_burst(target.global_position, 1.6)
			for e in enemies_inside():
				if e.global_position.distance_to(target.global_position) < 1.8:
					mage.spell_damage(e, 0.45, 6.0, "Resonance: Flare", _tag())
		"frost":
			mage.kit._chill(target, 0.15, 1.0, "frozen", "Frozen")
			VFX.frost_burst(target.global_position, 0.9)
		"storm":
			var nxt = null
			var nd := 6.0
			for e in enemies_inside():
				if e != target:
					var dd: float = e.global_position.distance_to(target.global_position)
					if dd < nd:
						nd = dd
						nxt = e
			if nxt:
				VFX.lightning(target.global_position + Vector3(0, 1, 0), nxt.global_position + Vector3(0, 1, 0))
				mage.spell_damage(nxt, 0.55, 8.0, "Resonance: Arc", _tag())
		"stone":
			target.take_poise(25.0)
			VFX.stone_burst(target.global_position, 0.8)
		"life":
			var amt := info.final_amount * 0.25
			if amt > 0.5:
				for a in allies_inside():
					mage.kit.heal_target(a, amt, "Resonance: Sanctified Ground", {"no_fx": true})
	Events.augment_triggered.emit(mage, "m_resonance", "%s resonance on %s" % [element.capitalize(), target.display_name])


## Consume: element-specific burst, then the sigil disappears.
func detonate() -> void:
	if consumed or not is_instance_valid(mage):
		return
	consumed = true
	var wp := _wp()
	var col: Color = COLORS.get(element, Color.WHITE)
	match element:
		"life":
			VFX.life_bloom(global_position, radius)
			var ward_mult := float(mage.kit.ap("sanctified_ward", "ward_mult", 1.0)) if mage.kit.aug("sanctified_ward") > 0 else 1.0
			for a in allies_inside():
				mage.kit.heal_target(a, wp * 1.2, "Life Sigil Bloom")
				if mage.unlocked("m_ward"):
					a.add_shield(wp * 0.8 * mage.stats.effect_power() * ward_mult, 6.0, mage)
				if ward_mult > 1.0:
					for e in a.statuses.effects.duplicate():
						if e.kind == "debuff" or e.kind == "dot":
							a.statuses.remove(e.id)
		"fire":
			VFX.fire_burst(global_position, radius)
			for e in enemies_inside():
				mage.spell_damage(e, 2.2, 45.0, "Fire Sigil Eruption", {"knockback": 4.0, "tags": {"sigil": true}})
				mage.kit._burn(e, 0.2)
		"frost":
			VFX.frost_burst(global_position, radius)
			for e in enemies_inside():
				mage.spell_damage(e, 1.2, 50.0, "Frost Sigil Shatter", {"tags": {"sigil": true}})
				mage.kit._chill(e, 0.1, 2.0, "frozen", "Frozen")
		"storm":
			for e in enemies_inside():
				VFX.lightning(e.global_position + Vector3(0, 9, 0), e.global_position + Vector3(0, 1, 0))
				mage.spell_damage(e, 1.8, 35.0, "Storm Sigil Tempest", {"tags": {"sigil": true}})
		"stone":
			VFX.stone_burst(global_position, radius)
			for e in enemies_inside():
				mage.spell_damage(e, 1.5, 80.0, "Stone Sigil Upheaval", {"type": AttackData.DamageType.PHYSICAL, "knockback": 6.0, "tags": {"sigil": true}})
			for a in allies_inside():
				var st := StatusEffect.make("stoneskin", "Stoneskin", "buff", 6.0, {"damage_taken": 0.7, "poise_taken": 0.4})
				st.source = mage
				a.statuses.add(st.scaled_by(mage.stats.effect_power()))
	Events.fusion_cast.emit(mage, "%s Sigil consumed" % element.capitalize())
	FX.burst(global_position + Vector3(0, 0.4, 0), radius * 0.6, col, 0.35)
	queue_free()
