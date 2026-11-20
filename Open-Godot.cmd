@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -Command "$c=Get-Content -LiteralPath '.dev/local.json' -Raw|ConvertFrom-Json; & $c.powershell -NoProfile -File 'tools/dev/Editor.ps1'"
