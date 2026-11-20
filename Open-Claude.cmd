@echo off
title The Living World - Claude Code
cd /d "%~dp0"
if exist ".dev\local.json" goto project_found
cd /d "C:\Users\PC\Documents\Codex\2026-11-20\new-chat\TheLivingWorld"
if exist ".dev\local.json" goto project_found
echo ERROR: The Living World project configuration could not be found.
echo Expected project: C:\Users\PC\Documents\Codex\2026-11-20\new-chat\TheLivingWorld
pause
exit /b 1
:project_found
echo Starting Claude Code in:
echo %CD%
echo This window will stay open if startup fails.
echo.
powershell.exe -NoLogo -NoProfile -NoExit -Command "$ErrorActionPreference='Stop'; try { $c=Get-Content -LiteralPath '.dev/local.json' -Raw | ConvertFrom-Json; if (!(Test-Path -LiteralPath $c.claude)) { throw 'Claude Code executable was not found. Its installed version may have changed.' }; if ($c.git -and (Test-Path -LiteralPath $c.git)) { $env:PATH=(Split-Path -Parent $c.git)+';'+$env:PATH; $g=Split-Path (Split-Path $c.git -Parent) -Parent; foreach ($b in @((Join-Path $g 'bin/bash.exe'),(Join-Path $g 'usr/bin/bash.exe'))) { if (Test-Path -LiteralPath $b) { $env:CLAUDE_CODE_GIT_BASH_PATH=$b; break } } }; & $c.claude; Write-Host ('Claude Code exited with code: '+$LASTEXITCODE); Write-Host 'If sign-in is needed, run the login command shown above.' } catch { Write-Host ('STARTUP ERROR: '+$_.Exception.Message) -ForegroundColor Red }"
echo.
echo Claude launcher finished. Press any key to close this window.
pause >nul
