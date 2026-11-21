class_name VanguardKit
extends ClassKit
## VANGUARD — Tank. Core: Aegis Guard (Guard / Perfect Guard / Counter) + Resolve.
## Skills: Shield Rush (interception / empowered), Judgment Strike (charge / riposte / verdict),
## Iron Sweep (multi-hit / guarded / resolve taunt).

const EQUIPPED_SKILLS := ["shield_rush", "judgment_strike", "iron_sweep"]

var skills: Array = []
var resolve: float = 0.0
var resolve_idle: float = 0.0
var guarding: bool = false
var guard_start: float = -10.0
var guard_release_time: float = -10.0
var guard_perfect_ok: bool = false
var counter_until: float = -10.0
var reprisal_until: float = -10.0
var crushing_ready: bool = false
var combo: int = 0
var combo_reset: float = 0.0
var last_line_icd: float = 0.0
var fortress_icd: float = 0.0
## Resolve spend by HOLDING a skill key (design resolution 8): action being held, and when it was pressed
var hold_skill: String = ""
var hold_t: float = 0.0
const HOLD_TO_SPEND := 0.35
## Shield Plant (Lv12)
var planted: bool = false
var planted_until: float = -10.0
var _last_guard_key: String = ""
var guarded_strike_hits: int = 0


func setup(h: Hero) -> void:
	super.setup(h)
	for id in EQUIPPED_SKILLS:
		var s = load("res://data/skills/%s.tres" % id)
		skills.append(s)


func build_model() -> void:
	hero.display_name = (hero.prog().character_name if hero.is_player and hero.prog().character_name != "" else "Vanguard") if hero.is_player else "Vanguard (AI)"
	CharModel.build(hero, "vanguard", hero.prog())


func threat_mult() -> float:
	return b.vanguard_threat_mult


func overrides_idle_anim() -> bool:
	return guarding or charging != ""


func move_mult() -> float:
	if planted:
		return b.shield_plant_move_mult
	if guarding:
		var m := b.guard_move_mult * (hero.rt.guard_move_mult() if hero.rt else 1.0)
		# Living Fortress (Bulwark anchor): forward steps while guarding at up to 60% of normal speed
		if hero.rt and _guard_advancing():
			m = maxf(m, hero.rt.guard_forward_fraction())
			if hero.rt.ready("vb01_fx"):
				hero.rt.use_cd("vb01_fx", 3.0)    # visible cue (006 Part 12): advancing behind the Guard
				hero.rt.fire("vb01_living_fortress", "Advancing behind the Guard (%s speed)" % StatStyle.pct(m))
		return m
	return super.move_mult()


## Moving forward (facing direction) while guarding - Living Fortress advance.
func _guard_advancing() -> bool:
	return guarding and hero.rt != null and hero.rt.guard_forward_fraction() > 0.0 and hero.move_input.length() > 0.2 and hero.move_input.normalized().dot(hero.forward()) > 0.5


func stamina_regen_mult() -> float:
	if guarding and _guard_advancing():
		return 0.35 * float(hero.rt.pv("vb01_living_fortress", "regen_mult", 0.7))
	return 0.35 if guarding else 1.0


func resource_name() -> String:
	return "Resolve"


func resource_value() -> float:
	return resolve


func resource_max() -> float:
	return b.resolve_max


func restore() -> void:
	super.restore()
	resolve = b.resolve_max if unlocked("v_resolve") else 0.0


func gain_resolve(x: float) -> void:
	if not unlocked("v_resolve"):
		return
	resolve = minf(b.resolve_max, resolve + x)
	resolve_idle = 0.0


## true when the skill's Resolve spender is available (skill + Resolve Spending unlocked, enough Resolve)
func _can_spend(i: int) -> bool:
	return unlocked("v_resolve") and resolve >= skills[i].resolve_cost and cd(skills[i].id) <= 0.0


func process(delta: float) -> void:
	fortress_icd = maxf(0.0, fortress_icd - delta)
	if hold_skill != "" and Game.time - hold_t >= HOLD_TO_SPEND:
		var a := hold_skill
		hold_skill = ""
		if a == "skill1":
			_shield_rush(true)
		else:
			_iron_sweep(true)
	if planted and Game.time >= planted_until:
		_end_plant("expired")
	elif planted:
		guarding = true
	super.process(delta)
	combo_reset -= delta
	if combo_reset <= 0.0:
		combo = 0
	last_line_icd -= delta
	resolve_idle += delta
	# Threat aura: the Vanguard constantly draws attention from nearby enemies.
	for e in hero.enemies_within(7.0):
		e.add_threat(hero, b.vanguard_threat_aura * delta)
	if resolve_idle > 8.0:
		resolve = maxf(0.0, resolve - 3.0 * delta)
	if guarding and (hero.runner.is_busy() or not hero.is_held("guard")):
		_lower_guard()
	elif not guarding and hero.is_held("guard") and charging == "" and not hero.runner.is_busy() and hero.can_act():
		_raise_guard(false)
	elif not guarding and hero.is_held("guard") and charging == "" and _retaliation_guard_ok():
		hero.runner.interrupt()
		_raise_guard(false)
		trigger("vk04_retaliation_window", "Guard raised early after the counter")


## Retaliation Window: after a CONNECTING counter, Guard may return once (1 - 20%) of its recovery has
## passed (Redirected Force synergy: 30%). Never during startup / hit frames.
func _retaliation_guard_ok() -> bool:
	var r := hero.runner
	if not r.is_busy() or r.phase != AttackRunner.Phase.RECOVERY or not r.ctx.has("guard_return"):
		return false
	return r.time_in_recovery() >= r.data.recovery * float(r.ctx.guard_return)


# ------------------------------------------------------------------ input
func on_press(action: String) -> void:
	match action:
		"guard":
			if charging == "" and hero.can_act():
				hero.runner.interrupt()
				_raise_guard(true)
		"light":
			if not hero.can_act():
				hero.buffer(action)
				return
			if Game.time < counter_until and unlocked("v_counter"):
				_lower_guard()
				_counter()
			elif _echo_strike():
				_lower_guard()
			elif (guarding or hero.is_held("guard")) and not planted and unlocked("v_guarded_strike"):
				_guarded_strike()
			else:
				_lower_guard()
				_light()
		"heavy":
			if not hero.can_act():
				hero.buffer(action)
				return
			_lower_guard()
			_heavy()
		"skill1":
			if not unlocked("shield_rush"):
				locked_msg("shield_rush")
			elif _can_spend(0):
				hold_skill = "skill1"
				hold_t = Game.time
			else:
				_shield_rush(false)
		"skill2":
			if unlocked("judgment_strike"):
				_judgment_press()
			else:
				locked_msg("judgment_strike")
		"skill3":
			if not unlocked("iron_sweep"):
				locked_msg("iron_sweep")
			elif _can_spend(2):
				hold_skill = "skill3"
				hold_t = Game.time
			else:
				_iron_sweep(false)
		"core":
			if planted:
				_end_plant("voluntary")
			elif unlocked("v_shield_plant"):
				_shield_plant()
			else:
				locked_msg("v_shield_plant")


func on_release(action: String) -> void:
	if hold_skill != "" and action == hold_skill:
		hold_skill = ""
		if action == "skill1":
			_shield_rush(false)
		else:
			_iron_sweep(false)
		return
	if action == "guard":
		if not planted:
			_lower_guard()
	elif action == "skill2" and charging == "skill2":
		_judgment_release()


func _raise_guard(fresh: bool) -> void:
	guarding = true
	guard_start = Game.time if fresh else -10.0
	guard_perfect_ok = fresh and (Game.time - guard_release_time) >= b.perfect_guard_rearm
	hero.play_anim("guard")


func _lower_guard() -> void:
	if guarding:
		guarding = false
		guard_release_time = Game.time
		if not hero.runner.is_busy():
			hero.play_anim("idle")


# ------------------------------------------------------------------ basic attacks
func _light() -> void:
	var d := load_attack("v_light1" if combo % 2 == 0 else "v_light2")
	combo += 1
	combo_reset = 1.0
	_attack(d, {})


func _heavy() -> void:
	combo = 0
	# Aegis Reversal (Counterguard anchor): after a Perfect Guard the Heavy becomes the Reversal counter
	if hero.rt and hero.rt.has("vk01_aegis_reversal") and hero.rt.take_reversal():
		counter_until = -10.0       # one Perfect Guard = one counter (LMB counter OR the Reversal)
		var d := load_attack("v_heavy").clone()
		d.display_name = "Aegis Reversal"
		d.anim_style = "bash"
		var rm := float(hero.rt.pv("vk01_aegis_reversal", "reach_mult", 0.9))
		d.hitbox_offset.z *= rm
		d.hitbox_size.z *= rm
		d.add_tag("shield")
		trigger("vk01_aegis_reversal", "Reversal counter: +%d%% Poise, %d%% reach" % [roundi(float(hero.rt.pv("vk01_aegis_reversal", "poise_bonus", 0.3)) * 100.0), roundi(rm * 100.0)])
		_attack(d, {"reversal": true, "counter": true})
		return
	_attack(load_attack("v_heavy"), {})


## Judgment Echo: one distinct follow-up strike after a connecting counter (65% damage, 20% longer recovery).
func _echo_strike() -> bool:
	if hero.rt == null or not hero.rt.active("vk05"):
		return false
	var w := hero.rt.take("vk05")
	var d := load_attack("v_counter").clone()
	d.damage_mult *= float(hero.rt.pv("vk05_judgment_echo", "damage_share", 0.65))
	d.recovery *= float(hero.rt.pv("vk05_judgment_echo", "recovery_mult", 1.2))
	d.display_name = "Echo Strike"
	# after an Aegis Reversal the echo uses the alternate (rising) follow-up animation - never a second automatic hit
	d.anim_style = "rising" if w.get("reversal", false) else "slash_v"
	d.add_tag("shield")
	trigger("vk05_judgment_echo", "Echo Strike (%d%% damage)" % roundi(float(hero.rt.pv("vk05_judgment_echo", "damage_share", 0.65)) * 100.0))
	_attack(d, {"echo": true})
	return true


## Guarded Strike: short sword strike FROM Guard. Guard stays raised but its coverage is reduced
## during the swing (modify_incoming); normal Guard returns after recovery if Guard is still held.
func _guarded_strike() -> void:
	var d := load_attack("v_guarded_strike")
	guarding = true
	guard_perfect_ok = false
	_attack(d, {"guarded_strike": true})


func _shield_plant() -> void:
	if cd("v_shield_plant") > 0.0:
		if hero.is_player:
			Events.notify.emit("Shield Plant on cooldown (%.1fs)" % cd("v_shield_plant"))
		return
	if not hero.can_act() or hero.stamina < b.shield_plant_stamina:
		return
	hero.use_stamina(b.shield_plant_stamina)
	hero.runner.interrupt()
	planted = true
	planted_until = Game.time + b.shield_plant_duration
	guarding = true
	guard_perfect_ok = false
	set_cd("v_shield_plant", b.shield_plant_cooldown)
	hero.play_anim("guard")
	FX.burst(hero.global_position + hero.forward() * 0.7 + Vector3(0, 0.4, 0), 1.0, Color(1.0, 0.85, 0.5), 0.25)
	Events.log_message.emit("Shield Plant (%.0fs)" % b.shield_plant_duration, "guard")


func _end_plant(reason: String) -> void:
	if not planted:
		return
	planted = false
	guarding = hero.is_held("guard")
	if reason != "broken":
		start_attack(load_attack("v_plant_exit"), {"plant_exit": true})
	Events.log_message.emit("Shield Plant ended (%s)" % reason, "guard")


func _counter() -> void:
	counter_until = -10.0
	var ctx := {"counter": true}
	# Redirected Force: after Perfect-Guarding a charging attack, A / D steps 0.8m aside before countering
	if hero.rt and hero.rt.has("vk03_redirected_force") and hero.rt.active("vk03") and hero.rt.ready("vk03_cd") and hero.move_input.length() > 0.2:
		var side := hero.forward().cross(Vector3.UP).normalized()
		var s := signf(hero.move_input.dot(side))
		if absf(hero.move_input.normalized().dot(side)) > 0.5:
			hero.rt.take("vk03")
			hero.rt.use_cd("vk03_cd", float(hero.rt.pv("vk03_redirected_force", "cooldown", 10.0)))
			hero.knock_velocity += side * s * sqrt(36.0 * float(hero.rt.pv("vk03_redirected_force", "distance", 0.8)))
			ctx["redirected"] = true
			trigger("vk03_redirected_force", "Lateral reposition %.1fm before the counter" % float(hero.rt.pv("vk03_redirected_force", "distance", 0.8)))
	_attack(load_attack("v_counter"), ctx)
	Events.log_message.emit("Vanguard: Aegis Counter!", "guard")


func _attack(d: AttackData, ctx: Dictionary) -> void:
	var dd := d
	if dd.is_heavy and Game.time < reprisal_until and aug("iron_reprisal") > 0:
		dd = d.clone()
		dd.hitbox_size *= Vector3(1.35, 1.0, 1.3)
		dd.display_name += " (Reprisal)"
	_offense_ctx(dd, ctx)
	start_attack(dd, ctx)


## Augment interactions on outgoing attacks. Iron Reprisal = additive bonuses;
## Crushing Rhythm poise = EXPLICITLY multiplicative with other poise bonuses.
func _offense_ctx(d: AttackData, ctx: Dictionary) -> Dictionary:
	var dmg_mult := float(ctx.get("damage_mult", 1.0))
	var poise_add := 0.0
	var poise_mult := 1.0
	if d.is_heavy and Game.time < reprisal_until and aug("iron_reprisal") > 0:
		dmg_mult += float(ap("iron_reprisal", "damage_bonus", 0.6))
		poise_add += float(ap("iron_reprisal", "poise_bonus", 0.5))
		reprisal_until = -10.0
		ctx["reprisal"] = true
		trigger("iron_reprisal", "Empowered %s (+%d%% dmg, +%d%% poise, wider)" % [d.display_name, roundi(ap("iron_reprisal", "damage_bonus", 0.6) * 100), roundi(ap("iron_reprisal", "poise_bonus", 0.5) * 100)])
	if crushing_ready and aug("crushing_rhythm") > 0:
		crushing_ready = false
		poise_mult *= float(ap("crushing_rhythm", "poise_mult", 1.75))
		trigger("crushing_rhythm", "%s poise damage x%.2f" % [d.display_name, poise_mult * (1.0 + poise_add)])
	ctx["damage_mult"] = dmg_mult
	ctx["poise_mult"] = (1.0 + poise_add) * poise_mult
	return ctx


# ------------------------------------------------------------------ skills
func skill_ready(i: int) -> bool:
	return cd(skills[i].id) <= 0.0


func _cd_msg(s: SkillData) -> void:
	if hero.is_player:
		Events.notify.emit("%s on cooldown (%.1fs)" % [s.display_name, cd(s.id)])


func _shield_rush(spend: bool) -> void:
	var s: SkillData = skills[0]
	if cd(s.id) > 0.0:
		_cd_msg(s)
		return
	if not hero.can_act():
		hero.buffer("skill1")
		return
	_lower_guard()
	var ally = endangered_ally() if unlocked("v_intercept") else null
	var d: AttackData = s.attack
	var ctx := {"skill": s.id}
	if ally != null:
		d = s.attack.clone()
		var dist: float = hero.global_position.distance_to(ally.global_position)
		d.lunge = clampf(dist - 1.3, 1.0, 9.0) / maxf(d.active, 0.05)
		d.display_name = "Shield Rush (Interception)"
		ctx["intercept_ally"] = ally
		# Guardian's Reach: longer interception reach costs 10% more stamina
		if hero.rt and hero.rt.has("vc01_guardians_reach"):
			d.stamina_cost *= float(hero.rt.pv("vc01_guardians_reach", "cost_mult", 1.1))
	elif spend and _can_spend(0):
		resolve -= s.resolve_cost
		d = s.alt_attack
		ctx["empowered"] = true
		ctx["taunt"] = true
		Events.log_message.emit("EMPOWERED SHIELD RUSH (30 Resolve)", "guard")
	# Shielded Advance (Bulwark): a shorter defensive advance with stronger frontal protection
	if hero.rt and hero.rt.has("vb02_shielded_advance"):
		d = d.clone()
		d.lunge *= float(hero.rt.pv("vb02_shielded_advance", "travel_mult", 0.8))
		d.frontal_guard = minf(d.frontal_guard + float(hero.rt.pv("vb02_shielded_advance", "frontal_add_pp", 0.15)), float(hero.rt.pv("vb02_shielded_advance", "cap", 0.9)))
		d.display_name += " (Shielded Advance)"
		trigger("vb02_shielded_advance", "Shield Rush: %d%% travel, frontal reduction %d%%" % [roundi(float(hero.rt.pv("vb02_shielded_advance", "travel_mult", 0.8)) * 100.0), roundi(d.frontal_guard * 100.0)])
	_offense_ctx(d, ctx)
	start_attack(d, ctx)
	if ally != null:
		hero.face_dir(ally.global_position - hero.global_position)
		# Interception stance starts with the rush: any blow aimed at the ally while the Vanguard is
		# within intercept range is taken by the Vanguard instead.
		ally.protector = hero
		ally.protector_until = Game.time + d.total_time() + b.intercept_duration
		Events.log_message.emit("Vanguard rushes to intercept for %s" % ally.display_name, "guard")
	set_cd(s.id, s.cooldown)


func endangered_ally():
	var aim := hero.move_input if hero.move_input.length() > 0.2 else hero.forward()
	var best = null
	var best_d := INF
	for h in hero.allies(false):
		var to: Vector3 = h.global_position - hero.global_position
		var dist := to.length()
		if dist > 11.0 * (hero.rt.intercept_range_mult() if hero.rt else 1.0) or dist < 0.5:
			continue
		if hero.is_player and rad_to_deg(aim.angle_to(Vector3(to.x, 0, to.z).normalized())) > 70.0:
			continue
		var danger := false
		for e in hero.get_tree().get_nodes_in_group("enemies"):
			if e.is_targetable() and e.target == h and e.is_attacking_now() and e.global_position.distance_to(h.global_position) < 9.0:
				danger = true
				break
		if danger and dist < best_d:
			best_d = dist
			best = h
	return best


func _judgment_press() -> void:
	var s: SkillData = skills[1]
	if cd(s.id) > 0.0:
		_cd_msg(s)
		return
	if not hero.can_act():
		hero.buffer("skill2")
		return
	_lower_guard()
	if Game.time < counter_until:
		counter_until = -10.0
		var d := s.alt_attack.clone()
		var ctx := {"skill": s.id, "riposte": true}
		_offense_ctx(d, ctx)
		start_attack(d, ctx)
		set_cd(s.id, s.cooldown * 0.5)
		Events.log_message.emit("Judgment Strike: RIPOSTE (after Perfect Guard)", "guard")
		return
	begin_charge("skill2", s.attack.charge_time)
	if not hero.is_held("skill2"):
		_judgment_release()


func _judgment_release() -> void:
	var s: SkillData = skills[1]
	var ratio := charge_ratio()
	cancel_charge()
	var d := apply_charge(s.attack, ratio)
	var ctx := {"skill": s.id, "charge": ratio}
	if ratio >= 0.99 and unlocked("v_resolve") and resolve >= s.resolve_cost:
		resolve -= s.resolve_cost
		d.hitbox_size *= Vector3(1.7, 1.0, 1.5)
		d.poise_damage *= 1.5
		d.display_name = "Verdict Strike"
		d.recovery += 0.15      # appropriate commitment
		ctx["verdict"] = true
		Events.log_message.emit("VERDICT STRIKE (40 Resolve)", "guard")
		if aug("verdict_of_steel") > 0:
			d.poise_damage *= float(ap("verdict_of_steel", "poise_mult", 2.2))
			d.damage_mult *= float(ap("verdict_of_steel", "damage_mult", 0.7))
			d.display_name = "Verdict of Steel"
			trigger("verdict_of_steel", "Resolve Judgment became a Poise finisher")
	_attack(d, ctx)
	set_cd(s.id, s.cooldown)


func _iron_sweep(spend: bool) -> void:
	var s: SkillData = skills[2]
	if cd(s.id) > 0.0:
		_cd_msg(s)
		return
	if not hero.can_act():
		hero.buffer("skill3")
		return
	var d: AttackData = s.attack
	var ctx := {"skill": s.id}
	if guarding or hero.is_held("guard"):
		d = s.alt_attack
		ctx["guarded"] = true
	if spend and _can_spend(2):
		# Aegis Sweep: area THREAT control, not extra damage
		resolve -= s.resolve_cost
		d = d.clone()
		d.hitbox_size *= Vector3(1.25, 1.0, 1.25)
		d.threat_mult *= 3.0
		d.display_name = "Aegis Sweep"
		ctx["taunt"] = true
		Events.log_message.emit("AEGIS SWEEP (25 Resolve)", "guard")
	_lower_guard()
	_attack(d, ctx)
	set_cd(s.id, s.cooldown)


# ------------------------------------------------------------------ combat hooks
func on_hit_landed(target, info: DamageInfo) -> void:
	var ctx: Dictionary = hero.runner.ctx
	if ctx.get("guarded_strike", false) and not ctx.get("resolve_given", false) and target is Enemy and target.team != hero.team and unlocked("v_resolve"):
		ctx["resolve_given"] = true
		gain_resolve(b.resolve_on_guarded_strike)
		guarded_strike_hits += 1
	if ctx.get("taunt", false) and target.has_method("taunt"):
		target.taunt(hero)
	if ctx.get("counter", false) and info.hit_index == 0 and not ctx.get("resolve_given", false):
		ctx["resolve_given"] = true
		gain_resolve(b.resolve_on_counter)


func on_attack_finished(d: AttackData, ctx: Dictionary, interrupted: bool) -> void:
	if ctx.get("guarded_strike", false):
		# normal Guard returns after the legal recovery if Guard is still held
		guarding = hero.is_held("guard")
		if guarding:
			hero.play_anim("guard")
	if interrupted:
		return
	if d.hits >= 2 and hero.runner.connected_hits() >= d.hits and aug("crushing_rhythm") > 0:
		crushing_ready = true
		trigger("crushing_rhythm", "%s landed all %d hits - next attack gains crushing poise" % [d.display_name, d.hits])
	if ctx.get("skill", "") == "shield_rush":
		var ally = ctx.get("intercept_ally", null)
		if ally != null and is_instance_valid(ally) and ally.global_position.distance_to(hero.global_position) <= b.intercept_range:
			ally.protector = hero
			ally.protector_until = Game.time + b.intercept_duration
			Events.log_message.emit("Vanguard is guarding %s (interception ready %.1fs)" % [ally.display_name, b.intercept_duration], "guard")
		if aug("phantom_bulwark") > 0:
			var hp_v: float = hero.max_hp * float(ap("phantom_bulwark", "hp_pct", 0.4)) * (1.0 + hero.stats.fortitude * 0.02)
			Barrier.spawn(hero, hero.global_position, float(ap("phantom_bulwark", "radius", 3.5)), hp_v, float(ap("phantom_bulwark", "duration", 6.0)))
			trigger("phantom_bulwark", "Shield Rush left a barrier (%d HP)" % roundi(hp_v))


func try_intercept(info: DamageInfo, ally: Node) -> bool:
	if hero.downed or hero.dead or not hero.visible:
		return false
	if hero.global_position.distance_to(ally.global_position) > b.intercept_range * (hero.rt.intercept_range_mult() if hero.rt else 1.0):
		return false
	var redirected := info.copy()
	redirected.target = hero
	redirected.forced_guard = true
	gain_resolve(b.resolve_on_intercept)
	Events.guard_event.emit(hero, info, "intercept")
	if aug("last_line") > 0 and last_line_icd <= 0.0:
		last_line_icd = float(ap("last_line", "icd", 6.0))
		var red := float(ap("last_line", "damage_reduction", 0.35))
		var e := StatusEffect.make("last_line", "Last Line", "buff", float(ap("last_line", "duration", 5.0)), {"damage_taken": 1.0 - red, "poise_taken": 0.4})
		e.source = hero
		hero.statuses.add(e.scaled_by(hero.stats.effect_power()))
		trigger("last_line", "Interception grants Last Line (-%d%% damage taken)" % roundi(red * 100))
	hero.take_damage(redirected)
	if aug("guardians_reserve") > 0 and unlocked("v_resolve") and resolve >= float(ap("guardians_reserve", "cost", 20.0)):
		resolve -= float(ap("guardians_reserve", "cost", 20.0))
		ally.add_shield(ally.max_hp * float(ap("guardians_reserve", "hp_frac", 0.12)), float(ap("guardians_reserve", "duration", 3.0)), hero)
		trigger("guardians_reserve", "20 Resolve -> brief protection on %s" % ally.display_name)
		Events.combat_notice.emit("PROTECTED", ally)
	if aug("guardians_return") > 0 and unlocked("v_counter"):
		counter_until = Game.time + float(ap("guardians_return", "window", 1.5))
		trigger("guardians_return", "Interception opened an Aegis Counter")
		if hero.is_player:
			Events.notify.emit("GUARDIAN'S RETURN  -  counter ready (LMB)")
	return true


## Dodge while planted: Rolling Fortress = short reposition that KEEPS the plant; otherwise Dodge
## exits the plant through its recovery (the roll itself still happens).
func dodge_override() -> bool:
	if not planted:
		return false
	if aug("rolling_fortress") <= 0 or fortress_icd > 0.0:
		_end_plant("dodge")
		return false
	if hero.stamina < float(ap("rolling_fortress", "stamina", 10.0)):
		return true
	var cost := float(ap("rolling_fortress", "stamina", 10.0))
	if hero.stamina < cost:
		return false
	var dir: Vector3 = hero.move_input
	dir.y = 0
	if dir.length() < 0.1:
		dir = -hero.forward()
	hero.use_stamina(cost)
	fortress_icd = float(ap("rolling_fortress", "icd", 0.6))
	hero.knock_velocity += dir.normalized() * float(ap("rolling_fortress", "distance_speed", 7.0))
	trigger("rolling_fortress", "Planted reposition")
	return true


func modify_incoming(info: DamageInfo) -> void:
	var raw := info.amount
	var striking: bool = hero.runner.is_busy() and hero.runner.data != null and hero.runner.data.has_tag("guarded_strike")
	var angle := b.guard_frontal_angle
	if planted:
		angle = b.shield_plant_frontal_angle
	elif striking:
		angle = b.guarded_strike_frontal_angle
	var frontal := hero.is_frontal(info.source_pos, angle)
	if planted:
		info.knockback *= 0.2       # displacement resistance (all directions)
	if not guarding and not info.forced_guard:
		if info.is_dot or not frontal:
			return
		var rd := hero.runner.data
		if hero.runner.is_busy() and rd and rd.frontal_guard > 0.0:
			info.amount *= 1.0 - rd.frontal_guard
			info.poise *= 0.3
		var charge_state := charging == "skill2" or (hero.runner.is_busy() and rd != null and rd.has_tag("charge_attack"))
		if charge_state and aug("unyielding_charge") > 0:
			info.amount *= 1.0 - float(ap("unyielding_charge", "reduction", 0.5))
			info.poise = 0.0
			Events.guard_event.emit(hero, info, "frontal")
			trigger("unyielding_charge", "Frontal hit reduced during charge (%d -> %d)" % [roundi(raw), roundi(info.amount)])
		return
	if info.is_dot:
		return
	if not info.forced_guard and not frontal:
		return
	var steadfast := clampf(1.0 - float(ap("steadfast", "stamina_reduction", 0.25)) * aug("steadfast"), 0.2, 1.0)
	if aug("steadfast") > 0:
		trigger("steadfast", "Guard stamina cost x%.2f" % steadfast)
	var window := b.perfect_guard_window * (1.35 if unlocked("v_bulwark_mastery") else 1.0) + (hero.rt.perfect_window_bonus() if hero.rt else 0.0)
	var perfect := guard_perfect_ok and not info.forced_guard and (Game.time - guard_start) <= window
	info.guarded = true
	if perfect:
		info.perfect = true
		info.amount = raw * (1.0 - b.perfect_guard_reduction)
		info.poise = 0.0
		hero.use_stamina(raw * b.guard_stamina_per_damage * b.perfect_guard_stamina_mult * steadfast)
		gain_resolve(b.resolve_on_perfect)
		counter_until = Game.time + b.counter_window * (1.4 if unlocked("v_bulwark_mastery") else 1.0)
		FX.guard_flash(hero)
		if is_instance_valid(info.source) and info.source.has_method("take_poise") and not info.is_projectile:
			info.source.take_poise(b.perfect_guard_poise_damage)
		if aug("iron_reprisal") > 0:
			reprisal_until = Game.time + float(ap("iron_reprisal", "duration", 6.0))
			trigger("iron_reprisal", "Perfect Guard - next Heavy Attack is empowered")
		Events.guard_event.emit(hero, info, "perfect")
		FX.burst(hero.global_position + Vector3(0, 1.1, 0) + hero.forward() * 0.6, 1.2, Color(1.0, 0.85, 0.3), 0.25)
	elif info.guard_break and not info.forced_guard:
		info.guarded = false
		info.amount = raw * 0.8
		Events.guard_event.emit(hero, info, "break")
		if planted:
			_end_plant("broken")
		guarding = false
		guard_release_time = Game.time
		hero.stagger(1.0)
	else:
		var cost := raw * b.guard_stamina_per_damage * steadfast
		if hero.stamina < cost and not info.forced_guard:
			info.amount = raw * 0.5
			hero.stamina = 0.0
			Events.guard_event.emit(hero, info, "break")
			if planted:
				_end_plant("broken")
			guarding = false
			hero.stagger(0.9)
		else:
			hero.use_stamina(cost)
			var red := b.guard_reduction
			if planted:
				red = b.shield_plant_reduction
			elif striking:
				red = b.guarded_strike_reduction
			info.amount = raw * (1.0 - red)
			info.poise *= 0.05 if planted else 0.15
			# one Resolve gain per defended attack instance (no repeated / recursive generation)
			var key := "%d:%d" % [info.source.get_instance_id() if is_instance_valid(info.source) else 0, int(info.source.attack_serial) if is_instance_valid(info.source) and "attack_serial" in info.source else -1]
			if key != _last_guard_key:
				_last_guard_key = key
				gain_resolve(b.resolve_on_guard)
			if not info.forced_guard:
				Events.guard_event.emit(hero, info, "guard")
	if is_instance_valid(info.source) and info.source.has_method("add_threat"):
		info.source.add_threat(hero, raw * 0.5)


func hud_lines() -> Array:
	var out: Array = []
	var names := ["1", "2", "3"]
	for i in skills.size():
		var s: SkillData = skills[i]
		var c := cd(s.id)
		out.append("[%s] %s %s" % [names[i], s.display_name, "READY" if c <= 0.0 else "%.1fs" % c])
	if planted:
		out.append("SHIELD PLANTED %.1fs (E / Dodge to recover)" % (planted_until - Game.time))
	if unlocked("v_resolve"):
		var sp: Array = []
		if unlocked("shield_rush"):
			sp.append("hold 1: Empowered Rush 30")
		if unlocked("judgment_strike"):
			sp.append("full 2: Verdict 40")
		if unlocked("iron_sweep"):
			sp.append("hold 3: Aegis Sweep 25")
		out.append("Resolve spenders: " + ", ".join(sp))
	if guarding:
		out.append("GUARDING%s" % (" (perfect window)" if guard_perfect_ok and Game.time - guard_start <= b.perfect_guard_window else ""))
	if Game.time < counter_until:
		out.append("COUNTER WINDOW: LMB = Aegis Counter / 2 = Riposte")
	if Game.time < reprisal_until:
		out.append("Iron Reprisal: next Heavy empowered")
	if crushing_ready:
		out.append("Crushing Rhythm primed")
	if charging == "skill2":
		out.append("Charging Judgment %d%%" % roundi(charge_ratio() * 100))
	return out
