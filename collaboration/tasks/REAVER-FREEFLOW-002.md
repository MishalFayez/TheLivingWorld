# REAVER-FREEFLOW-002 — Human Playtest Feedback and Approved Design Direction

- **Status:** APPROVED (owner Meshal + ChatGPT, pasted into the Claude Code chat on 2026-11-21)
- **Base branch:** `feature/reaver-freeflow-001` (`1471719`)
- **Implementation branch:** `feature/reaver-freeflow-002`
- **No PR, no merge.**

The specification below is stored verbatim as received.

---

# THE LIVING WORLD — REAVER FREE FLOW 002
## Human Playtest Feedback and Approved Design Direction

The owner has completed an initial human playtest of Free Flow 001.

**Verdict: Not accepted as the final Reaver design.**

The class is more accessible, but its depth and combat satisfaction remain noticeably below Vanguard and Worldweaver.

## Confirmed human feedback

1. After Light → Light → Dodge → Heavy, the player frequently feels too far away from the enemy to continue naturally.
2. Reaver feels excessively simple.
3. The class lacks the offensive depth found in enjoyable action-RPG DPS characters.
4. Stamina depletes too quickly.
5. Its current mechanics do not produce the same satisfaction as Vanguard and Worldweaver.

The goal is NOT higher DPS.

The goal is a deeper, more expressive, more satisfying melee combat system.

## 1. Dodge Follow-up — Pursuit Slash

Implement a dedicated post-dodge light-attack follow-up.

- Available briefly after a completed dodge.
- Performs a short controlled approach toward a nearby target.
- Uses collision-safe movement.
- Does not teleport.
- Does not guarantee a hit.
- Does not increase invulnerability.
- Preserves the Free Flow continuation system.
- Uses a visually distinct attack motion.

Initial approach distance target: approximately 1.0–1.5 meters, limited by actual target distance and collision.

Do not automatically pull the player toward distant enemies.

## 2. Offensive Reads

Introduce distinct tactical rewards for three situations:

**A. Perfect Dodge**

A correctly timed Perfect Dodge enables a short-lived Counter Slash follow-up.

The counter should feel faster and more responsive than a normal attack, with a distinct movement or animation response.

It should remain a physical sword attack.

**B. Enemy Recovery**

A Heavy Cut connecting against an enemy during attack recovery gains increased Poise effectiveness.

This should reward reading enemy attacks, not simply spamming Heavy.

**C. Flanking**

Pivot Cut connecting from a meaningful flank grants access to a faster offensive follow-up.

The follow-up must be mechanically distinct, not just a damage multiplier.

These opportunities must not be mandatory for baseline combat.

Do not reinstate Swordmaster's directional-link restrictions or Sword Sense's old compulsory Opening system.

## 3. Reaver's Tempo

Introduce three internal combat states:

- Neutral
- In Rhythm
- Perfect Flow

These are NOT visible resources.

Do not add a gauge, stack counter, or permanent HUD element.

**Neutral:** ordinary Free Flow combat.

**In Rhythm:** earned through successful connected attack transitions. Improves responsiveness of an eligible follow-up action.

**Perfect Flow:** earned through a real Perfect Dodge or an approved tactical opportunity. Enables one enhanced follow-up.

These states must primarily affect available combat actions and transitions, not create unlimited passive damage scaling.

The player must receive clear and restrained animation, VFX, and audio feedback.

Avoid overlapping several hidden buffs that are impossible to distinguish.

## 4. Stamina Rework

Prototype these initial costs:

| Action | Stamina |
|---|---:|
| Light | 4 |
| Heavy | 12 |
| Pursuit Cut | 10 |
| Pivot Cut | 8 |
| Decisive Cut | 20 |

Successful connecting attacks restore 2 Stamina per executed attack, not per hit.

Multihit attacks cannot generate repeated Stamina refunds through individual hit events.

Missed attacks restore nothing.

Keep the existing global dodge cost and stamina regeneration unchanged initially.

Compare:
- Reaver's sustained attack uptime.
- Ability to retain enough stamina to dodge.
- DPS and stamina efficiency.
- Behavior under repeated misses.

Do not create infinite stamina loops.

## 5. Skill Interaction

The three core skills remain:

1. Pursuit Cut — approach and offensive engagement.
2. Pivot Cut — repositioning and flanking.
3. Decisive Cut — committed offensive strike.

Add context-sensitive follow-ups:

- Perfect Dodge → Counter Pursuit.
- Pivot flank hit → faster offensive continuation.
- Valid tactical opening → improved Heavy or Decisive execution.

Keep these interactions responsive and readable.

Do not increase the number of core active skill buttons.

Keep the three transformational Edge Augments compatible.

Do not redesign or extend the Augment system beyond what this change requires.

## 6. Animation Priority

Combat feel is critical.

Review whether the existing procedural attack animation resets are causing visibly stiff transitions.

Implement a narrowly scoped Reaver-only transition improvement if feasible within the current architecture.

Do not rewrite the shared animation framework or modify other classes.

Distinguish:
- movement responsiveness;
- attack cancel responsiveness;
- animation blending;
- target spacing and approach behavior.

Each issue should be measurable independently.

## 7. Perfect Dodge Accuracy

Review the difference between the full defensive invulnerability window and a genuinely precise dodge timing window.

Use a narrower offensive-reward window without reducing the existing defensive invulnerability.

Keep normal dodges useful and safe.

Only genuine well-timed dodges should activate the enhanced Counter Slash.

## 8. Implementation requirements

Create a new branch based on the latest `feature/reaver-freeflow-001`:

`feature/reaver-freeflow-002`

Before changing any code, inspect existing Free Flow implementations and identify reuse opportunities.

Do not erase working systems or character progress.

Do not change:
- Vanguard.
- Worldweaver.
- Enemy attack tracking.
- Camera systems.
- Shared dodge defensive behavior.
- Existing save formats.

Add focused automated tests covering:
- Post-dodge gap closing.
- Collision and maximum approach distance.
- Perfect Dodge reward timing.
- Enemy recovery punishes.
- Flank follow-ups.
- Tempo state transitions.
- Stamina recovery and refund limits.
- Existing Augment interactions.
- Save safety and regressions.

Provide an Arabic implementation report, DPS comparison, and an exact human playtest checklist.

Do not open a PR or merge.

## Critical design principle

**Reaver should reward decisions made while fighting an enemy, not simply reward players for pressing buttons in the correct order.**

The class should be accessible at Level 1 but require meaningful mastery.

Do not compensate for shallow gameplay with inflated damage.

If any requested mechanic requires an architecture-wide change, report the exact limitation instead of introducing unauthorized redesigns.
