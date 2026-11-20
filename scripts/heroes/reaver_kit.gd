class_name ReaverKit
extends ClassKit
## REAVER — pure physical melee DPS. No magic, no Guard, no clones, no wound stacks.
## Fast 4-hit light combo, heavy / combo-heavy / charged Draw Cut, dodge-attack.
## Core (Update 5, default): SWORD SENSE — read the enemy, punish Openings with the right cut.
##   Openings: enemy attack RECOVERY, STAGGER, and (Lv5) after a PERFECT DODGE. Shown as a gold glint.
##   Light on an Opening  = TEMPO CUT  (x1.25, +6 stamina, keeps the Opening)
##   Heavy/Charged        = SUNDER CUT (x1.6 / x1.9, double poise, +50% crit dmg, consumes it)
##   Precision (Lunge)    = VITAL CUT  (guaranteed crit, consumes it)
##   No stacks, no counters, no automatic extra attacks: timing and choice of cut are the skill.
## Legacy core candidate (Game.reaver_core = "bladecraft"): BLADECRAFT — keys 1/2/3 arm Split / Focus / Precision; the next
## eligible attack is rebuilt (hit count, timing, hitbox, animation, properties), not buffed.
## Bladecraft can be disabled from the Debug Panel to compare the class with and without its Core.

const FORMS := ["split", "focus", "precision"]
const LIGHTS := ["r_light1", "r_light2", "r_light3", "r_light4"]

var combo: int = 0
var combo_timer: float = 0.0
var armed_form: String = ""
var armed_until: float = 0.0
var crescent_until: float = -10.0
var ghost_until: float = -10.0
var cuts: Dictionary = {"Tempo Cut": 0, "Sunder Cut": 0, "Vital Cut": 0}
const SKILL_CD := {"r_lunge": 5.0, "r_flurry": 8.0, "r_flow_step": 3.0, "r_crosscut": 5.0, "r_sunder_edge": 8.0, "r_turning_edge": 6.0}


var sm: ReaverSwordmaster


func sense_core() -> bool:
	return Game.reaver_core == "sense"


## Swordmaster (Blade Lines) is the default Reaver core; Sword Sense / Bladecraft are retired
## to Debug-only comparison.
func sword_core() -> bool:
	return Game.reaver_core == "swordmaster"


func setup(h: Hero) -> void:
	super.setup(h)
	sm = ReaverSwordmaster.new(self)
	h.runner.hit_window.connect(_on_hit_window)


## Crosscut: the second hit is a NARROWER reverse slash, with limited steering toward the input.
func _on_hit_window(idx: int) -> void:
	var d: AttackData = hero.runner.data
	if d == null or not d.has_tag("crosscut") or idx != 1:
		return
	hero.hitbox.configure(Vector3(1.4, 1.6, 2.6), Vector3(0, 1, -1.5))
	if hero.move_input.length() > 0.3:
		var cur: Vector3 = hero.forward()
		var want: Vector3 = hero.move_input.normalized()
		var ang := clampf(cur.signed_angle_to(want, Vector3.UP), -deg_to_rad(35.0), deg_to_rad(35.0))
		hero.attack_turn_dir = cur.rotated(Vector3.UP, ang)


## Retired cores keep their own Update-5 unlock levels (Debug comparison), independent of the
## Swordmaster track.
const LEGACY_UNLOCKS := {"r_openings": 1, "r_charged": 3, "r_perfect_dodge": 5, "r_lunge": 7, "r_flurry": 9, "r_edge_master": 10}


func unlocked(id: String) -> bool:
	if not sword_core() and LEGACY_UNLOCKS.has(id):
		var p: ClassProgress = hero.prog()
		return (p.level >= int(LEGACY_UNLOCKS[id]) or p.debug_unlocks.has(id)) and not p.debug_locks.has(id)
	return hero.unlocked(id)


func dodge_override() -> bool:
	return sword_core() and sm.dodge_override()


func on_dodge() -> void:
	super.on_dodge()
	if sword_core():
		sm.on_dodge()


func on_hit_landed(target, info: DamageInfo) -> void:
	if sword_core():
		sm.on_hit_landed(target, info)


func build_model() -> void:
	hero.display_name = (hero.prog().character_name if hero.is_player and hero.prog().character_name != "" else "Reaver") if hero.is_player else "Reaver (AI)"
	CharModel.build(hero, "reaver", hero.prog())


func dodge_cost_mult() -> float:
	return b.reaver_dodge_cost_mult


func iframe_mult() -> float:
	return b.reaver_iframe_mult


func resource_name() -> String:
	return "Stamina-driven"


func process(delta: float) -> void:
	super.process(delta)
	if sword_core():
		sm.process(delta)
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = 0
	if armed_form != "" and (Game.time > armed_until or not Game.bladecraft_enabled):
		armed_form = ""


func on_press(action: String) -> void:
	if sword_core():
		sm.on_press(action)
		return
	match action:
		"light":
			if charging != "":
				return
			if not hero.can_act():
				hero.buffer(action)
				return
			_light()
		"heavy":
			if charging != "":
				return
			if not hero.can_act():
				hero.buffer(action)
				return
			begin_charge("heavy", load_attack("r_charged").charge_time)
			if not hero.is_held("heavy"):
				on_release("heavy")
		"skill1":
			if sense_core():
				_skill("r_lunge", "precision")
			else:
				arm("split")
		"skill2":
			if sense_core():
				_skill("r_flurry", "flurry")
			else:
				arm("focus")
		"skill3":
			if not sense_core():
				arm("precision")


func on_release(action: String) -> void:
	if sword_core():
		sm.on_release(action)
		return
	if action != "heavy" or charging != "heavy":
		return
	var is_charged := charge_t >= b.charge_min
	if sense_core() and not unlocked("r_charged"):
		if is_charged and hero.is_player:
			locked_msg("r_charged")
		is_charged = false
	var ratio := charge_ratio()
	cancel_charge()
	var base: AttackData
	var kind := "heavy"
	if is_charged:
		base = apply_charge(load_attack("r_charged"), ratio)
		kind = "charged"
	elif combo > 0 and combo_timer > 0.0:
		base = load_attack("r_heavy_combo")
		kind = "combo_heavy"
	else:
		base = load_attack("r_heavy")
	combo = 0
	_execute(base, kind)


func _light() -> void:
	var base: AttackData
	var kind := "light"
	if Game.time - hero.last_dodge_end < 0.35:
		base = load_attack("r_dodge_slash")
		combo = 1
	else:
		base = load_attack(LIGHTS[combo])
		if combo == 3:
			kind = "finisher"
		combo = (combo + 1) % 4
	combo_timer = 0.9
	_execute(base, kind)


func _skill(id: String, kind: String) -> void:
	if not unlocked(id):
		locked_msg(id)
		return
	if cooldowns.get(id, 0.0) > 0.0:
		return
	if not hero.can_act():
		hero.buffer("skill1" if id == "r_lunge" else "skill2")
		return
	var d := load_attack(id)
	if hero.stamina < d.stamina_cost * 0.5:
		if hero.is_player:
			Events.notify.emit("Not enough stamina")
		return
	cooldowns[id] = SKILL_CD[id]
	combo = 0
	_execute(d, kind)


func skill_cd(id: String) -> float:
	return cooldowns.get(id, 0.0)


func _execute(base: AttackData, kind: String) -> void:
	var r := build_attack(base, kind)
	start_attack(r[0], r[1])


# ------------------------------------------------------------------ Bladecraft
func arm(form: String) -> void:
	if sense_core():
		return
	if not Game.bladecraft_enabled:
		if hero.is_player:
			Events.notify.emit("Bladecraft is DISABLED (Debug Panel)")
		return
	if armed_form == form:
		armed_form = ""
		return
	var r := hero.runner
	if r.is_busy() and String(r.ctx.get("form", "")) != "" and String(r.ctx.get("form", "")) != form and aug("unbroken_form") > 0:
		var cost := float(ap("unbroken_form", "stamina", 15.0))
		if hero.stamina >= cost:
			hero.use_stamina(cost)
			r.cancel_override = true
			trigger("unbroken_form", "%s -> %s seamless transition (-%d stamina)" % [String(r.ctx.form).capitalize(), form.capitalize(), roundi(cost)])
	armed_form = form
	armed_until = Game.time + b.bladecraft_arm_duration
	hero.use_stamina(b.bladecraft_arm_stamina)
	if hero.is_player:
		Events.notify.emit("Bladecraft: %s armed" % form.to_upper())


func form_eligible(form: String, kind: String) -> bool:
	match form:
		"split":
			return true
		"focus":
			return kind != "light"
		"precision":
			return true
	return false


## Builds the actual executed attack: mutations -> Bladecraft form -> enhancements.
func build_attack(base: AttackData, kind: String) -> Array:
	var d := base.clone()
	var ctx := {"kind": kind, "transforms": [], "form": ""}
	var form := ""
	if Game.bladecraft_enabled and armed_form != "" and Game.time <= armed_until and form_eligible(armed_form, kind):
		form = armed_form
	# --- Mutations
	if kind == "heavy" and aug("rising_crescent") > 0:
		d = load_attack("r_rising").clone()
		ctx.transforms.append("rising_crescent")
		trigger("rising_crescent", "Heavy Attack became Rising Crescent (launch + follow-up crit window)")
	elif (kind == "heavy" or kind == "charged" or kind == "combo_heavy") and aug("splintering_steel") > 0 and form != "focus":
		var n := int(ap("splintering_steel", "hits", 3))
		d.hits = n
		d.anim_style = "flurry"
		d.is_heavy = false
		d.active = maxf(d.active, 0.09 * n)
		d.damage_mult *= float(ap("splintering_steel", "total_mult", 1.0))
		d.hitbox_size.x *= 1.2
		d.add_tag("multi")
		d.display_name += " (Splintered)"
		ctx.transforms.append("splintering_steel")
		trigger("splintering_steel", "%s split into %d hits" % [base.display_name, n])
	# --- Bladecraft
	if form != "":
		_apply_form(d, form, kind)
		ctx.form = form
		armed_form = ""
		Events.log_message.emit("Bladecraft %s -> %s (%d hit%s)" % [form.to_upper(), d.display_name, d.hits, "s" if d.hits > 1 else ""], "augment")
	# --- Enhancements
	if d.hits >= 3 and aug("legacy_flowing_edge") > 0:
		d.move_during = float(ap("legacy_flowing_edge", "move_fraction", 0.55))
		ctx.transforms.append("legacy_flowing_edge")
		trigger("legacy_flowing_edge", "Movement allowed during %s" % d.display_name)
	if form == "precision" and aug("execution_line") > 0:
		d.hitbox_size.x *= float(ap("execution_line", "width_mult", 0.55))
		d.hitbox_size.z *= float(ap("execution_line", "length_mult", 1.8))
		d.hitbox_offset.z = -0.4 - d.hitbox_size.z * 0.5
		d.crit_damage_bonus += float(ap("execution_line", "crit_damage", 0.3))
		d.display_name = "Execution Line"
		ctx.transforms.append("execution_line")
		trigger("execution_line", "Precision became a long narrow line (%.1fm)" % d.hitbox_size.z)
	if d.hits >= 3 and aug("one_perfect_cut") > 0:
		var n := d.hits
		var final_share := float(ap("one_perfect_cut", "final_share", 0.45))
		var w := PackedFloat32Array()
		for i in n:
			w.append(final_share if i == n - 1 else (1.0 - final_share) / float(n - 1))
		d.hit_weights = w
		d.final_hit_heavy = true
		d.final_hit_crit_damage_bonus += float(ap("one_perfect_cut", "final_crit_damage", 0.5))
		ctx.transforms.append("one_perfect_cut")
		trigger("one_perfect_cut", "Final hit of %s concentrates %d%% of the sequence" % [d.display_name, roundi(final_share * 100)])
	# --- Sword Sense: Ghost Step (after a Perfect Dodge the next attack becomes a Vital Cut)
	if sense_core() and Game.time < ghost_until and aug("ghost_step") > 0:
		ghost_until = -10.0
		ctx["ghost"] = true
		ctx["crit_damage_bonus"] = float(ctx.get("crit_damage_bonus", 0.0)) + float(ap("ghost_step", "crit_damage", 0.5))
		d.startup = minf(d.startup, 0.08)
		trigger("ghost_step", "%s became an instant Vital Cut" % d.display_name)
	if Game.time < crescent_until and (kind == "light" or kind == "finisher"):
		crescent_until = -10.0
		d.crit_chance_bonus += 0.25
		d.display_name = "Crescent Follow"
	return [d, ctx]


func _apply_form(d: AttackData, form: String, kind: String) -> void:
	match form:
		"split":
			var extra := 4 if kind == "charged" else 3
			if kind == "light":
				d.hits = maxi(d.hits, 1) + 1
			elif kind == "finisher":
				d.hits = maxi(d.hits, 1) + 2
			else:
				d.hits = (d.hits + 2) if d.hits > 1 else (1 + extra)
			d.anim_style = "flurry"
			d.active = maxf(d.active * 1.4, 0.075 * d.hits)
			d.hitbox_size.x *= 1.35
			d.is_heavy = false
			d.poise_damage *= 0.85
			d.damage_mult *= 1.05
			d.hit_weights = PackedFloat32Array()
			d.add_tag("multi")
			d.display_name = "Split " + d.display_name
		"focus":
			d.hits = 1
			d.hit_weights = PackedFloat32Array()
			d.anim_style = "slam"
			d.startup += 0.15
			d.recovery += 0.1
			d.damage_mult *= 1.55
			d.poise_damage *= 2.2
			d.is_heavy = true
			d.hitstop = 0.14
			d.hitbox_size.x *= 0.85
			d.hitbox_size.z *= 1.2
			d.stamina_cost += 8.0
			d.move_during = 0.0
			d.remove_tag("multi")
			d.display_name = "Focused " + d.display_name
		"precision":
			d.hits = 1
			d.hit_weights = PackedFloat32Array()
			d.anim_style = "thrust"
			d.hitbox_size = Vector3(0.75, 1.4, 3.0)
			d.hitbox_offset = Vector3(0, 1.0, -1.9)
			d.startup *= 0.8
			d.damage_mult *= 1.1
			d.remove_tag("multi")
			d.add_tag("precision")
			d.display_name = "Precise " + d.display_name


func situational_crit(d: AttackData, target, ctx: Dictionary) -> float:
	if sense_core():
		if _cut_for(d, target, ctx) == "Vital Cut":
			return 2.0      # guaranteed
		return 0.0
	if not d.has_tag("precision") or target == null:
		return 0.0
	if target.is_staggered():
		return 0.45
	if target.is_attacking_now():
		return 0.35
	var to_attacker: Vector3 = (hero.global_position - target.global_position).normalized()
	if target.forward().dot(to_attacker) < -0.3:
		return 0.3
	return 0.05


# ------------------------------------------------------------------ Sword Sense
func _cut_for(d: AttackData, target, ctx: Dictionary) -> String:
	if not sense_core() or not unlocked("r_openings") or target == null or not is_instance_valid(target):
		return ""
	if not target.has_method("has_opening") or not target.has_opening() or target.team == hero.team:
		return ""
	if ctx.get("ghost", false) or d.has_tag("precision"):
		return "Vital Cut"
	var kind := String(ctx.get("kind", "light"))
	if kind in ["heavy", "combo_heavy", "charged"] or d.is_heavy:
		return "Sunder Cut"
	return "Tempo Cut"


func modify_outgoing(info: DamageInfo, d: AttackData, target, idx: int, ctx: Dictionary) -> void:
	var cut := _cut_for(d, target, ctx)
	if cut == "":
		return
	var last := idx == maxi(1, d.hits) - 1
	match cut:
		"Tempo Cut":
			info.amount *= 1.25
			if idx == 0:
				hero.stamina = minf(hero.max_stamina, hero.stamina + 6.0)
			if unlocked("r_edge_master"):
				target.extend_opening(0.15)
		"Sunder Cut":
			info.amount *= 1.9 if String(ctx.get("kind", "")) == "charged" else 1.6
			info.poise *= 2.0
			if info.is_crit:
				info.amount *= 1.0 + 0.5 / maxf(1.0, hero.stats.crit_damage_total())
			if last and aug("sense_sundering_verdict") > 0:
				hero.stamina = minf(hero.max_stamina, hero.stamina + d.stamina_cost)
				if not target.is_boss:
					var st := float(ap("sense_sundering_verdict", "stagger", 0.8))
					schedule(0.0, func():
						if is_instance_valid(target) and not target.dead:
							target.stagger(st)
							target.consume_opening())
				trigger("sense_sundering_verdict", "Sunder Cut staggered %s" % target.display_name)
		"Vital Cut":
			info.amount *= 1.15
	info.raw_amount = info.amount
	info.tags["cut"] = cut
	if idx == 0 or last:
		cuts[cut] = int(cuts.get(cut, 0)) + 1
		Events.opening_cut.emit(hero, target, cut)
		VFX.opening_glint(target.global_position + Vector3(0, 1.3, 0))
		if hero.is_player and idx == 0:
			FX.number(target, cut.to_upper(), Color(1.0, 0.86, 0.45), 0.8)
	if cut != "Tempo Cut" and last:
		target.consume_opening()


func on_perfect_dodge(info: DamageInfo) -> void:
	if not sense_core() or not unlocked("r_perfect_dodge"):
		return
	var src = info.source
	hero.stamina = minf(hero.max_stamina, hero.stamina + 15.0)
	if src != null and is_instance_valid(src) and src.has_method("open_window"):
		src.open_window("dodge", 1.5)
	if aug("ghost_step") > 0:
		ghost_until = Game.time + float(ap("ghost_step", "window", 1.2))
	VFX.opening_glint(hero.global_position + Vector3(0, 1.2, 0))
	if hero.is_player:
		Events.notify.emit("Perfect Dodge  -  Opening!")
	Events.augment_triggered.emit(hero, "r_perfect_dodge", "Perfect Dodge opened %s" % (src.display_name if src else "?"))


func on_attack_finished(_d: AttackData, ctx: Dictionary, interrupted: bool) -> void:
	if sword_core():
		sm.on_attack_finished(_d, ctx, interrupted)
		return
	if not interrupted and ctx.get("transforms", []).has("rising_crescent"):
		crescent_until = Game.time + 1.0


func hud_lines() -> Array:
	if sword_core():
		return sm.hud_lines()
	var out: Array = []
	if sense_core():
		out.append("Sword Sense  -  strike Openings: LMB Tempo / RMB Sunder / [1] Vital")
		var t = hero.lock_target
		if t and is_instance_valid(t) and t.has_method("has_opening") and t.has_opening():
			out.append("OPENING (%s) %.1fs" % [t.opening_kind, t.opening_until - Game.time])
		if Game.time < ghost_until:
			out.append("Ghost Step ready")
	elif not Game.bladecraft_enabled:
		out.append("BLADECRAFT: DISABLED (comparison mode)")
	else:
		out.append("Bladecraft [1] Split  [2] Focus  [3] Precision")
		if armed_form != "":
			out.append("ARMED: %s (%.1fs)" % [armed_form.to_upper(), armed_until - Game.time])
	out.append("Combo: %d/4" % combo)
	if charging == "heavy":
		out.append("Charging Draw Cut %d%%" % roundi(charge_ratio() * 100))
	if Game.time < crescent_until:
		out.append("Crescent Follow ready (LMB)")
	return out
