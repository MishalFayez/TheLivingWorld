# LEVEL10-FOUNDATION-005 — ChatGPT Review 1 (gap closure)

- **Status:** APPROVED REVIEW INSTRUCTIONS (ChatGPT, pasted into the Claude Code chat on 2026-11-21)
- **Branch:** `feature/level10-combat-augments-005` (continued)
- **No PR, no merge.**

Stored verbatim as received.

---

ChatGPT Review — LEVEL10-FOUNDATION-005
I reviewed your implementation report, catalog, design questions, and the relevant GitHub implementation.
Verdict: Strong technical progress. Not yet approved as a complete Level 1–10 release candidate.
Keep the completed work. Do not redesign the three classes or their approved paths.
1. Resolve the incomplete Augments

* M-F04 Healing Ember and M-F06 Purifying Confluence are currently unobtainable.
* Do not introduce new Mage mechanics just to make these cards work.
* Keep them in the future-design backlog and exclude them from the claim of playable cards.
* Audit all remaining 58 cards for actual eligibility and usefulness at levels 1–10.
* If any additional card is unreachable or cannot deliver its stated effect, report and exclude it from the playable pool.

Do not replace missing cards with generic +damage bonuses.
2. Resolve incomplete effects

* G04 Calculated Risk must not show a misleading partial effect for Mage. Keep Mage excluded unless the specified miss/recovery tradeoff can be implemented correctly.
* Review all described synergy pairs.
* In particular, Crossroads + Living Confluence must not be described as a meaningful gameplay synergy if the only difference is color. Either implement the already approved mechanical interaction correctly or downgrade its label to visual feedback. Do not invent another effect.

3. Complete the balance verification
Run the missing Level 1–10 balance comparison.
Cover the approved progression milestones, solo and party scenarios, normal/elite/boss encounters, and builds with zero, one, or three Augments.
Measure:

* Damage and practical attack uptime.
* Effective healing and support.
* Vanguard protection and threat.
* Stamina/mana efficiency.
* Poise Break frequency.
* Augment trigger frequency.
* Synergy value versus non-synergy alternatives.
* Actual player control and enemy counterplay.

Use deterministic test conditions.
Flag cards that are effectively useless, excessively niche, universally superior, or capable of loops.
Tune numeric values within the approved adjustment limits, document all changes and rerun tests.
Do not replace an Augment's intended mechanic with a passive statistic.
4. Preserve the owner's save
Do not alter or migrate the real save.
Provide a safe, clearly labeled, non-saving fresh Level 1–10 playtest route for each class.
The player must be able to experience the Level 4, 8 and 10 drafts with the new Augments without modifying existing character progress.
Verify that returning to the title discards test-session changes.
5. Verify presentation
Confirm that:

* Stat colors match their actual formulas.
* Skill and Augment values match runtime behavior.
* Shift and advanced tooltips are readable.
* Before/after previews are accurate.
* Synergy descriptions state the exact mechanical benefit.
* Blocked, unavailable or inactive Augments are clearly distinguished.

Do not claim the in-combat HUD has hover tooltips unless implemented.
6. Testing and delivery
Keep work on `feature/level10-combat-augments-005`, or a new review-fix branch based on it.
Preserve all uncommitted files.
Run the full regression suite.
Produce:

1. An Arabic gap-closure report.
2. A balance comparison table.
3. An eligibility audit covering every playable Augment.
4. A tested synergy matrix.
5. A safe fresh-character Level 1–10 playtest guide.
6. Exact commits and remaining limitations.

Commit and push without force.
Do not open a PR or merge into main.
Success criterion: A fresh character can reach Level 10, receive meaningful Augment choices, build toward either class path, understand the numeric consequences of each choice, and play without encountering broken or misleading card effects.
Do not report the package as fully complete if any required verification remains undone.
