param(
    # camera_jitter_144 / camera_jitter_30: the camera suite at another fixed frame rate (the camera test
    # needs rendering faster than physics to expose jitter; 30 fps checks the frame-rate independence)
    [ValidateSet('freeflow_runner','resolution_runner','refoundation_runner','mage_runner','test_runner','update5_runner','smoke_runner','camera_jitter','camera_jitter_144','camera_jitter_30')]
    [string[]]$Suite = @('freeflow_runner','resolution_runner','refoundation_runner','mage_runner','test_runner','update5_runner','smoke_runner','camera_jitter','camera_jitter_144','camera_jitter_30'),
    [int]$TimeoutSeconds = 240
)
. "$PSScriptRoot/Config.ps1"
$godot = Resolve-DevTool 'godot' 'GODOT_BIN'
$run = Join-Path $ProjectRoot ('.dev/reports/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$version = (& $godot --version | Out-String).Trim()
$results = @()
foreach ($name in $Suite) {
    $out = Join-Path $run "$name.stdout.log"
    $err = Join-Path $run "$name.stderr.log"
    $engineLog = Join-Path $run "$name.engine.log"
    $scene = $name
    $fps = '60'
    if ($name -match '^(camera_jitter)_(\d+)$') { $scene = $Matches[1]; $fps = $Matches[2] }
    $arguments = @('--headless','--path',('"' + $ProjectRoot + '"'),'--log-file',('"' + $engineLog + '"'),'--fixed-fps',$fps,"res://tests/$scene.tscn")
    $process = Start-Process -FilePath $godot -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) { $process.Kill(); $process.WaitForExit() }
    $process.Refresh()
    $output = (Get-Content $out -Raw) + "`n" + (Get-Content $err -Raw)
    $matchesSummary = [regex]::Matches($output, '(\d+) passed, (\d+) failed')
    $passed = $null; $failed = $null
    if ($matchesSummary.Count) { $last = $matchesSummary[$matchesSummary.Count-1]; $passed = [int]$last.Groups[1].Value; $failed = [int]$last.Groups[2].Value }
    $hasErrors = $output -match '(?m)^(SCRIPT ERROR:|ERROR:|\s*FAIL[: ])'
    $success = $finished -and $process.ExitCode -eq 0 -and $null -ne $passed -and $failed -eq 0 -and -not $hasErrors
    $results += [pscustomobject]@{suite=$name; success=$success; exitCode=$process.ExitCode; timedOut=(-not $finished); passed=$passed; failed=$failed; errorsDetected=$hasErrors; stdout=$out; stderr=$err}
    Write-Host "$name : success=$success passed=$passed failed=$failed exit=$($process.ExitCode)"
}
$report = [pscustomobject]@{timestamp=(Get-Date -Format o); godot=$version; project=$ProjectRoot; results=$results}
$report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $run 'summary.json') -Encoding utf8
$lines = @('# Automated test results', '', "Godot: $version", '', '| Suite | Pass | Fail | Exit | Success |', '|---|---:|---:|---:|---|')
foreach ($r in $results) { $lines += "| $($r.suite) | $($r.passed) | $($r.failed) | $($r.exitCode) | $($r.success) |" }
$lines += @('', 'Automated functional evidence only; human playtesting is not performed.', "Logs: $run")
$lines | Set-Content (Join-Path $run 'summary.md') -Encoding utf8
Copy-Item (Join-Path $run 'summary.json') (Join-Path $ProjectRoot '.dev/reports/latest.json')
Write-Host "Report: $run"
if (@($results | Where-Object { -not $_.success }).Count) { exit 1 }
