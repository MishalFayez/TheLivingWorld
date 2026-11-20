class_name AIBrain
extends Node
## Party Test companion AI. Drives a Hero through the same press/release interface as the player.
## Vanguard: guards (sometimes perfectly), intercepts threats to allies, holds threat.
## Mage: heals allies by priority, keeps distance, attacks / weaves when safe.
## Reaver: aggressive melee, reads telegraphs and dodges; follows the active core's rules (Swordmaster Blade
## Lines by default, never attempting illegal links; the retired cores only when selected in Debug).

var hero: Hero
var think_t: float = 0.0
var holds: Dictionary = {}
var reacted: Dictionary = {}
var guard_at: float = INF
var guard_until: float = 0.0
var dodge_at: float = INF
var dodge_from = null
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	hero = get_parent()
	rng.randomize()


func _physics_process(delta: float) -> void:
	if hero == null or hero.dead or not hero.visible:
		return
	_process_holds()
	if hero.downed:
		return
	think_t -= delta
	var ally = _downed_ally()
	if ally != null:
		var to: Vector3 = ally.global_position - hero.global_position
		to.y = 0
		if to.length() > 1.8:
			hero.move_input = to.normalized()
		else:
			hero.move_input = Vector3.ZERO
			hero.try_revive(delta)
		return
	match hero.class_id:
		"vanguard":
			_vanguard(delta)
		"mage":
			_mage(delta)
		"reaver":
			_reaver(delta)


# ------------------------------------------------------------------ helpers
func tap(action: String) -> void:
	hero.press(action)
	hero.release(action)


func press_for(action: String, dur: float) -> void:
	hero.press(action)
	holds[action] = Game.time + dur


func _process_holds() -> void:
	for a in holds.keys():
		if Game.time >= holds[a]:
			holds.erase(a)
			hero.release(a)


func _downed_ally():
	for h in Game.heroes:
		if is_instance_valid(h) and h != hero and h.downed and h.global_position.distance_to(hero.global_position) < 25.0:
			var safe := true
			for e in hero.enemies_within(2.5, h.global_position):
				if e.target == hero:
					safe = false
			if safe or h.downed_timer < 6.0:
				return h
	return null


func _anchor() -> Vector3:
	if is_instance_valid(Game.player) and Game.player != hero and Game.player.visible:
		return Game.player.global_position
	return hero.global_position


func _pick_target():
	var anchor := _anchor()
	var best = null
	var best_score := INF
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if not e.is_targetable() or e.global_position.distance_to(anchor) > 24.0:
			continue
		var score: float = e.global_position.distance_to(hero.global_position)
		if e.target != null and e.target != hero:
			score -= 3.0
		if e.is_boss:
			score -= 2.0
		if score < best_score:
			best_score = score
			best = e
	return best


func _incoming_attack():
	for e in hero.get_tree().get_nodes_in_group("enemies"):
		if e.is_targetable() and e.target == hero and e.runner.phase == AttackRunner.Phase.STARTUP:
			var reach: float = e.runner.data.ai_range.y + 2.5
			if e.runner.data.special != "" or e.global_position.distance_to(hero.global_position) <= reach:
				return e
	return null


func _move_toward(pos: Vector3, stop: float) -> void:
	var to := pos - hero.global_position
	to.y = 0
	hero.move_input = to.normalized() if to.length() > stop else Vector3.ZERO


func _follow() -> void:
	hero.lock_target = null
	if is_instance_valid(Game.player) and Game.player != hero:
		_move_toward(Game.player.global_position, 4.0)
	else:
		hero.move_input = Vector3.ZERO


func _react_once(e) -> bool:
	var key: int = e.get_instance_id()
	if reacted.get(key, -1) == e.attack_serial:
		return false
	reacted[key] = e.attack_serial
	return true


# ------------------------------------------------------------------ Vanguard
func _vanguard(_delta: float) -> void:
	var kit: VanguardKit = hero.kit
	var threat = _incoming_attack()
	if threat != null and _react_once(threat):
		var remaining: float = threat.startup_remaining()
		guard_at = Game.time + maxf(0.0, remaining - rng.randf_range(0.04, 0.4))
		guard_until = Game.time + remaining + threat.runner.data.active + 0.25
		hero.lock_target = threat
	if Game.time >= guard_at:
		guard_at = INF
		if not hero.is_held("guard"):
			hero.press("guard")
		holds["guard"] = guard_until
	if hero.is_held("guard"):
		hero.move_input = Vector3.ZERO
		if Game.time < kit.counter_until:
			holds.erase("guard")
			hero.release("guard")
			tap("light" if rng.randf() < 0.6 else "skill2")
		return
	if kit.skill_ready(0) and kit.endangered_ally() != null and rng.randf() < 0.1:
		tap("skill1")
		return
	var target = _pick_target()
	if target == null:
		_follow()
		return
	hero.lock_target = target
	var dist: float = target.global_position.distance_to(hero.global_position)
	if dist > 2.3:
		_move_toward(target.global_position, 2.0)
		return
	hero.move_input = Vector3.ZERO
	if think_t > 0.0 or not hero.can_act():
		return
	think_t = rng.randf_range(0.3, 0.6)
	if hero.enemies_within(3.6).size() >= 2 and kit.skill_ready(2):
		tap("skill3")
	elif target.is_staggered() and kit.skill_ready(1):
		press_for("skill2", 0.5)
	elif rng.randf() < 0.25:
		tap("heavy")
	else:
		tap("light")


# ------------------------------------------------------------------ Mage
func _mage(_delta: float) -> void:
	var kit: MageKit = hero.kit
	if kit.elementalist():
		_mage_elementalist()
		return
	if kit.charging != "" or hero.runner.is_busy():
		return
	var threat = _incoming_attack()
	if threat != null and _react_once(threat) and threat.global_position.distance_to(hero.global_position) < 5.0:
		dodge_at = Game.time + maxf(0.0, threat.startup_remaining() - 0.15)
		dodge_from = threat
	if Game.time >= dodge_at:
		dodge_at = INF
		if is_instance_valid(dodge_from):
			var away: Vector3 = hero.global_position - dodge_from.global_position
			hero.move_input = Vector3(away.x, 0, away.z).normalized()
		tap("dodge")
		return
	if think_t > 0.0:
		_mage_position()
		return
	think_t = rng.randf_range(0.35, 0.6)
	var low = hero.lowest_ally(20.0)
	var hurt := 0
	for a in hero.allies(true):
		if a.hp / a.max_hp < 0.7 and a.global_position.distance_to(hero.global_position) < 7.5:
			hurt += 1
	if hurt >= 2 and kit.mana >= 25.0:
		press_for("life", 0.7)
		return
	if low != null and low.hp / low.max_hp < 0.55 and kit.mana >= 10.0:
		tap("life")
		return
	var target = _pick_target()
	if target == null:
		if low != null and low.hp / low.max_hp < 0.9 and kit.mana > 30.0:
			tap("life")
		_follow()
		return
	hero.lock_target = target
	if kit.sigil_core():
		# Ley Sigils: inscribe Life where allies are hurt, offensive sigils on clustered enemies,
		# consume when the sigil is about to be wasted.
		if kit.unlocked("m_ward") and kit.ward_cd <= 0.0 and low != null and low.hp / low.max_hp < 0.45 and kit.mana >= 15.0:
			tap("skill3")
			return
		if kit.sigils.size() < kit.sigil_limit() and kit.mana >= 40.0 and kit.unlocked("m_sigil") and rng.randf() < 0.35:
			if hurt >= 1 and kit.last_element != "life":
				tap("life")      # sets last element to Life first
				return
			tap("core")
			return
		if kit.sigils.size() >= kit.sigil_limit() and rng.randf() < 0.12:
			var sg = kit.sigils[0]
			if is_instance_valid(sg) and (sg.t > sg.duration - 1.5 or (sg.element != "life" and sg.enemies_inside().size() >= 2) or (sg.element == "life" and hurt >= 2)):
				tap("core")
				return
	elif kit.echoes.size() == 2 and kit.weave_cd <= 0.0 and kit.mana >= 25.0 and rng.randf() < 0.7:
		tap("core")
		return
	if low != null and low.hp / low.max_hp < 0.85 and rng.randf() < 0.3:
		tap("life")
		return
	var slot := "heavy" if kit.slot_element(1) != "" and rng.randf() < 0.4 else "light"
	if rng.randf() < 0.25 and kit.mana > 30.0:
		press_for(slot, 0.65)
	else:
		tap(slot)
	_mage_position()


## Worldweaver companion. Uses exactly the player's spell rules (same spells, charges, mana,
## cooldowns, heal-target selection). Priorities (spec 17):
##   1 prevent urgent ally death  2 maintain essential recovery  3 avoid immediate danger
##   4 defensive spells when appropriate  5 offence when healing is stable  6 Sanctum when sensible
func _mage_elementalist() -> void:
	var kit: MageKit = hero.kit
	var e: MageElementalist = kit.el
	if e.cur != null or hero.runner.is_busy():
		_mage_position()
		return
	var threat = _incoming_attack()
	var danger: bool = threat != null and threat.global_position.distance_to(hero.global_position) < 5.0
	var low = hero.lowest_ally(20.0)
	var low_r: float = low.hp / low.max_hp if low != null else 1.0
	# 1) urgent: an ally about to die -> instant Lifeline
	if low != null and low_r < 0.35 and kit.cd("lifeline") <= 0.0 and kit.mana >= e.spells.lifeline.mana_partial:
		e.heal_target = low
		tap("life")
		return
	# 3) immediate danger (dodging also cancels a charge, as for the player)
	if danger and _react_once(threat):
		dodge_at = Game.time + maxf(0.0, threat.startup_remaining() - 0.15)
		dodge_from = threat
	if Game.time >= dodge_at:
		dodge_at = INF
		if is_instance_valid(dodge_from):
			var away: Vector3 = hero.global_position - dodge_from.global_position
			hero.move_input = Vector3(away.x, 0, away.z).normalized()
		tap("dodge")
		return
	if think_t > 0.0:
		_mage_position()
		return
	think_t = rng.randf_range(0.3, 0.5)
	# 2) essential recovery: prepared Life Bloom (short charge when enemies are close)
	if low != null and low_r < 0.6 and kit.mana >= e.spells.life_bloom.mana_partial and e.spell_known("life_bloom") and not danger:
		e.heal_target = low
		e.ai_spell["heavy"] = "life_bloom"
		var near_h := not hero.enemies_within(4.5).is_empty()
		press_for("heavy", 0.3 if near_h else e.spells.life_bloom.full_charge / e.charge_speed() + 0.05)
		return
	var u: String = e.utility_spell()
	# 4) defensive spells: Protective Renewal before a telegraphed elite / boss blow on an ally;
	#    formation utilities / Crystal Formation to block a melee enemy closing on the Mage
	if u == "protective_renewal" and kit.cd(u) <= 0.0 and kit.mana >= e.spells[u].mana_partial:
		for en in hero.enemies_within(25.0):
			if (en.is_elite or en.is_boss) and en.runner.is_busy() and en.runner.phase == AttackRunner.Phase.STARTUP and en.target != null and is_instance_valid(en.target) and en.target.team == hero.team:
				e.heal_target = en.target
				tap("skill3")
				return
	var closing = null
	for en in hero.enemies_within(7.0):
		if not en.is_boss and en.target == hero:
			closing = en
			break
	if closing != null:
		hero.lock_target = closing
		if u in ["frozen_bastion", "stone_ward", "rising_pillar"] and kit.cd(u) <= 0.0 and kit.mana >= e.spells[u].mana_partial:
			e.ai_aim = null
			e.cast_utility(u)
			return
		if e.spell_known("crystal_formation") and kit.mana >= e.spells.crystal_formation.mana_full and rng.randf() < 0.5:
			e.ai_spell["light"] = "crystal_formation"
			press_for("light", e.spells.crystal_formation.min_charge + 0.02)
			return
	var target = _pick_target()
	if target == null:
		e.heal_target = null
		if low != null and low_r < 0.95 and kit.mana > 40.0 and e.spell_known("life_bloom"):
			e.heal_target = low
			e.ai_spell["heavy"] = "life_bloom"
			press_for("heavy", e.spells.life_bloom.full_charge / e.charge_speed() + 0.05)
			return
		_follow()
		return
	hero.lock_target = target
	# 5) offence only while healing is stable
	var stable: bool = low_r >= 0.6
	# 6) Arcane Sanctum when positioning is sensible (nothing on top of us, party stable)
	if stable and kit.unlocked("m_sanctum") and kit.cd("sanctum") <= 0.0 and kit.mana >= 45.0 and hero.enemies_within(5.0).is_empty():
		tap("core")
		return
	if not stable:
		_mage_position()
		return
	var spell := "flame_cataclysm"
	var all_e: Array = hero.enemies_within(22.0)
	var grouped := 0
	for x in all_e:
		if x.global_position.distance_to(target.global_position) < 3.5:
			grouped += 1
	var r: AttackRunner = target.runner
	if e.spell_known("lightning_verdict") and r.is_busy() and r.phase == AttackRunner.Phase.STARTUP and r.data and r.data.interruptible and not target.is_boss:
		spell = "lightning_verdict"
	elif e.spell_known("earthbreaker") and (target is ShieldGuardian or target.is_boss or target.is_elite):
		spell = "earthbreaker"
	elif e.spell_known("thunder_conduit") and all_e.size() >= 2 and grouped < 2:
		spell = "thunder_conduit"
	elif e.spell_known("flame_cataclysm"):
		spell = "flame_cataclysm"
	else:
		var ks: Array = e.known_charged().filter(func(x): return e.spells[x].element != "life")
		if ks.is_empty():
			_mage_position()
			return
		spell = ks[0]
	var sd: ChargedSpellData = e.spells[spell]
	if kit.mana < sd.mana_partial + 10.0:
		_mage_position()
		return
	e.ai_spell["light"] = spell
	var near := not hero.enemies_within(4.0).is_empty()
	var full_t := sd.full_charge / e.charge_speed() + 0.05
	press_for("light", sd.min_charge + 0.02 if near or spell == "lightning_verdict" else full_t)


func _mage_position() -> void:
	var nearest = null
	var nd := INF
	for e in hero.enemies_within(20.0):
		var d: float = e.global_position.distance_to(hero.global_position)
		if d < nd:
			nd = d
			nearest = e
	if nearest == null:
		_follow()
		return
	if nd < 7.0:
		var away: Vector3 = hero.global_position - nearest.global_position
		away.y = 0
		hero.move_input = away.normalized()
	elif nd > 14.0:
		_move_toward(nearest.global_position, 11.0)
	else:
		hero.move_input = Vector3.ZERO


# ------------------------------------------------------------------ Reaver
func _reaver(_delta: float) -> void:
	var threat = _incoming_attack()
	if threat != null and _react_once(threat) and rng.randf() < 0.8:
		dodge_at = Game.time + maxf(0.0, threat.startup_remaining() - rng.randf_range(0.05, 0.2))
		dodge_from = threat
	if Game.time >= dodge_at:
		dodge_at = INF
		if is_instance_valid(dodge_from):
			var side: Vector3 = (hero.global_position - dodge_from.global_position).cross(Vector3.UP)
			side.y = 0
			hero.move_input = side.normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
		tap("dodge")
		return
	var target = _pick_target()
	if target == null:
		_follow()
		return
	hero.lock_target = target
	var dist: float = target.global_position.distance_to(hero.global_position)
	if dist > 2.0:
		_move_toward(target.global_position, 1.7)
		return
	hero.move_input = Vector3.ZERO
	if think_t > 0.0 or not hero.can_act():
		return
	think_t = rng.randf_range(0.12, 0.3)
	var kit: ReaverKit = hero.kit
	if kit.sword_core():
		# Swordmaster: same Blade Lines rules as the player. Changes lines deliberately (forward <->
		# lateral, lateral -> heavy) instead of repeating one cut; uses equipped skills when ready.
		var sm: ReaverSwordmaster = kit.sm
		var r: AttackRunner = target.runner
		if sm.finisher_open() and kit.unlocked("r_final_stroke") and hero.stamina > 30.0:
			tap("life")
			return
		for act in ReaverSwordmaster.SLOT_ACTIONS:
			var sid: String = sm.slot_skill(act)
			if sid == "" or kit.skill_cd(sid) > 0.0:
				continue
			if sid == "r_flurry" and hero.enemies_within(3.0).size() >= 2 and rng.randf() < 0.3:
				tap(act)
				return
			if sid == "r_lunge" and dist > 1.6 and rng.randf() < 0.25:
				tap(act)
				return
			if sid == "r_crosscut" and rng.randf() < 0.15:
				tap(act)
				return
			if sid == "r_sunder_edge" and (target is ShieldGuardian or target.is_elite) and rng.randf() < 0.3:
				tap(act)
				return
			if sid == "r_turning_edge" and rng.randf() < 0.12:
				sm.ai_lateral = "left" if rng.randf() < 0.5 else "right"
				tap(act)
				return
		if (r.is_busy() and r.phase == AttackRunner.Phase.RECOVERY) or target.is_staggered():
			tap("heavy")
			return
		if sm.last_line == "forward":
			sm.ai_lateral = "left" if rng.randf() < 0.5 else "right"
		elif sm.last_line in ["left", "right"] and rng.randf() < 0.3:
			tap("heavy")
			return
		tap("light")
		return
	if kit.sense_core():
		# Sword Sense: punish Openings with Sunder/Vital cuts, otherwise keep tempo with light attacks.
		if target.has_method("has_opening") and target.has_opening():
			if kit.unlocked("r_lunge") and kit.skill_cd("r_lunge") <= 0.0 and rng.randf() < 0.4:
				tap("skill1")
			elif rng.randf() < 0.5:
				tap("heavy")
			else:
				tap("light")
			return
		if kit.unlocked("r_flurry") and kit.skill_cd("r_flurry") <= 0.0 and hero.enemies_within(3.0).size() >= 2 and rng.randf() < 0.3:
			tap("skill2")
			return
		tap("light" if rng.randf() < 0.85 else "heavy")
		return
	if Game.bladecraft_enabled and kit.armed_form == "" and rng.randf() < 0.15:
		tap(["skill1", "skill2", "skill3"][rng.randi() % 3])
	if kit.combo == 3 or rng.randf() < 0.15:
		if rng.randf() < 0.35:
			press_for("heavy", 0.7)
		else:
			tap("heavy" if kit.combo != 3 else "light")
	else:
		tap("light")
