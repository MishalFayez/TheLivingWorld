class_name BalanceConfig
extends Resource
## Every global balance value lives here (res://data/balance/balance.tres). Edit in the Inspector.

@export_group("Stat Scaling")
@export var hp_per_vit: float = 12.0
@export var str_heavy_scale: float = 0.03       ## Heavy/Charged damage +3% per STR
@export var str_crit_damage_scale: float = 0.012 ## +1.2% crit damage per STR
@export var dex_multihit_scale: float = 0.03     ## Multi-hit TOTAL damage +3% per DEX
@export var for_defense_scale: float = 0.05      ## Armor/MR effectiveness +5% per FOR
@export var mas_effect_scale: float = 0.04       ## Buff/debuff/DoT/HoT power +4% per MAS
@export var armor_constant: float = 120.0        ## reduction = A / (A + constant)
@export var weapon_power_per_level: float = 0.08

@export_group("Movement / Stamina / Poise")
@export var move_speed: float = 5.6
@export var stamina_max: float = 100.0
@export var stamina_regen: float = 30.0
@export var stamina_regen_delay: float = 0.7
@export var dodge_cost: float = 22.0
@export var dodge_duration: float = 0.42
@export var dodge_iframe_start: float = 0.03
@export var dodge_iframes: float = 0.28
@export var dodge_speed: float = 11.0
@export var poise_regen: float = 18.0
@export var poise_regen_delay: float = 2.5
@export var stagger_time: float = 0.85
@export var input_buffer: float = 0.15   ## provisional (refoundation spec 4): one stored action for 0.15s
@export var charge_min: float = 0.4

@export_group("Hit Feel")
@export var hitstop_scale: float = 1.0
@export var damage_numbers: bool = true

@export_group("Vanguard")
@export var guard_reduction: float = 0.7
@export var guard_move_mult: float = 0.45
@export var guard_stamina_per_damage: float = 0.8
@export var perfect_guard_window: float = 0.2
@export var perfect_guard_reduction: float = 0.95
@export var perfect_guard_stamina_mult: float = 0.25
@export var perfect_guard_poise_damage: float = 30.0
@export var perfect_guard_rearm: float = 0.35
@export var guard_frontal_angle: float = 75.0
@export var resolve_max: float = 100.0
@export var resolve_on_guard: float = 5.0
@export var resolve_on_perfect: float = 20.0
@export var resolve_on_intercept: float = 15.0
@export var resolve_on_counter: float = 10.0
@export var resolve_on_guarded_strike: float = 3.0
## Guarded Strike: protection while swinging (normal Guard: 70% reduction, 75 deg)
@export var guarded_strike_reduction: float = 0.4
@export var guarded_strike_frontal_angle: float = 45.0
## Shield Plant (design resolution 7, provisional)
@export var shield_plant_duration: float = 4.0
@export var shield_plant_cooldown: float = 18.0
@export var shield_plant_move_mult: float = 0.15
@export var shield_plant_stamina: float = 15.0
@export var shield_plant_reduction: float = 0.85
@export var shield_plant_frontal_angle: float = 90.0
@export var counter_window: float = 1.3
@export var intercept_duration: float = 1.6
@export var intercept_range: float = 4.5
@export var vanguard_threat_mult: float = 2.0
@export var vanguard_threat_aura: float = 15.0   ## threat/sec added to enemies within 7m

@export_group("Mage")
@export var mana_max: float = 100.0
@export var mana_regen: float = 9.0
@export var weave_cooldown: float = 3.0
@export var discipline_casts_per_rank: int = 20
@export var discipline_power_per_rank: float = 0.1
## Major Mutations equipped at once (refoundation spec 10); extra ones stay owned but inactive
@export var max_equipped_mutations: int = 3
## Worldweaver (provisional values from the approved spec; editable for balance testing)
@export var ww_max_solid_formations: int = 2
@export var ww_max_fire_areas: int = 2
@export var ww_fire_area_interval: float = 1.0
@export var ww_max_steam_clouds: int = 2
@export var ww_steam_duration: float = 3.0
@export var ww_steam_radius: float = 2.6
@export var ww_sanctum_radius: float = 3.5
@export var ww_sanctum_duration: float = 10.0
@export var ww_sanctum_cooldown: float = 25.0
@export var ww_sanctum_mana: float = 15.0
@export var ww_mastery_preserve: float = 0.4
@export var ww_mastery_window: float = 2.0
@export var ww_mastery_cooldown: float = 15.0
@export var ww_heal_range: float = 22.0

@export_group("Reaver")
@export var bladecraft_arm_duration: float = 3.0
@export var bladecraft_arm_stamina: float = 4.0
@export var reaver_dodge_cost_mult: float = 0.8
@export var reaver_iframe_mult: float = 1.2

@export_group("Death")
@export var downed_window: float = 15.0
@export var revive_time: float = 2.5
@export var revive_hp_pct: float = 0.35
@export var companion_respawn_time: float = 20.0

@export_group("Progression")
@export var max_level: int = 10
## EXP needed to go from level N to N+1 (index 0 = 1->2).
@export var exp_curve: PackedInt32Array = PackedInt32Array([80, 120, 160, 200, 250, 300, 360, 420, 600])
@export var draft_levels: PackedInt32Array = PackedInt32Array([2, 4, 6, 8, 10])
@export var draft_choices: int = 3
@export var free_points_per_level: int = 2
@export var rarity_weights: Dictionary = {"standard": 60.0, "advanced": 30.0, "exotic": 10.0}
@export var enemy_exp: Dictionary = {"wolf": 18, "raider": 28, "shield_guardian": 45, "ash_caster": 30, "ashen_warden": 500}
@export var elite_exp_mult: float = 3.0
@export var pack_objective_exp: int = 30
@export var area_objective_exp: int = 150
@export var area_exp_mult: Dictionary = {"outskirts": 1.0, "ruins": 1.2, "keep": 1.4}
@export var area_power: Dictionary = {"outskirts": 1.0, "ruins": 1.55, "keep": 2.2}

@export_group("Classes")
@export var class_base: Dictionary = {}
@export var class_growth: Dictionary = {}
