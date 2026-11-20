class_name MainMenuText
extends RefCounted
## Shared text for menus.

const CONTROLS := "WASD  move   ·   Mouse  camera   ·   Space  dodge   ·   Tab / MMB  lock-on   ·   Wheel Up / X  next target right   ·   Wheel Down / Z  next target left\n" \
	+ "LMB  light   ·   RMB  heavy (hold = charged, when learned)\n\n" \
	+ "VANGUARD  —  Shift  Aegis Guard (raise just before impact = Perfect Guard)   ·   1  Shield Rush   ·   2  Judgment Strike (hold)   ·   3  Iron Sweep   ·   LMB in counter window = Aegis Counter\n\n" \
	+ "MAGE  —  HOLD LMB / RMB / 1 to charge the equipped spells (release early = partial, hold = full)   ·   F  Lifeline   ·   E  Arcane Sanctum   ·   3  Protective Renewal   ·   T  cycle heal target   ·   2  most injured ally   ·   B  Spellbook\n\n" \
	+ "REAVER  —  strike enemy Openings: LMB Tempo Cut · RMB Sunder Cut · 1 Piercing Lunge (Vital Cut) · 2 Tempest Flurry · Perfect Dodge opens the attacker\n\n" \
	+ "G  interact   ·   R  revive ally   ·   C  character   ·   K  skills   ·   I  inventory   ·   M  map   ·   J  journal   ·   F1  debug   ·   F2  combat log   ·   F11  fullscreen   ·   Esc  menu"

const CLASSES := {
	"vanguard": {
		"role": "TANK  ·  PROTECTOR", "core": "Aegis Guard  ·  Resolve",
		"text": "A knight in blue and gold plate. Read the enemy, raise the shield at the last instant and answer with counters. Protects allies by intercepting the blows meant for them.",
		"strengths": ["Perfect Guard and Aegis Counter reward timing", "Highest survivability; draws enemy attention", "Intercepts attacks aimed at endangered allies"],
		"difficulty": "Moderate",
	},
	"mage": {
		"role": "HEALER  ·  MAGIC DPS", "core": "Grand Elementalist  ·  Charged Spellcasting",
		"text": "A silver-haired spellcaster with a crystal staff. Prepares and releases powerful charged spells - release early for a quick cast or hold for the full effect - and is the party's primary healer. Fire destroys, Frost shapes movement, Stone breaks guards, Storm chains, Life heals and protects.",
		"strengths": ["True healer: prepared heals, instant emergency rescue, preventive protection", "Five elements with different battlefield roles", "Arcane Sanctum empowers spells cast from the circle"],
		"difficulty": "Moderate - High",
	},
	"reaver": {
		"role": "PHYSICAL DPS  ·  DUELIST", "core": "Sword Sense  ·  Openings",
		"text": "A red-haired swordsman in a crimson coat. Watches the enemy instead of a meter: strike in their recovery, their stagger or right after a Perfect Dodge, and choose the right cut for the opening.",
		"strengths": ["Highest single-target damage when timing is right", "Fast combos, long dodge, precise lunges", "Punishes mistakes - every opening is a choice"],
		"difficulty": "High",
	},
}
