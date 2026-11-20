extends Node
## Training statistics (autoload "Training"). Records the PLAYER's damage against training dummies:
## total, hits, per-hit, per-skill, crit rate, DPS, healing / shields, resources spent, augment and
## core activations. A baseline snapshot allows before/after comparisons (e.g. new stats, gear,
## augments, core on/off, enemy defenses).

signal changed

var total: float = 0.0
var hits: int = 0
var crits: int = 0
var biggest: float = 0.0
var healed: float = 0.0
var per_skill: Dictionary = {}      # name -> {damage, hits, crits}
var activations: Dictionary = {}    # augment/core id -> count
var cuts: Dictionary = {}
var first_t: float = -1.0
var last_t: float = -1.0
var stamina_spent: float = 0.0
var mana_spent: float = 0.0
var baseline: Dictionary = {}
# Mage (Grand Elementalist) metrics
var spell_casts: Dictionary = {}     # id -> {partial, full, charge}
var casts_done: int = 0
var casts_interrupted: int = 0
var poise_dealt: float = 0.0
var control_time: float = 0.0
var sanctum_active_t: float = 0.0
var sanctum_inside_t: float = 0.0
var heal_casts: int = 0
var interaction_events: Dictionary = {}   # Worldweaver elemental interaction id -> count
var _last_res: Dictionary = {}


func _ready() -> void:
	Events.damage_applied.connect(_on_damage)
	Events.healed.connect(_on_heal)
	Events.augment_triggered.connect(_on_aug)
	Events.opening_cut.connect(_on_cut)
	Events.spell_released.connect(_on_spell)
	Events.spell_interrupted.connect(func(c, _id, _r): if c == Game.player and active(): casts_interrupted += 1)
	Events.status_applied.connect(_on_status)
	Events.elemental_interaction.connect(func(c, id, _d): if c == Game.player and active():
		interaction_events[id] = int(interaction_events.get(id, 0)) + 1
		changed.emit())
	Events.fusion_cast.connect(func(c, n): if c == Game.player and active(): _count("Core: " + String(n)))


func active() -> bool:
	return not get_tree().get_nodes_in_group("training_dummy").is_empty()


func reset() -> void:
	total = 0.0
	hits = 0
	crits = 0
	biggest = 0.0
	healed = 0.0
	per_skill.clear()
	activations.clear()
	cuts.clear()
	first_t = -1.0
	last_t = -1.0
	stamina_spent = 0.0
	mana_spent = 0.0
	spell_casts.clear()
	casts_done = 0
	casts_interrupted = 0
	poise_dealt = 0.0
	control_time = 0.0
	sanctum_active_t = 0.0
	sanctum_inside_t = 0.0
	heal_casts = 0
	interaction_events.clear()
	changed.emit()


func _physics_process(_d: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or not active():
		_last_res.clear()
		return
	if _last_res.has("st") and p.stamina < _last_res.st:
		stamina_spent += _last_res.st - p.stamina
	if p.kit is MageKit:
		var m: float = p.kit.mana
		if _last_res.has("mana") and m < _last_res.mana:
			mana_spent += _last_res.mana - m
		_last_res["mana"] = m
	_last_res["st"] = p.stamina
	if p.kit is MageKit and p.kit.elementalist() and p.kit.el.sanctum != null and is_instance_valid(p.kit.el.sanctum):
		sanctum_active_t += _d
		if p.kit.el.in_sanctum():
			sanctum_inside_t += _d


func _on_damage(info) -> void:
	if info.source != Game.player or info.target == null or not is_instance_valid(info.target) or not info.target.is_in_group("training_dummy"):
		return
	var amt: float = info.final_amount + info.absorbed
	poise_dealt += info.poise
	if amt <= 0.0:
		return
	if first_t < 0.0:
		first_t = Game.time
	last_t = Game.time
	total += amt
	hits += 1
	biggest = maxf(biggest, amt)
	if info.is_crit:
		crits += 1
	var nm := String(info.attack_name)
	var e: Dictionary = per_skill.get(nm, {"damage": 0.0, "hits": 0, "crits": 0})
	e.damage += amt
	e.hits += 1
	if info.is_crit:
		e.crits += 1
	per_skill[nm] = e
	changed.emit()


func _on_heal(source, _target, amount, _over, _tags) -> void:
	if source == Game.player and active():
		healed += amount
		changed.emit()


func _on_aug(c, id, _detail) -> void:
	if c == Game.player and active():
		_count(String(id))


func _on_cut(c, _t, cut) -> void:
	if c == Game.player and active():
		cuts[cut] = int(cuts.get(cut, 0)) + 1
		changed.emit()


func _count(id: String) -> void:
	activations[id] = int(activations.get(id, 0)) + 1
	changed.emit()


func duration() -> float:
	if first_t < 0.0:
		return 0.0
	return maxf(1.0, Game.time - first_t)


func dps() -> float:
	return total / duration() if total > 0.0 else 0.0


func per_hit() -> float:
	return total / float(hits) if hits > 0 else 0.0


func crit_rate() -> float:
	return float(crits) / float(hits) if hits > 0 else 0.0


func snapshot() -> Dictionary:
	return {"total": total, "hits": hits, "per_hit": per_hit(), "crit_rate": crit_rate(), "dps": dps(),
		"healed": healed, "biggest": biggest, "duration": duration()}


func save_baseline() -> void:
	baseline = snapshot()
	changed.emit()


## [label, current, baseline, delta%] rows for the comparison table.
func comparison() -> Array:
	var cur := snapshot()
	var out: Array = []
	for k in ["dps", "per_hit", "crit_rate", "total", "hits", "healed"]:
		var b = baseline.get(k, null)
		var d := ""
		if b != null and float(b) > 0.0:
			d = "%+.0f%%" % ((float(cur[k]) / float(b) - 1.0) * 100.0)
		out.append([k, cur[k], b, d])
	return out



func _on_spell(c, id: String, element: String, full: bool, t: float, _mana: float) -> void:
	if c != Game.player or not active():
		return
	casts_done += 1
	if element == "life":
		heal_casts += 1
	var e: Dictionary = spell_casts.get(id, {"partial": 0, "full": 0, "charge": 0.0})
	e[("full" if full else "partial")] += 1
	e.charge += t
	spell_casts[id] = e
	changed.emit()


func _on_status(owner_c, e) -> void:
	if e.source == Game.player and active() and owner_c != null and owner_c.team != 0 and e.mods.has("move_speed") and float(e.mods.move_speed) < 1.0:
		control_time += e.duration


func completion_rate() -> float:
	var n := casts_done + casts_interrupted
	return float(casts_done) / float(n) if n > 0 else 0.0


func heal_per_cast() -> float:
	return healed / float(heal_casts) if heal_casts > 0 else 0.0
