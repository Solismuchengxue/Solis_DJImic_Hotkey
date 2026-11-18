#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('\A[0-9a-fA-F]{7,40}\z')]
    [string]$Commit,

    [string]$UpstreamDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$zipTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)

function Invoke-BuildGit {
    & $git --no-replace-objects -C $repoRoot @args
    if ($LASTEXITCODE -ne 0) { throw "Git 命令失败（退出码 $LASTEXITCODE）：$args" }
}

function Get-BuildDirectory([string]$Path) {
    [void][IO.Directory]::CreateDirectory($Path)
    $directory = Get-Item -LiteralPath $Path -Force
    if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "打包目录不能是重解析点：$Path"
    }
    return $directory.FullName
}

function Get-ArchiveEntry([IO.Compression.ZipArchive]$Archive, [string]$Name) {
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry -or $entry.Name.Length -eq 0) { throw "归档缺少文件：$Name" }
    return $entry
}

function Read-ArchiveJson([IO.Compression.ZipArchive]$Archive, [string]$Name) {
    $entry = Get-ArchiveEntry $Archive $Name
    $reader = [IO.StreamReader]::new($entry.Open(), $utf8)
    try { return ($reader.ReadToEnd() | ConvertFrom-Json -Depth 16) } finally { $reader.Dispose() }
}

function Get-EntrySha256([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    try { return (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash } finally { $stream.Dispose() }
}

function Copy-VerifiedArchive([string]$Name, [string]$ExpectedHash) {
    if ($ExpectedHash -notmatch '\A[0-9a-f]{64}\z') { throw "发布清单缺少有效的 SHA256：$Name" }
    $inputPath = Join-Path $UpstreamDirectory $Name
    $copy = Join-Path $scratch $Name
    [IO.File]::Copy($inputPath, $copy)
    $actualHash = (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash
    if ($actualHash -ne $ExpectedHash) { throw "上游归档 SHA256 不一致：$Name（实际 $actualHash）" }
    return $copy
}

function Add-PackageFile([string]$Name, $Content) {
    foreach ($component in $Name.Split('/')) {
        if ($component.Length -eq 0 -or $component.EndsWith('.') -or $component.EndsWith(' ') -or
            $component.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
            $component -match '\A(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|\z)') {
            throw "ZIP 文件路径无法在 Windows 安全解压：$Name"
        }
    }
    if (!$packageNames.Add($Name)) { throw "ZIP 中存在重名文件：$Name" }
    if ($Content -is [IO.Compression.ZipArchiveEntry] -and (($Content.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
        throw "ZIP 不能打包符号链接：$Name"
    }
    $packageFiles.Add($Name, $Content)
}

function Write-PackageZip([string]$Path) {
    $zip = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create, $utf8)
    try {
        foreach ($file in $packageFiles.GetEnumerator()) {
            $name = $file.Key
            for ($slash = $name.LastIndexOf('/'); $slash -ge 0; $slash = $name.LastIndexOf('/', $slash - 1)) {
                if ($packageNames.Contains($name.Substring(0, $slash))) {
                    throw "ZIP 中文件与目录重名：$name"
                }
            }

            # Fixed entry order, timestamp, attributes, encoding and compression.
            $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::NoCompression)
            $entry.LastWriteTime = $zipTime
            $entry.ExternalAttributes = [int][IO.FileAttributes]::Archive
            $target = $entry.Open()
            try {
                if ($file.Value -is [IO.Compression.ZipArchiveEntry]) {
                    $source = $file.Value.Open()
                    try { $source.CopyTo($target) } finally { $source.Dispose() }
                } else {
                    $bytes = $utf8.GetBytes([string]$file.Value)
                    $target.Write($bytes, 0, $bytes.Length)
                }
            } finally { $target.Dispose() }
        }
    } finally { $zip.Dispose() }
}

$oldNoLazyFetch = $env:GIT_NO_LAZY_FETCH
$oldNoSystemAttributes = $env:GIT_ATTR_NOSYSTEM
$scratch = $null
$sourceZip = $null
$runtimeZip = $null
try {
    $env:GIT_NO_LAZY_FETCH = '1'
    $env:GIT_ATTR_NOSYSTEM = '1'
    $gitRoot = Invoke-BuildGit rev-parse --show-toplevel
    if ([IO.Path]::GetFullPath($gitRoot) -ne $repoRoot) { throw '请在原仓库的 tools 目录中使用此脚本。' }
    $sourceCommit = Invoke-BuildGit rev-parse --verify --end-of-options "$Commit^{commit}"
    if ($sourceCommit -cnotmatch '\A[0-9a-f]{40}\z' -or !$sourceCommit.StartsWith($Commit, [StringComparison]::OrdinalIgnoreCase)) {
        throw '请明确指定 Git 提交的哈希。'
    }
    $gitAttributes = Invoke-BuildGit rev-parse --path-format=absolute --git-path info/attributes
    if (Test-Path -LiteralPath $gitAttributes) { throw "请先移除会影响 git archive 的本地属性覆盖：$gitAttributes" }

    $shortCommit = $sourceCommit.Substring(0, 7)
    $tmp = Get-BuildDirectory (Join-Path $repoRoot 'tmp')
    $scratch = Get-BuildDirectory (Join-Path $tmp ('portable_build_' + [guid]::NewGuid().ToString('N')))
    $sourcePath = Join-Path $scratch 'project.zip'
    $emptyAttributes = Join-Path $scratch 'empty_attributes'
    [IO.File]::WriteAllText($emptyAttributes, '', $utf8)
    Invoke-BuildGit -c "core.attributesFile=$emptyAttributes" -c core.autocrlf=false -c core.eol=lf `
        archive --format=zip "--output=$sourcePath" $sourceCommit

    $sourceZip = [IO.Compression.ZipFile]::OpenRead($sourcePath)
    $manifest = Read-ArchiveJson $sourceZip 'release/manifest.json'
    $version = [string]$manifest.version
    $runtimeVersion = [string]$manifest.autoHotkey.version
    if ($manifest.schemaVersion -ne 1 -or $version -cnotmatch '\Av[0-9]+\.[0-9]+\.[0-9]+\z' -or
        $runtimeVersion -notmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z' -or $manifest.autoHotkey.tag -cne "v$runtimeVersion" -or
        $manifest.outputDirectory -cne 'release/<version>/<short-commit>/') {
        throw '发布清单版本或输出目录格式无效。'
    }

    $release = Get-BuildDirectory (Join-Path $repoRoot 'release')
    $versionPath = Join-Path $release $version
    $outputPath = Join-Path $versionPath $shortCommit
    if (Test-Path -LiteralPath $outputPath) { throw "候选输出已存在：$outputPath" }
    if (!$UpstreamDirectory) { $UpstreamDirectory = Join-Path $tmp 'portable_upstream' }
    $UpstreamDirectory = (Resolve-Path -LiteralPath $UpstreamDirectory).ProviderPath
    $runtimeName = "AutoHotkey_$runtimeVersion.zip"
    $sourceName = "AutoHotkey_$runtimeVersion-source.zip"
    $runtimePath = Copy-VerifiedArchive $runtimeName $manifest.autoHotkey.archiveSha256
    $upstreamSourcePath = Copy-VerifiedArchive $sourceName $manifest.autoHotkey.sourceArchiveSha256
    $runtimeZip = [IO.Compression.ZipFile]::OpenRead($runtimePath)

    $packageNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $packageFiles = [Collections.Generic.SortedDictionary[string, object]]::new([StringComparer]::Ordinal)
    Add-PackageFile 'DJI 听写.exe' (Get-ArchiveEntry $runtimeZip 'AutoHotkey64.exe')
    Add-PackageFile 'DJI 听写.ahk' "#Requires AutoHotkey v2.0`n#Include %A_ScriptDir%\app\Main.ahk`n"
    foreach ($name in @('AutoHotkey.chm', 'license.txt')) {
        Add-PackageFile $name (Get-ArchiveEntry $runtimeZip $name)
    }
    $sourceFiles = [ordered]@{
        'DJI_Mic_Hotkey.ahk' = 'DJI_Mic_Hotkey.ahk'
        '使用说明.html' = 'docs/portable_quick_start.html'
        'resources/logo.ico' = 'assets/logo.ico'
        'resources/github.png' = 'assets/github.png'
        'resources/release.json' = 'release/manifest.json'
        'THIRD_PARTY_NOTICES.md' = 'THIRD_PARTY_NOTICES.md'
        'LICENSES/GPL-2.0.txt' = 'LICENSES/GPL-2.0.txt'
        'LICENSES/Archify-MIT.txt' = 'LICENSES/Archify-MIT.txt'
    }
    foreach ($file in $sourceFiles.GetEnumerator()) {
        Add-PackageFile $file.Key (Get-ArchiveEntry $sourceZip $file.Value)
    }
    foreach ($name in @('app/Main.ahk', 'app/PortableBinding.ahk', 'config/DJI_Mic_Hotkey.ini')) {
        $null = Get-ArchiveEntry $sourceZip $name
    }
    foreach ($entry in $sourceZip.Entries) {
        if ($entry.Name.Length -gt 0 -and $entry.FullName -cmatch '\A(app|config)/') {
            Add-PackageFile $entry.FullName $entry
        }
    }
    $buildInfo = [ordered]@{ sourceCommit = $sourceCommit } | ConvertTo-Json -Compress
    Add-PackageFile 'resources/build.json' "$buildInfo`n"

    $patches = @(Read-ArchiveJson $sourceZip 'localization/manifest.json')
    $patchedFiles = [Collections.Generic.Dictionary[string, IO.Compression.ZipArchiveEntry]]::new([StringComparer]::Ordinal)
    if ($patches.Count -ne 7) { throw '应有 7 个已验证的 UX 汉化文件。' }
    foreach ($patch in $patches) {
        $name = [string]$patch.path
        if ($name -cnotmatch '\AUX/[^/]+\.ahk\z') { throw "UX 汉化路径无效：$name" }
        $original = Get-ArchiveEntry $runtimeZip $name
        $localized = Get-ArchiveEntry $sourceZip "localization/$name"
        if ((Get-EntrySha256 $original) -ne $patch.original_sha256 -or (Get-EntrySha256 $localized) -ne $patch.localized_sha256) {
            throw "UX 文件 SHA256 不一致：$name"
        }
        $patchedFiles.Add($name, $localized)
    }
    foreach ($entry in $runtimeZip.Entries) {
        if ($entry.Name.Length -eq 0 -or !$entry.FullName.StartsWith('UX/', [StringComparison]::Ordinal)) { continue }
        $name = $entry.FullName
        if ($patchedFiles.ContainsKey($name)) { Add-PackageFile $name $patchedFiles[$name] }
        else { Add-PackageFile $name $entry }
    }

    $outputStage = Get-BuildDirectory (Join-Path $scratch 'output')
    $packageName = "DJI_Dictation_${version}_windows-x64.zip"
    Write-PackageZip (Join-Path $outputStage $packageName)
    [IO.File]::Copy($upstreamSourcePath, (Join-Path $outputStage $sourceName))
    $hashLines = foreach ($name in @($sourceName, $packageName)) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $outputStage $name) -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $name"
    }
    [IO.File]::WriteAllText((Join-Path $outputStage 'SHA256SUMS.txt'), (($hashLines -join "`n") + "`n"), $utf8)

    $versionPath = Get-BuildDirectory $versionPath
    # Both parent paths were checked inside the repository. Directory.Move refuses an existing destination.
    [IO.Directory]::Move($outputStage, (Join-Path $versionPath $shortCommit))
    Write-Output $outputPath
} finally {
    if ($null -ne $runtimeZip) { $runtimeZip.Dispose() }
    if ($null -ne $sourceZip) { $sourceZip.Dispose() }
    $env:GIT_NO_LAZY_FETCH = $oldNoLazyFetch
    $env:GIT_ATTR_NOSYSTEM = $oldNoSystemAttributes
    if ($null -ne $scratch) {
        $directory = Get-Item -LiteralPath $scratch -Force
        if ($directory.Parent.FullName -eq $tmp -and !($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Remove-Item -LiteralPath $directory.FullName -Recurse -Force
        }
    }
}
