# المهمة: REAVER-FREEFLOW-001 — إعادة بناء قتال Reaver الافتراضي (Free Flow)

الحالة: APPROVED
جهة الاعتماد: مشعل (صاحب المشروع) وChatGPT
مرجع الاعتماد: نص المواصفات الذي لصقه المستخدم في المحادثة بتاريخ 21 نوفمبر 2026، منقول أدناه حرفيًا.
الفرع الأساسي: `review/chatgpt-004` (`2a6b6ac`)، وفرع التنفيذ: `feature/reaver-freeflow-001`.

سجّل Claude هذا الملف لحفظ المواصفات كما وصلته فقط. Claude لم يعتمد المهمة. نقاط النقص في التصميم مسجلة في `collaboration/DESIGN_QUESTIONS.md` (قسم REAVER-FREEFLOW-001).

---

# THE LIVING WORLD — REAVER FREE FLOW REFOUNDATION
## Approved Gameplay Design — Implementation Specification

**Project:** The Living World
**Base branch:** `review/chatgpt-004` (`2a6b6ac`)
**Task:** Rebuild Reaver's default combat experience.

### 0. Authority and scope

This is an approved design specification from the project owner and ChatGPT.

The player has completed human playtesting of the current Swordmaster and found its overall combat experience unsatisfying, despite acceptable damage output.

The primary problems were:
- Heavy and unsatisfying combat flow.
- Unclear skill purposes.
- Skills that felt unnecessary.
- Unintuitive directional-link rules.
- No compelling reason to continue playing the class.

Do not attempt to repair this through damage buffs alone.

**The goal is a substantially redesigned Reaver combat experience.**

You are responsible for programming and technical execution only. Do not independently redesign mechanics, add skills, introduce new resources, or change other classes.

Create a separate implementation branch from `review/chatgpt-004`. Do not merge into `main`.

---

# 1. CORE IDENTITY

**Reaver: Free Flow**

A fast, fluid, precise physical melee damage dealer.

The combat fantasy combines:

1. Continuous offensive pressure.
2. Skillful dodging and repositioning.
3. Smooth transitions between attacks and abilities.
4. Heavy, decisive strikes with genuine impact.
5. Player-created attack sequences rather than mandatory combo recipes.

Inspiration:
- Monster Hunter: meaningful commitment and weight.
- League of Legends: immediate skill readability and strong ability identity.
- Action RPG combat: responsive movement and player-directed sequences.

Avoid rigid rotational gameplay.

Reaver must not overlap with:
- Vanguard's defensive Guard identity.
- Worldweaver's magic/healing/support identity.
- Ninja's future physical/magical hybrid identity.
- Berserker's future heavy, aggressive greatsword identity.

Reaver remains a pure physical DPS class.

No magic, clones, teleportation, bleeding systems, or additional resource bars.

---

# 2. FREE FLOW COMBAT SYSTEM

Replace the default Swordmaster Blade Lines/Continuity rules with a unified Free Flow system.

### 2.1 Free-form sequences

The player can freely transition between:

- Light attacks
- Heavy attacks
- Combat Dodge
- Pursuit Cut
- Pivot Cut
- Decisive Cut

No mandatory attack order.

No forbidden left-to-right transition combinations.

No "NO LINK" errors because a player selected the wrong attack sequence.

The system should reward intelligent timing, but never require memorizing predefined combos.

### 2.2 Flow continuation

Successful attacks and well-timed actions can keep an offensive sequence active.

A dodge does not automatically reset the sequence.

The player may:

Light → Light → Dodge → Light → Heavy

or:

Pursuit → Light → Pivot → Decisive

or:

Heavy → Dodge → Pursuit → Light.

These are examples, not special hardcoded combinations.

### 2.3 Initial timing values

Use the following as first-prototype tuning values:

- Normal continuation grace: 0.65 seconds.
- Grace after completing a dodge: 0.80 seconds.
- Input buffer: preserve the shared combat input-buffer system.
- Valid transitions may begin during the previous attack's recovery cancel window.
- No early cancellation of committed heavy attacks outside approved dodge windows.

A missed attack does not instantly reset continuity.

Repeated misses eventually expire the continuation window naturally.

Taking damage interrupts the current action according to existing combat rules.

### 2.4 Movement

Allow controlled movement during appropriate attacks.

Do not root the player unnecessarily during light attacks.

Preserve collision, stamina costs, and meaningful recovery.

No instant snapping or teleportation to targets.

Do not automatically steer attacks through large angles to guarantee a hit.

---

# 3. THE HIDDEN PRECISION OPPORTUNITY

There must be **no visible Flow meter, stacks, or combo counter**.

Instead, introduce a temporary internal state:

`precision_opportunity`

This is not a new resource. It is a short-lived combat opportunity.

### How it activates

A Precision Opportunity can be created by:

1. Connecting two consecutive attacks with valid timing.
2. Successfully performing a Perfect Dodge against an actual incoming attack.
3. Successfully connecting Pivot Cut from a meaningful flank angle.

Repeated missed attacks never generate this opportunity.

Pressing Dodge without actually avoiding an attack does not generate it.

### Initial rules

- One opportunity maximum; no stacking.
- Duration: 1.75 seconds.
- Another successful qualifying action may refresh its duration.
- Heavy Cut or Decisive Cut can consume the opportunity.
- The opportunity expires naturally if unused.
- A failed ordinary attack does not immediately remove it.
- A missed consuming Heavy/Decisive attack still consumes it.

Avoid exponential damage scaling.

### Feedback

When an opportunity activates:
- Brief, readable weapon glint.
- Subtle transition animation emphasis.
- Distinct but restrained placeholder audio cue.

When consumed:
- Stronger hit feedback.
- More noticeable impact animation.
- Distinct sound.

Do not display another permanent HUD widget.

Important: the player must recognize improved combat effectiveness without tracking an invisible numerical system.

---

# 4. BASIC ATTACKS

## Light Attack — Flow Strikes

Three visually distinct light-attack animations/cycles.

These animations are variations within a free-form system, NOT a mandatory three-hit combo.

Initial timing targets:

- Startup: 0.12–0.16 seconds.
- Active: 0.10 seconds.
- Recovery: 0.22–0.28 seconds.

Light attacks must feel noticeably more responsive than the current Swordmaster.

Permit movement during suitable portions of the attack.

Light attacks maintain offensive pressure but have less individual impact than heavy attacks.

Repeated light attacks remain functional, but efficient use of dodges, positioning, and abilities should outperform mindless repetition.

## Heavy Attack — Heavy Cut

Available at all times from Level 1.

Initial timing targets:

- Startup: 0.32 seconds.
- Active: 0.14 seconds.
- Recovery: 0.43 seconds.

A Heavy Cut is meaningful without any setup.

When consuming a Precision Opportunity:
- Increase heavy attack damage by approximately 20%.
- Increase Poise damage by approximately 35%.
- Add visibly stronger impact feedback.

These numbers are initial prototype values, not final balance targets.

No mandatory unlock condition for the basic Heavy Cut.

Avoid giving the heavy attack a long charge mechanic in the initial Free Flow prototype.

---

# 5. COMBAT DODGE

Dodge is part of Reaver's offensive identity.

Preserve existing stamina costs, collision behavior, and baseline invulnerability functionality unless changes are strictly necessary for continuity.

### Required behavior

- Dodge may preserve an active attack sequence.
- After the dodge, the player can continue with Light, Heavy, or a compatible skill.
- A properly timed Perfect Dodge can create a Precision Opportunity.
- A regular dodge maintains mobility but grants no offensive bonus by itself.
- Dodge must not become an unlimited attack-cancel exploit.

A dodge must not grant repeated opportunities from one attack event.

A Perfect Dodge must correspond to an actual enemy attack avoided during valid invulnerability timing.

Use available combat hooks wherever possible. If the current engine cannot reliably distinguish Perfect Dodge from an ordinary dodge, document the exact limitation rather than faking success.

---

# 6. THREE CORE ACTIVE SKILLS

Skills must be natural extensions of Free Flow combat.

Each skill requires a clear tactical purpose.

Use three main skills for the prototype.

## SKILL 1 — PURSUIT CUT

**Identity: Gap closer / offensive entry / pressure continuation.**

Purpose:
- Close a moderate distance.
- Initiate combat.
- Re-engage after an enemy moves away.
- Continue an existing attack sequence.

Initial prototype:

- Unlock: Level 3.
- Cooldown: 5 seconds.
- Moderate stamina cost.
- Short forward movement with collision detection.
- One controlled physical strike.
- Moderate damage and Poise.

The skill must not teleport or perfectly home onto moving enemies.

It should be useful because of the distance it covers, not because it has the highest DPS.

Allow natural transition into Light or Heavy after its recovery cancel window.

## SKILL 2 — PIVOT CUT

**Identity: Reposition / flank / maintain offensive flow.**

Purpose:
- Change attacking angle around an enemy.
- Avoid remaining directly in front of a shielded opponent.
- Continue pressure without resetting the sequence.
- Create a tactical advantage through positioning.

Initial prototype:

- Unlock: Level 5.
- Cooldown: 4 seconds.
- Moderate stamina cost.
- Short directional step plus a physical slash.
- Direction comes from movement input.
- Without directional input, use a conservative backward reposition.

This ability has NO invulnerability frames.

It must not replace Combat Dodge.

A successful attack from a meaningful flank angle (initial threshold: 60 degrees from the enemy's forward direction) may generate Precision Opportunity.

Allow continued attacks immediately after the legal recovery transition.

## SKILL 3 — DECISIVE CUT

**Identity: Powerful, precise offensive commitment.**

Purpose:
- Deliver a significant finishing-quality hit.
- Punish enemy recovery.
- Exploit an opportunity created by skilled play.

Initial prototype:

- Unlock: Level 7.
- Cooldown: 8 seconds.
- High stamina cost.
- Single-target-focused physical strike.
- Strong Poise damage.
- More commitment and recovery than normal Light attacks.

Available whenever cooldown and stamina allow.

Does NOT require Precision Opportunity to activate.

If Precision Opportunity exists, consume it for:
- Approximately +20% damage.
- Approximately +35% Poise damage.
- Enhanced impact feedback.

Do not automatically stagger bosses or guarantee critical strikes.

The base skill must be valuable even without an opportunity.

The skill should not feel like a slow Berserker attack.

---

# 7. AUGMENT-DRIVEN COMBAT TRANSFORMATIONS

Augments are where combat styles branch.

The base Reaver must remain fully functional and enjoyable without them.

Create three transformational Augments for Decisive Cut.

These three are mutually exclusive on the same character during one run.

Other compatible Augments may modify the selected transformation, but must not override its identity.

## A. PRECISION EDGE

Transforms Decisive Cut into a single narrow, high-impact thrust/slash.

Properties:
- Narrower hitbox.
- Improved single-target impact.
- Higher Poise damage.
- Greater reward for attacking from a flank or during enemy recovery.

Weakness:
- Less effective against groups.
- Requires accurate positioning.

Do not give guaranteed critical hits.

## B. TEMPEST EDGE

Transforms Decisive Cut into a brief multi-hit sequence with a strong final strike.

Properties:
- Several rapid physical hits.
- Final hit carries the largest portion of damage and impact.
- Can connect against nearby enemies within a controlled arc.

Weakness:
- Longer total animation commitment.
- More vulnerable to interruption.
- Full damage requires landing the sequence.

Keep total expected single-target damage competitive with the other transformations, not automatically superior.

## C. MOMENTUM EDGE

Transforms Decisive Cut into a moving offensive strike.

Properties:
- Controlled directional movement.
- Damage and impact linked to successful positioning.
- Synergy with Perfect Dodge and Pivot Cut.
- Better pursuit capability than Precision Edge.

Weakness:
- Requires positional awareness.
- A poorly aimed movement can miss.
- Must respect world collision.

No teleportation.

### Augment acquisition

Integrate these transformations into the existing Augment draft infrastructure.

Do not introduce a separate talent tree or skill specialization screen.

Maintain the existing global limits on active mutations and Augment selections.

If the current draft system requires compatibility rules, implement mutual exclusion only for these three transformations.

Existing unrelated Augments should remain compatible wherever technically sensible.

Any existing Swordmaster Augment that depends on removed Blade Lines or obsolete directional-link rules should not be silently reinterpreted. Mark it as incompatible with Free Flow pending an approved migration design.

---

# 8. LEVEL 1–10 PROTOTYPE PROGRESSION

Use the following progression for the new default Free Flow prototype:

| Level | Unlock |
|---|---|
| 1 | Flow Strikes, Heavy Cut, Combat Dodge, Free Flow core |
| 2 | Existing attribute progression |
| 3 | Pursuit Cut |
| 4 | Existing Augment draft |
| 5 | Pivot Cut |
| 6 | Existing attribute progression |
| 7 | Decisive Cut |
| 8 | Existing Advanced Augment draft |
| 9 | Free Flow Mastery: extend Precision Opportunity duration by 0.25 seconds |
| 10 | Existing Augment draft |

Do not design Levels 11–30 in this implementation.

Retain existing level, XP, and attribute systems.

The three transformational Augments must be testable through the existing draft/debug testing facilities.

Do not guarantee a specific transformational Augment from ordinary random drafts.

### Existing character saves

The project already contains saved Reaver progression.

Preserve existing characters, levels, attributes, equipment, and inventory.

Do not reset the player's Reaver when switching to the new default core.

Handle obsolete Swordmaster progression/loadout references safely.

The current Level 2 Reaver must remain playable without save corruption.

---

# 9. COMBAT FEEL REQUIREMENTS

This is the highest-priority implementation objective.

**Target feel: fast and controlled, but not weightless.**

Required:
- Immediate readable response to player input.
- Smooth transitions between valid attacks.
- No unnecessary pauses between standard attacks.
- Proper hitstop on connecting strikes.
- Distinct visual weight for Heavy and Decisive Cut.
- Readable movement direction.
- Predictable dodge behavior.
- Stable camera and lock-on.
- No hidden directional-combo restrictions.

Use the existing procedural animation framework initially.

If transitions cannot feel smooth with existing animation infrastructure, identify exactly what animation blending improvements are technically necessary.

Do not redesign the entire animation architecture without approval.

Temporary audio and visual feedback may be added for testing only if clearly isolated and replaceable. Do not add permanent art-direction decisions.

---

# 10. BALANCE GUARDRAILS

Reaver remains the primary pure physical damage class.

It should generally achieve higher sustained offensive output than Vanguard and Worldweaver in equivalent solo damage conditions.

However:

- Do not compensate for bad gameplay feel through large damage increases.
- Do not grant tank-level survivability.
- Do not introduce healing or magical abilities.
- Do not make dodge cost-free.
- Do not make all attacks freely cancelable.
- Do not guarantee critical hits.
- Do not make one Decisive Cut transformation dominate all situations.

Compare prototype DPS against the previous Swordmaster baseline.

Record the differences.

Treat numerical tuning as provisional.

The primary acceptance criterion is human combat feel, not benchmark superiority.

---

# 11. REQUIRED TESTING

Add automated tests for:

**Free Flow**
- Arbitrary legal attack transitions.
- No forbidden directional combinations.
- Recovery-window transitions.
- Buffered input handling.
- Continuation after dodge.
- Sequence expiration.

**Precision Opportunity**
- Two connecting attacks can create an opportunity.
- Correctly timed Perfect Dodge can create an opportunity.
- Ordinary dodge does not create one.
- Missed attacks cannot generate free bonuses.
- Opportunity expires correctly.
- Opportunity is consumed correctly.
- No accidental stacking or duplicated rewards.

**Skills**
- All three skills activate correctly.
- Cooldowns work.
- Stamina costs work.
- Movement respects collision.
- Pivot Cut does not grant invulnerability.
- Decisive Cut works with and without opportunity.

**Augments**
- Each transformation changes the actual attack behavior.
- Transformations are mutually exclusive.
- Normal compatible Augments still function.
- Existing character saves load safely.

**Regression**
- Vanguard unchanged.
- Worldweaver unchanged.
- Enemy AI unchanged.
- Camera unchanged.
- Save system unchanged except any strictly necessary compatibility adjustment.
- Full existing test suite remains green.

Add a simple human comparison mode so the owner can switch between old Swordmaster and new Free Flow for evaluation without corrupting saved characters.

Legacy Sword Sense and Swordmaster must remain accessible for technical comparison. They must not silently replace Free Flow during normal play.

---

# 12. DELIVERY REQUIREMENTS

Implement on a new branch:

`feature/reaver-freeflow-001`

Do not merge.

Provide:

1. Exact Git commit SHA.
2. Files changed.
3. Description of the new combat architecture.
4. Input mapping and skill unlocks.
5. Augment compatibility report.
6. Automated test results.
7. DPS comparison against the old Swordmaster.
8. Known technical limitations.
9. Clear instructions to test the new Reaver in Godot.
10. A short Arabic implementation report.

Ensure screenshot/test utilities never overwrite the real player's save.

Do not alter Vanguard, Worldweaver, enemy attack tracking, or other previously approved mechanics as part of this Reaver implementation.

**Do not implement the separately approved enemy attack commitment redesign yet. It will be handled as its own change.**

If an existing system prevents an exact implementation, document the blocker and use the closest technically faithful approach only where it does not change the approved mechanics. Otherwise leave the affected part incomplete and flag it for ChatGPT review.

No independent game-design decisions.

No merge into `main`.

**Final goal:** A Reaver that feels satisfying at Level 1 and becomes more expressive with skill and Augments—not one that requires the player to understand complex hidden rules before combat becomes enjoyable.
