param([switch]$Enable)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Enable) { throw 'Explicit -Enable is required after approval of persistent all-device Volume_Up interception.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptTarget = 'D:\AutoHotkey\DJI_Mic_Hotkey.ahk'
$configTarget = 'D:\AutoHotkey\DJI_Mic_Hotkey.ini'
$recordPath = Join-Path $projectRoot 'hotkey_applied.json'
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $scriptTarget -Algorithm SHA256).Hash -ne $record.SourceSHA256) { throw 'Deployed script changed; preserve user edits.' }
if ((Get-FileHash -LiteralPath $configTarget -Algorithm SHA256).Hash -ne $record.ConfigSHA256) { throw 'Deployed configuration changed; preserve user edits.' }
$running = @(Get-CimInstance -ClassName Win32_Process -Filter "Name LIKE 'AutoHotkey%.exe'" | Where-Object { $_.CommandLine -match 'DJI_Mic_Hotkey\.ahk|test_volume_registration\.ahk|verify_composer\.ahk|verify_final_binding\.ahk' })
if ($running.Count) { throw 'A binding or temporary test is still running; wait for it to exit.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $projectRoot ('backups\' + $stamp + '_before_enable')
New-Item -ItemType Directory -Path $backup -ErrorAction Stop | Out-Null
$backupConfig = Join-Path $backup 'DJI_Mic_Hotkey.ini'
Copy-Item -LiteralPath $configTarget -Destination $backupConfig
if ((Get-FileHash -LiteralPath $backupConfig -Algorithm SHA256).Hash -ne $record.ConfigSHA256) { throw 'Configuration backup mismatch.' }
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class DjiIni {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool WritePrivateProfileString(string section, string key, string value, string path);
}
'@
$started = $null
$changedConfigHash = $null
$logPath = Join-Path $projectRoot ('tmp\active_binding_' + $stamp + '.tsv')
try {
    if (-not [DjiIni]::WritePrivateProfileString('Behavior','BlockVolumeUp','1',$configTarget)) { throw 'Unable to save explicit all-device interception setting.' }
    $changedConfigHash = (Get-FileHash -LiteralPath $configTarget -Algorithm SHA256).Hash
    $started = Start-Process -FilePath 'D:\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList @('/ErrorStdOut=UTF-8',$scriptTarget,('--log=' + $logPath)) -WindowStyle Hidden -PassThru
    $startupWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $ready = $false
    do {
        $started.Refresh()
        if ($started.HasExited) { break }
        $startup = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
        $ready = $startup -match '\tvolume_block_started\tALL_DEVICES' -and $startup -match '\tstarted\t'
        if ($ready) { break }
        Start-Sleep -Milliseconds 50
    } while ($startupWatch.ElapsedMilliseconds -lt 5000)
    if (-not $ready) { throw 'No successful startup evidence; rolling back this activation.' }
    $record.ConfigSHA256 = $changedConfigHash
    $record.ConfigPreserved = $false
    $record.Activated = $true
    $record | Add-Member -NotePropertyName ActivationPID -NotePropertyValue $started.Id -Force
    $record | Add-Member -NotePropertyName ActivationLog -NotePropertyValue $logPath -Force
    $record | Add-Member -NotePropertyName ActivationConfigBackup -NotePropertyValue $backupConfig -Force
    $record | ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding utf8
    [pscustomobject]@{ Result='ACTIVATED'; PID=$started.Id; VolumeUp='ALL_DEVICES_BLOCKED'; WindowsAutoStartConfigured=$false; ConfigBackup=$backupConfig; Log=$logPath } | ConvertTo-Json
} catch {
    if ($null -ne $started -and -not $started.HasExited) { Stop-Process -Id $started.Id -ErrorAction SilentlyContinue }
    if ($changedConfigHash -and (Get-FileHash -LiteralPath $configTarget -Algorithm SHA256).Hash -eq $changedConfigHash) { Copy-Item -LiteralPath $backupConfig -Destination $configTarget }
    throw
}
