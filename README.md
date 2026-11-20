# The Living World — Ashen Valley Prototype (Godot 4.7, GDScript)

> **Current build: Three-Class Combat Refoundation.** This README describes the **current** game first. Everything under **ARCHIVE** at the bottom is historical: its controls and systems are **obsolete**.

Documents shipped with this build:
- `DESIGN_TECHNICAL_FEEDBACK.md`: the critical design and technical review, with recommendations tagged A / B / C.
- `IMPLEMENTATION_REPORT.md`: what was implemented, what is incomplete, deviations, test results, and old vs new measurements.
- `CLASS_PLAYTEST_GUIDE.md`: step-by-step playtests for every class and build.
- `PLAYTEST_FEEDBACK.md`: the scoring template for human testers. It is empty on purpose.

## Run
- Open `project.godot` in **Godot 4.7** and press F5.
- Choose a class (Vanguard, Mage or Reaver) and Solo or Party.
- Training Grounds are reachable from the map and from the Lab.

## Current controls

| Common | Action |
|---|---|
| WASD | Move |
| Mouse | Camera |
| Space | Dodge |
| Tab / mouse wheel | Lock on / switch target |
| C | Character / attributes (preview → Confirm / Cancel) |
| I / K / J / M | Inventory / Skills / Journal / Map |
| B | Spellbook (Mage) |
| Esc | Pause |
| F1 | Debug Panel + **Class Experience Lab** |

**Vanguard (Aegis Knight)**

| Input | Action |
|---|---|
| LMB | Sword |
| RMB | Heavy |
| Shift (hold) | Guard; raise it just before a hit for a **Perfect Guard** |
| LMB after a Perfect Guard | Aegis Counter |
| Shift + LMB | Guarded Strike (Lv1) |
| 1 (tap / hold 0.35s) | Shield Rush; toward an endangered ally = Interception (Lv7). Hold = Empowered Shield Rush (30 Resolve, Lv5) |
| 2 (hold) | Judgment Strike: Riposte right after a Perfect Guard; full charge + 40 Resolve = Verdict Strike |
| 3 (tap / hold 0.35s) | Iron Sweep; hold = Aegis Sweep (25 Resolve) |
| E | Shield Plant (Lv12, Build Showcase only) |

**Mage (Worldweaver)**

| Input | Action |
|---|---|
| LMB / RMB / 1 (hold, release) | Charged spell slots (choose spells in the Spellbook, B) |
| 3 | Utility spell; hold to aim formations |
| F | Lifeline |
| E | Arcane Sanctum |
| T | Cycle heal target |
| 2 | Most injured ally |
| Space | Dodge; cancels a charge at no mana cost |

**Reaver (Swordmaster)**

| Input | Action |
|---|---|
| LMB | Forward Cut (always, even while strafing) |
| Shift + A / D + LMB | Lateral Cut left / right with a short side step (new `blade_modifier` action on Shift; no binding changed) |
| RMB | Heavy Cut; from Lv7, hold for Draw Cut |
| Space then LMB | Slip Cut |
| 1 / 2 / 3 / E | Skill loadout (Skills menu, K): Lunge, Flow Step, Crosscut, Flurry, and the showcase skills Sunder Edge / Turning Edge |
| F | Final Stroke (Lv18 showcase) while its 1.5s opportunity is open |

Press a **different** cut during the previous cut's recovery to **link** it. Forward → Forward is allowed but never links. A left ↔ right reversal is not a legal link.

## Current gameplay systems

| System | State |
|---|---|
| Shared combat | AttackRunner phases (startup / active / recovery), cancel windows, **0.15s single-action input buffer**, dodge with i-frames, poise / stagger, hitstop, lock-on, near-wall camera fix |
| Vanguard | Aegis Guard, Perfect Guard, Aegis Counter, **Guarded Strike**, Resolve with three spenders (Empowered Shield Rush 30 / Verdict Strike 40 / Aegis Sweep 25), Shield Rush + Interception, Judgment Strike, Iron Sweep, **Shield Plant** (Lv12 showcase). Augments: Iron Reprisal, Last Line, Steadfast, Crushing Rhythm, Unyielding Charge, Phantom Bulwark, **Guardian's Return**, **Verdict of Steel**, **Rolling Fortress** (modifies Shield Plant), **Guardian's Reserve** |
| Mage | Worldweaver (charged spells, five elements, formations, Elemental States, four interactions including **natural Conductive Anchors**, Arcane Sanctum). Augments: the 9 specified, including **Storm Lattice** and **Second Heart** |
| Reaver | **Swordmaster** core: Blade Lines (Shift + A/D lateral), Measure, Footwork, Blade Continuity, Flow Step, Crosscut, Discipline; showcase Sunder Edge / Turning Edge / Final Stroke; 4-slot skill loadout. Augments: Flowing Edge, Crosswind, Unbroken Line, Sundering Verdict, Drawn Horizon, Measured Step, Turning Steel, Needlepoint |
| Progression | Lv1–10 tables per class (below). Drafts at **4, 8, 10**. **Max 3 Major Mutations equipped** (extras kept, swap in Augments). Lv11–30 slot framework (15 / 20 / 25 / 30), content pending |
| UI | Class HUDs, status icons ordered by priority (CC → danger → protection → buffs → secondary) with shape marks, timers, magnitude tooltips, and throttled combat banners (PERFECT GUARD, GUARD BROKEN, INTERRUPTED, PROTECTED, POISE BROKEN) |
| Testing | **Class Experience Lab** (F1 → Lab): presets, nine BUILD SHOWCASES, encounters, resets, teleports, baseline. **Guided Playtest Mode**: 30 scenarios. All of it is session-only and never saved |
| Death | Downed / revive / True Death / optional permadeath, unchanged; per-class progression isolation |

## Progression (Lv1–10)
| Lv | Vanguard | Mage | Reaver |
|---|---|---|---|
| 1 | Guard, Perfect Guard, Aegis Counter, Guarded Strike | Fire, Life, Life Bloom, Lifeline | Forward / Lateral / Heavy Cut (+ Slip Cut), Blade Continuity |
| 2 | Stats | Stats | Stats |
| 3 | Shield Rush | Frost + Crystal Formation | Piercing Lunge |
| 4 | Draft | Draft | Draft |
| 5 | Resolve Spending | Arcane Sanctum | Flow Step + expanded continuity |
| 6 | Stats | Stats | Stats |
| 7 | Judgment Strike + Interception | Stone + Earthbreaker + Protective Renewal | Draw Cut + Crosscut |
| 8 | Advanced draft | Advanced draft | Advanced draft |
| 9 | Iron Sweep | Storm + Thunder Conduit | Tempest Flurry |
| 10 | Aegis Mastery + draft | Arcane Mastery + draft | Swordmaster's Discipline + draft |
| 12* / 15* / 18* | Shield Plant (12) | — | Sunder Edge (12), Turning Edge (15), Final Stroke (18) |

\* Beyond the Lv10 prototype cap: Build Showcase (Lab) only, labelled in the Skills menu. Not natural unlocks.

## Retired systems (Debug comparison only, never in normal play)
- Mage: Arcane Weave / Elemental Echo, Ley Sigils, the Grand Elementalist pieces.
- Reaver: Sword Sense (Openings, Tempo / Sunder / Vital cuts) and Bladecraft. Both are selectable in Debug → Character → Class cores, with their own unlock levels and augments.
- The full previous project is kept in `AshenValley_BACKUP_before_Refoundation.zip`.

## Missing mechanics (spec gaps: reported, not invented)
- **Vanguard:** the detailed Aegis Mastery effect.
- **Reaver:** the Finality augment.
- **Mage:** advanced spells still have no unlock levels (showcase / Debug only).
- **All classes:** Lv11–30 content.
- **Not done this pass:** sound effects (none exist) and AnimationTree crossfades.

## Test results (Godot 4.7.2, headless, `--fixed-fps 60`)
| Suite | Result |
|---|---|
| resolution_runner (Design Resolution) | 78 / 78 |
| refoundation_runner | 71 / 71 |
| mage_runner | 164 / 164 |
| test_runner | 136 / 136 |
| update5_runner | 63 / 63 |
| smoke_runner | 31 / 31 |
| camera_jitter | 7 / 7 (1 snap of 0.57m in an 18-run wall census; 0 frames inside geometry) |

There were no script errors in the logs. Old vs new measurements: `tests/compare_runner.tscn`.
**These tests verify mechanics, not enjoyment.**

## Manual playtesting
Follow `CLASS_PLAYTEST_GUIDE.md` (scenarios V1–V4, VH–VJ, M1–M5, R1–R5, RA–RG, A–F) and record scores in `PLAYTEST_FEEDBACK.md`.

## Known limitations
- **Art:** procedural placeholder characters, animation and VFX. They are not final art.
- **Sound:** none.
- **Camera:** one reproducible 0.57m anti-clipping snap when walking into a tall pillar with the camera behind (not fully fixed; see DESIGN_TECHNICAL_FEEDBACK.md §6).
- **Reaver:** Forward → Forward no longer links; spam keeps about 76% of deliberate-path DPS (measured). The comfort of the Shift + A/D chord needs human testing.
- **Mage:** setup cost of Worldcraft before Lv10.

---

## Mage details — THE WORLDWEAVER (current; refoundation changes listed in IMPLEMENTATION_REPORT.md)

This build implements the approved *Mage — The Worldweaver* specification. It replaces the earlier
"Grand Elementalist" Mage. The previous project is kept as `AshenValley_BACKUP_before_Worldweaver.zip`.
The retired Grand Elementalist pieces (ice crystals, frost veil, static line, stone bulwark,
element-choice popup, old tests) are not part of the project any more.
The internal core id is still `elementalist`, so saves and the Debug core switch keep working.
The rejected Arcane Weave and Ley Sigils cores stay reachable only through Debug, for comparison.

### Controls (Mage) — no input binding was changed
| Key | Action |
|---|---|
| LMB / RMB / 1 (hold) | Charged spell slots 1-3. Choose the spells in the Spellbook (B). Release before full charge for the partial version, or at full charge for the full version. |
| 3 | Utility slot. Defaults to Protective Renewal at Lv7 (others are advanced spells). For formation utilities, **hold 3** to aim with the placement preview and release to cast. A tap casts at the current aim point. |
| F | Lifeline (instant emergency heal, 12s cooldown) |
| E | Arcane Sanctum (Lv5) |
| T / 2 | Cycle heal target (you → allies) / select the most injured ally. With no selection, the heal target is yourself. |
| Space | Dodge. It cancels a charge, and no mana is spent. At Lv10, Arcane Mastery can preserve part of the charge. |
| Tab / mouse wheel | Lock-on / switch target (unchanged) |

No new key was needed. Key 3 was already the Mage's skill3 action; it now runs the Spellbook utility slot.
Focused / Shared Bloom is switched in the Spellbook, so no new binding was added for it either.

### Charged casting (spec section 3)
The rules:
- Minimum release is 0.25s for every charged spell.
- Full charge is 1.20s for standard spells and 1.80s for major spells (Earthbreaker).
- Movement while charging is 65% (45% for Earthbreaker).
- Holding past full charge adds nothing, and there is no perfect-timing bonus.
- Mana is spent only on a successful release. A dodge-cancel, or a cast with no valid target, costs nothing.

The feedback:
- An element-specific charge pose and `ChargeFX` energy that grows while you hold.
- A clear full-charge flare, plus the HUD ring.
- Cast recovery runs through the normal AttackRunner, so there are no animation lockups.

### Spells
| Element | Spell | Slot | Unlock |
|---|---|---|---|
| Fire | Flame Cataclysm. Partial: compact projectile, small explosion, no area. Full: bigger explosion and ONE burning area (2.5m, 5s, damage every 1s). | charged | Lv1 |
| Fire | Inferno Wave (forward wave, each enemy hit once) · Cinderfall (telegraphed delayed impact) | charged | advanced: Debug grant |
| Frost | Crystal Formation. Partial: 1.5m obstruction + limited Chill. Full: 4m connected formation + Chill within 3.5m. Lifetime 7s, placement preview, orientation follows aim. | charged | Lv3 |
| Frost | Glacial Spear (single target + Chill) · Frozen Bastion (instant short-lived wall, cooldown) | charged / utility | advanced: Debug grant |
| Stone | Earthbreaker (major). Partial: Magic + moderate Poise. Full: stronger Poise + limited area. Displacement by weight: light displaced, medium limited, heavy and bosses none. | charged | Lv7 |
| Stone | Rising Pillar (destructible, limited displacement) · Stone Ward (directional cover) | utility | advanced: Debug grant |
| Storm | Thunder Conduit. Partial: one target. Full: chain, max 3 total targets, 6m jumps, no repeats. It does not interrupt. | charged | Lv9 |
| Storm | Lightning Verdict (interrupts only attacks flagged `interruptible`; bosses resist) · Storm Arc (aimed route) | charged | advanced: Debug grant |
| Life | Life Bloom (partial moderate heal; full larger and more mana-efficient) · Lifeline (instant, 12s cooldown) | charged / F | Lv1 |
| Life | Protective Renewal (limited shield + part of the damage taken is healed back; never full immunity) | utility | Lv7 |
| Life | Verdant Renewal (charged HoT) · Focused / Shared Bloom (Spellbook toggle) | charged | advanced: Debug grant |

### World formations (spec section 4)
`WorldFormation` (scripts/combat/world_formation.gd) is a physical object built from sections.
Each formation has:
- An owner, an element and a kind.
- A lifetime, and HP per section (durability).
- States, and a full `destroy()` cleanup.

Collision:
- Ice uses `LAYER_FROST`: it blocks enemies only, so allies are never trapped.
- Stone uses `LAYER_WORLD`: it blocks everyone and blocks projectiles and line of sight.

Limits:
- 2 solid formations per Mage. The oldest is destroyed: collision, groups, states, signal and VFX are all cleaned up.
- 2 burning areas. Steam has its own cap.

Enemy interaction:
- Formations are never baked into the navmesh. Enemies steer around them (`WorldFormation.steer` in `Enemy.move_to`).
- Bosses break a formation on contact.
- Enemy melee hits and projectiles damage sections.

### Elemental interactions (spec section 10) — only through real effects and formations
- **Thermal Fracture** (Fire touches ice):
  - The affected sections are destroyed.
  - Partial Fire releases a short-range fragment burst.
  - Full Fire creates a 3s steam cloud. It blocks player lock-on, Mage targeting, new enemy target acquisition and enemy ranged attacks. Bosses are exempt, and clouds never stack.
- **Shattered Winter** (Stone impact on ice):
  - Partial damages the ice; full destroys it.
  - Directional fragments go along the impact direction.
  - It triggers once and never re-triggers itself.
- **Conductive Anchors** (Storm near a *Conductive* Stone formation):
  - The anchor relays a Thunder Conduit or Storm Arc once per cast, with no loops and no extra chain targets.
  - Stone is never conductive by default. **Refoundation:** a full Thunder Conduit whose path passes a Stone formation makes it Conductive for 6s in normal gameplay (Storm Lattice: 9s, two relays).
- **Living Bastion** (full Life Bloom or full Verdant Renewal on an ally within 3m of a *Fortified* Stone formation):
  - The formation becomes *Vitalized* for 6s.
  - It heals allies within 3m by 0.12 × weapon power per second (MAS-scaled). That is far below Life Bloom.
  - It stays destructible.

Elemental States (`ElementalStates`):
- Burning and Chill apply to combatants.
- Frozen Structure, Conductive, Fortified and Vitalized apply to formations.
- Interactions are emitted as `Events.elemental_interaction`. They are logged, shown as a floating label, and counted in Training and Debug.

### Arcane Sanctum (Lv5, E)
The circle is 3.5m, lasts 10s, has a 25s cooldown and costs 15 mana. It is stationary.

Spells cast **from inside** it get one enhancement per element:
- **Fire:** a full impact produces a secondary flame wave.
- **Frost:** the new ice connects to your nearest ice formation within 8m.
- **Stone:** a qualifying impact raises a small Fortified formation.
- **Storm:** one additional relay (one more chain jump or arc relay).
- **Life:** 35% of the charged heal reaches one additional injured ally.

Every spell works normally outside the circle. The HUD shows the Sanctum state, and the Spellbook lists each enhancement.

### Progression and augments
| Level | Unlock |
|---|---|
| 1 | Fire + Life: Flame Cataclysm, Life Bloom, Lifeline |
| 2 | Stats |
| 3 | Frost: Crystal Formation |
| 4 | Augment draft |
| 5 | Arcane Sanctum |
| 6 | Stats |
| 7 | Stone: Earthbreaker, plus Protective Renewal |
| 8 | Advanced draft |
| 9 | Storm: Thunder Conduit |
| 10 | Arcane Mastery: 40% of the charge kept for 2s on a dodge, same spell only, 15s cooldown |

There is no element choice. **Refoundation:** drafts are now at Lv 4, 8 and 10.

Augments: the draft pool is the approved list. The refoundation spec added **Storm Lattice** and **Second Heart**, so there are 9.

| Augment | Build path |
|---|---|
| Infernal Collapse | Primal Sorcery |
| Crystal Chain | Worldcraft |
| Mountainfall | Primal Sorcery |
| Living Thunder | Primal Sorcery |
| Everlasting Bloom (conversion only, no bonus) | Lifebinding |
| Wandering Sanctum (follows, 70% effect) | Worldcraft |
| Living Bastion (enhances the interaction: 1.5× duration, 4.5m) | Lifebinding + Worldcraft |

Draft rules:
- No augments are offered for locked elements or with missing prerequisites.
- The six extra augments from the earlier build were removed.
- Legacy augments only appear for the legacy cores.

### Debug (F1 → Training / Class) and Training Grounds
The Debug panel can:
- Start a fresh Level 1 Mage for the session only.
- Grant or remove each element and each spell (advanced ones included, plus Focused / Shared Bloom).
- Enable or disable the Sanctum, or summon it now.
- Make Stone formations Conductive (test only).
- Show a formation inspector (kind, time left, sections, HP, states) and the latest elemental interactions.
- Show the last release (partial / full / in Sanctum).
- Wound allies or only yourself, and spawn wolves, raiders, guardians, casters or the dummy.

The existing set-level, augment add/remove, stat reset and baseline compare tools are unchanged.

The training dummy panel shows:
- Damage, Poise, healing and mana.
- Casts (partial / full and average charge time).
- Augment activations and elemental interaction counts.

Every Debug change taints the session, so it is never saved. Debug grants are not written to the save; a test checks this.

### Verified automatically (Godot 4.7.2, headless, `--fixed-fps 60`)
| Suite | Result |
|---|---|
| `tests/mage_runner.tscn`: Worldweaver milestones A–F | **164 / 164 passed**, no script errors in the log |
| `tests/test_runner.tscn` | 136 / 136 |
| `tests/update5_runner.tscn` | 63 / 63 |
| `tests/smoke_runner.tscn` (all three classes load, full Valley run, boss, save) | 31 / 31 |
| `tests/camera_jitter.tscn` | 6 / 6 after the refoundation camera fix |

The near-wall camera item that failed at the time was investigated and fixed in the refoundation (see `IMPLEMENTATION_REPORT.md`).

`mage_runner` covers:
- Charge timings and partial/full release, no rapid combo, no bonus past full charge, dodge-cancel at no mana cost and no lockup.
- Healing with no enemies, explicit target priority and out-of-range refusal (no silent redirect), Lifeline cooldown.
- Burning area size, interval and limit, and the Burning state.
- Formation creation, preview, orientation, width, lifetime, durability and boss break, plus the 2-formation limit with cleanup and enemies steering around ice without passing through it.
- Earthbreaker Poise and weight displacement, the Thunder 3-target / 6m / no-repeat / no-interrupt rules, and every advanced spell.
- All four interactions, steam LOS for both sides, boss exemption and no stacking.
- The five Sanctum enhancements, stationary behaviour and no effect outside the circle.
- The Lv1–10 table, drafts at 4 and 8 only, Arcane Mastery 40% / 2s / 15s, the augment pool and its eligibility, and each augment's effect.
- STR and MAS scaling, the AI healing and attacking with the same rules, and save/load of the loadout without Debug grants.

**These tests prove mechanics only. They do not show the Mage is fun; that needs human playtesting.**

### Gameplay feel that needs human playtesting
- Charge timings and movement while charging.
- Whether the partial/full choice feels meaningful.
- Formation size, lifetime and readability in a crowd.
- Whether steam is annoying or useful.
- Interaction frequency.
- Sanctum value versus mobility.
- Healing balance in party play and AI companion judgement.
- Boss fight pacing with formations.

### Known technical limitations
- **Visuals are procedural primitives.** Toon materials, prisms and boxes, translucent puffs, billboard particles and unshaded rings. They read clearly in the screenshots (`screenshots/mage_ww_*.png`), but they are **not** final "beautiful high-fantasy" art.
- **Spell animations are procedural poses** (ProcAnim cast and charge styles), not authored animation clips.
- **Enemy avoidance is local steering, not a navmesh rebake.** An enemy can hesitate at a very long chained barrier.
- **Steam is a sphere test.** It blocks sight; it does not block melee contact.
- **Healing uses weapon power × spell power.** There is no separate "Healing Power" stat in this project (see report).

### Manual playtesting checklist (Mage)
1. New Mage at Lv1:
   - Hold and release LMB at different times and confirm partial vs full in the HUD ring and the visuals.
   - Spam LMB: there should be no combo.
   - Dodge mid-charge: no mana should be spent.
2. With no enemies around, Life Bloom yourself.
3. Press T to select an ally, walk 25m away and cast: the cast should be refused.
4. Press F: Lifeline, 12s cooldown.
5. At Lv3, hold 1 while turning the camera: the preview should follow and rotate. Release partial and full on a wolf pack, then watch them path around the ice.
6. Cast three ice formations: the first should disappear cleanly.
7. Fire into your ice, partial and full: fragments vs steam. Try to lock on through the steam.
8. At Lv5, cast E, then cast each element from inside and outside the circle.
9. At Lv7, Earthbreaker the wolf, the raider, the guardian and the boss: displacement should differ. Earthbreaker your ice to get Shattered Winter.
10. Debug: grant Stone Ward, cast it, then fully charge Life Bloom on an ally standing next to it for Living Bastion. Mark the stone Conductive, then chain Thunder Conduit through it.
11. At Lv9, Thunder Conduit on 4 grouped raiders should hit 3. Debug-grant Lightning Verdict and use it on an Ash Caster mid-cast, then on the boss: the boss should resist.
12. At Lv10, dodge out of a charge and re-press within 2s: you should keep about 40%.
13. Party with an AI Mage: it should heal before attacking and avoid danger.
14. Boss fight: ice and stone must never hold the boss.
15. Save, quit and reload: the loadout and Bloom mode should be kept.

### Report: missing, ambiguous or contradictory specification details (not invented, flagged)
1. **Advanced spells have no unlock level.** Inferno Wave, Cinderfall, Glacial Spear, Frozen Bastion, Rising Pillar, Stone Ward, Lightning Verdict, Storm Arc, Verdant Renewal and Focused/Shared Bloom are not in the L1–10 table. They are implemented and obtainable **only through Debug grants** until a source is approved.
2. **Partial vs full effects for the advanced charged spells are not specified.** They use the same function and scale only in power, size or length. Lightning Verdict interrupts on both partial and full.
3. **Cast type is not specified** for Rising Pillar and Stone Ward. They are treated as instant utility spells with cooldowns, like Frozen Bastion ("no long charge").
4. ~~The source of conductivity is undefined.~~ **Resolved by the refoundation spec:** a full Thunder Conduit contacting a Stone formation establishes it (6s).
5. **Living Bastion trigger:** "a formation receives a qualifying Life spell" does not say how a formation is targeted. Implemented as: a *full* Life Bloom or Verdant Renewal whose heal target is within 3m of the Mage's Fortified Stone formation.
6. **Living Bastion augment** says "unlocks or enhances". The interaction itself is base gameplay (section 10), so the augment *enhances* it (1.5× duration, 4.5m radius).
7. **The Fortified state has no defined effect.** It marks defensive Stone formations (Ward, Pillar, Sanctum stone) as eligible for Living Bastion and nothing else.
8. **Sanctum Storm:** "one additional conductive relay" is implemented as one extra chain jump (Thunder Conduit) or arc relay (Storm Arc).
9. **Sanctum Fire "eligible charged Fire impacts"** is interpreted as full-charge impacts (Flame Cataclysm, Cinderfall, Inferno Wave).
10. **Glacial Spear's "interaction with eligible formations"** has no defined rule, so none was added.
11. **No "Healing Power" system exists in this project** (spec section 14 references one). Direct heals use weapon power × spell power, as before. HoTs and shields scale with MAS.
12. **The enemy weight classes are not defined in the spec.** Provisional mapping: Wolf and Ash Caster light, Raider medium, Shield Guardian and Ashen Warden heavy (bosses always resist).
13. **"Wolf: charge interruption"** is read as wolves interrupting the Mage's charge by pressure and hits, which already happens through stagger. Wolf attacks are not flagged as interruptible by Lightning Verdict.
14. **The Arcane Mastery "qualifying charge"** is not defined. Implemented as any charge past its minimum release time.
15. **The Shared Bloom split ratio is not given.** Provisional: up to 4 recipients within 8m of the target, 45% of the heal each.

### Provisional values chosen or changed for functional testing (all editable)
Most values live in `data/mage_spells/*.tres`; the BalanceConfig values are named in each entry.
- **Spec timing values (0.25 / 1.2 / 1.8 / 65% / 45%) are used as given.** The Lifeline cooldown went from 9s to 12s per spec. The Sanctum cooldown went from 24s to 25s.
- **Steam:** 3s duration, 2.6m radius, max 2 per Mage (`ww_steam_*`).
- **Arcane Mastery:** 40% / 2s / 15s (`ww_mastery_*`).
- **Formation durability:**
  - Ice: 3 × weapon power per section. Frozen Bastion: 3.5×.
  - Pillar: 8×.
  - Ward: 4× per section. Sanctum stone: 3×.
- **Frozen Bastion:** 5m wide, 4s, 16s cooldown. **Rising Pillar:** 8s, 12s cooldown. **Stone Ward:** 3.5m, 6s, 14s cooldown.
- **Chill:**
  - Crystal partial: 1.5s at about 73% speed, 2m. Crystal full: 2.5s at 55% speed, 3.5m.
  - Bosses are never slowed below 85%.
- **Fragments:**
  - Thermal Fracture: 0.5 power, 2.2m.
  - Shattered Winter: 0.7 power (full) or 0.45 (partial), 6m cone of ±35°.
- **Living Bastion:** 6s, 3m, 0.12 power per second. **Sanctum Life share:** 35%.




---

# ARCHIVE — historical notes (OBSOLETE controls and systems; kept for reference only)

### [archive] Update 5: what changed

### Start flow and saving
- **Title screen:** Continue / New Character / Character Selection / Settings / Exit.
- **New Character:** choose a class on the left. The centre shows a live, rotating 3D model (the same model used in game, drag to turn it). The right side shows the role, description, core, strengths, difficulty and progression path. Then enter a name and press **Create → Level 1**. Replacing an existing character of that class asks for confirmation first.
- **Character Selection:** each class is an **independent saved character**, with Play, Training and Reset (Reset asks for confirmation).
- **Save file:** `user://living_world_save.json`. It is written atomically through a temporary file and holds every class plus the settings.
- **Autosave:** on level up, augment choice, equip, stat allocation, permadeath, Return to Title and quit (including closing the window).
- **Debug isolation:** any debug change that affects the character "taints" the session. This covers level/EXP, unlocks, stat bonuses, augments, items, elements, invincibility and kill‑all.
  - A tainted session **refuses to save**, and the HUD shows *DEBUG SESSION · progress is not saved*.
  - Return to Title then **reloads the characters from disk**, so debug testing cannot corrupt a normal character.
  - Settings are saved on their own.

### Progression (Level 1 starts small)
Every class has a track in `data/progression/<class>.tres` (generated by `tools/generate_data.gd`).

| Lv | Vanguard | Mage | Reaver |
|---|---|---|---|
| 1 | Aegis Guard, Aegis Counter | Spells (Fire / Life), Ley Sigil | Sword Sense (Openings) |
| 2 | Attributes | Attributes | Attributes |
| 3 | Shield Rush | Lifeline | Draw Cut (charged heavy) |
| 4 | Augment draft | Augment draft | Augment draft |
| 5 | Resolve (core resource) | Resonance | Perfect Dodge |
| 6 | Interception | Attributes | Attributes |
| 7 | Judgment Strike | Ward | Piercing Lunge |
| 8 | Advanced draft | Advanced draft | Advanced draft |
| 9 | Iron Sweep | Twin Sigils | Tempest Flurry |
| 10 | Bulwark Mastery + Exotic draft | Archmage + Exotic draft | Edge Master + Exotic draft |

- There are three drafts in total: L4 (any rarity), L8 (Advanced/Exotic weighted) and L10 (Exotic weighted).
- Locked abilities show a lock and their unlock level on the skill bar. Pressing one shows *"Name — unlocks at Level N"*.
- A **New Ability popup** shows the icon, name, description and input on unlock.
- AI companions mirror the player's level with auto‑allocated stats and starter gear. They never write to the save.

### Mage — new core: **Ley Sigils** (original; this is not a renamed Arcane Weave)
- **Healing never requires attacking:** F = Mend (tap) / Renewal (hold) heals directly.
- **E inscribes a Sigil of the element you last cast:**
  - Life is placed under the most wounded ally.
  - Fire, Frost and Storm are placed under the locked or aimed enemy.
  - Stone is placed on the Mage.
- **Each element pulses differently:**
  - Life heals allies inside.
  - Fire burns.
  - Frost chills (slow).
  - Storm strikes one enemy with lightning.
  - Stone hardens allies (damage and poise taken reduced).
- **Pressing E at the Sigil limit consumes the oldest Sigil** in an element burst:
  - Life: group heal (+ Ward shields from L7).
  - Fire: eruption + burn.
  - Frost: 2 s freeze.
  - Storm: a bolt on every enemy inside.
  - Stone: knock‑back upheaval + Stoneskin.
- **L5 Resonance:** your spells hitting an enemy inside a Sigil trigger its element:
  - Fire: flare.
  - Frost: freeze.
  - Storm: extra arc.
  - Stone: poise.
  - Life: 25% of the damage heals allies inside.
- **Other milestones:**
  - L3 Lifeline (Mend on an ally under 35% heals ×1.8 and halves their damage taken for 2 s).
  - L7 Ward (key 3, shield).
  - L9 Twin Sigils (2 active).
  - L10 Archmage (charged spells cast 25% faster, Sigils last ×1.5).
- **New augments:** Resonant Ground (wider Sigils, faster pulses) and Sanctified Ward (stronger Ward + cleanse on a Life consume).
- **Re-evaluated augments:** the existing Mage augments are kept, and core‑specific ones are filtered by `requires_core`.
- **The legacy Arcane Weave is kept.** Switch to it in Debug → Combat → Mage core.

### Reaver — new core: **Sword Sense / Openings** (no stacks, no combo meters, no automatic extra attacks, no clones)
- **Enemies expose a short Opening** (gold glint on the enemy, *OPENING* in the target frame and the core widget):
  - during their **attack recovery**
  - while **staggered**
  - after your **Perfect Dodge** (L5, plus 15 stamina back)
- **The cut you choose is the decision:**
  - **LMB = Tempo Cut** (×1.25, +6 stamina, keeps the Opening).
  - **RMB / Draw Cut = Sunder Cut** (×1.6 / ×1.9, double poise, +50% crit damage, consumes the Opening).
  - **1 Piercing Lunge = Vital Cut** (guaranteed crit, consumes the Opening).
- **Other skills:**
  - L9 Tempest Flurry (key 2) is a six‑hit steerable flurry.
  - L10 Edge Master makes Openings last ×1.4, and Tempo Cuts extend them.
- **New augments:** Predator's Patience, Sundering Verdict and Ghost Step (mutation).
- **Bladecraft is kept as the legacy core** (Debug → Combat → Reaver core: Sense / Bladecraft / None), so the two can be compared side by side.

### Vanguard
Its identity is unchanged (Guard → Perfect Guard → Counter → Resolve → Interception), but its abilities now unlock gradually. A gold **Perfect Guard flash** (ring + sparks + light) was added, and L10 Bulwark Mastery widens the perfect and counter windows.

### Attributes, equipment, inventory
- **Character screen (C):** the 3D model, attributes with +/− *pending* points and **Confirm / Cancel**. A derived‑stats table shows **Current → Preview → Change**. These are computed by `StatPreview` from the **same formulas the game uses** (`StatBlock.for_class` + the hero weapon‑power formula). An automated test checks that the preview equals the real result after allocation.
- **The attributes are still STR / DEX / VIT / FOR / MAS,** with their existing roles. No new stats were added.
- **Inventory (I):**
  - 6 slots: weapon, head, chest, hands, feet, accessory.
  - 25 items, including starter gear.
  - Each item shows bonus lines and an **"If equipped" comparison** (real formulas).
  - Equip / unequip changes real stats. Class‑restricted items are refused.
  - Loot drops from enemies: 7% for normal enemies, 100% for elites and the Warden.
- **Equipment tiers change the model:**
  - Pauldrons, gold emblems and capes on chest tier 2/3.
  - Helm / circlet / headband on head tier 2.
  - Weapon glow and size on weapon tier 2/3.

### UI / UX (charcoal · gold · parchment · burgundy; class accents gold/steel, blue/teal, crimson/amber)
- **HUD:**
  - Class core widgets: Resolve shards / Ley Sigils (next element, active sigils with timers, inscribe/consume prompt) / Sword Sense (opening eye + timer, cut legend).
  - Skill bar with cooldowns and **locked states**.
  - Enemy target frame with **level, elite, staggered, opening and status names**.
  - Boss bar.
  - Quest tracker.
  - Save / debug indicator and an optional FPS counter.
- **The lock‑on system and camera from Update 4 are unchanged** (the camera jitter tests still report 0.000 m distance variation).
- **Esc pause menu:** Resume, Character, Skills, Augments, Inventory, Map, Journal, Settings, Debug Panel, Controls, Return to Title, Quit.
- **Game menu tabs (C / K / I / M / J):**
  - **Skills:** every milestone, shown as learned or locked.
  - **Augments:** owned augments with descriptions, plus an *open pending draft* button.
  - **Map:** a parchment map built from live data: areas and levels, road, gates, encounters (cleared or not), rest points, totems and shrine, boss arena, current objective, player arrow and compass.
  - **Journal:** objectives.
  - **Settings.**
- **Augment draft:** pauses the game and shows three cards with rarity gems. The header shows the draft tier and "Draft N of 3". **Right‑click a card to inspect** its full details (values, interactions, requirements, stacks).

### Art pass (procedural; see limitations)
- **Heroes (`CharModel`):** semi‑anime proportions, toon‑ramp + rim materials (no outlines), anime eyes (white, coloured iris, pupil, highlight), brows, blush and mouth. Arms are a **live 2‑bone IK** to the weapon and shield, legs swing with speed, and capes and hair move.
  - Vanguard: blue/white/gold plate, an original sun‑and‑chevron kite shield, sword.
  - Mage: white/blue robes, long silver hair, crystal staff.
  - Reaver: red messy hair, red/black long coat and scarf, longsword.
- **Enemies were restyled with the same gameplay:**
  - wolf with snout, mane, ears and tail
  - bandit raider with hood, mask and axe
  - ash‑armoured Shield Guardian with tower shield and mace
  - hooded Ash Caster with ember eyes and drifting embers
  - Ashen Warden with ember crown, bone spikes, tattered cape and burning greatsword
- **Environment (`Scenery`):**
  - procedural sky, glow, filmic tone mapping, SSAO (Forward+) and fog that blends from green valley to ashen keep as you go deeper
  - grass and flowers (MultiMesh), a winding flagstone road and ash scars with embers
  - rocky cliffs instead of box walls, forests and pines, distant snowy mountains
  - ruins with broken columns, ruined arches, ivy and glowing ley crystals
  - the keep with crenellated castle walls, towers with roofs and windows, banners, braziers on the arena pillars and ember‑filled air
- **VFX (`VFX`) — each element has its own shape language** rather than being a recoloured copy:
  - Fire: embers + flame shell + heat light.
  - Frost: crystals that jut out of the ground and shatter + mist.
  - Storm: jagged branching bolts + flash.
  - Stone: flying rock chunks + dust ring.
  - Life: rising motes + ring bloom.
- **Combat VFX:** sword arcs shaped by the attack (horizontal, sweep, vertical, thrust, flurry), hit sparks, crit flash, the Perfect Guard flash and the Opening glint.

### Training Grounds
- **Getting there:** Character Selection → Training, the "Training Grounds" sign near the valley start, or Debug → Testing.
- **Dummies:** three of them, which never die. Armour and resist can be changed (F7), and they can perform slow telegraphed swings (F8) to practise guards, dodges and openings.
- **Training panel:** total, hits, per hit, biggest hit, crit rate, DPS, healing, stamina/mana spent, cuts, per‑skill breakdown, augment and core activations, and a **baseline before/after comparison** (F5 reset · F6 save baseline).

### Debug Panel (F1) — sections
- **Character:** class, fresh Level 1 test character, give items.
- **Stats:** reset allocation, debug bonuses.
- **Combat:** invincibility, hitboxes, **core selectors**, **enemy defence multipliers**, time scale, restore, kill all.
- **Progression:** level, EXP, drafts, **unlock all, or toggle each ability** natural/on/off, Mage elements.
- **Augments:** add / remove.
- **Spawning:** enemies, boss, dummies, teleports.
- **AI:** party, freeze enemy AI.
- **Testing:** training stats, baseline, compare.
- **Log.**

### Controls (Update 5)
| Input | Action |
|---|---|
| **Mage** | LMB / RMB element slots (tap / hold) · **F** Life · **E** Ley Sigil (inscribe / consume) · **3** Ward · 1 / 2 cycle slot elements |
| **Reaver** | LMB Tempo Cut · RMB (hold = Draw Cut) Sunder Cut · **1** Piercing Lunge (Vital Cut) · **2** Tempest Flurry · Perfect Dodge = dodge through an attack |
| **Menus** | **C** Character · **K** Skills · **I** Inventory · **M** Map · **J** Journal · Esc pause · F1 debug · F2 log |
| **Training** | F5 reset · F6 baseline · F7 dummy armour · F8 dummy swings |

### What was verified automatically (Godot **4.7.2**, headless, `--fixed-fps 60`)
These are automated mechanical checks only. **They are not a substitute for human playtesting.**

| Suite | Result | Notes |
|---|---|---|
| `tests/update5_runner.tscn` (new) | **63 / 63** (also 63/63 on Godot 4.3) | See the checks listed below. |
| `tests/test_runner.tscn` | **136 / 136** (also on 4.3) | Legacy mechanics, run with the legacy cores and all milestones unlocked. |
| `tests/smoke_runner.tscn` | **30 / 30** | Full UI stack; see the checks listed below. |
| `tests/camera_jitter.tscn` (144 fps) | **5 / 5** | Camera‑to‑hero distance range is still 0.000 m. |

`tests/update5_runner.tscn` checks:
- save/load round trip
- a debug‑tainted session refuses to save, and the saved character stays clean
- Level 1 gating and unlocking at Level 3
- stat preview equals the real stats after allocation
- equip changes stats, the preview matches, other‑class items are refused
- Mage heals with no enemies present, a Life Sigil heals allies inside, Lifeline
- a Fire Sigil burns, Resonance flare, consume eruption, the Frost Sigil chills rather than burns, Twin Sigils
- Reaver recovery Opening, Tempo / Sunder / Vital cuts, no cut without an Opening
- Perfect Dodge creates an Opening
- training dummy stats + baseline

`tests/smoke_runner.tscn` checks:
- all 9 debug sections
- the draft opens at Level 4 and pauses
- every game‑menu tab builds
- a full clear reaches Level 10
- the boss
- the pause menu and Return to Title
- character selection, the creation preview, New Character → Level 1 (other classes untouched)
- Training Grounds

**Screenshots** (`screenshots/`):
- `u5_1080_*` at 1920×1080 and `u5_1440_*` at 2560×1440 (title, creation, HUD with sigils and openings, every menu tab, draft + inspect, unlock popup, training, debug)
- `art_*` at 1600×900 (heroes, close‑ups, enemies, outskirts, ruins, keep)
- They were rendered with the OpenGL Compatibility renderer under a virtual display, **so SSAO, and in some cases glow, do not appear in them**. Forward+ on a real GPU will look somewhat different.

**Performance:** measured with `tests/perf_probe.tscn` in a party fight with 8 enemies, after optimisation:
- about 2.5k visible objects, ~760k primitives and ~1.26k draw calls per frame (shadows included)
- game logic is about 2.5 ms process + 2.6 ms physics per frame (headless)
- small model details cast no shadows, there are 2 shadow splits, and far decoration fades out at 120 m

The sandbox only has a software renderer, so **real GPU frame rates were not measured**. Please check them on your machine (Settings → Show FPS).

### Needs human playtesting (not verifiable here)
- How the new cores *feel*:
  - Sigil placement and mana pacing.
  - Opening window lengths (recovery +0.25 s) and whether Tempo / Sunder / Vital choices read clearly in a real fight.
  - Bladecraft vs. Sword Sense, and Arcane Weave vs. Ley Sigils.
- Damage and heal numbers of Sigils, Ward and the new augments. They are first‑pass values in code and `tools/generate_data.gd`.
- UI readability on your monitor, mouse flows in every menu, and the inventory and map at different resolutions.
- Visual quality on a Forward+ GPU (SSAO, glow, shadows) and the actual frame rate.

### Art limitations (honest)
**The reference concept images are *not* reproduced.** Characters are stylized primitive models with procedural animation: no sculpted meshes, skeletal rigs, hand‑painted textures, cloth simulation or authored animation. Faces, hair and armour are simplified shapes. The direction (palette, silhouettes, class identities, green‑to‑ash world, element shapes) follows the brief, but the Godot scene still looks clearly different from the concept art.

The path to real anime models is the pipeline you mentioned earlier (VRoid / Mixamo → Godot). `CharModel.build()` is the single place to swap in imported scenes. Paid generation services were not used.

### Notes
- When the game is started directly without a created character (`--autostart`), a temporary Level 1 character for that class is created in memory.
- The automated test runners disable saving. The smoke and UI‑shot runners boot `main.tscn`, which *reads* an existing save, so on a machine with real saves some smoke expectations (levels) can differ. Run them on a clean profile.
- The base UI layout is 1600×900, scaled with `canvas_items` / `expand`. It was checked at 1920×1080 and 2560×1440.

---

### [archive] Run it (unchanged since Update 4; the controls table below is the Update 4 one, see Update 5 controls above)

1. Open the folder in **Godot 4.7** (tested on 4.7.2 stable) with Project → Import → `project.godot`.
2. Press **F5**. In the menu, pick a class and Solo or Party Test, then enter Ashen Valley.

The first time you open the project, Godot imports it. All data `.tres` files are already generated.

### [archive] Controls

| Input | Action |
|---|---|
| WASD / Mouse | Move / camera |
| LMB / RMB | Light / Heavy (**hold RMB = charged attack**) |
| Space | Dodge (has i-frames) |
| Tab / MMB | Lock-on toggle |
| Wheel Up / X · Wheel Down / Z | Switch lock target right / left on screen (only while locked; actions `lock_switch_right` / `lock_switch_left` in the InputMap) |
| **Vanguard** | Shift = Guard (raise it just before impact for a **Perfect Guard**). 1 = Shield Rush, 2 = Judgment Strike (hold to charge), 3 = Iron Sweep. LMB during the counter window = Aegis Counter |
| **Mage** | LMB / RMB = element slot 1 / 2 (tap = quick, hold = charged). F = Life. E = Arcane Weave. 1 / 2 = cycle the element in each slot |
| **Reaver** | 1 / 2 / 3 = arm Bladecraft **Split / Focus / Precision** for the next eligible attack |
| G / R | Interact (Trial Totems, Elemental Shrine) / hold to revive an ally |
| C / F1 / F2 / Esc | Character sheet (spend stat points) / Debug Panel / combat log (compact / expanded / hidden) / **pause menu** |
| F11 | Toggle fullscreen |

**Display:** the game opens maximized, the window can be resized, and it uses `canvas_items` stretch with `expand` aspect. The UI is laid out for 1600×900 and scales to any window, so nothing is cut off on 720p, 1080p, 1440p or ultrawide screens. You can change this in Project Settings → Display → Window. The UI is forced **left-to-right with English number formatting**, so a Windows system set to Arabic (or any RTL language) no longer mirrors the HUD off the right edge.

Input actions are registered at startup in `scripts/core/game.gd → _setup_inputs()`. An action you define in Project Settings with the same name takes priority.

---

### [archive] Project structure

```
project.godot
scenes/        main.tscn, world/ashen_valley.tscn, heroes/{vanguard,mage,reaver}.tscn (Hero + Kit child),
               enemies/{wolf,raider,shield_guardian,ash_caster,ashen_warden}.tscn
scripts/
  core/        events.gd (signal bus), game.gd (state/progression/spawning/death), combat_log.gd
  data/        AttackData, AugmentData, SkillData, SpellData, FusionData, BalanceConfig (Resource classes)
  combat/      Combatant (CharacterBody3D base), AttackRunner (startup/active/recovery/cancel windows),
               Hitbox (Area3D), StatBlock, DamageInfo, StatusEffect/StatusComponent (buff/debuff/DoT/HoT),
               ProcAnim (AnimationPlayer clips generated from attack timings), Projectile, GroundZone,
               Barrier, Telegraph, FX
  heroes/      Hero, ClassKit, VanguardKit, MageKit, ReaverKit, PlayerBrain, AIBrain, CameraRig
  enemies/     Enemy (threat, NavigationAgent3D, attack selection), EnemyStateMachine + states/*,
               Wolf, Raider, ShieldGuardian, AshCaster, AshenWarden
  progression/ ClassProgress (per-class life), AugmentDB (eligibility + rarity-weighted drafts)
  world/       AshenValley (procedural level, navmesh bake, gates, checkpoints, boss), EncounterZone
  ui/          HUD, DraftUI, DebugPanel, CharSheet, main.gd (menu)
data/          attacks/*.tres (39), augments/*.tres (18), skills/*.tres (3), spells/*.tres (10),
               fusions/*.tres (7), balance/balance.tres
tools/generate_data.gd   regenerates all .tres defaults (overwrites your edits!)
tests/                   automated test suites + screenshot capture
screenshots/             reference renders captured from the running game
```

**Editing balance:** open any `.tres` in the Inspector. Attack timings, damage, poise, hitboxes, cancel windows, lunges and AI ranges live in `data/attacks`. Global numbers (stat scaling, guard values, EXP curve, rarity weights, enemy EXP, area power) live in `data/balance/balance.tres`. Augment tuning is in each augment's `params`.

---

### [archive] How the spec maps to the build

### Foundation
* `AttackRunner` drives every attack through **startup → active → recovery**, using the attack's `cancel_after`, `dodge_cancel`, `poise_armor`, `lunge` and `move_during` values. Light attacks can be dodge-cancelled during startup. Heavy attacks are committed.
* Each **multi-hit** attack splits its active window into hit sub-windows. A target can be hit once per sub-window.
* **Hitstop** is per character: both the attacker and the target freeze. Each hit also adds knockback, a flash, a damage number, and camera shake for the player.
* **Telegraphs** are ground decals that build up during enemy startup. Red marks a normal attack, orange plus "!! UNBLOCKABLE" marks a guard break, and circles mark delayed AoEs.
* Damage can be Physical or Magic, reduced by Armor or MR. Crits come from Critical Chance and Critical Damage. Attack Speed scales the runner and animation speed.
* Stats follow the spec exactly (see `stat_block.gd`). **DEX multiplies the TOTAL of a multi-hit attack once, and the total is then divided among the hits.** A test checks this.

### Vanguard — Aegis Guard + Resolve
* **Guard** blocks hits from the front at a stamina cost. Raising it within 0.2s of impact gives a **Perfect Guard**: 95% damage reduction, 25% of the stamina cost, +20 Resolve, poise damage to the attacker, and a counter window (Aegis Counter or Judgment Riposte). To stop mashing, a perfect guard needs a fresh press after a 0.35s rearm.
* Guard-break attacks crush a normal guard, but a Perfect Guard still parries them. Running out of stamina also breaks the guard.
* **Resolve** comes from guarding, perfect guarding, interception and counters. It is spent on the Empowered Rush, the Verdict charge and the Resolve Sweep.
* **Threat:** the class has a ×2 threat multiplier, gives off a threat aura within 7m, and adds threat while guarding. Shield Rush has ×4 threat. The Resolve Sweep taunts.

**Skills** (each has two variations):
* **Shield Rush:** with an ally in danger, it becomes an *Interception* that moves the ally's next hits onto the Vanguard. With 30 Resolve it becomes the *Empowered Rush*.
* **Judgment Strike:** hold to charge. Right after a Perfect Guard it becomes the *Riposte*. At full charge with 40 Resolve it becomes the *Verdict*.
* **Iron Sweep:** a 3-hit spin. Used while holding Guard it becomes the *Guarded Sweep*. With 25 Resolve it gains a hit and taunts.

### Mage — Arcane Weave
* Fire and Life are known from the start. **Life is always on F.**
* Each element has a quick spell and a charged spell, and charging changes how the spell works:
  * Firebolt vs. the exploding Fireball
  * Mend (direct heal on the lowest ally) vs. Renewal Wave (slow channel, group heal + HoT)
  * Ice Shard (chill) vs. Frost Nova (freeze ring)
  * Spark (chain) vs. Thunder Strike (delayed strike)
  * Stone Shard vs. Earthen Ward
* Every spell stores an Echo, and the last two are kept. **E fuses them:** Phoenix Bloom, Sanctuary, Thermal Fracture, Winter's Embrace, Plasma Surge, Vital Current. Pairs not in the spec produce *Arcane Discord*.
* **How Mage progression differs:** the Mage has no skill slots. Progression comes from discoveries (Frost and Storm augments, plus Stone at the Elemental Shrine in the Ruins), from **disciplines** (each element ranks up with use, +10% power per rank, up to 3), and from spell enhancement and mutation augments.

### Reaver — Bladecraft (EXPERIMENTAL)
* The Reaver has a 4-hit light chain, a heavy, a combo heavy (heavy after lights), a charged Draw Cut and a dodge-attack. Its defence is dodging, with cheaper dodges and longer i-frames.
* **Split** rebuilds the attack into a 2–5 hit flurry, with a wider hitbox and a longer active window, scaled by DEX.
* **Focus** turns it into a single slam with longer startup, ×1.55 damage and ×2.2 poise, scaled by STR (Heavy). It only works on finishers, heavies and charged attacks.
* **Precision** turns it into a narrow 3m thrust with faster startup. It gets bonus crit chance against staggered or attacking targets and from behind.
* **Critical test:** turn off *Bladecraft* in the Debug Panel or the menu. Forms can no longer be armed, Bladecraft-only augments drop out of drafts, and normal combos are unchanged.
* **Build directions:** augments are tagged Tempest, Finality or Precision. These tags are not locks, so a build can mix them.

### Augments (18 in the prototype, all functional, all testable alone with Debug Panel → Add / Remove)
| Class | Augment | Type / Rarity | Effect hook |
|---|---|---|---|
| Vanguard | Iron Reprisal | Conditional / Advanced | Perfect Guard → next Heavy +60% dmg, +50% poise, wider |
| | Last Line | Conditional / Standard | Interception → −35% dmg, −60% poise taken (MAS-scaled), 6s ICD |
| | Steadfast | Passive / Standard, stacks ×2 (additive) | −25% guard stamina per stack |
| | Crushing Rhythm | Synergy / Advanced (**explicit multiplicative**) | all hits of a multi-hit land → next attack ×1.75 poise |
| | Unyielding Charge | Enhancement / Standard | while charging / rushing: −50% frontal dmg, no frontal poise loss |
| | Phantom Bulwark | Mutation / Exotic | Shield Rush leaves a **real barrier** with HP: absorbs hits from outside, blocks projectiles |
| Mage | Frost Discovery / Storm Discovery | Enhancement / Standard | unlock the element + its weaves; only offered while undiscovered |
| | Living Flame | Mutation / Advanced | fire spells leave burning ground |
| | Spell Echo | Synergy / Advanced | quick cast of a different element within 1.5s re-casts the previous spell at 40% (non-recursive) |
| | Gentle Restoration | Passive / Standard | 50% overheal → 4s HoT (never re-converts) |
| | Living Current | Synergy / Exotic, requires Storm | storm dmg heals lowest ally; Vital Current +2 jumps, heal ×1.5 |
| Reaver | Splintering Steel | Mutation / Advanced | heavy / charged → 3 hits (+2 with Split) |
| | One Perfect Cut | Synergy / Advanced | 3+ hit attacks put 45% of the damage into a final Heavy hit (+50% crit dmg) |
| | Flowing Edge | Enhancement / Standard | move and steer at 55% speed during 3+ hit attacks |
| | Execution Line | Mutation / Advanced, requires Bladecraft | Precision → ×1.8 length, ×0.55 width, piercing, +30% crit dmg |
| | Rising Crescent | Mutation / Exotic | uncharged heavy → launching rising strike + crit follow-up window |
| | Unbroken Form | Synergy / Advanced, requires Bladecraft | arming a different form mid-attack cancels recovery for 15 stamina |

**Draft rules:**
* Every 2 levels you get 3 cards, weighted by rarity (60/30/10), drawn only from the class's **eligible** pool.
* Cards are hidden if their required skill or element is missing, if they need Bladecraft and it's disabled, or if you already own them and they don't stack.
* Echo copies and HoTs are flagged so they can't trigger more effects, which prevents recursion.

### Leveling, stage, enemies, boss
* Each class has its own progress: level 1–10, 2 free stat points per level (spend them on the character sheet, C), and drafts at levels 2, 4, 6, 8 and 10. EXP comes from kills, elites (×3), pack objectives, area objectives and the boss.
* **Ashen Valley** has three areas, from the Outskirts through the Ruins to the Keep. Ash gates open when an area is cleared. Each area has a checkpoint. Each area also has a repeatable Trial Totem, so you can grind or test without restarting. The Keep holds the boss arena.
* EXP budget for a full clear: **Outskirts 450 → Lv4, Ruins ~1020 → Lv8, Keep 840 → Lv9, boss → Lv10** (curve total 2490).
* **Enemies** use a node-based FSM: idle, chase, attack, reposition, stagger, dead. They pick attacks by range, weight and cooldown, and target by threat table. They move with NavigationAgent3D and react to poise breaks with stagger.
  * **Wolf:** lunges and bites, circles while its attacks recover.
  * **Raider:** a 3-hit chained combo and a slow overhead.
  * **Shield Guardian:** frontal block (light hits deal 25%), turns slowly so you can flank it, and has an orange Guard Breaker.
  * **Ash Caster:** fires projectiles, casts delayed AoEs and backs away to keep distance.
* **The Ashen Warden:**
  * Phase 1: sword combo, a 270° sweep and a guard crusher.
  * Phase 2 (at 60% HP): telegraphed burning ground under each hero, a 4-hit flame combo, and an Ember Lance aimed at the most distant hero.
  * Phase 3 (at 25% HP): ×1.3 attack speed, ×0.6 cooldowns, shorter pauses between attacks, and an Execution Strike on the lowest-HP hero.
  * Each phase change opens with a knockback roar.

### Party Test, death
* **Vanguard AI** reads telegraphs and guards. Its timing varies, so some guards are perfect. It counters, intercepts for endangered allies, and draws threat.
* **Mage AI** triages heals (single target or group), keeps distance, dodges, and attacks and weaves when it is safe.
* **Reaver AI** reads telegraphs and dodges sideways, chains combos, and arms Bladecraft forms.
* **Downed:** you have 15s to be revived (hold R near the ally for 2.5s). After that, **True Death**. With Permadeath on, True Death resets only the active class's life (a `ClassProgress` reset). The other classes are untouched.
* Companions that die respawn after 20s. Permadeath can be switched off.

---

### [archive] Testing — what was actually run

All tests were run with **Godot 4.7.2** (and originally 4.3) on Linux:

```
godot --headless --fixed-fps 60 res://tests/test_runner.tscn    # 117 gameplay assertions — 117 PASS
godot --headless --fixed-fps 60 res://tests/smoke_runner.tscn   # 20 end-to-end checks     — 20 PASS
xvfb-run godot --rendering-driver opengl3 res://tests/screenshot_runner.tscn   # renders /screenshots
```

* The **test suite** spawns real sessions and drives heroes through the same `press()` / `release()` API that player input uses. It covers:
  * hitbox hits, cancel windows, and dodge i-frames against a real enemy attack
  * normal / perfect / broken guard, the counter, Resolve, all three Vanguard skills and their variations, interception, and all 6 Vanguard augments (including the barrier absorbing hits and blocking projectiles)
  * Mage quick and charged spells, Echoes, all 6 listed fusions, both discoveries, and all 4 other Mage augments
  * Split / Focus / Precision rebuilding attacks, Bladecraft on/off, and all 6 Reaver augments plus their interactions
  * the stat identities
  * drafts: eligibility, no duplicates, rarity weighting, 5 selections by level 10
  * True Death isolation, Downed → Revive, Party AI healing and threat
  * the FSM, telegraphs and attacks of every enemy, Shield Guardian blocking and flanking
  * boss phases
  * the stage EXP budget
* The **smoke test** goes through the real menu, then the session with HUD, Draft UI (pause, then resume), Debug Panel and character sheet. It clears every encounter in all three areas, checks that the gates open, triggers the boss and records the kill, and checks class switching.
* **Screenshots** were rendered with software OpenGL to confirm that the HUD, telegraphs, AI companions, boss arena, draft UI and debug panel render correctly.

**Not tested by a human:** no one has played it with mouse and keyboard yet. That means **game feel** (input responsiveness, hit weight, camera comfort) and the **20–30 minute pacing** target are not verified. Pacing has only been checked as an EXP budget. Tuning those is the next step.

### [archive] Changelog — Update 4 (camera + lock-on)

### Jitter: root cause and fix
* **Cause.** Characters move in `_physics_process` at 60 Hz, but the camera followed them in `_process` at the monitor's rate with exponential smoothing. On a display above 60 Hz the body moved in 60 Hz steps while the camera glided between them, so the hero shook on screen. Measured on the old build at 144 fps: the camera-to-hero distance oscillated by up to **7.8 cm** while walking in a straight line.
* **Fix.**
  * **Physics interpolation** is enabled in the project, so in Godot 4.4+ every character is rendered at its interpolated transform.
  * The camera follows the hero's **interpolated root transform** every frame. On engines without 3D interpolation (4.3) it updates in `_physics_process` instead, so it shares the character's update rate.
  * **AnimationPlayers run on the physics tick** (`callback_mode_process = PHYSICS`), the same tick as movement.
  * Nodes that are moved by tweens or teleports are excluded from interpolation, or reset with `reset_physics_interpolation()` when they move.
  * No extra lag smoothing was added on top of interpolation.
* **Result.** At 144 fps the camera now advances by exactly the same amount every frame, and the camera-to-hero distance stays constant while walking (**0.000 cm**). During attacks and dodges the camera follows the root, never the animated model.
* **Collision.** The SpringArm3D was replaced by a manual sphere cast. The camera pulls in quickly but continuously (no pop when a pillar passes between camera and hero) and eases back out at 4 m/s. The impact shake is now a smooth sine instead of per-frame random noise.
* **One camera authority.** `CameraRig` is the only code that writes camera yaw and pitch. The hero's facing is computed separately in `Hero`.

### Lock-on (`scripts/heroes/lock_on.gd` + `CameraRig`)
* **Acquire (Tab):** picks the visible enemy closest to the **screen centre**, within 24m and with line of sight (raycasts from the camera and the hero's head; walls block it).
* **Switch (Wheel / Z / X):**
  * Works only while locked, and picks the nearest eligible enemy **in that screen direction**.
  * If there is none in that direction, the current target stays and the indicator shakes.
  * Has a 0.25s cooldown (`switch_cooldown`, adjustable in the Inspector), and a single wheel burst never skips targets.
  * The wheel actions are separate from all weapon actions.
* **Automatic changes only when necessary:** when the target dies, leaves keep range (32m), or stays hidden behind walls for more than 1.5s, the lock moves to the best visible target, or releases if there is none.
* **Lock camera:**
  * Eases into lock over 0.35s and turns toward the target with frame-rate-independent exponential gain, capped at 4.2 rad/s.
  * The mouse keeps a manual offset (±0.55 rad) that drifts back to centre.
  * The pivot shifts toward the target so both stay in frame. Distance changes slowly (no zoom pumping), and the pitch is clamped so large enemies don't drag the view upward.
  * When an enemy crosses behind or over the hero, the last stable heading is held.
  * Right after a target switch, the camera turns more gently.
  * **Unlocking keeps the current view direction.**
* **Movement while locked:**
  * Full move speed; the hero faces the target and strafes or circles naturally.
  * Dodge rolls in the input direction, then turns back to face the target.
  * Attacks turn the hero quickly toward the target during startup instead of snapping.
* **Visuals:**
  * Corner brackets sized to the enemy, plus a bobbing chevron.
  * A pulsing ground ring under the target.
  * The locked enemy gets a larger bar with its name, and other enemies' bars are dimmed.
  * The indicator glides to the new target on a switch, with a pulse; when no target is available it shakes.
  * A **target frame** at the top of the screen shows name, HP, poise and ELITE / STAGGERED, and updates immediately on a switch.

### Tests for this update
* **Gameplay suite (135 checks)** adds:
  * Tab picks the centre enemy; Wheel Up / Down move right and left; one burst equals one switch.
  * No target in a direction keeps the current one; Z works as a keyboard switch.
  * Enemies behind walls are excluded; switching never triggers attacks.
  * Target death and leaving range retarget the lock; the wheel does nothing while unlocked.
  * Camera entry and switch respect the turn cap (no snap); character turning is bounded.
  * Circling keeps full speed with a smooth camera; unlocking preserves direction.
  * Dodging works in four directions while locked.
* **`tests/camera_jitter.tscn`**, run with `--fixed-fps 144`, checks: per-frame camera step uniformity while walking, rapid direction changes, attack and dodge, and sliding along a wall.
* **Results:** all pass on Godot 4.7.2. See the Godot 4.3 note below.

### [archive] Changelog — Update 3 (combat refinement + UI redesign)

### Enemy pacing and readability (player speed unchanged)
* **Longer startups and recoveries** on every enemy attack. Examples: Raider overhead 0.95 → 1.25s startup with 1.4s recovery; Wolf lunge 0.55 → 0.8s; Shield Guardian slam 0.9 → 1.25s; Warden sweep 0.85 → 1.15s and Execution 1.5 → 1.9s. Cooldowns and pauses between attacks are longer too.
* **Ash Caster:**
  * Casts at 90% speed.
  * The Ash Bolt windup is 1.05s, followed by a 10 m/s projectile, so a bolt from 10m reaches you after about 2s.
  * Ash Burst casts for 1.3s, then the marked circle detonates 0.9s later.
  * It casts at most once every 3.5–8s, which works out to about 4 casts in 15s.
  * While casting it shows a glowing orb that grows on its staff and a rune circle on the ground.
* **Telegraphs** now stack several readable cues before every damage window:
  * The wind-up pose is reached at 55% of startup and then held, leaning further in (MonHun-style anticipation).
  * The enemy's body glows brighter as the hit approaches: red for physical, purple for magic, orange for guard-break.
  * A "!" icon pops above its head ("!!" for unblockable attacks).
  * The ground decal stays on screen.
* **Tempo AI:**
  * When an attack becomes available, the enemy hesitates and strafes before committing (engage delay).
  * **Attack tokens:** at most 2 enemies can attack the same hero at once.
  * Enemies walk when close instead of sprinting.
  * Combo chains continue only 75–85% of the time.
  * Each enemy pauses after its attacks finish.
  * Boss phase 3 is still faster, but less extreme (×1.15 speed, ×0.75 cooldowns).

### Distance-aware melee approach (`scripts/combat/melee_approach.gd`)
* **Reusable and opt-in per attack.** Each attack sets `approach_max`, `approach_range` and `approach_window` in its AttackData.
* **Currently tuned for Vanguard only** (Light 1.2m, Light 2 0.8m, Heavy 1.8m, Judgment 1.5m). Reaver attacks have it switched off.
* **How it decides:**
  * Target already in range → no movement.
  * Slightly out of range → a short step during startup that stops at sword range.
  * Far out of range (more than 1.5× the max step) → no movement, so it never dashes or teleports.
  * It uses the lock-on target, or otherwise the nearest enemy inside a 45° cone of the attack direction.
* **Movement rules:** it moves through `move_and_slide`, so walls and enemy bodies stop it, and it never overshoots the stop range. It only happens during startup, so the attack's commitment, stamina cost and animation timing are preserved.

### UI redesign (fantasy ARPG style, all native Control nodes + a code-built Theme)
* **Fonts:** free OFL fonts in `assets/fonts` (Cinzel for titles, Alegreya Sans for text).
* **HUD:** the level emblem has an EXP ring and a stat-point badge. HP and Stamina bars animate, with a damage "chip" trail, plus a Mana bar for the Mage. Buff and debuff icons show their timers. The ability bar has vector icons, keycaps, cooldown sweeps and a flash when a skill becomes ready. A thin EXP bar runs along the bottom of the screen. Party frames are on the left, and the compact combat log cycles with F2 (compact / expanded / hidden).
* **Class widgets:**
  * **Vanguard:** a five-shard Resolve gauge, plus Guard, COUNTER, Reprisal and Crushing states.
  * **Mage:** Echo orbs, an arrow pointing to the fusion name, and the Weave state.
  * **Reaver:** Split / Focus / Precision diamonds with an armed timer ring, combo pips, and a DISABLED state.
* **Combat UI:**
  * Screen-space enemy HP bars with a chip trail, a poise strip, a gold frame for elites, and a STAGGERED tag.
  * An ornate boss frame showing phase and poise.
  * A rotating lock-on reticle and downed-ally markers showing revive progress.
  * A ring flash with "PERFECT GUARD" / "GUARD BROKEN".
  * Styled damage numbers that pop (crits enlarged; heals in green; numbers not involving the player are dimmed).
* **Menus:**
  * Title screen with drifting embers, and a class selection screen with animated class cards.
  * **Esc pause menu:** Resume / Character / Debug / Controls / Return to Main Menu / Quit.
  * Augment cards framed by rarity (gems, category medallion, hover lift, click anywhere on the card).
  * Tabbed Debug Panel: Session / Progress / World / Stats / Augments / Log.
  * Redesigned character sheet.
* **Layout:** resolution-independent through anchors with `canvas_items` stretch, forced left-to-right.

### Tests for this update
* The gameplay suite now has **117 checks**. New ones cover:
  * the approach step in each case: in range, slightly out, far away, and Heavy;
  * follow-up attacks staying in place;
  * a wall stopping the step;
  * Reaver having no approach;
  * telegraph → glow → "!" → damage only after startup, for Raider / Wolf / Guardian;
  * Ash Caster cast and travel time, and its cast rate.
* The smoke test now has **20 checks**, including the pause menu, Return to Main Menu followed by a new session, and real LMB press/release reaching the hero with the full UI loaded.
* **Results:** all pass on **Godot 4.7.2** and on **Godot 4.3**. On 4.3, the project opens with a version notice because `config/features` says 4.7.

### [archive] Not implemented / known limitations

* **Godot 4.3:** 3D physics interpolation only exists in 4.4+. On 4.3 the camera updates on the physics tick, so the character and camera never jitter relative to each other, but on displays above 60 Hz the whole view moves at 60 Hz. Use 4.4+ (the project targets 4.7) for full smoothness.
* **Camera and lock-on still need hands-on testing:** mouse feel, sensitivity, whether the lock camera is too loose or too tight, and boss framing. The tuning values are exported on `CameraRig` and `LockOnSystem` so they can be adjusted in the Inspector.

* **Vanguard skill pool:** only the 3 representative skills exist, and they are always equipped. The 15-skill pool and the skill draft are not built (`SkillData` already supports rarity and a shared flag).
* **Animation:** the rig is procedural primitives driven by **AnimationPlayer**. Clips are generated from attack timings, so they always match the hit windows. There is no AnimationTree, skeletal mesh or Mixamo/VRoid import yet.
* **Companion movement:** AI heroes steer directly toward targets without a NavigationAgent, so they can snag on walls. Enemies do use the navmesh.
* **Lock-on** toggles the best target but has no target cycling. No gamepad support. No save/load: progression lasts for the session.
* **Stone** has spells and is discoverable at the shrine, but it has no specified fusion, so Stone pairs produce Arcane Discord.
* `tools/generate_data.gd` **overwrites** the `.tres` files. Only rerun it if you want the defaults back.
