@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -Command "$c=Get-Content -LiteralPath '.dev/local.json' -Raw|ConvertFrom-Json; & $c.powershell -NoProfile -NoExit -File 'tools/dev/Claude.ps1'"
