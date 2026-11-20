extends Node
## Global signal bus. Systems communicate through these signals instead of direct references.

signal damage_applied(info)                      ## DamageInfo after mitigation
signal healed(source, target, amount, overheal, tags)
signal guard_event(defender, info, kind)         ## kind: guard / perfect / break / intercept / barrier / frontal_block / dodge
signal fusion_cast(caster, fusion_name)
signal spell_cast(caster, spell_id)
signal augment_triggered(owner, augment_id, detail)
signal status_applied(target, effect)
signal combatant_downed(c)
signal combatant_revived(c, by)
signal hero_true_death(hero)
signal enemy_killed(enemy, killer)
signal exp_gained(class_id, amount, reason)
signal level_up(class_id, level)
signal draft_ready(class_id)
signal augment_added(class_id, aug_id)
signal augment_removed(class_id, aug_id)
signal objective_completed(objective_name, exp)
signal area_entered(area_name)
signal log_message(text, category)
signal player_changed(hero)
signal boss_phase(boss, phase)
signal boss_spawned(boss)
signal element_unlocked(element)
signal notify(text)
## Short combat event banner (PERFECT GUARD, GUARD BROKEN, INTERRUPTED, PROTECTED, CLEANSED, POISE BROKEN). HUD throttles it.
signal combat_notice(text: String, who)
signal unlocks_gained(class_id, milestones)
signal equipment_changed(class_id)
signal item_found(class_id, item_id)
signal saved
signal opening_cut(attacker, target, cut_name)

# Grand Elementalist (Mage) spellcasting
signal spell_charge_started(caster, spell_id: String)
signal spell_released(caster, spell_id: String, element: String, full: bool, charge_time: float, mana: float)
signal spell_interrupted(caster, spell_id: String, reason: String)
signal element_choice_needed(class_id: String)   ## retired (Worldweaver has no element choice)
## Worldweaver: a real elemental interaction happened (Thermal Fracture, Conductive Anchors, ...)
signal elemental_interaction(caster, interaction_id: String, detail: String)
signal formation_changed(formation, change: String)
## Reaver Blade Continuity: attempted link between two Blade Lines (legal or refused)
signal blade_transition(hero, from_line: String, to_line: String, legal: bool)
