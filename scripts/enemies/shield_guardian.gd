class_name ShieldGuardian
extends Enemy
## Frontal shield defense (light hits blocked, heavies partially), high poise, slow turning so it can
## be flanked, powerful slams and an orange-telegraphed Guard Breaker that breaks normal guards.


func setup_type() -> void:
	display_name = "Shield Guardian"
	enemy_type = "shield_guardian"
	weight_class = "heavy"
	base_hp = 220.0
	base_poise = 140.0
	base_power = 16.0
	armor = 45.0
	magic_resist = 20.0
	move_speed = 2.9
	turn_speed = 2.2
	global_cd = 1.6
	post_pause = 0.9
	engage_delay = Vector2(0.4, 0.9)
	body_scale = 1.15
	stagger_mult = 1.2
	load_attacks(["guardian_bash", "guardian_slam", "guardian_breaker"])
	base_color = Color(0.32, 0.32, 0.36)
	CharModel.build(self, "guardian", null)


func pre_damage(info: DamageInfo) -> void:
	if info.is_dot or is_staggered():
		return
	if is_frontal(info.source_pos, 70.0):
		info.blocked_frontal = true
		if info.attack != null and info.attack.has_tag("sunder"):
			# Sunder Edge: extra effectiveness against a raised guard (not a full bypass)
			info.amount *= 0.75
			info.poise *= 1.5
		elif info.is_heavy or info.guard_break:
			info.amount *= 0.6
			info.poise *= 0.9
		elif statuses.has("sundered"):
			# Sundering Verdict: a weakened guard lets more through
			info.amount *= 0.6
			info.poise *= 0.7
		else:
			info.amount *= 0.25
			info.poise *= 0.35
		FX.number(self, "BLOCK", Color(0.8, 0.8, 0.9), 0.7)
