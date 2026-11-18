param(
    [Parameter(Mandatory)][string]$Package,
    [Parameter(Mandatory)][string]$UpstreamArchive
)

$ErrorActionPreference = 'Stop'
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Package).ProviderPath)
$upstream = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $UpstreamArchive).ProviderPath)
try {
    $files = @($archive.Entries | Where-Object Name)
    $root = @($files | Where-Object { !$_.FullName.Contains('/') } | Select-Object -ExpandProperty FullName)
    if ($root.Count -ne 1 -or $root[0] -cne 'DJI 听写.exe') {
        throw "Unexpected files at package root: $($root -join ', ')"
    }
    if ($files | Where-Object Name -eq 'AutoHotkey.chm') { throw 'The package still includes AutoHotkey.chm.' }
    foreach ($name in 'app/ui/Main.ahk','app/DJI_Mic_Hotkey.ahk','config/DJI_Mic_Hotkey.ini','docs/使用说明.html','LICENSES/GPL-2.0.txt') {
        if (!$archive.GetEntry($name)) { throw "Required package file missing: $name" }
    }
    foreach ($entry in $upstream.Entries | Where-Object { $_.Name -and ($_.FullName -ceq 'AutoHotkey64.exe' -or $_.FullName.StartsWith('UX/')) }) {
        $shipped = $archive.GetEntry('runtime/' + $entry.FullName)
        if (!$shipped) { throw "Official runtime payload missing: $($entry.FullName)" }
        $upstreamStream = $entry.Open()
        $shippedStream = $shipped.Open()
        try {
            if ((Get-FileHash -InputStream $upstreamStream).Hash -cne (Get-FileHash -InputStream $shippedStream).Hash) {
                throw "Official runtime payload changed: $($entry.FullName)"
            }
        } finally {
            $upstreamStream.Dispose()
            $shippedStream.Dispose()
        }
    }
    'PASS: single root launcher, no CHM, config path and unmodified official runtime and Dash payload.'
} finally {
    $archive.Dispose()
    $upstream.Dispose()
}
