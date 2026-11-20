class_name StatusIcon
extends Control
## Buff / debuff / DoT / HoT icon with remaining-time sweep and short label.

var effect: StatusEffect

const KIND_COLOR := {"buff": Color(0.45, 0.75, 1.0), "debuff": Color(1.0, 0.45, 0.35), "dot": Color(1.0, 0.55, 0.2), "hot": Color(0.45, 1.0, 0.55)}
const ICONS := {"burn": "fire", "chill": "frost", "frozen": "frost", "winters_chill": "frost", "frost_armor": "frost",
	"stoneskin": "stone", "last_line": "shield", "renewal": "life", "sanctuary": "life", "gentle_restoration": "life"}


func _init() -> void:
	custom_minimum_size = Vector2(26, 26)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	if effect == null:
		return
	var col: Color = KIND_COLOR.get(effect.kind, UITheme.GOLD)
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.035, 0.035, 0.92))
	var icon: String = ICONS.get(effect.id, "buff" if effect.kind in ["buff", "hot"] else "debuff")
	GameIcon.draw_icon(self, icon, r.grow(-4), col)
	var frac := clampf(effect.remaining / maxf(effect.duration, 0.01), 0.0, 1.0)
	draw_rect(Rect2(Vector2(0, size.y - 3), Vector2(size.x * frac, 3)), col)
	draw_rect(r, col.darkened(0.2), false, 1.0)
	# not colour-only: a shape per priority class (triangle = danger, shield notch = protection)
	var pr := effect.priority()
	if pr <= 1:
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - 9, 0), Vector2(size.x, 0), Vector2(size.x, 9)]), Color(1.0, 0.3, 0.25))
	elif pr == 2:
		draw_rect(Rect2(Vector2(size.x - 8, 1), Vector2(7, 7)), Color(0.55, 0.8, 1.0))
	if effect.stacks > 1:
		draw_string(ThemeDB.fallback_font, Vector2(2, 11), str(effect.stacks), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	if effect.remaining < 10.0:
		draw_string(ThemeDB.fallback_font, Vector2(2, size.y - 5), "%d" % ceili(effect.remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.85))
	# expiring: blink during the last second
	modulate.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.012)) if effect.remaining < 1.0 else 1.0
	var mag := effect.magnitude_text()
	var src := effect.source_name()
	tooltip_text = "%s  [%s]  %.1fs%s%s%s" % [effect.display_name, effect.category().replace("_", " "), effect.remaining,
		("\n" + mag) if mag != "" else "", ("\nfrom " + src) if src != "" else "", ("\nstacks %d" % effect.stacks) if effect.stacks > 1 else ""]
