class_name MageKit
extends ClassKit
## MAGE — Healer / Magic DPS.
## DEFAULT (approved design): GRAND ELEMENTALIST - charged elemental spellcasting, five elements with
## different battlefield roles, real healing and Arcane Sanctum. All of it lives in MageElementalist
## (scripts/heroes/mage_elementalist.gd); this kit routes to it when Game.mage_core == "elementalist".
## The rejected cores below are kept ONLY for debug comparison (Debug > Combat > Mage core).
## Legacy (rejected) core: LEY SIGILS — E inscribes a sigil of the element you last cast. Sigils pulse
## (Life heals allies inside, Fire burns, Frost chills, Storm zaps, Stone hardens). Lv5 Resonance: your
## spells hitting enemies inside a sigil trigger its element. Press E at the sigil limit to CONSUME the
## oldest sigil in an element burst. Healing never requires attacking first (Mend / Renewal / Life Sigil).
## Legacy core (Game.mage_core = "weave"): Arcane Weave.
## LMB = element slot 1, RMB = element slot 2, F = Life (always available). Tap = quick cast,
## hold = charged cast (charging changes HOW the spell works). Every spell stores an Elemental Echo
## (last two kept). E = Arcane Weave fuses both Echoes into a Fusion Spell.
## 1 / 2 cycle the element in slot 1 / slot 2 among discovered elements.
## Progression is different from Vanguard: no skill slots - discoveries, disciplines, mutations.

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.45, 0.15), "life": Color(0.4, 1.0, 0.5), "frost": Color(0.55, 0.85, 1.0),
	"storm": Color(0.75, 0.65, 1.0), "stone": Color(0.7, 0.55, 0.35),
}

var mana: float = 100.0
var echoes: Array = []
var spells: Dictionary = {}       # id -> SpellData
var fusions: Dictionary = {}      # key -> FusionData
var last_quick: Dictionary = {}
var weave_cd: float = 0.0
var _weave_pending: FusionData = null
# Ley Sigils core
var last_element: String = "life"
var sigils: Array = []
var ward_cd: float = 0.0
const SIGIL_MANA := 20.0
const WARD_MANA := 15.0
const WARD_CD := 12.0
var el: MageElementalist


func setup(h: Hero) -> void:
	super.setup(h)
	for f in DirAccess.get_files_at("res://data/spells"):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var s = load("res://data/spells/" + file)
			if s is SpellData:
				spells[s.id] = s
	for f in DirAccess.get_files_at("res://data/fusions"):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var fu = load("res://data/fusions/" + file)
			if fu is FusionData:
				fusions[fu.key] = fu
	mana = b.mana_max
	Events.damage_applied.connect(_on_damage_applied)
	el = MageElementalist.new(self)


func elementalist() -> bool:
	return Game.mage_core == "elementalist"


func sigil_core() -> bool:
	return Game.mage_core == "sigils"


## The rejected legacy cores (debug comparison only) keep their original Update 5 unlock levels.
const LEGACY_UNLOCKS := {"m_spells": 1, "m_sigil": 1, "m_emergency": 3, "m_resonance": 5, "m_ward": 7, "m_twin_sigils": 9, "m_archmage": 10}


func unlocked(id: String) -> bool:
	if not elementalist() and LEGACY_UNLOCKS.has(id):
		var p := prog()
		return (p.level >= int(LEGACY_UNLOCKS[id]) or p.debug_unlocks.has(id) or not p.debug_unlocks.is_empty()) and not p.debug_locks.has(id)
	return hero.unlocked(id)


func on_dodge() -> void:
	if elementalist():
		el.cancel("dodge")
	super.on_dodge()


func on_staggered() -> void:
	if elementalist():
		el.cancel("stagger")
	super.on_staggered()


func on_downed() -> void:
	if elementalist():
		el.cancel("downed")
	super.on_downed()


func move_mult() -> float:
	if elementalist():
		return el.move_mult()
	return super.move_mult()


func _exit_tree() -> void:
	if el:
		el.clear_world()
		el.free_indicator()


func build_model() -> void:
	hero.display_name = (hero.prog().character_name if hero.is_player and hero.prog().character_name != "" else "Mage") if hero.is_player else "Mage (AI)"
	CharModel.build(hero, "mage", hero.prog())


func resource_name() -> String:
	return "Mana"


func resource_value() -> float:
	return mana


func resource_max() -> float:
	return b.mana_max


func restore() -> void:
	super.restore()
	mana = b.mana_max
	weave_cd = 0.0
	ward_cd = 0.0
	clear_sigils()
	if el:
		el.clear_world()


func prog() -> ClassProgress:
	return hero.prog()


func slot_element(i: int) -> String:
	return prog().slots[i]


func process(delta: float) -> void:
	super.process(delta)
	mana = minf(b.mana_max, mana + b.mana_regen * delta)
	weave_cd = maxf(0.0, weave_cd - delta)
	ward_cd = maxf(0.0, ward_cd - delta)
	if elementalist():
		el.process(delta)
	if not sigils.is_empty():
		sigils = sigils.filter(func(x): return is_instance_valid(x) and not x.consumed)


func overrides_idle_anim() -> bool:
	return charging != ""


# ------------------------------------------------------------------ input
func on_press(action: String) -> void:
	if elementalist():
		el.on_press(action)
		return
	match action:
		"light", "heavy", "life":
			if charging != "":
				return
			if not hero.can_act():
				hero.buffer(action)
				return
			var el := _element_for(action)
			if el == "":
				if hero.is_player:
					Events.notify.emit("No element in that slot - discover Frost/Storm/Stone")
				return
			charging = action
			charge_t = 0.0
			charge_max = 1.0
			hero.play_anim("cast_hold")
			if not hero.is_held(action):
				on_release(action)
		"core":
			if sigil_core():
				sigil_action()
			else:
				weave()
		"skill1":
			_cycle_slot(0)
		"skill2":
			_cycle_slot(1)
		"skill3":
			if sigil_core():
				cast_ward()


func on_release(action: String) -> void:
	if elementalist():
		el.on_release(action)
		return
	if charging != action:
		return
	var el := _element_for(action)
	var is_charged := charge_t >= b.charge_min
	cancel_charge()
	var spell := _spell_for(el, is_charged)
	if spell:
		cast(spell)


func _element_for(action: String) -> String:
	match action:
		"light":
			return slot_element(0)
		"heavy":
			return slot_element(1)
		"life":
			return "life"
	return ""


func _spell_for(el: String, is_charged: bool) -> SpellData:
	for s in spells.values():
		if s.element == el and s.charged == is_charged:
			return s
	return null


func _cycle_slot(i: int) -> void:
	var p := prog()
	var opts: Array = p.offensive_elements()
	opts.erase(p.slots[1 - i])
	if opts.is_empty():
		return
	var cur := opts.find(p.slots[i])
	p.slots[i] = opts[(cur + 1) % opts.size()]
	Events.notify.emit("Slot %d: %s" % [i + 1, p.slots[i].capitalize()])


# ------------------------------------------------------------------ casting
func cast(spell: SpellData) -> bool:
	if mana < spell.mana_cost:
		if hero.is_player:
			Events.notify.emit("Not enough mana")
		return false
	mana -= spell.mana_cost
	var d := AttackData.new()
	d.id = "cast_" + spell.id
	d.display_name = spell.display_name
	d.anim_style = "cast"
	d.startup = spell.cast_time
	if spell.charged and unlocked("m_archmage"):
		d.startup *= 0.75
	d.active = 0.05
	d.recovery = spell.recovery
	d.cancel_after = spell.recovery * 0.5
	d.hits = 0
	d.stamina_cost = 0.0
	d.add_tag("spell")
	d.add_tag("light")
	start_attack(d, {"spell": spell.id})
	return true


func on_attack_active(d: AttackData, ctx: Dictionary) -> void:
	if ctx.has("spell"):
		release_spell(spells[ctx.spell], 1.0, false)
	elif ctx.has("fusion") and _weave_pending:
		var f := _weave_pending
		_weave_pending = null
		_release_fusion(f)


func spell_power(el: String) -> float:
	var rank := mini(3, int(prog().discipline_casts.get(el, 0)) / maxi(1, b.discipline_casts_per_rank))
	return 1.0 + rank * b.discipline_power_per_rank


func release_spell(spell: SpellData, power_mult: float, is_echo: bool) -> void:
	var pw := power_mult * spell_power(spell.element)
	match spell.id:
		"firebolt": _firebolt(spell, pw, is_echo)
		"fireball": _fireball(spell, pw, is_echo)
		"mend": _mend(spell, pw)
		"renewal": _renewal(spell, pw)
		"ice_shard": _ice_shard(spell, pw)
		"frost_nova": _frost_nova(spell, pw)
		"spark": _spark(spell, pw)
		"thunder": _thunder(spell, pw)
		"stone_shard": _stone_shard(spell, pw)
		"earthen_ward": _earthen_ward(spell, pw)
	Events.spell_cast.emit(hero, spell.id)
	if is_echo:
		return
	last_element = spell.element
	# Elemental Echo
	echoes.append(spell.element)
	while echoes.size() > 2:
		echoes.pop_front()
	# Discipline (deepen existing elements by using them)
	var p := prog()
	var before := spell_power(spell.element)
	p.discipline_casts[spell.element] = int(p.discipline_casts.get(spell.element, 0)) + 1
	if spell_power(spell.element) > before:
		Events.log_message.emit("%s discipline deepened (power x%.1f)" % [spell.element.capitalize(), spell_power(spell.element)], "fusion")
	# Spell Echo augment: quick cast of a DIFFERENT element right after a quick cast re-casts the earlier spell weaker.
	if not spell.charged:
		if aug("spell_echo") > 0 and not last_quick.is_empty() and last_quick.element != spell.element and Game.time - last_quick.time <= float(ap("spell_echo", "window", 1.5)):
			var prev: SpellData = spells[last_quick.id]
			var pm := float(ap("spell_echo", "power", 0.4))
			trigger("spell_echo", "%s -> %s : echo of %s at %d%%" % [prev.display_name, spell.display_name, prev.display_name, roundi(pm * 100)])
			var echo_fn := func():
				if is_instance_valid(hero) and not hero.downed:
					release_spell(prev, pm, true)
			schedule(0.25, echo_fn)
			last_quick = {}
		else:
			last_quick = {"id": spell.id, "element": spell.element, "time": Game.time}


func aim_point(max_dist: float) -> Vector3:
	var t = hero.find_enemy_target(max_dist, 40.0)
	if t:
		return t.global_position + Vector3(0, 0.9, 0)
	return hero.global_position + hero.forward() * minf(12.0, max_dist) + Vector3(0, 0.9, 0)


func _launch(spell: SpellData, pw: float, color: Color, on_hit: Callable, radius: float = 0.3) -> void:
	var from := hero.global_position + Vector3(0, 1.3, 0) + hero.forward() * 0.6
	var target := aim_point(spell.max_range)
	var dir := (target - from)
	if dir.length() < 0.1:
		dir = hero.forward()
	Projectile.spawn(hero, from, dir, spell.speed, radius, color, on_hit, spell.max_range / spell.speed + 0.3, hero.weapon_power * spell.power * pw)


func _burn(target, power: float) -> void:
	var e := StatusEffect.make("burn", "Burn", "dot", 3.0, {}, hero.weapon_power * power, 1.0)
	e.source = hero
	target.statuses.add(e.scaled_by(hero.stats.effect_power()))


func _living_flame(pos: Vector3, radius: float, duration: float) -> void:
	if aug("living_flame") == 0:
		return
	var h := hero
	var pw := float(ap("living_flame", "tick_power", 0.25))
	GroundZone.spawn(hero, pos, radius, duration, Color(1.0, 0.4, 0.1), 0.5, func(z):
		if not is_instance_valid(h):
			return
		for e in z.enemies_of_source():
			h.spell_damage(e, pw, 2.0, "Living Flame", {"hitstop": 0.0, "knockback": 0.0}))
	trigger("living_flame", "Fire left lingering flames (r=%.1f)" % radius)


func _firebolt(s: SpellData, pw: float, is_echo: bool) -> void:
	var h := hero
	_launch(s, pw, ELEMENT_COLORS.fire, func(t, pos):
		if not is_instance_valid(h):
			return
		if t:
			h.spell_damage(t, s.power * pw, s.poise_damage, s.display_name + (" (echo)" if is_echo else ""), {"pos": pos, "projectile": true})
			_burn(t, s.status_power * pw)
		FX.burst(pos, 0.8, ELEMENT_COLORS.fire)
		_living_flame(pos, 1.6, 3.0))


func _fireball(s: SpellData, pw: float, is_echo: bool) -> void:
	var h := hero
	var cb := func(_t, pos):
		if not is_instance_valid(h):
			return
		FX.burst(pos, s.radius, ELEMENT_COLORS.fire, 0.45)
		for e in h.enemies_within(s.radius, pos):
			h.spell_damage(e, s.power * pw, s.poise_damage, s.display_name + (" (echo)" if is_echo else ""), {"pos": pos})
			_burn(e, s.status_power * pw)
		_living_flame(pos, 2.6, 4.0)
	_launch(s, pw, ELEMENT_COLORS.fire, cb, 0.55)


func heal_target(target, amount: float, label: String, opts: Dictionary = {}) -> void:
	if target == null or not is_instance_valid(target):
		return
	var missing: float = target.max_hp - target.hp
	var over := maxf(0.0, amount - missing)
	target.heal(amount, hero, {"spell": label})
	if over > 1.0 and aug("gentle_restoration") > 0 and not opts.get("no_convert", false):
		var conv := over * float(ap("gentle_restoration", "conversion", 0.5))
		var dur := float(ap("gentle_restoration", "duration", 4.0))
		var e := StatusEffect.make("gentle_restoration", "Gentle Restoration", "hot", dur, {}, conv / dur, 1.0)
		e.source = hero
		target.statuses.add(e.scaled_by(hero.stats.effect_power()))
		trigger("gentle_restoration", "%d overheal -> HoT on %s" % [roundi(over), target.display_name])
	# Second Heart (Worldweaver): limited overhealing from the Mage becomes temporary protection
	if over > 1.0 and aug("second_heart") > 0 and elementalist() and not opts.get("no_convert", false):
		var cap: float = target.max_hp * float(ap("second_heart", "max_hp_frac", 0.15))
		var amt: float = minf(over * float(ap("second_heart", "conversion", 0.3)), cap)
		target.add_shield(amt, float(ap("second_heart", "duration", 4.0)), hero)
		trigger("second_heart", "%d overheal -> %d protection on %s" % [roundi(over), roundi(amt), target.display_name])
	if not opts.get("no_fx", false):
		VFX.heal_motes(target)


func _mend(s: SpellData, pw: float) -> void:
	var t = hero.lowest_ally(s.max_range)
	if t == null:
		t = hero
	FX.beam(hero.global_position + Vector3(0, 1.4, 0), t.global_position + Vector3(0, 1.0, 0), ELEMENT_COLORS.life)
	var amt := hero.weapon_power * s.power * pw
	# Lifeline (Lv3): emergency Mend on a critically wounded ally heals more and briefly protects them.
	if sigil_core() and unlocked("m_emergency") and t.hp / t.max_hp < 0.35:
		amt *= 1.8
		var e := StatusEffect.make("lifeline", "Lifeline", "buff", 2.0, {"damage_taken": 0.5})
		e.source = hero
		t.statuses.add(e)
		Events.augment_triggered.emit(hero, "m_emergency", "Lifeline on %s" % t.display_name)
	heal_target(t, amt, s.display_name)


func _renewal(s: SpellData, pw: float) -> void:
	FX.burst(hero.global_position + Vector3(0, 0.5, 0), s.radius, ELEMENT_COLORS.life, 0.6)
	for h in hero.allies(true):
		if h.global_position.distance_to(hero.global_position) <= s.radius:
			heal_target(h, hero.weapon_power * s.power * pw, s.display_name)
			var e := StatusEffect.make("renewal", "Renewal", "hot", s.status_duration, {}, hero.weapon_power * s.status_power * pw, 1.0)
			e.source = hero
			h.statuses.add(e.scaled_by(hero.stats.effect_power()))


func _chill(target, slow: float, dur: float, id: String = "chill", nm: String = "Chill") -> void:
	var e := StatusEffect.make(id, nm, "debuff", dur, {"move_speed": slow, "attack_speed": lerpf(1.0, slow, 0.5)})
	e.source = hero
	target.statuses.add(e.scaled_by(hero.stats.effect_power()))


func _ice_shard(s: SpellData, pw: float) -> void:
	var h := hero
	_launch(s, pw, ELEMENT_COLORS.frost, func(t, pos):
		if not is_instance_valid(h):
			return
		if t:
			h.spell_damage(t, s.power * pw, s.poise_damage, s.display_name, {"pos": pos, "projectile": true})
			_chill(t, 1.0 - s.status_power, s.status_duration)
		FX.burst(pos, 0.7, ELEMENT_COLORS.frost))


func _frost_nova(s: SpellData, pw: float) -> void:
	FX.burst(hero.global_position + Vector3(0, 0.5, 0), s.radius, ELEMENT_COLORS.frost, 0.4)
	for e in hero.enemies_within(s.radius):
		hero.spell_damage(e, s.power * pw, s.poise_damage, s.display_name)
		_chill(e, 1.0 - s.status_power, s.status_duration, "frozen", "Frozen")


func _storm_hit(target, power: float, poise_dmg: float, label: String) -> DamageInfo:
	var info := hero.spell_damage(target, power, poise_dmg, label, {"hitstop": 0.04})
	if aug("living_current") > 0 and info.final_amount > 0.0:
		var ally = hero.lowest_ally(25.0)
		if ally:
			var amt := info.final_amount * float(ap("living_current", "heal_ratio", 0.25))
			heal_target(ally, amt, "Living Current")
			trigger("living_current", "Storm damage healed %s for %d" % [ally.display_name, roundi(amt)])
	return info


func chain(first, bounces: int, power: float, poise_dmg: float, label: String, color: Color, on_each: Callable = Callable()) -> int:
	var hit_list: Array = []
	var cur = first
	var from := hero.global_position + Vector3(0, 1.3, 0)
	for i in bounces + 1:
		if cur == null or not is_instance_valid(cur):
			break
		var to: Vector3 = cur.global_position + Vector3(0, 1.0, 0)
		FX.beam(from, to, color, 0.3)
		_storm_hit(cur, power, poise_dmg, label)
		if on_each.is_valid():
			on_each.call(cur)
		hit_list.append(cur)
		from = to
		var nxt = null
		var nd := 7.5
		for e in hero.get_tree().get_nodes_in_group("enemies"):
			if e.is_targetable() and not hit_list.has(e):
				var dd: float = e.global_position.distance_to(cur.global_position)
				if dd < nd:
					nd = dd
					nxt = e
		cur = nxt
	return hit_list.size()


func _spark(s: SpellData, pw: float) -> void:
	var t = hero.find_enemy_target(s.max_range, 45.0)
	if t == null:
		FX.beam(hero.global_position + Vector3(0, 1.3, 0), hero.global_position + hero.forward() * 6.0 + Vector3(0, 1, 0), ELEMENT_COLORS.storm)
		return
	chain(t, s.bounces, s.power * pw, s.poise_damage, s.display_name, ELEMENT_COLORS.storm)


func _thunder(s: SpellData, pw: float) -> void:
	var pos := aim_point(s.max_range) - Vector3(0, 0.9, 0)
	Telegraph.circle(pos, s.radius, s.delay, Color(0.75, 0.65, 1.0, 0.6))
	var h := hero
	schedule_world(s.delay, func():
		if not is_instance_valid(h):
			return
		FX.beam(pos + Vector3(0, 12, 0), pos, ELEMENT_COLORS.storm, 0.35)
		FX.burst(pos, s.radius, ELEMENT_COLORS.storm)
		for e in h.enemies_within(s.radius, pos):
			_storm_hit(e, s.power * pw, s.poise_damage, s.display_name))


func _stone_shard(s: SpellData, pw: float) -> void:
	var h := hero
	var cb := func(t, pos):
		if not is_instance_valid(h):
			return
		if t:
			h.spell_damage(t, s.power * pw, s.poise_damage, s.display_name, {"pos": pos, "projectile": true, "type": AttackData.DamageType.PHYSICAL, "knockback": 4.0})
		FX.burst(pos, 0.7, ELEMENT_COLORS.stone)
	_launch(s, pw, ELEMENT_COLORS.stone, cb, 0.4)


func _earthen_ward(s: SpellData, pw: float) -> void:
	FX.burst(hero.global_position + Vector3(0, 0.5, 0), s.radius, ELEMENT_COLORS.stone, 0.5)
	for h in hero.allies(true):
		if h.global_position.distance_to(hero.global_position) <= s.radius:
			var e := StatusEffect.make("stoneskin", "Stoneskin", "buff", s.status_duration, {"damage_taken": 1.0 - s.status_power, "poise_taken": 0.5})
			e.source = hero
			h.statuses.add(e.scaled_by(hero.stats.effect_power()))
	for e in hero.enemies_within(3.0):
		hero.spell_damage(e, s.power * pw, s.poise_damage, s.display_name, {"type": AttackData.DamageType.PHYSICAL, "knockback": 6.0})


# ------------------------------------------------------------------ Arcane Weave
func fusion_key() -> String:
	if echoes.size() < 2:
		return ""
	var pair: Array = echoes.duplicate()
	pair.sort()
	return "%s+%s" % [pair[0], pair[1]]


func weave() -> bool:
	if echoes.size() < 2:
		if hero.is_player:
			Events.notify.emit("Arcane Weave needs 2 Echoes")
		return false
	if weave_cd > 0.0 or not hero.can_act() or charging != "":
		return false
	var f: FusionData = fusions.get(fusion_key(), fusions.get("discord"))
	if f == null:
		return false
	if mana < f.mana_cost:
		if hero.is_player:
			Events.notify.emit("Not enough mana for %s" % f.display_name)
		return false
	mana -= f.mana_cost
	echoes.clear()
	weave_cd = b.weave_cooldown
	_weave_pending = f
	var d := AttackData.new()
	d.id = "weave"
	d.display_name = f.display_name
	d.anim_style = "cast"
	d.startup = 0.3
	d.active = 0.05
	d.recovery = 0.35
	d.cancel_after = 0.2
	d.hits = 0
	d.stamina_cost = 0.0
	d.add_tag("spell")
	start_attack(d, {"fusion": f.id})
	return true


func _release_fusion(f: FusionData) -> void:
	Events.fusion_cast.emit(hero, f.display_name)
	var h := hero
	var wp := hero.weapon_power
	match f.id:
		"phoenix_bloom":
			var t = hero.find_enemy_target(18.0, 60.0)
			var pos: Vector3 = t.global_position if t else hero.global_position
			GroundZone.spawn(hero, pos, f.radius, f.duration, Color(1.0, 0.6, 0.2), f.tick, func(z):
				if not is_instance_valid(h):
					return
				for e in z.enemies_of_source():
					h.spell_damage(e, f.power, f.poise_damage, f.display_name, {"hitstop": 0.0, "knockback": 0.0})
				for a in z.allies_of_source():
					h.kit.heal_target(a, wp * f.heal_power, f.display_name))
		"sanctuary":
			FX.burst(hero.global_position + Vector3(0, 1, 0), f.radius, ELEMENT_COLORS.life, 0.7)
			for a in hero.allies(true):
				if a.global_position.distance_to(hero.global_position) <= f.radius:
					heal_target(a, wp * f.heal_power, f.display_name)
					var e := StatusEffect.make("sanctuary", "Sanctuary", "hot", f.status_duration, {"damage_taken": 0.85}, wp * f.status_power, 1.0)
					e.source = hero
					a.statuses.add(e.scaled_by(hero.stats.effect_power()))
		"thermal_fracture":
			var pos := aim_point(18.0) - Vector3(0, 0.9, 0)
			FX.burst(pos, f.radius, Color(1.0, 0.9, 0.9), 0.5)
			for e in hero.enemies_within(f.radius, pos):
				hero.spell_damage(e, f.power, f.poise_damage, f.display_name, {"pos": pos, "hitstop": 0.12, "knockback": 5.0})
		"winters_embrace":
			FX.burst(hero.global_position + Vector3(0, 1, 0), f.radius, ELEMENT_COLORS.frost, 0.6)
			for a in hero.allies(true):
				if a.global_position.distance_to(hero.global_position) <= f.radius:
					heal_target(a, wp * f.heal_power, f.display_name)
					var e := StatusEffect.make("frost_armor", "Frost Armor", "buff", f.status_duration, {"damage_taken": 1.0 - f.status_power})
					e.source = hero
					a.statuses.add(e.scaled_by(hero.stats.effect_power()))
			for e in hero.enemies_within(f.radius * 0.7):
				hero.spell_damage(e, f.power, f.poise_damage, f.display_name)
				_chill(e, 0.45, f.status_duration, "winters_chill", "Winter's Chill")
		"plasma_surge":
			var t = hero.find_enemy_target(20.0, 70.0)
			if t:
				chain(t, f.bounces, f.power, f.poise_damage, f.display_name, Color(1.0, 0.5, 1.0), func(e): _burn(e, f.status_power))
		"vital_current":
			var t = hero.find_enemy_target(20.0, 70.0)
			var bounces := f.bounces
			var heal_mult := 1.0
			if aug("living_current") > 0:
				bounces += int(ap("living_current", "vital_bounces", 2))
				heal_mult = float(ap("living_current", "vital_heal_mult", 1.5))
				trigger("living_current", "Vital Current empowered (+%d bounces, heal x%.1f)" % [int(ap("living_current", "vital_bounces", 2)), heal_mult])
			if t:
				chain(t, bounces, f.power, f.poise_damage, f.display_name, Color(0.5, 1.0, 0.8), func(_e):
					var ally = h.lowest_ally(25.0)
					if ally:
						h.kit.heal_target(ally, wp * f.heal_power * heal_mult, f.display_name))
			else:
				var ally = hero.lowest_ally(25.0)
				if ally:
					heal_target(ally, wp * f.heal_power * heal_mult * 2.0, f.display_name)
		_:
			var pos := aim_point(15.0) - Vector3(0, 0.9, 0)
			FX.burst(pos, f.radius, Color(0.9, 0.9, 1.0))
			for e in hero.enemies_within(f.radius, pos):
				hero.spell_damage(e, f.power, f.poise_damage, f.display_name, {"pos": pos})


# ------------------------------------------------------------------ Ley Sigils
func sigil_limit() -> int:
	return 2 if unlocked("m_twin_sigils") else 1


func sigil_duration() -> float:
	return 10.0 * (1.5 if unlocked("m_archmage") else 1.0)


func sigil_pulse() -> float:
	return 1.0 / (float(ap("resonant_ground", "pulse_mult", 1.0)) if aug("resonant_ground") > 0 else 1.0)


func sigil_radius() -> float:
	return 4.0 * (float(ap("resonant_ground", "radius_mult", 1.0)) if aug("resonant_ground") > 0 else 1.0)


func clear_sigils() -> void:
	for sg in sigils:
		if is_instance_valid(sg):
			sg.queue_free()
	sigils.clear()


func sigil_place_point(el: String) -> Vector3:
	match el:
		"life":
			var a = hero.lowest_ally(22.0)
			if a and a.hp < a.max_hp:
				return a.global_position
			return hero.global_position
		"stone":
			return hero.global_position
	var t = hero.lock_target
	if t == null or not is_instance_valid(t) or not t.is_targetable():
		t = hero.find_enemy_target(14.0, 45.0)
	if t and is_instance_valid(t):
		return t.global_position
	return hero.global_position + hero.forward() * 7.0


## E: inscribe a sigil of the last-cast element; at the sigil limit E consumes the oldest one.
func sigil_action() -> bool:
	if not hero.can_act() or charging != "":
		return false
	if not unlocked("m_sigil"):
		locked_msg("m_sigil")
		return false
	if sigils.size() >= sigil_limit():
		var old = sigils.pop_front()
		if is_instance_valid(old):
			old.detonate()
		return true
	if mana < SIGIL_MANA:
		if hero.is_player:
			Events.notify.emit("Not enough mana for a sigil")
		return false
	mana -= SIGIL_MANA
	var el := last_element if last_element != "" else "life"
	var pos := sigil_place_point(el)
	var sg := LeySigil.inscribe(hero, el, pos, sigil_radius(), sigil_duration(), sigil_pulse())
	sigils.append(sg)
	hero.play_anim("cast_hold")
	Events.log_message.emit("%s inscribes a %s Sigil" % [hero.display_name, el.capitalize()], "fusion")
	return true


func cast_ward() -> bool:
	if not unlocked("m_ward"):
		locked_msg("m_ward")
		return false
	if ward_cd > 0.0 or not hero.can_act():
		return false
	if mana < WARD_MANA:
		if hero.is_player:
			Events.notify.emit("Not enough mana for Ward")
		return false
	var t = hero.lowest_ally(22.0)
	if t == null:
		t = hero
	mana -= WARD_MANA
	ward_cd = WARD_CD
	var mult := float(ap("sanctified_ward", "ward_mult", 1.0)) if aug("sanctified_ward") > 0 else 1.0
	t.add_shield(hero.weapon_power * 1.4 * hero.stats.effect_power() * mult, 6.0, hero)
	FX.beam(hero.global_position + Vector3(0, 1.4, 0), t.global_position + Vector3(0, 1.0, 0), Color(0.75, 0.95, 1.0))
	VFX.ground_ring(t.global_position, 1.4, Color(0.75, 0.95, 1.0), 0.4)
	Events.log_message.emit("%s wards %s" % [hero.display_name, t.display_name], "fusion")
	return true


func _on_damage_applied(info) -> void:
	if elementalist():
		if is_instance_valid(hero):
			el.on_damage(info)
		return
	if not sigil_core() or not is_instance_valid(hero) or info.source != hero:
		return
	if info.tags.get("sigil", false) or info.final_amount <= 0.0 or not unlocked("m_resonance"):
		return
	var tgt = info.target
	if not is_instance_valid(tgt) or tgt.team == hero.team:
		return
	for sg in sigils:
		if is_instance_valid(sg) and not sg.consumed and sg.contains(tgt.global_position):
			sg.resonate(tgt, info)
			break


func hud_lines() -> Array:
	var p := prog()
	var out: Array = []
	if elementalist():
		out.append("LMB %s   RMB %s   1 %s   3 %s" % [el.slot_spell(0), el.slot_spell(1), el.slot_spell(2), el.utility_spell()])
		if el.cur:
			out.append("Charging %s %d%%%s" % [el.cur.display_name, roundi(el.ratio() * 100.0), "  FULL" if el.is_full() else ""])
		return out
	out.append("LMB: %s   RMB: %s   F: Life" % [p.slots[0].capitalize() if p.slots[0] != "" else "-", p.slots[1].capitalize() if p.slots[1] != "" else "-"])
	var ech := "Echoes: "
	for e in echoes:
		ech += "[%s] " % e.capitalize()
	out.append(ech)
	var key := fusion_key()
	if key != "":
		var f: FusionData = fusions.get(key, fusions.get("discord"))
		out.append("E -> %s%s" % [f.display_name if f else "?", "" if weave_cd <= 0 else " (%.1fs)" % weave_cd])
	var disc := "Discipline: "
	for el in p.elements:
		disc += "%s x%.1f  " % [el.capitalize(), spell_power(el)]
	out.append(disc)
	if charging != "":
		out.append("Charging %s %s" % [_element_for(charging).capitalize(), "(CHARGED)" if charge_t >= b.charge_min else ""])
	return out
