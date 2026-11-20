class_name MageElementalist
extends RefCounted
## MAGE — THE WORLDWEAVER (approved combat design v1.0). Internal core id stays "elementalist" so
## saves, routing and the debug core switch keep working; every rule below follows the spec.
##
## Charged spellcasting: hold to prepare, release before full charge = partial version, release at
## full charge = full version. Holding longer adds nothing. No perfect-charge bonus. Mana is the
## only resource and is spent ONLY on a successful release (dodge-cancel costs nothing).
##
##   LMB / RMB / 1 : the three charged spell slots (Spellbook, B)
##   3             : utility slot (Protective Renewal / Frozen Bastion / Rising Pillar / Stone Ward)
##                   formation utilities: hold 3 to aim (placement preview), release to cast
##   F             : Lifeline (emergency heal)           E : Arcane Sanctum (Lv5)
##   T             : cycle heal target (you -> allies)   2 : heal target = most injured ally
##   Space         : Dodge (cancels a charge; Lv10 Arcane Mastery may preserve 40% of it)
##
## World formations (WorldFormation): max 2 solid per Mage (oldest removed with full cleanup),
## max 2 burning areas, steam has its own cap (SteamCloud). Elemental interactions happen only
## through real effects touching real formations: Thermal Fracture, Conductive Anchors, Living
## Bastion, Shattered Winter. Interaction products never trigger further interactions.

const CHARGED_ORDER := ["flame_cataclysm", "inferno_wave", "cinderfall", "crystal_formation", "glacial_spear", "earthbreaker",
	"thunder_conduit", "lightning_verdict", "storm_arc", "life_bloom", "verdant_renewal"]
const UTILITY_ORDER := ["protective_renewal", "frozen_bastion", "rising_pillar", "stone_ward"]
const UTIL_SLOT := 3
const BLOOM_MODES_ID := "bloom_modes"     # advanced Life Bloom functionality (Focused / Shared)
const COLORS := {"fire": Color(1.0, 0.45, 0.15), "life": Color(0.45, 1.0, 0.55), "frost": Color(0.6, 0.88, 1.0), "storm": Color(0.78, 0.65, 1.0), "stone": Color(0.72, 0.56, 0.36)}
const WEIGHT_DISPLACE := {"light": 1.0, "medium": 0.4, "heavy": 0.0}

var kit
var hero: Hero
var spells: Dictionary = {}
var cur: ChargedSpellData = null
var cur_action: String = ""
var charge_t: float = 0.0
var release_queued: bool = false
var fx: ChargeFX
var heal_target = null
var sanctum: ArcaneSanctum
var preserved: Dictionary = {}
var mastery_cd: float = 0.0
var ai_spell: Dictionary = {}
var ai_aim = null                      # AI: explicit ground point for formation spells
var fire_zones: Array = []
var formations: Array = []             # solid formations owned by this Mage (oldest first)
var interactions: Array = []           # recent interaction events (debug / training)
var util_aiming: String = ""
var conductive_debug: bool = false     # Debug: new Stone formations are Conductive (no approved source)
var heal_ring: MeshInstance3D
var heal_ring_mat: StandardMaterial3D
var preview: Node3D
var preview_box: MeshInstance3D
var preview_disc: MeshInstance3D
var preview_mat: StandardMaterial3D
var last_release: Dictionary = {}
var release_info: Dictionary = {}       # per-cast results (targets hit, interrupt, ...) merged into last_release
var _known_cache: Array = []
var _know_t: float = 0.0
var _interaction_depth: int = 0
var _cast_serial: int = 0


func _init(p_kit) -> void:
	kit = p_kit
	hero = p_kit.hero
	for f in DirAccess.get_files_at("res://data/mage_spells"):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var s = load("res://data/mage_spells/" + file)
			if s is ChargedSpellData:
				spells[s.id] = s


func b() -> BalanceConfig:
	return Game.balance


# ------------------------------------------------------------------ knowledge / loadout
func prog() -> ClassProgress:
	return hero.prog()


func knows_element(el: String) -> bool:
	return prog().known_elements().has(el)


## A spell is known when its element is known and: it has no unlock (starting spell), its level
## milestone is reached, or a Debug grant gave it. Advanced spells (no level in the approved
## table) are Debug-grant only. Debug can also remove any spell.
func spell_known(id: String) -> bool:
	var s: ChargedSpellData = spells.get(id)
	if s == null or not knows_element(s.element):
		return false
	var p := prog()
	if p.debug_locks.has("spell:" + id):
		return false
	if p.debug_unlocks.has("spell:" + id):
		return true
	if s.advanced:
		return false
	if s.unlock_id == "":
		return true
	return kit.unlocked(s.unlock_id)


func bloom_modes_known() -> bool:
	return spell_known("life_bloom") and prog().debug_unlocks.has("spell:" + BLOOM_MODES_ID)


func bloom_shared() -> bool:
	return bloom_modes_known() and prog().bloom_shared


func set_bloom_shared(v: bool) -> void:
	prog().bloom_shared = v
	if hero.is_player:
		Events.notify.emit("Life Bloom: " + ("SHARED (all nearby allies, less each)" if v else "FOCUSED (selected target)"))


func known_charged() -> Array:
	var out: Array = []
	for id in CHARGED_ORDER:
		if spell_known(id):
			out.append(id)
	return out


func known_utility() -> Array:
	var out: Array = []
	for id in UTILITY_ORDER:
		if spell_known(id):
			out.append(id)
	return out


func _ensure_loadout() -> void:
	var p := prog()
	while p.spell_loadout.size() < 4:
		p.spell_loadout.append("")


func slot_spell(i: int) -> String:
	_ensure_loadout()
	var id := String(prog().spell_loadout[i])
	if id == "" or not spell_known(id):
		return ""
	var want := "utility" if i == UTIL_SLOT else "charged"
	return id if spells[id].slot_kind == want else ""


func utility_spell() -> String:
	return slot_spell(UTIL_SLOT)


## Put a spell in a slot (it moves out of any other slot). Slot 3 = utility.
func equip_spell(i: int, id: String) -> void:
	_ensure_loadout()
	var p := prog()
	if id != "":
		for k in 4:
			if String(p.spell_loadout[k]) == id:
				p.spell_loadout[k] = ""
	p.spell_loadout[i] = id


## A newly learned spell goes into the first empty matching slot so it is usable immediately.
func auto_equip(id: String) -> void:
	_ensure_loadout()
	if prog().spell_loadout.has(id):
		return
	if spells[id].slot_kind == "utility":
		if utility_spell() == "":
			equip_spell(UTIL_SLOT, id)
		return
	if spells[id].slot_kind != "charged":
		return
	for i in 3:
		if slot_spell(i) == "":
			equip_spell(i, id)
			return


func action_slot(action: String) -> int:
	return {"light": 0, "heavy": 1, "skill1": 2}.get(action, -1)


func spell_for_action(action: String) -> String:
	if ai_spell.has(action):
		return ai_spell[action] if spell_known(ai_spell[action]) else ""
	var i := action_slot(action)
	return slot_spell(i) if i >= 0 else ""


# ------------------------------------------------------------------ input
func on_press(action: String) -> void:
	match action:
		"light", "heavy", "skill1":
			begin(action)
		"life":
			lifeline()
		"core":
			cast_sanctum()
		"skill3":
			press_utility()
		"skill2":
			select_injured()
		"heal_target":
			cycle_heal_target()


func on_release(action: String) -> void:
	if action == "skill3" and util_aiming != "":
		var u := util_aiming
		util_aiming = ""
		cast_utility(u)
		return
	if cur != null and cur_action == action:
		request_release()


func begin(action: String) -> bool:
	if cur != null:
		return false
	var sid := spell_for_action(action)
	if sid == "":
		if hero.is_player:
			Events.notify.emit("Empty spell slot  -  equip a spell in the Spellbook (B)")
		return false
	if not hero.can_act():
		hero.buffer(action)
		return false
	var s: ChargedSpellData = spells[sid]
	if kit.mana < s.mana_partial:
		if hero.is_player:
			Events.notify.emit("Not enough mana")
		return false
	if s.element == "life" and current_heal_target() == null:
		if hero.is_player:
			Events.notify.emit("Heal target out of range")
		return false
	util_aiming = ""
	cur = s
	cur_action = action
	charge_t = 0.0
	release_queued = false
	if not preserved.is_empty() and preserved.spell == sid and Game.time < float(preserved.until):
		charge_t = float(preserved.t)
		kit.trigger("m_arcane_mastery", "%s resumed at %d%%" % [s.display_name, roundi(ratio() * 100.0)])
		preserved = {}
	kit.charging = action
	kit.charge_t = 0.0
	hero.play_anim("charge_" + s.element)
	if is_instance_valid(fx):
		fx.finish()
	fx = ChargeFX.attach(hero, s.element)
	Events.spell_charge_started.emit(hero, sid)
	if not hero.is_held(action):
		release_queued = true
	return true


func charge_speed() -> float:
	# Attack Speed shortens charge times within controlled limits (never rapid-fire)
	return clampf(hero.stats.attack_speed, 0.85, 1.2)


func ratio() -> float:
	if cur == null:
		return 0.0
	return clampf(charge_t / maxf(cur.full_charge, 0.01), 0.0, 1.0)


func is_full() -> bool:
	return cur != null and charge_t >= cur.full_charge


func move_mult() -> float:
	return cur.move_mult if cur != null else 1.0


func request_release() -> void:
	if cur == null:
		return
	if charge_t >= cur.min_charge:
		release()
	else:
		release_queued = true      # a tap still casts: it waits for the minimum release time


func process(delta: float) -> void:
	mastery_cd = maxf(0.0, mastery_cd - delta)
	if cur != null:
		charge_t = minf(charge_t + delta * charge_speed(), cur.full_charge + 5.0)
		if is_instance_valid(fx):
			fx.set_ratio(ratio(), is_full())
		if release_queued and charge_t >= cur.min_charge:
			release()
	if heal_target != null and (not is_instance_valid(heal_target) or heal_target.dead):
		heal_target = null
	fire_zones = fire_zones.filter(func(z): return is_instance_valid(z))
	formations = formations.filter(func(f): return is_instance_valid(f) and not f.gone)
	if sanctum != null and not is_instance_valid(sanctum):
		sanctum = null
	if hero.is_player:
		_update_heal_ring()
		_update_preview()
	_know_t -= delta
	if _know_t <= 0.0:
		_know_t = 0.5
		_check_discoveries()


## Newly learned spells go straight into an empty slot (no element choice: the approved
## progression grants Frost at 3, Stone at 7, Storm at 9).
func _check_discoveries() -> void:
	var now: Array = known_charged() + known_utility()
	for id in now:
		if not _known_cache.has(id) and not _known_cache.is_empty():
			auto_equip(id)
			if hero.is_player:
				Events.notify.emit("New spell: %s  (Spellbook: B)" % spells[id].display_name)
	if _known_cache.is_empty():
		for id in now:
			auto_equip(id)
	_known_cache = now


## Dodge / stagger / downed cancel the current charge: nothing is released, no mana is spent.
func cancel(reason: String) -> void:
	util_aiming = ""
	if cur == null:
		return
	if reason == "dodge" and kit.unlocked("m_arcane_mastery") and mastery_cd <= 0.0 and charge_t >= cur.min_charge:
		var keep: float = minf(charge_t, cur.full_charge) * b().ww_mastery_preserve
		preserved = {"spell": cur.id, "t": keep, "until": Game.time + b().ww_mastery_window}
		mastery_cd = b().ww_mastery_cooldown
		kit.trigger("m_arcane_mastery", "%s: %d%% of the charge preserved for %.0fs" % [cur.display_name, roundi(keep / cur.full_charge * 100.0), b().ww_mastery_window])
		if hero.is_player:
			Events.notify.emit("Arcane Mastery  -  charge preserved (cast %s again)" % cur.display_name)
	Events.spell_interrupted.emit(hero, cur.id, reason)
	_end_charge()


func _end_charge() -> void:
	cur = null
	cur_action = ""
	charge_t = 0.0
	release_queued = false
	kit.charging = ""
	if is_instance_valid(fx):
		fx.finish()
	fx = null


func in_sanctum() -> bool:
	return sanctum != null and is_instance_valid(sanctum) and sanctum.contains(hero.global_position)


func sanctum_mult() -> float:
	return float(kit.ap("wandering_sanctum", "effect_mult", 0.7)) if kit.aug("wandering_sanctum") > 0 else 1.0


func release() -> void:
	var s := cur
	var full := is_full()
	var cost := s.mana_for(full)
	if kit.mana < cost:
		if full and kit.mana >= s.mana_partial:
			full = false
			cost = s.mana_partial
			if hero.is_player:
				Events.notify.emit("Not enough mana for the full spell  -  partial cast")
		else:
			if hero.is_player:
				Events.notify.emit("Not enough mana")
			Events.spell_interrupted.emit(hero, s.id, "mana")
			_end_charge()
			return
	_cast_serial += 1
	release_info = {}
	var ctx := {"full": full, "sanctum": in_sanctum(), "charge_time": charge_t, "mult": sanctum_mult(), "cast": _cast_serial}
	var held := charge_t
	_end_charge()
	var ok := true
	match s.id:
		"flame_cataclysm":
			_flame(s, ctx)
		"inferno_wave":
			_inferno(s, ctx)
		"cinderfall":
			_cinderfall(s, ctx)
		"crystal_formation":
			ok = _crystal(s, ctx)
		"glacial_spear":
			_spear(s, ctx)
		"earthbreaker":
			_earth(s, ctx)
		"thunder_conduit":
			ok = _thunder(s, ctx)
		"lightning_verdict":
			ok = _verdict(s, ctx)
		"storm_arc":
			_storm_arc(s, ctx)
		"life_bloom":
			ok = _bloom(s, ctx)
		"verdant_renewal":
			ok = _verdant(s, ctx)
	if not ok:
		# nothing was cast (no valid target / no room): no mana spent
		Events.spell_interrupted.emit(hero, s.id, "no_target")
		return
	kit.mana -= cost
	if ctx.sanctum:
		sanctum.pulse(s.element)
	_recovery(s, full)
	last_release = {"spell": s.id, "full": full, "time": Game.time, "sanctum": ctx.sanctum}
	last_release.merge(release_info, true)
	Events.spell_released.emit(hero, s.id, s.element, full, held, cost)
	Events.spell_cast.emit(hero, s.id)


## Cast commitment through the AttackRunner (element-specific release + recovery animation), so
## dodge-cancel and buffering work like every other action. Heavy full releases briefly root.
func _recovery(s: ChargedSpellData, full: bool) -> void:
	var d := AttackData.new()
	d.id = "cast_" + s.id
	d.display_name = s.display_name
	d.anim_style = "cast_" + s.element
	d.startup = 0.03
	d.active = 0.05
	d.recovery = (s.recovery_full + s.root_on_full) if full else s.recovery_partial
	d.cancel_after = d.recovery * 0.6
	d.move_during = 0.0 if (full and s.root_on_full > 0.0) else 0.45
	d.hits = 0
	d.stamina_cost = 0.0
	d.add_tag("spell")
	kit.start_attack(d, {"elementalist": true})


# ------------------------------------------------------------------ aiming
func tip_pos() -> Vector3:
	return hero.global_position + Vector3(0, 1.45, 0) + hero.forward() * 0.6


func has_los(a: Vector3, b2: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b2, Combatant.LAYER_WORLD)
	return hero.get_world_3d().direct_space_state.intersect_ray(q).is_empty() and not SteamCloud.blocks(a, b2)


func visible(e) -> bool:
	return has_los(hero.global_position + Vector3(0, 1.45, 0), e.global_position + Vector3(0, 1.0, 0))


## Locked target if valid and visible; otherwise the best visible enemy in front (steam hides).
func target_enemy(max_range: float):
	var t = hero.lock_target
	if t != null and is_instance_valid(t) and t.is_targetable() and t.team != hero.team and t.global_position.distance_to(hero.global_position) <= max_range and visible(t):
		return t
	var fwd := aim_dir()
	var best = null
	var bs := INF
	for e in hero.enemies_within(max_range):
		var to: Vector3 = e.global_position - hero.global_position
		to.y = 0
		var d := to.length()
		var ang := rad_to_deg(fwd.angle_to(to.normalized())) if d > 0.1 else 0.0
		if ang > 50.0 or not visible(e):
			continue
		var sc := d + ang * 0.15
		if sc < bs:
			bs = sc
			best = e
	return best


func _camera() -> Camera3D:
	if not hero.is_player or not hero.is_inside_tree():
		return null
	return hero.get_viewport().get_camera_3d()


## Horizontal aim direction: lock target > camera forward (player) > facing.
func aim_dir() -> Vector3:
	var t = hero.lock_target
	if t != null and is_instance_valid(t) and t.is_targetable():
		var d: Vector3 = t.global_position - hero.global_position
		d.y = 0
		if d.length() > 0.1:
			return d.normalized()
	var cam := _camera()
	if cam:
		var f := -cam.global_transform.basis.z
		f.y = 0
		if f.length() > 0.05:
			return f.normalized()
	return hero.forward()


## Ground point under the camera centre (player), clamped to the spell's range.
func camera_ground(max_range: float, default_dist: float) -> Vector3:
	var me := hero.global_position
	var cam := _camera()
	var p := me + aim_dir() * default_dist
	if cam:
		var o := cam.global_position
		var d := -cam.global_transform.basis.z
		var q := PhysicsRayQueryParameters3D.create(o, o + d * 80.0, Combatant.LAYER_WORLD)
		var hit := hero.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			p = hit.position
		elif d.y < -0.02:
			p = o + d * ((me.y - o.y) / d.y)
	var off := p - me
	off.y = 0
	var dist := clampf(off.length(), 2.0, max_range)
	off = off.normalized() * dist if off.length() > 0.05 else aim_dir() * dist
	return Vector3(me.x + off.x, me.y, me.z + off.z)


## Placement for formation / location spells: {pos, axis (formation width direction), dir}.
func aim_info(s: ChargedSpellData) -> Dictionary:
	var me := hero.global_position
	var dir := aim_dir()
	var pos: Vector3
	if s.id == "stone_ward":
		pos = me + dir * 2.0
	elif ai_aim != null and not hero.is_player:
		pos = ai_aim
	else:
		var t = target_enemy(s.max_range)
		if t != null and s.id in ["crystal_formation", "frozen_bastion"]:
			# intercept: rise between the enemy and the Mage
			var to: Vector3 = t.global_position - me
			to.y = 0
			var d := to.length()
			pos = me + to.normalized() * clampf(d - 2.0, minf(2.5, d * 0.5), s.max_range)
		elif t != null:
			pos = t.global_position
		elif hero.is_player:
			pos = camera_ground(s.max_range, minf(7.0, s.max_range))
		else:
			pos = me + dir * minf(7.0, s.max_range)
	pos.y = me.y
	var line := pos - me
	line.y = 0
	if line.length() > 0.1:
		dir = line.normalized()
	return {"pos": pos, "axis": dir.cross(Vector3.UP).normalized(), "dir": dir}


func dmg_power(s: ChargedSpellData, full: bool) -> float:
	# STR scales CHARGED attack damage: applied to fully charged damage spells only
	return s.power_full * hero.stats.heavy_mult() if full else s.power_partial


## Earthbreaker / Rising Pillar displacement by enemy weight (light / medium / heavy; bosses resist).
func displace(e, from: Vector3, strength: float) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	var m: float = 0.0 if e.is_boss else float(WEIGHT_DISPLACE.get(e.weight_class, 0.4))
	if m <= 0.0:
		return
	var d: Vector3 = e.global_position - from
	d.y = 0
	if d.length() < 0.05:
		d = aim_dir()
	e.knock_velocity += d.normalized() * strength * m


# ------------------------------------------------------------------ formations
func solid_count() -> int:
	return formations.filter(func(f): return is_instance_valid(f) and not f.gone).size()


## Before a new solid formation: remove the oldest owned one so at most N exist (full cleanup).
func _make_room() -> void:
	formations = formations.filter(func(f): return is_instance_valid(f) and not f.gone)
	while formations.size() >= b().ww_max_solid_formations:
		var old = formations.pop_front()
		if is_instance_valid(old):
			old.destroy("limit")


func _register(f: WorldFormation) -> WorldFormation:
	formations.append(f)
	if f.element == "stone" and conductive_debug:
		f.set_state("conductive")
	return f


func ice_formations() -> Array:
	return WorldFormation.active().filter(func(f): return f.element == "frost")


## Crystal Chain / Sanctum Frost: the new ice formation connects to the nearest other OWN ice
## formation within range - ice sections fill the gap so both become one extended barrier.
func _connect_ice(f: WorldFormation, rng: float, source_id: String) -> int:
	var best = null
	var bd := rng
	var a_end := Vector3.ZERO
	var b_end := Vector3.ZERO
	for o in formations:
		if o == f or not is_instance_valid(o) or o.gone or o.element != "frost":
			continue
		for ca in f.centers():
			for cb in o.centers():
				var d: float = Vector2(ca.x - cb.x, ca.z - cb.z).length()
				if d < bd and d > 1.0:
					bd = d
					best = o
					a_end = ca
					b_end = cb
	if best == null:
		return 0
	var n := int(floor(bd / 0.8)) - 1
	var along: Vector3 = (b_end - a_end)
	along.y = 0
	var made := 0
	for k in n:
		var p: Vector3 = a_end.lerp(b_end, (k + 1) / float(n + 1))
		if _spot_free(p, 0.7):
			f.add_segment_at(p, along, 0.85, hero.weapon_power * 3.0)
			made += 1
	if made > 0:
		kit.trigger(source_id, "Connected two ice formations (+%d sections)" % made)
	return made


func _spot_free(pos: Vector3, r: float) -> bool:
	for g in ["enemies", "heroes"]:
		for c in Game.get_tree().get_nodes_in_group(g):
			if c is Combatant and not c.dead and Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length() < r:
				return false
	return true


# ------------------------------------------------------------------ interactions (spec 10)
func interaction(id: String, detail: String, pos: Vector3) -> void:
	interactions.append({"time": Game.time, "id": id, "detail": detail})
	if interactions.size() > 30:
		interactions.pop_front()
	Events.elemental_interaction.emit(hero, id, detail)
	Events.log_message.emit("%s: %s" % [id.replace("_", " ").capitalize(), detail], "fusion")
	var lbl := Label3D.new()
	lbl.text = id.replace("_", " ").to_upper()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 44
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.9, 0.6)
	if VFX._add(lbl, pos + Vector3(0, 2.4, 0)):
		var tw := lbl.create_tween()
		tw.tween_property(lbl, "position:y", lbl.position.y + 0.8, 0.9)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
		tw.tween_callback(lbl.queue_free)


## FIRE + FROST - Thermal Fracture. Fire contacting a Frost structure destroys the affected
## section(s). Partial Fire: short-range fragment burst. Full Fire: melts -> temporary steam cloud.
func thermal_fracture(f: WorldFormation, pos: Vector3, radius: float, full: bool) -> void:
	if _interaction_depth > 0 or not is_instance_valid(f) or f.gone or f.element != "frost":
		return
	var idx: Array = f.segments_within(pos, radius + 0.3)
	if idx.is_empty():
		return
	_interaction_depth += 1
	var centers: Array = []
	for i in idx:
		centers.append(f.seg_center(i))
	for i in idx:
		f.destroy_segment(i, "thermal_fracture")
	var c := Vector3.ZERO
	for p in centers:
		c += p
	c /= float(centers.size())
	if full:
		SteamCloud.spawn(hero, c)
		interaction("thermal_fracture", "Fire melted %d ice section(s) - steam cloud" % idx.size(), c)
	else:
		var hit := {}
		VFX.frost_burst(c, 1.8)
		for p in centers:
			for e in hero.enemies_within(2.2, p):
				if hit.has(e):
					continue
				hit[e] = true
				hero.spell_damage(e, 0.5, 10.0, "Thermal Fracture", {"pos": p, "knockback": 1.5, "tags": {"interaction": true}})
		interaction("thermal_fracture", "Fire shattered %d ice section(s), fragments hit %d" % [idx.size(), hit.size()], c)
	_interaction_depth -= 1


## STONE + FROST - Shattered Winter. A qualifying Stone impact damages (partial) or destroys (full)
## the struck ice and releases DIRECTIONAL fragments along the impact direction. Never re-triggers.
func shattered_winter(pos: Vector3, radius: float, travel: Vector3, full: bool) -> void:
	if _interaction_depth > 0:
		return
	_interaction_depth += 1
	travel.y = 0
	travel = travel.normalized() if travel.length() > 0.05 else aim_dir()
	for f in ice_formations():
		var idx: Array = f.segments_within(pos, radius + 0.4)
		if idx.is_empty():
			continue
		var broken := 0
		var origin := Vector3.ZERO
		for i in idx:
			origin += f.seg_center(i)
		origin /= float(idx.size())
		for i in idx:
			if full:
				f.destroy_segment(i, "shattered_winter")
				broken += 1
			elif f.damage_segment(i, f.segments[i].max_hp * 0.6, "shattered_winter"):
				broken += 1
		var hit := 0
		for e in hero.enemies_within(6.0, origin):
			var to: Vector3 = e.global_position - origin
			to.y = 0
			if to.length() < 0.2 or rad_to_deg(travel.angle_to(to.normalized())) <= 35.0:
				hit += 1
				hero.spell_damage(e, 0.7 if full else 0.45, 20.0 if full else 10.0, "Shattered Winter", {"pos": origin, "knockback": 2.0, "tags": {"interaction": true}})
				ElementalStates.apply_chill(e, hero, 1.5, 0.7)
		VFX.particles(origin + Vector3(0, 1.0, 0), VFX._quad(0.16), VFX._billboard(Color(0.85, 0.95, 1.0), 2.5), 18, 0.5,
			{"direction": travel, "spread": 30.0, "vmin": 8.0, "vmax": 14.0, "gravity": Vector3(0, -4, 0)})
		interaction("shattered_winter", "Stone struck ice (%d section(s) %s), fragments hit %d" % [idx.size(), "destroyed" if full else "damaged", hit], origin)
	_interaction_depth -= 1


## STORM + STONE - Conductive Anchors. A CONDUCTIVE Stone formation within reach relays the
## electrical path once per Storm cast (no loops).
func _anchor_near(pos: Vector3, rng: float, cast_id: int):
	var best = null
	var bd := rng
	for f in WorldFormation.active():
		if f.element != "stone" or not f.has_state("conductive") or int(f.relayed.get(cast_id, 0)) >= _anchor_relays(f):
			continue
		var d: float = f.distance_to(pos)
		if d <= bd:
			bd = d
			best = f
	return best


## LIFE + STONE - Living Bastion. A qualifying Life spell (full Life Bloom / full Verdant Renewal)
## landing on an ally next to a Fortified (defensive) Stone formation Vitalizes it.
func _living_bastion(target_pos: Vector3) -> void:
	if _interaction_depth > 0:
		return
	var enh: bool = kit.aug("living_bastion") > 0
	var reach := 3.0
	var radius: float = float(kit.ap("living_bastion", "radius", 4.5)) if enh else 3.0
	var dur: float = 6.0 * (float(kit.ap("living_bastion", "duration_mult", 1.5)) if enh else 1.0)
	for f in WorldFormation.active():
		if f.element != "stone" or not f.has_state("fortified") or f.mage != hero:
			continue
		if f.distance_to(target_pos) > reach + 1.0:
			continue
		f.vital_radius = radius
		f.set_state("vitalized", dur)
		f._vital_t = 0.0
		interaction("living_bastion", "%s Vitalized for %.0fs (recovery within %.1fm)" % [f.kind.capitalize(), dur, radius], f.global_position)
		if enh:
			kit.trigger("living_bastion", "Enhanced Vitalized formation")


# ------------------------------------------------------------------ FIRE
func _projectile_aim(s: ChargedSpellData) -> Vector3:
	var t = target_enemy(s.max_range)
	if t:
		return t.global_position + Vector3(0, 0.9, 0)
	return hero.global_position + aim_dir() * 14.0 + Vector3(0, 0.9, 0)


func _flame(s: ChargedSpellData, ctx: Dictionary) -> void:
	var full: bool = ctx.full
	var h = hero
	var from := tip_pos()
	var aim := _projectile_aim(s)
	var spd := s.speed_full if full else s.speed_partial
	var power := dmg_power(s, full)
	var r := s.radius_full if full else s.radius_partial
	var poise := s.poise_full if full else s.poise_partial
	var label := s.display_name + (" (full)" if full else "")
	var cb := func(_hit, pos):
		if is_instance_valid(h):
			_fire_impact(s, pos, full, power, r, poise, label, ctx)
	Projectile.spawn(hero, from, aim - from, spd, 0.5 if full else 0.28, COLORS.fire, cb, s.max_range / spd + 0.3, hero.weapon_power * power)


func _fire_impact(s: ChargedSpellData, pos: Vector3, full: bool, power: float, r: float, poise: float, label: String, ctx: Dictionary) -> void:
	var ground := Vector3(pos.x, hero.global_position.y, pos.z)
	VFX.fire_burst(pos, r)
	for e in hero.enemies_within(r, ground):
		hero.spell_damage(e, power, poise, label, {"pos": ground, "knockback": 3.5 if full else 1.0, "hitstop": 0.08 if full else 0.04})
	for f in ice_formations():
		thermal_fracture(f, ground, r * 0.6, full)
	if not full:
		return
	if kit.aug("infernal_collapse") > 0:
		var delay := float(kit.ap("infernal_collapse", "delay", 1.0))
		var cr := float(kit.ap("infernal_collapse", "radius", 3.0))
		var cp := float(kit.ap("infernal_collapse", "power", 1.5))
		Telegraph.circle(ground, cr, delay, Color(1.0, 0.5, 0.15, 0.55))
		var h = hero
		kit.schedule(delay, func():
			if not is_instance_valid(h):
				return
			VFX.fire_burst(ground, cr * 1.1)
			var n := 0
			for e in h.enemies_within(cr, ground):
				h.spell_damage(e, cp, 40.0, "Infernal Collapse", {"pos": ground, "knockback": 5.0, "hitstop": 0.1})
				n += 1
			kit.trigger("infernal_collapse", "Secondary explosion hit %d" % n))
	else:
		_burn_zone(s, ground, s.width_full, s.duration_full)
	if ctx.sanctum:
		_sanctum_fire_wave(ground, float(ctx.mult))


## Arcane Sanctum + Fire: an eligible charged Fire impact produces a secondary flame wave.
func _sanctum_fire_wave(ground: Vector3, m: float) -> void:
	var h = hero
	kit.schedule(0.35, func():
		if not is_instance_valid(h):
			return
		VFX.ground_ring(ground, 5.0 * m, Color(1.0, 0.5, 0.15), 0.45)
		VFX.particles(ground + Vector3(0, 0.3, 0), VFX._quad(0.3), VFX._billboard(Color(1.0, 0.55, 0.2), 3.0), 24, 0.6,
			{"shape": CPUParticles3D.EMISSION_SHAPE_RING, "ring_radius": 4.0 * m, "vmin": 1.0, "vmax": 3.0, "gravity": Vector3(0, 2, 0)})
		var n := 0
		for e in h.enemies_within(5.0 * m, ground):
			h.spell_damage(e, 0.8 * m, 20.0, "Sanctum Flame Wave", {"pos": ground, "knockback": 4.0})
			n += 1
		kit.trigger("sanctum_fire", "Secondary flame wave hit %d" % n))


## Burning area: damage every interval (1s); each enemy at most once per interval per Mage,
## whatever the number of overlapping areas or collision events. Max 2 areas (oldest goes out).
func _burn_zone(s: ChargedSpellData, pos: Vector3, radius: float, duration: float) -> void:
	while fire_zones.size() >= b().ww_max_fire_areas:
		var old = fire_zones.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var h = hero
	var pw := s.status_power
	var interval := b().ww_fire_area_interval
	var key := "burn_area_t_%d" % hero.get_instance_id()
	var cb := func(zz):
		if not is_instance_valid(h):
			return
		for e in zz.enemies_of_source():
			if float(e.get_meta(key, -10.0)) > Game.time - interval * 0.9:
				continue
			e.set_meta(key, Game.time)
			h.spell_damage(e, pw * h.stats.effect_power(), 2.0, "Burning Area", {"hitstop": 0.0, "knockback": 0.0, "tags": {"dot_zone": true}})
			ElementalStates.apply_burning(e, h, interval + 0.1, 0.0)
	var z := GroundZone.spawn(hero, pos, radius, duration, Color(1.0, 0.4, 0.1), interval, cb)
	z.set_meta("ww_fire_area", true)
	fire_zones.append(z)


func _inferno(s: ChargedSpellData, ctx: Dictionary) -> void:
	var full: bool = ctx.full
	var dir := aim_dir()
	var from := hero.global_position + dir * 1.2
	var spd := s.speed_full if full else s.speed_partial
	var life := s.duration_full if full else s.duration_partial
	FireWave.launch(self, from, dir, spd, s.radius_full if full else s.radius_partial, life, dmg_power(s, full),
		s.poise_full if full else s.poise_partial, s.status_power, full, s.display_name + (" (full)" if full else ""))
	VFX.fire_burst(from, 1.0)
	if ctx.sanctum and full:
		_sanctum_fire_wave(hero.global_position + dir * spd * life, float(ctx.mult))


func _cinderfall(s: ChargedSpellData, ctx: Dictionary) -> void:
	var full: bool = ctx.full
	var point: Vector3 = aim_info(s).pos
	var r := s.radius_full if full else s.radius_partial
	var delay := s.duration_full if full else s.duration_partial
	var power := dmg_power(s, full)
	var poise := s.poise_full if full else s.poise_partial
	Telegraph.circle(point, r, delay, Color(1.0, 0.45, 0.1, 0.6))
	_falling_rock(point, delay, Color(1.0, 0.45, 0.15), 0.7)
	var h = hero
	var sanct: bool = ctx.sanctum
	var m: float = ctx.mult
	kit.schedule(delay, func():
		if not is_instance_valid(h):
			return
		VFX.fire_burst(point + Vector3(0, 0.3, 0), r)
		for e in h.enemies_within(r, point):
			h.spell_damage(e, power, poise, "Cinderfall" + (" (full)" if full else ""), {"pos": point, "knockback": 3.0, "hitstop": 0.08})
			ElementalStates.apply_burning(e, h, 2.0, 0.2)
		for f in ice_formations():
			thermal_fracture(f, point, r * 0.7, full)
		if sanct and full:
			_sanctum_fire_wave(point, m))


# ------------------------------------------------------------------ FROST
func _chill_release(center: Vector3, r: float, slow: float, dur: float, power: float, poise: float, label: String) -> int:
	var n := 0
	for e in hero.enemies_within(r, center):
		if power > 0.0:
			hero.spell_damage(e, power, poise, label, {"pos": center, "knockback": 0.5})
		ElementalStates.apply_chill(e, hero, dur, slow)
		n += 1
	return n


func _crystal(s: ChargedSpellData, ctx: Dictionary) -> bool:
	var full: bool = ctx.full
	var ai := aim_info(s)
	var point: Vector3 = ai.pos
	var width := s.width_full if full else s.width_partial
	_make_room()
	var f := WorldFormation.spawn(hero, "crystal", "frost", point, ai.axis, width, 2.2 if full else 1.8, 0.9, s.duration_full if full else s.duration_partial, hero.weapon_power * 3.0)
	# never trap anyone inside the ice: sections overlapping a body are removed, enemies shoved out
	for i in f.segments.size():
		var c := f.seg_center(i)
		if not _spot_free(c, 0.75):
			for e in hero.enemies_within(1.0, c):
				displace(e, c, 4.0)
			f.destroy_segment(i, "occupied")
	if f.gone:
		return true
	_register(f)
	var slow := 1.0 - s.status_power
	VFX.frost_burst(point, width * 0.4)
	if full:
		_chill_release(point, s.radius_full, slow, 2.5, s.power_full, s.poise_full, s.display_name + " (full)")
	else:
		_chill_release(point, s.radius_partial, lerpf(1.0, slow, 0.6), 1.5, s.power_partial, s.poise_partial, s.display_name)
	if ctx.sanctum:
		if _connect_ice(f, 8.0 * float(ctx.mult), "sanctum_frost") == 0:
			kit.trigger("sanctum_frost", "No other ice formation in reach to connect")
	elif kit.aug("crystal_chain") > 0:
		_connect_ice(f, float(kit.ap("crystal_chain", "link_range", 8.0)), "crystal_chain")
	return true


func _spear(s: ChargedSpellData, ctx: Dictionary) -> void:
	var full: bool = ctx.full
	var h = hero
	var from := tip_pos()
	var aim := _projectile_aim(s)
	var power := dmg_power(s, full)
	var poise := s.poise_full if full else s.poise_partial
	var dur := s.duration_full if full else s.duration_partial
	var slow := 1.0 - s.status_power
	var cb := func(hit, pos):
		if not is_instance_valid(h):
			return
		VFX.frost_burst(pos, 0.6)
		if hit != null and is_instance_valid(hit):
			h.spell_damage(hit, power, poise, "Glacial Spear" + (" (full)" if full else ""), {"pos": pos, "knockback": 1.5, "hitstop": 0.06})
			ElementalStates.apply_chill(hit, h, dur, slow)
	Projectile.spawn(hero, from, aim - from, s.speed_full, 0.3, Color(0.65, 0.9, 1.0), cb, s.max_range / s.speed_full + 0.3, hero.weapon_power * power)


# ------------------------------------------------------------------ STONE
func _earth(s: ChargedSpellData, ctx: Dictionary) -> void:
	var full: bool = ctx.full
	var power := dmg_power(s, full)
	var poise := s.poise_full if full else s.poise_partial
	var h = hero
	if full and kit.aug("mountainfall") > 0:
		var point: Vector3 = aim_info(s).pos
		var delay := float(kit.ap("mountainfall", "delay", 1.0))
		var r := float(kit.ap("mountainfall", "radius", 3.6))
		var pm := float(kit.ap("mountainfall", "poise_mult", 1.6))
		var travel := point - hero.global_position
		Telegraph.circle(point, r, delay, Color(0.85, 0.65, 0.35, 0.6))
		_falling_rock(point, delay, Color(0.5, 0.42, 0.34), 1.1)
		kit.schedule(delay, func():
			if not is_instance_valid(h):
				return
			_stone_impact(point, null, true, power, poise * pm, r, ctx, "Mountainfall", travel)
			kit.trigger("mountainfall", "Overhead impact"))
		return
	var from := tip_pos()
	var aim := _projectile_aim(s)
	var spd := s.speed_full if full else s.speed_partial
	var r2 := s.radius_full if full else 0.0
	var travel2 := aim - from
	var cb := func(hit, pos):
		if is_instance_valid(h):
			_stone_impact(Vector3(pos.x, h.global_position.y, pos.z), hit, full, power, poise, r2, ctx, s.display_name + (" (full)" if full else ""), travel2)
	Projectile.spawn(hero, from, aim - from, spd, 0.55 if full else 0.3, COLORS.stone, cb, s.max_range / spd + 0.3, hero.weapon_power * power)


func _falling_rock(point: Vector3, delay: float, color: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 1.8
	sm.radial_segments = 8
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = CharModel.toon(color, 1.2 if color.r > 0.9 else 0.0)
	Game.fx_root().add_child(mi)
	mi.global_position = point + Vector3(0, 14, 0)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", point + Vector3(0, 0.6, 0), delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


func _stone_impact(pos: Vector3, hit, full: bool, power: float, poise: float, radius: float, ctx: Dictionary, label: String, travel: Vector3) -> void:
	VFX.stone_burst(pos, maxf(0.8, radius))
	var targets: Array = []
	if radius > 0.0:
		targets = hero.enemies_within(radius, pos)
	elif hit != null and is_instance_valid(hit):
		targets = [hit]
	else:
		targets = hero.enemies_within(1.0, pos)
	for e in targets:
		# Magic damage; the weight pushes through frontal guards (Shield Guardian). Poise always applies.
		hero.spell_damage(e, power, poise, label, {"pos": pos, "guard_break": true, "knockback": 0.0, "hitstop": 0.14 if full else 0.08})
		displace(e, pos - travel.normalized() * 0.5, 7.0 if full else 3.5)
	shattered_winter(pos, maxf(radius, 1.0), travel, full)
	# Arcane Sanctum + Stone: a qualifying impact raises a small temporary defensive formation
	if ctx.sanctum and (full or targets.size() > 0):
		var to_mage: Vector3 = hero.global_position - pos
		to_mage.y = 0
		var wall_pos := pos + to_mage.normalized() * minf(2.2, to_mage.length() * 0.5)
		if _spot_free(wall_pos, 0.9):
			_make_room()
			var g := WorldFormation.spawn(hero, "sanctum_guard", "stone", wall_pos, to_mage.cross(Vector3.UP), 2.0, 1.6, 0.8, 5.0 * float(ctx.mult), hero.weapon_power * 3.0, 1.0)
			g.set_state("fortified")
			_register(g)
			kit.trigger("sanctum_stone", "Small defensive stone formation raised")


func _pillar_point(p: Vector3) -> Vector3:
	var me := hero.global_position
	for k in 5:
		var q := p.lerp(me, k * 0.12)
		var blocked := false
		for e in hero.enemies_within(1.1, q):
			if e.is_boss or e.weight_class == "heavy":
				blocked = true
		if not blocked and _spot_free_heroes(q, 1.0):
			return q
	return Vector3.INF


func _spot_free_heroes(pos: Vector3, r: float) -> bool:
	for c in hero.allies(true):
		if Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length() < r:
			return false
	return true


# ------------------------------------------------------------------ STORM
func _thunder(s: ChargedSpellData, ctx: Dictionary) -> bool:
	var full: bool = ctx.full
	var from := tip_pos()
	var t = target_enemy(s.max_range)
	if t == null:
		VFX.lightning(from, hero.global_position + aim_dir() * 8.0 + Vector3(0, 0.5, 0))
		if hero.is_player:
			Events.notify.emit("No visible target")
		return false
	var power := dmg_power(s, full)
	var poise := s.poise_full if full else s.poise_partial
	var jumps := s.chains_full if full else s.chains_partial
	if ctx.sanctum and full:
		jumps += 1
		kit.trigger("sanctum_storm", "One additional relay")
	VFX.lightning(from, t.global_position + Vector3(0, 1.0, 0))
	VFX.lightning(t.global_position + Vector3(0, 10, 0), t.global_position + Vector3(0, 1.0, 0))
	var hit: Array = [t]
	hero.spell_damage(t, power, poise, s.display_name + (" (full)" if full else ""), {"hitstop": 0.06})
	var cur_pos: Vector3 = t.global_position
	var path: Array = [hero.global_position, t.global_position]
	if full:
		_establish_conductive(path)
	var dmg := power
	for i in jumps:
		var nxt = _next_chain(cur_pos, hit, s.chain_range)
		if nxt == null:
			var anchor = _anchor_near(cur_pos, s.chain_range, ctx.cast)
			if anchor != null:
				anchor.relayed[ctx.cast] = int(anchor.relayed.get(ctx.cast, 0)) + 1
				if anchor.relayed[ctx.cast] > 1:
					kit.trigger("storm_lattice", "Anchor relayed a second time")
				var ap: Vector3 = anchor.global_position + Vector3(0, 1.4, 0)
				VFX.lightning(cur_pos + Vector3(0, 1.0, 0), ap)
				cur_pos = anchor.global_position
				nxt = _next_chain(cur_pos, hit, s.chain_range)
				interaction("conductive_anchors", "Thunder Conduit relayed through a conductive %s%s" % [anchor.kind, "" if nxt == null else " to " + nxt.display_name], anchor.global_position)
		if nxt == null:
			break
		dmg *= s.chain_falloff
		if full:
			_establish_conductive([cur_pos, nxt.global_position])
		VFX.lightning(cur_pos + Vector3(0, 1.0, 0), nxt.global_position + Vector3(0, 1.0, 0))
		# DEX: chain jumps are the multi-hit part of the spell
		hero.spell_damage(nxt, dmg * hero.stats.multihit_mult(), poise * 0.6, s.display_name + " (chain)", {"hitstop": 0.03})
		hit.append(nxt)
		cur_pos = nxt.global_position
	if full and kit.aug("living_thunder") > 0:
		var extra = _aimed_enemy(float(kit.ap("living_thunder", "range", 15.0)), hit)
		if extra != null:
			VFX.lightning(cur_pos + Vector3(0, 1.0, 0), extra.global_position + Vector3(0, 1.0, 0), Color(0.6, 1.0, 0.9))
			hero.spell_damage(extra, dmg * s.chain_falloff, poise * 0.6, "Living Thunder")
			hit.append(extra)
			kit.trigger("living_thunder", "Directed chain to %s" % extra.display_name)
	release_info["targets"] = hit.size()
	return true


## Natural Conductive Anchors (refoundation spec 6): a FULL Thunder Conduit whose strike or chain
## path contacts a Stone formation makes it Conductive for 6s (Storm Lattice: longer).
## "Contact" (engineering interpretation, reported): a struck point within 3m of the formation, or
## a chain segment passing within 1.5m of it.
func _establish_conductive(points: Array) -> void:
	var dur := 6.0 * (float(kit.ap("storm_lattice", "duration_mult", 1.5)) if kit.aug("storm_lattice") > 0 else 1.0)
	for f in WorldFormation.active():
		if f.element != "stone" or f.has_state("conductive"):
			continue
		var touched := false
		for i in points.size():
			if f.distance_to(points[i]) <= 3.0:
				touched = true
			if i > 0:
				var a: Vector3 = points[i - 1]
				var bb: Vector3 = points[i]
				var ab := bb - a
				ab.y = 0
				var c: Vector3 = f.global_position - a
				c.y = 0
				var tt := clampf(c.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				if f.distance_to(a + ab * tt) <= 1.5:
					touched = true
			if touched:
				break
		if touched:
			f.set_state("conductive", dur)
			interaction("conductive_route", "Thunder Conduit made a %s conductive for %.0fs" % [f.kind, dur], f.global_position)


func _anchor_relays(_f) -> int:
	return 1 + (int(kit.ap("storm_lattice", "extra_relays", 1)) if kit.aug("storm_lattice") > 0 else 0)


func _next_chain(from: Vector3, hit: Array, rng: float):
	var best = null
	var bd := rng
	for e in Game.get_tree().get_nodes_in_group("enemies"):
		if not (e is Combatant) or not e.is_targetable() or hit.has(e):
			continue
		var d: float = e.global_position.distance_to(from)
		if d <= bd and has_los(from + Vector3(0, 1.0, 0), e.global_position + Vector3(0, 1.0, 0)):
			bd = d
			best = e
	return best


## Enemy closest to the screen centre (player) / to the facing direction (AI).
func _aimed_enemy(rng: float, exclude: Array):
	var cam := _camera()
	var best = null
	var bs := INF
	for e in hero.enemies_within(rng):
		if exclude.has(e) or not visible(e):
			continue
		var score: float
		if cam != null and not cam.is_position_behind(e.global_position):
			var sp := cam.unproject_position(e.global_position + Vector3(0, 1.0, 0))
			score = sp.distance_to(hero.get_viewport().get_visible_rect().size * 0.5)
		else:
			var d: Vector3 = e.global_position - hero.global_position
			score = hero.forward().angle_to(d.normalized()) * 1000.0
		if score < bs:
			bs = score
			best = e
	return best


## Lightning Verdict: cancels an ELIGIBLE preparation only - the attack must expose an interruptible
## window (AttackData.interruptible, STARTUP phase). Bosses resist. No universal interrupt.
func _verdict(s: ChargedSpellData, ctx: Dictionary) -> bool:
	var full: bool = ctx.full
	var t = target_enemy(s.max_range)
	if t == null:
		if hero.is_player:
			Events.notify.emit("No visible target")
		return false
	VFX.lightning(t.global_position + Vector3(0, 12, 0), t.global_position + Vector3(0, 1.0, 0), Color(0.9, 0.85, 1.0))
	VFX.lightning(tip_pos(), t.global_position + Vector3(0, 1.0, 0))
	hero.spell_damage(t, dmg_power(s, full), s.poise_full if full else s.poise_partial, s.display_name + (" (full)" if full else ""), {"hitstop": 0.07})
	var r = t.runner
	var preparing: bool = r.is_busy() and r.phase == AttackRunner.Phase.STARTUP and r.data != null
	if preparing and r.data.interruptible and not t.is_boss and not t.dead:
		t.stagger(0.6)
		FX.number(t, "INTERRUPTED", Color(0.8, 0.7, 1.0), 0.9)
		Events.combat_notice.emit("INTERRUPTED", t)
		kit.trigger("verdict_interrupt", "Interrupted %s (%s)" % [t.display_name, r.data.display_name])
		release_info["interrupted"] = true
	elif preparing:
		FX.number(t, "RESISTED" if t.is_boss else "NOT INTERRUPTIBLE", Color(0.75, 0.75, 0.8), 0.7)
		release_info["interrupted"] = false
	return true


## Storm Arc: electricity along the aimed route. Enemies on the route are hit once. A conductive
## anchor near the route relays it (once per anchor per cast) to an enemy within jump range.
func _storm_arc(s: ChargedSpellData, ctx: Dictionary) -> void:
	var full: bool = ctx.full
	var dir := aim_dir()
	var start := hero.global_position
	var length := s.radius_full if full else s.radius_partial
	var q := PhysicsRayQueryParameters3D.create(start + Vector3(0, 1.0, 0), start + Vector3(0, 1.0, 0) + dir * length, Combatant.LAYER_WORLD)
	var wh := hero.get_world_3d().direct_space_state.intersect_ray(q)
	if not wh.is_empty():
		length = Vector2(wh.position.x - start.x, wh.position.z - start.z).length()
	var end := start + dir * length
	var power := dmg_power(s, full)
	var poise := s.poise_full if full else s.poise_partial
	var hw := s.width_full * 0.5
	var hit: Array = []
	var pts: Array = [start + Vector3(0, 1.0, 0)]
	var n := maxi(2, int(length / 2.0))
	for k in n:
		pts.append(start.lerp(end, (k + 1) / float(n)) + Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)))
	for k in pts.size() - 1:
		VFX.lightning(pts[k], pts[k + 1])
	for e in hero.enemies_within(length + 1.0):
		var rel: Vector3 = e.global_position - start
		rel.y = 0
		var along := rel.dot(dir)
		if along < 0.0 or along > length:
			continue
		if (rel - dir * along).length() <= hw + 0.4:
			hit.append(e)
			hero.spell_damage(e, power, poise, s.display_name + (" (full)" if full else ""), {"hitstop": 0.03})
	var relays := 0
	for f in WorldFormation.active():
		if f.element != "stone" or not f.has_state("conductive") or int(f.relayed.get(ctx.cast, 0)) >= 1:
			continue
		var c: Vector3 = f.global_position - start
		c.y = 0
		var al := clampf(c.dot(dir), 0.0, length)
		if f.distance_to(start + dir * al) > 1.5 + hw:
			continue
		f.relayed[ctx.cast] = 1
		var nxt = _next_chain(f.global_position, hit, s.chain_range)
		relays += 1
		if nxt != null:
			VFX.lightning(f.global_position + Vector3(0, 1.4, 0), nxt.global_position + Vector3(0, 1.0, 0))
			hero.spell_damage(nxt, power * 0.8, poise, "Storm Arc (relay)", {"hitstop": 0.03})
			hit.append(nxt)
		interaction("conductive_anchors", "Storm Arc relayed through a conductive %s%s" % [f.kind, "" if nxt == null else " to " + nxt.display_name], f.global_position)
	if ctx.sanctum:
		var extra = _next_chain(end, hit, s.chain_range)
		if extra != null:
			VFX.lightning(end + Vector3(0, 1.0, 0), extra.global_position + Vector3(0, 1.0, 0))
			hero.spell_damage(extra, power * 0.8, poise, "Storm Arc (sanctum relay)", {"hitstop": 0.03})
			hit.append(extra)
		kit.trigger("sanctum_storm", "One additional relay")
	release_info["targets"] = hit.size()


# ------------------------------------------------------------------ LIFE
func current_heal_target():
	if heal_target != null and is_instance_valid(heal_target) and not heal_target.dead:
		if heal_target.global_position.distance_to(hero.global_position) <= b().ww_heal_range:
			return heal_target
		return null          # explicit target out of range: never silently redirected
	return hero


func heal_target_in_range() -> bool:
	return current_heal_target() != null


func set_heal_target(t) -> void:
	heal_target = t
	if hero.is_player and t != null:
		Events.notify.emit("Heal target: " + ("yourself" if t == hero else t.display_name))


func cycle_heal_target() -> void:
	var party: Array = hero.allies(true)
	if party.is_empty():
		return
	var cur_t = heal_target if heal_target != null else hero
	var i := party.find(cur_t)
	set_heal_target(party[(i + 1) % party.size()])


func select_injured() -> void:
	var best = null
	var br := 1.0
	for a in hero.allies(true):
		if a.global_position.distance_to(hero.global_position) <= b().ww_heal_range and a.hp / a.max_hp < br:
			br = a.hp / a.max_hp
			best = a
	if best == null:
		if hero.is_player:
			Events.notify.emit("Everyone is at full health")
		return
	set_heal_target(best)


func _heal(t, amount: float, label: String) -> void:
	kit.heal_target(t, amount, label)


func _bloom(s: ChargedSpellData, ctx: Dictionary) -> bool:
	var full: bool = ctx.full
	var t = current_heal_target()
	if t == null:
		if hero.is_player:
			Events.notify.emit("Heal target out of range")
		return false
	var amount := hero.weapon_power * (s.power_full if full else s.power_partial)
	var label := s.display_name + (" (full)" if full else "")
	var recipients: Array = [t]
	var each := amount
	if bloom_shared():
		for a in hero.allies(true):
			if a != t and not a.dead and a.global_position.distance_to(t.global_position) <= 8.0 and recipients.size() < 4:
				recipients.append(a)
		each = amount * s.status_power
		label = "Shared Bloom" + (" (full)" if full else "")
	for r in recipients:
		FX.beam(tip_pos(), r.global_position + Vector3(0, 1.0, 0), COLORS.life)
		VFX.life_bloom(r.global_position, 1.2 if full else 0.8)
		var direct := each
		if kit.aug("everlasting_bloom") > 0:
			var conv := float(kit.ap("everlasting_bloom", "convert", 0.35))
			var dur := float(kit.ap("everlasting_bloom", "duration", 6.0))
			var hot := StatusEffect.make("everlasting_bloom", "Everlasting Bloom", "hot", dur, {}, each * conv / dur, 1.0)
			hot.source = hero
			r.statuses.add(hot.scaled_by(hero.stats.effect_power()))
			direct = each * (1.0 - conv)
			kit.trigger("everlasting_bloom", "%d of the heal -> HoT on %s" % [roundi(each * conv), r.display_name])
		_heal(r, direct, label)
	if ctx.sanctum:
		_sanctum_life(t, amount * 0.35 * float(ctx.mult), recipients, false)
	if full:
		_living_bastion(t.global_position)
	release_info["recipients"] = recipients.size()
	return true


## Arcane Sanctum + Life: part of the charged healing reaches ONE additional valid ally.
func _sanctum_life(t, amount: float, exclude: Array, as_hot: bool) -> void:
	var best = null
	var br := 1.01
	for a in hero.allies(true):
		if exclude.has(a) or a.dead or a.hp >= a.max_hp:
			continue
		if a.global_position.distance_to(t.global_position) > 15.0:
			continue
		if a.hp / a.max_hp < br:
			br = a.hp / a.max_hp
			best = a
	if best == null:
		kit.trigger("sanctum_life", "No other injured ally in reach")
		return
	FX.beam(t.global_position + Vector3(0, 1.0, 0), best.global_position + Vector3(0, 1.0, 0), Color(0.7, 1.0, 0.75))
	if as_hot:
		var hot := StatusEffect.make("sanctum_renewal", "Sanctum Renewal", "hot", 6.0, {}, amount / 6.0, 1.0)
		hot.source = hero
		best.statuses.add(hot.scaled_by(hero.stats.effect_power()))
	else:
		_heal(best, amount, "Sanctum Grace")
	kit.trigger("sanctum_life", "Healing reached %s" % best.display_name)


func _verdant(s: ChargedSpellData, ctx: Dictionary) -> bool:
	var full: bool = ctx.full
	var t = current_heal_target()
	if t == null:
		if hero.is_player:
			Events.notify.emit("Heal target out of range")
		return false
	var dur := s.duration_full if full else s.duration_partial
	var total := hero.weapon_power * (s.power_full if full else s.power_partial)
	var hot := StatusEffect.make("verdant_renewal", "Verdant Renewal", "hot", dur, {}, total / dur, 1.0)
	hot.source = hero
	t.statuses.add(hot.scaled_by(hero.stats.effect_power()))
	FX.beam(tip_pos(), t.global_position + Vector3(0, 1.0, 0), COLORS.life)
	VFX.ground_ring(t.global_position, 1.2, COLORS.life, 0.6)
	if ctx.sanctum:
		_sanctum_life(t, total * 0.35 * float(ctx.mult), [t], true)
	if full:
		_living_bastion(t.global_position)
	return true


func lifeline() -> bool:
	var s: ChargedSpellData = spells.lifeline
	if kit.cd("lifeline") > 0.0:
		return false
	if not hero.can_act() and cur == null:
		hero.buffer("life")
		return false
	if kit.mana < s.mana_partial:
		if hero.is_player:
			Events.notify.emit("Not enough mana for Lifeline")
		return false
	var t = current_heal_target()
	if t == null:
		if hero.is_player:
			Events.notify.emit("Heal target out of range")
		return false
	if cur != null:
		cancel("lifeline")
	kit.mana -= s.mana_partial
	kit.set_cd("lifeline", s.cooldown)
	FX.beam(tip_pos(), t.global_position + Vector3(0, 1.0, 0), COLORS.life)
	_heal(t, hero.weapon_power * s.power_partial, "Lifeline")
	_recovery(s, false)
	Events.spell_released.emit(hero, s.id, "life", false, 0.0, s.mana_partial)
	return true


# ------------------------------------------------------------------ UTILITY slot (key 3)
func press_utility() -> void:
	var u := utility_spell()
	if u == "":
		if hero.is_player:
			if prog().spell_loadout.size() > UTIL_SLOT and String(prog().spell_loadout[UTIL_SLOT]) != "":
				kit.locked_msg("m_renewal")
			else:
				Events.notify.emit("No utility spell equipped  -  Spellbook (B)")
		return
	if spells[u].places_formation and hero.is_player and hero.is_held("skill3") and cur == null:
		util_aiming = u        # hold to aim (placement preview), release to cast
		return
	cast_utility(u)


func cast_utility(id: String) -> bool:
	if not spell_known(id):
		return false
	var s: ChargedSpellData = spells[id]
	if kit.cd(id) > 0.0:
		if hero.is_player:
			Events.notify.emit("%s on cooldown (%.1fs)" % [s.display_name, kit.cd(id)])
		return false
	if not hero.can_act() and cur == null:
		return false
	if kit.mana < s.mana_partial:
		if hero.is_player:
			Events.notify.emit("Not enough mana for " + s.display_name)
		return false
	var ok := false
	match id:
		"protective_renewal":
			ok = _renewal(s)
		"frozen_bastion":
			ok = _bastion(s)
		"rising_pillar":
			ok = _pillar(s)
		"stone_ward":
			ok = _ward(s)
	if not ok:
		return false
	if cur != null:
		cancel(id)
	kit.mana -= s.mana_partial
	kit.set_cd(id, s.cooldown)
	_recovery(s, false)
	last_release = {"spell": id, "full": false, "time": Game.time, "sanctum": in_sanctum()}
	Events.spell_released.emit(hero, id, s.element, false, 0.0, s.mana_partial)
	return true


## kept for callers / tests from the previous build
func renewal() -> bool:
	if not spell_known("protective_renewal"):
		kit.locked_msg("m_renewal")
		return false
	return cast_utility("protective_renewal")


func _renewal(s: ChargedSpellData) -> bool:
	var t = current_heal_target()
	if t == null:
		if hero.is_player:
			Events.notify.emit("Heal target out of range")
		return false
	t.add_shield(hero.weapon_power * s.power_partial * hero.stats.effect_power(), s.duration_partial, hero)
	var st := StatusEffect.make("protective_renewal", "Protective Renewal", "buff", s.duration_partial, {})
	st.source = hero
	t.statuses.add(st)
	FX.beam(tip_pos(), t.global_position + Vector3(0, 1.0, 0), Color(0.75, 1.0, 0.85))
	VFX.ground_ring(t.global_position, 1.3, Color(0.75, 1.0, 0.85), 0.5)
	Events.combat_notice.emit("PROTECTED", t)
	return true


func _bastion(s: ChargedSpellData) -> bool:
	var ai := aim_info(s)
	_make_room()
	var f := WorldFormation.spawn(hero, "bastion", "frost", ai.pos, ai.axis, s.width_partial, 2.6, 1.0, s.duration_partial, hero.weapon_power * 3.5)
	for i in f.segments.size():
		var c := f.seg_center(i)
		if not _spot_free(c, 0.75):
			for e in hero.enemies_within(1.0, c):
				displace(e, c, 4.0)
			f.destroy_segment(i, "occupied")
	if not f.gone:
		_register(f)
		VFX.frost_burst(ai.pos, 1.5)
		if kit.aug("crystal_chain") > 0:
			_connect_ice(f, float(kit.ap("crystal_chain", "link_range", 8.0)), "crystal_chain")
	return true


func _pillar(s: ChargedSpellData) -> bool:
	var ai := aim_info(s)
	var p := _pillar_point(ai.pos)
	if p == Vector3.INF:
		if hero.is_player:
			Events.notify.emit("No room for the pillar there")
		return false
	_make_room()
	for e in hero.enemies_within(s.radius_partial, p):
		hero.spell_damage(e, 0.3, s.poise_partial, s.display_name, {"pos": p, "knockback": 0.0})
		displace(e, p, 6.0)
	var f := WorldFormation.spawn(hero, "pillar", "stone", p, ai.axis, s.width_partial, 3.0, 1.4, s.duration_partial, hero.weapon_power * 8.0, 2.0)
	f.set_state("fortified")
	_register(f)
	VFX.stone_burst(p, 1.4)
	return true


func _ward(s: ChargedSpellData) -> bool:
	var ai := aim_info(s)
	if not _spot_free(ai.pos, 0.6):
		ai.pos = hero.global_position + ai.dir * 2.8
	_make_room()
	var f := WorldFormation.spawn(hero, "ward", "stone", ai.pos, ai.axis, s.width_partial, 2.0, 0.8, s.duration_partial, hero.weapon_power * 4.0, 0.9)
	f.set_state("fortified")
	_register(f)
	VFX.stone_burst(ai.pos, 1.2)
	return true


# ------------------------------------------------------------------ ARCANE SANCTUM
func cast_sanctum() -> bool:
	if not kit.unlocked("m_sanctum"):
		kit.locked_msg("m_sanctum")
		return false
	if kit.cd("sanctum") > 0.0 or not hero.can_act() or cur != null:
		return false
	if kit.mana < b().ww_sanctum_mana:
		if hero.is_player:
			Events.notify.emit("Not enough mana for Arcane Sanctum")
		return false
	kit.mana -= b().ww_sanctum_mana
	kit.set_cd("sanctum", b().ww_sanctum_cooldown)
	if sanctum != null and is_instance_valid(sanctum):
		sanctum.queue_free()
	sanctum = ArcaneSanctum.summon(hero, b().ww_sanctum_radius, b().ww_sanctum_duration, kit.aug("wandering_sanctum") > 0)
	var d := AttackData.new()
	d.id = "cast_sanctum"
	d.display_name = "Arcane Sanctum"
	d.anim_style = "cast_life"
	d.startup = 0.03
	d.active = 0.05
	d.recovery = 0.3
	d.cancel_after = 0.15
	d.hits = 0
	d.stamina_cost = 0.0
	d.add_tag("spell")
	kit.start_attack(d, {"elementalist": true})
	Events.spell_released.emit(hero, "arcane_sanctum", "arcane", false, 0.0, b().ww_sanctum_mana)
	return true


## Full cleanup of everything this Mage placed in the world.
func clear_world() -> void:
	if sanctum != null and is_instance_valid(sanctum):
		sanctum.queue_free()
	sanctum = null
	for f in formations:
		if is_instance_valid(f):
			f.destroy("cleared")
	formations.clear()
	for z in fire_zones:
		if is_instance_valid(z):
			z.queue_free()
	fire_zones.clear()
	for c in Game.get_tree().get_nodes_in_group(SteamCloud.GROUP):
		if is_instance_valid(c) and c.owner_mage == hero:
			c.remove_from_group(SteamCloud.GROUP)
			c.queue_free()
	preserved = {}
	util_aiming = ""
	if cur != null:
		_end_charge()


## Kept for AI / compatibility (no conductive-path linking in the Worldweaver design).
func on_damage(info) -> void:
	# Protective Renewal: damage taken while protected is partly healed back over 3s
	var tgt = info.target
	if tgt != null and is_instance_valid(tgt) and tgt.team == hero.team and (info.final_amount + info.absorbed) > 0.0 and not info.is_dot:
		for e in tgt.statuses.effects:
			if e.id == "protective_renewal" and e.source == hero:
				var back: float = (info.final_amount + info.absorbed) * spells.protective_renewal.status_power
				var hot := StatusEffect.make("renewal_mend", "Renewal", "hot", 3.0, {}, back / 3.0, 1.0)
				hot.source = hero
				tgt.statuses.add(hot.scaled_by(hero.stats.effect_power()))
				break


# ------------------------------------------------------------------ indicators
func _update_heal_ring() -> void:
	var show_t = null
	var explicit: bool = heal_target != null and heal_target != hero
	if explicit:
		show_t = heal_target
	elif cur != null and cur.element == "life":
		show_t = hero
	if show_t == null or not is_instance_valid(show_t):
		if heal_ring:
			heal_ring.visible = false
		return
	if heal_ring == null or not is_instance_valid(heal_ring):
		heal_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.62
		tm.outer_radius = 0.72
		tm.rings = 32
		heal_ring.mesh = tm
		heal_ring_mat = StandardMaterial3D.new()
		heal_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		heal_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		heal_ring_mat.emission_enabled = true
		heal_ring.material_override = heal_ring_mat
		heal_ring.scale = Vector3(1, 0.2, 1)
		Game.fx_root().add_child(heal_ring)
	heal_ring.visible = true
	var in_range: bool = show_t.global_position.distance_to(hero.global_position) <= b().ww_heal_range
	var c := Color(0.45, 1.0, 0.55) if in_range else Color(1.0, 0.35, 0.3)
	heal_ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.6 + 0.3 * sin(Game.time * 6.0))
	heal_ring_mat.emission = c
	heal_ring.global_position = show_t.global_position + Vector3(0, 0.08, 0)
	heal_ring.rotation.y += 0.02


## Ground-placement preview for formation / location spells (charging, or holding 3 to aim).
func preview_spell() -> ChargedSpellData:
	if cur != null and cur.places_formation:
		return cur
	if util_aiming != "":
		return spells[util_aiming]
	if cur != null and cur.id == "earthbreaker" and kit.aug("mountainfall") > 0 and is_full():
		return cur
	return null


func _update_preview() -> void:
	var s := preview_spell()
	if s == null:
		if preview and is_instance_valid(preview):
			preview.visible = false
		return
	if preview == null or not is_instance_valid(preview):
		preview = Node3D.new()
		preview_mat = StandardMaterial3D.new()
		preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		preview_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		preview_mat.no_depth_test = true
		preview_box = MeshInstance3D.new()
		preview_box.mesh = BoxMesh.new()
		preview_box.material_override = preview_mat
		preview.add_child(preview_box)
		preview_disc = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.height = 0.04
		cm.radial_segments = 40
		preview_disc.mesh = cm
		preview_disc.material_override = preview_mat
		preview.add_child(preview_disc)
		Game.fx_root().add_child(preview)
	preview.visible = true
	var full := cur != null and is_full()
	var ai := aim_info(s)
	var col: Color = COLORS.get(s.element, Color.WHITE)
	preview_mat.albedo_color = Color(col.r, col.g, col.b, (0.55 if full else 0.3) + 0.1 * sin(Game.time * 8.0))
	preview.global_position = ai.pos + Vector3(0, 0.06, 0)
	preview.rotation.y = atan2(-ai.axis.z, ai.axis.x)
	var width := 0.0
	var depth := 0.9
	var radius := 0.0
	match s.id:
		"crystal_formation":
			width = s.width_full if full else s.width_partial
		"frozen_bastion", "stone_ward":
			width = s.width_partial
		"rising_pillar":
			width = s.width_partial
			depth = 1.4
			radius = s.radius_partial
		"cinderfall":
			radius = s.radius_full if full else s.radius_partial
		"earthbreaker":
			radius = float(kit.ap("mountainfall", "radius", 3.6))
	preview_box.visible = width > 0.0
	(preview_box.mesh as BoxMesh).size = Vector3(maxf(width, 0.1), 0.05, depth)
	preview_disc.visible = radius > 0.0
	(preview_disc.mesh as CylinderMesh).top_radius = maxf(radius, 0.1)
	(preview_disc.mesh as CylinderMesh).bottom_radius = maxf(radius, 0.1)


func free_indicator() -> void:
	if heal_ring and is_instance_valid(heal_ring):
		heal_ring.queue_free()
	if preview and is_instance_valid(preview):
		preview.queue_free()
