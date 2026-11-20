# نتيجة المهمة: ENV-002-GITHUB

الحالة: مكتملة للمراجعة — رُفع `main` والوسم إلى المستودع الخاص وتطابقت البصمات.
الفرع والالتزام: `main` عند `38da0aa04b15db9b15c5b164463442726946f024` محليًا وبعيدًا عند الرفع. هذا الملف وتحديثات STATUS.md وENVIRONMENT_SETUP.md التُزمت ورُفعت لاحقًا في التزام توثيق مستقل فوق `38da0aa` بتفويض المستخدم.
التاريخ: 20 نوفمبر 2026. الجلسة: Claude Code في تطبيق Claude لسطح المكتب.

## التغيير

لا تغيير في ملفات اللعبة أو الاختبارات أو التصميم. التغييرات البيئية فقط:

- GitHub CLI محمول في `.dev/tools/gh/` (مستثنى من Git عبر `.gitignore:14`).
- مساعد اعتماد محلي للمستودع فقط في `.git/config` (غير متتبع).
- `.dev/tools/gh-login.ps1`: مشغّل تسجيل دخول لم يُستخدم فعليًا (سياسة تنفيذ السكربتات منعته)؛ مستثنى من Git، ويمكن حذفه.
- لم يُنشأ `~/.gitconfig` ولم تتغير إعدادات Git العامة أو النظام أو سياسات Windows أو إعدادات TLS.

## GitHub CLI

- غير موجود مسبقًا (لا في PATH ولا في مسارات التثبيت المعتادة).
- الإصدار: `gh_2.105.0_windows_amd64.zip` من https://github.com/cli/cli/releases/tag/v2.105.0 (أحدث إصدار غير تجريبي، منشور 2026-11-18)، الحجم 15,212,614 بايت.
- SHA-256 مطابق لـ`gh_2.105.0_checksums.txt` الرسمي: `8813a72c899900afaa10e3fec8fbc64b908c89dbfe837e95ed2fa500fc140627`.
- توقيع Authenticode لـ`gh.exe`: `Valid`، الموقّع `CN="GitHub, Inc."`.
- `gh --version` → `gh version 2.105.0 (2026-11-17)`.

## المصادقة

الأمر المستخدم في كل محاولة (stdin غير تفاعلي، فلا يظهر سؤال "Authenticate Git with your GitHub credentials?" ولا يُعدّل إعداد Git):

```
$null | .dev/tools/gh/bin/gh.exe auth login --hostname github.com --git-protocol https --web
```

| المحاولة | الرمز | النتيجة |
|---|---|---|
| 1 (تبويب طرفية تفاعلي) | — | توقف عند سؤال Git؛ ألغي قبل التفويض. |
| 2 (تبويب طرفية عبر سكربت) | — | رُفض: `running scripts is disabled on this system`. لم تُغيَّر سياسة التنفيذ. |
| 3 | 44CF-8E20 | `failed to authenticate via web browser: context deadline exceeded` عند 12:05. |
| 4 | 4BC1-37E0 | أكدت صفحة GitHub `Your device is now connected`، لكن gh انتهى بـ`context deadline exceeded` عند 12:21. |
| 5 (مع `GODEBUG=http2client=0` للعملية فقط) | 75FB-ACE0 | `✓ Authentication complete` و`✓ Logged in as MishalFayez`، كود الخروج 0. |

تشخيص المحاولة 4 (دليل وليس إثباتًا قاطعًا للسبب):

- عملية gh (PID 18320) حيّة، زمن المعالج ثابت عند 0.125 ثانية خلال عينة 15 ثانية، واتصال TCP واحد قائم (منفذ محلي 51141) إلى `64:ff9b::14e9:5391:443` (عنوان GitHub عبر NAT64). gh يستطلع كل ~5 ثوانٍ عادةً، فالثبات يشير إلى طلب HTTP معلق لم يرجع.
- الشبكة نفسها سليمة: `gh api /zen` برمز وهمي أعاد `401 Bad credentials` فورًا، وطلب مباشر إلى `https://github.com/login/oauth/access_token` برمز وهمي أعاد 404 خلال 913ms، و`Test-NetConnection github.com -Port 443` = True، ولا يوجد proxy في البيئة.
- الاستنتاج المرجّح: التفويض في المتصفح تم، لكن عملية gh علقت على اتصال HTTP/2 عبر NAT64 فلم تستلم الرمز. إعادة المحاولة مع HTTP/1.1 للعملية فقط نجحت. لم يُتحقق من السبب الجذري في طبقة الشبكة.

نتيجة `gh auth status --hostname github.com` (الرمز مقنّع ولم يُطبع أو يُقرأ):

- `Logged in to github.com account MishalFayez (keyring)`؛ Active account: true؛ Git operations protocol: https.
- Token scopes: `'gist', 'read:org', 'repo'` (النطاقات الافتراضية لـgh؛ لم تُطلب نطاقات إضافية).
- `gh api user --jq .login` → `MishalFayez`.
- gh كتب `config.yml` و`hosts.yml` في `%APPDATA%\GitHub CLI` (الرمز في keyring الخاص بـWindows). لم تُقرأ محتوياتهما.

## مساعد الاعتماد (محلي للمستودع فقط)

في `.git/config` بالترتيب:

```
credential.https://github.com.helper = ""     (يصفّر قائمة المساعدات الموروثة، ومنها manager على مستوى النظام)
credential.https://github.com.helper = !C:/Users/PC/Documents/Codex/2026-11-20/new-chat/TheLivingWorld/.dev/tools/gh/bin/gh.exe auth git-credential
```

قبل إضافة التصفير، فشل `git ls-remote` بـ`fatal: Cannot prompt because user interactivity has been disabled.` لأن `credential.helper=manager` على مستوى النظام كان يُستدعى أولًا. ملاحظة تنفيذية: Windows PowerShell 5.1 يُسقط الوسيط الفارغ `''`، فاستُخدم `'""'`.

`~/.gitconfig` غير موجود قبل المهمة وبعدها.

## التحقق قبل الرفع

`gh repo view MishalFayez/TheLivingWorld --json ...`:
`{"isEmpty":true,"isPrivate":true,"nameWithOwner":"MishalFayez/TheLivingWorld","viewerPermission":"ADMIN","visibility":"PRIVATE"}`

`git ls-remote origin` → لا مراجع (exit 0)، فلا يوجد تاريخ بعيد متعارض.

## الرفع (دون force)

```
git push origin refs/heads/main:refs/heads/main
 * [new branch]      main -> main                     exit 0
git push origin refs/tags/baseline-design-resolution-2026-11-20:refs/tags/baseline-design-resolution-2026-11-20
 * [new tag]         baseline-design-resolution-2026-11-20 -> baseline-design-resolution-2026-11-20   exit 0
```

لم يُضبط upstream للفرع المحلي.

## مطابقة البصمات

| المرجع | محلي | بعيد (`git ls-remote origin`) | تطابق |
|---|---|---|---|
| `refs/heads/main` | `38da0aa04b15db9b15c5b164463442726946f024` | `38da0aa04b15db9b15c5b164463442726946f024` | نعم |
| `refs/tags/baseline-design-resolution-2026-11-20` (وسم خفيف) | `1d5d336eb2fcea22698cf0983672b38cb3744bb5` | `1d5d336eb2fcea22698cf0983672b38cb3744bb5` | نعم |
| `HEAD` البعيد | — | `38da0aa…` | — |

بعد الرفع: `{"defaultBranchRef":{"name":"main"},"isEmpty":false,"isPrivate":true,"visibility":"PRIVATE"}`.

الالتزامات المرفوعة تشمل `cf1062c` و`38da0aa`؛ لم يُعدَّل أو يُعاد كتابة أي التزام. `git status` نظيف بعد الرفع.

## القيود

- لم يُفحص محتوى المستودع البعيد في المتصفح؛ التحقق عبر API وls-remote فقط.
- لم يُشغَّل `tools/dev/GitHub.ps1` (المحدَّث في `38da0aa`)؛ الرفع نُفذ بأوامر git مباشرة. لم يُراجع محتواه في هذه المهمة.
- مسار مساعد الاعتماد مطلق؛ نقل المجلد يتطلب تحديثه.
- `GODEBUG=http2client=0` استُخدم لعملية تسجيل الدخول فقط. العمليات اللاحقة (`gh api` و`git push` عبر مساعد gh) نجحت دونه.
- لم تُشغَّل اختبارات Godot؛ لم تتغير شيفرة اللعبة.

## قرارات مطلوبة

1. (حُسم: التزام هذا الملف ورفعه بتفويض المستخدم.)
2. هل يُحذف `.dev/tools/gh-login.ps1` غير المستخدم وأرشيف `.dev/tools/_download/`؟ كلاهما مستثنى من Git.
3. هل يُضبط تتبّع upstream (`main` → `origin/main`) محليًا؟
