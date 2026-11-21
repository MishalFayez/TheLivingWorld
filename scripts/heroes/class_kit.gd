class_name ClassKit
extends Node
## Base for class mechanics. Each class scene (vanguard.tscn / mage.tscn / reaver.tscn) has a
## Hero root with a "Kit" child using a ClassKit subclass. Kits receive input actions from the
## Hero and hook into the damage pipeline (incoming/outgoing), attack lifecycle and HUD.

var hero: Hero
var b: BalanceConfig
var cooldowns: Dictionary = {}
var charging: String = ""
var charge_t: float = 0.0
var charge_max: float = 1.0
var attacks: Dictionary = {}
var _scheduled: Array = []


func setup(h: Hero) -> void:
	hero = h
	b = Game.balance


func load_attack(id: String) -> AttackData:
	if not attacks.has(id):
		var path := "res://data/attacks/%s.tres" % id
		var a = load(path)
		if a == null:
			push_error("Missing attack resource " + path)
			a = AttackData.new()
		attacks[id] = a
	return attacks[id]


# ------------------------------------------------------------------ virtuals
func build_model() -> void:
	pass

func on_press(_action: String) -> void:
	pass

func on_release(_action: String) -> void:
	pass

func modify_incoming(_info: DamageInfo) -> void:
	pass

func modify_outgoing(_info: DamageInfo, _d: AttackData, _target, _idx: int, _ctx: Dictionary) -> void:
	pass

func situational_crit(_d: AttackData, _target, _ctx: Dictionary) -> float:
	return 0.0

func on_attack_started(_d: AttackData, _ctx: Dictionary) -> void:
	pass

func on_attack_active(_d: AttackData, _ctx: Dictionary) -> void:
	pass

func on_attack_finished(_d: AttackData, _ctx: Dictionary, _interrupted: bool) -> void:
	pass

func on_hit_landed(_target, _info: DamageInfo) -> void:
	pass

func on_damaged(_info: DamageInfo) -> void:
	pass

func on_dodge() -> void:
	cancel_charge()

func on_perfect_dodge(_info: DamageInfo) -> void:
	pass

func unlocked(id: String) -> bool:
	return hero.unlocked(id)

## Notifies the player that an ability is still locked (with its unlock level).
func locked_msg(id: String) -> void:
	if not hero.is_player:
		return
	var t := hero.prog().track()
	var m: Dictionary = t.milestone(id) if t else {}
	Events.notify.emit("%s  -  unlocks at Level %d" % [String(m.get("name", id)), int(m.get("level", 0))])

func on_staggered() -> void:
	cancel_charge()

func on_downed() -> void:
	cancel_charge()

func on_stats_refreshed() -> void:
	pass

func restore() -> void:
	cooldowns.clear()

func threat_mult() -> float:
	return 1.0

func dodge_cost_mult() -> float:
	return 1.0

func iframe_mult() -> float:
	return 1.0

func stamina_regen_mult() -> float:
	return 1.0

func overrides_idle_anim() -> bool:
	return charging != ""

func move_mult() -> float:
	return 0.35 if charging != "" else 1.0

func resource_name() -> String:
	return ""

func resource_value() -> float:
	return 0.0

func resource_max() -> float:
	return 100.0

func hud_lines() -> Array:
	return []


# ------------------------------------------------------------------ shared helpers
func process(delta: float) -> void:
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	if charging != "":
		charge_t += delta
	for i in range(_scheduled.size() - 1, -1, -1):
		var s: Dictionary = _scheduled[i]
		s.t -= delta
		if s.t <= 0.0:
			_scheduled.remove_at(i)
			if s.fn.is_valid():
				s.fn.call()


## Delay on the HERO's clock: pauses during the hero's hitstop and while downed / dead. For the hero's own
## follow-up actions (deferred recovery, same-tick follow-ups).
func schedule(delay: float, fn: Callable) -> void:
	_scheduled.append({"t": delay, "fn": fn})


## Delay on the WORLD clock, for effects already announced in the world (telegraphed impacts, secondary
## waves): they land when their telegraph says, even if the caster is in hitstop, downed or dead. A paused
## tree (menus, drafts) still pauses them.
func schedule_world(delay: float, fn: Callable) -> void:
	if hero == null or not hero.is_inside_tree():
		return
	hero.get_tree().create_timer(maxf(delay, 0.0), false, true).timeout.connect(func():
		if fn.is_valid():
			fn.call())


func cd(key: String) -> float:
	return cooldowns.get(key, 0.0)


func set_cd(key: String, base: float) -> void:
	cooldowns[key] = base * (1.0 - hero.stats.cdr)


func aug(id: String) -> int:
	return hero.prog().augment_stacks(id)


func ap(id: String, key: String, default_value = 0.0):
	var a: AugmentData = Game.augment_db.get_augment(id)
	if a == null:
		return default_value
	return a.params.get(key, default_value)


func trigger(id: String, detail: String) -> void:
	Events.augment_triggered.emit(hero, id, detail)


func start_attack(d: AttackData, ctx: Dictionary = {}) -> bool:
	if hero.stamina <= 0.0 and d.stamina_cost > 0.0:
		return false
	var mult := 1.0
	if hero.rt:
		d = hero.rt.prepare_attack(d, ctx)
		mult = hero.rt.stamina_mult(d, ctx)
	hero.use_stamina(d.stamina_cost * mult)
	hero.face_for_attack()
	var aim := hero.move_input if hero.move_input.length() > 0.2 else hero.forward()
	hero.approach = MeleeApproach.plan(hero, d, hero.lock_target, aim, hero.attack_speed())
	if hero.approach.active:
		hero.attack_turn_dir = hero.approach.target.global_position - hero.global_position
		hero.attack_turn_dir.y = 0.0
	hero.runner.start(d, ctx, hero.attack_speed())
	return true


func begin_charge(action: String, max_time: float) -> void:
	charging = action
	charge_t = 0.0
	charge_max = maxf(max_time, 0.01)
	hero.play_anim("charge")


func charge_ratio() -> float:
	return clampf(charge_t / charge_max, 0.0, 1.0)


func cancel_charge() -> void:
	charging = ""
	charge_t = 0.0


## Applies charge level to a cloned attack. Charging changes the attack, not only its numbers
## (subclasses add mechanical differences on top).
func apply_charge(d: AttackData, ratio: float) -> AttackData:
	return charged_attack(d, ratio)


## Static form (LEVEL10-FOUNDATION-005: tooltips build the same charged attack the kit builds).
static func charged_attack(d: AttackData, ratio: float) -> AttackData:
	var c := d.clone()
	c.damage_mult += d.charge_damage_bonus * ratio
	c.poise_damage += d.charge_poise_bonus * ratio
	c.is_charged = ratio >= 0.25
	return c
