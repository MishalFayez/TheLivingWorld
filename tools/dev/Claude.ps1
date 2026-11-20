. "$PSScriptRoot/Config.ps1"
$claude = Resolve-DevTool 'claude' 'CLAUDE_BIN'
$gitCommand = Resolve-DevTool 'git' 'GIT_BIN'
if (-not $env:CLAUDE_CODE_GIT_BASH_PATH) {
    $gitBase = Split-Path (Split-Path $gitCommand -Parent) -Parent
    foreach ($candidate in @((Join-Path $gitBase 'bin/bash.exe'),(Join-Path $gitBase 'usr/bin/bash.exe'))) {
        if (Test-Path $candidate) { $env:CLAUDE_CODE_GIT_BASH_PATH = $candidate; break }
    }
}
Push-Location $ProjectRoot
try { & $claude @args } finally { Pop-Location }
