# CLASS PLAYTEST GUIDE — Vanguard · Mage · Reaver

This guide is for someone who did not write the code.
Everything here can be done in the game. Nothing you do in the Lab or in guided mode is saved to your character.

## Before you start (2 minutes)

1. Start or continue a character, then press **F1** to open the Debug Panel and choose the **Lab** tab.
2. In the Lab:
   - Pick a **class**.
   - Pick **Solo** or **Party**.
   - Optionally turn on **Temporary invincibility** (useful for learning; turn it off to judge difficulty).
3. Use the **Presets**:
   - **Fresh Level 1 / 5 / 10** follow normal progression. The Level 10 preset leaves 3 augment drafts for you to pick.
   - **BUILD SHOWCASE** presets give a whole build at once. They are **not** something a normal Level 10 character can have; they exist so you can feel the build. They also include the named skills above the Lv10 cap (Shield Plant, Sunder Edge, Turning Edge, Final Stroke).
4. Start a guided scenario with the buttons at the bottom of the Lab (V1…V4 + VH–VJ, M1…M5, R1…R5 + RA–RG, A…F). The list shows the active class; scroll down in the Lab if needed.
   - A small panel on the left tells you what to do and what should happen.
   - **Restart** resets the scenario, **Skip** goes to the next one, **Hide** shrinks the panel.
   - You always play the scenario yourself.
5. Record your impressions in `PLAYTEST_FEEDBACK.md` right after each class.

To reset at any time, use the Lab's **Reset encounter** (removes enemies and Mage formations, restores you) and **Restore resources** buttons.

### Common controls (all classes)

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Camera |
| Tab | Lock on |
| Mouse wheel | Switch target |
| Space | Dodge |
| C | Character / attributes |
| F1 | Debug + Lab |

---

# VANGUARD — The Aegis Knight

**Identity:** a sword-and-shield tank who controls danger by guarding, intercepting and counterattacking.

**Starting abilities (Lv1):** sword attacks, Aegis Guard, Perfect Guard, Aegis Counter, **Guarded Strike**.

### Controls

| Input | Action |
|---|---|
| LMB | Sword attack (2-hit chain) |
| RMB | Heavy |
| Shift (hold) | Guard (frontal) |
| Shift just before a hit | Perfect Guard (gold flash + PERFECT GUARD banner) |
| LMB after a Perfect Guard | Aegis Counter |
| **Shift + LMB** | **Guarded Strike**: a short strike from Guard. Your guard is weaker during the swing and returns afterwards |
| 1 (tap) | Shield Rush. Toward an ally being attacked = **Interception** (Lv7) |
| **1 (hold 0.35s)** | **Empowered Shield Rush**: 30 Resolve, taunt + stagger (Lv5) |
| 2 (hold, release) | Judgment Strike. Right after a Perfect Guard = instant Riposte. Full charge + 40 Resolve = **Verdict Strike** (Lv7) |
| 3 (tap) | Iron Sweep (Lv9) |
| **3 (hold 0.35s)** | **Aegis Sweep**: 25 Resolve, wider sweep that pulls enemy attention onto you (no extra damage) |
| **E** | **Shield Plant** (Lv12: Build Showcase only). Press E again to leave it |
| Space | Dodge. While planted with Rolling Fortress = a planted reposition |

Spenders you have not unlocked are not shown and do nothing.

### Level 1–10 (and showcase)
| Level | Unlock |
|---|---|
| 1 | Guard, Perfect Guard, Aegis Counter, **Guarded Strike** |
| 2 | Stats |
| 3 | Shield Rush |
| 4 | Draft |
| 5 | Resolve Spending (hold 1 = Empowered Shield Rush) |
| 6 | Stats |
| 7 | Judgment Strike (Verdict Strike) + Interception |
| 8 | Advanced draft |
| 9 | Iron Sweep (hold = Aegis Sweep) |
| 10 | Aegis Mastery + draft |
| 12* | **Shield Plant**: beyond the Lv10 cap, **Build Showcase only** |

### Core mechanics
- **Resolve (0–100):**
  - Gained from Guard (+5 per defended attack), Perfect Guard (+20, the strongest), counters (+10), interception (+15) and Guarded Strike (+3 per strike on an enemy).
  - Repeated hits from the same attack never give Resolve twice.
- **Spending choices:**
  - Empowered Shield Rush (30): reach and taunt.
  - Verdict Strike (40): one big poise hit.
  - Aegis Sweep (25): group control.
  - Guardian's Reserve (augment, 20): spent automatically on an interception to briefly protect that ally.
- **Shield Plant:**
  - Strong protection from the front and front-sides; very little knockback; 15% movement.
  - **Hits from behind land fully.** A Guard Break still breaks it.
  - It lasts 4s, with an 18s cooldown.
- **Builds:**
  - **Sentinel** holds ground: Steadfast, Shield Plant + Rolling Fortress (showcase), Phantom Bulwark, Unyielding Charge.
  - **Interceptor** saves allies: Last Line, Guardian's Return, **Guardian's Reserve**, Unyielding Charge.
  - **Retribution** punishes: Iron Reprisal, Crushing Rhythm, Verdict of Steel.

### Test V1 — Basic Frontline Feel
- **Goal:** do sword, guard, Perfect Guard and counter feel responsive and distinct?
- **Setup:** Lab → Vanguard → Fresh Level 1 → guided **V1** (one Raider).
- **Steps:**
  1. Attack with LMB and RMB.
  2. Hold Shift through two Raider attacks.
  3. Tap Shift just as the Raider's weapon comes down.
  4. Immediately press LMB.
  5. Dodge sideways.
  6. Kill one Raider defensively, then one aggressively (Restart between).
- **Expected Result:** Guard cuts frontal damage. A Perfect Guard flashes gold with the PERFECT GUARD banner, and the next LMB is a staggering counter.
- **What to Observe:** Is the Perfect Guard timing readable without sound? Does the counter feel like a reward? Can you stay active?
- **Failure Signs:** a Perfect Guard you were sure of shows nothing; the counter does not come out; you are stuck in guard pose.
- **How to Repeat:** **Restart** in the guided panel.

### Test V2 — Sentinel
- **Goal:** is defending a position different from just holding Guard?
- **Setup:** guided **V2** (Sentinel Showcase, Shield Guardian + 2 Raiders).
- **Steps:**
  1. Pick a spot and hold it.
  2. Press 1 (Shield Rush): a Phantom Bulwark dome stays where the rush ends.
  3. Press E (Shield Plant), then Space while planted (Rolling Fortress). Press E again to leave.
- **Expected Result:** the dome absorbs damage to allies inside from attackers outside. The planted step moves about 1.4m and keeps the plant.
- **What to Observe:** does position matter? Can enemies still threaten you from the side?
- **Failure Signs:** the guarded step drops the shield; the dome blocks nothing.
- **How to Repeat:** Restart.

### Test V3 — Interceptor
- **Goal:** is saving an ally controllable and rewarding?
- **Setup:** guided **V3** (Party, Raider + Ash Caster).
- **Steps:**
  1. Let the Raider target your Mage.
  2. Press 1 toward the Mage just before the hit lands.
  3. Press LMB within 1.5s.
- **Expected Result:** you take the hit instead (interception). Last Line reduces your damage taken. Guardian's Return makes the next LMB an Aegis Counter.
- **What to Observe:** can you tell who is in danger? Is the timing fair?
- **Failure Signs:** the rush goes to the enemy instead of the ally; no counter window.
- **How to Repeat:** Restart.

### Test V4 — Retribution
- **Goal:** are Resolve decisions meaningful?
- **Setup:** guided **V4** (Shield Guardian).
- **Steps:**
  1. Perfect Guard several attacks.
  2. Counter with LMB.
  3. Watch Resolve (the diamonds under your character).
  4. At 40+ Resolve, hold 2 to a full charge and release.
  5. Next time, spend Resolve early (hold 1 or hold 3) instead and compare.
- **Expected Result:** Iron Reprisal makes the heavy after a Perfect Guard wider and stronger. A full Judgment with 40 Resolve becomes **Verdict Strike** (with the Verdict of Steel augment: an even larger poise hit).
- **What to Observe:** does saving vs spending feel like a real choice?
- **Failure Signs:** Resolve never fills; Verdict does not trigger at full charge.
- **How to Repeat:** Restart.

**Common mistakes:**
- Raising Guard too early: Perfect Guard needs a fresh raise within 0.2s of the hit.
- Holding Guard after the hit, then expecting a counter: the counter window is short.

### Test VH — Guarded Strike
- **Goal:** can you fight actively from Guard instead of waiting for Perfect Guards?
- **Setup:** guided **VH** (Lv5, one Raider).
- **Steps:**
  1. Hold Shift and press LMB repeatedly while the Raider attacks.
  2. Compare with only holding Shift.
- **Expected Result:** short strikes from Guard, +3 Resolve per strike that hits. If the Raider hits you mid-swing you take more damage (narrower, weaker guard). Guard is fully back after the swing.
- **What to Observe:** is the risk readable? Is it worth doing?
- **Failure Signs:** you drop Guard after the strike while Shift is still held; Resolve rises without hitting anything.

### Test VI — Shield Plant (Build Showcase)
- **Goal:** a reinforced stance, not immunity.
- **Setup:** guided **VI** (Sentinel showcase; Shield Guardian + 2 Raiders).
- **Steps:**
  1. Press E.
  2. Let hits come from the front, the side and behind.
  3. Take the Guardian's Guard Breaker.
  4. Dodge while planted (Rolling Fortress).
  5. Press E to leave.
- **Expected Result:** strong front and side-front protection, little knockback, slow movement. Rear hits land fully. Guard Breaker breaks the plant. Leaving has a short recovery.
- **Failure Signs:** rear hits are reduced; the plant survives a Guard Break; you cannot move at all.

### Test VJ — Resolve Choices
- **Goal:** do the three spends compete?
- **Setup:** guided **VJ** (Lv10; 3 Raiders + Ash Caster).
- **Steps:**
  1. Build Resolve with Perfect Guards.
  2. Spend it on HOLD 1 (30), on a full 2 (40) and on HOLD 3 (25), against the group and against the caster.
- **Expected Result:** each spend is best in a different situation: reach / taunt, single big poise hit, group attention.
- **What to Observe:** do you think about when to spend? Is holding the key (0.35s) comfortable?

**Compared with the previous version:** Guarded Strike at Lv1; Resolve now has three spenders with costs; Shield Plant exists (showcase); Rolling Fortress now modifies Shield Plant instead of the plain guard.

---

# MAGE — The Worldweaver

**Identity:** elemental magic and primary healer. You charge spells, shape the battlefield with formations, combine elements, and keep the party alive.

**Starting abilities (Lv1):** Fire (Flame Cataclysm), Life (Life Bloom, Lifeline).

### Controls

| Input | Action |
|---|---|
| LMB / RMB / 1 (hold, release) | Charged spell slots. Release early = partial; release at full = full |
| 3 | Utility spell. Hold to aim formations |
| F | Lifeline |
| E | Arcane Sanctum (Lv5) |
| T | Cycle heal target |
| 2 | Most injured ally |
| B | Spellbook (choose spells for each slot) |
| Space | Dodge. Cancels a charge, no mana spent |

### Level 1–10
| Level | Unlock |
|---|---|
| 1 | Fire, Life, Life Bloom, Lifeline |
| 2 | Stats |
| 3 | Frost + Crystal Formation |
| 4 | Draft |
| 5 | Arcane Sanctum |
| 6 | Stats |
| 7 | Stone + Earthbreaker + Protective Renewal |
| 8 | Advanced draft |
| 9 | Storm + Thunder Conduit |
| 10 | Arcane Mastery + draft |

### Core mechanics
- **Formations:** max 2 solid per Mage (the oldest disappears), max 2 burning areas.
- **Interactions:**
  - Fire on ice = **Thermal Fracture** (fragments, or steam from a full cast).
  - Stone impact on ice = **Shattered Winter**.
  - A full Thunder Conduit passing a Stone formation makes it **Conductive** for 6s, so later chains relay through it.
  - A full Life Bloom next to a Fortified stone = **Living Bastion**.
- **Builds:**
  - **Cataclysm:** Infernal Collapse, Mountainfall, Living Thunder.
  - **Worldcraft:** Crystal Chain, Storm Lattice, Living Bastion, Wandering Sanctum.
  - **Lifebinding:** Everlasting Bloom, Second Heart, Living Bastion.
- The advanced spells (Inferno Wave, Cinderfall, Glacial Spear, Frozen Bastion, Rising Pillar, Stone Ward, Lightning Verdict, Storm Arc, Verdant Renewal, Shared Bloom) **have no level in the approved table**. You get them only through Showcase presets or Debug.

### Test M1 — Basic Spellcasting
- **Goal:** is charging fun, and do partial and full releases both have a purpose?
- **Setup:** guided **M1** (Lv1, one Wolf).
- **Steps:**
  1. Tap LMB (partial Flame).
  2. Hold LMB until the flare, then release (full).
  3. Walk while charging.
  4. Press Space mid-charge.
  5. Hold RMB to heal yourself.
  6. When low, press F.
- **Expected Result:** partial = small explosion, no area. Full = bigger explosion + a burning area. Dodge cancels with no mana spent. Lifeline heals instantly (12s cooldown).
- **What to Observe:** can you survive the wolf? Is partial worth using?
- **Failure Signs:** a tap does nothing; mana is spent on a cancel; you are stuck after a release.
- **How to Repeat:** Restart.

### Test M2 — Frost and Worldshaping
- **Goal:** does ice change the fight, and is placement intuitive?
- **Setup:** guided **M2** (Lv3, three Wolves).
- **Steps:**
  1. Hold 1 and move the camera; the blue preview follows and rotates.
  2. Release partial, then full.
  3. Watch the wolves go around the ice.
  4. Shoot LMB into the ice: once partial, once full.
- **Expected Result:** partial = 1.5m ice, full = 4m. Wolves path around it. Partial Fire = fragments; full Fire = steam that blocks sight (you cannot lock on through it).
- **What to Observe:** do you understand what you can interact with? Is steam useful or annoying?
- **Failure Signs:** wolves walk through the ice; the preview does not follow the camera.
- **How to Repeat:** Restart.

### Test M3 — Cataclysm
- **Goal:** a powerful offensive Mage without elaborate setup.
- **Setup:** guided **M3** (Cataclysm Showcase; Shield Guardian + 3 Raiders).
- **Steps:**
  1. Full Flame into the Raiders.
  2. Earthbreaker (1) on the Guardian.
  3. Watch Infernal Collapse (delayed explosion) and Mountainfall (overhead impact).
  4. Dodge in the middle of a long charge, then re-press within 2s.
- **Expected Result:** the delayed explosion comes 1s after impact. Mountainfall lands 1s after release. Arcane Mastery keeps about 40% of the charge.
- **How to Repeat:** Restart.

### Test M4 — Worldcraft
- **Goal:** are interactions worth their setup time and mana?
- **Setup:** guided **M4** (Worldcraft Showcase; 2 Ash Casters + 2 Raiders).
- **Steps:**
  1. Raise ice with LMB.
  2. Press 3 for a Stone Ward.
  3. Fully charge Thunder Conduit (hold 1) past the ward.
  4. Cast again: the chain relays through the ward.
  5. Press E and compare casts inside and outside the circle.
- **Expected Result:** a CONDUCTIVE ROUTE label appears on the stone, and later chains relay through it (twice per cast with Storm Lattice). Sanctum effects happen only for casts from inside the circle.
- **Failure Signs:** nothing happens near the stone; the Sanctum works from outside.
- **How to Repeat:** Restart.

### Test M5 — Lifebinding
- **Goal:** is healing satisfying, and do the options differ?
- **Setup:** guided **M5** (Party, Ashen Warden).
- **Steps:**
  1. Press T until the Vanguard is selected (green ring).
  2. Heal with partial and full Life Bloom.
  3. Lifeline in emergencies.
  4. Protective Renewal (3) before the boss's big hit.
  5. Switch Shared Bloom on in the Spellbook (B).
  6. Raise a Stone Ward and fully charge Life Bloom on an ally standing next to it.
- **Expected Result:** overheal turns into a shield (Second Heart). A PROTECTED banner appears. The ward becomes Vitalized (green) and heals people nearby a little.
- **How to Repeat:** Restart.

**Common mistakes:**
- Expecting the heal to go to someone else when your selected ally is out of range: it is refused on purpose.
- Charging next to wolves: use partial casts or ice.

**Compared with the previous version:**
- Natural Conductive routes (they were Debug-only before).
- Storm Lattice and Second Heart added.
- Lv10 draft added.

---

# REAVER — The Swordmaster

**Identity:** a technical swordsman. You choose the **line** of each cut, keep the right **distance**, step with **footwork**, and connect *different* cuts through **Blade Continuity**.
There is no magic, no teleport, no combo meter and no damage-for-combo bonus.

**Starting abilities (Lv1):** Forward Cut, Lateral Cut, Heavy Cut, Slip Cut.

### Controls

| Input | Action |
|---|---|
| **LMB** | **Forward Cut, always**, even while strafing with A/D |
| **Shift + A + LMB** / **Shift + D + LMB** | **Lateral Cut** left / right: wide, short, with a ~0.6m side step |
| RMB | Heavy Cut. From **Lv7**, hold = **Draw Cut** |
| Space then LMB within 0.35s | Slip Cut |
| 1 / 2 / 3 / E | Skill slots. Choose them in Skills (K). New skills fill empty slots automatically |
| F | **Final Stroke** (Lv18, showcase), only while FINAL STROKE is shown |

- The side is fixed **when you press**. Releasing or changing keys afterwards does not change the cut.
- Shift is also the Vanguard's Guard key, but the Reaver has no Guard, so they do not conflict.

**Linking:**
- Press a **different** cut during the previous cut's recovery, for example Forward → Lateral, Lateral → Heavy, or Dodge → Slip. It starts faster, and you see a gold glint and **LINK**.
- Forward → Forward is allowed but **never links** (no speed-up).
- Lateral left → right (a reversal) is not legal; you see "NO LINK". Crosswind, or Discipline once per sequence, allows it.

### Skills
| Skill | Level | What it does |
|---|---|---|
| Piercing Lunge | 3 | Forward thrust |
| **Flow Step** | 5 | ~0.7m step in the direction you hold (backwards if none). 12 stamina, 3s cooldown. **Not a dodge**: you can be hit. Stops at walls and bodies. In a link window it keeps the sequence for your next *different* cut |
| **Crosscut** | 7 | Wide diagonal, then a narrow reverse you can steer slightly. Dodge after the first hit to abandon the second |
| Draw Cut | 7 | Hold RMB |
| Tempest Flurry | 9 | Steerable multi-hit |
| Swordmaster's Discipline | 10 | One reversal link per sequence |
| **Sunder Edge** | 12* | Committed strike: heavy poise damage, more through a raised guard (never a full bypass). Long recovery if it misses |
| **Turning Edge** | 15* | Hold A or D: a short side step, then a slash. Only a real flank (≥60°) gets around a shield |
| **Final Stroke** | 18* | F, within 1.5s after: two different linked cuts both hit, **or** a Sunder Edge poise break, **or** a flank hit (Turning Edge / Slip Cut / Lunge). 25 stamina; can miss; ends the sequence |

\* Beyond the Lv10 prototype cap: available **only through Lab Build Showcases**. They are labelled in the Skills menu and are not natural unlocks.

### Level table
1 Forward / Lateral / Heavy · 2 Stats · 3 Lunge · 4 Draft · 5 Flow Step + expanded continuity · 6 Stats · 7 Crosscut + Draw Cut · 8 Advanced draft · 9 Flurry · 10 Discipline + draft · *12 Sunder Edge · 15 Turning Edge · 18 Final Stroke (showcase)*

### Builds
- **Flowblade:** Flowing Edge, Crosswind, Unbroken Line, Flow Step, Crosscut. Final Stroke from linked hits.
- **Breaker:** Sundering Verdict, Drawn Horizon, Sunder Edge. Final Stroke from a poise break.
- **Duelist:** Measured Step, Turning Steel, Needlepoint, Turning Edge. Final Stroke from a flank hit.

### Tests R1–R5
Same steps as before, with the new inputs:
- Lateral is **Shift + A/D + LMB** (R1, R2).
- R3 adds Flow Step, Crosscut and Final Stroke.
- R4 adds Sunder Edge.
- R5 adds Turning Edge.

Follow the guided panel text.

### Test RA — Directional Intent
- **Setup:** guided **RA** (Lv5, Raider).
- **Steps:**
  1. Lock on and circle the Raider holding A or D, pressing LMB.
  2. Then hold Shift + A, or Shift + D, and press LMB.
- **Expected:** step 1 gives Forward Cut only; step 2 gives a Lateral Cut to that side.
- **Observe:** is the Shift + A/D + LMB chord comfortable during a real fight? (Main question.)

### Test RB — Repetition vs Paths
- **Setup:** guided **RB** (Lv10).
- **Steps:**
  1. Reset metrics, then mash LMB for 6s.
  2. Reset, then alternate LMB / Shift+A / LMB / Shift+D / RMB for 6s.
  3. Compare the training panel.
- **Expected:** repeats never link. Paths link, and (in the automated measurement) deal about 30% more DPS.
- **Observe:** does variety feel rewarding, or just more work?

### Test RC — Flow Step
- **Setup:** guided **RC** (Lv5, 2 Raiders).
- **Steps:**
  1. Flow Step toward a Raider and into a wall.
  2. Cut, Flow Step during its recovery, then do a different cut.
- **Expected:** a short step that stops at bodies and walls. You can be hit during it. The next different cut links.

### Test RD — Crosscut
- **Setup:** guided **RD** (Lv7).
- **Steps:**
  1. Use Crosscut.
  2. Repeat, then dodge right after the first hit.
- **Expected:** two hits, or only the first one when you dodge. Damage is never duplicated.

### Test RE — Sunder Edge (Breaker showcase)
- **Steps:** Sunder Edge into the Guardian's shield, then into the Raider. Miss once.
- **Expected:** more gets through the guard than with a Heavy, with big poise damage. A miss is punished.

### Test RF — Turning Edge (Duelist showcase)
- **Steps:**
  1. Turning Edge straight at the shield.
  2. Then from its side, holding A or D.
- **Expected:** the frontal one is blocked. The flank one is not, and FINAL STROKE appears.

### Test RG — Final Stroke (Flowblade showcase)
- **Steps:**
  1. Press F with nothing open.
  2. Link LMB → Shift+A+LMB (both hit), then press F within 1.5s.
  3. Wait 2s instead.
  4. Try it out of range.
- **Expected:** refused when nothing is open; opens after the link; expires; can whiff; costs 25 stamina.

**Common mistakes:**
- Holding A/D without Shift and expecting a Lateral Cut.
- Repeating the same cut and expecting LINK.
- Expecting Draw Cut before Lv7.
- Using Turning Edge without A or D held.

---

# Cross-class scenarios (A–F)

Play each with all three classes; switch class in the Lab and press **Restart**. The enemies are unmodified.

| Scenario | Setup | Compare |
|---|---|---|
| A | One Raider | Vanguard defense / counter; Mage charging / positioning; Reaver line choice / footwork |
| B | Three Wolves | Pressure control vs route control vs close threats |
| C | Shield Guardian | Counterpressure vs Stone tools vs guard-breaking |
| D | Ash Caster | Protected approach vs Storm interruption (Lightning Verdict: Mage Cataclysm showcase) vs closing distance |
| E | Ashen Warden | Guard vs sustained healing vs DPS windows |
| F | Party (Raiders, Caster, Wolves) | Roles, synergy, AI, statuses, performance |

## Known technical limitations (all classes)
- **No sound effects exist yet.** Feedback is visual only, which makes timing-based mechanics harder to judge.
- **Characters and animations are procedural placeholders,** not final art. Attack-to-attack transitions are not crossfaded.
- **The camera can still snap once (about 0.57m)** when you walk into a tall pillar with the camera behind you. It never ends a frame inside the wall, but the jump is visible. It is not fully fixed.
- **No gamepad binding** exists yet for the Reaver's Shift modifier.
