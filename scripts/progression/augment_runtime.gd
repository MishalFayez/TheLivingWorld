class_name AugmentRuntime
extends Node
## LEVEL10-FOUNDATION-005 Part 6: runtime of the curated Level 1-10 augment pool (60 cards). One instance per
## hero. The class kits call narrow hooks (prepare_attack, stamina_mult, modify_outgoing, mana_mult, ...);
## everything else listens to the global Events bus. Every tunable value is read from the card's .tres
## params (data-driven). Rules enforced here for every card:
##   - cooldowns / internal cooldowns are real (Game.time based)
##   - secondary effects are tagged "aug_secondary" and never trigger augments again (no recursion)
##   - multi-hit attacks pay a refund / bonus once per ACTION, not per hit
##   - every activation is visible: combat log (augment_triggered) + a short floating label for the player

const SECONDARY := "aug_secondary"
## Vanguard strikes delivered with the shield (Fortress Breaker): Aegis Counter (shield-and-sword), Shield Rush
const SHIELD_ATTACKS := ["v_counter", "v_shield_rush", "v_shield_rush_emp"]

var hero: Hero
var cds: Dictionary = {}          # key -> Game.time when ready again
var windows: Dictionary = {}      # key -> {until, ...data}
var counts: Dictionary = {}       # augment id -> activations (diagnostics / balance)
var _echo: Dictionary = {}        # target instance id -> {n, last_action}
var _action_serial: int = 0
var _was_staggered: bool = false
var _last_element: Dictionary = {} # element -> last cast time (Elemental Memory)
var _prev_cast_element: String = ""
var _last_spell_id: String = ""
var _last_spell_full: bool = false
var _link: Dictionary = {}        # Sympathetic Link {ally, enemy, until}


func setup(h: Hero) -> void:
	hero = h
	name = "AugmentRuntime"
	Events.damage_applied.connect(_on_damage_applied)
	Events.healed.connect(_on_healed)
	Events.guard_event.connect(_on_guard_event)
	Events.spell_released.connect(_on_spell_released)
	Events.elemental_interaction.connect(_on_interaction)
	Events.spell_slot_changed.connect(_on_slot_changed)
	hero.runner.recovery_started.connect(_on_recovery_started)
	hero.runner.started.connect(func(_d, _c): _action_serial += 1)


# ------------------------------------------------------------------ helpers
func has(id: String) -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	var a: AugmentData = Game.augment_db.get_augment(id)
	if a == null or a.blocked_reason != "":
		return false
	if a.class_id != "global" and a.class_id != hero.class_id:
		return false
	if a.class_id == "global" and a.blocked_classes.has(hero.class_id):
		return false
	return hero.prog().augment_stacks(id) > 0


func pv(id: String, key: String, default_value = 0.0):
	var a: AugmentData = Game.augment_db.get_augment(id)
	return a.params.get(key, default_value) if a else default_value


func ready(key: String) -> bool:
	return Game.time >= float(cds.get(key, -100.0))


func use_cd(key: String, sec: float) -> void:
	cds[key] = Game.time + sec


func open(key: String, sec: float, data: Dictionary = {}) -> void:
	var w := data.duplicate()
	w["until"] = Game.time + sec
	windows[key] = w


func active(key: String) -> bool:
	return windows.has(key) and Game.time <= float(windows[key].until)


func take(key: String) -> Dictionary:
	if not active(key):
		windows.erase(key)
		return {}
	var w: Dictionary = windows[key]
	windows.erase(key)
	return w


func fire(id: String, detail: String) -> void:
	counts[id] = int(counts.get(id, 0)) + 1
	Events.augment_triggered.emit(hero, id, detail)
	if hero.is_player:
		var a: AugmentData = Game.augment_db.get_augment(id)
		FX.number(hero, (a.display_name if a else id).to_upper(), Color(0.85, 0.75, 1.0), 0.75)
		PlaceholderSfx.play(hero, "augment")


func _is_enemy(t) -> bool:
	return t != null and is_instance_valid(t) and t is Enemy


func _recovering(t) -> bool:
	return _is_enemy(t) and ReaverFreeFlow.in_attack_recovery(t)


func _class() -> String:
	return hero.class_id


func _ally_ok(a) -> bool:
	return a != null and is_instance_valid(a) and a is Hero and not a.dead and not a.downed


func _secondary(info: DamageInfo) -> bool:
	return info.tags.get(SECONDARY, false)


static func runtime_of(h) -> AugmentRuntime:
	return h.get_node_or_null("AugmentRuntime") if h != null and is_instance_valid(h) else null


# ------------------------------------------------------------------ attacks (Vanguard / Reaver)
## Called by ClassKit.start_attack before the attack runs. Returns the attack to run (a clone when changed).
func prepare_attack(d: AttackData, ctx: Dictionary) -> AttackData:
	var out := d
	# G04 Calculated Risk: explicitly tagged committed actions only
	if has("g04_calculated_risk") and (d.has_tag("committed") or String(pv("g04_calculated_risk", "committed_ids", "")).split(",").has(d.id)) and not ctx.get("risk", false):
		out = out.clone() if out == d else out
		out.damage_mult *= float(pv("g04_calculated_risk", "power_mult", 1.2))
		ctx["risk"] = true
		ctx["risk_recovery"] = float(pv("g04_calculated_risk", "fail_recovery_mult", 1.2))
	# R-C03 Measured Blade: next eligible attack recovers faster (never inside committed hit frames)
	if active("rc03") and d.hits > 0 and not d.has_tag("spell"):
		take("rc03")
		out = out.clone() if out == d else out
		out.recovery *= float(pv("rc03_measured_blade", "recovery_mult", 0.85))
		out.cancel_after = minf(out.cancel_after, out.recovery)
		fire("rc03_measured_blade", "%s recovery x%.2f" % [d.display_name, float(pv("rc03_measured_blade", "recovery_mult", 0.85))])
	# A-K04-style guard return / others are handled by the kits
	return out


## Stamina multiplier for an attack about to start (consumes one-shot discounts).
func stamina_mult(d: AttackData, ctx: Dictionary) -> float:
	var m := 1.0
	if d.stamina_cost <= 0.0 or d.has_tag("spell"):
		return m
	if active("g01"):
		take("g01")
		m *= float(pv("g01_second_wind", "stamina_mult", 0.75))
		fire("g01_second_wind", "%s costs %s less stamina" % [d.display_name, StatStyle.pct(1.0 - float(pv("g01_second_wind", "stamina_mult", 0.75)))])
	var kind := String(ctx.get("kind", ""))
	var directional := kind in ["dance_forward", "dance_lateral"]
	var whirl_ok := kind == "whirl" and has("rd05_tempest_waltz")
	if active("rd02") and (directional or whirl_ok):
		take("rd02")
		m *= float(pv("rd02_flowing_steps", "stamina_mult", 0.75))
		fire("rd02_flowing_steps", "%s costs %s less stamina%s" % [d.display_name, StatStyle.pct(1.0 - float(pv("rd02_flowing_steps", "stamina_mult", 0.75))), " (Tempest Waltz synergy)" if whirl_ok else ""])
	return m


func modify_outgoing(info: DamageInfo, d: AttackData, target, idx: int, ctx: Dictionary) -> void:
	if not _is_enemy(target):
		return
	var kind := String(ctx.get("kind", ""))
	var recovering := _recovering(target)
	# Poise bonuses vs recovering targets (Edge): Clean Execution + Fracturing Edge capped at +50% combined
	var poise_bonus := 0.0
	if kind == "precision" and recovering and has("rc06_clean_execution"):
		var key := "rc06:%d" % target.get_instance_id()
		if ready(key) or ctx.get("rc06", false):
			if not ctx.get("rc06", false):
				use_cd(key, float(pv("rc06_clean_execution", "cd_per_target", 5.0)))
				ctx["rc06"] = true
				fire("rc06_clean_execution", "Precision Cut on a recovering %s: +%s Poise" % [target.display_name, StatStyle.pct(float(pv("rc06_clean_execution", "poise_bonus", 0.25)))])
			poise_bonus += float(pv("rc06_clean_execution", "poise_bonus", 0.25))
	if kind == "break" and recovering and has("re03_fracturing_edge"):
		poise_bonus += float(pv("re03_fracturing_edge", "poise_bonus", 0.3))
		if idx == 0 and not ctx.get("re03", false):
			ctx["re03"] = true
			fire("re03_fracturing_edge", "Breaking Point vs a recovering enemy: +%s Poise" % StatStyle.pct(float(pv("re03_fracturing_edge", "poise_bonus", 0.3))))
	if poise_bonus > 0.0:
		var cap := 0.5 if (has("rc06_clean_execution") and has("re03_fracturing_edge")) else 99.0
		info.poise *= 1.0 + minf(poise_bonus, cap)
	# V-B05 Fortress Breaker: next shield-based strike +35% (45% with Heavy Anchor) Poise
	if (d.has_tag("shield") or SHIELD_ATTACKS.has(d.id)) and active("vb05") and idx == 0:
		var w := take("vb05")
		info.poise *= 1.0 + float(w.get("bonus", 0.35))
		fire("vb05_fortress_breaker", "%s: +%s Poise" % [d.display_name, StatStyle.pct(float(w.get("bonus", 0.35)))])
	# V-K01 Aegis Reversal transformed heavy (+30% Poise, set by the kit through ctx)
	if ctx.get("reversal", false):
		info.poise *= 1.0 + float(pv("vk01_aegis_reversal", "poise_bonus", 0.3))


func on_hit_landed(target, info: DamageInfo) -> void:
	if not _is_enemy(target) or _secondary(info):
		return
	var ctx: Dictionary = hero.runner.ctx
	var d: AttackData = hero.runner.data
	if d == null:
		return
	ctx["hit"] = true
	var kind := String(ctx.get("kind", ""))
	var first: bool = not ctx.get("aug_first_hit", false)
	ctx["aug_first_hit"] = true
	if first:
		_common_hit(target, info, "attack:%d" % _action_serial)
	# R-C02 Swordsman's Breath (once per Precision Cut)
	if first and kind == "precision" and has("rc02_swordsmans_breath") and ready("rc02"):
		use_cd("rc02", float(pv("rc02_swordsmans_breath", "cooldown", 4.0)))
		var st := float(pv("rc02_swordsmans_breath", "stamina", 3.0))
		hero.stamina = minf(hero.max_stamina, hero.stamina + st)
		fire("rc02_swordsmans_breath", "+%d stamina" % roundi(st))
	# R-C01 Seamless Steel: a connecting Dance attack opens the mobile Precision transition
	if first and kind.begins_with("dance_") and has("rc01_seamless_steel") and ready("rc01"):
		open("rc01", float(pv("rc01_seamless_steel", "window", 2.0)))
	# R-C04 Close Pursuit: armed by a connecting attack; the next Forward Dance checks the gap itself
	if first and kind != "" and has("rc04_close_pursuit"):
		open("rc04", float(pv("rc04_close_pursuit", "window", 3.0)), {"target": target})
	# R-D03 Circling Predator: a flank hit after a real lateral displacement
	var moved: float = hero.global_position.distance_to(ctx.get("start_pos", hero.global_position))
	if first and has("rd03_circling_predator") and ready("rd03") and (kind == "dance_lateral" or kind == "orbit") and moved >= float(pv("rd03_circling_predator", "min_lateral", 0.5)):
		var to_me: Vector3 = hero.global_position - target.global_position
		to_me.y = 0
		var ang: float = rad_to_deg(target.forward().angle_to(to_me.normalized()))
		if ang >= float(pv("rd03_circling_predator", "flank_angle", 60.0)):
			open("rd03", float(pv("rd03_circling_predator", "window", 2.0)), {"target": target})
			use_cd("rd03", float(pv("rd03_circling_predator", "cooldown", 7.0)))
			fire("rd03_circling_predator", "Flank hit (%.0f deg): Predator follow-up ready (LMB)" % ang)
	# V-K05 Judgment Echo: a connecting counter opens one follow-up
	if first and ctx.get("counter", false) and has("vk05_judgment_echo") and ready("vk05"):
		open("vk05", float(pv("vk05_judgment_echo", "window", 2.0)), {"reversal": ctx.get("reversal", false)})
		use_cd("vk05", float(pv("vk05_judgment_echo", "cooldown", 10.0)))
		fire("vk05_judgment_echo", "Echo Strike ready (LMB)")
	# V-K04 Retaliation Window: a connecting counter returns to Guard sooner
	if first and ctx.get("counter", false) and has("vk04_retaliation_window"):
		ctx["guard_return"] = float(pv("vk04_retaliation_window", "guard_delay_mult", 0.8))
		if ctx.get("redirected", false) and has("vk03_redirected_force"):
			ctx["guard_return"] = float(pv("vk04_retaliation_window", "synergy_mult", 0.7))
	# V-B06 Sheltering Counter / V-K06 Guardian's Retort: counter right after protecting an ally
	if first and ctx.get("counter", false):
		var prot := take("protected") if (has("vb06_sheltering_counter") or has("vk06_guardians_retort")) else {}
		var ally = prot.get("ally")
		if _ally_ok(ally):
			if has("vb06_sheltering_counter") and ready("vb06"):
				use_cd("vb06", float(pv("vb06_sheltering_counter", "cooldown", 8.0)))
				_give_shield(ally, hero.max_hp * float(pv("vb06_sheltering_counter", "shield_frac", 0.05)), float(pv("vb06_sheltering_counter", "duration", 4.0)), "vb06_sheltering_counter")
			if has("vk06_guardians_retort") and ready("vk06"):
				use_cd("vk06", float(pv("vk06_guardians_retort", "cooldown", 8.0)))
				var amt := minf(info.raw_amount * float(pv("vk06_guardians_retort", "share", 0.2)), ally.max_hp * float(pv("vk06_guardians_retort", "cap_frac", 0.08)))
				_give_shield(ally, amt, float(pv("vk06_guardians_retort", "duration", 4.0)), "vk06_guardians_retort")


## G02 / G03: shared "connecting offensive action" rules for attacks AND spells.
func _common_hit(target, info: DamageInfo, action_key: String) -> void:
	# G02 Measured Recovery
	var was_recovering: bool = info.tags.get("target_recovering", false) or _recovering(target)
	if has("g02_measured_recovery") and was_recovering and ready("g02"):
		use_cd("g02", float(pv("g02_measured_recovery", "cooldown", 5.0)))
		if _class() == "mage" and hero.kit is MageKit:
			var mn := float(pv("g02_measured_recovery", "mana", 4.0))
			hero.kit.mana = minf(hero.kit.resource_max(), hero.kit.mana + mn)
			fire("g02_measured_recovery", "Hit during recovery: +%d mana" % roundi(mn))
		else:
			var st := float(pv("g02_measured_recovery", "stamina", 5.0))
			hero.stamina = minf(hero.max_stamina, hero.stamina + st)
			fire("g02_measured_recovery", "Hit during recovery: +%d stamina" % roundi(st))
	# R-C03 Measured Blade arms on a recovery hit
	if has("rc03_measured_blade") and was_recovering and ready("rc03") and _class() == "reaver":
		use_cd("rc03", float(pv("rc03_measured_blade", "cooldown", 6.0)))
		open("rc03", float(pv("rc03_measured_blade", "window", 3.0)))
	# G03 Echoing Impact: third separate connecting action on the same target
	if has("g03_echoing_impact"):
		var k: int = target.get_instance_id()
		var e: Dictionary = _echo.get(k, {"n": 0, "last": ""})
		if String(e.last) != action_key:
			e.n = int(e.n) + 1
			e.last = action_key
		_echo[k] = e
		if int(e.n) >= int(pv("g03_echoing_impact", "actions", 3)) and ready("g03"):
			_echo[k] = {"n": 0, "last": action_key}
			use_cd("g03", float(pv("g03_echoing_impact", "cooldown", 6.0)))
			var share := float(pv("g03_echoing_impact", "share", 0.25))
			var dmg := info.raw_amount * share
			var magic := info.damage_type == AttackData.DamageType.MAGIC
			var h := hero
			fire("g03_echoing_impact", "Echo on %s in %.1fs (%d)" % [target.display_name, float(pv("g03_echoing_impact", "delay", 0.4)), roundi(dmg)])
			hero.get_tree().create_timer(float(pv("g03_echoing_impact", "delay", 0.4)), false, true).timeout.connect(func():
				if is_instance_valid(h) and is_instance_valid(target) and not target.dead:
					_flat_damage(target, dmg, "Echoing Impact", magic)
					VFX.hit_sparks(target.global_position + Vector3(0, 1.2, 0), Color(0.8, 0.7, 1.0), 12, false))


## Fixed-amount secondary hit (already computed from an eligible direct value): never re-enters augments.
func _flat_damage(target, amount: float, label: String, magic: bool) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = hero
	info.target = target
	info.attack_name = label
	info.damage_type = AttackData.DamageType.MAGIC if magic else AttackData.DamageType.PHYSICAL
	info.amount = amount
	info.raw_amount = amount
	info.poise = 0.0
	info.hitstop = 0.0
	info.knockback = 0.0
	info.source_pos = hero.global_position
	info.tags[SECONDARY] = true
	target.take_damage(info)
	return info


func _give_shield(ally, amount: float, duration: float, id: String) -> void:
	if not _ally_ok(ally) or amount <= 0.0:
		return
	# shields from different cards refresh duration; amounts never stack beyond the larger one (cap)
	var cur: float = ally.shield_hp if ally.has_shield() else 0.0
	var amt := maxf(amount, cur) - cur if (has("vc03_shared_aegis") and has("vb06_sheltering_counter")) else amount
	ally.add_shield(amt, duration, hero)
	fire(id, "%s: shield %d for %.0fs" % [ally.display_name, roundi(maxf(amount, cur)), duration])
	Events.combat_notice.emit("PROTECTED", ally)


func on_attack_finished(d: AttackData, ctx: Dictionary, interrupted: bool) -> void:
	if interrupted or d == null:
		return
	# R-E06 Patient Blade: a FULLY charged Committed Cut that connected (every impact for Twin Verdict)
	if String(ctx.get("kind", "")) == "committed" and has("re06_patient_blade") and float(ctx.get("charge", 0.0)) >= 0.999 and ready("re06"):
		var all_hit: bool = hero.runner.connected_hits() >= maxi(1, d.hits)
		if ctx.get("hit", false) and all_hit:
			use_cd("re06", float(pv("re06_patient_blade", "cooldown", 6.0)))
			var st := float(pv("re06_patient_blade", "stamina", 5.0))
			hero.stamina = minf(hero.max_stamina, hero.stamina + st)
			fire("re06_patient_blade", "Full Committed Cut landed: +%d stamina" % roundi(st))


## G04: a committed action that connected with nothing recovers 20% longer.
func _on_recovery_started(d: AttackData) -> void:
	var ctx: Dictionary = hero.runner.ctx
	if ctx.get("risk", false) and not ctx.get("hit", false) and hero.runner.connected_hits() == 0:
		d.recovery *= float(ctx.get("risk_recovery", 1.2))
		fire("g04_calculated_risk", "%s missed: recovery x%.2f" % [d.display_name, float(ctx.get("risk_recovery", 1.2))])


# ------------------------------------------------------------------ defence
func modify_incoming(info: DamageInfo) -> void:
	if info.is_dot:
		return
	var pm := 1.0
	if hero.kit is VanguardKit and hero.kit.guarding and has("vb04_heavy_anchor"):
		pm *= 1.0 - float(pv("vb04_heavy_anchor", "poise_resist", 0.2))
	if hero.kit.charging == "edge_lmb" and has("re02_steel_focus"):
		pm *= 1.0 - float(pv("re02_steel_focus", "poise_resist", 0.2))
		if info.poise > 0.0:
			fire("re02_steel_focus", "Charging: Poise damage -%s" % StatStyle.pct(float(pv("re02_steel_focus", "poise_resist", 0.2))))
	info.poise *= pm
	if active("vc02") and info.knockback > 0.0 and not info.guarded:
		take("vc02")
		info.knockback *= float(pv("vc02_steel_foundation", "knockback_mult", 0.7))
		fire("vc02_steel_foundation", "Knockback -%s" % StatStyle.pct(1.0 - float(pv("vc02_steel_foundation", "knockback_mult", 0.7))))


## Perfect / well-timed defensive dodge: i-frames avoided a REAL attack.
func on_perfect_dodge(info: DamageInfo) -> void:
	if info == null or not _is_enemy(info.source):
		return
	if has("g01_second_wind") and ready("g01_icd"):
		use_cd("g01_icd", float(pv("g01_second_wind", "cooldown", 6.0)))
		open("g01", float(pv("g01_second_wind", "window", 3.0)))
		if _class() == "mage":
			open("g01_mana", float(pv("g01_second_wind", "window", 3.0)))
			windows.erase("g01")
		fire("g01_second_wind", "Dodged %s: next offensive action is cheaper" % info.source.display_name)
	if has("rd02_flowing_steps") and ready("rd02_cd"):
		use_cd("rd02_cd", float(pv("rd02_flowing_steps", "cooldown", 5.0)))
		open("rd02", float(pv("rd02_flowing_steps", "window", 3.0)))
	if has("rc05_blade_reflex") and ready("rc05"):
		use_cd("rc05", float(pv("rc05_blade_reflex", "cooldown", 6.0)))
		open("rc05", float(pv("rc05_blade_reflex", "window", 2.0)))
		fire("rc05_blade_reflex", "Reflex follow-up ready (LMB)")
	var bd = hero.kit.bd if hero.kit is ReaverKit else null
	if bd != null and bd.last_dodge_kind == "side" and has("rd06_dancers_reversal") and ready("rd06"):
		use_cd("rd06", float(pv("rd06_dancers_reversal", "cooldown", 8.0)))
		open("rd06", float(pv("rd06_dancers_reversal", "window", 2.0)))
		fire("rd06_dancers_reversal", "Side dodge: turning follow-up ready")


func _physics_process(_delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var st := hero.is_staggered()
	if _was_staggered and not st and has("g06_resolute_spirit") and ready("g06"):
		use_cd("g06", float(pv("g06_resolute_spirit", "cooldown", 10.0)))
		var e := StatusEffect.make("resolute_spirit", "Resolute Spirit", "buff", float(pv("g06_resolute_spirit", "duration", 3.0)), {"poise_taken": 1.0 - float(pv("g06_resolute_spirit", "poise_resist", 0.2))})
		e.source = hero
		hero.statuses.add(e)
		fire("g06_resolute_spirit", "Recovered: Poise damage -%s for %.0fs" % [StatStyle.pct(float(pv("g06_resolute_spirit", "poise_resist", 0.2))), e.duration])
	_was_staggered = st


## G05 Near Miss: called by Enemy when one of its attacks ends its active phase. A hero that was the
## attack's target, stood inside its reach + margin and frontal arc, was NOT hit, and avoided it by moving
## (not dodging, no i-frames) gets the speed boost.
static func enemy_attack_resolved(e, d: AttackData, hit_ids: Dictionary) -> void:
	if d == null or d.hits <= 0:
		return
	for h in Game.heroes:
		var rt := runtime_of(h)
		if rt == null or not rt.has("g05_near_miss") or e.target != h or hit_ids.has(h.get_instance_id()):
			continue
		if h.dodging or Game.time - h.last_dodge_end < d.active + 0.2 or h.is_invulnerable():
			continue
		var reach: float = absf(d.hitbox_offset.z) + d.hitbox_size.z * 0.5 + float(rt.pv("g05_near_miss", "margin", 1.0))
		var to: Vector3 = h.global_position - e.global_position
		to.y = 0
		if to.length() > reach or not e.is_frontal(h.global_position, 100.0):
			continue
		if Vector2(h.velocity.x, h.velocity.z).length() < float(rt.pv("g05_near_miss", "min_speed", 1.5)) or not rt.ready("g05"):
			continue
		rt.use_cd("g05", float(rt.pv("g05_near_miss", "cooldown", 8.0)))
		var s := StatusEffect.make("near_miss", "Near Miss", "buff", float(rt.pv("g05_near_miss", "duration", 2.0)), {"move_speed": float(rt.pv("g05_near_miss", "speed_mult", 1.15))})
		s.source = h
		h.statuses.add(s)
		rt.fire("g05_near_miss", "Avoided %s by moving: +%s speed" % [d.display_name, StatStyle.pct(float(rt.pv("g05_near_miss", "speed_mult", 1.15)) - 1.0)])


# ------------------------------------------------------------------ Vanguard
func guard_move_mult() -> float:
	var m := 1.0
	if has("vc04_unyielding_footing"):
		m *= float(pv("vc04_unyielding_footing", "guard_move_mult", 1.15))
	if has("vb04_heavy_anchor"):
		m *= float(pv("vb04_heavy_anchor", "move_mult", 0.9))
	return m


## V-B01 Living Fortress: forward speed while guarding (fraction of normal move speed).
func guard_forward_fraction() -> float:
	return float(pv("vb01_living_fortress", "forward_mult", 0.6)) if has("vb01_living_fortress") else 0.0


func perfect_window_bonus() -> float:
	if active("vk02"):
		return float(pv("vk02_precise_defense", "extra_window", 0.03))
	return 0.0


func intercept_range_mult() -> float:
	return float(pv("vc01_guardians_reach", "range_mult", 1.2)) if has("vc01_guardians_reach") else 1.0


func _on_guard_event(defender, info, kind: String) -> void:
	if defender != hero:
		return
	match kind:
		"guard", "perfect":
			if has("vc02_steel_foundation"):
				open("vc02", float(pv("vc02_steel_foundation", "window", 3.0)))
			if has("vc06_last_barrier") and ready("vc06") and hero.hp / hero.max_hp < float(pv("vc06_last_barrier", "hp_threshold", 0.35)):
				use_cd("vc06", float(pv("vc06_last_barrier", "cooldown", 20.0)))
				hero.add_shield(hero.max_hp * float(pv("vc06_last_barrier", "shield_frac", 0.08)), float(pv("vc06_last_barrier", "duration", 4.0)), hero)
				fire("vc06_last_barrier", "Guard below %s HP: shield %d" % [StatStyle.pct(float(pv("vc06_last_barrier", "hp_threshold", 0.35))), roundi(hero.max_hp * float(pv("vc06_last_barrier", "shield_frac", 0.08)))])
			if info != null and info.is_heavy and has("vb05_fortress_breaker") and ready("vb05_cd"):
				use_cd("vb05_cd", float(pv("vb05_fortress_breaker", "cooldown", 6.0)))
				var bonus := float(pv("vb05_fortress_breaker", "poise_bonus", 0.35))
				if has("vb04_heavy_anchor"):
					bonus = float(pv("vb05_fortress_breaker", "synergy_bonus", 0.45))
				open("vb05", float(pv("vb05_fortress_breaker", "window", 4.0)), {"bonus": bonus})
				fire("vb05_fortress_breaker", "Heavy blow blocked: next shield strike +%s Poise" % StatStyle.pct(bonus))
			if kind == "perfect":
				_on_perfect_guard(info)
		"intercept":
			_on_intercept(info)


func _on_perfect_guard(info) -> void:
	if has("vk02_precise_defense") and ready("vk02_cd"):
		use_cd("vk02_cd", float(pv("vk02_precise_defense", "cooldown", 10.0)))
		open("vk02", float(pv("vk02_precise_defense", "window", 4.0)))
		fire("vk02_precise_defense", "Next Perfect Guard window +%.2fs" % float(pv("vk02_precise_defense", "extra_window", 0.03)))
	elif active("vk02"):
		take("vk02")   # single use: the widened opportunity was used by this Perfect Guard
	if has("vk01_aegis_reversal"):
		open("vk01", float(pv("vk01_aegis_reversal", "window", 3.0)))
		fire("vk01_aegis_reversal", "Next Heavy Attack becomes the Reversal counter")
	if has("vk03_redirected_force") and info != null and _is_enemy(info.source) and info.source.runner.data != null and info.source.runner.data.lunge > 0.0 and ready("vk03"):
		open("vk03", hero.kit.b.counter_window)
	if has("vb03_bastion_pulse") and ready("vb03"):
		use_cd("vb03", float(pv("vb03_bastion_pulse", "cooldown", 8.0)))
		var r := float(pv("vb03_bastion_pulse", "radius", 3.0))
		var advancing: bool = has("vb01_living_fortress") and hero.move_input.dot(hero.forward()) > 0.5
		if advancing:
			r *= float(pv("vb03_bastion_pulse", "synergy_radius_mult", 1.15))
		var slow := float(pv("vb03_bastion_pulse", "slow", 0.25))
		var n := 0
		for e in hero.enemies_within(r):
			var s := slow * (float(pv("vb03_bastion_pulse", "boss_factor", 0.5)) if e.is_boss else 1.0)
			var st := StatusEffect.make("bastion_slow", "Bastion Pulse", "debuff", float(pv("vb03_bastion_pulse", "duration", 2.0)), {"move_speed": 1.0 - s})
			st.source = hero
			e.statuses.add(st)
			n += 1
		VFX.ground_ring(hero.global_position, r, Color(1.0, 0.85, 0.45), 0.35)
		fire("vb03_bastion_pulse", "Pulse %.1fm slowed %d enemies%s" % [r, n, " (Living Fortress synergy)" if advancing else ""])


func _on_intercept(info) -> void:
	var ally = info.target if info != null else null
	if not _ally_ok(ally) or ally == hero:
		return
	open("protected", float(pv("vb06_sheltering_counter", "window", 3.0)), {"ally": ally})
	if has("vc03_shared_aegis") and ready("vc03"):
		use_cd("vc03", float(pv("vc03_shared_aegis", "cooldown", 8.0)))
		_give_shield(ally, hero.max_hp * float(pv("vc03_shared_aegis", "shield_frac", 0.06)), float(pv("vc03_shared_aegis", "duration", 4.0)), "vc03_shared_aegis")
	if has("vc05_defenders_oath") and ready("vc05"):
		use_cd("vc05", float(pv("vc05_defenders_oath", "cooldown", 8.0)))
		ally.set_meta("oath_guard", hero)
		ally.set_meta("oath_until", Game.time + float(pv("vc05_defenders_oath", "window", 4.0)))
		fire("vc05_defenders_oath", "%s is under the Oath: %s of incoming damage redirected" % [ally.display_name, StatStyle.pct(float(pv("vc05_defenders_oath", "share", 0.25)))])


## V-C05 Defender's Oath: called from Hero.pre_damage of the protected ally. Splits the hit (distance and
## line-of-sight still required). The redirected part is real damage on the Vanguard and cannot redirect.
static func oath_split(ally, info: DamageInfo) -> void:
	if info.tags.get("oath", false) or info.is_dot or info.cancelled:
		return
	var v = ally.get_meta("oath_guard", null)
	if v == null or not is_instance_valid(v) or Game.time > float(ally.get_meta("oath_until", -10.0)) or v.dead or v.downed:
		return
	var rt := runtime_of(v)
	if rt == null or not rt.has("vc05_defenders_oath"):
		return
	if v.global_position.distance_to(ally.global_position) > v.kit.b.intercept_range * rt.intercept_range_mult():
		return
	var q := PhysicsRayQueryParameters3D.create(v.global_position + Vector3(0, 1.2, 0), ally.global_position + Vector3(0, 1.2, 0), Combatant.LAYER_WORLD)
	if not v.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	var share := float(rt.pv("vc05_defenders_oath", "share", 0.25))
	var red := info.copy()
	red.target = v
	red.amount = info.amount * share
	red.raw_amount = red.amount
	red.poise = 0.0
	red.tags["oath"] = true
	red.tags[SECONDARY] = true
	info.amount *= 1.0 - share
	v.take_damage(red)


# ------------------------------------------------------------------ Worldweaver
func mana_mult(s: ChargedSpellData) -> float:
	var m := 1.0
	var offensive := s.element != "life" and s.slot_kind == "charged"
	var support := s.element == "life" or s.slot_kind == "utility"
	if offensive and active("g01_mana"):
		take("g01_mana")
		m *= float(pv("g01_second_wind", "mana_mult", 0.85))
		fire("g01_second_wind", "%s costs %s less mana" % [s.display_name, StatStyle.pct(1.0 - float(pv("g01_second_wind", "mana_mult", 0.85)))])
	if has("mc03_elemental_memory") and ready("mc03") and s.element != _prev_cast_element and _last_element.has(s.element) \
			and Game.time - float(_last_element[s.element]) <= float(pv("mc03_elemental_memory", "memory", 6.0)):
		use_cd("mc03", float(pv("mc03_elemental_memory", "cooldown", 6.0)))
		m *= float(pv("mc03_elemental_memory", "mana_mult", 0.88))
		fire("mc03_elemental_memory", "Returned to %s: %s costs %s less mana" % [s.element.capitalize(), s.display_name, StatStyle.pct(1.0 - float(pv("mc03_elemental_memory", "mana_mult", 0.88)))])
	if support and active("mc04"):
		take("mc04")
		m *= float(pv("mc04_benevolent_casting", "mana_mult", 0.85))
		fire("mc04_benevolent_casting", "%s costs %s less mana" % [s.display_name, StatStyle.pct(1.0 - float(pv("mc04_benevolent_casting", "mana_mult", 0.85)))])
	return m


## Preparation (charge time) multipliers for a spell being charged: {min, full}. Reductions from different
## cards do not compound past the documented caps (Threading + Dual Invocation: 25%).
func charge_mods(s: ChargedSpellData) -> Dictionary:
	var min_m := 1.0
	var full_m := 1.0
	var prep := 0.0
	var offensive := s.element != "life"
	if active("mc05_off") and offensive:
		prep += 1.0 - float(pv("mc05_dual_invocation", "prep_mult", 0.85))
	if active("mc05_heal") and not offensive:
		prep += 1.0 - float(pv("mc05_dual_invocation", "prep_mult", 0.85))
	if active("ma04"):
		prep += 1.0 - float(pv("ma04_swift_invocation", "prep_mult", 0.9))
	var thread := active("ma01") and String(windows["ma01"].get("spell", "")) != s.id
	if thread:
		min_m *= float(pv("ma01_spell_threading", "min_mult", 0.8))
		full_m *= float(pv("ma01_spell_threading", "full_mult", 0.9))
	if prep > 0.0:
		var p := minf(prep, 0.25 if thread else prep)
		min_m *= 1.0 - p
		full_m *= 1.0 - p
	var cap := 0.75
	return {"min": maxf(min_m, cap), "full": maxf(full_m, cap), "thread": thread, "prep": prep}


## Release happened: consume the one-shot preparation windows that applied to this spell.
func consume_charge_mods(s: ChargedSpellData) -> void:
	var offensive := s.element != "life"
	if active("mc05_off") and offensive:
		take("mc05_off")
		fire("mc05_dual_invocation", "%s prepared %s faster" % [s.display_name, StatStyle.pct(1.0 - float(pv("mc05_dual_invocation", "prep_mult", 0.85)))])
	if active("mc05_heal") and not offensive:
		take("mc05_heal")
		fire("mc05_dual_invocation", "%s prepared %s faster" % [s.display_name, StatStyle.pct(1.0 - float(pv("mc05_dual_invocation", "prep_mult", 0.85)))])
	if active("ma04"):
		take("ma04")
		fire("ma04_swift_invocation", "%s prepared %s faster" % [s.display_name, StatStyle.pct(1.0 - float(pv("ma04_swift_invocation", "prep_mult", 0.9)))])
	if active("ma01") and String(windows["ma01"].get("spell", "")) != s.id:
		take("ma01")
		use_cd("ma01", float(pv("ma01_spell_threading", "cooldown", 5.0)))
		fire("ma01_spell_threading", "%s threaded: minimum charge -%s" % [s.display_name, StatStyle.pct(1.0 - float(pv("ma01_spell_threading", "min_mult", 0.8)))])


func spell_recovery_mult(s: ChargedSpellData) -> float:
	if s.element != "life" and active("ma06"):
		take("ma06")
		fire("ma06_emergency_thread", "%s recovers %s faster" % [s.display_name, StatStyle.pct(1.0 - float(pv("ma06_emergency_thread", "recovery_mult", 0.85)))])
		return float(pv("ma06_emergency_thread", "recovery_mult", 0.85))
	return 1.0


## M-A02 Arcane Relay: origin of the next targeted spell (the supported ally) when range / LOS allow.
func relay_origin(default_pos: Vector3, max_range: float) -> Vector3:
	if not active("ma02"):
		return default_pos
	var ally = windows["ma02"].get("ally")
	if not _ally_ok(ally) or ally.global_position.distance_to(hero.global_position) > max_range:
		return default_pos
	var from: Vector3 = ally.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(hero.global_position + Vector3(0, 1.4, 0), from, Combatant.LAYER_WORLD)
	if not hero.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return default_pos
	take("ma02")
	use_cd("ma02", float(pv("ma02_arcane_relay", "cooldown", 10.0)))
	fire("ma02_arcane_relay", "Spell relayed from %s" % ally.display_name)
	return from


## M-F01 / M-F03: magnitude multiplier for an implemented elemental interaction.
func interaction_mult(id: String) -> float:
	if has("mf01_elemental_crossroads") and crossroads_choice() == id:
		if ready("mf01_fx"):
			use_cd("mf01_fx", 1.0)   # visible cue (006 Part 12), at most once per second
			fire("mf01_elemental_crossroads", "%s enhanced (%s)" % [id.replace("_", " ").capitalize(), StatStyle.pct(float(pv("mf01_elemental_crossroads", "magnitude", 1.2)) - 1.0)])
		return float(pv("mf01_elemental_crossroads", "magnitude", 1.2))
	return 1.0


func crossroads_choice() -> String:
	var c := hero.prog().crossroads_choice
	return c if c != "" else String(pv("mf01_elemental_crossroads", "default_choice", "thermal_fracture"))


## Poise bonus of a Fire/Frost interaction on one target (M-F03, with the Crossroads cap).
func thermal_poise_mult(target) -> float:
	if not has("mf03_thermal_fracture") or not _is_enemy(target):
		return interaction_mult("thermal_fracture")
	var key := "mf03:%d" % target.get_instance_id()
	var base := interaction_mult("thermal_fracture") - 1.0
	if not ready(key):
		return 1.0 + base
	use_cd(key, float(pv("mf03_thermal_fracture", "cooldown", 6.0)))
	var bonus := float(pv("mf03_thermal_fracture", "boss_bonus", 0.1)) if target.is_boss else float(pv("mf03_thermal_fracture", "poise_bonus", 0.25))
	var total := minf(base + bonus, float(pv("mf03_thermal_fracture", "synergy_cap", 0.4)))
	fire("mf03_thermal_fracture", "Fire / Frost: +%s Poise on %s" % [StatStyle.pct(total), target.display_name])
	return 1.0 + total


## M-F02 Lingering Essence: extended duration of an elemental status applied by this Worldweaver.
func status_duration(dur: float, hard_cc: bool) -> float:
	if not has("mf02_lingering_essence") or hard_cc:
		return dur
	var ext := minf(dur * (float(pv("mf02_lingering_essence", "duration_mult", 1.2)) - 1.0), float(pv("mf02_lingering_essence", "cap", 1.5)))
	counts["mf02_lingering_essence"] = int(counts.get("mf02_lingering_essence", 0)) + 1
	return dur + ext


func _on_spell_released(caster, spell_id: String, element: String, full: bool, _t: float, _mana: float) -> void:
	if caster != hero:
		return
	var offensive := element != "life"
	if has("ma01_spell_threading") and ready("ma01"):
		open("ma01", float(pv("ma01_spell_threading", "window", 3.0)), {"spell": spell_id})
	_prev_cast_element = element
	_last_element[element] = Game.time
	_last_spell_id = spell_id
	_last_spell_full = full
	if active("mf05") and String(windows["mf05"].get("element", "")) != element:
		windows["mf05"]["armed"] = spell_id
	if offensive and has("mc05_dual_invocation") and ready("mc05_heal_cd"):
		use_cd("mc05_heal_cd", float(pv("mc05_dual_invocation", "cooldown", 6.0)))
		open("mc05_heal", float(pv("mc05_dual_invocation", "window", 3.0)))


func _on_slot_changed(caster, _slot: int, _old: String, _new: String, source: String) -> void:
	if caster != hero:
		return
	if (source == "wheel" or source == "tap" or source == "restore") and has("ma04_swift_invocation") and ready("ma04_cd"):
		use_cd("ma04_cd", float(pv("ma04_swift_invocation", "cooldown", 6.0)))
		open("ma04", 4.0)


const INTERACTION_ELEMENT := {"thermal_fracture": "fire", "living_bastion": "life", "shattered_winter": "stone",
	"conductive_anchors": "storm", "conductive_route": "storm"}


func _on_interaction(caster, interaction_id: String, _detail: String) -> void:
	if caster != hero or not has("mf05_living_confluence") or not ready("mf05"):
		return
	open("mf05", float(pv("mf05_living_confluence", "window", 4.0)), {"element": String(INTERACTION_ELEMENT.get(interaction_id, "")), "id": interaction_id})


func _on_damage_applied(info) -> void:
	if info.source != hero or _secondary(info) or info.attack != null or info.is_dot or info.tags.get("dot_zone", false):
		return
	# spell damage only (attacks are handled by on_hit_landed)
	if info.final_amount <= 0.0 and info.absorbed <= 0.0:
		return
	var target = info.target
	if not _is_enemy(target):
		return
	var key := "spell:%s:%d" % [_last_spell_id, int(Game.time * 10.0)]
	_common_hit(target, info, key)
	# M-C01 Merciful Conduit
	if has("mc01_merciful_conduit") and ready("mc01"):
		var ally = _most_injured(hero.kit.b.ww_heal_range)
		if ally != null:
			use_cd("mc01", float(pv("mc01_merciful_conduit", "cooldown", 8.0)))
			var amt := minf(info.final_amount * float(pv("mc01_merciful_conduit", "share", 0.12)), ally.max_hp * float(pv("mc01_merciful_conduit", "cap_frac", 0.08)))
			ally.heal(amt, hero, {"spell": "Merciful Conduit", SECONDARY: true})
			fire("mc01_merciful_conduit", "%d healing to %s" % [roundi(amt), ally.display_name])
	# M-C05 offensive spell opens the heal window
	# (handled at release: _on_spell_released)
	# M-A03 Rewoven Spell: single-target spells only
	# single-target only: Thunder Conduit's FULL release chains, so only its partial (focused) release counts
	if has("ma03_rewoven_spell") and ready("ma03") and String(pv("ma03_rewoven_spell", "spells", "")).split(",").has(_last_spell_id) and not (_last_spell_id == "thunder_conduit" and _last_spell_full) and not info.attack_name.contains("(chain)"):
		var other = null
		var bd := float(pv("ma03_rewoven_spell", "radius", 6.0))
		for e in hero.get_tree().get_nodes_in_group("enemies"):
			if e != target and e.is_targetable() and e.global_position.distance_to(target.global_position) <= bd:
				bd = e.global_position.distance_to(target.global_position)
				other = e
		if other != null:
			use_cd("ma03", float(pv("ma03_rewoven_spell", "cooldown", 8.0)))
			FX.beam(target.global_position + Vector3(0, 1.0, 0), other.global_position + Vector3(0, 1.0, 0), Color(0.75, 0.65, 1.0))
			_flat_damage(other, info.raw_amount * float(pv("ma03_rewoven_spell", "share", 0.25)), "Rewoven Spell", true)
			fire("ma03_rewoven_spell", "Second hit on %s" % other.display_name)
	# M-F05 Living Confluence (enemy-targeted follow-up)
	if active("mf05") and String(windows["mf05"].get("armed", "")) == _last_spell_id:
		var w := take("mf05")
		use_cd("mf05", float(pv("mf05_living_confluence", "cooldown", 10.0)))
		var share := float(pv("mf05_living_confluence", "dmg_share", 0.2))
		_flat_damage(target, info.raw_amount * share, "Living Confluence", true)
		var col := Color(1.0, 0.6, 0.3) if String(w.get("id", "")) == crossroads_choice() and has("mf01_elemental_crossroads") else Color(0.7, 1.0, 0.8)
		VFX.ground_ring(target.global_position, 1.4, col, 0.3)
		fire("mf05_living_confluence", "Follow-up impact on %s (%s)" % [target.display_name, StatStyle.pct(share)])


func _most_injured(rng: float):
	var best = null
	var br := 1.0
	for a in hero.allies(true):
		if a.global_position.distance_to(hero.global_position) > rng or a.hp >= a.max_hp:
			continue
		if a.hp / a.max_hp < br:
			br = a.hp / a.max_hp
			best = a
	return best


func _on_healed(source, target, amount: float, over: float, tags: Dictionary) -> void:
	if source != hero or tags.get(SECONDARY, false) or tags.get("hot", false):
		return
	if not _ally_ok(target):
		return
	var effective := amount > 0.5
	var ratio_before: float = (target.hp - amount) / target.max_hp
	# M-C02 Gentle Current
	if effective and has("mc02_gentle_current"):
		var key := "mc02:%d" % target.get_instance_id()
		if ready(key):
			use_cd(key, float(pv("mc02_gentle_current", "cd_per_target", 5.0)))
			var s := StatusEffect.make("gentle_current", "Gentle Current", "buff", float(pv("mc02_gentle_current", "duration", 2.5)), {"move_speed": float(pv("mc02_gentle_current", "speed_mult", 1.1))})
			s.source = hero
			target.statuses.add(s)
			fire("mc02_gentle_current", "%s +%s speed" % [target.display_name, StatStyle.pct(float(pv("mc02_gentle_current", "speed_mult", 1.1)) - 1.0)])
	# M-C06 Woven Protection
	if over > 0.5 and has("mc06_woven_protection"):
		var amt := minf(over * float(pv("mc06_woven_protection", "share", 0.2)), target.max_hp * float(pv("mc06_woven_protection", "cap_frac", 0.06)))
		target.add_shield(amt, float(pv("mc06_woven_protection", "duration", 4.0)), hero)
		fire("mc06_woven_protection", "%d overheal -> shield %d" % [roundi(over), roundi(amt)])
	# M-C04 Benevolent Casting
	if effective and has("mc04_benevolent_casting") and ready("mc04_cd") and ratio_before < float(pv("mc04_benevolent_casting", "hp_threshold", 0.4)):
		use_cd("mc04_cd", float(pv("mc04_benevolent_casting", "cooldown", 8.0)))
		open("mc04", float(pv("mc04_benevolent_casting", "expiry", 5.0)))
		fire("mc04_benevolent_casting", "Next support spell -%s mana" % StatStyle.pct(1.0 - float(pv("mc04_benevolent_casting", "mana_mult", 0.85))))
	# M-C05 Dual Invocation: a direct heal opens the offensive window
	if effective and has("mc05_dual_invocation") and ready("mc05_off_cd"):
		use_cd("mc05_off_cd", float(pv("mc05_dual_invocation", "cooldown", 6.0)))
		open("mc05_off", float(pv("mc05_dual_invocation", "window", 3.0)))
	# M-A02 Arcane Relay
	if effective and target != hero and has("ma02_arcane_relay") and ready("ma02"):
		open("ma02", float(pv("ma02_arcane_relay", "window", 4.0)), {"ally": target})
	# M-A05 Sympathetic Link: the heal on a linked ally strikes the linked enemy; support creates the link
	if not _link.is_empty() and Game.time <= float(_link.until) and _link.ally == target and effective:
		var en = _link.enemy
		_link = {}
		if _is_enemy(en) and not en.dead:
			var dmg := minf(amount * float(pv("ma05_sympathetic_link", "share", 0.15)), hero.weapon_power * float(pv("ma05_sympathetic_link", "cap_wp", 0.6)))
			FX.beam(target.global_position + Vector3(0, 1.0, 0), en.global_position + Vector3(0, 1.0, 0), Color(0.6, 1.0, 0.75))
			_flat_damage(en, dmg, "Sympathetic Link", true)
			fire("ma05_sympathetic_link", "%d damage to linked %s" % [roundi(dmg), en.display_name])
	elif effective and target != hero and has("ma05_sympathetic_link") and ready("ma05"):
		var origin: Vector3 = target.global_position
		var best = null
		var bd := float(pv("ma05_sympathetic_link", "link_range", 8.0))
		for e in hero.get_tree().get_nodes_in_group("enemies"):
			if e.is_targetable() and e.global_position.distance_to(origin) <= bd:
				bd = e.global_position.distance_to(origin)
				best = e
		if best != null:
			use_cd("ma05", float(pv("ma05_sympathetic_link", "cooldown", 12.0)))
			_link = {"ally": target, "enemy": best, "until": Game.time + float(pv("ma05_sympathetic_link", "duration", 4.0))}
			fire("ma05_sympathetic_link", "%s linked to %s" % [target.display_name, best.display_name])
	# M-A06 Emergency Thread
	if effective and has("ma06_emergency_thread") and ready("ma06_cd") and ratio_before < float(pv("ma06_emergency_thread", "hp_threshold", 0.35)):
		use_cd("ma06_cd", float(pv("ma06_emergency_thread", "cooldown", 10.0)))
		open("ma06", float(pv("ma06_emergency_thread", "window", 4.0)))
		var el = hero.kit.el if hero.kit is MageKit else null
		if el != null:
			for slot in [0, 1]:
				var cur: String = el.slot_spell(slot)
				var prev := String(el.prev_spell.get(slot, ""))
				if cur != "" and el.spells[cur].element == "life" and prev != "" and el.spells.has(prev) and el.spells[prev].element != "life":
					# 006: the next press of that button starts the kept offensive spell again (counts as a switch)
					el.restore_spell = {"slot": slot, "spell": prev, "until": Game.time + float(pv("ma06_emergency_thread", "window", 4.0))}
		fire("ma06_emergency_thread", "Ally saved: offensive spell kept for a quick swap back, next offensive cast recovers faster")
	# M-F05 Living Confluence (ally-targeted follow-up)
	if effective and active("mf05") and String(windows["mf05"].get("armed", "")) == _last_spell_id:
		take("mf05")
		use_cd("mf05", float(pv("mf05_living_confluence", "cooldown", 10.0)))
		var extra := amount * float(pv("mf05_living_confluence", "heal_share", 0.15))
		target.heal(extra, hero, {"spell": "Living Confluence", SECONDARY: true})
		fire("mf05_living_confluence", "+%d healing on %s" % [roundi(extra), target.display_name])


# ------------------------------------------------------------------ Reaver (Blade Dancer)
## Dance attack shaping: returns extra ctx entries and may change the attack (clone already).
func bd_dance(kind: String, d: AttackData, extra: Dictionary) -> void:
	if kind == "lateral" and has("rd01_phantom_footwork") and hero.lock_target != null and is_instance_valid(hero.lock_target):
		extra["phantom"] = true
		extra["travel_mult"] = float(extra.get("travel_mult", 1.0)) * float(pv("rd01_phantom_footwork", "travel_mult", 1.15))
		d.anim_style = "bd_orbit"
		d.display_name = "Phantom " + d.display_name
		counts["rd01_phantom_footwork"] = int(counts.get("rd01_phantom_footwork", 0)) + 1
	if kind == "forward" and active("rc04"):
		var t = windows["rc04"].get("target")
		if _is_enemy(t) and t.is_targetable():
			var gap: float = Vector2(t.global_position.x - hero.global_position.x, t.global_position.z - hero.global_position.z).length()
			if gap >= float(pv("rc04_close_pursuit", "gap_min", 2.2)) and gap <= float(pv("rc04_close_pursuit", "gap_max", 3.6)):
				take("rc04")
				var bonus := float(pv("rc04_close_pursuit", "travel_bonus", 0.2))
				extra["travel_mult"] = float(extra.get("travel_mult", 1.0)) * (1.0 + bonus)
				extra["pursuit"] = true
				fire("rc04_close_pursuit", "Forward Dance +%s travel toward %s" % [StatStyle.pct(bonus), t.display_name])
	if active("rd06") and kind != "neutral":
		take("rd06")
		extra["travel_mult"] = float(extra.get("travel_mult", 1.0)) * float(pv("rd06_dancers_reversal", "travel_mult", 1.2))
		d.anim_style = "bd_relentless"
		d.display_name = "Reversal " + d.display_name
		fire("rd06_dancers_reversal", "Turning follow-up (+%s movement)" % StatStyle.pct(float(pv("rd06_dancers_reversal", "travel_mult", 1.2)) - 1.0))


## A special follow-up replacing the next Dance LMB, or null.
func bd_follow_up(mode: String) -> Dictionary:
	if active("rd03") and mode == "dance":
		take("rd03")
		var base: AttackData = hero.kit.load_attack("bd_dance_lateral")
		var d := base.clone()
		d.id = "bd_predator"
		d.display_name = "Predator Cut"
		d.damage_mult *= float(pv("rd03_circling_predator", "damage_share", 0.85))
		d.startup *= 0.8
		d.anim_style = "bd_relentless"
		return {"attack": d, "kind": "predator", "aug": "rd03_circling_predator"}
	if active("rc05"):
		take("rc05")
		var d: AttackData
		if mode == "edge":
			d = hero.kit.load_attack("bd_precision").clone()
			d.display_name = "Reflex Thrust"
			d.anim_style = "bd_withdraw"
		else:
			d = hero.kit.load_attack("bd_dance_neutral").clone()
			d.display_name = "Reflex Cut"
			d.anim_style = "bd_whirl"
		d.id = "bd_reflex"
		return {"attack": d, "kind": "reflex", "aug": "rc05_blade_reflex"}
	return {}


func bd_precision(d: AttackData) -> void:
	if has("re04_executioners_distance"):
		var rm := float(pv("re04_executioners_distance", "range_mult", 1.15))
		d.hitbox_offset.z = d.hitbox_offset.z - d.hitbox_size.z * (rm - 1.0) * 0.5
		d.hitbox_size.z *= rm
		d.hitbox_size.x *= float(pv("re04_executioners_distance", "width_mult", 0.8))
		counts["re04_executioners_distance"] = int(counts.get("re04_executioners_distance", 0)) + 1
	if active("rc01") and ready("rc01_cd"):
		take("rc01")
		use_cd("rc01_cd", float(pv("rc01_seamless_steel", "cooldown", 5.0)))
		d.startup *= float(pv("rc01_seamless_steel", "startup_mult", 0.8))
		d.anim_style = "bd_forward"
		d.display_name = "Seamless " + d.display_name
		fire("rc01_seamless_steel", "Mobile transition into Precision Cut (startup x%.2f)" % float(pv("rc01_seamless_steel", "startup_mult", 0.8)))


func bd_technique(id: String, d: AttackData) -> void:
	if id == "bd_break" and has("re03_fracturing_edge"):
		d.hitbox_size.x *= float(pv("re03_fracturing_edge", "width_mult", 0.85))
	if id == "bd_orbit" and has("rd04_extended_orbit"):
		var cm := float(pv("rd04_extended_orbit", "commit_mult", 1.15))
		d.startup *= cm
		d.recovery *= cm
		counts["rd04_extended_orbit"] = int(counts.get("rd04_extended_orbit", 0)) + 1
	if id == "bd_whirl" and has("rd05_tempest_waltz"):
		d.move_during *= float(pv("rd05_tempest_waltz", "speed_mult", 1.15))


## Committed Cut changes (Twin Verdict transform, Perfect Draw release window). `held` = LMB hold time.
func bd_committed(d: AttackData, held: float, transform: String) -> String:
	var tr := transform
	if tr == "" and has("re05_twin_verdict"):
		tr = "twin_verdict"
		var f := float(pv("re05_twin_verdict", "first", 0.4))
		d.hits = 2
		d.hit_weights = PackedFloat32Array([f, 1.0 - f])
		d.add_tag("single_impact_scaling")   # two committed impacts: STR as before, no extra DEX multi-hit bonus
		# +15% total exposure: most of it widens the active window so two impacts fit, the rest is recovery
		var extra := d.total_time() * (float(pv("re05_twin_verdict", "exposure_mult", 1.15)) - 1.0)
		d.active += extra * 0.7
		d.recovery += extra * 0.3
		d.anim_style = "bd_twin"
		d.display_name = "Twin Verdict"
		fire("re05_twin_verdict", "Committed Cut: two impacts (%s / %s)" % [StatStyle.pct(f), StatStyle.pct(1.0 - f)])
	if has("re01_perfect_draw"):
		var lo := ReaverBladeDancer.COMMIT_MAX
		if held >= lo and held <= lo + float(pv("re01_perfect_draw", "window", 0.12)):
			d.recovery *= float(pv("re01_perfect_draw", "recovery_mult", 0.8))
			d.cancel_after = minf(d.cancel_after, d.recovery)
			fire("re01_perfect_draw", "Perfect Draw: released %.2fs after full charge, recovery x%.2f" % [held - lo, float(pv("re01_perfect_draw", "recovery_mult", 0.8))])
	return tr


## V-K01: Perfect Guard window for the transformed heavy.
func take_reversal() -> bool:
	if active("vk01"):
		take("vk01")
		return true
	return false
