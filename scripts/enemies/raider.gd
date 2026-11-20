class_name Raider
extends Enemy
## Melee combinations (3-hit chain) and a slow, readable Heavy overhead with a long punish window.


func setup_type() -> void:
	display_name = "Raider"
	enemy_type = "raider"
	weight_class = "medium"
	base_hp = 110.0
	base_poise = 45.0
	base_power = 13.0
	armor = 20.0
	magic_resist = 10.0
	move_speed = 4.3
	turn_speed = 6.0
	global_cd = 1.4
	post_pause = 0.8
	engage_delay = Vector2(0.35, 0.8)
	chain_chance = 0.75
	load_attacks(["raider_combo1", "raider_heavy"])
	base_color = Color(0.42, 0.28, 0.17)
	CharModel.build(self, "raider", null)
