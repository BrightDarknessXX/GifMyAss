@echo off

:: Check for help argument
if /I "%1"=="help" (
    echo ---------------------------------------------------
    echo Usage:
    echo    GifMyAss.bat          = Interactive mode
    echo    GifMyAss.bat batch    = Batch mode
    echo    GifMyAss.bat help     = Show this help message
    echo ---------------------------------------------------
    exit /b
)
if "%1"=="batch" (
    set "batchmode=1"
    echo GifMyAss Batchmode
) else (
    echo GifMyAss
)

echo Made by _BrightDarkness_ v1.0a with FFMPEG
echo.

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

::Default Values
set "FPS=30"
set "scale=-2:500"
set "CRF=25"
set "lossless=0"
set "compression=6"
set "qscale=75"
set "preset=4"
set "outputDIR=output"
set "batchmodeDIR=batchmode"

if not exist "%outputDIR%\" (md "%outputDIR%\")


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
echo -2 will automatically adjust height or width
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
    echo %ffmpeg_cmd% -i %%F -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libsvtav1 -crf %CRF% -preset %preset% -b:v 0 -an -f avif "%outputDIR%\%%~nF_out.avif"
    echo.
    echo Proceed with Enter.
    pause>nul

    %ffmpeg_cmd% -i %%F -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libsvtav1 -crf %CRF% -preset %preset% -b:v 0 -an -f avif "%outputDIR%\%%~nF_out.avif"
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
    echo %ffmpeg_cmd% -i %%F -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libwebp -lossless %lossless% -compression_level %compression% -q:v %qscale% -preset default -loop 0 -an -fps_mode passthrough "%outputDIR%\%%~nF_out.webp"
    echo.
    echo Proceed with Enter.
    pause>nul

    %ffmpeg_cmd% -i %%F -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libwebp -lossless %lossless% -compression_level %compression% -q:v %qscale% -preset default -loop 0 -an -fps_mode passthrough "%outputDIR%\%%~nF_out.webp"
)

goto end

::Subroutines
:resetInput
set "input="
goto :eof

::Batchmode
:batchmode
if not exist "%batchmodeDIR%\" (md %batchmodeDIR%\)
echo.
echo Copy all files into the folder "%batchmodeDIR%" that you want to convert to %format%.
echo.
echo Proceed with Enter.
pause>nul
goto %format%_BATCH
pause

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
    %ffmpeg_cmd% -i %%F -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libsvtav1 -crf %CRF% -preset %preset% -b:v 0 -an -f avif "%outputDIR%\%%~nF_out.avif"
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
    %ffmpeg_cmd% -i %%F -vf "fps=%FPS%,scale=%scale%:flags=lanczos" -c:v libwebp -lossless %lossless% -compression_level %compression% -qscale %qscale% -preset default -loop 0 -an -vsync 0 "%outputDIR%\%%~nF_out.webp"
)
goto end



:end
exit /b
