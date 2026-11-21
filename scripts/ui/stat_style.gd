class_name StatStyle
extends RefCounted
## LEVEL10-FOUNDATION-005 (Part 8.1): colors + icons + labels for stats and effect types. Colors are never
## the only signal: every helper prints the abbreviation / text next to the color.

const STAT := {
	"str": {"abbr": "STR", "name": "Strength", "color": Color("#F28C52"), "icon": "sword"},
	"dex": {"abbr": "DEX", "name": "Dexterity", "color": Color("#48C8D8"), "icon": "flurry"},
	"vit": {"abbr": "VIT", "name": "Vitality", "color": Color("#66C985"), "icon": "life"},
	"for": {"abbr": "FOR", "name": "Fortitude", "color": Color("#80A8E8"), "icon": "guard"},
	"mas": {"abbr": "MAS", "name": "Mastery", "color": Color("#BD92F5"), "icon": "sigil"},
}
const EFFECT := {
	"physical": Color("#F5D2A8"),   # warm white / orange
	"magic": Color("#9A8CFF"),      # blue-violet
	"heal": Color("#5FDB7A"),       # green
	"poise": Color("#F2B544"),      # gold / amber
	"stamina": Color("#B8E05A"),    # yellow-green
	"mana": Color("#5A9BFF"),       # blue
	"crit": Color("#FFD84A"),       # bright gold
	"negative": Color("#C9665E"),   # muted red
	"neutral": Color("#E8DCC0"),
}
const EFFECT_LABEL := {"physical": "Physical", "magic": "Magic", "heal": "Healing", "poise": "Poise", "stamina": "Stamina",
	"mana": "Mana", "crit": "Critical", "negative": "Cost"}


static func hex(c: Color) -> String:
	return c.to_html(false)


## "[color=#F28C52]STR[/color]"
static func stat_tag(k: String) -> String:
	var s: Dictionary = STAT.get(k, {})
	return "[color=#%s]%s[/color]" % [hex(s.get("color", Color.WHITE)), s.get("abbr", k.to_upper())]


static func stat_color(k: String) -> Color:
	return STAT.get(k, {}).get("color", Color.WHITE)


static func fx(kind: String, text: String) -> String:
	return "[color=#%s]%s[/color]" % [hex(EFFECT.get(kind, Color.WHITE)), text]


## "[color=..]Physical Damage: 136[/color]"
static func labeled(kind: String, label: String, value: String) -> String:
	return "%s %s" % [fx(kind, label + ":"), value]


static func num(v: float, decimals: int = 0) -> String:
	if decimals <= 0:
		return "%d" % roundi(v)
	return ("%." + str(decimals) + "f") % v


static func pct(v: float, decimals: int = 0) -> String:
	return num(v * 100.0, decimals) + "%"


static func delta(a: float, b: float, decimals: int = 0) -> String:
	var d := b - a
	if absf(d) < pow(10.0, -decimals) * 0.5:
		return ""
	var sgn := "+" if d > 0 else ""
	return fx("heal" if d > 0 else "negative", "(%s%s)" % [sgn, num(d, decimals)])
