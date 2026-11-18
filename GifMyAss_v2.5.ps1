<#
.SYNOPSIS
Converts animated image/video files to AVIF or animated WebP.

.DESCRIPTION
Builds FFmpeg (or gif2webp) commands from interactive settings, previews them,
then asks before executing. Input may be one file or a directory.

.PARAMETER InputPath
File or directory to convert. Directory mode includes the extensions listed in
$videoExt; a file passed directly is used regardless of its extension.

.PARAMETER Help
Print usage instructions and exit.

.PARAMETER Default
Print the current configured defaults and exit.

.PARAMETER Gif2WebP
Use Google's gif2webp utility instead of FFmpeg. Only GIF files are accepted.

.PARAMETER GetFPS
Print frame rates for one or more files or directories. A directory includes the
same media extensions supported by directory conversion mode, then exit.

.PARAMETER OutputDir
Override the configured output folder for this run.

.PARAMETER Parallel
Run up to this many WebP/gif2webp conversions at once when using PowerShell 7+.
AVIF jobs run serially because the selected AV1 encoders already use multiple cores.

.EXAMPLE
.\GifMyAss.ps1 .\animation.gif

.EXAMPLE
.\GifMyAss.ps1 .\input-folder -OutputDir .\converted
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$InputPath,

    [switch]$Help,
    [switch]$Default,
    [switch]$Gif2WebP,
    [switch]$GetFPS,
    [string]$OutputDir,
    [ValidateRange(1, 32)]
    [int]$Parallel = 1
)

Write-Host "Made by _BrightDarkness_ v2.5 with FFmpeg and gif2webp`n"

# Shared defaults are used both by the prompts and when building conversion commands.
# Values are strings because they are passed to external programs as command-line arguments.
$cfg = [ordered]@{
    FPS          = 'source'     # 'source' = keep the input frame rate
    scale        = '-1:-1'      # -1:-1 = no scaling
    flags        = 'lanczos'    # scaler; try bicubic if transparent edges show halos
    alpha        = 'auto'       # auto / on / off
    pixfmt       = 'yuv420p'    # AVIF color format when alpha is used; 420 is smaller, 444 preserves colored edges better
    CRF          = '20'         # AV1 quality level: lower is higher quality/larger; 0 is lossless
    preset       = '6'          # SVT-AV1 speed/quality trade-off, used for AVIF without alpha
    cpuused      = '6'          # libaom speed/quality trade-off, used for AVIF with alpha
    lossless     = '0'          # WebP encoder switch: 1=lossless, 0=lossy
    compression  = '4'          # WebP compression effort: higher is slower but usually smaller
    qscale       = '75'         # WebP lossy visual quality, from 0 to 100
    gif2webpq    = '80'         # gif2webp quality/effort value; interpretation depends on mode
    gif2webpm    = '4'          # gif2webp compression method, from 0 (fast) to 6 (slow)
    gif2webpmode = 'lossless'   # lossless / lossy / mixed
    outputDIR    = 'Z:\Dropbox\Pictures\raw\GifMyAss\Output'
}

# An explicit command-line output folder takes precedence over the built-in default.
if (-not [string]::IsNullOrWhiteSpace($OutputDir)) { $cfg.outputDIR = $OutputDir.Trim().Trim('"') }

# Extensions picked up in directory mode; a single file passed explicitly is never filtered.
$videoExt = '.gif', '.apng', '.mp4', '.m4v', '.mov', '.mkv', '.webm', '.avi', '.wmv', '.flv', '.mpg', '.mpeg', '.ts', '.m2ts', '.3gp'

# Prompt text and supported formats are kept together so one loop can handle each output mode.
$prompts = @(
    [pscustomobject]@{ Name = 'FPS'; Label = 'FPS'; Info = "Frames Per Second`n'source' keeps the input frame rate (recommended)"; Formats = @('AVIF', 'WEBP') }
    [pscustomobject]@{ Name = 'scale'; Label = 'Resolution'; Info = "Width:Height`n-1 automatically adjusts width or height`n-2 automatically adjusts and makes it even`n-1:-1 = no scaling"; Formats = @('AVIF', 'WEBP') }
    [pscustomobject]@{ Name = 'alpha'; Label = 'Alpha'; Info = 'auto = detect transparency per file, on = always keep alpha, off = never'; Formats = @('AVIF', 'WEBP') }
    [pscustomobject]@{ Name = 'pixfmt'; Label = 'Alpha color format'; Info = 'Used for AVIF files with alpha: yuv420p=smaller, yuv444p=sharper colored edges'; Formats = @('AVIF') }
    [pscustomobject]@{ Name = 'CRF'; Label = 'CRF'; Info = 'CRF: 0=lossless, 23-35=good balance, 40+=lower quality'; Formats = @('AVIF') }
    [pscustomobject]@{ Name = 'preset'; Label = 'Preset'; Info = 'SVT-AV1 preset (files without alpha): 0-3=slow/best, 4-6=balanced, 7-13=fast'; Formats = @('AVIF') }
    [pscustomobject]@{ Name = 'cpuused'; Label = 'cpu-used'; Info = 'libaom speed (files with alpha): 0-3=very slow, 4-6=balanced, 7-8=fast'; Formats = @('AVIF') }
    [pscustomobject]@{ Name = 'lossless'; Label = 'Lossless'; Info = '1=lossless, 0=lossy'; Formats = @('WEBP') }
    [pscustomobject]@{ Name = 'compression'; Label = 'Compression Level'; Info = '6=best compression (slowest), 0=least compression (fastest), 3-4=good trade-off'; Formats = @('WEBP') }
    [pscustomobject]@{ Name = 'qscale'; Label = 'Quality Scale'; Info = '100=best quality, 0=worst quality (lossy only)'; Formats = @('WEBP') }
    [pscustomobject]@{ Name = 'gif2webpmode'; Label = 'Mode'; Info = "lossless = exact colors, big files`nlossy = much smaller, mixed = per-frame choice"; Formats = @('GIF2WEBP') }
    [pscustomobject]@{ Name = 'gif2webpq'; Label = 'Quality'; Info = 'Lossless mode: compression effort. Lossy/mixed: visual quality. 100=best, 0=worst'; Formats = @('GIF2WEBP') }
    [pscustomobject]@{ Name = 'gif2webpm'; Label = 'Method'; Info = 'Compression method: 6=slowest/smallest, 0=fastest/largest'; Formats = @('GIF2WEBP') }
)

# Each rule defines the input check and the exact guidance shown when that input is rejected.
# Types: Choice checks a list, Range checks an integer, Pattern checks a regex, FPS checks a rate/fraction.
$promptRules = @{
    alpha        = @{ Type = 'Choice'; Normalize = $true; Values = @('auto', 'on', 'off'); Hint = 'auto, on, or off' }
    pixfmt       = @{ Type = 'Choice'; Normalize = $true; Values = @('yuv420p', 'yuv422p', 'yuv444p'); Hint = 'yuv420p, yuv422p, or yuv444p' }
    gif2webpmode = @{ Type = 'Choice'; Normalize = $true; Values = @('lossless', 'lossy', 'mixed'); Hint = 'lossless, lossy, or mixed' }
    FPS          = @{ Type = 'FPS'; Normalize = $true; Hint = 'source, 0, a positive frame rate, or a positive ratio such as 30000/1001' }
    scale        = @{ Type = 'Pattern'; Pattern = '^(?:-1|-2|[1-9]\d*):(?:-1|-2|[1-9]\d*)$'; Hint = 'width:height using positive integers or -1/-2 for automatic dimensions (for example -1:-1)' }
    CRF          = @{ Type = 'Range'; Range = @(0, 63); Hint = 'an integer from 0 to 63' }
    preset       = @{ Type = 'Range'; Range = @(0, 13); Hint = 'an integer from 0 to 13' }
    cpuused      = @{ Type = 'Range'; Range = @(0, 8); Hint = 'an integer from 0 to 8' }
    lossless     = @{ Type = 'Range'; Range = @(0, 1); Hint = '0 or 1' }
    compression  = @{ Type = 'Range'; Range = @(0, 6); Hint = 'an integer from 0 to 6' }
    qscale       = @{ Type = 'Range'; Range = @(0, 100); Hint = 'an integer from 0 to 100' }
    gif2webpq    = @{ Type = 'Range'; Range = @(0, 100); Hint = 'an integer from 0 to 100' }
    gif2webpm    = @{ Type = 'Range'; Range = @(0, 6); Hint = 'an integer from 0 to 6' }
}

function Stop-Script([string]$Message) {
    # Centralize fatal validation errors so they have a consistent format and nonzero exit code.
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

function Get-PromptValueValidation([string]$Name, [string]$Value) {
    $rule = $promptRules[$Name]
    if (-not $rule) {
        return [pscustomobject]@{ IsValid = $true; Hint = 'a supported value'; Value = $Value }
    }

    $normalized = if ($rule.Normalize) { $Value.ToLowerInvariant() } else { $Value }
    $isValid = switch ($rule.Type) {
        'Choice' { $normalized -in $rule.Values }
        'Pattern' { $Value -match $rule.Pattern }
        'Range' {
            # TryParse rejects non-integers and overflow without throwing for a bad entry.
            $number = 0
            [int]::TryParse($Value, [ref]$number) -and
                $number -ge $rule.Range[0] -and $number -le $rule.Range[1]
        }
        'FPS' {
            # Accept common named rates, "source", or a positive decimal/rational rate.
            $namedRates = @{
                'ntsc'      = '30000/1001'
                'pal'       = '25/1'
                'film'      = '24/1'
                'ntsc-film' = '24000/1001'
            }
            if ($namedRates.ContainsKey($normalized)) {
                $normalized = $namedRates[$normalized]
                $true
            }
            elseif ($normalized -in 'source', '0') {
                $true
            }
            elseif ($normalized -match '^(?<num>\d+(?:\.\d+)?)(?:/(?<den>\d+(?:\.\d+)?))?$') {
                # FFmpeg uses a decimal point regardless of Windows locale.
                $number = 0.0
                $numeratorValid = [double]::TryParse($Matches.num, [Globalization.NumberStyles]::Float,
                    [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -and
                    -not [double]::IsInfinity($number)
                $denominator = 1.0
                $denominatorValid = $true
                if ($Matches.den) {
                    $denominatorValid = [double]::TryParse($Matches.den, [Globalization.NumberStyles]::Float,
                        [Globalization.CultureInfo]::InvariantCulture, [ref]$denominator) -and
                        -not [double]::IsInfinity($denominator)
                }
                $numeratorValid -and $denominatorValid -and $number -gt 0 -and $denominator -gt 0
            }
            else {
                $false
            }
        }
    }

    [pscustomobject]@{ IsValid = [bool]$isValid; Hint = $rule.Hint; Value = $normalized }
}

function Read-ValidatedPrompt([string]$Name, [string]$Label, [string]$DefaultValue) {
    while ($true) {
        $value = Read-Host "$Label (Default=$DefaultValue)"
        if ([string]::IsNullOrWhiteSpace($value)) { return $DefaultValue }

        $validation = Get-PromptValueValidation $Name $value.Trim()
        if ($validation.IsValid) { return $validation.Value }

        Write-Host "[INVALID] $Label must be $($validation.Hint). Please try again." -ForegroundColor Yellow
    }
}

function Resolve-Executable([string]$Name) {
    # Prefer an executable on PATH, then look beside the script so portable installs work.
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    $local = Join-Path $PSScriptRoot $Name
    if (Test-Path -LiteralPath $local -PathType Leaf) { $local }
}

# Convert arguments into a readable PowerShell command for the preview.
# Arguments without special characters remain unquoted; other values are single-quoted with embedded quotes escaped.
function Format-CommandLine([string]$Exe, [string[]]$Arguments) {
    $quoted = $Arguments | ForEach-Object {
        if ($_ -match '^[\w\-.:\\/=]+$') { $_ } else { "'" + $_.Replace("'", "''") + "'" }
    }
    "& '$($Exe.Replace("'", "''"))' $($quoted -join ' ')"
}

# Cache stream metadata because the same files are probed for both the alpha prompt and job creation.
$script:videoInfoCache = @{}
function Get-VideoInfo([string]$Path) {
    # Full paths make equivalent relative/absolute paths share one cache entry.
    $cacheKey = [IO.Path]::GetFullPath($Path)
    if ($script:videoInfoCache.ContainsKey($cacheKey)) { return $script:videoInfoCache[$cacheKey] }

    # Return safe defaults if ffprobe cannot inspect this file; alpha is then treated as absent.
    $info = [pscustomobject]@{ Codec = ''; Alpha = $false; AlphaMode = $false }
    if (-not $script:ffprobe) { return $info }
    # Read only the first video stream's codec, pixel format, and alpha_mode tag.
    $raw = & $script:ffprobe -v error -select_streams v:0 -show_entries 'stream=codec_name,pix_fmt:stream_tags=alpha_mode' -of json $Path 2>$null
    if (-not $raw) { return $info }
    try { $s = (($raw -join "`n") | ConvertFrom-Json).streams | Select-Object -First 1 } catch { return $info }
    if (-not $s) { return $info }
    $info.Codec     = [string]$s.codec_name
    $info.AlphaMode = ($s.tags -and $s.tags.alpha_mode -eq '1')
    # pal8 = GIF palette (may contain a transparent index), the rest are real alpha formats
    $info.Alpha     = ($s.pix_fmt -match '^(pal8|ya8|ya16|argb|abgr|rgba|bgra|ayuv|yuva|gbrap|rgba64|bgra64|argb64|abgr64)') -or $info.AlphaMode
    if ($info.Codec -eq 'gif' -and $info.Alpha) {
        # GIF decoders often report an alpha-capable format even for opaque palettes; inspect decoded alpha values.
        # The alpha plane minimum is below 255 if any decoded pixel is transparent or partially transparent.
        $alphaProbe = @(& $script:exe -hide_banner -loglevel info -nostats -i $Path `
            -vf 'format=rgba,alphaextract,signalstats,metadata=print:key=lavfi.signalstats.YMIN' -an -f null NUL 2>&1)
        $alphaMinima = @($alphaProbe | ForEach-Object {
            if ("$_" -match 'lavfi\.signalstats\.YMIN=([\d.]+)') {
                [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
            }
        })
        if ($LASTEXITCODE -eq 0 -and $alphaMinima.Count -gt 0) {
            $info.Alpha = @($alphaMinima | Where-Object { $_ -lt 255 }).Count -gt 0
        }
        else {
            Write-Host "[WARN] Could not inspect GIF transparency in '$Path'; treating it as alpha-capable." -ForegroundColor Yellow
        }
    }
    $script:videoInfoCache[$cacheKey] = $info
    $info
}

function Test-WebPHasAlpha([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }

    $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($Path))
    try {
        if ($reader.BaseStream.Length -lt 21) { return $false }
        $riff = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $null = $reader.ReadUInt32()
        $webp = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $chunk = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $chunkSize = $reader.ReadUInt32()
        if ($riff -ne 'RIFF' -or $webp -ne 'WEBP' -or $chunk -ne 'VP8X' -or $chunkSize -lt 1) {
            return $false
        }
        # The VP8X alpha feature flag is bit 4 (0x10).
        return (($reader.ReadByte() -band 0x10) -ne 0)
    }
    finally {
        $reader.Dispose()
    }
}

function Remove-IncompleteOutput($Job) {
    # Do not delete a pre-existing output that the failed converter may not have touched.
    if (-not $Job.OutputExistedBeforeRun -and (Test-Path -LiteralPath $Job.Out -PathType Leaf)) {
        try { Remove-Item -LiteralPath $Job.Out -Force -ErrorAction Stop }
        catch { Write-Host "[WARN] Could not remove incomplete output '$($Job.Out)': $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}

function Test-JobSuccess($Job, [int]$ExitCode, [string]$OutputFormat) {
    if ($ExitCode -ne 0) {
        Remove-IncompleteOutput $Job
        Write-Host "[ERROR] Conversion failed: $($Job.Name)" -ForegroundColor Red
        return $false
    }
    if ($OutputFormat -eq 'WEBP' -and $Job.Alpha -and -not (Test-WebPHasAlpha $Job.Out)) {
        Remove-IncompleteOutput $Job
        Write-Host "[ERROR] WebP output for '$($Job.Name)' does not contain alpha although alpha was requested. This FFmpeg/libwebp build may have dropped transparency." -ForegroundColor Red
        return $false
    }
    return $true
}

function New-Job($File) {
    # Derive the output filename from the input basename and the selected output format.
    $name = [IO.Path]::GetFileNameWithoutExtension($File.Name)
    $ext  = if ($format -eq 'AVIF') { 'avif' } else { 'webp' }
    $out  = Join-Path $cfg.outputDIR "${name}_out.$ext"

    if ($format -eq 'GIF2WEBP') {
        # gif2webp consumes GIF directly, so it does not use FFmpeg's filters or alpha settings.
        $a = [System.Collections.Generic.List[string]]::new()
        $a.AddRange([string[]]@($File.FullName, '-q', $cfg.gif2webpq, '-m', $cfg.gif2webpm))
        # These are mode flags, not independent quality settings.
        if ($cfg.gif2webpmode -eq 'lossy') { $a.Add('-lossy') }
        elseif ($cfg.gif2webpmode -eq 'mixed') { $a.Add('-mixed') }
        $a.AddRange([string[]]@('-mt', '-o', $out))
        return [pscustomobject]@{
            Name = $File.Name
            Out = $out
            Alpha = $false
            OutputExistedBeforeRun = [bool](Test-Path -LiteralPath $out -PathType Leaf)
            Arguments = [string[]]$a
        }
    }

    # "auto" preserves alpha only for files detected with transparency; "on"/"off" override that choice.
    $info  = Get-VideoInfo $File.FullName
    $alpha = switch ($cfg.alpha) { 'on' { $true } 'off' { $false } default { $info.Alpha } }

    # Build video filters in order. With alpha, convert to rgba FIRST so fps/scale filters retain the alpha plane.
    $f = [System.Collections.Generic.List[string]]::new()
    if ($alpha) { $f.Add('format=rgba') }
    # "source" and "0" both mean no FPS filter; other accepted values are passed to FFmpeg.
    if ($cfg.FPS -notmatch '^(source|0)?$') { $f.Add("fps=$($cfg.FPS)") }
    if ($cfg.scale -eq '-2:-2') {
        # With both dimensions automatic, FFmpeg leaves the input size unchanged; explicitly make both dimensions even.
        $f.Add("scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=$($cfg.flags)")
    }
    elseif ($cfg.scale -ne '-1:-1') { $f.Add("scale=$($cfg.scale):flags=$($cfg.flags)") }
    # With no requested scaling, crop AVIF input down to even dimensions for subsampled AV1 formats.
    # An explicit scale bypasses this crop; an odd result can fail in the non-alpha libsvtav1/yuv420p path.
    elseif ($format -eq 'AVIF') { $f.Add('crop=trunc(iw/2)*2:trunc(ih/2)*2') }

    # Start an FFmpeg argument list; each item stays separate so paths with spaces remain safe.
    $a = [System.Collections.Generic.List[string]]::new()
    $a.AddRange([string[]]@('-hide_banner', '-y', '-loglevel', 'error'))
    # Show FFmpeg's progress only when conversions run one-by-one.
    if ($Parallel -le 1) { $a.Add('-stats') }
    # VP9 WebM with alpha: the native decoder ignores alpha, libvpx-vp9 keeps it
    if ($info.Codec -eq 'vp9' -and $info.AlphaMode) { $a.AddRange([string[]]@('-c:v', 'libvpx-vp9')) }
    $a.AddRange([string[]]@('-i', $File.FullName))

    # Preserve source timestamps; FFmpeg's default constant-rate sync can duplicate frames.
    if ($format -eq 'AVIF' -and $alpha) {
        # AVIF alpha is encoded as two AV1 image tracks: color and an extracted grayscale alpha plane.
        # Pin an alpha-capable format right before the split: scale can change the pixel format and drop alpha,
        # which makes alphaextract fail with "Requested planes not available".
        $pfa   = $cfg.pixfmt -replace '^yuv', 'yuva'
        $chain = ($f -join ',') + ",format=$pfa,split[c][a];[c]format=$($cfg.pixfmt)[c2];[a]alphaextract[al]"
        $a.AddRange([string[]]@('-filter_complex', "[0:v:0]$chain", '-map', '[c2]', '-map', '[al]',
            '-c:v', 'libaom-av1', '-crf', $cfg.CRF, '-b:v', '0', '-cpu-used', $cfg.cpuused, '-row-mt', '1',
            '-an', '-fps_mode', 'passthrough', '-f', 'avif', $out))
    }
    elseif ($format -eq 'AVIF') {
        # Without alpha, use the faster SVT-AV1 encoder and its supported 4:2:0 pixel format.
        $f.Add('format=yuv420p')
        $a.AddRange([string[]]@('-map', '0:v:0', '-vf', ($f -join ','),
            '-c:v', 'libsvtav1', '-crf', $cfg.CRF, '-preset', $cfg.preset, '-b:v', '0',
            '-an', '-fps_mode', 'passthrough', '-f', 'avif', $out))
    }
    else {
        # Explicitly choose a format with or without alpha; GIF decoders can otherwise preserve alpha even when disabled.
        if ($alpha) { $f.Add('format=yuva420p') }
        elseif ($cfg.lossless -eq '1') { $f.Add('format=rgb24') } # Drop alpha without adding 4:2:0 color loss.
        else { $f.Add('format=yuv420p') }
        $a.AddRange([string[]]@('-map', '0:v:0'))
        if ($f.Count -gt 0) { $a.AddRange([string[]]@('-vf', ($f -join ','))) }
        # libwebp_anim (not plain libwebp): plain libwebp writes full frames with blend/no-dispose, which stacks transparent frames
        $a.AddRange([string[]]@('-c:v', 'libwebp_anim', '-lossless', $cfg.lossless, '-compression_level', $cfg.compression,
            '-q:v', $cfg.qscale, '-loop', '0', '-an', '-fps_mode', 'passthrough', $out))
    }

    # Keep both the preview/display metadata and the exact argument vector for execution.
    [pscustomobject]@{
        Name = $File.Name
        Out = $out
        Alpha = [bool]$alpha
        OutputExistedBeforeRun = [bool](Test-Path -LiteralPath $out -PathType Leaf)
        Arguments = [string[]]$a
    }
}

$usage = @'
Usage:
  GifMyAss.ps1 <file>                       = Convert a single file
  GifMyAss.ps1 <directory>                  = Convert video/GIF files in a directory
  GifMyAss.ps1 <path> -Gif2WebP             = Use Google gif2webp (GIF only)
  GifMyAss.ps1 <path> -OutputDir <d>        = Write output to <d> instead of the default folder
  GifMyAss.ps1 <path> -Parallel <n>         = Run n conversions at once (PowerShell 7+, WEBP and gif2webp only)
  GifMyAss.ps1 -Default                     = List default values
  GifMyAss.ps1 -GetFPS <file> [<file>...]   = Get FPS for files or directories
  GifMyAss.ps1 -Help                        = Show this help message
'@

# ---------------------------------------------------------------------------
# Simple modes
# ---------------------------------------------------------------------------

# These options are early-exit shortcuts, handled before requiring an input path.
if ($Help) { Write-Host $usage; return }

if ($Default) {
    Write-Host 'Default values:'
    $cfg.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key.PadRight(14)) = $($_.Value)" }
    return
}

if ($GetFPS) {
    $ffprobe = Resolve-Executable 'ffprobe.exe'
    if (-not $ffprobe) { Stop-Script 'ffprobe not found.' }

    $fpsFiles = [System.Collections.Generic.List[IO.FileInfo]]::new()
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if (-not $InputPath -or $InputPath.Count -eq 0) { Stop-Script 'No input file or directory given.' }
    foreach ($requestedPath in $InputPath) {
        $requestedPath = $requestedPath.Trim().Trim('"')
        if ([string]::IsNullOrWhiteSpace($requestedPath)) { continue }
        if (-not (Test-Path -LiteralPath $requestedPath)) { Stop-Script "Path not found: $requestedPath" }

        $pathItems = if (Test-Path -LiteralPath $requestedPath -PathType Container) {
            @(Get-ChildItem -LiteralPath $requestedPath -File |
                Where-Object { $videoExt -contains $_.Extension.ToLowerInvariant() } |
                Sort-Object Name)
        }
        else {
            @(Get-Item -LiteralPath $requestedPath)
        }

        foreach ($match in $pathItems) {
            if ($seenPaths.Add([IO.Path]::GetFullPath($match.FullName))) {
                $fpsFiles.Add($match)
            }
        }
    }

    if ($fpsFiles.Count -eq 0) { Stop-Script 'No suitable files found.' }

    $fpsResults = @($fpsFiles | ForEach-Object {
        $file = $_
        $ffFract = (& $ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 $file.FullName |
            Select-Object -First 1)
        $ffFract = [string]$ffFract

        if ($ffFract -match '^\d+/[1-9]\d*$') {
            $rateParts = $ffFract -split '/'
            $fps = [math]::Round(([double]$rateParts[0] / [double]$rateParts[1]), 3)
            [pscustomobject]@{ Name = $file.Name; Fraction = $ffFract; FPS = $fps }
        }
        else {
            [pscustomobject]@{ Name = $file.Name; Fraction = 'N/A'; FPS = 'N/A' }
        }
    })

    if ($fpsResults.Count -eq 1) {
        Write-Host $fpsResults[0].Name
        Write-Host $fpsResults[0].Fraction
        Write-Host "$($fpsResults[0].FPS) FPS"
    }
    else {
        $fpsResults | Format-Table -AutoSize -Property `
            @{ Label = 'FileName'; Expression = { $_.Name } },
            @{ Label = 'Fraction'; Expression = { $_.Fraction } },
            @{ Label = 'FPS'; Expression = { if ($_.FPS -eq 'N/A') { 'N/A' } else { "$($_.FPS) FPS" } } }
    }
    return
}

# ---------------------------------------------------------------------------
# Validate everything before asking any questions
# ---------------------------------------------------------------------------

# Resolve and filter the input list up front so prompts only apply to files that will be converted.
if (-not $InputPath -or $InputPath.Count -eq 0) {
    Write-Host $usage
    Write-Host ''
    Stop-Script 'No input file or directory given.'
}
if ($InputPath.Count -gt 1) { Stop-Script 'Conversion mode accepts one file or directory only.' }

$InputPath = ([string]$InputPath[0]).Trim().Trim('"')
if (-not (Test-Path -LiteralPath $InputPath)) { Stop-Script "Path not found: $InputPath" }

# In directory mode, filter and sort recognized media extensions for predictable processing order.
$isDir = Test-Path -LiteralPath $InputPath -PathType Container
$files = if ($isDir) {
    @(Get-ChildItem -LiteralPath $InputPath -File | Where-Object { $videoExt -contains $_.Extension.ToLowerInvariant() } | Sort-Object Name)
} else {
    @(Get-Item -LiteralPath $InputPath)
}

if ($Gif2WebP) { $files = @($files | Where-Object Extension -ieq '.gif') }
if (-not $files) { Stop-Script 'No suitable files found.' }

# Resolve the converter now so missing dependencies are reported before settings prompts begin.
$exeName = if ($Gif2WebP) { 'gif2webp.exe' } else { 'ffmpeg.exe' }
$exe = Resolve-Executable $exeName
if (-not $exe) { Stop-Script "$exeName not found in PATH or next to this script." }

$ffprobe = $null
if (-not $Gif2WebP) {
    # ffprobe is needed for alpha auto-detection and stream-specific handling; conversions can still run without it.
    $ffprobe = Resolve-Executable 'ffprobe.exe'
    if (-not $ffprobe) { Write-Host '[WARN] ffprobe not found: alpha auto-detection is disabled; set $cfg.alpha = ''on'' in the script to force alpha.' -ForegroundColor Yellow }
}

if (Test-Path -LiteralPath $cfg.outputDIR -PathType Leaf) {
    Stop-Script "Output path '$($cfg.outputDIR)' is a file; provide a folder with -OutputDir."
}
try { New-Item -ItemType Directory -Path $cfg.outputDIR -Force -ErrorAction Stop | Out-Null }
catch { Stop-Script "Cannot create output folder '$($cfg.outputDIR)'. Use -OutputDir <folder>." }

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

if ($Gif2WebP) {
    # gif2webp is always WebP output, so there is no output-format question in this mode.
    $format = 'GIF2WEBP'
    Write-Host 'GifMyAss gif2webp'
}
else {
    Write-Host 'GifMyAss'
    # Keep asking until the user chooses one of the formats supported by the FFmpeg path.
    do {
        $format = (Read-Host "`nOutput format (AVIF / WEBP)").ToUpperInvariant()
    } until ($format -in 'AVIF', 'WEBP')
}

if ($format -eq 'WEBP') {
    # Animated WebP needs the animation encoder; plain libwebp does not preserve animated frames correctly.
    $ffmpegEncoders = & $exe -hide_banner -encoders 2>&1
    if (-not ($ffmpegEncoders | Select-String -SimpleMatch 'libwebp_anim')) {
        Stop-Script 'This ffmpeg build has no libwebp_anim encoder (needed for animated WebP). Use a newer build or -Gif2WebP.'
    }
}

# Does any input file have alpha? Alpha settings apply to AVIF and WEBP output.
# Probe only until one alpha-capable input is found; this controls whether alpha-specific questions are useful.
$anyAlpha = $false
if ($format -in 'AVIF', 'WEBP') {
    $anyAlpha = [bool]($files | Where-Object { (Get-VideoInfo $_.FullName).Alpha } | Select-Object -First 1)
}

foreach ($p in $prompts) {
    $name = $p.Name
    $label = $p.Label
    $info = $p.Info
    if ($format -notin $p.Formats) { continue }
    # Alpha controls and options are irrelevant when no input has an alpha path.
    if ($name -eq 'alpha' -and -not $anyAlpha) { continue }
    # These two settings only matter for the alpha path, so ask only when alpha will actually be used
    if ($name -in 'pixfmt', 'cpuused') {
        $needAlpha = $anyAlpha -and ($cfg.alpha -ne 'off')
        if (-not $needAlpha) { continue }
    }
    Write-Host "`n$info"
    # Enter keeps the default; invalid values are rejected by the shared prompt reader.
    $cfg[$name] = Read-ValidatedPrompt $name $label $cfg[$name]
}

# ---------------------------------------------------------------------------
# Build commands
# ---------------------------------------------------------------------------

# Build every command before execution so filename conflicts can be caught safely.
$jobs = @($files | ForEach-Object { New-Job $_ })

# Different inputs with the same basename would otherwise overwrite the same output path.
$dupes = @($jobs | Group-Object { Split-Path $_.Out -Leaf } | Where-Object Count -gt 1)
if ($dupes) {
    Write-Host '[ERROR] Multiple input files would produce the same output filename:' -ForegroundColor Red
    $dupes | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Red }
    exit 1
}

Write-Host "`nFound $($jobs.Count) files:" -ForegroundColor Yellow
$jobs | ForEach-Object { Write-Host ("  $($_.Name)" + $(if ($_.Alpha) { '  [alpha]' } else { '' })) }

$existing = @($jobs | Where-Object { Test-Path -LiteralPath $_.Out })
# Warn before confirmation because FFmpeg is invoked with -y and will overwrite existing outputs.
if ($existing) { Write-Host "`n$($existing.Count) output file(s) already exist and will be overwritten." -ForegroundColor Yellow }

# Print exact runnable commands so the user can inspect or copy them before starting conversion.
Write-Host "`nCommand preview:`n" -ForegroundColor Yellow
$jobs | ForEach-Object { Write-Host (Format-CommandLine $exe $_.Arguments) -ForegroundColor Cyan }

# ---------------------------------------------------------------------------
# Confirm and run
# ---------------------------------------------------------------------------

Write-Host "`nCopy a command and type C to cancel if you want to execute it manually."
# No conversion starts until the user confirms this batch.
if ((Read-Host 'Press Enter to execute all conversions, or type C to cancel') -match '^[Cc]$') {
    Write-Host 'Conversion cancelled.'
    return
}

Write-Host ''
$failed = 0
# Parallel mode is supported only in PowerShell 7+ and for non-AVIF encoders.
$canParallel = ($Parallel -gt 1) -and ($PSVersionTable.PSVersion.Major -ge 7) -and ($format -ne 'AVIF')
if ($Parallel -gt 1 -and -not $canParallel) {
    Write-Host '[INFO] -Parallel needs PowerShell 7+ and WEBP/gif2webp output (AVIF encoders already use all cores). Running one at a time.' -ForegroundColor Yellow
}

if ($canParallel) {
    # Run independent WebP jobs concurrently; AVIF encoders already use the available cores.
    $results = $jobs | ForEach-Object -ThrottleLimit $Parallel -Parallel {
        $j = $_
        & $using:exe @($j.Arguments) 2>&1 | Out-Host
        [pscustomobject]@{
            Name = $j.Name
            Out = $j.Out
            Alpha = $j.Alpha
            OutputExistedBeforeRun = $j.OutputExistedBeforeRun
            Code = $LASTEXITCODE
        }
    }
    foreach ($r in $results) {
        if (-not (Test-JobSuccess $r $r.Code $format)) { $failed++ }
    }
}
else {
    # Serial path also supports Windows PowerShell and the AVIF encoder workflows.
    foreach ($job in $jobs) {
        & $exe @($job.Arguments)
        if (-not (Test-JobSuccess $job $LASTEXITCODE $format)) { $failed++ }
    }
}

if ($failed -gt 0) {
    Write-Host "`nConversion finished with $failed error(s)." -ForegroundColor Yellow
    exit 1
}
else { Write-Host "`nConversion finished." -ForegroundColor Green }
