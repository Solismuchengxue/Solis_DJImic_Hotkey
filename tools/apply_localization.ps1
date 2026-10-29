Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$installRoot = 'D:\AutoHotkey'
$backupRoot = Join-Path $projectRoot 'backups\20261029_before_changes'
$allowed = @('UX/ui-dash.ahk','UX/ui-editor.ahk','UX/ui-launcherconfig.ahk','UX/ui-newscript.ahk','UX/ui-setup.ahk','UX/ui-uninstall.ahk','UX/WindowSpy.ahk')
$manifest = @(Get-Content -LiteralPath (Join-Path $projectRoot 'localization\manifest.json') -Raw | ConvertFrom-Json)
if ($manifest.Count -ne $allowed.Count -or @($manifest.path | Select-Object -Unique).Count -ne $allowed.Count) { throw 'Unexpected patch set.' }
foreach ($entry in $manifest) {
    if ($entry.path -notin $allowed) { throw 'Unexpected target.' }
    $relative = $entry.path.Replace('/', '\')
    $current = (Get-FileHash -LiteralPath (Join-Path $installRoot $relative) -Algorithm SHA256).Hash
    $original = (Get-FileHash -LiteralPath (Join-Path $backupRoot $relative) -Algorithm SHA256).Hash
    $localized = (Get-FileHash -LiteralPath (Join-Path $projectRoot ('localization\' + $relative)) -Algorithm SHA256).Hash
    if ($current -ne $entry.original_sha256 -or $original -ne $entry.original_sha256 -or $localized -ne $entry.localized_sha256) { throw "File changed since backup: $relative" }
}
$applied = @()
try {
    foreach ($entry in $manifest) {
        $relative = $entry.path.Replace('/', '\')
        Copy-Item -LiteralPath (Join-Path $projectRoot ('localization\' + $relative)) -Destination (Join-Path $installRoot $relative)
        $applied += $entry
        if ((Get-FileHash -LiteralPath (Join-Path $installRoot $relative) -Algorithm SHA256).Hash -ne $entry.localized_sha256) { throw "Write verification failed: $relative" }
    }
} catch {
    foreach ($entry in $applied) {
        $relative = $entry.path.Replace('/', '\')
        $target = Join-Path $installRoot $relative
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $entry.localized_sha256) {
            Copy-Item -LiteralPath (Join-Path $backupRoot $relative) -Destination $target
        }
    }
    throw
}
$result = [pscustomobject]@{ Result = 'APPLIED'; FileCount = $applied.Count; Backup = $backupRoot; Targets = $allowed; ExeFilesChanged = $false; ExistingHotkeyChanged = $false }
$result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $projectRoot 'localization\applied.json') -Encoding utf8
$result | ConvertTo-Json -Depth 3
