# GifMyAss
GifMyAss.bat is a script takes videos and creates animated pictures in these formats: AVIF, WEBP

Since it's difficult to remember all the command-lines for FFMPEG, and it's hard to find a good CLI or GUI for this task that works the way I need, I created this script and wanted to share it with you.

AVIF uses libsvtav1 and WEBP uses libwebp. Sadly, no transparency support.

Google's gif2webp to convert any gif to an animated WebP that supports transparency.

Usage:
- GifMyAss.bat                = Interactive mode
- GifMyAss.bat batch          = Batch mode
- GifMyAss.bat default        = List default values
- GifMyAss.bat gif2webp       = Uses google's gif2webp
- GifMyAss.bat gif2webp batch = gif2webp Batch mode
- GifMyAss.bat help           = Show this help message


It uses FFMPEG command line and carries you through the progress.

Default values are:
- set "FPS=30"
- set "scale=-1:-1"
- set "CRF=25"
- set "lossless=0"
- set "compression=6"
- set "qscale=75"
- set "preset=4"
- set "gif2webpq=80"
- set "gif2webpm=6"
- set "outputDIR=output"
- set "batchmodeDIR=batchmode"

# Smart Script
This script is designed to be easy to use and be smart. The script can handle file input like this 123.mp4 or "123.mp4". So you can easily tab the file you want to choose.

You can press Enter if you do not want to set a value, instead it uses the pre-defined default value.

Batch mode will create a folder "batchmode" and will convert every file in that folder to your desired format.

Instead of using the reference encoder libaom-av1, I use the libsvtav1 for multi-threading and WAY FASTER conversion.

You can define your own output or batchmode path. You must use normal characters like 0-9, a-z or ! for your folder. ÜÄÖ is not allowed or may need some bypass.

# Prerequisites
You need to have FFMPEG installed and add it to the PATH environment variables OR have the FFMPEG.exe saved next to GifMyAss.bat. This script will find FFMPEG this way.
You will need the download google's libwebp (gif2webp.exe) if you want to use my script's integrated use of gif2webp.
