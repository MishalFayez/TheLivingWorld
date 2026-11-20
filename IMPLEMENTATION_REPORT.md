> **Later work (2026-11-20, not yet merged):** technical fixes from QA-001, the class & combat audit and the
> ChatGPT review are documented in `collaboration/results/QA-001.md`, `CLASS_COMBAT_AUDIT.md` and `REVIEW-001.md`.
> Current test counts are in README → Test results (628/628). The camera and test numbers below are historical.

# IMPLEMENTATION REPORT — Refoundation Design Resolution

Engine: Godot 4.7.2 (GDScript). Date: 2026-11-20.
Backup of the project before this pass: `AshenValley_BACKUP_before_DesignResolution.zip`.
Mage was not changed. Vanguard and Reaver were extended, not rebuilt. Category **C** items in `DESIGN_TECHNICAL_FEEDBACK.md` were **not** implemented.

## Implemented

### Reaver
| Item | Implementation |
|---|---|
| Directional input | LMB = Forward Cut always. **Shift + A/D + LMB** = Lateral left/right, using the new `blade_modifier` action on Shift. No binding was changed or removed. The direction is captured when the input is accepted (also for buffered presses) and never changes mid-animation. |
| Forward→Forward | Allowed, but it is not a link: no faster start, no tracking, no follow-up flags. Only line changes link (0.75× startup). There is no damage multiplier. |
| Draw Cut | Lv7. Lv1–6 has the normal Heavy Cut. Shown as a separate Lv7 row in the Skills menu. |
| Flow Step (Lv5) | About 0.7m (measured 0.74m) in the input direction; backward from neutral. Costs 12 stamina, 3s cooldown, no i-frames, collision-safe, no attack. Used in a link window, it keeps the sequence alive for the next different cut ("expanded continuity"). |
| Crosscut (Lv7) | Two hits: a wide diagonal, then a narrow reverse, ±35° steering on the second. Damage split 55/45 under the multi-hit rules. No crit bonus, no third hit. A dodge after the first hit abandons the second. 5s cooldown. |
| Sunder Edge (Lv12, showcase) | Committed strike: 1.2× damage, 55 poise. Against a raised guard: ×0.75 damage and ×1.5 poise (82 vs 32 poise compared with Heavy). No full bypass, no automatic boss stagger. A miss adds 0.35s recovery. 8s cooldown. |
| Turning Edge (Lv15, showcase) | Requires A or D held. A short collision-safe side step (0.74m), then a slash. No teleport, no auto-behind. A frontal hit gets no benefit; a real flank (≥60°) avoids the shield and opens Final Stroke. 6s cooldown. |
| Final Stroke (Lv18, showcase, F) | Opens for 1.5s after any of: two different linked attacks connect, a Sunder Edge poise break, or a Duelist flank hit (Turning Edge / Slip Cut / Lunge ≥60°). Costs 25 stamina, 0.4s startup, 0.6s recovery. Can miss, can be guarded, ends the sequence, no guaranteed crit. |
| Skill slots | 1 / 2 / 3 / E loadout chosen in Skills (K). Unlocked skills auto-fill empty slots. The loadout is saved per class. |
| Progression | 1 Forward/Lateral/Heavy · 3 Lunge · 5 Flow Step + expanded continuity · 7 Crosscut + Draw Cut · 9 Flurry · 10 Discipline · 12 Sunder Edge · 15 Turning Edge · 18 Final Stroke. Lv>10 rows show `Lv12*` with "Beyond the Lv10 prototype cap: Build Showcase" and are reachable only through Lab showcases or debug unlocks. No other Lv11–30 skills were added. |

### Vanguard
| Item | Implementation |
|---|---|
| Guarded Strike (Lv1) | Shift + LMB from Guard. 0.8× damage, 12 stamina. Guard narrows to 45° and 40% during the swing; full Guard returns after recovery while Shift is held. +3 Resolve once per strike on enemies only, after Resolve unlocks (Lv5). |
| Shield Plant (Lv12, showcase, E) | 4s, 18s cooldown, 15% movement, 15 stamina. 85% reduction over a 90° front arc; 0.8 displacement and poise resistance. No rear protection. Guard Break and stamina break end it. E again exits through a 0.35s recovery. Guard and Perfect Guard do not depend on it. |
| Rolling Fortress | Now modifies Shield Plant: Dodge while planted repositions and stays planted. |
| Resolve sources | Guard +5, Perfect Guard +20, counter +10, interception +15, Guarded Strike +3. Duplicates are prevented by source id + attack serial. |
| Resolve spenders | HOLD 1 (≥0.35s) = Empowered Shield Rush (30, Lv5). Full charge 2 = Verdict Strike (40, Lv7). HOLD 3 = Aegis Sweep (25, Lv9; area, threat ×3, taunt, no damage bonus). A tap gives the normal skill. HUD and menus show only the spenders already unlocked. |
| Guardian's Reserve | New augment (requires Interception + Resolve). On interception it spends 20 Resolve automatically and gives the ally 3s of limited damage reduction (not healing). |

### Camera (shared technical correction)
- Pivot look-ahead and `min_collision_distance` 0.3m.
- Lift fallback when the camera would penetrate.
- Snap and penetration counters, plus a wall-sweep census test.
- The original 1.18m snap no longer reproduces.
- **One reproducible 0.57m snap remains** (tall pillar; see feedback §6). The camera is **not** claimed fully fixed.

### Lab and UI
- New guided scenarios: **RA–RG** (Reaver) and **VH–VJ** (Vanguard); 30 in total.
- R1–R5, V2 and V4 texts updated for the new controls.
- Showcase presets carry the Lv12–18 skills plus a Reaver loadout:
  - Sentinel: Shield Plant.
  - Interceptor: Guardian's Reserve.
  - Breaker / Duelist / Flowblade: their skills plus Final Stroke.
- Skills menu: Reaver loadout selectors and the "beyond Lv10 cap" labelling.
- HUD: Reaver slots follow the loadout; F Final Stroke shows once unlocked.
- Lab text now word-wraps. Before this, the panel ran off-screen and hid the scenario buttons.

## Interpretations (please confirm)
1. Resolve spend input = **hold** the skill key for 0.35s (tap = normal skill). Verdict Strike = full Judgment charge with ≥40 Resolve.
2. Shield Plant on **E** (the Vanguard had nothing on E). Reaver skills on loadout slots **1/2/3/E**; Final Stroke on **F**. These are existing keys; no binding was changed.
3. "Guard / Poise break" by Sunder Edge = the target's poise break (stagger).
4. "Approved Duelist technique" angle = Turning Edge, Slip Cut or Piercing Lunge hitting ≥60° from the target's front.
5. "Expanded continuity" (Lv5) = Flow Step used in a link window keeps the sequence for the next different cut.
6. Turning Edge with no A/D held is refused (direction must be intentional).
7. Guardian's Reserve spends automatically on interception (no input was specified).
8. **Provisional numbers:** Flow Step stamina 12; cooldowns Crosscut 5s, Sunder Edge 8s, Turning Edge 6s; Final Stroke stamina 25; Guarded Strike 0.8× / 12 stamina; Guardian's Reserve 3s. All are in `tools/generate_data.gd` / `balance_config.gd`.

## Remaining incomplete work
- **Camera:** one 0.57m snap near a tall pillar. Fixing it needs either a camera-collision proxy (a level-geometry change) or occluder fade (a visible behaviour change). Both are reported, not done.
- **No audio** at all.
- **No authored animation and no AnimationTree.** All poses are procedural. Crosscut's reverse slash, Flow Step footwork and the Shield Plant stance have no distinct authored motion.
- **No gamepad binding** for `blade_modifier` (the project has no controller layout yet).
- **Finality augment:** still unspecified, so not implemented.
- **Lv11–30:** only the named skills (Sunder Edge, Turning Edge, Final Stroke, Shield Plant) exist, as showcase content. Nothing else was invented.
- **Rolling Fortress** cannot appear in natural Lv1–10 drafts any more, because it now requires Shield Plant (C-4).
- **Human playtesting** of everything above has not been done.

## Testing (Godot 4.7.2, headless, `--fixed-fps 60`)
| Suite | Result |
|---|---|
| resolution_runner (new: Design Resolution) | **78 / 78** |
| refoundation_runner | 71 / 71 (two checks superseded by approved changes were replaced) |
| mage_runner | 164 / 164 |
| test_runner | 136 / 136 |
| update5_runner | 63 / 63 |
| smoke_runner | 31 / 31 |
| camera_jitter | 7 / 7 (census: 1 snap in 18 runs, 0 frames inside geometry) |
| compare_runner | spam investigation table (DESIGN_TECHNICAL_FEEDBACK §2) |

The two superseded refoundation checks:
- "Rolling Fortress while guarding" now runs in resolution_runner, against Shield Plant.
- "Flow Step / Crosscut shown as DESIGN PENDING" is now a check that both are real skills.

No script errors appeared in the logs.

Screenshots: `screenshots/resolution_*.png`.

**These tests verify mechanics only. They do not verify feel, readability or fun.** Use `CLASS_PLAYTEST_GUIDE.md` (RA–RG, VH–VJ).

---

*Previous report (Three-Class Combat Refoundation) follows unchanged.*

# IMPLEMENTATION REPORT — Three-Class Combat Refoundation

Engine: Godot 4.7.2 (GDScript).
Backup of the project before this work: `AshenValley_BACKUP_before_Refoundation.zip`. The previous Reaver (Sword Sense / Bladecraft) and the old Mage cores also remain selectable in Debug → Character → Class cores.
The design review is in `DESIGN_TECHNICAL_FEEDBACK.md`. Its **C** items were **not** implemented.

---

## Implemented

### Milestone 1 — Shared combat feel
- **Input buffer 0.15s** (was 0.30s). One stored action. It never bypasses committed recovery, and it expires instead of firing late.
- **Reaver direction is captured at press time** for buffered attacks; it is not re-read when the attack fires.
- **Near-wall camera:**
  - Investigated the root cause (see Technical Problems).
  - Fixed: occlusion pull-in is capped at about 0.25 m/frame, and the camera snaps only if its near-plane would end inside geometry.
  - Added a regression check: 0 frames inside geometry.
- **Throttled combat banners:** PERFECT GUARD, GUARD BROKEN, INTERRUPTED, PROTECTED, POISE BROKEN. Max 3 visible; the same text at most once per 1.2s.
- **Camera guard:** the shake code no longer crashes if the camera node is not ready during a class switch (an error seen while taking screenshots).

### Milestone 2 — Vanguard
- **Lv1–10 table matches the spec.** Interception moved from Lv6 to Lv7. Lv5 is named "Resolve Spending". Lv10 is named "Aegis Mastery", with the existing mechanic (see Deviations).
- **New augments:**
  - **Guardian's Return:** an interception opens a 1.5s Aegis Counter window.
  - **Verdict of Steel** (mutation): a Resolve Judgment deals ×2.2 Poise and ×0.7 damage.
  - **Rolling Fortress:** Dodge while guarding becomes a guarded step (about 1.4m, shield stays up, 10 stamina, 0.6s internal cooldown).
- **Existing augments kept:** Iron Reprisal, Last Line, Steadfast, Crushing Rhythm, Unyielding Charge, Phantom Bulwark.

### Milestone 3 — Mage (Worldweaver refinements)
- **Natural Conductive Anchors:**
  - A FULL Thunder Conduit whose strike or chain path contacts a Stone formation makes it Conductive for **6s**, in normal gameplay.
  - "Contact" means a struck point within 3m, or a chain segment within 1.5m.
  - Each anchor relays a cast once.
  - The Debug toggle is still there for testing.
- **Storm Lattice:** Conductive lasts 9s, and an anchor can relay the same cast twice (bounded).
- **Second Heart:** 30% of overheal becomes a shield, capped at 15% of max HP, for 4s.
- **Lv10 draft added.** Drafts are now at 4 / 8 / 10, as the spec table says.
- **The Mage augment pool is now the 9 listed augments.**

### Milestone 4 — Reaver: the Swordmaster (new default core)
- **Blade Lines:**
  - Forward Cut (neutral or forward + LMB).
  - Lateral Cut (Left or Right + LMB): wide and short, with a 0.6m collision-safe side step.
  - Heavy Cut (RMB).
  - Draw Cut (hold RMB, Lv7).
  - Slip Cut (Dodge → LMB within 0.35s).
  - Piercing Lunge (1, Lv3) and Tempest Flurry (2, Lv9).
- **Measure:** every line has its own reach, width and approach.
  - Forward: 2.4m deep, 0.6m max approach.
  - Lateral: 3.0m wide, 1.8m deep, no approach.
  - Heavy: narrow and 2.9m deep.
- **Blade Continuity:**
  - An attack started in the previous attack's cancel window, or within 0.3s after it ends, is LINKED. It starts 25% faster and keeps tracking.
  - **No damage multiplier and no combo meter.**
  - Lateral left ↔ right reversal is refused with "NO LINK" feedback (Crosswind or Discipline allow it).
- **Swordmaster's Discipline (Lv10):** one otherwise-illegal directional link per sequence.
- **Augments:** Flowing Edge, Crosswind, Unbroken Line, Sundering Verdict (weakens a raised guard for 4s), Drawn Horizon, Measured Step, Turning Steel, Needlepoint.
- **HUD:** three marks for the last line, which glow while a link is open. Skill slots show Lunge and Flurry.
- **AI Reaver** uses the same Blade Lines rules and never attempts illegal links.
- **Retired cores:** Sword Sense and Bladecraft stay selectable in Debug, with their own unlock levels, for comparison.

### Milestone 5 — Progression
- All three tracks match the spec's L1–10 table.
- **Drafts at 4, 8 and 10** for every class.
- **Major Mutations:**
  - At most 3 equipped. Extra ones stay owned and inactive, never deleted.
  - Swap them in Augments ("Equip, replacing X").
  - Saved with the game.
- **Lv11–30 framework:** milestone slots at 15 / 20 / 25 / 30 (`ProgressionTrack.future_slots`), all marked "design pending". The level cap stays at 10.

### Milestone 6 — UI/UX
Status model:
- Category, priority, magnitude, source, stack count and expiration rule.
- Icons are ordered by priority: crowd control, then danger, then protection, then buffs, then secondary.
- Shape marks (triangle = danger, square = protection), a seconds counter and a last-second blink, so meaning is not carried by colour alone.
- The tooltip shows name, category, magnitude and source.

Other UI:
- Reaver class widget (see above).
- Mutation equip UI.
- Updated Spellbook (Worldweaver).

### Milestone 7 — Validation & playtesting package
- **Class Experience Lab** (F1 → **Lab** tab), as specified:
  - Class switch and Solo/Party.
  - Invincibility.
  - Fresh Lv1, Lv5 (1 draft pending) and Lv10 (3 drafts pending).
  - **9 BUILD SHOWCASE presets**, clearly labelled as not a natural Lv10 build.
  - Enemy spawns.
  - Restore, reset encounter, reset metrics, baseline.
  - Teleports.
  - Per-class controls.
  - All of it taints the session, so it is never saved.
- **Guided Playtest Mode:** 20 scenarios (V1–V4, M1–M5, R1–R5, A–F).
  - A small left-edge panel shows the mechanic, what you do and the expected result.
  - Restart / Skip / Hide / End.
  - The player always performs the actions.
- **Documents:** `CLASS_PLAYTEST_GUIDE.md` and `PLAYTEST_FEEDBACK.md` (empty scores, to be filled by humans).
- **Old vs new measurements:** `tests/compare_runner.tscn` (results below).

---

## Incomplete (not implemented, with reason)

| Item | Reason |
|---|---|
| Shield Plant, Guarded Strike / Guarded Offense (Vanguard) | Not defined (timings, input) and not in the level table (C-V1, C-V5) |
| Resolve *spending choices* beyond the existing Verdict / Resolve Sweep | Spend options not defined (C-V3) |
| Aegis Mastery's specific "defensive-to-offensive transition" | Not defined. The existing Bulwark Mastery effect is kept under the new name (C-V6) |
| Reaver: Flow Step, Crosscut, Sunder Edge, Final Stroke, Turning Edge | Not defined. The Lv5 / Lv7 milestones show "DESIGN PENDING" (C-R1) |
| Reaver: Finality augment | Modifies Final Stroke, which is undefined |
| Reaver: "Blade Continuity expansion" at Lv5 | Not defined (C-R4) |
| Lv11–30 content | The spec forbids inventing it. Only the framework exists (C-P1) |
| AnimationTree crossfade blending (A2) | Not done this pass. Placeholder procedural poses remain |
| Impact / guard sounds (A4) | No audio assets exist. Synthesised placeholder SFX were not done in this pass |
| CLEANSED notification | Supported by the banner system, but no cleanse mechanic exists in the game, so it never fires |
| Mage advanced spell levels | Still no levels (C-M1). They are reachable via showcase presets and Debug only |
| Running the same scenarios inside the old build | The old Reaver core is selectable in Debug in this build, and the full old project is in the backup zip. The Lab presets themselves are new-build only |

---

## Technical Problems

1. **Near-wall camera (measured).**
   - Strafing along the Valley wall, the old proportional pull-in moved the camera **0.66m in one frame** when a wall edge crossed the camera line.
   - After the fix: smooth occlusion pull-in (≤0.25 m/frame) and 0 frames with the near-plane inside geometry.
   - **One forced snap (1.18m) remains** in the test path, where a protruding wall section physically sweeps through the camera position. A smooth, clip-free result there needs simplified camera-collision proxies on the scenery or an occluder-fade design (C).
2. **No audio.** Hit, guard and spell feedback is visual only. This weakens every "feel" evaluation.
3. **Procedural animation.** Linked attacks re-enter poses without a crossfade.
4. **Buffered dodge during an attack's active frames.** In the measurement below, a dodge pressed 0.2s into a new Forward Cut is buffered until the cut can be cancelled.
   - Old light cuts were 0.03s shorter, so 3 of 5 dodge attempts landed instantly; the new ones landed 0 of 5. The dodges still happen, just later.
   - This is commitment by data (startup + active 0.24s) and may be intentional. It needs human feel testing (B).
5. **Button spam still pays.** Forward → Forward is a legal link and linked attacks start 25% faster, so mashing LMB deals **more** damage on a static dummy than the old core did (402 vs 254 in 6s).
   - This conflicts with "fast combat does not mean button spam".
   - Options: make Forward → Forward non-linking, or narrow forward reach so whiffs happen. Both are **C or B decisions**, not changed.
6. **Performance:** a headless party fight at Lv10 averaged 0.86 ms of simulation per frame. Rendering cost was not measured in this container.

### Old vs new measurements (Reaver, Lv10, same frozen Raider; `tests/compare_runner.tscn`)

| Metric | Sword Sense (old) | Swordmaster (new) |
|---|---|---|
| Press → attack start | 0 frames | 0 frames |
| First light: startup / active / recovery | 0.11 / 0.10 / 0.24s | 0.14 / 0.10 / 0.28s |
| Damage in 6s of LMB every 0.25s | 254 | 402 |
| Distance moved by attacks | 0.80m | 1.54m |
| Dodge-cancel at 0.2s into a light | 3/5 immediate | 0/5 immediate (buffered) |
| Heavy startup / recovery | 0.38 / 0.45s | 0.38 / 0.50s |

These are objective numbers only. They say nothing about which version feels better.

---

## Deviations

| Original requirement | Actual implementation | Reason | Gameplay impact | Approval needed |
|---|---|---|---|---|
| RMB "hold for Draw Cut" in Blade Lines (L1) | Draw Cut unlocks at **Lv7** (table) | The spec contradicts itself (C-R2) | Lv1–6 RMB is Heavy Cut only | Yes |
| "Left/Right + LMB" | Direction read relative to the facing (or the locked target) at press time; lateral if the sideways component is ≥0.6 | An exact rule is needed to implement | Strafing while locked and pressing LMB gives lateral cuts (risk C-R3) | Yes (rule) |
| Base legal transitions not listed | Everything links except lateral left ↔ right reversal | Inferred from Crosswind's existence | Mashing Forward still links (problem 5) | Yes |
| Continuity benefit not quantified | Linked = 25% faster startup, keeps tracking | "more fluid transitions" | Provisional (B) | Tuning |
| Slip Cut has no level | Available from Lv1 (it is in the Blade Lines list) | Listed under the core | — | Confirm |
| Aegis Mastery wording | Existing mastery (+35% Perfect Guard window, +40% counter windows) renamed | The new wording is undefined | Same mechanic as before | Yes |
| Rolling Fortress "eligible defensive stance" | Aegis Guard is the stance (Shield Plant does not exist) | Shield Plant is undefined | Works without Shield Plant | Confirm |
| Sundering Verdict "weakens Guard effectiveness" | A Heavy / Draw Cut on a raised guard applies "Sundered" for 4s (guard blocks 40% instead of 75% of lights) | Numbers are provisional | Only the Shield Guardian has a guard | Tuning / C-R5 |
| Swordmaster's Discipline | One left ↔ right reversal link per sequence | Reading of "additional legal directional transition" | — | Confirm |
| Conductive "contact" | Struck point within 3m, or chain segment within 1.5m | Geometry needed (C-M3) | — | Confirm |
| Storm Lattice | +50% duration and +1 relay per anchor | Numbers not given | — | Tuning |
| Second Heart | 30% of overheal, cap 15% max HP, 4s | Numbers not given | — | Tuning |
| Turning Steel | The next linked attack after a Lateral Cut faces the movement input | Reading of "modifies attack direction after footwork" | — | Confirm |
| Measured Step | Dodge within 0.6s after a connecting Lunge = 6-stamina step, no i-frames | Reading | — | Confirm |

---

## Testing

### Automated functionality verified (Godot 4.7.2, headless, `--fixed-fps 60`)

| Suite | Result |
|---|---|
| `tests/refoundation_runner.tscn` (new) | **72 / 72** |
| `tests/mage_runner.tscn` (Worldweaver) | 164 / 164 |
| `tests/test_runner.tscn` (core, including legacy cores) | 136 / 136 |
| `tests/update5_runner.tscn` (saves, taint, stats, equipment, retired Sword Sense) | 63 / 63 |
| `tests/smoke_runner.tscn` (all classes, Valley run, boss, save, all Debug tabs) | 31 / 31 |
| `tests/camera_jitter.tscn` (including the near-wall checks) | 6 / 6 |

There were no script errors in any suite log.

The new suite covers:
- The 0.15s buffer, heavy commitment, and buffer expiry.
- The Reaver direction mapping (forward / left / right / heavy / slip), the bounded side step (0.63m measured), and Measure data.
- No excessive magnetism, wall collision safety, legal and illegal links, Discipline, Draw Cut gating, and all 8 Reaver augments.
- The Vanguard table and its 3 new augments.
- Natural Conductive Anchors (full vs partial), Storm Lattice, Second Heart.
- Drafts at 4 / 8 / 10 for every class, and the Lv11–30 slots.
- The mutation limit (3 equipped, the extra one kept inactive, swap, save/load).
- Status priority, magnitude, no duplicates, expiry, POISE BROKEN.
- Lab presets, taint isolation, guided scenario setup, and a performance smoke test.

### Manual gameplay feel NOT yet verified
Nothing about enjoyment, readability or "feel" was validated automatically.
Priorities for human testing:
1. **R1 / R2:** does Left/Right + LMB produce the intended cut while strafing locked-on (risk C-R3)? Does mashing feel rewarded (problem 5)?
2. **M4:** is the natural Conductive route worth its setup?
3. **V1 / V4:** Perfect Guard readability without audio.
4. **Camera near walls** in the Ruins and the Keep (different geometry from the test path).
5. **Party scenario F:** AI behaviour with the new Reaver core.
