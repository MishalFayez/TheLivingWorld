# LEVEL10-FOUNDATION-005 — Level 1–10 Combat & Augment Foundation

- **Status:** APPROVED DESIGN — IMPLEMENTATION REQUEST (owner Meshal + ChatGPT, Design Package 005, pasted into the Claude Code chat on 2026-11-21)
- **Base branch:** `feature/reaver-bladedancer-003` (`9bad1ed`)
- **Implementation branch:** `feature/level10-combat-augments-005`
- **No PR, no merge.** Staged milestones A–E, each committed separately.

The specification below is stored verbatim as received.

---

THE LIVING WORLD — LEVEL 1–10 COMBAT & AUGMENT FOUNDATION
Unified Implementation Specification — Design Package 005
Project: The Living World
Repository: `MishalFayez/TheLivingWorld`
Starting point: Latest available `feature/reaver-bladedancer-003`, including subsequent commits only after verifying their contents.
New branch: `feature/level10-combat-augments-005`
Authority: Owner + ChatGPT design. Claude implements, tests, measures, documents and reports blockers. Claude must not independently redesign class identities, create unapproved mechanics, or merge changes.
Goal: Deliver a complete, playable, understandable, mechanically diverse Level 1–10 experience across Vanguard, Worldweaver and Reaver.
This is one unified assignment with staged implementation and testing. Do not attempt to implement everything in one unreviewed commit.
Do not open a PR or merge to `main`.

PART 0 — REQUIRED BASELINE AUDIT
Before editing code:

1. Fetch and inspect the latest branches and commits.
2. Verify whether Blade Dancer 004 mobility improvements have actually been implemented. The owner has NOT sent the previous 004 prompt, so do not assume they exist.
3. Review all three classes' current implementation and Level 1–10 progression.
4. Inspect:
   * `scripts/combat/stat_block.gd`
   * `scripts/data/balance_config.gd`
   * `scripts/progression/stat_preview.gd`
   * `scripts/progression/augment_db.gd`
   * `scripts/data/augment_data.gd`
   * `scripts/progression/class_progress.gd`
   * `scripts/heroes/mage_elementalist.gd`
   * `scripts/heroes/reaver_bladedancer.gd`
   * Vanguard's existing Guard/Resolve implementation
   * Damage resolution and Poise/Stagger implementation
   * Skills, Spellbook, Augment Draft and HUD interfaces
   * Relevant progression resources and tests.
5. Confirm the actual stat-scaling and damage formulas. Never invent a tooltip formula that differs from combat.
6. Check existing saves and uncommitted files.
7. Preserve all approved class mechanics and old debug comparison cores.

Write a baseline audit to:
`collaboration/results/LEVEL10-FOUNDATION-005-BASELINE.md`
Do not unnecessarily stop implementation for routine technical questions. If a design conflict cannot be resolved without changing the approved gameplay specification, report it.

PART 1 — NON-NEGOTIABLE CLASS IDENTITIES
Vanguard
Always a Tank with meaningful team protection.
Two build directions:
Bulwark
* Endurance.
* Guard pressure.
* Position control.
* Team protection through defensive positioning.

Counterguard
* Perfect Guard.
* Timed counterattacks.
* Redirection of enemy pressure.
* Protection through accurate defensive reactions.

Both retain their existing core Guard, protection, threat and defensive functionality.
Do not turn Counterguard into a pure DPS class.

Worldweaver
Always a hybrid Magic DPS + Healer + Support.
Healing must remain accessible and meaningful in every build.
Two build directions:
Elemental Fusion
* Element combinations.
* Interaction with elemental effects and world formations.
* Target-dependent offensive, healing and support applications.

Arcane Weaving
* Spell timing.
* Spell transitions.
* Target routing.
* Offensive/healing spell interactions.

Arcane Weaving is a build direction inside the approved Worldweaver core. Do not resurrect the rejected legacy Mage core.
Both paths retain full baseline access to healing and support.

Reaver
Always pure Physical DPS.
Base combat remains Blade Dancer.
Two build directions:
Dance Mastery
* Mobile swordplay.
* Circling enemies.
* Directional attacks.
* Footwork and continuous engagement.

Edge Mastery
* Precision.
* Charged sword strikes.
* Recovery punishes.
* Poise disruption.
* Meaningful attack commitment.

Neither path removes Dance or Edge from the base kit.
All classes must be fully playable without Augments.

PART 2 — REAVER BLADE DANCER 004 REFINEMENT
Implement the already approved playtest-feedback refinement before developing advanced Augments.
The player strongly approved Blade Dancer 003's overall design.
Do not redesign Dance/Edge.

2.1 Forward Dance
Current measured travel: approximately 0.9m.
Initial target: approximately 1.3m.
* Increase meaningful forward travel.
* Reduce unnecessary displacement when already in effective weapon range.
* Preserve collision and interrupt rules.
* Do not teleport or guarantee contact.
* Preserve damage initially.
Tune within approximately 1.1–1.4m if actual play geometry supports it.

2.2 Lateral Dance
Current movement: approximately 0.69m.
Initial target: approximately 1.0m.
With a locked target, implement shallow curved or tangential movement that better maintains target radius.
* No orbit snapping.
* No automatic flank bonus.
* Collision must remain real.
* Without lock-on, movement remains predictable.
* Repeated lateral attacks should not accidentally drift outside melee range.
Tune actual movement and duration together.

2.3 Combat Weave
Current dodge distances are perceived as too short.
Initial targets:
* Side: 2.0m.
* Forward: 2.0m.
* Backward: 2.7m.
These are tuning targets, NOT mandatory exact results.
Maintain existing defensive i-frame timing and stamina cost initially.
Make Combat Weave a visually distinctive defensive action, separate from offensive Dance footwork.
Do not add i-frames to normal movement attacks.
Improve transitions back into Dance without bypassing attack commitment.

2.4 Orbit Step
Current orbit approximately 40 degrees.
Initial target approximately 70–80 degrees.
The owner suggested 80 degrees but explicitly authorized reasonable tuning for better game feel.
* Adjust duration as needed.
* Preserve sensible tangential speed.
* Maintain reasonable distance from target.
* No snapping, teleportation or guaranteed flanking.
* No invulnerability.
* Collision-safe.
* Measure achieved angle and travel distance at several engagement radii.

2.5 Whirling Assault
Preserve:
* Four physical hits.
* Multi-target utility.
* Mobile offensive identity.
Improve:
* Sword animation continuity.
* Directional control.
* Weight and sound of consecutive hits.
* Ability to remain engaged with targets.
Do not just increase damage or hit count.

2.6 Withdraw & Thrust
Current retreat approximately 0.8m.
Initial retreat target approximately 1.5m.
* Make backward movement readable.
* Verify the existing thrust range still provides meaningful spacing gameplay.
* Do not extend its hitbox simply to guarantee impact.
* No invulnerability.

2.7 Committed Cut full-charge feedback
Current maximum effective charge: 0.75s.
Preserve its existing gameplay.
Add:
* A restrained charging visual progression.
* A distinct full-charge sword highlight.
* One short full-charge audio cue.
* Clear maximum-charge pose.
* Correct cancellation of charge feedback.
Cue fires once per charge.
No extra damage beyond existing charge maximum.

2.8 Reaver acceptance tests
Measure movement, collision, angle, hit uptime, DPS, defensive opportunity and cancel windows.
The objective is more satisfying mobility, not increased DPS.

PART 3 — WORLDWEAVER ELEMENT SELECTION UX
The approved Worldweaver currently uses:
* LMB / RMB / 1 for three equipped charged spells.
* 3 for utility.
* F for emergency healing.
* E for Arcane Sanctum.
* Existing heal-target controls.
* Spellbook for loadout management.
Do not break these controls.

3.1 Two quick-selection controls
Create two configurable quick-selection inputs:
Primary Spell Wheel
* Changes the spell assigned to LMB.
Secondary Spell Wheel
* Changes the spell assigned to RMB.
Use conflict-free default keys after inspecting existing bindings. Do not steal target switching, charging, healing, or any currently required key.
Both controls must be rebindable.

3.2 Hold to open a wheel
Holding the relevant key opens a compact radial selector.
The wheel lists only unlocked usable spells.
Visually group spells by element:
* Fire
* Life
* Frost
* Storm
* Stone
If multiple spells belong to an element, distinguish their individual icons and names within that element group. The player must choose the actual spell, not an ambiguous element that silently selects the wrong spell.
Unlearned spells must not be selectable.

3.3 Release to confirm
* Move the mouse toward a valid spell.
* Release the wheel key to select.
* Escape or invalid selection cancels.
* Do not cast automatically.
* Do not consume mana.
* Do not interrupt a currently charging spell.
* If switching during charge is not safely supported, defer selection until charge ends without losing the request.

3.4 Tap to swap
Quick tap swaps between the current and previous valid spell assigned to that slot.
If the previous spell is no longer valid, do nothing and provide subtle feedback.
The wheel must not become mandatory before every spell.

3.5 Preserve healing identity
All Worldweaver builds retain:
* Direct healing.
* Emergency healing.
* Existing healing target selection.
* Existing support abilities.
* Offensive elemental spellcasting.
Never make healing available only to Elemental Fusion or Arcane Weaving.

3.6 Scope
The third charged spell slot and utility slot remain available.
Preserve existing Spellbook and saved loadouts.
Do not alter the existing spell fusion mechanics unless implementing an explicitly defined Augment below.

PART 4 — PATH SYSTEM AND LEVEL 1–10 PROGRESSION
4.1 Path model
Each class has two build paths.
These are Augment-oriented specializations, NOT replacement class kits.
Path selection must not remove baseline skills.
An eligible path-defining Augment establishes the build direction.
A player can still use common Augments.
Mutually exclusive path-defining Augments cannot be owned simultaneously in the active build.

4.2 Level progression
Respect current class progression and the configured level cap of 10.
Do not silently add drafts or free stat points.
Target experience:
Level 1
* All basic class mechanics are functional.
* No Augment required for baseline fun.
Levels 2–3
* Existing class progression and key skills.
* Clear introduction to class identity.
Level 4
* First meaningful Augment decision.
* Present a path-defining option for EACH of the two paths whenever technically eligible.
* Third choice should be a strong class-common alternative.
Level 5
* Existing class ability development remains accessible.
Levels 6–7
* Existing progression.
* Build interactions begin to matter.
* Reaver's Lv7 Blade Dancer Mastery remains intact.
Level 8
* Advanced draft.
* Include synergy and transformation opportunities.
* If no path has been selected, preserve a valid route to establish one.
Level 9
* Existing class milestones preserved.
Level 10
* A meaningful completed early-game build.
* Third Augment decision.
* Every path must support at least one useful three-Augment combination.
* No dead drafts.
The actual number of drafts must be validated against each class's progression track. Do not confuse global draft configuration with class-specific milestones.

4.3 Three equipped Augments
Keep the existing three-active-Augment concept.
Preserve current mutation and stacking compatibility.
If a historical save has incompatible Augments, preserve ownership and prevent destructive conversion.
Do not grant extra free drafts to existing saves without a separately defined migration.
For testing, use isolated fresh Level 1 fixtures.

PART 5 — AUGMENT QUALITY RULES
Implement a curated, first-10-level pool of 60 meaningful Augments.
This specification defines:
* 6 global Augments.
* 18 class-common Augments: 6 for each class.
* 36 path Augments: 6 for each of six paths.
Preserve existing working Augments and mark incompatible legacy options appropriately.
The larger 102-concept catalog discussed in design is future backlog, NOT a requirement to implement 102 simultaneously.
Do not fabricate another 42 entries to meet a number.
Every Augment must:
1. Have a meaningful Level 1–10 use case.
2. Produce an observable gameplay effect.
3. Remain useful without a specific partner.
4. Gain an additional interaction when a compatible partner is equipped, where specified.
5. Have a clear cap, cooldown or commitment tradeoff when necessary.
6. Avoid creating unavoidable damage loops.
7. Avoid making bosses permanently staggered.
8. Display honest percentage values.
9. Display correct stat scaling.
10. Be eligible only when its mechanics are accessible.
11. Have automated functional tests.
12. Show correct before/after information.

Numerical conventions
All values below are initial design targets.
* `+20%` multiplicative improvement means ×1.20 unless explicitly marked otherwise.
* Additive percentage-point changes must be labeled `pp`.
* Percentage changes from different sources should not compound unless explicitly approved.
* A cooldown reduction cannot reduce a cooldown below a reasonable ability-specific floor.
* Multi-hit effects apply their intended total bonus once, not independently per hit.
* Healing cannot recursively trigger itself.
* Extra hits do not generate additional resource refunds unless specified.
* If a suggested numerical value breaks balance, tune within ±25% relative to the proposed effect and document the adjustment.
* Do not replace a mechanical transformation with a generic stat buff simply because implementation is easier.
* If the effect itself is not feasible, report it as a blocker rather than inventing a substitute.
Balance target: no single Augment should make its intended alternative categorically inferior in every relevant scenario.

PART 6 — THE 60 AUGMENTS
Definitions below are complete design targets. Exact implementation should reuse existing events and effect systems when possible.
Use data-driven configuration for all tunable values.

6A. GLOBAL — SIX AUGMENTS
G01 — Second Wind — Advanced
After avoiding a real enemy attack using defensive dodge, the next offensive action within 3s costs 25% less stamina.
Internal cooldown: 6s.
For Mage, apply a 15% mana reduction to the next offensive spell instead.
Do not trigger on empty dodges.
G02 — Measured Recovery — Standard
Hitting an enemy during its real recovery phase restores:
* 5 stamina for Vanguard/Reaver.
* 4 mana for Worldweaver.
Internal cooldown: 5s.
G03 — Echoing Impact — Exotic
After three separate connecting offensive actions against the same target, the third creates a delayed secondary physical/magic impact dealing 25% of the triggering action's eligible direct damage.
Maximum once per 6s per attacker.
Secondary impacts cannot trigger this Augment or additional Augment hit events.
No extra resource refund.
G04 — Calculated Risk — Exotic
Committed actions gain +20% eligible direct impact or effect power, but failed committed actions increase their recovery duration by 20%.
Applicable actions must be explicitly tagged; never apply indiscriminately to every attack.
G05 — Near Miss — Advanced
Avoid an enemy attack through real movement without dodge i-frames.
Gain +15% movement speed for 2s.
Cooldown 8s.
Must detect a credible attack near-miss, not arbitrary movement.
If reliable detection is unavailable, omit from the active pool and report why. Do not substitute dodge detection.
G06 — Resolute Spirit — Standard
After recovering from Stagger, gain 20% Poise damage resistance for 3s.
Cooldown 10s.
Does not make the player immune to interruption.

6B. VANGUARD COMMON — SIX
V-C01 — Guardian's Reach — Advanced
Increase valid interception range by 20%.
Interception resource cost increases by 10%.
V-C02 — Steel Foundation — Standard
After successful Guard, reduce knockback from the next received hit by 30% within 3s.
V-C03 — Shared Aegis — Advanced
After an actual successful defensive interception, grant the protected ally a shield worth 6% of the Vanguard's maximum HP.
Shield lasts 4s.
Cooldown 8s.
Shield uses correct existing defensive/effect scaling where applicable.
V-C04 — Unyielding Footing — Standard
Increase movement speed during Guard by 15% relative to current Guard movement speed.
Do not allow unrestricted sprinting.
V-C05 — Defender's Oath — Exotic
Intercept up to 25% of damage received by one nearby protected ally within the existing interception mechanism.
The redirected damage is genuinely taken by Vanguard and cannot recursively redirect.
Cooldown 8s.
Never bypass existing distance and line-of-sight requirements.
V-C06 — Last Barrier — Advanced
Successful Guard below 35% HP grants a shield equal to 8% maximum HP.
Cooldown 20s.
Does not trigger from passive damage reduction.

6C. BULWARK — SIX
V-B01 — Living Fortress — Exotic / Path Anchor
Move forward during Guard at up to 60% normal movement speed.
Guard resource recovery while advancing is reduced by 30%.
All normal Guard directional and break conditions remain.
V-B02 — Shielded Advance — Advanced
Transform Shield Rush into a shorter defensive advance:
* Travel distance approximately 80% of normal.
* During the approved frontal protection phase, +15 percentage points to its specific defensive reduction, capped below complete immunity.
Retain its interception identity.
V-B03 — Bastion Pulse — Exotic
Perfect Guard emits a 3m defensive pulse reducing nearby enemies' movement speed by 25% for 2s.
Internal cooldown 8s.
Bosses use reduced slow effectiveness.
No automatic Stun.
V-B04 — Heavy Anchor — Standard
While guarding, gain +20% Poise damage resistance.
Movement while guarding is reduced an additional 10%.
V-B05 — Fortress Breaker — Advanced
After successfully blocking a heavy enemy attack, the next shield-based strike within 4s deals +35% Poise damage.
Cooldown 6s.
Do not increase raw damage.
V-B06 — Sheltering Counter — Advanced
A successful counterattack immediately following protection of an ally grants that ally a shield equal to 5% Vanguard maximum HP for 4s.
Cooldown 8s.
Bulwark synergy:
* Living Fortress + Bastion Pulse: pulse may originate from the defensive advance end position; radius +15%, once per cooldown.
* Heavy Anchor + Fortress Breaker: successful heavy guard increases the Poise bonus from 35% to 45%; never stacks repeatedly.
* Shared Aegis + Sheltering Counter: shields refresh duration, but their amounts do not stack without a cap.

6D. COUNTERGUARD — SIX
V-K01 — Aegis Reversal — Exotic / Path Anchor
Perfect Guard transforms the next eligible Heavy Attack within 3s into a special counter animation.
+30% Poise damage.
-10% reach relative to ordinary heavy attack.
No automatic crit.
V-K02 — Precise Defense — Standard
After Perfect Guard, the next Perfect Guard opportunity within 4s receives +0.03s to its timing window.
Single use, cooldown 10s.
Do not enlarge the normal Guard window.
V-K03 — Redirected Force — Exotic
Against a correctly Perfect-Guarded charging attack, gain an optional 0.8m controlled lateral reposition before counterattacking.
No teleport or i-frames beyond the original defensive event.
Cooldown 10s.
V-K04 — Retaliation Window — Advanced
After a connecting counterattack, reduce the transition delay into Guard by 20%.
Do not allow Guard during committed attack hit frames.
V-K05 — Judgment Echo — Exotic
A connecting counter opens a 2s window for one distinct follow-up strike.
Follow-up direct damage = 65% of normal relevant strike.
Its recovery is 20% longer.
Cooldown 10s.
V-K06 — Guardian's Retort — Advanced
When a counter follows a successful ally interception, 20% of the counter's eligible direct damage value instead contributes to a capped ally shield.
No direct healing from damage.
Cooldown 8s.
Counterguard synergy:
* Aegis Reversal + Judgment Echo: transformed counter unlocks the alternate follow-up animation, not a second automatic hit.
* Redirected Force + Retaliation Window: positional counter allows slightly earlier Guard return, respecting all cancel rules.
* Guardian's Reach + Guardian's Retort: only improves successful interception opportunity; does not multiply shield generation per ally.

6E. WORLDWEAVER COMMON — SIX
M-C01 — Merciful Conduit — Exotic
Once every 8s, a successful direct offensive spell contributes healing equal to 12% of eligible effective damage to the most injured ally in range.
Cap per trigger: 8% of that ally's maximum HP.
Healing cannot trigger additional damage or healing events recursively.
Does not replace baseline healing abilities.
M-C02 — Gentle Current — Standard
Effective direct healing gives the target +10% movement speed for 2.5s.
Cooldown 5s per target.
Overhealing alone does not trigger the effect.
M-C03 — Elemental Memory — Advanced
Returning to an element used within the previous 6s reduces the mana cost of the first eligible spell by 12%.
Cooldown 6s.
Does not trigger on repeated spam of the same element.
M-C04 — Benevolent Casting — Standard
Healing a valid ally below 40% HP reduces the mana cost of your next support spell by 15%.
Expiry 5s. Cooldown 8s.
M-C05 — Dual Invocation — Exotic
A successful direct healing spell opens a 3s window for one offensive spell with 15% shorter preparation time.
A successful offensive spell similarly opens a 3s window for one direct healing spell with 15% shorter preparation.
Cooldown 6s per direction.
Cannot trigger itself recursively.
M-C06 — Woven Protection — Advanced
Up to 20% of actual overhealing becomes a shield.
Cap: 6% of recipient maximum HP.
Duration 4s.
Shield does not trigger further healing effects.

6F. ELEMENTAL FUSION — SIX
Preserve actual approved elemental spells, formations, and interactions.
Do not invent a completely new elemental system.
M-F01 — Elemental Crossroads — Exotic / Path Anchor
Select one existing, implemented element interaction.
Enhance its tactical outcome depending on whether it affects an enemy or ally.
Provisional bonus:
* +20% relevant interaction effect magnitude.
* No increase to unrelated spell damage.
* Existing interaction target and formation limits remain.
Provide a clear UI selection of the enhanced interaction.
M-F02 — Lingering Essence — Standard
Extend one existing valid elemental status or interaction-enabling effect by 20%, capped at +1.5s.
Does not extend hard crowd-control effects without their own cap.
M-F03 — Thermal Fracture — Advanced
An existing valid Fire/Frost interaction adds +25% Poise effect against ordinary enemies.
Against bosses, only +10% Poise effectiveness.
Cooldown 6s per target.
M-F04 — Healing Ember — Advanced
An approved Fire-based ally support effect additionally grants +12% physical weapon damage for 4s.
One buff per recipient.
Does not stack with itself.
Must be accessible through an actual existing support interaction; otherwise report the missing design prerequisite rather than inventing a new Fire healing skill.
M-F05 — Living Confluence — Exotic
After a valid elemental interaction, the next different-element spell within 4s gains a small situational secondary effect:
* Enemy-targeted: secondary impact worth 20% of the spell's eligible direct damage.
* Ally-targeted: additional direct healing worth 15% of eligible direct heal value.
Cooldown 10s.
Secondary effects do not chain.
M-F06 — Purifying Confluence — Advanced
A qualifying existing ally-targeted elemental interaction removes one eligible minor negative status.
Cooldown 12s per ally.
Boss debuffs and non-cleansable statuses cannot be removed.
Fusion synergy:
* Crossroads + Thermal Fracture: improved tactical Poise payoff, maximum combined bonus capped at 40% over base for ordinary enemies.
* Crossroads + Living Confluence: the chosen interaction changes the follow-up's visual behavior, without doubling the follow-up damage.
* Woven Protection + Purifying Confluence: cleansing an eligible effect may refresh an existing shield's duration once, not its amount.

6G. ARCANE WEAVING — SIX
This is a build direction of the approved Worldweaver class, not the rejected old Arcane Weave core.
M-A01 — Spell Threading — Exotic / Path Anchor
After a successful spell release, casting a different eligible spell within 3s reduces its minimum charge requirement by 20%.
Full-charge time reduction capped at 10%.
Cooldown 5s.
Never make expensive spells instant or free.
M-A02 — Arcane Relay — Advanced
After applying a direct support spell to an ally, your next eligible targeted spell within 4s may originate from that ally's position if:
* Both caster and ally are within valid range.
* Line of sight remains valid.
* Target remains eligible.
Spell retains normal mana cost and targeting restrictions.
Cooldown 10s.
M-A03 — Rewoven Spell — Advanced
A successful single-target offensive spell can create one secondary hit on another valid nearby enemy.
Secondary hit deals 25% of eligible original direct damage.
Cooldown 8s.
Cannot chain or trigger itself.
M-A04 — Swift Invocation — Standard
Switching to a different equipped spell using the new spell wheel gives the next spell a 10% shorter preparation time.
Cooldown 6s.
No benefit for rapidly swapping without casting.
M-A05 — Sympathetic Link — Exotic
Direct support on a valid ally creates a temporary connection to one nearby enemy for 4s.
The next direct healing spell on that ally deals secondary magic damage to the linked enemy equal to 15% of effective healing.
Cap the secondary impact.
Cooldown 12s.
No recursive triggers.
M-A06 — Emergency Thread — Advanced
Successfully healing an ally below 35% HP preserves the previously selected offensive spell for quick restoration to its former slot.
The next valid offensive cast within 4s has 15% shorter recovery.
Cooldown 10s.
Arcane synergy:
* Spell Threading + Dual Invocation: shorter preparation, but combined reduction capped at 25%.
* Arcane Relay + Sympathetic Link: the link may originate from the supported ally, but no additional enemy targets.
* Swift Invocation + Emergency Thread: restoring the prior spell counts as a legitimate spell switch, subject to the shared cooldown.

6H. REAVER COMMON — SIX
R-C01 — Seamless Steel — Exotic
After a connecting Dance attack, the first Edge Precision Cut within 2s uses a distinct mobile transition animation.
Reduce transition delay by 20%.
No automatic direct-damage increase.
Cooldown 5s.
R-C02 — Swordsman's Breath — Standard
A connecting Precision Cut restores 3 stamina.
Cooldown 4s.
No multihit duplication.
R-C03 — Measured Blade — Advanced
Hitting an enemy during its recovery phase reduces the recovery of your next eligible attack by 15%.
Expiry 3s.
Cooldown 6s.
No illegal committed-frame cancels.
R-C04 — Close Pursuit — Standard
If an enemy moves just outside melee range after a connecting attack, the next Forward Dance within 3s gains up to 20% additional controlled forward travel.
Only toward a real valid target.
No teleport or guaranteed hit.
R-C05 — Blade Reflex — Advanced
A genuinely well-timed defensive dodge enables one special follow-up based on current mode.
Available for 2s.
Cooldown 6s.
Keep the alternate physical follow-up distinct from a normal attack.
R-C06 — Clean Execution — Advanced
Precision Cut hitting an enemy in real attack recovery deals +25% Poise damage.
Cooldown 5s per target.

6I. DANCE MASTERY — SIX
R-D01 — Phantom Footwork — Exotic / Path Anchor
Transform Lateral Dance into a shallow curved motion around the locked target.
Travel approximately 1.15 times the base Lateral Dance distance.
Maintain actual collision and reasonable target radius.
No automatic critical or immunity.
R-D02 — Flowing Steps — Standard
After a successful dodge of an actual attack, the next directional Dance attack within 3s costs 25% less stamina.
Cooldown 5s.
R-D03 — Circling Predator — Advanced
Hitting from the flank following a real lateral displacement enables a special follow-up attack.
Follow-up direct damage = 85% of normal eligible attack damage.
Compensation: superior positioning/transition, not raw damage.
Cooldown 7s.
R-D04 — Extended Orbit — Advanced
Orbit Step covers approximately 20% more angular distance.
Increases its movement commitment by 15%.
Do not exceed a safe orbit angle or pass through collision.
R-D05 — Tempest Waltz — Exotic
Whirling Assault allows exactly one controlled movement redirection during its four-hit sequence.
Movement speed during the technique increases by 15%.
No additional hits or direct-damage multiplier.
R-D06 — Dancer's Reversal — Exotic
After a precise side dodge, one eligible Dance attack becomes a turning follow-up.
Up to +20% controlled movement distance.
Cooldown 8s.
No teleport, clones or i-frames beyond dodge.
Dance synergy:
* Phantom Footwork + Circling Predator: valid curved flank movement can enable the special follow-up.
* Extended Orbit + Dancer's Reversal: Orbit itself does not count as a defensive dodge; the player must still execute a genuine dodge.
* Tempest Waltz + Flowing Steps: a real dodge may reduce the following Whirling Assault stamina cost, but not refund per hit.

6J. EDGE MASTERY — SIX
R-E01 — Perfect Draw — Exotic / Path Anchor
Committed Cut gains a precision release window around maximum charge.
Initial timing window: 0.12s after reaching maximum charge.
Successful release reduces that attack's recovery by 20%.
No automatic damage increase.
Outside the timing window, Committed Cut works normally.
The full-charge visual cue remains clear.
R-E02 — Steel Focus — Standard
While charging Committed Cut, gain +20% Poise damage resistance.
Does not prevent damage or interruption.
R-E03 — Fracturing Edge — Advanced
Breaking Point against a recovering enemy gains +30% Poise effectiveness.
Its hitbox width decreases by 15%.
No raw-damage increase.
R-E04 — Executioner's Distance — Advanced
Precision Cut range increases by 15%.
Its hitbox width decreases by 20%.
The narrowness is the tradeoff.
R-E05 — Twin Verdict — Exotic
Transform Committed Cut into two committed sword impacts.
First strike deals 40%, second 60% of the original eligible total damage.
Total direct damage remains approximately unchanged before other modifiers.
Increase total exposure/recovery by 15%.
The second strike may use a small controlled angle correction, not homing.
No additional stamina refund.
Mutually exclusive with any other transformation that replaces Committed Cut, including legacy Twin Tempest-style transformation.
R-E06 — Patient Blade — Standard
A fully charged Committed Cut that connects restores 5 stamina after resolution.
Cooldown 6s.
A missed strike refunds nothing.
Edge synergy:
* Perfect Draw + Steel Focus: accurate full-charge release provides the recovery benefit while Steel Focus protects charge commitment, without stacking invulnerability.
* Fracturing Edge + Clean Execution: combined Poise bonus against recovering targets capped at +50% over the base relevant attack, before target mitigation.
* Twin Verdict + Patient Blade: refund happens once only if the whole committed action lands, not once for each hit.

PART 7 — DRAFT QUALITY, SYNERGY AND BAD-CHOICE PREVENTION
7.1 Avoid dead picks
Each offered Augment must have:
* A currently usable gameplay trigger.
* At least one ordinary combat scenario where it matters.
* A clear benefit relative to existing alternatives.
* A visual or combat-log indication of activation.
* A verified tooltip and actual-value preview.
No player should be offered a support-specific Augment when their current mechanics cannot trigger it.
No Augment should require a second Augment just to function.

7.2 Synergy display
Add structured metadata:
* `path_id`
* `synergy_tags`
* `synergy_partners`
* `exclusive_group`
* `trigger_summary`
* `cooldown`
* `mechanical_tradeoff`
* `scaling_sources`
Adapt the exact data format to the existing architecture.
Do not rely only on parsing free-form descriptions.
If one card synergizes with an owned Augment, show:
SYNERGY AVAILABLE
Then explain exactly what the combined behavior becomes.
If an eligible Augment would replace an active transformation, show the replacement warning before confirmation.

7.3 Draft composition
Level 4:
* One anchor from each path.
* One strong class-common alternative.
Level 8:
* Favor the chosen path, compatible class-common options, and relevant synergy.
* Do not offer an exclusive opposite-path anchor while a conflicting anchor is active.
Level 10:
* Prioritize useful build completion and synergy.
* Always offer three legitimate options where the eligible pool allows.
* No duplicate already-owned nonstackable cards.
* No dead or incompatible cards.
Preserve reproducible RNG and deterministic test seeds.
Do not secretly force a specific build outcome.

7.4 Evolution / replacement
Arena-style evolution and replacement are approved as design directions, but do not add free extra active Augment slots.
For the Level 1–10 milestone:
* Implement a safe replacement mechanism for an already owned Augment at a documented build-management opportunity.
* Replacement cannot duplicate drafts or create free rarity upgrades.
* Clearly warn when removing a path anchor invalidates a dependent effect.
* Preserve save compatibility.
* Existing owned Augments must never be silently deleted.
* Do not implement multi-level evolution of all 60 cards.
Implement one optional evolution prototype per path only if the existing three-slot and draft economy can support it without distorting progression.
Priority is fully functional base Augments and synergies, not broad unfinished evolution.

PART 8 — COLORED SKILL SCALING AND READABLE TOOLTIPS
This is a major player-experience requirement.
The player currently finds it difficult to understand:
* Skill effects.
* Damage calculations.
* Stat percentages.
* Scaling.
* Differences between equipment and Augment choices.
Build a unified numerical presentation layer.

8.1 Stat color palette
Use the following initial colors, adjusted slightly for contrast if necessary.
Strength — STR
* Warm orange-red.
* `#F28C52`
* Icon: sword/impact.
Dexterity — DEX
* Cyan.
* `#48C8D8`
* Icon: swift blades.
Vitality — VIT
* Green.
* `#66C985`
* Icon: heart.
Fortitude — FOR
* Steel-blue.
* `#80A8E8`
* Icon: armor/shield.
Mastery — MAS
* Violet.
* `#BD92F5`
* Icon: arcane sigil.
Additional effect types:
Physical damage: warm white/orange.
Magic damage: blue-violet.
Healing: green with healing icon.
Poise: gold/amber with impact icon.
Stamina: yellow-green.
Mana: blue.
Critical: bright gold.
Negative effects: muted red.
Never rely on color alone.
Always include stat abbreviation and readable text.

8.2 Important stat identity
Use ACTUAL game formulas.
The current game's StatBlock defines:
* STR: Heavy/Charged scaling and Critical Damage.
* DEX: Total multi-hit scaling.
* VIT: Maximum HP.
* FOR: effectiveness of Armor/Magic Resistance.
* MAS: effects including buffs, debuffs, DoT and HoT.
Current default tuning in BalanceConfig includes:
* STR heavy scale: 3% per STR.
* STR crit damage: 1.2 percentage points per STR.
* DEX multihit scale: 3% per DEX.
* VIT: +12 maximum HP per VIT.
* FOR: +5% effectiveness of existing armor/MR per FOR.
* MAS: +4% effect-power coefficient per MAS.
These are baseline configuration values, not a license to apply all stats to every skill.
A skill must display only stats that genuinely affect it.
Do not display VIT as a direct damage stat when its only contribution is HP.
Do not mislabel MAS as direct Magic Damage unless the specific calculation uses MAS.
If the game formulas change, tooltips must update automatically.

8.3 Three tooltip levels
SIMPLE — default
Show:
* Skill name.
* Short plain-language purpose.
* Actual current value.
* Resource cost.
* Poise.
* Cooldown or charge time.
* Clear risk/commitment.
Example format:
Committed Cut
Powerful charged physical sword strike.
Physical Damage: [calculated]
Poise: [calculated]
Stamina: 20
Full Charge: 0.75s
Relevant scaling: STR, if supported by the real formula.
DETAILED — hold Shift
Show:
* Base value.
* Relevant stat contributions with matching colors.
* Multipliers.
* Charge modifiers.
* Augment modifiers.
* Current pre-mitigation result.
* Estimated post-mitigation result if a valid enemy target is selected.
ADVANCED — expanded Skills menu
Show:
* Exact formula.
* Timing phases.
* Status duration.
* Hit count and distribution.
* Critical contribution.
* Physical/Magic type.
* Damage or healing breakdown.
* Poise contribution.
* Effect scaling.
* Actual Augment and equipment modifiers.
* Before/after preview.

8.4 Single calculation source
Do not duplicate combat math in UI code.
Expose calculation breakdowns through a shared query interface that uses the same underlying combat formulas.
Damage breakdown should include:
* Base weapon/spell value.
* Stat-derived modifiers.
* Charge modifiers.
* Additive bonuses.
* Multiplicative bonuses.
* Critical assumptions.
* Target mitigation.
* Final result.
Never describe a deterministic tooltip estimate as guaranteed damage if crit or target mitigation makes the result variable.
Show:
* Noncritical expected value.
* Critical value or expected critical contribution when relevant.
* Target-mitigated estimate when target data exists.

8.5 Before/after previews
On Character stat allocation:
When increasing STR, DEX, VIT, FOR or MAS, preview changes to every relevant derived stat and equipped skill.
Use the matching colors.
Example display:
STR +1
Committed Cut: 136 → 140 (+4)
The numbers above are illustrative; use real calculations at runtime.
When the player inspects an Augment:
Display:
* What changes.
* What stays the same.
* What is sacrificed.
* Which current skills are affected.
* Before/after values.
* Which owned Augments interact with it.
* Whether another equipped transformation is excluded.
Support both skill-related and non-damage effects.
For example, movement Augments should show actual travel distance and movement commitment rather than inventing a DPS value.

8.6 Dynamic text
Tooltip percentages must be generated from configuration and runtime stat values.
No manually hardcoded percentages that can become wrong after balance changes.
Support:
* Current values.
* Changed gear.
* Allocated stats.
* Selected Augments.
* Charged versus partial spells.
* Level progression.

8.7 UI usability
* Compact combat HUD.
* Full details in menu.
* Clear readable contrast.
* No tiny text.
* No color-only indicators.
* No overlapping tooltip panels.
* Mouse hover and Shift details.
* Controller-compatible focus/navigation where supported.
Preserve the game's established fantasy art direction.
No unrelated HUD redesign.

PART 9 — POISE AND STAGGER
The owner reported that Stagger/Poise Break windows feel too short.
Current global `BalanceConfig.stagger_time` default: 0.85s.
Do not assume every enemy uses exactly this duration.
Audit:
* Normal hit reactions.
* Interrupts.
* Stagger.
* Poise Break.
* Enemy stagger immunity.
* Recovery and regeneration.
* Boss-specific rules.
Provisional target windows
Normal enemies:
* Approximately 1.2–1.4s genuine Poise Break opportunity.
Elite enemies:
* Approximately 0.8–1.0s.
Bosses:
* Approximately 0.5–0.7s, or their existing scripted vulnerability windows if those are superior.
Minor hit reactions should remain shorter and separate from Poise Break.
Do not globally assign long disable durations to ordinary attacks.
Required behavior
* Poise Break must have a clearly visible animation and sound.
* UI should communicate when the opening starts.
* A readable attack follow-up should fit into the opportunity.
* Breaking Point and other Poise-focused actions should visibly contribute.
* Avoid indefinite stagger loops.
* Repeated crowd control should be limited by existing or explicitly documented per-target rules.
* Bosses must retain meaningful counterplay.
Measure the usable attack window, not just the configured timer.
Do not change class damage to compensate for missing Stagger feedback.

PART 10 — BALANCE TARGETS
All percentages above are provisional.
Claude may tune within the documented envelope after measuring real combat.
However, Claude must not independently change the identities or functional behavior of Augments.
Test at levels:
1, 3, 4, 5, 8 and 10.
Test conditions:
* Solo.
* Party.
* No Augments.
* One path anchor.
* Full three-Augment build.
* At least one intended synergy.
* A competing build from the opposite path.
* Ordinary enemies.
* Elite enemies.
* Boss-representative encounters.
Evaluate:
* DPS.
* Effective healing.
* Shielding.
* Threat generation.
* Guard uptime.
* Stamina/mana uptime.
* Poise Break frequency.
* Enemy counterplay.
* Movement and attack commitment.
* Augment trigger frequency.
* Synergy activation frequency.
* Whether a player can understand why an Augment activated.
Initial balance guidance:
* A typical Advanced Augment should create a noticeable tactical benefit, not merely insignificant passive numbers.
* Exotic Augments should change behavior substantially.
* Path anchors must produce different combat decisions within the first few encounters.
* A three-Augment synergy build should feel stronger in its intended context but must not universally dominate every other combination.
* No single synergy should create permanent protection, permanent healing loops, permanently disabled enemies or indefinite resource generation.
No artificial target of identical DPS across classes.
Vanguard is a tank.
Worldweaver combines damage, healing and support.
Reaver specializes in physical DPS.
Balance around their different responsibilities.

PART 11 — TESTING REQUIREMENTS
Add deterministic unit/integration tests for:
1. Every new Augment trigger.
2. Each Augment's cooldown.
3. Missing/invalid target cases.
4. Invalid class/path eligibility.
5. Core-only and legacy Augment compatibility.
6. At least every specified synergy pair.
7. Mutually exclusive transformations.
8. No recursive activation.
9. No unintended multi-hit duplication.
10. Correct resource refunds.
11. No infinite healing/resource loops.
12. Boss crowd-control restrictions.
13. Path anchor availability.
14. Level 4/8/10 draft validity.
15. Save and reload.
16. Death and progression reset.
17. Inactive legacy Augments.
18. Color and scaling correctness.
19. Tooltip numeric agreement with real damage/healing.
20. Before/after preview accuracy.
21. Worldweaver wheel hold, tap, release and cancel behavior.
22. Worldweaver healing in both paths.
23. Reaver mobility and charge feedback.
24. Vanguard Guard and team protection in both paths.
25. Full Level 1–10 progression.
26. Regression coverage for all three classes.
A tooltip displaying a mathematically wrong value is a test failure.
An Augment that never activates under its documented intended combat scenario is a test failure.
An Augment that silently changes core mechanics outside its stated specification is a test failure.
Run the existing full regression suite and report the actual passing/failing counts.

PART 12 — DELIVERABLES AND IMPLEMENTATION ORDER
Implement in reviewable milestones on the new feature branch.
Milestone A — Baseline and Stat UI
* Baseline audit.
* Actual calculation breakdown provider.
* Colored stat references.
* Skill and Augment tooltips.
* Before/after preview.
Milestone B — Combat Feel
* Reaver Blade Dancer 004 refinements.
* Worldweaver two-wheel spell selection.
* Poise/Stagger audit and scoped improvements.
Milestone C — Path Framework
* Two path identities for each class.
* Path eligibility.
* Compatible and exclusive Augment groups.
* Level 4/8/10 draft structure.
* Save compatibility.
Milestone D — Augment Library
* Implement the 60 specified Augments.
* Add required visual/audio feedback.
* Implement documented synergies.
* Implement the safe replacement mechanism.
* Ensure fully functional three-Augment builds.
Milestone E — Full Level 1–10 Verification
* Complete automated test suite.
* Balance comparison.
* UI and scaling verification.
* Save safety.
* Human playtest guide.
If a milestone uncovers an architecture blocker that prevents safe implementation, document it precisely. Do not silently remove requirements or substitute generic effects.
Do not describe a partially implemented milestone as complete.
Provide:
1. `collaboration/results/LEVEL10-FOUNDATION-005-BASELINE.md`
2. `collaboration/results/LEVEL10-FOUNDATION-005.md`
3. `collaboration/results/LEVEL10-FOUNDATION-005-PLAYTEST.md`
4. A complete Augment catalog showing all 60 implemented effects.
5. A matrix of class/path eligibility.
6. A matrix of tested Augment synergies.
7. Actual values and balance changes.
8. Full test results.
9. Commit SHAs.
10. Exact Godot launch instructions.
Commit logically by milestone.
Push the feature branch without force.
Do not create a PR.
Do not merge into main.
Preserve the owner's existing saved game and all preexisting uncommitted files.

FINAL ACCEPTANCE STANDARD
The first ten levels must demonstrate the core promise of The Living World:
Three fundamentally different classes, each supporting two genuinely different build directions, with impactful Augments that change combat decisions.
Worldweaver must remain capable of healing and supporting allies in both paths.
Vanguard must protect the team in both paths.
Reaver must preserve Blade Dancer's distinctive movement and Edge precision.
Augments must be individually useful and capable of meaningful combinations.
The player must be able to understand every skill's effect, real stat scaling, and expected consequences of selecting an Augment.
Do not maximize the number of cards. Maximize the number of genuinely different, enjoyable and comprehensible ways to play.
