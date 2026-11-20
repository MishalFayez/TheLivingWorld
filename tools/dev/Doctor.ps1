. "$PSScriptRoot/Config.ps1"
foreach ($name in @('godot','claude','git','gh')) {
    try {
        $tool = Resolve-DevTool $name ($name.ToUpper() + '_BIN')
        $version = (& $tool --version | Select-Object -First 1)
        Write-Host "$name : $version [$tool]"
    } catch { Write-Warning $_.Exception.Message }
}
Write-Host 'Git:'
& git -C $ProjectRoot status --short
& git -C $ProjectRoot remote -v
$claude = Resolve-DevTool 'claude' 'CLAUDE_BIN'
Push-Location $ProjectRoot
try { & $claude auth status } finally { Pop-Location }
Write-Host 'Authentication status does not prove an implementation session has succeeded.'
