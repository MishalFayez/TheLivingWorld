# REAVER-BLADEDANCER-003 — Reaver Refoundation: Blade Dancer

- **Status:** APPROVED DESIGN — IMPLEMENTATION REQUEST (owner Meshal + ChatGPT, pasted into the Claude Code chat on 2026-11-21)
- **Base branch:** `feature/reaver-freeflow-002` (`a79b4e1`)
- **Implementation branch:** `feature/reaver-bladedancer-003`
- **No PR, no merge.**

The specification below is stored verbatim as received.

---

# THE LIVING WORLD
# REAVER REFOUNDATION 003 — BLADE DANCER

## STATUS: APPROVED DESIGN — IMPLEMENTATION REQUEST

**Base branch:** `feature/reaver-freeflow-002`

**New branch:** `feature/reaver-bladedancer-003`

**Objective:** Completely replace Reaver's default combat identity with a distinct, skill-expressive action combat system.

Preserve Free Flow 002 as a selectable legacy comparison core.

Do not merge into main.

---

# 1. WHY WE ARE REDESIGNING REAVER

Two previous human playtests confirmed that Reaver remains significantly less satisfying than Vanguard and Worldweaver.

The problem is not insufficient DPS or lack of basic responsiveness.

The underlying combat identity is too generic.

Confirmed player feedback:

- Reaver feels too similar to Vanguard.
- Light and heavy attacks overlap with active skills.
- Some abilities do not justify occupying their own buttons.
- The class is too simple.
- Short repositioning skills do not feel rewarding.
- Dodge often breaks practical melee engagement.
- The player wants the mechanical depth found in Monster Hunter Dual Blades and Granblue Fantasy: Relink.
- The player dislikes rigid, repetitive Final Fantasy XIV-style rotations.

**We are not adding more skills to Free Flow. We are replacing its fundamental control and combat structure.**

---

# 2. CLASS IDENTITY

## Reaver — Blade Dancer

A pure physical melee DPS fighter specializing in:

1. Continuous close-range movement.
2. Positional sword attacks.
3. Switching between fluid offense and committed precision.
4. Staying engaged with enemies through evasive footwork.
5. Exploiting openings created through player skill.

No shield, blocking, healing, magic, teleportation, clones, or bleeding mechanics.

No additional resource meters.

No mandatory combo recipes.

Reaver should feel fundamentally different from Vanguard and Worldweaver within the first minute of gameplay.

---

# 3. TWO COMBAT MODES

## DANCE — Default mode

Fast mobile swordplay.

Dance allows attacks to incorporate directional footwork.

The player's movement input influences the actual attack behavior.

### Dance attack types

**Neutral Dance:**
- LMB without significant movement input.
- A rapid, controlled sword cut.
- Minimal displacement.
- Efficient attack speed.

**Forward Dance:**
- W + LMB.
- A connecting forward sword cut.
- Short controlled forward travel.
- Helps maintain melee engagement.

**Lateral Dance:**
- A/D + LMB.
- Short lateral movement incorporated into the sword attack.
- Changes the player's actual position relative to the enemy.
- Maintains offensive pressure.

These are movement-dependent attack variations, not fixed combo steps.

Repeated directions are always legal.

No illegal directional-transition restrictions.

No automatic critical bonuses simply for choosing a direction.

### Movement requirements

- Directional movement must be visible.
- Movement must respect collision.
- No teleporting.
- No excessive homing.
- No guaranteed attacks.
- Attacks must be responsive without becoming weightless.

**Initial tuning:**

- Neutral startup: 0.12s.
- Forward startup: 0.14s.
- Lateral startup: 0.15s.
- Dance recovery: 0.22–0.28s.
- Forward travel: up to 0.9m.
- Lateral travel: approximately 0.5–0.8m.

These are provisional tuning targets.

---

## EDGE — Precision mode

Holding RMB enters Edge.

Edge is NOT a charge attack by itself.

Edge changes how the character attacks and moves.

Holding RMB without attacking does not consume stamina.

### Edge controls

**RMB + tap LMB: Precision Cut**

A fast, relatively narrow, controlled sword strike.

- Useful against short enemy openings.
- Less movement than Dance.
- Longer effective reach than Neutral Dance.
- Moderate Poise damage.
- Lower commitment than the charged Edge attack.

**RMB + hold LMB: Committed Cut**

A powerful deliberate sword strike.

- Hold LMB to prepare the strike.
- Release LMB to execute.
- Stronger Poise damage.
- Noticeably higher commitment.
- Can be interrupted or punished.
- Cannot be freely dodge-cancelled during its committed impact phase.

The attack must visually and mechanically differ from Precision Cut.

**Input rule:**
The Edge attack is determined by the LMB press duration. Releasing RMB must never accidentally trigger another attack.

### Initial tuning

Precision Cut:
- Startup: approximately 0.18s after confirmation.
- Moderate stamina cost.
- Short recovery.

Committed Cut:
- Hold threshold: 0.35s.
- Maximum useful hold: 0.75s.
- Strong Poise damage.
- Significant committed recovery.

No unlimited charging advantage.

The final charge thresholds and damage coefficients can be provisional but must be documented.

---

# 4. MODE TRANSITIONS

Holding RMB enters Edge.

Releasing RMB requests a return to Dance.

The switch should be immediate when idle or during a legal transition window.

During committed attack frames, the switch must wait until the action can legally transition.

**Critical:** Holding or releasing RMB must not repeatedly restart animations, create input loops, or bypass attack commitment.

No mode-switch cooldown.

No automatic damage buff solely for alternating modes.

Switching modes is valuable because each changes the player's available actions.

---

# 5. COMBAT WEAVE — REAVER DODGE

Reaver must feel different from the default defensive dodge.

While in Dance:

**Directional side dodge:**
- Short evasive movement.
- Designed to stay close to an enemy.
- Can be followed by a directional Dance attack.
- Maintains practical melee engagement.

**Backward dodge:**
- Deliberate retreat.
- Travels farther than a side dodge.
- Does not automatically re-engage.

**Forward dodge:**
- Short committed evasive advance.
- Does not teleport through obstacles.

While in Edge:

- Dodge exits Edge after the legal cancel point.
- Performs a precision disengagement.
- Allows the player to re-enter Dance naturally.

Do not turn Edge into another Guard/Block system.

### Defensive behavior

Preserve valid defensive invulnerability behavior.

Do not make every movement attack invulnerable.

Movement-based attack evasion depends primarily on actual positioning.

**Initial distances:**

- Dance side dodge: approximately 1.3m.
- Dance forward dodge: approximately 1.5m.
- Backward disengagement: approximately 2.5m.

These require testing against enemy hitboxes.

Do not change Vanguard or Worldweaver dodge behavior.

---

# 6. THE UNIQUE MECHANIC — BLADE WEAVING

Blade Weaving integrates movement and attack selection.

It must provide gameplay depth without requiring memorized button sequences.

The system should distinguish between:

1. Maintaining position to deliver fast attacks.
2. Advancing to preserve contact.
3. Circling to change angle.
4. Switching into Edge to punish a committed enemy.
5. Disengaging when the enemy's attack cannot safely be avoided through positioning.

The player's mechanical challenge is choosing the correct movement and attack for the current enemy behavior.

**Do not implement hidden damage stacks or hidden automatic multipliers for merely changing attack directions.**

If movement does not change meaningful positioning, the system has failed.

---

# 7. SPECIAL TECHNIQUES

Only two special technique buttons are required initially.

Each changes functionality depending on the active mode.

## Q — FOOTWORK TECHNIQUE

### Dance + Q: Orbit Step

A deliberate lateral repositioning technique.

- Larger positional adjustment than Lateral Dance.
- Can circle around a locked target.
- Does not guarantee reaching the flank.
- Preserves collision.
- Includes a quick follow-up slash.
- No inherent invulnerability.

Purpose: actively create a new attacking angle.

### Edge + Q: Withdraw & Thrust

A controlled backward adjustment followed by a precision thrust.

- Creates a small amount of space.
- Punishes enemies that continue advancing.
- Requires accurate spacing.
- No invulnerability.
- The thrust can miss.

Purpose: control a dangerous close-range exchange without blocking.

These abilities must not be the same attack with different animations.

---

## E — OFFENSIVE TECHNIQUE

### Dance + E: Whirling Assault

A short, mobile series of physical slashes.

- Allows controlled directional movement.
- Useful for sustained pressure or multiple nearby targets.
- Moderate commitment.
- May be interrupted.
- Not automatically the highest single-target DPS option.

### Edge + E: Breaking Point

A narrow, committed precision technique focused on Poise disruption.

- Significantly different hitbox and timing from Whirling Assault.
- More effective against enemies recovering from attacks.
- Less flexible against mobile groups.
- Noticeable recovery if it misses.

Purpose: reward precise timing against enemy commitment.

**Important:** Breaking Point must not simply be a more expensive version of Committed Cut.

It must have a meaningful tactical identity: concentrated Poise disruption during genuine punish opportunities.

If this distinction cannot be implemented convincingly, flag it rather than producing two nearly identical skills.

---

# 8. STAMINA DESIGN

Stamina should reward sustained accurate swordplay without allowing thoughtless infinite attacks.

No new resource gauge.

Initial values:

| Action | Stamina |
|---|---:|
| Dance basic attack | 5 |
| Edge Precision Cut | 10 |
| Edge Committed Cut | 20 |
| Dance Orbit Step | 10 |
| Edge Withdraw & Thrust | 12 |
| Dance Whirling Assault | 18 |
| Edge Breaking Point | 22 |

Dodge cost remains compatible with the existing shared stamina economy.

Successful attacks may refund 1 stamina once per executed attack.

Multi-hit attacks must not repeatedly refund stamina.

Missed attacks refund nothing.

Do not reduce global stamina costs or regeneration for other classes.

The player should be able to maintain reasonable offensive pressure while retaining defensive options.

Compare attack uptime, dodge readiness, and stamina efficiency.

---

# 9. AUGMENTS

The core combat system must feel complete without Augments.

Do not automatically port every Free Flow 002 Augment.

For the first prototype, implement three example transformative Augments:

### Relentless Dance

After a successful Edge attack, the first returning Dance attack gains a distinct mobile follow-up animation.

It does not automatically gain bonus damage.

### Perfect Edge

Committed Cut becomes narrower and gains increased Poise effectiveness against a recovering target.

It sacrifices some hitbox forgiveness.

### Twin Tempest

Committed Cut transforms into a brief multi-hit technique with a strong final strike.

Total expected damage must remain competitive with the default version.

The transformation has longer exposure to interruption.

Augments must interact with the existing draft and mutation-slot systems.

Do not invent additional skills or a new talent tree.

Preserve existing Augments and save data.

Mark obsolete Augments incompatible with Blade Dancer instead of silently converting them.

Existing character migration must not happen without separate approval.

---

# 10. PROTOTYPE PROGRESSION

Level 1:
- Dance.
- Edge.
- Basic Blade Weaving.
- Combat Weave dodge.

Level 3:
- Q technique in both modes.

Level 5:
- E technique in both modes.

Levels 2 and 6:
- Existing attribute progression.

Levels 4, 8, and 10:
- Existing Augment drafts.

Level 7:
- Blade Dancer Mastery: unlock a more advanced transition between Dance and Edge.

**Level 7 mastery specification:**

After a successful Edge Precision Cut, the player can transition directly into one directional Dance attack during a slightly earlier recovery window.

No additional damage buff.

No mandatory sequence.

The transition must still respect attack commitment and stamina.

Do not design Level 11–30 now.

---

# 11. INPUT MAPPING

Required:

| Input | Behavior |
|---|---|
| LMB | Directional Dance attack |
| Hold RMB | Edge mode |
| RMB + tap LMB | Precision Cut |
| RMB + hold LMB | Committed Cut |
| Space | Mode-sensitive combat dodge |
| Q | Mode-sensitive footwork technique |
| E | Mode-sensitive offensive technique |

Do not require keys 1, 2, or 3 for Blade Dancer's base mechanics.

Do not modify the input mapping of Vanguard or Worldweaver.

Maintain compatibility with the existing shared input architecture.

Prevent accidental attacks when changing modes or releasing held inputs.

Controller mappings should remain technically possible, but do not redesign controller input architecture in this task.

---

# 12. ANIMATION REQUIREMENTS

Combat feel is a primary acceptance criterion.

Implement visibly different motions for:

- Neutral Dance.
- Forward Dance.
- Lateral Dance.
- Edge Precision Cut.
- Edge Committed Cut.
- Orbit Step.
- Withdraw & Thrust.
- Whirling Assault.
- Breaking Point.

Reuse procedural animation infrastructure where feasible.

Do not substitute the same slash animation for every attack.

Apply meaningful animation blending.

Avoid resetting the entire character pose to idle between every legal attack transition.

Keep hitstop and recovery readable.

Do not rewrite global animation architecture without explicitly reporting the blocker.

---

# 13. LEGACY COMPARISON

Preserve:

- Free Flow 002.
- Swordmaster.
- Sword Sense and other legacy comparison cores.

Blade Dancer becomes the prototype default Reaver core on the new feature branch.

The player must be able to compare Blade Dancer with Free Flow 002 without corrupting the existing save.

Non-default comparison sessions remain non-saving.

---

# 14. AUTOMATED TESTS

Add focused tests for:

1. All Dance directional attacks.
2. Movement distances and collision.
3. Edge hold/release behavior.
4. Tap versus held LMB.
5. Legal mode transitions.
6. No attack duplication from input release.
7. Commitment and cancel rules.
8. Side, forward, and backward Combat Weave.
9. Both Q techniques.
10. Both E techniques.
11. Meaningful mechanical differences between techniques.
12. Stamina usage and recovery.
13. Augment transformations.
14. Existing character compatibility.
15. Legacy core comparisons.
16. Vanguard and Worldweaver regressions.
17. Full project startup and save safety.

Include a small automated comparison:

- Reaver 002 versus Blade Dancer 003 DPS.
- Sustained stamina use.
- Average time between accepted player actions.
- Time spent unable to move.
- Actual positional displacement during attacks.

Passing automated tests does not constitute human gameplay approval.

---

# 15. DELIVERABLES

Create:

`feature/reaver-bladedancer-003`

Provide:

1. Implementation commit SHA.
2. Changed-file summary.
3. Arabic implementation report.
4. Arabic human playtest instructions.
5. Full automated test results.
6. Reaver 002 versus 003 comparison.
7. Known limitations.
8. Save compatibility report.
9. Clear Godot launch instructions.

Do not open a PR.

Do not merge into main.

Do not modify other classes.

Do not alter enemy attack tracking or camera systems.

Do not make independent gameplay-design changes.

If a technical problem requires changing an approved mechanic, document the exact problem and request a design review rather than inventing a replacement.

## FINAL ACCEPTANCE CRITERION

The Reaver must offer a distinctive, expressive combat experience even with no Augments equipped.

Its identity must come from sword movement, positional control, deliberate precision, and meaningful transitions between Dance and Edge.

**Do not measure success by how many attacks were implemented. Measure it by how differently the player can fight.**
