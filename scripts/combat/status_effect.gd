class_name StatusEffect
extends RefCounted
## Buff / debuff / DoT / HoT. `mods` are multiplicative stat modifiers read by StatusComponent.mult().
## Known mod keys: damage_taken, damage_dealt, move_speed, attack_speed, poise_damage, poise_taken.

var id: String = ""
var display_name: String = ""
var kind: String = "buff"     # buff / debuff / dot / hot
var duration: float = 3.0
var remaining: float = 3.0
var tick_interval: float = 1.0
var tick_t: float = 0.0
var tick_amount: float = 0.0
var mods: Dictionary = {}
var source = null
var tags: Dictionary = {}
var stacks: int = 1
## "refresh" (default: re-application refreshes duration) - the only rule the game uses today
var expiration: String = "refresh"

const CONTROL_IDS := ["stagger", "frozen", "chill", "winters_chill"]
const PROTECTIVE_IDS := ["last_line", "protective_renewal", "renewal_mend", "frost_armor", "stoneskin", "sanctuary"]


## Display model (refoundation spec 13): category + priority. 0 = crowd control, 1 = dangerous
## debuffs / DoTs, 2 = critical protection, 3 = important buffs / HoTs, 4 = secondary markers.
func category() -> String:
	if id in CONTROL_IDS or float(mods.get("move_speed", 1.0)) <= 0.7:
		return "control"
	if id in PROTECTIVE_IDS or float(mods.get("damage_taken", 1.0)) < 1.0:
		return "protective"
	if kind == "dot":
		return "damage_over_time"
	if kind == "hot":
		return "healing_over_time"
	if kind == "debuff":
		return "debuff" if not mods.is_empty() else "marker"
	return "buff" if not mods.is_empty() else "marker"


func priority() -> int:
	match category():
		"control":
			return 0
		"debuff", "damage_over_time":
			return 1
		"protective":
			return 2
		"buff", "healing_over_time":
			return 3
	return 4


## Human-readable magnitude ("-45% speed", "12 /s").
func magnitude_text() -> String:
	var parts: Array = []
	if tick_amount > 0.0:
		parts.append("%d /%.0fs" % [roundi(tick_amount), tick_interval])
	for k in mods.keys():
		var m: float = mods[k]
		var pct := roundi((m - 1.0) * 100.0)
		if pct != 0:
			parts.append("%+d%% %s" % [pct, String(k).replace("_", " ")])
	return ", ".join(parts)


func source_name() -> String:
	return source.display_name if source != null and is_instance_valid(source) and "display_name" in source else ""

static func make(p_id: String, p_name: String, p_kind: String, p_duration: float, p_mods: Dictionary = {}, p_tick_amount: float = 0.0, p_tick_interval: float = 1.0) -> StatusEffect:
	var e := StatusEffect.new()
	e.id = p_id
	e.display_name = p_name
	e.kind = p_kind
	e.duration = p_duration
	e.remaining = p_duration
	e.mods = p_mods
	e.tick_amount = p_tick_amount
	e.tick_interval = p_tick_interval
	return e


## Mastery scaling: magnitudes and (partially) durations grow with the SOURCE's effect power.
func scaled_by(power: float) -> StatusEffect:
	if power == 1.0:
		return self
	tick_amount *= power
	for k in mods.keys():
		var m: float = mods[k]
		if m >= 1.0:
			mods[k] = 1.0 + (m - 1.0) * power
		else:
			mods[k] = maxf(0.1, 1.0 - (1.0 - m) * power)
	duration *= 1.0 + (power - 1.0) * 0.5
	remaining = duration
	return self
