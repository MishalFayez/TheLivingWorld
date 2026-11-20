param([string]$RepositoryName = 'TheLivingWorld')
. "$PSScriptRoot/Config.ps1"
$gh = Resolve-DevTool 'gh' 'GH_BIN'
$git = Resolve-DevTool 'git' 'GIT_BIN'
& $gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Sign in first using: gh auth login --web --git-protocol https. Then rerun this script.' }
$owner = (& $gh api user --jq .login | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $owner -notmatch '^[a-zA-Z0-9-]+$') { throw 'Cannot verify GitHub account.' }
if ($RepositoryName -notmatch '^[a-zA-Z0-9_.-]+$') { throw 'Invalid repository name.' }
$repo = "$owner/$RepositoryName"
$expected = "https://github.com/$repo.git"
$remote = (& $git -C $ProjectRoot remote get-url origin 2>$null | Out-String).Trim()
if ($remote -and $remote -ne $expected) { throw "Origin already points elsewhere: $remote. It was not changed." }
$existing = & $gh repo view $repo --json nameWithOwner,visibility 2>$null
$exists = $LASTEXITCODE -eq 0
if ($exists -and -not $remote) { throw "Repository $repo already exists. Review ownership and contents before attaching; no remote was changed." }
if (-not $exists) {
    if ($remote) { throw 'Remote exists but GitHub repository cannot be verified; check access.' }
    & $gh repo create $repo --private --source $ProjectRoot --remote origin
    if ($LASTEXITCODE -ne 0) { throw 'Private repository creation failed.' }
}
$verified = & $gh repo view $repo --json nameWithOwner,visibility | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $verified.visibility -ne 'PRIVATE' -or $verified.nameWithOwner -ne $repo) { throw 'Private visibility not verified. Nothing pushed.' }
& $gh auth setup-git
if ($LASTEXITCODE -ne 0) { throw 'Git credential integration failed.' }
& $git -C $ProjectRoot push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'Push failed.' }
$local = (& $git -C $ProjectRoot rev-parse main | Out-String).Trim()
$remoteHead = (& $git -C $ProjectRoot ls-remote origin refs/heads/main | Out-String).Trim().Split()[0]
if ($local -ne $remoteHead) { throw 'Remote main does not match local main.' }
Write-Host "Verified PRIVATE repository and matching main: https://github.com/$repo"
