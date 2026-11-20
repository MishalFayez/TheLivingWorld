class_name StatusComponent
extends Node
## Holds and ticks StatusEffects on one Combatant.

var owner_c = null
var effects: Array = []


func add(e: StatusEffect) -> void:
	if owner_c == null or owner_c.dead:
		return
	for ex in effects:
		if ex.id == e.id:
			ex.remaining = maxf(ex.remaining, e.duration)
			ex.duration = maxf(ex.duration, e.duration)
			ex.tick_amount = maxf(ex.tick_amount, e.tick_amount)
			ex.mods = e.mods
			ex.source = e.source
			return
	effects.append(e)
	Events.status_applied.emit(owner_c, e)


func has(id: String) -> bool:
	for e in effects:
		if e.id == id:
			return true
	return false


func remove(id: String) -> void:
	for i in range(effects.size() - 1, -1, -1):
		if effects[i].id == id:
			effects.remove_at(i)


func clear() -> void:
	effects.clear()


func mult(key: String) -> float:
	var m := 1.0
	for e in effects:
		if e.mods.has(key):
			m *= float(e.mods[key])
	return m


func names() -> Array:
	var out: Array = []
	for e in effects:
		out.append("%s %.0fs" % [e.display_name, e.remaining])
	return out


func _physics_process(delta: float) -> void:
	if owner_c == null or owner_c.dead or owner_c.downed:
		return
	for i in range(effects.size() - 1, -1, -1):
		if i >= effects.size():
			continue
		var e: StatusEffect = effects[i]
		e.remaining -= delta
		if e.kind == "dot" or e.kind == "hot":
			e.tick_t += delta
			while e.tick_t >= e.tick_interval:
				e.tick_t -= e.tick_interval
				_tick(e)
				if owner_c.dead or owner_c.downed:
					return
		if e.remaining <= 0.0 and i < effects.size() and effects[i] == e:
			effects.remove_at(i)


func _tick(e: StatusEffect) -> void:
	if e.kind == "dot":
		var info := DamageInfo.new()
		info.source = e.source if is_instance_valid(e.source) else null
		info.target = owner_c
		info.attack_name = e.display_name
		info.damage_type = AttackData.DamageType.MAGIC
		info.amount = e.tick_amount
		info.raw_amount = e.tick_amount
		info.is_dot = true
		info.source_pos = owner_c.global_position
		owner_c.take_damage(info)
	else:
		owner_c.heal(e.tick_amount, e.source if is_instance_valid(e.source) else owner_c, {"hot": true, "no_convert": true})
