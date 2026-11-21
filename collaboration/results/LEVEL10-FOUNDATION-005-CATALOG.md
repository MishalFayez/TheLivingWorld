# LEVEL10-FOUNDATION-005: Augment catalog (60 cards: 57 playable, 3 blocked)

Generated from `data/augments/*.tres` by `tools/print_l10_catalog.gd`. The description is the in-game text, filled from the card's params.

**Status legend**

| Status | Meaning |
|---|---|
| ACTIVE | Implemented and drafted |
| BLOCKED | In the catalog, never offered; a design prerequisite is missing |
| PARTIAL | Not offered to some classes, with the reason |

## Global

| Code | Card | Path | Rarity | Requires | Party | Cooldown | Status | Effect (in-game text) |
|---|---|---|---|---|---|---|---|---|
| G01 | Second Wind | Common | advanced | - | - | 6.0s | ACTIVE | After a defensive dodge avoids a real enemy attack, your next offensive action within 3s costs 25% less stamina (Worldweaver: the next offensive spell costs 15% less mana). Empty dodges do nothing. |
| G02 | Measured Recovery | Common | standard | - | - | 5.0s | ACTIVE | Hitting an enemy during its real attack recovery restores 5 stamina (Vanguard / Reaver) or 4 mana (Worldweaver). |
| G03 | Echoing Impact | Common | exotic | - | - | 6.0s | ACTIVE | The third separate connecting offensive action against the same target creates a delayed echo dealing 25% of that action's direct damage. Echoes trigger nothing else and refund nothing. |
| G04 | Calculated Risk | Common | exotic | - | - | - | PARTIAL (not mage): Worldweaver spells resolve after their recovery, so a missed committed spell cannot lengthen it (spec rule: report, do not substitute). | Committed actions (Committed Cut, Breaking Point, Judgment Strike, Shieldbreaker Slash) deal +20% direct damage, but if one connects with nothing its recovery is +20% longer. |
| G05 | Near Miss | Common | advanced | - | - | 8.0s | ACTIVE | Avoid an enemy attack aimed at you by moving out of it (no dodge, no i-frames, inside its reach + 1m): gain +15% movement speed for 2s. |
| G06 | Resolute Spirit | Common | standard | - | - | 10.0s | ACTIVE | When you recover from a Stagger, take 20% less Poise damage for 3s. You can still be interrupted. |

## Vanguard

| Code | Card | Path | Rarity | Requires | Party | Cooldown | Status | Effect (in-game text) |
|---|---|---|---|---|---|---|---|---|
| V-B01 | Living Fortress | Bulwark (ANCHOR) | exotic | - | - | - | ACTIVE | PATH ANCHOR (Bulwark). Walk forward while guarding at up to 60% of normal speed. Stamina recovery while advancing in Guard is 30% lower. Every Guard rule (front only, breaks) still applies. |
| V-B02 | Shielded Advance | Bulwark | advanced | shield_rush | - | - | ACTIVE | Shield Rush becomes a shorter defensive advance: 80% of its travel, and +15pp frontal damage reduction during the rush (capped at 90%). Interception still works. |
| V-B03 | Bastion Pulse | Bulwark | exotic | - | - | 8.0s | ACTIVE | A Perfect Guard emits a 3m pulse that slows nearby enemies by 25% for 2s (bosses: half). No stun. |
| V-B04 | Heavy Anchor | Bulwark | standard | - | - | - | ACTIVE | While guarding, take 20% less Poise damage. Guard movement -10%. |
| V-B05 | Fortress Breaker | Bulwark | advanced | - | - | 6.0s | BLOCKED: No enemy attack in the game is marked heavy (AttackData.is_heavy), so a heavy attack can never be blocked. Needs enemy heavy attacks defined first. | After blocking a heavy enemy attack, your next shield strike (Aegis Counter, Shield Rush) within 4s deals 35% more Poise damage. No raw damage. |
| V-B06 | Sheltering Counter | Bulwark | advanced | v_intercept | party only | 8.0s | ACTIVE | A connecting counter within 3s after protecting an ally gives that ally a shield of 5% of your max HP for 4s. |
| V-C01 | Guardian's Reach | Common | advanced | v_intercept | party only | - | ACTIVE | Interception range +20%. Interception Shield Rush costs +10% stamina. |
| V-C02 | Steel Foundation | Common | standard | - | - | - | ACTIVE | After a successful Guard, the next hit you receive within 3s has 30% less knockback. |
| V-C03 | Shared Aegis | Common | advanced | v_intercept | party only | 8.0s | ACTIVE | A successful interception gives the protected ally a shield of 6% of YOUR max HP for 4s. |
| V-C04 | Unyielding Footing | Common | standard | - | - | - | ACTIVE | Movement while guarding +15% (relative to normal Guard movement; never a sprint). |
| V-C05 | Defender's Oath | Common | exotic | v_intercept | party only | 8.0s | ACTIVE | After a successful interception, for 4s you take 25% of the damage that ally receives (range and line of sight required). The redirected part never redirects again. |
| V-C06 | Last Barrier | Common | advanced | - | - | 20.0s | ACTIVE | A successful Guard while below 35% HP grants a shield of 8% max HP for 4s. |
| V-K01 | Aegis Reversal | Counterguard (ANCHOR) | exotic | - | - | - | ACTIVE | PATH ANCHOR (Counterguard). After a Perfect Guard, your next Heavy Attack within 3s becomes the Reversal counter: 30% more Poise damage, 10% shorter reach. No automatic critical. |
| V-K02 | Precise Defense | Counterguard | standard | - | - | 10.0s | ACTIVE | After a Perfect Guard, your next Perfect Guard within 4s has a 0.03s wider timing window. Single use. The normal Guard window is unchanged. |
| V-K03 | Redirected Force | Counterguard | exotic | - | - | 10.0s | ACTIVE | After Perfect-Guarding a charging (lunging) attack, counter while holding A / D to step 0.8m aside first. No teleport, no extra i-frames. |
| V-K04 | Retaliation Window | Counterguard | advanced | - | - | - | ACTIVE | After a connecting counter you can raise Guard 20% earlier in its recovery. Never during its hit frames. |
| V-K05 | Judgment Echo | Counterguard | exotic | - | - | 10.0s | ACTIVE | A connecting counter opens a 2s window for one Echo Strike (LMB): 65% of the counter's damage, +20% recovery. |
| V-K06 | Guardian's Retort | Counterguard | advanced | v_intercept | party only | 8.0s | ACTIVE | A counter right after an interception turns 20% of its direct damage into a shield on that ally (max 8% of the ally's max HP). No healing. |

## Mage

| Code | Card | Path | Rarity | Requires | Party | Cooldown | Status | Effect (in-game text) |
|---|---|---|---|---|---|---|---|---|
| M-A01 | Spell Threading | Arcane Weaving (ANCHOR) | exotic | - | - | 5.0s | ACTIVE | PATH ANCHOR (Arcane Weaving). After releasing a spell, casting a DIFFERENT spell within 3s lowers its minimum charge by 20% and its full charge by 10%. Never instant, never free. |
| M-A02 | Arcane Relay | Arcane Weaving | advanced | - | party only | 10.0s | ACTIVE | After a direct heal on an ally, your next projectile spell within 4s launches from that ally (in range, line of sight). Same mana and targeting rules. |
| M-A03 | Rewoven Spell | Arcane Weaving | advanced | m_storm | - | 8.0s | ACTIVE | A single-target offensive spell (Thunder Conduit partial release; Glacial Spear / Lightning Verdict when known) that hits also strikes another enemy within 6m for 25% of its direct damage. Never chains. |
| M-A04 | Swift Invocation | Arcane Weaving | standard | - | - | 6.0s | ACTIVE | Changing a spell with the spell wheel (Q / V, hold or tap) makes the next spell prepare 10% faster. Swapping without casting gains nothing. |
| M-A05 | Sympathetic Link | Arcane Weaving | exotic | - | party only | 12.0s | ACTIVE | A direct heal on an ally links them to the nearest enemy within 8m for 4s. Your next direct heal on that ally deals 15% of the effective healing as magic damage to the linked enemy (max 0.6 x Weapon Power). |
| M-A06 | Emergency Thread | Arcane Weaving | advanced | - | - | 10.0s | ACTIVE | Healing an ally below 35% HP keeps your previous offensive spell ready for a one-tap swap back (spell wheel), and your next offensive cast within 4s recovers 15% faster. |
| M-C01 | Merciful Conduit | Common | exotic | - | - | 8.0s | ACTIVE | Once every 8s, a damaging offensive spell heals the most injured ally in range for 12% of the damage dealt (max 8% of that ally's max HP). Never recursive. |
| M-C02 | Gentle Current | Common | standard | - | - | 5.0s | ACTIVE | Effective direct healing gives the target +10% movement speed for 2.5s (once per 5s per target). Pure overheal does nothing. |
| M-C03 | Elemental Memory | Common | advanced | - | - | 6.0s | ACTIVE | Returning to an element you used within the last 6s (after casting a different one) makes that spell cost 12% less mana. Repeating one element does nothing. |
| M-C04 | Benevolent Casting | Common | standard | - | - | 8.0s | ACTIVE | Healing an ally below 40% HP makes your next support spell (Life / utility) within 5s cost 15% less mana. |
| M-C05 | Dual Invocation | Common | exotic | - | - | 6.0s | ACTIVE | A direct heal makes your next offensive spell within 3s prepare 15% faster; an offensive spell does the same for your next direct heal. Each direction has its own 6s cooldown. |
| M-C06 | Woven Protection | Common | advanced | - | - | - | ACTIVE | 20% of real overhealing becomes a shield (max 6% of the recipient's max HP) for 4s. The shield triggers no healing effects. |
| M-F01 | Elemental Crossroads | Elemental Fusion (ANCHOR) | exotic | m_frost | - | - | ACTIVE | PATH ANCHOR (Elemental Fusion). Choose one implemented interaction (Augments menu): its effect is +20% - fragment damage / Poise vs enemies, or Vitalize duration on allies. Other spells are unchanged. |
| M-F02 | Lingering Essence | Elemental Fusion | standard | - | - | - | ACTIVE | Burning and Chill you apply last +20% longer (max +1.5s). Hard crowd control is not extended. |
| M-F03 | Thermal Fracture | Elemental Fusion | advanced | m_frost | - | 6.0s | ACTIVE | Fire shattering your ice deals 25% more Poise to ordinary enemies (10% vs bosses), once per 6s per target. |
| M-F04 | Healing Ember | Elemental Fusion | advanced | - | - | - | BLOCKED: No Fire-based ally support effect exists in the approved Worldweaver (all support is Life). The spec forbids inventing one: design prerequisite missing. | An approved Fire-based ally support effect would also grant +12% physical weapon damage for 4s. |
| M-F05 | Living Confluence | Elemental Fusion | exotic | m_frost | - | 10.0s | ACTIVE | After an elemental interaction, your next spell of a DIFFERENT element within 4s adds a follow-up: 20% of its direct damage as a second impact, or 15% extra healing on an ally. Never chains. |
| M-F06 | Purifying Confluence | Elemental Fusion | advanced | - | - | - | BLOCKED: No enemy applies a negative status to heroes in the current game, so there is nothing to cleanse. Needs a defined minor debuff first. | A qualifying ally-targeted elemental interaction would remove one minor negative status (12s per ally). |

## Reaver

| Code | Card | Path | Rarity | Requires | Party | Cooldown | Status | Effect (in-game text) |
|---|---|---|---|---|---|---|---|---|
| R-C01 | Seamless Steel | Common | exotic | - | - | 5.0s | ACTIVE | After a connecting Dance attack, your first Precision Cut within 2s uses a mobile transition and starts 20% sooner. No damage bonus. |
| R-C02 | Swordsman's Breath | Common | standard | - | - | 4.0s | ACTIVE | A connecting Precision Cut restores 3 stamina (once per cut). |
| R-C03 | Measured Blade | Common | advanced | - | - | 6.0s | ACTIVE | Hitting an enemy during its recovery makes your next attack within 3s recover 15% faster. Never inside committed hit frames. |
| R-C04 | Close Pursuit | Common | standard | - | - | - | ACTIVE | If the enemy you just hit ends 2.2m-3.6m away, your next Forward Dance within 3s travels up to 20% farther toward it. No teleport. |
| R-C05 | Blade Reflex | Common | advanced | - | - | 6.0s | ACTIVE | A well-timed dodge (i-frames avoid a real attack) makes your next LMB within 2s a Reflex follow-up: a spinning Reflex Cut in Dance, a Reflex Thrust in Edge. |
| R-C06 | Clean Execution | Common | advanced | - | - | 5.0s | ACTIVE | A Precision Cut that hits an enemy in its attack recovery deals 25% more Poise damage (5s per target). |
| R-D01 | Phantom Footwork | Dance Mastery (ANCHOR) | exotic | - | - | - | ACTIVE | PATH ANCHOR (Dance Mastery). With a locked target, Lateral Dance becomes a curved step around it, traveling +15% the distance. Collision is real; no crit or immunity. |
| R-D02 | Flowing Steps | Dance Mastery | standard | - | - | 5.0s | ACTIVE | After a well-timed dodge, your next directional Dance attack within 3s costs 25% less stamina. |
| R-D03 | Circling Predator | Dance Mastery | advanced | - | - | 7.0s | ACTIVE | Hitting from the flank (>60 deg) after moving at least 0.5m sideways readies a Predator Cut (next LMB within 2s): 85% damage, faster start. |
| R-D04 | Extended Orbit | Dance Mastery | advanced | bd_footwork | - | - | ACTIVE | Orbit Step sweeps +20% more angle; its startup and recovery are +15% longer. |
| R-D05 | Tempest Waltz | Dance Mastery | exotic | bd_offense | - | - | ACTIVE | Whirling Assault allows exactly one redirection of its movement (turn your input by more than 60 deg) and moves +15% faster. No extra hits or damage. |
| R-D06 | Dancer's Reversal | Dance Mastery | exotic | - | - | 8.0s | ACTIVE | After a well-timed SIDE dodge, your next forward or lateral Dance within 2s is a turning follow-up with +20% movement. |
| R-E01 | Perfect Draw | Edge Mastery (ANCHOR) | exotic | - | - | - | ACTIVE | PATH ANCHOR (Edge Mastery). Release Committed Cut within 0.12s after it reaches full charge: that strike recovers 20% faster. No damage bonus; outside the window it is normal. |
| R-E02 | Steel Focus | Edge Mastery | standard | - | - | - | ACTIVE | While charging Committed Cut, take 20% less Poise damage. Damage and interruption still apply. |
| R-E03 | Fracturing Edge | Edge Mastery | advanced | bd_offense | - | - | ACTIVE | Breaking Point vs a recovering enemy deals 30% more Poise damage; its hitbox is 15% narrower. No raw damage. |
| R-E04 | Executioner's Distance | Edge Mastery | advanced | - | - | - | ACTIVE | Precision Cut reaches +15% farther but is 20% narrower. |
| R-E05 | Twin Verdict | Edge Mastery | exotic | - | - | - | ACTIVE | Committed Cut becomes two committed impacts (40% / 60% of its damage, total unchanged); total exposure +15%. The second impact may turn up to 15 deg toward your target. |
| R-E06 | Patient Blade | Edge Mastery | standard | - | - | 6.0s | ACTIVE | A FULLY charged Committed Cut that connects restores 5 stamina after it resolves. A miss refunds nothing. |

## Synergies (listed pairs)

Kind: **synergy** = a real extra gameplay effect (only these are announced as SYNERGY AVAILABLE); **visual feedback only**; **rule, no extra benefit** = a limit or clarification; **inactive** = the partner is blocked.

| Card | Partner | Kind | Combined behaviour |
|---|---|---|---|
| Spell Threading | Dual Invocation | synergy | Combined preparation reduction capped at 25%. |
| Arcane Relay | Sympathetic Link | rule, no extra benefit | The link may start from the supported ally; never extra targets. |
| Swift Invocation | Emergency Thread | rule, no extra benefit | Restoring the kept offensive spell counts as a wheel change (shared cooldown). |
| Elemental Crossroads | Thermal Fracture | synergy | Fire / Frost Poise payoff improves further, capped at +40% total for ordinary enemies. |
| Elemental Crossroads | Living Confluence | visual feedback only | If the follow-up comes from your chosen interaction it changes colour - its damage is not doubled. |
| Purifying Confluence | Woven Protection | inactive - partner blocked | A cleanse would refresh an existing shield's duration once (not its amount). |
| Clean Execution | Fracturing Edge | synergy | Combined Poise bonus vs recovering enemies capped at +50%. |
| Phantom Footwork | Circling Predator | rule, no extra benefit | A curved flank step counts as lateral displacement for the Predator follow-up. |
| Flowing Steps | Tempest Waltz | synergy | The discount may apply to the next Whirling Assault instead (once, never per hit). |
| Extended Orbit | Dancer's Reversal | rule, no extra benefit | Orbit Step never counts as a dodge: Reversal still needs a real dodge. |
| Perfect Draw | Steel Focus | rule, no extra benefit | Steel Focus protects the charge while you wait for the window - no invulnerability. |
| Twin Verdict | Patient Blade | rule, no extra benefit | The refund happens once, only if both impacts land. |
| Living Fortress | Bastion Pulse | synergy | A Perfect Guard while advancing releases the pulse from your advance position with +15% radius (once per cooldown). |
| Heavy Anchor | Fortress Breaker | inactive - partner blocked | Blocking a heavy attack raises Fortress Breaker's Poise bonus from 35% to 45% (never stacks). |
| Sheltering Counter | Shared Aegis | rule, no extra benefit | Shields refresh duration; the amount is the larger shield, never the sum. |
| Guardian's Reach | Guardian's Retort | rule, no extra benefit | Longer reach only creates more successful interceptions; Retort still shields one ally per counter. |
| Aegis Reversal | Judgment Echo | visual feedback only | A Reversal counter unlocks the alternate (rising) Echo Strike animation - still one follow-up, never an automatic second hit. |
| Redirected Force | Retaliation Window | synergy | A repositioned counter returns to Guard 30% earlier instead of 20%. |
