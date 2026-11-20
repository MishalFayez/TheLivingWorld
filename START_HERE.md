# بيئة تطوير العالم الحي

المجلد الذي يحتوي هذا الملف هو نسخة العمل الرسمية لهذه البيئة. افتح project.godot هنا، وشغّل Claude من هذا المجلد ليتعامل مع الملفات مباشرة.

## تشغيل الأدوات

من PowerShell داخل المشروع:

```powershell
& ./tools/dev/Editor.ps1
& ./tools/dev/Claude.ps1
& ./tools/dev/Test.ps1
& ./tools/dev/Test.ps1 -Suite smoke_runner,resolution_runner
& ./tools/dev/Handoff.ps1
& ./tools/dev/Doctor.ps1
```

تشغيل Claude أول مرة قد يتطلب تسجيل الدخول والموافقة على الثقة بهذا المجلد. لا تستخدم تجاوز الصلاحيات. الإعدادات المحلية في .dev/local.json مستثناة من Git؛ ويمكن استخدام GODOT_BIN وCLAUDE_BIN وGIT_BIN بدلًا منها.

للتشغيل بالنقر المزدوج: Open-Claude.cmd وOpen-Godot.cmd وRun-Tests.cmd.

## التعاون

مشعل وChatGPT يحددان التصميم. Claude ينفذ مهمة معتمدة فقط حسب AGENTS.md وCLAUDE.md. القوالب في collaboration/tasks وcollaboration/results. تقارير الاختبار المحلية في .dev/reports. أمر Handoff يجمع حالة Git والمهمات والنتائج في ملف للمراجعة.

تبادل الملفات هنا لا ينشئ اتصالًا تلقائيًا بين المحادثات. هذه المحادثة المحلية تستطيع قراءة المشروع؛ عند استخدام محادثة أخرى أرفق تقرير Handoff أو افتح المشروع في جلسة محلية.

## GitHub

حالة الربط الفعلية موثقة في collaboration/results/ENVIRONMENT_SETUP.md. وجود Git محليًا لا يعني أن نسخة احتياطية رُفعت إلى GitHub. لا ترفع أي محتوى قبل التحقق من أن المستودع خاص.

بعد توفر GitHub CLI وتسجيل الدخول، شغّل tools/dev/GitHub.ps1. ينشئ مستودع TheLivingWorld الخاص، يتحقق من الخصوصية قبل الرفع، ثم يطابق بصمة الفرع المحلي مع GitHub. يتوقف إذا وجد مستودعًا سابقًا يحتاج مراجعة.
