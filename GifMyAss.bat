@echo off

echo Made by _BrightDarkness_ v1.1a with FFMPEG
echo.

::Default Values
set "FPS=30"
set "scale=-1:-1"
set "CRF=25"
set "lossless=0"
set "compression=6"
set "qscale=75"
set "preset=4"
set "gif2webpq=80"
set "gif2webpm=6"
set "outputDIR=output"
set "batchmodeDIR=batchmode"

:: Check for gif2webp
if /I "%1"=="gif2webp" (
    goto gif2webp
)

:: Check for help argument
if /I "%1"=="help" (
    echo ---------------------------------------------------
    echo Usage:
    echo    GifMyAss.bat                = Interactive mode
    echo    GifMyAss.bat batch          = Batch mode
    echo    GifMyAss.bat default        = List default values
    echo    GifMyAss.bat gif2webp       = Uses google's gif2webp
    echo    GifMyAss.bat gif2webp batch = gif2webp Batch mode
    echo    GifMyAss.bat getFPS ^<file^>  = Gets you the FPS of a file
    echo    GifMyAss.bat help           = Show this help message
    echo ---------------------------------------------------
    exit /b
)

:: Lists default values
if /I "%1"=="default" (
    echo ---------------------------------------------------
    echo Default Values:
    echo FPS            = %FPS%
    echo scale          = %scale%
    echo CRF            = %CRF%
    echo lossless       = %lossless% 
    echo compression    = %compression%
    echo qscale         = %qscale%
    echo preset         = %preset%
    echo gif2webpq      = %gif2webpq%
    echo gif2webpm      = %gif2webpm%
    echo outputDIR      = %outputDIR%
    echo batchmodeDIR   = %batchmodeDIR%
    echo ---------------------------------------------------
    exit /b
)

if /I "%1"=="getFPS" (
    ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "%~2"
    exit /b
)

:: Check if ffmpeg is available
set "ffmpeg_cmd=ffmpeg"

where %ffmpeg_cmd% >nul 2>&1
if errorlevel 1 (
    if exist "%~dp0ffmpeg.exe" (
        set "ffmpeg_cmd=%~dp0ffmpeg.exe"
    ) else (
        echo [ERROR] ffmpeg not found in PATH or next to this script.
        echo Place ffmpeg.exe in the same folder as this script or add it to PATH.
        pause
        exit /b
    )
)
if not exist "%outputDIR%\" (md "%outputDIR%\")


:: Check for batchmode
if "%1"=="batch" (
    set "batchmode=1"
    echo GifMyAss Batchmode
) else (
    set "batchmode=0"
    echo GifMyAss
)


::Start
:unkwnFormat
set /p "format=AVIF or WEBP : "

if /I not "%format%"=="AVIF" (
    if /I not "%format%"=="WEBP" (
        echo Unknown format.
        goto unkwnFormat
    )
)
echo.

echo Name of the input file.ext (ingore in batchmode)
set /p "inputFile=Inputfile : "
call set "inputFile=%%inputFile:"=%%"

echo.
echo Frames Per Second
echo.
echo Default=%FPS%
set /p "input=FPS : "
if defined input (set "FPS=%input%")
call :resetInput

echo.
echo Width:Height
echo -1 will automatically adjust height or width
echo -2 same but make it an even number
echo.
echo Default=%scale%
set /p "input=Resolution : "
if defined input (set "scale=%input%")
call :resetInput

goto %format%


:AVIF
echo.
echo Constant Rate Factor / 0=lossless, 23-35 good balance, 40+ quality drops but smaller file size, ^>50 probably ugly, 63 worst
echo.
echo Default=%CRF%
set /p "input=CRF : "
if defined input (set "CRF=%input%")
call :resetInput

echo.
echo 1-3=Heigest quality / slowest, 4-6=Balanced speed / quality, 7-12=Fast / Real-Time, 13=Debug-only
echo.
echo Default=%preset%
set /p "input=Preset : "
if defined input (set "preset=%input%")
call :resetInput

if "%batchmode%"=="1" (goto batchmode)

for %%F in ("%inputFile%") do (
    echo.
    echo %ffmpeg_cmd% -i "%%~F" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libsvtav1 -crf %CRF% -preset %preset% -b:v 0 -an -f avif "%outputDIR%\%%~nF_out.avif"
    echo.
    echo Proceed with Enter.
    pause>nul

    %ffmpeg_cmd% -i "%%~F" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libsvtav1 -crf %CRF% -preset %preset% -b:v 0 -an -f avif "%outputDIR%\%%~nF_out.avif"
)

goto end

:WEBP
echo.
echo 1=lossless, 0=lossy
echo.
echo Default=%lossless%
set /p "input=Lossless : "
if defined input (set "lossless=%input%")
call :resetInput

echo.
echo 6=best compression, 0=least compression
echo.
echo Default=%compression%
set /p "input=Compression Level : "
if defined input (set "compression=%input%")
call :resetInput

echo.
echo 100=best quality and big file, 0=worst quality and small file
echo.
echo Default=%qscale%
set /p "input=Quality Scale : "
if defined input (set "qscale=%input%")
call :resetInput

if "%batchmode%"=="1" (goto batchmode)

for %%F in ("%inputFile%") do (
    echo.
    echo %ffmpeg_cmd% -i "%%~F" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libwebp -lossless %lossless% -compression_level %compression% -q:v %qscale% -preset default -loop 0 -an -fps_mode passthrough "%outputDIR%\%%~nF_out.webp"
    echo.
    echo Proceed with Enter.
    pause>nul

    %ffmpeg_cmd% -i "%%~F" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libwebp -lossless %lossless% -compression_level %compression% -q:v %qscale% -preset default -loop 0 -an -fps_mode passthrough "%outputDIR%\%%~nF_out.webp"
)

goto end

::Subroutines
:resetInput
set "input="
goto :eof

::Batchmode
:batchmode
if not exist "%batchmodeDIR%\" (md "%batchmodeDIR%\")
echo.
echo Copy all files into the folder "%batchmodeDIR%" that you want to convert to %format%.
echo.
echo Proceed with Enter.
pause>nul
goto %format%_BATCH

:AVIF_BATCH
echo.
echo All these files will be converted to %format%:
dir "%batchmodeDIR%\" /B /A
:confirm_avif_batch_err
set /p "confirm=Continue? (Y) : "
if /I not "%confirm%"=="Y" (
    echo Input was not Y.
    goto confirm_avif_batch_err
)

echo.
echo %ffmpeg_cmd% -i "%batchmodeDIR%\*" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libsvtav1 -crf %CRF% -preset %preset% -b:v 0 -an -f avif "%outputDIR%\*_out.avif"
echo.
echo Proceed with Enter.
pause>nul

for %%F in ("%batchmodeDIR%\*.*") do (
    %ffmpeg_cmd% -i "%%~F" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libsvtav1 -crf %CRF% -preset %preset% -b:v 0 -an -f avif "%outputDIR%\%%~nF_out.avif"
)
goto end

:WEBP_BATCH
echo.
echo All these files will be converted to %format%:
dir "%batchmodeDIR%\" /B /A
:confirm_webp_batch_err
set /p "confirm=Continue? (Y) : "
if /I not "%confirm%"=="Y" (
    echo Input was not Y.
    goto confirm_webp_batch_err
)

echo.
echo %ffmpeg_cmd% -i "%batchmodeDIR%\*" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libwebp -lossless %lossless% -compression_level %compression% -q:v %qscale% -preset default -loop 0 -an -fps_mode passthrough "%outputDIR%\*_out.webp"
echo.
echo Proceed with Enter.
pause>nul

for %%F in ("%batchmodeDIR%\*.*") do (
    %ffmpeg_cmd% -i "%%~F" -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libwebp -lossless %lossless% -compression_level %compression% -qscale %qscale% -preset default -loop 0 -an -vsync 0 "%outputDIR%\%%~nF_out.webp"
)
goto end

:gif2webp_BATCH
echo.
echo All these files will be converted to %format%:
dir "%batchmodeDIR%\*.gif" /B /A
:confirm_gif2webp_batch_err
set /p "confirm=Continue? (Y) : "
if /I not "%confirm%"=="Y" (
    echo Input was not Y.
    goto confirm_gif2webp_batch_err
)

echo.
echo %gif2webp_cmd% "%batchmodeDIR%\*.gif" -q %gif2webpq% -m %gif2webpm% -o "%outputDIR%\*_out.webp"
echo.
echo Proceed with Enter.
pause>nul

for %%F in ("%batchmodeDIR%\*.gif") do (
    %gif2webp_cmd% "%%~F" -q %gif2webpq% -m %gif2webpm% -o "%outputDIR%\%%~nF_out.webp"
)
goto end


::gif2webp option
:gif2webp
set "format=gif2webp"

:: Check for batchmode
if "%2"=="batch" (
    set "batchmode=1"
    echo GifMyAss gif2webp Batchmode
) else (
    set "batchmode=0"
    echo GifMyAss gif2webp
)

:: Check if gif2webp is available
set "gif2webp_cmd=gif2webp"

where %gif2webp_cmd% >nul 2>&1
if errorlevel 1 (
    if exist "%~dp0gif2webp.exe" (
        set "gif2webp_cmd=%~dp0gif2webp.exe"
    ) else (
        echo [ERROR] gif2webp not found in PATH or next to this script.
        echo Place gif2webp.exe in the same folder as this script or add it to PATH.
        pause
        exit /b
    )
)
if not exist "%outputDIR%\" (md "%outputDIR%\")

echo Name of the input file.ext (ingore in batchmode)
set /p "inputFile=Inputfile : "
call set "inputFile=%%inputFile:"=%%"

echo.
echo 100=best quality and big file, 0=worst quality and small file
echo.
echo Default=%gif2webpq%
set /p "input=Quality Scale : "
if defined input (set "gif2webpq=%input%")
call :resetInput

echo.
echo 6=best compression, 0=least compression
echo.
echo Default=%gif2webpm%
set /p "input=Compression Level : "
if defined input (set "gif2webpm=%input%")
call :resetInput

if "%batchmode%"=="1" (goto batchmode)

for %%F in ("%inputFile%") do (
    echo.
    echo %gif2webp_cmd% "%%~F" -q %gif2webpq% -m %gif2webpm% -o "%outputDIR%\%%~nF_out.webp"
    echo.
    echo Proceed with Enter.
    pause>nul

    %gif2webp_cmd% "%%~F" -q %gif2webpq% -m %gif2webpm% -o "%outputDIR%\%%~nF_out.webp"
)

goto end


:end
exit /b
