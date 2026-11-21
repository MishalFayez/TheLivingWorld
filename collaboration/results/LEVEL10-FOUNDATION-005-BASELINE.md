# LEVEL10-FOUNDATION-005 — تدقيق الأساس (Part 0)

| البند | القيمة |
|---|---|
| تاريخ التدقيق | 2026-11-21 |
| نقطة البداية | `feature/reaver-bladedancer-003` عند `9bad1ed` (آخر commit محلي وبعيد، بعد `git fetch`) |
| فرع العمل | `feature/level10-combat-augments-005` (أُنشئ من `9bad1ed`) |
| المحرك | Godot 4.7.2 |
| المواصفة | `collaboration/tasks/LEVEL10-FOUNDATION-005.md` (محفوظة حرفيًا) |

## 1. حالة Git والملفات

- لا توجد commits بعد `9bad1ed` على أي فرع Reaver، محليًا أو على origin.
- **Blade Dancer 004 غير منفّذ.** لا يوجد فرع ولا commit ولا كود لـ004. القيم الحالية هي قيم 003:
  - Forward Dance: نحو 0.9 م.
  - Lateral: نحو 0.65–0.69 م.
  - Combat Weave: جانب 1.3، أمام 1.5، خلف 2.5 م.
  - Orbit Step: نحو 40°.
  - Withdraw: نحو 0.8 م.
- الملفات غير المتتبعة: 8 ملفات `tests/*.gd.uid` فقط. لم تُمس ولن تُضاف، حسب قرار مراجعة 001.
- **الحفظ الحقيقي** (`user://living_world_save.json`):

  | البند | القيمة |
  |---|---|
  | البصمة | SHA-256 يبدأ بـ `B140323FDCAA7A68` |
  | الحجم | 3916 بايت |
  | آخر كتابة | 2026-11-21 00:37 |

  محتواه:

  | الكلاس | المستوى | الزيادات |
  |---|---|---|
  | Mage | 10 | `crystal_chain`، `living_bastion`، `mountainfall` |
  | Reaver | 10 | `crosswind`، `turning_steel`، `needlepoint` (كلها غير نشطة تحت Blade Dancer) |
  | Vanguard | 7 | `phantom_bulwark` |

  أي اختبار جديد يستخدم حفظًا معزولًا (`test_save_guard`)، ولا يُكتب الحفظ الحقيقي.
- آخر تشغيل كامل للاختبارات على هذا الكود: **1060 نجاحًا و0 فشل** (`.dev/reports/20261121-115716-510`).

## 2. الصيغ الفعلية (مصدر الحقيقة للتلميحات)

### 2.1 الإحصاءات (`StatBlock` + `BalanceConfig`)

| الإحصاء | الصيغة الفعلية | القيمة الافتراضية |
|---|---|---|
| STR | `heavy_mult = 1 + STR × str_heavy_scale`، يطبّق فقط إذا كان `is_heavy` أو `is_charged` | 0.03 لكل نقطة |
| STR | `crit_damage_total = crit_damage + STR × str_crit_damage_scale` | 0.012 لكل نقطة (1.2pp) |
| DEX | `multihit_mult = 1 + DEX × dex_multihit_scale`، يطبّق فقط إذا كانت `hits > 1`، على الإجمالي ثم يوزَّع | 0.03 لكل نقطة |
| VIT | `max_hp = base_hp + VIT × hp_per_vit` | 12 |
| FOR | `effective_armor = armor × (1 + FOR × for_defense_scale)`، والتخفيض = `A / (A + 120)` | 0.05 لكل نقطة |
| MAS | `effect_power = 1 + MAS × mas_effect_scale`، يطبّق على الحالات والشفاء المستمر عبر `scaled_by` | 0.04 لكل نقطة |

**قيمة الإحصاء** = أساس الكلاس + النمو × (المستوى − 1) + المخصّص + المعدّات + Debug.

**قوة السلاح** = `power × (1 + 0.08 × (المستوى − 1)) × (1 + power المعدّات)` (`StatPreview.weapon_power`، وهو نفس ما يستخدمه Hero).

### 2.2 الضرر (`Combatant.build_damage`)

1. `total = weapon_power × damage_mult × ctx.damage_mult`.
2. × STR إذا كانت الضربة heavy أو charged.
3. × DEX إذا كانت متعددة الضربات.
4. × حالة `damage_dealt`.
5. `amount = total × وزن الضربة` (`hit_weights`، وإلا 1/hits).
6. الحرج: `cc = crit_chance + bonuses + situational_crit`، و`cd = crit_damage_total + bonuses (+ final_hit bonus)`. القرار عشوائي (`randf`).
7. الـPoise: `poise_damage × weight × ctx.poise_mult × status poise_damage`.
8. بعدها `modify_outgoing` (خطافات الكلاس).

**الاستقبال (`take_damage`):** `amount × (1 − reduction) × damage_taken`، ثم الدرع (Ward)، ثم HP، ثم Poise (× `poise_taken`، × (1 − `poise_armor`) أثناء الهجوم).

**ضرر التعاويذ (`spell_damage`):** `weapon_power × power × damage_dealt`، والحرج بـ`crit_chance` الأساسي.

- **تصحيح بعد التدقيق:** الإطلاق **الكامل** لتعاويذ الضرر يُضرب في STR عبر `dmg_power = power_full × heavy_mult`. الإطلاق الجزئي لا يتأثر.
- DEX لا يدخل في التعاويذ.
- MAS يدخل فقط في الحالات والشفاء المستمر.
- **الشفاء المباشر** (Life Bloom وLifeline) = `weapon_power × power`، ولا يتأثر بـMAS.

**مشكلة معمارية للتلميحات:** لا توجد دالة حساب خالية من العشوائية. `build_damage` يقرر الحرج بـ`randf` ويستدعي الخطافات مباشرة. الحل في المرحلة A: فصل الحساب الحتمي إلى دالة تفصيلية واحدة يستخدمها القتال والواجهة معًا.

### 2.3 الـPoise والـStagger

| البند | القيمة |
|---|---|
| `stagger_time` | 0.85 ث، ويُضرب في `Enemy.stagger_mult` |
| مدة كسر Poise للعدو العادي (raider, wolf, ash_caster) | 0.85 ث |
| مدة كسر Poise لـShield Guardian (×1.2) | 1.02 ث |
| مدة كسر Poise لـAshen Warden (زعيم، ×0.55) | 0.47 ث |
| مضاعف `stagger_mult` للنخبة | لا يوجد (النخبة لها فقط Poise ×1.6) |
| ردود الفعل الصغيرة (`stagger_on_hit`) | تمر بنفس `stagger()` ونفس المضاعف، **ولا تميّز بين كسر Poise ورد الفعل الصغير** في نظام الحالة |
| الزعيم | `can_be_launched = false`، فلا ردود فعل صغيرة |
| مؤشر الواجهة | إشعار "POISE BROKEN" يظهر فقط من `take_poise`، **وليس** من كسر Poise عبر `take_damage` |
| نافذة الفرصة | `open_window("stagger")` موجودة لعرض الفرصة |

## 3. الكلاسات والتقدم 1–10

مستويات الـDraft الفعلية من **مسار كل كلاس**: {4: any، 8: advanced، 10: exotic}، أي 3 اختيارات لكل كلاس. أما `BalanceConfig.draft_levels = [2,4,6,8,10]` فهي قيمة عامة **غير مستخدمة** في منح الـDraft.

| المستوى | Vanguard | Worldweaver | Reaver (Blade Dancer) |
|---|---|---|---|
| 1 | Guard، Perfect Guard، Aegis Counter، Guarded Strike | Fire + Life، Flame Cataclysm، Life Bloom، Lifeline | Dance، Edge، Combat Weave |
| 2 | نقاط | نقاط | نقاط |
| 3 | Shield Rush | Frost (Crystal Formation) | Q: Orbit Step / Withdraw |
| 4 | **Draft** | **Draft** | **Draft** |
| 5 | Resolve Spending | Arcane Sanctum (E) | E: Whirling Assault / Breaking Point |
| 6 | نقاط | نقاط | نقاط |
| 7 | Judgment Strike، **Interception** | Stone، Protective Renewal | Blade Dancer Mastery |
| 8 | **Draft (Advanced)** | **Draft (Advanced)** | **Draft (Advanced)** |
| 9 | Iron Sweep | Storm | — |
| 10 | Aegis Mastery + **Draft** | Arcane Mastery + **Draft** | **Draft** |

نقاط الإحصاء: 2 لكل مستوى، أي 18 نقطة عند المستوى 10.

### 3.1 التفاعلات العنصرية الفعلية (Worldweaver)

| التفاعل | الشرط | متاح من المستوى |
|---|---|---|
| `thermal_fracture` | Fire على Ice | 3 |
| `living_bastion` | Life على تشكيل | 3 |
| `shattered_winter` | Stone على Ice | 7 |
| `conductive_anchors` / `conductive_route` | Storm | 9 |

### 3.2 أزرار Worldweaver الحالية

| الزر | الوظيفة |
|---|---|
| LMB / RMB / 1 | التعاويذ المشحونة |
| 2 | تحديد الحليف الأكثر إصابة |
| 3 | Utility |
| F | Lifeline |
| E | Sanctum |
| T | تبديل هدف الشفاء |
| Space | مراوغة |

**مفاتيح حرة للساحر:** Q (يستخدمه Reaver فقط) و V (غير مربوط إطلاقًا).

## 4. الزيادات الحالية

| الكلاس | العدد | الملاحظة |
|---|---:|---|
| Vanguard | 10 | |
| Mage | 17 | |
| Reaver | 23 | منها 3 لـBlade Dancer: `relentless_dance`، `perfect_edge`، `twin_tempest` |

- حد "3 Major Mutations" (`max_equipped_mutations`) يطبّق فقط على فئة `mutation`.
- الحصرية حاليًا عبر `params.exclusive_group` و`params.excludes`.
- لا توجد حقول `path_id` أو `synergy_partners` أو `trigger_summary` أو `cooldown` أو `scaling_sources`.

## 5. حواجز واكتشافات تؤثر على الـ60 زيادة

1. **M-F06 Purifying Confluence:** لا يوجد في اللعبة أي حالة سلبية يطبّقها عدو على الأبطال (لا استدعاء `statuses.add` من الأعداء). الزيادة لن تجد ما تزيله، فتصبح بطاقة ميتة. **حاجز تصميمي:** تحتاج تعريف حالة سلبية "صغرى" قابلة للإزالة.
2. **M-F04 Healing Ember:** لا يوجد تأثير دعم للحلفاء مبني على Fire في Worldweaver المعتمد (الدعم كله Life، وLiving Bastion هو Life على تشكيل). المواصفة نفسها تقول: أبلغ عن المتطلب الناقص ولا تخترع مهارة. **حاجز تصميمي.**
3. **زيادات الاعتراض (Interception) لـVanguard** (V-C01، V-C03، V-C05، V-B06، V-K06): الاعتراض يُفتح في المستوى 7. ستكون غير مؤهلة في Draft المستوى 4 حسب القاعدة 10، ومتاحة في 8 و10.
4. **G05 Near Miss:** لا يوجد كاشف جاهز. يمكن بناء كاشف موثوق: عند انتهاء المرحلة النشطة لهجوم عدو، بطل داخل مدى الهجوم + هامش وداخل قوسه، لم يُصب، ولا يراوغ، وليس في i-frames. يُنفَّذ بهذا الشكل، وإذا ظهر أنه غير موثوق يُستبعد ويُبلَّغ عنه.
5. **"Mage" في G01:** تُفسَّر على أنها Worldweaver (الكلاس الحالي للساحر).
6. **R-C05 Blade Reflex:** المواصفة لا تحدد قيم الضربة البديلة. ستستخدم ضرر الهجوم العادي للوضع الحالي، بحركة مختلفة، دون مضاعف إضافي، وتُسجَّل كسؤال.

## 6. خطة التنفيذ حسب المراحل

| المرحلة | المحتوى |
|---|---|
| A | دالة تفصيل ضرر واحدة يستخدمها القتال والواجهة، ولوحة ألوان الإحصاءات، وتلميحات المهارات والزيادات بثلاثة مستويات، ومعاينة قبل/بعد. |
| B | تحسينات Blade Dancer 004، وعجلتا التعاويذ (Q للزر الأيسر، V للأيمن، قابلتان لإعادة الربط)، وتدقيق Poise/Stagger وتعديل المدد حسب نوع العدو. |
| C | حقول المسار والتآزر في `AugmentData`، وقواعد الأهلية، وتركيب Draft المستويات 4/8/10، والتوافق مع الحفظ. |
| D | الزيادات القابلة للتنفيذ من الـ60 (الحاجزان أعلاه لا يدخلان الـDraft)، والتآزرات، وآلية الاستبدال. |
| E | الاختبارات الكاملة، ومقارنة التوازن، ودليل اللعب. |

كل مرحلة في commit منفصل. لا PR ولا دمج.
