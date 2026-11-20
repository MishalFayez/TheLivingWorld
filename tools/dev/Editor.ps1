. "$PSScriptRoot/Config.ps1"
$godot = Resolve-DevTool 'godot' 'GODOT_BIN'
Start-Process -FilePath $godot -ArgumentList @('--editor','--path',('"' + $ProjectRoot + '"')) -WindowStyle Hidden
