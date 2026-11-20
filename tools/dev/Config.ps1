$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$configPath = Join-Path $ProjectRoot '.dev/local.json'
$LocalConfig = @{}
if (Test-Path -LiteralPath $configPath) {
    $parsedConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    foreach ($property in $parsedConfig.PSObject.Properties) { $LocalConfig[$property.Name] = $property.Value }
}
if ($LocalConfig['git'] -and (Test-Path -LiteralPath $LocalConfig['git'])) {
    $gitDirectory = Split-Path $LocalConfig['git'] -Parent
    if (($env:PATH -split ';') -notcontains $gitDirectory) { $env:PATH = $gitDirectory + ';' + $env:PATH }
}
function Resolve-DevTool([string]$Name, [string]$EnvironmentName) {
    $value = [Environment]::GetEnvironmentVariable($EnvironmentName)
    if (-not $value) { $value = $LocalConfig[$Name] }
    if ($value -and (Test-Path -LiteralPath $value)) { return $value }
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "Missing tool: $Name. Configure $EnvironmentName or .dev/local.json."
}
