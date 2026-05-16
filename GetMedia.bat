@echo off
setlocal EnableDelayedExpansion

:: =====================================================
::  GetMedia v1.0  |  Powered by yt-dlp + ffmpeg
:: =====================================================

set "SCRIPT_DIR=%~dp0"
set "BIN=%SCRIPT_DIR%bin"
set "YTDLP=%BIN%\yt-dlp_x86.exe"
set "FFMPEG=%BIN%\ffmpeg.exe"
set "DEFAULT_OUTPUT=%SCRIPT_DIR%Output"
set "URL_TEMP=%TEMP%\getmedia_urls.txt"

:: Default settings (can be changed in Settings menu)
set "CFG_SPEED="
set "CFG_FRAGMENTS=1"
set "CFG_RETRIES=10"
set "CFG_SKIP_EXISTING=no"
set "CFG_PLAYLIST=single"
set "CFG_PLAYLIST_LABEL=Single item only"

:: Check if tools exist
if not exist "%YTDLP%" (
    echo.
    echo  [ERROR] yt-dlp_x86.exe not found in bin\ folder!
    echo.
    pause & exit /b 1
)
if not exist "%FFMPEG%" (
    echo.
    echo  [ERROR] ffmpeg.exe not found in bin\ folder!
    echo.
    pause & exit /b 1
)

:: Create default output folder
if not exist "%DEFAULT_OUTPUT%" mkdir "%DEFAULT_OUTPUT%"


:: =====================================================
:MAIN_MENU
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   GetMedia  v1.0                     ^|
echo  ^|             Powered by yt-dlp + ffmpeg               ^|
echo  +------------------------------------------------------+
echo.
echo   [1]  Download Video
echo   [2]  Download Audio Only
echo   [3]  Download Video + Audio  (Separate Files)
echo   [4]  Playlist behavior
echo   [5]  Settings
echo   [0]  Exit
echo.
echo   Current playlist mode: !CFG_PLAYLIST_LABEL!
echo  ------------------------------------------------------
set "MAIN_CHOICE="
set /p "MAIN_CHOICE=  Choose an option: "

if "!MAIN_CHOICE!"=="1" goto DV_URL
if "!MAIN_CHOICE!"=="2" goto DA_URL
if "!MAIN_CHOICE!"=="3" goto DS_URL
if "!MAIN_CHOICE!"=="4" goto PLAYLIST_SETTINGS
if "!MAIN_CHOICE!"=="5" goto SETTINGS
if "!MAIN_CHOICE!"=="0" goto EXIT
echo.
echo   [!] Invalid option. Try again.
timeout /t 1 >nul
goto MAIN_MENU


:: =====================================================
:PLAYLIST_SETTINGS
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                PLAYLIST BEHAVIOR                   ^|
echo  +------------------------------------------------------+
echo.
echo   Current: !CFG_PLAYLIST_LABEL!
echo.
echo   [1]  Download only the single item  (default)
echo   [2]  Download all playlist items
echo   [0]  Back to Main Menu
echo.
set "PL_CHOICE="
set /p "PL_CHOICE=  Choose playlist handling [1-2, default=1]: "
if /i "!PL_CHOICE!"=="0" goto MAIN_MENU
if /i "!PL_CHOICE!"=="2" (
    set "CFG_PLAYLIST=all"
    set "CFG_PLAYLIST_LABEL=Download all"
) else (
    set "CFG_PLAYLIST=single"
    set "CFG_PLAYLIST_LABEL=Single item only"
)
echo.
echo   Playlist behavior set to: !CFG_PLAYLIST_LABEL!
timeout /t 2 >nul
goto MAIN_MENU


:: #####################################################
::  DOWNLOAD VIDEO
:: #####################################################

:DV_URL
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                  VIDEO DOWNLOAD                      ^|
echo  +------------------------------------------------------+
echo.
echo   Enter URLs one by one. Press Enter with no input when done.
echo   Type B to go back to Main Menu.
echo.
echo  ------------------------------------------------------

if exist "%URL_TEMP%" del "%URL_TEMP%"
set "URL_COUNT=0"

:DV_URL_LOOP
set "NEXT_URL="
set /p "NEXT_URL=  URL !URL_COUNT! ^> "
if /i "!NEXT_URL!"=="B" goto MAIN_MENU
if "!NEXT_URL!"=="" (
    if !URL_COUNT!==0 (
        echo   No URLs entered. Returning to menu...
        timeout /t 1 >nul
        goto MAIN_MENU
    )
    goto DV_RES
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DV_URL_LOOP


:DV_RES
echo.
echo  --- Resolution ---
echo.
echo   [1]  Best Available  (recommended)
echo   [2]  4K  (2160p)
echo   [3]  1440p
echo   [4]  1080p
echo   [5]  720p
echo   [6]  480p
echo   [7]  360p
echo   [B]  Back
echo.
set "RESOLUTION="
set "FORMAT_STR="
set "RES_CHOICE="
set /p "RES_CHOICE=  Choose resolution [1-7, default=1]: "
if /i "!RES_CHOICE!"=="B" goto DV_URL
if "!RES_CHOICE!"==""  set "RES_CHOICE=1"
if "!RES_CHOICE!"=="1" (set "RESOLUTION=Best Available" & set "FORMAT_STR=bestvideo+bestaudio/best")
if "!RES_CHOICE!"=="2" (set "RESOLUTION=4K (2160p)"     & set "FORMAT_STR=bestvideo[height<=2160]+bestaudio/best")
if "!RES_CHOICE!"=="3" (set "RESOLUTION=1440p"           & set "FORMAT_STR=bestvideo[height<=1440]+bestaudio/best")
if "!RES_CHOICE!"=="4" (set "RESOLUTION=1080p"           & set "FORMAT_STR=bestvideo[height<=1080]+bestaudio/best")
if "!RES_CHOICE!"=="5" (set "RESOLUTION=720p"            & set "FORMAT_STR=bestvideo[height<=720]+bestaudio/best")
if "!RES_CHOICE!"=="6" (set "RESOLUTION=480p"            & set "FORMAT_STR=bestvideo[height<=480]+bestaudio/best")
if "!RES_CHOICE!"=="7" (set "RESOLUTION=360p"            & set "FORMAT_STR=bestvideo[height<=360]+bestaudio/best")
if "!RESOLUTION!"=="" (
    echo   [!] Invalid choice. Defaulting to Best Available.
    set "RESOLUTION=Best Available"
    set "FORMAT_STR=bestvideo+bestaudio/best"
)


:DV_FMT
echo.
echo  --- Output Format ---
echo.
echo   [1]  mp4   (recommended, universal)
echo   [2]  mkv   (high quality container)
echo   [3]  webm  (open format)
echo   [4]  mov   (Apple QuickTime)
echo   [5]  avi   (legacy, wide compat)
echo   [6]  flv   (Flash Video)
echo   [B]  Back
echo.
set "VID_FORMAT="
set "FMT_CHOICE="
set /p "FMT_CHOICE=  Choose format [1-6, default=1]: "
if /i "!FMT_CHOICE!"=="B" goto DV_RES
if "!FMT_CHOICE!"=="" set "FMT_CHOICE=1"
if "!FMT_CHOICE!"=="1" set "VID_FORMAT=mp4"
if "!FMT_CHOICE!"=="2" set "VID_FORMAT=mkv"
if "!FMT_CHOICE!"=="3" set "VID_FORMAT=webm"
if "!FMT_CHOICE!"=="4" set "VID_FORMAT=mov"
if "!FMT_CHOICE!"=="5" set "VID_FORMAT=avi"
if "!FMT_CHOICE!"=="6" set "VID_FORMAT=flv"
if "!VID_FORMAT!"=="" set "VID_FORMAT=mp4"


:DV_SUBS
echo.
echo  --- Subtitles ---
echo.
echo   [1]  No subtitles  (default)
echo   [2]  Download subtitles  (separate .srt file)
echo   [3]  Embed subtitles into video
echo   [4]  Auto-generated subtitles  (e.g. YouTube auto-captions)
echo   [B]  Back
echo.
set "SUB_OPTS="
set "SUB_LABEL=None"
set "SUB_CHOICE="
set /p "SUB_CHOICE=  Choose subtitle option [1-4, default=1]: "
if /i "!SUB_CHOICE!"=="B" goto DV_FMT
if "!SUB_CHOICE!"=="" set "SUB_CHOICE=1"
if "!SUB_CHOICE!"=="1" (set "SUB_OPTS=" & set "SUB_LABEL=None")
if "!SUB_CHOICE!"=="2" (set "SUB_OPTS=--write-subs --sub-format srt/best" & set "SUB_LABEL=Download .srt")
if "!SUB_CHOICE!"=="3" (set "SUB_OPTS=--write-subs --embed-subs --sub-format srt/best" & set "SUB_LABEL=Embed into video")
if "!SUB_CHOICE!"=="4" (set "SUB_OPTS=--write-auto-subs --sub-format srt/best" & set "SUB_LABEL=Auto-generated")


:DV_OUT
echo.
echo  --- Output Path ---
echo.
echo   Default: !DEFAULT_OUTPUT!
echo.
echo   Press Enter to use default, or type a path. Type B to go back.
echo.
set "CUSTOM_PATH="
set "BASE_OUTPUT_PATH="
set /p "CUSTOM_PATH=  Output path: "
if /i "!CUSTOM_PATH!"=="B" goto DV_SUBS
if "!CUSTOM_PATH!"=="" (
    set "BASE_OUTPUT_PATH=!DEFAULT_OUTPUT!"
) else (
    set "BASE_OUTPUT_PATH=!CUSTOM_PATH!"
    if not exist "!BASE_OUTPUT_PATH!" mkdir "!BASE_OUTPUT_PATH!"
)

:: Ask for subfolder creation (default Yes)
set "CREATE_SUBFOLDER="
echo.
set /p "CREATE_SUBFOLDER=  Create subfolder for this download? (Y/n) [Y]: "
if /i "!CREATE_SUBFOLDER!"=="n" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!"
) else (
    set "SUBFOLDER="
    if "!CFG_PLAYLIST!"=="all" (
        set "SUBFOLDER=Video_Playlist"
    ) else (
        set "SUBFOLDER=Video"
    )
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\!SUBFOLDER!"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder created: !SUBFOLDER!
)


:: =====================================================
:DV_SUMMARY
:: =====================================================
if "!CFG_PLAYLIST!"=="single" (
    set "PL_OPTS=--no-playlist"
    set "PL_LABEL=Single video only"
) else (
    set "PL_OPTS="
    set "PL_LABEL=Download all"
)
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                  DOWNLOAD SUMMARY                    ^|
echo  +------------------------------------------------------+
echo.
echo   URLs     : !URL_COUNT! URL(s^) queued
echo   Quality  : !RESOLUTION!
echo   Format   : !VID_FORMAT!
echo   Subtitles: !SUB_LABEL!
echo   Playlist : !PL_LABEL!
echo   Output   : !OUTPUT_PATH!
if not "!CFG_SPEED!"=="" echo   Speed    : !CFG_SPEED! limit
echo   Fragments: !CFG_FRAGMENTS! concurrent
echo.
echo  ------------------------------------------------------
echo   [Y]  Start Download   [n]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [Y/n/B] (default=Y): "
:: Default to Y if empty
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DV_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   DOWNLOADING...                     ^|
echo  +------------------------------------------------------+
echo.

set "SPEED_OPT="
if not "!CFG_SPEED!"=="" set "SPEED_OPT=-r !CFG_SPEED!"
set "SKIP_OPT="
if "!CFG_SKIP_EXISTING!"=="yes" set "SKIP_OPT=-w"

"%YTDLP%" --ffmpeg-location "%BIN%" -f "!FORMAT_STR!" --merge-output-format !VID_FORMAT! !SUB_OPTS! !PL_OPTS! -N !CFG_FRAGMENTS! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s.%%(ext)s"

if errorlevel 1 (
    echo.
    echo  [!] Download interrupted or failed. Returning to main menu.
    timeout /t 2 >nul
    goto MAIN_MENU
)

echo.
echo  ------------------------------------------------------
echo   Done! File(s^) saved to: !OUTPUT_PATH!
echo  ------------------------------------------------------
echo.
pause
goto MAIN_MENU


:: #####################################################
::  DOWNLOAD AUDIO ONLY
:: #####################################################

:DA_URL
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                 AUDIO ONLY DOWNLOAD                  ^|
echo  +------------------------------------------------------+
echo.
echo   Enter URLs one by one. Press Enter with no input when done.
echo   Type B to go back to Main Menu.
echo.
echo  ------------------------------------------------------

if exist "%URL_TEMP%" del "%URL_TEMP%"
set "URL_COUNT=0"

:DA_URL_LOOP
set "NEXT_URL="
set /p "NEXT_URL=  URL !URL_COUNT! ^> "
if /i "!NEXT_URL!"=="B" goto MAIN_MENU
if "!NEXT_URL!"=="" (
    if !URL_COUNT!==0 (
        echo   No URLs entered. Returning to menu...
        timeout /t 1 >nul
        goto MAIN_MENU
    )
    goto DA_FMT
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DA_URL_LOOP


:DA_FMT
echo.
echo  --- Audio Format ---
echo.
echo   [1]  mp3     (most compatible)
echo   [2]  aac     (Apple / AAC)
echo   [3]  flac    (lossless)
echo   [4]  m4a     (iTunes)
echo   [5]  opus    (best quality/size ratio)
echo   [6]  wav     (uncompressed)
echo   [7]  alac    (Apple lossless)
echo   [8]  vorbis  (open lossless)
echo   [B]  Back
echo.
set "AUD_FORMAT="
set "AUD_CHOICE="
set /p "AUD_CHOICE=  Choose format [1-8, default=1]: "
if /i "!AUD_CHOICE!"=="B" goto DA_URL
if "!AUD_CHOICE!"=="" set "AUD_CHOICE=1"
if "!AUD_CHOICE!"=="1" set "AUD_FORMAT=mp3"
if "!AUD_CHOICE!"=="2" set "AUD_FORMAT=aac"
if "!AUD_CHOICE!"=="3" set "AUD_FORMAT=flac"
if "!AUD_CHOICE!"=="4" set "AUD_FORMAT=m4a"
if "!AUD_CHOICE!"=="5" set "AUD_FORMAT=opus"
if "!AUD_CHOICE!"=="6" set "AUD_FORMAT=wav"
if "!AUD_CHOICE!"=="7" set "AUD_FORMAT=alac"
if "!AUD_CHOICE!"=="8" set "AUD_FORMAT=vorbis"
if "!AUD_FORMAT!"=="" set "AUD_FORMAT=mp3"


:DA_QUAL
echo.
echo  --- Audio Quality ---
echo.
echo   [1]  Best   (VBR 0  - highest quality)
echo   [2]  High   (VBR 2)
echo   [3]  Medium (VBR 5)
echo   [4]  Low    (VBR 9  - smallest file)
echo   [5]  320K   (constant bitrate)
echo   [6]  256K   (constant bitrate)
echo   [7]  192K   (constant bitrate)
echo   [8]  128K   (constant bitrate)
echo   [B]  Back
echo.
set "AUD_QUALITY="
set "QUAL_CHOICE="
set /p "QUAL_CHOICE=  Choose quality [1-8, default=1]: "
if /i "!QUAL_CHOICE!"=="B" goto DA_FMT
if "!QUAL_CHOICE!"=="" set "QUAL_CHOICE=1"
if "!QUAL_CHOICE!"=="1" set "AUD_QUALITY=0"
if "!QUAL_CHOICE!"=="2" set "AUD_QUALITY=2"
if "!QUAL_CHOICE!"=="3" set "AUD_QUALITY=5"
if "!QUAL_CHOICE!"=="4" set "AUD_QUALITY=9"
if "!QUAL_CHOICE!"=="5" set "AUD_QUALITY=320K"
if "!QUAL_CHOICE!"=="6" set "AUD_QUALITY=256K"
if "!QUAL_CHOICE!"=="7" set "AUD_QUALITY=192K"
if "!QUAL_CHOICE!"=="8" set "AUD_QUALITY=128K"
if "!AUD_QUALITY!"=="" set "AUD_QUALITY=0"


:DA_OUT
echo.
echo  --- Output Path ---
echo.
echo   Default: !DEFAULT_OUTPUT!
echo.
echo   Press Enter to use default, or type a path. Type B to go back.
echo.
set "CUSTOM_PATH="
set "BASE_OUTPUT_PATH="
set /p "CUSTOM_PATH=  Output path: "
if /i "!CUSTOM_PATH!"=="B" goto DA_QUAL
if "!CUSTOM_PATH!"=="" (
    set "BASE_OUTPUT_PATH=!DEFAULT_OUTPUT!"
) else (
    set "BASE_OUTPUT_PATH=!CUSTOM_PATH!"
    if not exist "!BASE_OUTPUT_PATH!" mkdir "!BASE_OUTPUT_PATH!"
)

:: Ask for subfolder creation (default Yes)
set "CREATE_SUBFOLDER="
echo.
set /p "CREATE_SUBFOLDER=  Create subfolder for this download? (Y/n) [Y]: "
if /i "!CREATE_SUBFOLDER!"=="n" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!"
) else (
    set "SUBFOLDER=Audio"
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\!SUBFOLDER!"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder created: !SUBFOLDER!
)


:DA_SUMMARY
if "!CFG_PLAYLIST!"=="single" (
    set "PL_OPTS=--no-playlist"
    set "PL_LABEL=Single track only"
) else (
    set "PL_OPTS="
    set "PL_LABEL=Download all"
)
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   DOWNLOAD SUMMARY                   ^|
echo  +------------------------------------------------------+
echo.
echo   URLs     : !URL_COUNT! URL(s^) queued
echo   Format   : !AUD_FORMAT!
echo   Quality  : !AUD_QUALITY!
echo   Playlist : !PL_LABEL!
echo   Output   : !OUTPUT_PATH!
if not "!CFG_SPEED!"=="" echo   Speed    : !CFG_SPEED! limit
echo.
echo  ------------------------------------------------------
echo   [Y]  Start Download   [n]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [Y/n/B] (default=Y): "
:: Default to Y if empty
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DA_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   DOWNLOADING...                     ^|
echo  +------------------------------------------------------+
echo.

set "SPEED_OPT="
if not "!CFG_SPEED!"=="" set "SPEED_OPT=-r !CFG_SPEED!"
set "SKIP_OPT="
if "!CFG_SKIP_EXISTING!"=="yes" set "SKIP_OPT=-w"

"%YTDLP%" --ffmpeg-location "%BIN%" -x --audio-format !AUD_FORMAT! --audio-quality !AUD_QUALITY! !PL_OPTS! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s.%%(ext)s"

if errorlevel 1 (
    echo.
    echo  [!] Download interrupted or failed. Returning to main menu.
    timeout /t 2 >nul
    goto MAIN_MENU
)

echo.
echo  ------------------------------------------------------
echo   Done! File(s^) saved to: !OUTPUT_PATH!
echo  ------------------------------------------------------
echo.
pause
goto MAIN_MENU


:: #####################################################
::  DOWNLOAD SEPARATE VIDEO + AUDIO
:: #####################################################

:DS_URL
cls
echo.
echo  +------------------------------------------------------+
echo  ^|          SEPARATE VIDEO + AUDIO DOWNLOAD             ^|
echo  +------------------------------------------------------+
echo.
echo   Enter URLs one by one. Press Enter with no input when done.
echo   Type B to go back to Main Menu.
echo.
echo  ------------------------------------------------------

if exist "%URL_TEMP%" del "%URL_TEMP%"
set "URL_COUNT=0"

:DS_URL_LOOP
set "NEXT_URL="
set /p "NEXT_URL=  URL !URL_COUNT! ^> "
if /i "!NEXT_URL!"=="B" goto MAIN_MENU
if "!NEXT_URL!"=="" (
    if !URL_COUNT!==0 (
        echo   No URLs entered. Returning to menu...
        timeout /t 1 >nul
        goto MAIN_MENU
    )
    goto DS_RES
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DS_URL_LOOP


:DS_RES
echo.
echo  --- Video Resolution ---
echo.
echo   [1]  Best Available  (recommended)
echo   [2]  4K  (2160p)
echo   [3]  1440p
echo   [4]  1080p
echo   [5]  720p
echo   [6]  480p
echo   [7]  360p
echo   [B]  Back
echo.
set "RESOLUTION="
set "VID_FORMAT_STR="
set "RES_CHOICE="
set /p "RES_CHOICE=  Choose resolution [1-7, default=1]: "
if /i "!RES_CHOICE!"=="B" goto DS_URL
if "!RES_CHOICE!"=="" set "RES_CHOICE=1"
if "!RES_CHOICE!"=="1" (set "RESOLUTION=Best Available" & set "VID_FORMAT_STR=bestvideo")
if "!RES_CHOICE!"=="2" (set "RESOLUTION=4K (2160p)"     & set "VID_FORMAT_STR=bestvideo[height<=2160]")
if "!RES_CHOICE!"=="3" (set "RESOLUTION=1440p"           & set "VID_FORMAT_STR=bestvideo[height<=1440]")
if "!RES_CHOICE!"=="4" (set "RESOLUTION=1080p"           & set "VID_FORMAT_STR=bestvideo[height<=1080]")
if "!RES_CHOICE!"=="5" (set "RESOLUTION=720p"            & set "VID_FORMAT_STR=bestvideo[height<=720]")
if "!RES_CHOICE!"=="6" (set "RESOLUTION=480p"            & set "VID_FORMAT_STR=bestvideo[height<=480]")
if "!RES_CHOICE!"=="7" (set "RESOLUTION=360p"            & set "VID_FORMAT_STR=bestvideo[height<=360]")
if "!RESOLUTION!"=="" (
    set "RESOLUTION=Best Available"
    set "VID_FORMAT_STR=bestvideo"
)


:DS_AUD_FMT
echo.
echo  --- Audio Format (separate file) ---
echo.
echo   [1]  mp3     (most compatible)
echo   [2]  aac
echo   [3]  flac    (lossless)
echo   [4]  m4a
echo   [5]  opus
echo   [6]  wav
echo   [7]  alac
echo   [8]  vorbis
echo   [B]  Back
echo.
set "AUD_FORMAT="
set "AUD_CHOICE="
set /p "AUD_CHOICE=  Choose audio format [1-8, default=1]: "
if /i "!AUD_CHOICE!"=="B" goto DS_RES
if "!AUD_CHOICE!"=="" set "AUD_CHOICE=1"
if "!AUD_CHOICE!"=="1" set "AUD_FORMAT=mp3"
if "!AUD_CHOICE!"=="2" set "AUD_FORMAT=aac"
if "!AUD_CHOICE!"=="3" set "AUD_FORMAT=flac"
if "!AUD_CHOICE!"=="4" set "AUD_FORMAT=m4a"
if "!AUD_CHOICE!"=="5" set "AUD_FORMAT=opus"
if "!AUD_CHOICE!"=="6" set "AUD_FORMAT=wav"
if "!AUD_CHOICE!"=="7" set "AUD_FORMAT=alac"
if "!AUD_CHOICE!"=="8" set "AUD_FORMAT=vorbis"
if "!AUD_FORMAT!"=="" set "AUD_FORMAT=mp3"


:DS_OUT
echo.
echo  --- Output Path ---
echo.
echo   Default: !DEFAULT_OUTPUT!
echo.
echo   Press Enter to use default, or type a path. Type B to go back.
echo.
set "CUSTOM_PATH="
set "BASE_OUTPUT_PATH="
set /p "CUSTOM_PATH=  Output path: "
if /i "!CUSTOM_PATH!"=="B" goto DS_AUD_FMT
if "!CUSTOM_PATH!"=="" (
    set "BASE_OUTPUT_PATH=!DEFAULT_OUTPUT!"
) else (
    set "BASE_OUTPUT_PATH=!CUSTOM_PATH!"
    if not exist "!BASE_OUTPUT_PATH!" mkdir "!BASE_OUTPUT_PATH!"
)

:: Ask for subfolder creation (default Yes)
set "CREATE_SUBFOLDER="
echo.
set /p "CREATE_SUBFOLDER=  Create subfolder for this download? (Y/n) [Y]: "
if /i "!CREATE_SUBFOLDER!"=="n" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!"
) else (
    set "SUBFOLDER=Video+Audio"
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\!SUBFOLDER!"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder created: !SUBFOLDER!
)


:DS_SUMMARY
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                  DOWNLOAD SUMMARY                    ^|
echo  +------------------------------------------------------+
echo.
echo   URLs          : !URL_COUNT! URL(s^) queued
echo   Video Quality : !RESOLUTION!
echo   Audio Format  : !AUD_FORMAT!
echo   Output        : !OUTPUT_PATH!
echo.
echo   NOTE: Video and audio will be saved as SEPARATE files.
echo.
echo  ------------------------------------------------------
echo   [Y]  Start Download   [n]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [Y/n/B] (default=Y): "
:: Default to Y if empty
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DS_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                 DOWNLOADING VIDEO...                 ^|
echo  +------------------------------------------------------+
echo.

set "SPEED_OPT="
if not "!CFG_SPEED!"=="" set "SPEED_OPT=-r !CFG_SPEED!"
set "SKIP_OPT="
if "!CFG_SKIP_EXISTING!"=="yes" set "SKIP_OPT=-w"

"%YTDLP%" --ffmpeg-location "%BIN%" -f "!VID_FORMAT_STR!" -N !CFG_FRAGMENTS! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s [VIDEO].%%(ext)s"

if errorlevel 1 (
    echo.
    echo  [!] Video download interrupted or failed. Returning to main menu.
    timeout /t 2 >nul
    goto MAIN_MENU
)

echo.
echo  +------------------------------------------------------+
echo  ^|                 DOWNLOADING AUDIO...                 ^|
echo  +------------------------------------------------------+
echo.

"%YTDLP%" --ffmpeg-location "%BIN%" -x --audio-format !AUD_FORMAT! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s [AUDIO].%%(ext)s"

if errorlevel 1 (
    echo.
    echo  [!] Audio download interrupted or failed. Returning to main menu.
    timeout /t 2 >nul
    goto MAIN_MENU
)

echo.
echo  ------------------------------------------------------
echo   Done! Files saved to: !OUTPUT_PATH!
echo  ------------------------------------------------------
echo.
pause
goto MAIN_MENU


:: =====================================================
:SETTINGS
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                      SETTINGS                        ^|
echo  +------------------------------------------------------+
echo.
echo   Output path    : !DEFAULT_OUTPUT!
if "!CFG_SPEED!"=="" (
    echo   Speed limit    : Unlimited
) else (
    echo   Speed limit    : !CFG_SPEED!
)
echo   Concurrent DL  : !CFG_FRAGMENTS! fragment(s^)
echo   Retries        : !CFG_RETRIES!
echo   Skip existing  : !CFG_SKIP_EXISTING!
echo   Playlist        : !CFG_PLAYLIST_LABEL!
echo.
echo  ------------------------------------------------------
echo   [1]  Change default output path
echo   [2]  Open output folder in Explorer
echo   [3]  Set download speed limit
echo   [4]  Set concurrent fragments  (for DASH/HLS streams)
echo   [5]  Set number of retries
echo   [6]  Toggle skip existing files  (currently: !CFG_SKIP_EXISTING!^)
echo   [0]  Back to Main Menu
echo.
set "SET_CHOICE="
set /p "SET_CHOICE=  Choose an option: "

if "!SET_CHOICE!"=="1" (
    echo.
    set "NEW_PATH="
    set /p "NEW_PATH=  Enter new default output path: "
    if not "!NEW_PATH!"=="" (
        set "DEFAULT_OUTPUT=!NEW_PATH!"
        if not exist "!DEFAULT_OUTPUT!" mkdir "!DEFAULT_OUTPUT!"
        echo   Path updated to: !DEFAULT_OUTPUT!
    )
    timeout /t 2 >nul
    goto SETTINGS
)
if "!SET_CHOICE!"=="2" (
    explorer "!DEFAULT_OUTPUT!"
    goto SETTINGS
)
if "!SET_CHOICE!"=="3" (
    echo.
    echo   Enter speed limit e.g. 500K, 2M, or press Enter to remove limit:
    set "NEW_SPEED="
    set /p "NEW_SPEED=  Speed limit: "
    set "CFG_SPEED=!NEW_SPEED!"
    if "!CFG_SPEED!"=="" (
        echo   Speed limit removed.
    ) else (
        echo   Speed limit set to: !CFG_SPEED!
    )
    timeout /t 2 >nul
    goto SETTINGS
)
if "!SET_CHOICE!"=="4" (
    echo.
    echo   Enter number of concurrent fragments [1-16, default=1]:
    set "NEW_FRAG="
    set /p "NEW_FRAG=  Fragments: "
    if not "!NEW_FRAG!"=="" set "CFG_FRAGMENTS=!NEW_FRAG!"
    echo   Concurrent fragments set to: !CFG_FRAGMENTS!
    timeout /t 2 >nul
    goto SETTINGS
)
if "!SET_CHOICE!"=="5" (
    echo.
    echo   Enter number of retries [default=10, or type infinite]:
    set "NEW_RETRY="
    set /p "NEW_RETRY=  Retries: "
    if not "!NEW_RETRY!"=="" set "CFG_RETRIES=!NEW_RETRY!"
    echo   Retries set to: !CFG_RETRIES!
    timeout /t 2 >nul
    goto SETTINGS
)
if "!SET_CHOICE!"=="6" (
    if "!CFG_SKIP_EXISTING!"=="no" (
        set "CFG_SKIP_EXISTING=yes"
        echo   Skip existing files: ENABLED
    ) else (
        set "CFG_SKIP_EXISTING=no"
        echo   Skip existing files: DISABLED
    )
    timeout /t 2 >nul
    goto SETTINGS
)
if "!SET_CHOICE!"=="0" goto MAIN_MENU
goto SETTINGS


:: =====================================================
:EXIT
:: =====================================================
if exist "%URL_TEMP%" del "%URL_TEMP%"
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                      GetMedia                        ^|
echo  +------------------------------------------------------+
echo.
echo   Thanks for using GetMedia. Goodbye!
echo.
timeout /t 2 >nul
exit /b 0