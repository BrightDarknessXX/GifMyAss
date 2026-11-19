# GifMyAss v2.5

GifMyAss is a Windows PowerShell script that converts single files or complete directories to animated AVIF or animated WebP. It uses FFmpeg for AVIF and WebP conversion and Google's `gif2webp` utility for direct GIF-to-WebP conversion.

The script validates conversion settings, detects alpha transparency when possible, previews the exact commands, and asks for confirmation before converting anything.

## Prerequisites

- Windows PowerShell or PowerShell 7+
- `ffmpeg.exe` and `ffprobe.exe` for AVIF and FFmpeg-based WebP conversion
- `gif2webp.exe` for `-Gif2WebP` mode

Place the executables next to `GifMyAss_v2.5.ps1`, or add them to `PATH`. The script searches `PATH` first and then checks the script's own directory.

`ffprobe` is recommended for automatic alpha detection and is used to apply per-file FPS and resolution limits. Conversion can continue without it, but alpha will not be detected and limits cannot be applied.

## Usage

Run the script from PowerShell:

```powershell
.\GifMyAss_v2.5.ps1
```

`GifMyAss_v2.5.ps1` requires a file or directory. Use `-Help` or `-Default` for information-only modes.

### Convert a single file

```powershell
.\GifMyAss_v2.5.ps1 ".\animation.gif"
```

Direct file paths are not filtered by extension, so any file accepted by the selected converter can be used.

### Convert a directory

```powershell
.\GifMyAss_v2.5.ps1 ".\input-folder"
```

Directory mode processes supported files in alphabetical order. Supported extensions are `.gif`, `.apng`, `.mp4`, `.m4v`, `.mov`, `.mkv`, `.webm`, `.avi`, `.wmv`, `.flv`, `.mpg`, `.mpeg`, `.ts`, `.m2ts`, and `.3gp`.

### Choose the output format

In normal FFmpeg mode, the script prompts for `AVIF` or `WEBP`.

- AVIF without detected alpha uses the fast multi-threaded `libsvtav1` encoder.
- AVIF with alpha uses `libaom-av1` to encode separate color and alpha tracks.
- Animated WebP uses `libwebp_anim`.

### Convert GIF files with gif2webp

```powershell
.\GifMyAss_v2.5.ps1 ".\animation.gif" -Gif2WebP
```

With a directory, only `.gif` files are selected.

```powershell
.\GifMyAss_v2.5.ps1 ".\input-folder" -Gif2WebP
```

### Set the output folder

```powershell
.\GifMyAss_v2.5.ps1 ".\input-folder" -OutputDir ".\converted"
```

`-OutputDir` overrides the script's built-in `outputDIR` for that run. The built-in default is currently `.\output`.

Each output is named from the input basename with `_out.avif` or `_out.webp`. For example, `animation.gif` becomes `animation_out.webp`.

Existing outputs are overwritten after confirmation. Inputs that would generate duplicate output names are rejected before conversion.

### Run conversions concurrently

```powershell
.\GifMyAss_v2.5.ps1 ".\input-folder" -Parallel 4
```

`-Parallel` accepts 1 through 32 and is available only for WebP and `gif2webp` output in PowerShell 7 or newer. AVIF conversions run one at a time because their encoders already use multiple cores.

Windows PowerShell or AVIF output falls back to serial conversion.

### Inspect frame rates

```powershell
.\GifMyAss_v2.5.ps1 -GetFPS ".\animation.mp4"
.\GifMyAss_v2.5.ps1 -GetFPS ".\input-folder"
.\GifMyAss_v2.5.ps1 -GetFPS ".\first.mp4" ".\second.webm"
```

GetFPS mode accepts files or directories and prints the average frame rate from `ffprobe`.

### Display information

```powershell
.\GifMyAss_v2.5.ps1 -Default
.\GifMyAss_v2.5.ps1 -Help
```

`-Default` prints the configured defaults. `-Help` prints the command syntax.

## Conversion settings

Press Enter at a prompt to keep the displayed default. Invalid values are rejected and the prompt is repeated.

FPS and resolution limits are checked per file against source metadata from `ffprobe`.

### General

| Setting | Default | Accepted values |
| --- | --- | --- |
| FPS | `source` | `source`, `0`, a positive frame rate, rational rate such as `30000/1001`, or named rate: `ntsc`, `pal`, `film`, `ntsc-film`; prefix a limit with `<` to cap or `>` to raise source FPS |
| Resolution | `-1:-1` | `width:height`; positive integers or `-1`/`-2` for automatic dimensions; prefix a width or height limit with `<` to cap or `>` to raise |
| Alpha | `auto` | `auto`, `on`, or `off`; only shown when an input supports alpha |

FPS limits apply per file:

- `<20` or `<20fps` changes sources above 20 FPS to 20 FPS and leaves slower sources unchanged.
- `>20` or `>20fps` changes sources below 20 FPS to 20 FPS and leaves faster sources unchanged.
- Named and rational limits are accepted, for example `<ntsc`, `>24`, or `<30000/1001`.

Resolution limits use `width:height` with `-2` on the unconstrained side:

- `<400:-2` caps width at 400 pixels and calculates height to preserve aspect ratio.
- `-2:<400` caps height at 400 pixels and calculates width to preserve aspect ratio.
- `>400:-2` raises width below 400 pixels to 400 and leaves wider sources unchanged.
- `-2:>400` raises height below 400 pixels to 400 and leaves taller sources unchanged.

### AVIF

| Setting | Default | Accepted values |
| --- | --- | --- |
| Alpha color format | `yuv420p` | `yuv420p`, `yuv422p`, or `yuv444p` |
| CRF | `20` | Integer from `0` to `63`; `0` is lossless |
| SVT-AV1 preset | `6` | Integer from `0` to `13`; lower is slower and higher quality |
| libaom `cpu-used` | `6` | Integer from `0` to `8`; used for AVIF with alpha |

### FFmpeg WebP

| Setting | Default | Accepted values |
| --- | --- | --- |
| Lossless | `0` | `0` lossy or `1` lossless |
| Compression level | `4` | Integer from `0` to `6`; higher takes longer and can improve compression |
| Quality scale | `75` | Integer from `0` to `100`; used in lossy mode |

### gif2webp

| Setting | Default | Accepted values |
| --- | --- | --- |
| Mode | `lossless` | `lossless`, `lossy`, or `mixed` |
| Quality | `80` | Integer from `0` to `100` |
| Method | `4` | Integer from `0` to `6`; higher is slower and usually smaller |

The alpha prompts are limited to settings that apply to the detected inputs. GIF transparency is checked from decoded frames; for formats that expose alpha metadata, `ffprobe` is used to detect it.

For gif2webp:

- `lossless` preserves exact colors and produces larger files.
- `lossy` produces much smaller files.
- `mixed` lets gif2webp choose per-frame lossless or lossy encoding.
- In lossless mode, quality is interpreted as compression effort.
- In lossy and mixed modes, quality is interpreted as visual quality.

## Preview and execution

After settings are collected, the script prints all input files and the exact runnable converter commands. It then waits for confirmation:

- Press Enter to start all conversions.
- Enter `C` to cancel.

The script validates missing converters and input paths before prompting for settings. Conversion failures remove only outputs created by that failed run, while the script leaves pre-existing outputs untouched.
