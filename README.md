# GifMyAss
GifMyAss.bat is a script takes videos and creates animated pictures in these formats: AVIF, WEBP

AVIF uses libsvtav1 and WEBP uses libwebp.

Usage:
- GifMyAss.bat          = Interactive mode
- GifMyAss.bat batch    = Batch mode
- GifMyAss.bat help     = Show this help message


It uses FFMPEG command line and carries you through the progress.

Default values are:
- set "FPS=30"
- set "scale=-2:500"
- set "CRF=25"
- set "lossless=0"
- set "compression=6"
- set "qscale=75"
- set "preset=4"

# Smart Script
This script is designed to be easy to use and be smart. The script can handle file input like this 123.mp4 or "123.mp4". So you can easily tab the file you want to choose.

You can press Enter if you do not want to set a value, instead it uses the pre-defined default value.

Batch mode will create a folder "batchmode" and will convert every file in that folder to your desired format.

Instead of using the reference encoder libaom-av1, I use the libsvtav1 for multi-threading and WAY FASTER conversion.

# Prerequisites
You need to have FFMPEG installed and add it to the PATH environment variables OR have the FFMPEG.exe saved next to GifMyAss.bat. This script will find FFMPEG this way.
