. "$PSScriptRoot/Config.ps1"
$folder = Join-Path $ProjectRoot '.dev/handoff'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$target = Join-Path $folder ('handoff-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.md')
$content = @('# The Living World review handoff', '', '## Git state', '```', (& git -C $ProjectRoot status --short | Out-String), (& git -C $ProjectRoot log -5 --oneline | Out-String), '```')
foreach ($file in @('AGENTS.md','collaboration/STATUS.md','collaboration/DESIGN_QUESTIONS.md')) { $content += @('', "## $file", (Get-Content (Join-Path $ProjectRoot $file) -Raw)) }
foreach ($area in @('tasks','results')) {
    Get-ChildItem (Join-Path $ProjectRoot "collaboration/$area") -Filter '*.md' | Where-Object Name -NE 'TEMPLATE.md' | ForEach-Object { $content += @('', "## $area/$($_.Name)", (Get-Content $_.FullName -Raw)) }
}
$latest = Join-Path $ProjectRoot '.dev/reports/latest.json'
if (Test-Path $latest) { $content += @('', '## Latest test evidence', '```json', (Get-Content $latest -Raw), '```') }
$content | Set-Content $target -Encoding utf8
Write-Host $target
