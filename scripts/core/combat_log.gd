extends Node
## Collects combat events into a readable log (shown by the Debug Panel and log overlay).

signal line_added(entry)

const MAX_LINES := 500
const COLORS := {
	"damage": "#e8e8e8", "crit": "#ffd24a", "guard": "#6fb7ff", "heal": "#6dff8c",
	"fusion": "#d58bff", "augment": "#ff9b4a", "system": "#aaaaaa", "death": "#ff5555",
	"status": "#9fe0d8", "exp": "#c8ff7a",
}

var lines: Array = []
var echo_to_stdout := false


func _ready() -> void:
	Events.damage_applied.connect(_on_damage)
	Events.healed.connect(_on_heal)
	Events.guard_event.connect(_on_guard)
	Events.fusion_cast.connect(func(c, n): add("%s weaves %s" % [_n(c), n], "fusion"))
	Events.augment_triggered.connect(func(o, id, d): add("[AUG %s] %s: %s" % [_aug_name(id), _n(o), d], "augment"))
	Events.combatant_downed.connect(func(c): add("%s is DOWNED" % _n(c), "death"))
	Events.combatant_revived.connect(func(c, by): add("%s revived by %s" % [_n(c), _n(by)], "heal"))
	Events.hero_true_death.connect(func(h): add("%s suffered TRUE DEATH" % _n(h), "death"))
	Events.enemy_killed.connect(func(e, k): add("%s slain by %s" % [_n(e), _n(k)], "death"))
	Events.exp_gained.connect(func(c, a, r): add("+%d EXP (%s) [%s]" % [a, r, c], "exp"))
	Events.level_up.connect(func(c, l): add("%s reached level %d" % [c.capitalize(), l], "exp"))
	Events.objective_completed.connect(func(n, x): add("Objective complete: %s (+%d EXP)" % [n, x], "exp"))
	Events.boss_phase.connect(func(b, p): add("%s enters PHASE %d" % [_n(b), p], "death"))
	Events.log_message.connect(add)
	Events.status_applied.connect(_on_status)


func add(text: String, category: String = "system") -> void:
	var entry := {"time": Time.get_ticks_msec() / 1000.0, "text": text, "cat": category}
	lines.append(entry)
	if lines.size() > MAX_LINES:
		lines.pop_front()
	line_added.emit(entry)
	if echo_to_stdout:
		print("[%s] %s" % [category, text])


func clear() -> void:
	lines.clear()


func count(category: String, contains: String = "") -> int:
	var n := 0
	for e in lines:
		if e.cat == category and (contains == "" or String(e.text).contains(contains)):
			n += 1
	return n


func bbcode(entry: Dictionary) -> String:
	return "[color=%s]%s[/color]" % [COLORS.get(entry.cat, "#ffffff"), entry.text]


func _n(o) -> String:
	if o == null or not is_instance_valid(o):
		return "?"
	if "display_name" in o:
		return o.display_name
	return str(o)


func _aug_name(id: String) -> String:
	var a = Game.augment_db.get_augment(id) if Game.augment_db else null
	return a.display_name if a else id


func _on_damage(info) -> void:
	if info.final_amount <= 0.0 and info.absorbed <= 0.0 and not info.guarded:
		return
	var kind := "MAG" if info.damage_type == AttackData.DamageType.MAGIC else "PHY"
	var s := "%s -> %s: %d %s" % [_n(info.source), _n(info.target), roundi(info.final_amount), kind]
	if info.attack_name != "":
		s += " [%s]" % info.attack_name
	if info.hit_count > 1:
		s += " (hit %d/%d)" % [info.hit_index + 1, info.hit_count]
	if info.is_dot:
		s += " (DoT)"
	if info.blocked_frontal:
		s += " (frontal block)"
	if info.is_crit:
		add(s + "  CRIT!", "crit")
	else:
		add(s, "damage")


func _on_heal(source, target, amount, overheal, tags) -> void:
	if amount <= 0.0 and overheal <= 0.0:
		return
	var s := "%s heals %s for %d" % [_n(source), _n(target), roundi(amount)]
	if overheal > 0.5:
		s += " (%d overheal)" % roundi(overheal)
	if tags.get("hot", false):
		s += " (HoT)"
	add(s, "heal")


func _on_guard(defender, info, kind) -> void:
	var raw: float = info.raw_amount
	match kind:
		"perfect": add("%s PERFECT GUARD vs %s (%d -> %d)" % [_n(defender), _n(info.source), roundi(raw), roundi(info.amount)], "guard")
		"guard": add("%s guarded %s (%d -> %d)" % [_n(defender), _n(info.source), roundi(raw), roundi(info.amount)], "guard")
		"break": add("%s GUARD BROKEN by %s" % [_n(defender), _n(info.source)], "guard")
		"intercept": add("%s INTERCEPTED an attack aimed at an ally" % _n(defender), "guard")
		"barrier": add("Barrier absorbed %d damage for %s" % [roundi(info.absorbed), _n(defender)], "guard")
		"dodge": add("%s dodged %s (i-frames)" % [_n(defender), _n(info.source)], "guard")
		"frontal": add("%s braced frontally (Unyielding Charge)" % _n(defender), "guard")
		_: add("%s %s" % [_n(defender), kind], "guard")


func _on_status(target, effect) -> void:
	add("%s gains %s (%.1fs)" % [_n(target), effect.display_name, effect.duration], "status")
