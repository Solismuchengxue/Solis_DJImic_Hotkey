Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptTarget = 'D:\AutoHotkey\DJI_Mic_Hotkey.ahk'
$configTarget = 'D:\AutoHotkey\DJI_Mic_Hotkey.ini'
$original = Join-Path $projectRoot 'backups\20261029_before_changes\DJI_Mic_Hotkey.ahk'
$baseline = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
if ((Get-FileHash -LiteralPath $scriptTarget -Algorithm SHA256).Hash -ne $baseline) { throw 'Existing script changed; preserve user edits.' }
if (Test-Path -LiteralPath $configTarget) { throw 'Existing configuration must be preserved; inspect before updating.' }
$running = @(Get-CimInstance -ClassName Win32_Process -Filter "Name LIKE 'AutoHotkey%.exe'" | Where-Object CommandLine -Like '*D:\AutoHotkey\DJI_Mic_Hotkey.ahk*')
if ($running.Count) { throw 'Existing hotkey instance is running; do not force-replace it.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'DJI_Mic_Hotkey.ini') -Destination $configTarget
Copy-Item -LiteralPath (Join-Path $projectRoot 'DJI_Mic_Hotkey.ahk') -Destination $scriptTarget
foreach ($name in @('DJI_Mic_Hotkey.ahk','DJI_Mic_Hotkey.ini')) {
    if ((Get-FileHash -LiteralPath (Join-Path 'D:\AutoHotkey' $name) -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $projectRoot $name) -Algorithm SHA256).Hash) { throw "Verification failed: $name" }
}
$result = [pscustomobject]@{ Result='APPLIED'; Script=$scriptTarget; Config=$configTarget; OriginalSHA256=$baseline; OriginalBackup=$original; SourceSHA256=(Get-FileHash -LiteralPath $scriptTarget -Algorithm SHA256).Hash }
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectRoot 'hotkey_applied.json') -Encoding utf8
$result | ConvertTo-Json
