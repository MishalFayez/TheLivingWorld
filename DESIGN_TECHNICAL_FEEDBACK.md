# DESIGN & TECHNICAL FEEDBACK — after the Design Resolution

Reviewer: implementation engineer (Godot 4.7.2). Date: 2026-11-20.
Basis: the project **after** implementing `REFOUNDATION DESIGN RESOLUTION`. Backup of the state before this pass: `AshenValley_BACKUP_before_DesignResolution.zip`.

Tags: **A** = technical correction (no design change), **B** = balance number inside the approved design, **C** = design change that needs approval (**not implemented**).
Everything below comes from code, automated tests and measurements. **None of it replaces human playtesting.** Automated tests show that mechanics behave as specified, not that they are fun.

---

## Summary

| # | Question | Short answer | New concerns |
|---|---|---|---|
| 1 | Is Reaver's directional input predictable? | Yes, mechanically: LMB is always Forward Cut; only Shift + A/D + LMB gives a Lateral Cut; the side is locked at the press. Comfort of the 3-key chord is unverified. | A-1, C-1, C-2 |
| 2 | Do deliberate paths beat repetitive LMB? | Yes: +32% DPS and +29% damage per stamina vs Forward→Forward spam, with no damage multiplier. Spam is still 76% as strong. | B-1, B-2 |
| 3 | Are Flowblade / Breaker / Duelist different? | In the showcase scenarios, yes (different tools, triggers and targets). At natural Lv10 they differ only by augments, because their defining skills are Lv12–18. | C-3 |
| 4 | Does Vanguard have options outside Perfect Guard? | Yes: Guarded Strike (Lv1), Interception, three Resolve spenders, Shield Plant (showcase). | C-4, B-3 |
| 5 | Does Resolve have competing spends? | Yes: 30 / 40 / 25 for three different jobs. Guardian's Reserve spends automatically and can compete invisibly. | C-5, B-4 |
| 6 | Remaining camera problems? | Yes, one reproducible case: a 0.57m anti-clipping snap near a tall cylindrical pillar (1 in 18 sweeps). 0 frames end inside geometry. **The camera is not "completely fixed".** | A-2, C-6 |
| 7 | New animation / responsiveness problems? | Several, mostly because all poses are procedural and there is no audio. | A-3, A-4, B-5, C-7 |

---

## 1. Reaver directional input

**Implemented:**
- New input action `blade_modifier` on **Shift**.
- **Shift conflict check:**
  - Shift is already `guard`, but only the Vanguard uses that action. The Reaver has no Guard, so there is **no functional conflict**.
  - No existing binding was changed.
  - `blade_modifier` is a separate action, so it can be rebound on its own later (keyboard or controller).
- Direction is read once, when the input is accepted (or when it is buffered). It is never re-read mid-animation. This is tested with a buffered press after the keys are released.
- Strafing with A/D **without** Shift + LMB gives Forward Cut 4/4 times, with lock-on and with free camera. A/D is camera-relative movement as before.

**Concerns:**
- **A-1 (technical, not done):** there is no gamepad binding for `blade_modifier` yet, because the project has no controller layout at all. The action is controller-ready, but a binding must be added when controller support is scheduled.
- **C-1 (approval needed):** Shift + A/D + LMB means three simultaneous inputs while you also move the mouse. Mechanically it is unambiguous. Whether it is comfortable during long fights needs **human testing** (guided RA). If it is not, alternatives (for example holding the modifier to "stance" instead of chording) are design changes.
- **C-2 (interpretation to confirm):** Turning Edge with no A/D held is **refused** ("direction must be intentional"). The alternative would be to default to one side, which I did not choose because the resolution forbids automatic behaviour. Please confirm.

## 2. Deliberate paths vs repetitive LMB

Measured with `tests/compare_runner.tscn`: Reaver Lv10, the same frozen Raider, 6 seconds per run.

| Metric | OLD Sword Sense, LMB/0.25s | NEW F→F, LMB/0.25s | NEW mash, LMB/0.10s | NEW deliberate paths (buffered) | NEW deliberate, pressed in link window |
|---|---|---|---|---|---|
| attack inputs | 24 | 24 | 60 | 24 | 64 |
| executed attacks | 14 | 13 | 14 | 11 | 13 |
| hits | 11 | 13 | 14 | 11 | 10 |
| inputs buffered | 17 | 17 | 47 | 17 | 0 |
| avg startup (s) | 0.125 | 0.140 | 0.140 | 0.162 | 0.134 |
| avg recovery (s) | 0.279 | 0.280 | 0.280 | 0.335 | 0.303 |
| legal links | 0 | 0 | 0 | 10 | 12 |
| total damage | 305 | 402 | 433 | 530 | 430 |
| **DPS** | 50.8 | 67.1 | 72.2 | **88.3** | 71.6 |
| **damage / stamina** | 2.63 | 3.80 | 4.17 | **4.89** | 4.23 |
| stamina used | 116 | 106 | 104 | 109 | 102 |
| time committed (s) | 5.53 | 5.38 | 5.08 | 5.35 | 5.15 |
| displacement (m) | 0.80 | 1.74 | 1.74 | 1.63 | 2.39 |

**What explains the earlier 402 vs 254 gap:** the new Forward Cut always hits (100% hit rate, ×1.0 damage). The old 4-hit chain had a weak opener and a lower hit rate.

**What changed (without slowing every attack):**
- Forward→Forward is allowed but no longer counts as a link: no faster startup, no tracking, no `linked` flag.
- Only line changes (F→L, L→F, L→Heavy, Dodge→Slip, …) get the 0.75× startup.
- There is no damage multiplier. Deliberate paths win through **more useful attacks**: wider lateral arcs, heavy poise, faster linked starts.
- Mashing at 0.10s gains only +7% over a steady 0.25s rhythm, because the buffer stores one action.

**Concerns:**
- **B-1:** spam keeps 76% of deliberate DPS. That may be fine (spam is the floor, not a trap). Raising the gap is a tuning choice, for example a smaller F→F recovery saving or a larger link startup bonus.
- **B-2:** "pressed in the link window" scored lower than buffered paths (71.6 vs 88.3) because the lateral side steps (0.6m each) walked the hero partly out of reach: 2.39m of displacement, 10 hits out of 13. The lateral step size versus Forward Cut reach is a tuning value, and players who time links perfectly should not be penalised. **Human feel check:** RB.

## 3. Flowblade / Breaker / Duelist

| Build | Tools in its showcase | Trigger for Final Stroke | Plays against |
|---|---|---|---|
| Flowblade | Crosswind reversals, Flow Step inside links, Crosscut, Unbroken Line | Two different linked hits | Groups, sustained pressure |
| Breaker | Draw Cut, Sunder Edge (poise 55; guard ×0.75 dmg / ×1.5 poise) | Sunder Edge poise break | Guarding enemies (Shield Guardian) |
| Duelist | Lunge + Measured Step, Turning Edge, Slip Cut | Flank hit ≥60° | Single targets, spacing |

Automated tests confirm each trigger works only for its own route. Whether they *feel* different is for human testing (RE, RF, RG, R3–R5).

- **C-3:** the defining skills are Lv12 (Sunder Edge), Lv15 (Turning Edge) and Lv18 (Final Stroke). Under the Lv10 cap, naturally levelled builds differ only through augments and Lv1–10 skills. These skills are therefore only reachable through Lab **Build Showcase** presets, labelled "BEYOND LV10 CAP - BUILD SHOWCASE ONLY". Changing this needs a decision on the cap or the levels.

## 4. Vanguard options outside Perfect Guard

- **Guarded Strike (Lv1, Shift + LMB):**
  - 0.8× damage, 12 stamina.
  - Guard narrows to 45° and 40% reduction during the swing; full Guard returns afterwards.
  - +3 Resolve once per strike, only on enemies, and only once Resolve is unlocked.
- **Interception** (Lv7) and the **three Resolve spenders** (Lv5 / 7 / 9).
- **Shield Plant (Lv12, showcase):**
  - 85% reduction over a 90° frontal arc; 0.8 displacement resistance; 15% movement.
  - Rear hits land fully. Guard Break still breaks it.
  - E again exits through a 0.35s recovery.

**Concerns:**
- **C-4:** Rolling Fortress now modifies Shield Plant, as approved. Its augment requirement is therefore `v_shield_plant`, so **Rolling Fortress can no longer appear in a natural Lv1–10 draft**. Sentinel at Lv10 loses one of its three augments. A decision is needed: accept it, or allow a different Lv≤10 effect.
- **B-3:** Guarded Strike measured 54 damage taken during the swing vs 16 while guarding (Raider hit). Whether that risk is too punishing for 0.8× damage needs a VH playtest.

## 5. Resolve economy

| Source | Amount | Anti-farm rule |
|---|---|---|
| Guard | +5 | once per defended attack (source id + attack serial) |
| Perfect Guard | +20 (strongest) | once per attack |
| Counter | +10 | per counter |
| Interception | +15 | per interception |
| Guarded Strike | +3 | once per strike, enemies only |

| Spender | Cost | Job |
|---|---|---|
| Empowered Shield Rush (HOLD 1, Lv5) | 30 | Gap closer + taunt + stagger at range |
| Verdict Strike (full charge 2, Lv7) | 40 | One big single-target poise hit |
| Aegis Sweep (HOLD 3, Lv9) | 25 | Area threat control (hitbox ×1.25, threat ×3, taunt; no damage bonus) |
| Guardian's Reserve (augment) | 20, automatic | Brief damage reduction on the intercepted ally (not healing) |

Spenders do not appear in the UI or HUD before their skill unlocks (tested).

**Concerns:**
- **C-5:** Guardian's Reserve spends automatically on interception. The resolution did not define an input for it. It can therefore drain Resolve the player was saving for a Verdict. A manual trigger or an opt-in would be a design change.
- **B-4:** hold-to-spend uses 0.35s. That delays the empowered version by 0.35s but keeps a tap free for the normal skill. Tunable.

## 6. Camera

- **Investigated:**
  - The original 1.18m snap: caused by the occlusion sphere-cast jumping past a protruding wall corner. It no longer reproduces.
  - A new census sweeps 3 locations × 3 camera yaws × 2 directions.
  - Result: **1 anti-clipping snap of 0.57m in 18 runs**, at a tall `CylinderShape3D` pillar (4.5m) at world (26, 2.25, -2), with the camera behind the hero walking into it.
  - **0 rendered frames inside geometry** in any run.
- **Technical corrections made (A):**
  - Pivot look-ahead (0.3s motion prediction).
  - `min_collision_distance` lowered to 0.3m (it was a hard-coded 0.6m).
  - Lift fallback when the camera would penetrate.
  - Debug counters for snaps, inside-frames and lifts.
- **Player-visible change:** in tight spots the camera can now come closer to the hero (0.3m instead of 0.6m) before it lifts or snaps.

**Remaining:**
- **A-2:** a simplified camera-only collision proxy around tall pillars would probably remove the last snap. **This changes level geometry** (collision only, nothing visible), so I am reporting it rather than doing it.
- **C-6:** an occluder-fade camera (fade the pillar instead of pulling in) would change visible camera behaviour. It needs approval.

## 7. Animation and responsiveness

- **A-3:** all new actions use the same procedural pose generator, built from the attack timings. Specifically:
  - Flow Step, Turning Edge and the lateral steps are motion via `knock_velocity`, with no authored footwork.
  - Crosscut's second hit reshapes the hitbox into a narrow reverse slash, but the procedural swing does not visibly reverse.
  - Shield Plant reuses the guard pose.

  Authored clips and an AnimationTree are still missing.
- **A-4:** a missed Sunder Edge adds a separate 0.35s recovery action. On screen it can read as a short freeze rather than an over-swing. An authored follow-through would fix this.
- **B-5:** Final Stroke has 0.40s startup and 0.60s recovery. Readable, but it may feel slow after fast links. Tune after playtesting (RG).
- **C-7:** there is still **no audio**. Perfect Guard, link and Final-Stroke-ready cues are visual only, which makes timing-based mechanics harder to judge.

---

*Earlier report (Three-Class Combat Refoundation) follows unchanged for reference.*

# DESIGN & TECHNICAL FEEDBACK — Three-Class Combat Refoundation

Reviewer: implementation engineer (Godot 4.7.2).
Basis: the current Ashen Valley project, inspected before any class change. That covers code, data, tests and in-engine measurements.
The backup of the inspected state is `AshenValley_BACKUP_before_Refoundation.zip`.

How to read this document:
- Every recommendation is tagged **A** (technical correction, no design change), **B** (balance number inside the approved design) or **C** (design change: needs owner and design partner approval; **not implemented**).
- "Gap" means the spec does not define something that an implementation needs.
- I have tried to be critical rather than agreeable. Final creative decisions stay with the owner.

---

## 0. What the project actually is today (facts that shape every answer below)

| System | Current state (measured or read in code) |
|---|---|
| Attack model | `AttackRunner` phases STARTUP / ACTIVE / RECOVERY per `AttackData`. Each attack has `cancel_after`, `move_during`, lunge, hitbox box, poise, hitstop and stamina cost. Dodge-cancel exists. This is a solid base. |
| Input buffer | One stored action. It was **0.30s**; the spec asks for 0.15s (changed, see A1). |
| Animation | **Procedural**. `ProcAnim` builds AnimationPlayer tracks from attack timings on primitive "toon" models. There is no AnimationTree, no authored clips and no skeletal rig. |
| Audio | **None.** There are no audio assets and no audio players in the project. |
| Camera | Custom rig with sphere-cast collision and lock-on framing. The near-wall test failed before this work (investigated in A3). |
| Enemies | Wolf, Raider, Shield Guardian (frontal guard), Ash Caster (interruptible casts), Ashen Warden (boss). Only the Guardian and the boss have meaningful guard or poise mechanics. |
| Vanguard | Aegis Guard, Perfect Guard (0.2s window), Aegis Counter, Resolve (0–100), Shield Rush with interception, Judgment Strike (charge / riposte), Iron Sweep. Six augments, including 5 of the 9 now specified. |
| Mage | Worldweaver v1.0 is implemented: charged spells, formations, 4 interactions, Sanctum, 7 augments. |
| Reaver | Sword Sense core: Openings plus Tempo / Sunder / Vital cuts, a fixed 4-hit light chain, heavy, Draw Cut, Lunge and Flurry. There is no directional attack selection. |
| Progression | Drafts at 4 and 8 (plus an exotic draft at 10 for Vanguard and Reaver). There is **no mutation equip limit** and no Level 11+. |
| Tests | 400+ automated checks (mechanics only). |

---

## 1. Summary table

| Area | Strengths | Risks | Severity | Recommended action |
|---|---|---|---|---|
| Combat foundation | Clean phase model; dodge-cancel and buffer exist; lock-on is stable | No audio at all; procedural poses cannot deliver "smooth blending"; the 0.3s buffer caused late phantom actions; the camera snapped near walls | High | A1–A6 (implementable). Final feel depends on authored animation and sound assets the project does not have. |
| Vanguard | Readable defend → punish loop; interception is unique | Perfect-Guard dependence; Resolve has no real *spending* choices; Shield Plant / Guarded Strike / Aegis Mastery undefined; Sentinel's "structures" overlap Mage Stone and future Paladin | High | C-V1…C-V6 need decisions. Augments implementable with provisional numbers. |
| Mage | Clear, data-driven, already working; every element is usable | Long setup chains for Worldcraft; natural Conductive Anchors is only reachable through Sanctum before Lv10 because advanced spells still have no levels; Lifebinding vs Paladin overlap | Medium-High | Implement natural Conductive routes (approved). C-M1 (advanced spell levels) blocks a fair Worldcraft test without showcases. |
| Reaver | Strong concept, strong anti-Ninja and anti-Berserker intent | Nine named skills, of which **five are undefined** and **four have no unlock level**; a Draw Cut contradiction; the lateral-cut vs strafing input conflict; only 3 skill keys | **Critical** | C-R1…C-R8. Only Blade Lines L1, Lunge, Heavy / Draw Cut, Slip Cut and Flurry can be built faithfully now. |
| Progression | Unlock cadence of about one per level; drafts are respected | Drafts at 4 / 8 / 10 give only 3 augments by Lv10, so nine builds cannot exist naturally by Lv10. Mutation limit 3 is irrelevant before Lv11. Lv11–30 has no content. | Medium | Build Showcase presets (spec-sanctioned); C-P1, C-P2. |
| Augments | Behaviour-changing, not +% | Several depend on enemies with guards (only 2 types); some are prerequisites of skills that are not in the table | Medium | A-G1 eligibility; C-P3. |
| UI/UX | HUD already has class widgets and status icons | Status system lacks category / priority / source; notifications are not throttled per type | Medium | A-U1…A-U3. |
| Future classes | Spec explicitly guards against overlap | Sentinel ↔ Paladin, Lifebinding + Stone Ward ↔ Paladin, Breaker ↔ Berserker, Duelist + Slip Cut ↔ Ninja | Medium | Keep Vanguard structures physical (C-V3); define Duelist without dash or teleport (already stated). |

---

## 2.1 Combat foundation

**Will the foundation support three distinct classes without one feeling fundamentally less responsive?**
Mechanically, yes: all three share the same runner, buffer, dodge and cancel code paths, so no class is structurally slower to respond.
**Perceptually, not yet.** "Responsive" is mostly animation and sound, and the project has neither authored animation nor any sound. The Mage is the most exposed: a 1.2s charge with procedural poses and no audio cue reads as "nothing is happening".

**A1 — Input buffer 0.30s → 0.15s (done).**
- Issue: with 0.30s, a light press made during the last third of a heavy's recovery still fired after the heavy. Players experience this as a phantom attack.
- Example: Reaver Heavy (0.45s recovery). A panic-press at 0.2s into recovery produced a light swing 0.25s later, when the player had already started moving.
- Fix: 0.15s, one stored action, never bypassing `cancel_after` (heavy recovery stays committed). Type A/B.

**A2 — Animation continuity.**
- Issue: `ProcAnim` plays per-attack tracks. A legal attack-to-attack transition re-enters the pose from the previous end pose without blending, and the idle return is visible on chains.
- Recommendation: an `AnimationTree` with a BlendTree/StateMachine per class, crossfading 0.06–0.1s between attack states. The procedural tracks stay as clearly labelled placeholder animations.
- This is engineering (A) but costly. Without authored clips it improves continuity, not beauty.

**A3 — Near-wall camera (investigated and fixed).**
- Root cause, measured by tracing `cur_dist` per frame while strafing along the Valley wall: a wall edge crossing between hero and camera made the sphere-cast distance drop from 5.2m to about 1.5m in one frame. The proportional pull-in then moved the camera **0.66m in a single frame** (a visible pop).
- That pull-in was proportional to the gap, so any large occluder caused a jump. Slowing it down globally ("more smoothing") would have let the camera sit inside walls, which the spec forbids.
- Fix: when geometry only *occludes* (camera not inside), pull-in is capped (15 m/s, about 0.25 m per frame at 60 fps). If the capped step would leave the camera's near-plane volume inside geometry, it snaps to the safe distance.
- Result in the test: smooth pull-in, **0 frames inside geometry**, and **1 remaining snap (1.18m)** where a protruding wall section physically sweeps through the camera's position.
- That last case cannot be both smooth and clip-free with a single orbit camera. The real fix is simplified camera-collision proxies on the scenery (A, art pipeline) or a design choice to allow see-through fading of occluders (C).

**A4 — Hit feedback.** Hitstop, poise breaks and screen shake exist. **Impact and guard sounds do not exist.** I can add procedurally synthesised placeholder SFX (no paid or unlicensed assets). They will be functional, not good. Final sound needs real assets.

**A5 — Movement.** Acceleration and deceleration are fine. The lunge or approach steps on Reaver lights (4–8 m/s "lunge") produce sliding with procedural legs, which the spec explicitly lists as a failure sign. The new Reaver footwork must use short bounded steps (0.5–0.8m as specified) instead of velocity lunges.

**A6 — Readability.** Enemy telegraphs exist for casters and the boss. Wolves and Raiders have short startups (0.35–0.5s) with procedural wind-ups only. That is acceptable, but any "Perfect Guard" or "dodge-timing" design leans on telegraph quality we cannot fully deliver with placeholders.

**Pacing and complexity risk (C, informational).** The spec raises the number of concurrent concepts per class to 6–8 (core plus skills plus build systems), against enemies with 1–3 attacks each. The decision depth may exceed what these enemies test. Wolves and Raiders do not punish wrong *angle* or *spacing* choices strongly enough to make Reaver Measure or Duelist meaningful.

---

## 2.2 Vanguard

**Does Vanguard have enough offensive options?**
Lights, heavy, counter, Judgment, Iron Sweep and Shield Rush is enough *actions*, but almost all damage gates on Perfect Guard (counter, riposte, Iron Reprisal, Guardian's Return, Aegis Mastery). Guarded Offense is the right idea for the non-PG player, but it is **undefined**: no numbers, timing or input (Gap C-V1).

**Is Perfect Guard too central?** Yes. Of the 9 specified augments, 4 (Iron Reprisal, Guardian's Return, Verdict of Steel via Resolve-from-PG, and Aegis Mastery) reward PG directly, and Resolve gains are biased toward PG (+20 vs +5 for a normal guard).
- Example: against wolves (fast, low damage) the optimal play is holding guard forever. Against the boss, PG is the only meaningful damage window.
- Recommendation C-V2: make Resolve gain from hits *taken while guarding* and from *interceptions* comparable to PG, so the Sentinel and Interceptor builds are not secretly PG builds.

**Does Resolve offer meaningful spending decisions?** Not today. Resolve passively empowers Shield Rush and Judgment; nothing is *spent* by choice.
- The spec says "Resolve spending" at L5 but does not say what can be bought (Gap C-V3).
- Without at least 2 competing sinks (for example "spend 50 on an empowered Judgment" versus "spend 30 on a Shield Plant protection pulse"), Resolve is a damage multiplier, not a decision.

**Can Vanguard protect allies without becoming passive?** Interception is active and good. Shield Plant ("reduced mobility") plus Sentinel ("holding ground") plus the Rolling Fortress fix-up describe a stance build that is, by definition, low-mobility. That is fine, but it needs threat that pulls enemies *to* the Sentinel, or Sentinel waits.

**Are Sentinel / Interceptor / Retribution different?** Retribution and Interceptor are clearly different (where vs who). **Sentinel overlaps Retribution** because both resolve into "guard well". Sentinel's unique verb is "temporary protective structures", and the only structure source is Phantom Bulwark (an Exotic mutation).
- Example: a Lv10 Sentinel without Phantom Bulwark plays identically to a Retribution player who is bad at timing.

**Overlap with future classes:** Vanguard *structures* (Phantom Bulwark barrier) and the Mage's Stone Ward are both "raise temporary cover". A future Paladin (sword-and-shield plus magic protection) will want exactly that.
- Recommendation C-V4: Vanguard structures stay *physical* (shield wall, planted shield); magic barriers stay Mage/Paladin.
- Berserker overlap is low as long as Iron Sweep stays guarded and short.

**Likely mandatory picks:** Steadfast (guard stamina) is a universal efficiency pick for every Vanguard build. That is a classic "tax" augment (B: keep it small or make it conditional).

**Gaps (C):**
- C-V1: Guarded Offense / Guarded Strike timings and input.
- C-V3: Resolve sinks.
- C-V5: Shield Plant has no unlock level (it is not in the L1–10 table), yet Rolling Fortress depends on it.
- C-V6: Aegis Mastery "advanced defensive-to-offensive transition" is undefined. The current Lv10 is "Bulwark Mastery" (+35% PG window), a different thing.
- Verdict of Steel / Guardian's Return / Rolling Fortress have no numbers (B: I can use provisional values).

---

## 2.3 Mage

**Is charging enjoyable vs fast enemies?** Partially. The 0.25s partial release keeps the Mage alive against wolves, but at Lv1–2 the Mage has only Flame Cataclysm and Life, and no tool to stop three wolves. The first control (Frost) arrives at Lv3.
- Expect Lv1 wolf packs to feel bad for the Mage specifically. This is a balance issue (B: wolf pack size near spawn, or partial Flame knockback), not a design flaw.

**Does Mage require too much preparation?** Worldcraft does. A natural Conductive route before Lv10 currently needs:
- Arcane Sanctum (Lv5).
- A full Earthbreaker cast *inside* it (1.8s) to raise the only Lv1–10 Stone formation.
- A full Thunder Conduit (1.2s) that reaches it (Lv9).

That is about 4s of committed charging plus 40+ mana before the payoff, because **Rising Pillar and Stone Ward still have no unlock level** (C-M1, carried over from the Worldweaver report).
- Recommendation C-M1: give Stone Ward or Rising Pillar a level, or make them draftable. Otherwise "Worldcraft at Lv10" is Sanctum-mandatory, which contradicts "Mage remains functional without it".

**Are all five elements useful independently?** Yes, mechanically; each has a self-contained spell.
Storm is weakest as a solo element. Its unique value (interrupt) lives in Lightning Verdict, which has no level, so the natural Lv9 Storm player gets only a chain-damage spell.

**Are interactions rewarding / too complicated?**
- Thermal Fracture is cheap and readable.
- Shattered Winter is readable.
- Living Bastion is low impact: the healing is intentionally small and the trigger is spatial.
- Conductive Anchors is the most complicated for its benefit: one relay hop.
- Expect players to discover Fracture and ignore the rest unless guided (hence the Lab).

**Can the Mage heal under pressure?** Lifeline (instant, 12s) plus partial Bloom (0.25s) cover emergencies; a full Bloom at 65% move speed is fine against single bosses.
Risk: in Party with AI, the AI Vanguard does not always stay in heal range (22m). That is a technical issue I can monitor.

**Too many persistent objects?** No. The limits (2 solid, 2 Fire areas, steam cap) hold, and a profile of a full party fight stayed within budget. Visual clutter is the bigger risk than performance.

**Is Arcane Sanctum optional?** For Cataclysm and Lifebinding, yes (+1 wave, +35% spread). For Worldcraft it is currently *mandatory* in practice (see C-M1).

**Are the three playstyles different?** Cataclysm vs Lifebinding, yes.
Worldcraft vs Cataclysm differ mostly in *augments*, and by Lv10 a player owns 3. Draft luck decides whether you are "Worldcraft" at all; Build Showcases are required to feel it.

**Paladin overlap:** Protective Renewal (shield + heal-back) plus Stone Ward (cover) plus Living Bastion (healing structure) *is* a defensive caster-tank kit.
- Recommendation C-M2: keep Mage protection ranged and spell-based (no melee-range auras), so Paladin can own "protect while in melee".

**Spec items now defined and implementable:**
- Natural Conductive Anchors: a full Thunder Conduit contacting a compatible Stone formation makes it conductive for 6s.
- Storm Lattice and Second Heart (provisional numbers, B).
- The draft at Lv10.

**Remaining gaps:**
- C-M1: advanced spell levels.
- C-M3: "contacting" a formation with a target-chained spell is not geometric. Proposed interpretation: the chain path passes within 1.5m of the formation, or the strike lands within 3m of it.
- C-M4: does Storm Lattice relay more than once? Proposed: one extra relay per anchor.

---

## 2.4 Reaver (most critical)

**Spec completeness.** Of the nine named skills:

| Skill | Defined? | Unlock level |
|---|---|---|
| Forward Cut | yes | L1 |
| Lateral Cut | yes | L1 |
| Heavy Cut / Draw Cut | yes | L1 / **L7** (contradiction) |
| Slip Cut | partially | — (no level) |
| Piercing Lunge | yes | L3 |
| Flow Step | **no** | L5 |
| Crosscut | **no** | L7 |
| Tempest Flurry | exists today | L9 |
| Sunder Edge | **no** | — |
| Final Stroke | **no** ("when eligible": what makes it eligible?) | — |
| Turning Edge | **no** | — |

- **C-R1:** five skills cannot be implemented without inventing them. Four skills have no level.
- **C-R2 (contradiction):** RMB "Hold for eligible Draw Cut" is listed in Blade Lines at Lv1, but Draw Cut unlocks at Lv7.

**C-R3 — Directional input vs strafing.**
- Issue: with lock-on, moving left or right is *strafing*. If Left/Right + LMB always means Lateral Cut, a player strafing around a Raider who presses LMB gets a lateral cut every time, never a Forward Cut.
- Without lock-on, "left" is camera-relative while the character faces its movement direction, so "left" is ambiguous.
- Example: circling a Shield Guardian to its flank, then pressing LMB to attack its back, produces a sideways cut that whiffs.
- Recommendation (C): Lateral Cut is selected **relative to the facing at press time, only while locked on**, and only by an input flicked within about 0.12s before the press (not a held strafe). Without lock-on, LMB is always Forward Cut.
- Can players deliberately pick attacks? Only with a rule like this. Accidental attacks: very likely without it.

**Blade Continuity without a meter.** Understandable *if* each legal link has a visible tell: a sword glint or trail colour on the link window, plus a subtle sound. Without audio and with procedural animation, players will not perceive windows (A2 / A4 matter here).
"Expansion" at Lv5 is undefined: which new links? (C-R4)

**Button spam.** The current Reaver *does* reward spam (a fixed 4-hit chain). Blade Lines removes the fixed chain, which is good. But if every direction is always legal, mashing with random directions still works. Rewarding decisions requires that **wrong-measure attacks miss**: narrow, longer or shorter hitboxes per line (Measure). That is implementable (A) and is the real anti-spam tool.

*Post-implementation measurement:* with the specified rules (and my inference that only a left ↔ right reversal is illegal), mashing LMB on a static Raider deals **402 damage in 6s, vs 254 for the old Sword Sense core**, because Forward → Forward is a legal, faster-starting link. I recommend a **C decision**: either make repeated Forward Cuts non-linking, or define which base transitions are legal. Until then the design risk "rewards spam" is real and measurable.

**Flowblade vs Duelist:** both are "move + cut". Flowblade = sustained linked pressure (stamina economy); Duelist = single decisive line from the right distance.
They differ only if Duelist techniques (Lunge, Slip Cut, Turning Edge, Measured Step) have *punishing* recovery on miss, while Flowblade links are cheap but weak. That is a balance decision (B) inside a design that needs C-R1.

**Breaker vs Berserker:** Breaker = guard pressure with a *one-handed sword technique* (Sunder Edge, Draw Cut, Final Stroke). It stays distinct if Breaker never trades HP for power and keeps heavy attacks precise rather than wide.
Risk: Sundering Verdict and Finality need enemies with guards, and only the Shield Guardian (and partly the boss) has one, so **Breaker is non-functional against wolves, raiders and casters** (C-R5).

**Duelist vs Ninja:** Slip Cut (dodge → cut) plus Turning Edge (redirect after footwork) plus Measured Step is close to Ninja's "mobility and deception" unless all movement stays bounded (0.5–0.8m) and grounded, with no invulnerable repositioning beyond the normal dodge. Keep Slip Cut tied to a *normal* dodge.

**Effectiveness when enemies cannot be displaced:** Reaver has no displacement dependence. The boss is fine.

**Only three skill keys** (1/2/3) for Lunge, Flow Step, Crosscut, Tempest Flurry and Sunder Edge or Final Stroke or Turning Edge. A loadout rule is needed (C-R6).

**Swordmaster's Discipline:** "an additional legal directional transition" — which transition? (C-R7)

**Retiring Sword Sense:** Openings (enemy recovery windows) are the only thing teaching Reaver players *when* to attack. Removing them without an equivalent ("Measure" is about *where*, not *when*) may make Reaver feel aimless. Consider keeping enemy recovery tells as **visual feedback only**, with no bonus damage (C-R8, recommendation).

---

## 2.5 Progression & augments

- **Cadence:** about one unlock per level (good).
- **Nine builds by Lv10:** drafts at 4 / 8 / 10 give 3 augments. Each build has 3–4 signature augments, so **no build can be complete naturally by Lv10.** Builds emerge after Lv10; until then a class is "base kit + 1 flavour". The spec anticipates this with Build Showcases.
- **Mutation limit 3:** only matters after Lv10 (3 drafts can yield at most 3 mutations). Implemented as owned vs equipped, with no deletion.
- **Single dominant augment:** Steadfast (Vanguard tax). Everlasting Bloom is neutral by design.
- **Non-functional builds through draft luck:** the eligibility system already removes unusable cards. Breaker cards against guard-less enemies are a design issue (C-R5).
- **Lv11–30:** the spec forbids inventing content, so only the framework (milestone slots at 15 / 20 / 25 / 30) is possible.
- **C-P1:** what fills Lv11–14, 16–19, and so on (stats? drafts?).
- **C-P2:** do Lv10 masteries replace the current Lv10 "exotic draft" milestone? Yes per table ("Mastery + Draft").
- **C-P3:** augments requiring skills not in the table (Rolling Fortress → Shield Plant; Needlepoint → Lunge is fine; Turning Steel → Turning Edge?).

---

## 2.6 Class identity & future compatibility

| Pair | Overlap risk | Note |
|---|---|---|
| Vanguard Sentinel ↔ Paladin | High | Both "hold ground + protective structures". Keep Vanguard physical (C-V4). |
| Mage Lifebinding ↔ Paladin | Medium | Keep Mage protection ranged (C-M2). |
| Reaver Breaker ↔ Berserker | Medium | Breaker = precision guard-breaking with a one-handed sword; Berserker = greatsword, risk/HP. Must not give Breaker damage-for-HP trades. |
| Reaver Duelist ↔ Ninja | Medium | No teleports, invisibility or dash chains; footwork bounded (spec already says so). |
| Vanguard Retribution ↔ Reaver Duelist | Low-Medium | Both "punish timing". Retribution punishes *after guarding*, Duelist *by spacing*. Fine if Reaver has no guard. |

---

## 3. Recommendations by category

**A — Technical corrections**

| ID | Recommendation | Status |
|---|---|---|
| A1 | Buffer 0.15s | done |
| A2 | AnimationTree blending | planned |
| A3 | Camera fix | done |
| A4 | Placeholder SFX (synthesised) | planned |
| A5 | Bounded footwork steps instead of velocity lunges | Reaver milestone |
| A-G1 | Eligibility: no guard-dependent augments while the class lacks the prerequisite skill | |
| A-U1 | Status model with category / priority / source / magnitude | |
| A-U2 | Throttled notifications | |
| A-U3 | Icon + shape + timer (not colour-only) | |

**B — Balance (provisional, documented)**

| Topic | Value |
|---|---|
| Lv1 Mage vs wolves | |
| Steadfast size | |
| Storm Lattice | +1 relay per anchor |
| Second Heart | 30% of overheal, max 15% HP, 4s |
| Conductive duration | 6s (spec) |
| Lateral step | 0.6m |

**C — Need approval (not implemented)**

| ID | Question |
|---|---|
| C-V1 | Guarded Offense definition |
| C-V2 | Resolve gain rebalance away from PG |
| C-V3 | Resolve sinks |
| C-V4 | Vanguard structures stay physical |
| C-V5 | Shield Plant level |
| C-V6 | Aegis Mastery definition |
| C-M1 | Advanced Mage spell levels |
| C-M2 | Keep Mage protection ranged |
| C-M3 | "Contact" interpretation |
| C-M4 | Lattice relay count |
| C-R1 | Five undefined Reaver skills, four without level |
| C-R2 | Draw Cut L1 vs L7 |
| C-R3 | Lateral-cut input rule |
| C-R4 | Continuity "expansion" |
| C-R5 | Breaker vs guard-less enemies |
| C-R6 | Reaver skill loadout |
| C-R7 | Discipline definition |
| C-R8 | Keep enemy recovery tells as visuals |
| C-P1 | Lv11–30 content |
| C-P2 | Masteries replacing the current Lv10 |
| C-P3 | Missing skill prerequisites |

**What I implement without waiting:**
- All A items.
- Specified, unambiguous mechanics, with B numbers documented.
- Where a C gap blocks a feature, the feature is left out and listed. It is never replaced by my own design.
