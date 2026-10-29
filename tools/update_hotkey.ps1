Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptTarget = 'D:\AutoHotkey\DJI_Mic_Hotkey.ahk'
$configTarget = 'D:\AutoHotkey\DJI_Mic_Hotkey.ini'
$scriptSource = Join-Path $projectRoot 'DJI_Mic_Hotkey.ahk'
$backup = Join-Path $projectRoot 'backups\20261029_before_volume_fix'
$manifest = Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw | ConvertFrom-Json
$recordPath = Join-Path $projectRoot 'hotkey_applied.json'
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
foreach ($name in @('DJI_Mic_Hotkey.ahk','DJI_Mic_Hotkey.ini')) {
    $expected = $manifest.PSObject.Properties[$name].Value
    $currentExpected = if ($name -eq 'DJI_Mic_Hotkey.ahk') { $record.SourceSHA256 } elseif ($record.PSObject.Properties['ConfigSHA256']) { $record.ConfigSHA256 } else { $expected }
    if ((Get-FileHash -LiteralPath (Join-Path 'D:\AutoHotkey' $name) -Algorithm SHA256).Hash -ne $currentExpected) {
        throw "Deployed file changed after backup; preserve user edits: $name"
    }
    if ((Get-FileHash -LiteralPath (Join-Path $backup $name) -Algorithm SHA256).Hash -ne $expected) {
        throw "Backup mismatch: $name"
    }
}
$running = @(Get-CimInstance -ClassName Win32_Process -Filter "Name LIKE 'AutoHotkey%.exe'" | Where-Object { $_.CommandLine -match 'DJI_Mic_Hotkey\.ahk|test_volume_registration\.ahk|verify_composer\.ahk|compare_dictation\.ahk' })
if ($running.Count) { throw 'A binding or diagnostic is still running; do not force-replace it.' }
$sourceHash = (Get-FileHash -LiteralPath $scriptSource -Algorithm SHA256).Hash
$configHash = (Get-FileHash -LiteralPath $configTarget -Algorithm SHA256).Hash
Copy-Item -LiteralPath $scriptSource -Destination $scriptTarget
if ((Get-FileHash -LiteralPath $scriptTarget -Algorithm SHA256).Hash -ne $sourceHash) {
    throw 'Updated script hash mismatch; original remains in the verified backup.'
}
if ((Get-FileHash -LiteralPath $configTarget -Algorithm SHA256).Hash -ne $configHash) {
    throw 'Configuration changed concurrently; inspect before activation.'
}
$result = [pscustomobject]@{
    Result='UPDATED'
    Script=$scriptTarget
    Config=$configTarget
    OriginalSHA256=$record.OriginalSHA256
    OriginalBackup=$record.OriginalBackup
    PreviousBackup=$backup
    SourceSHA256=$sourceHash
    ConfigSHA256=$configHash
    ConfigPreserved=$true
    Activated=$false
}
$result | ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding utf8
$result | ConvertTo-Json
