@echo off
setlocal EnableDelayedExpansion
title GetMedia v1.1

:: =====================================================
::  GetMedia v1.1  |  Powered by yt-dlp + ffmpeg
:: =====================================================

set "SCRIPT_DIR=%~dp0"
set "BIN=%SCRIPT_DIR%bin"
set "YTDLP=%BIN%\yt-dlp.exe"
set "FFMPEG=%BIN%\ffmpeg.exe"
set "DEFAULT_OUTPUT=%SCRIPT_DIR%Output"
set "URL_TEMP=%TEMP%\getmedia_urls.txt"

:: ----- Default settings (changeable in Settings menu) -----
set "CFG_SPEED="
set "CFG_FRAGMENTS=1"
set "CFG_RETRIES=10"
set "CFG_SKIP_EXISTING=no"
set "CFG_PLAYLIST=single"
set "CFG_PLAYLIST_LABEL=Single item only"
set "CFG_METADATA=yes"
set "CFG_THUMBNAIL=yes"
set "CFG_SPONSORBLOCK=no"
set "CFG_COOKIES=none"
set "CFG_COOKIES_LABEL=No cookies"
set "CFG_PREVIEW=yes"
set "CFG_SLEEP="
set "CFG_CHAPTERS=yes"
set "CFG_HISTORY=no"

:: Common yt-dlp flags applied to every download
set "COMMON_OPTS=--windows-filenames --console-title --mtime --no-warnings --retry-sleep linear=1::5"

:: ============== Tool Validation (ffmpeg + yt-dlp) ==============
call :CHECK_TOOLS
if errorlevel 1 exit /b 1

if not exist "%DEFAULT_OUTPUT%" mkdir "%DEFAULT_OUTPUT%"

goto MAIN_MENU


:: =====================================================
:: HELPER: CHECK_TOOLS - validates ffmpeg + yt-dlp
:: =====================================================
:CHECK_TOOLS
if not exist "%YTDLP%" (
    echo.
    echo  [ERROR] yt-dlp.exe not found!
    echo  Expected location: %YTDLP%
    echo.
    echo  Please place yt-dlp.exe in the bin folder.
    echo.
    pause & exit /b 1
)
if not exist "%FFMPEG%" (
    echo.
    echo  [ERROR] ffmpeg.exe not found!
    echo  Expected location: %FFMPEG%
    echo.
    echo  Please place ffmpeg.exe in the bin folder.
    echo.
    pause & exit /b 1
)
"%FFMPEG%" -version >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [ERROR] ffmpeg.exe failed validation - the file may be corrupt.
    echo.
    pause & exit /b 1
)
"%YTDLP%" --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [ERROR] yt-dlp.exe failed validation - the file may be corrupt.
    echo.
    pause & exit /b 1
)
exit /b 0


:: =====================================================
:: HELPER: VALIDATE_URL - sets _url_valid = yes/no
:: input: _url
:: =====================================================
:VALIDATE_URL
set "_url_valid=no"
if "!_url!"=="" exit /b 0
if /i "!_url:~0,7!"=="http://"  set "_url_valid=yes"
if /i "!_url:~0,8!"=="https://" set "_url_valid=yes"
exit /b 0


:: =====================================================
:: HELPER: SHOW_VERSIONS - displays yt-dlp + ffmpeg versions
:: =====================================================
:SHOW_VERSIONS
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                  TOOL VERSIONS                       ^|
echo  +------------------------------------------------------+
echo.
echo   yt-dlp:
"%YTDLP%" --version
echo.
echo   ffmpeg:
"%FFMPEG%" -version 2>&1 | findstr /b /c:"ffmpeg version"
echo.
pause
exit /b 0


:: =====================================================
:: HELPER: PREVIEW_URLS - fetches title/duration/uploader/size
:: Prints a numbered preview for every URL in %URL_TEMP%
:: =====================================================
:PREVIEW_URLS
if /i not "!CFG_PREVIEW!"=="yes" exit /b 0
echo.
echo  --- Video Information Preview ---
echo  Fetching info from yt-dlp (this may take a moment)...
echo.
set "_cookie_opt="
if not "!CFG_COOKIES!"=="none" set "_cookie_opt=--cookies-from-browser !CFG_COOKIES!"
set "_pv_idx=0"
for /f "usebackq tokens=* delims=" %%U in ("%URL_TEMP%") do (
    set /a _pv_idx+=1
    echo   !_pv_idx!.
    "%YTDLP%" --no-warnings --skip-download --ignore-no-formats-error !_cookie_opt! --print "  Title    : %%(title)s" --print "  Uploader : %%(uploader)s" --print "  Duration : %%(duration_string)s" --print "  Filesize : %%(filesize_approx)s bytes" -I 1:1 "%%U" 2>nul
    if errorlevel 1 echo     [^^!] Could not fetch info for this URL.
    echo.
)
exit /b 0


:: =====================================================
:: HELPER: BUILD_DL_OPTS - builds shared yt-dlp option flags
:: Sets: SPEED_OPT, SKIP_OPT, META_OPT, CHAP_OPT, THUMB_OPT,
::       SB_OPT, COOKIE_OPT, SLEEP_OPT, HISTORY_OPT
:: =====================================================
:BUILD_DL_OPTS
set "SPEED_OPT="
if not "!CFG_SPEED!"=="" set "SPEED_OPT=-r !CFG_SPEED!"
set "SKIP_OPT="
if /i "!CFG_SKIP_EXISTING!"=="yes" set "SKIP_OPT=-w"
set "META_OPT="
if /i "!CFG_METADATA!"=="yes" set "META_OPT=--embed-metadata"
set "CHAP_OPT="
if /i "!CFG_CHAPTERS!"=="yes" set "CHAP_OPT=--embed-chapters"
set "THUMB_OPT="
if /i "!CFG_THUMBNAIL!"=="yes" set "THUMB_OPT=--embed-thumbnail"
set "SB_OPT="
if /i "!CFG_SPONSORBLOCK!"=="yes" set "SB_OPT=--sponsorblock-remove default"
set "COOKIE_OPT="
if not "!CFG_COOKIES!"=="none" set "COOKIE_OPT=--cookies-from-browser !CFG_COOKIES!"
set "SLEEP_OPT="
if not "!CFG_SLEEP!"=="" set "SLEEP_OPT=--sleep-interval !CFG_SLEEP! --max-sleep-interval !CFG_SLEEP!"
set "HISTORY_OPT="
:: --print-to-file fires after_move (only for completed files), writes one line per item
:: Separator is " - " to avoid escaping pipe; %%(...) is the yt-dlp template syntax
:: upload_date gives YYYYMMDD format (we avoid the >%%Y-%%m-%%d formatter to dodge CMD redirect parsing)
if /i "!CFG_HISTORY!"=="yes" set HISTORY_OPT=--print-to-file "after_move:%%(upload_date)s - %%(title)s - %%(webpage_url)s" "!OUTPUT_PATH!\_history.txt"
exit /b 0


:: =====================================================
:: HELPER: POST_DOWNLOAD - shown after every download
:: Inputs: _DONE_STATUS (OK/FAIL), _DONE_MODE, _DONE_PATH,
::         _DONE_COUNT, _DONE_EXTRA (optional)
:: =====================================================
:POST_DOWNLOAD
cls
echo.
if /i "!_DONE_STATUS!"=="OK" (
    echo  +------------------------------------------------------+
    echo  ^|                 DOWNLOAD COMPLETE                    ^|
    echo  +------------------------------------------------------+
    echo.
    echo   Status      : [OK] Success
) else (
    echo  +------------------------------------------------------+
    echo  ^|                  DOWNLOAD FAILED                     ^|
    echo  +------------------------------------------------------+
    echo.
    echo   Status      : [!] Failed or interrupted
)
echo   URLs queued : !_DONE_COUNT! URL(s^)
echo   Mode        : !_DONE_MODE!
echo   Saved to    : !_DONE_PATH!
if defined _DONE_EXTRA echo   Note        : !_DONE_EXTRA!
echo.
if /i not "!_DONE_STATUS!"=="OK" (
    echo   Common causes: invalid URL, network issue, age-restricted
    echo   content, missing cookies, or outdated yt-dlp
    echo   ^(Settings -^> Update yt-dlp^).
    echo.
)
echo  ------------------------------------------------------
echo   [Y]  Return to Main Menu  (default)
echo   [N]  Exit GetMedia
echo   [O]  Open output folder
echo  ------------------------------------------------------

:POST_DOWNLOAD_PROMPT
set "POST_CHOICE="
set /p "POST_CHOICE=  Choose [Y/N/O]: "
if "!POST_CHOICE!"=="" set "POST_CHOICE=Y"
if /i "!POST_CHOICE!"=="O" (
    if exist "!_DONE_PATH!" (
        start "" "!_DONE_PATH!"
    ) else (
        echo   [^^!] Folder not found: !_DONE_PATH!
    )
    goto POST_DOWNLOAD_PROMPT
)
if /i "!POST_CHOICE!"=="N" goto EXIT
if /i "!POST_CHOICE!"=="Y" goto MAIN_MENU
echo   [^^!] Invalid option. Try again.
goto POST_DOWNLOAD_PROMPT


:: =====================================================
:MAIN_MENU
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   GetMedia  v1.1                     ^|
echo  ^|             Powered by yt-dlp + ffmpeg               ^|
echo  +------------------------------------------------------+
echo.
echo   [1]  Download Video
echo   [2]  Download Audio Only
echo   [3]  Download Video + Audio  (Separate Files)
echo   [4]  Playlist behavior
echo   [5]  Settings
echo   [X]  Exit
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
if /i "!MAIN_CHOICE!"=="X" goto EXIT
if /i "!MAIN_CHOICE!"=="Q" goto EXIT
echo.
echo   [^^!] Invalid option. Try again.
timeout /t 1 >nul
goto MAIN_MENU


:: =====================================================
:PLAYLIST_SETTINGS
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                  PLAYLIST BEHAVIOR                   ^|
echo  +------------------------------------------------------+
echo.
echo   Current: !CFG_PLAYLIST_LABEL!
echo.
echo   [1]  Download only the single item  (default)
echo   [2]  Download all playlist items
echo   [B]  Back to Main Menu
echo.
set "PL_CHOICE="
set /p "PL_CHOICE=  Choose playlist handling [1-2, default=1]: "
if /i "!PL_CHOICE!"=="B" goto MAIN_MENU
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
::  DOWNLOAD VIDEO  (6 steps)
:: #####################################################

:DV_URL
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                  VIDEO DOWNLOAD                      ^|
echo  ^|              [Step 1/6]  URL Input                   ^|
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
        echo   [^^!] No URLs entered. Returning to menu...
        timeout /t 2 >nul
        goto MAIN_MENU
    )
    goto DV_RES
)
set "_url=!NEXT_URL!"
call :VALIDATE_URL
if /i not "!_url_valid!"=="yes" (
    echo   [^^!] Invalid URL - must start with http:// or https://
    goto DV_URL_LOOP
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DV_URL_LOOP


:DV_RES
echo.
echo  +------------------------------------------------------+
echo  ^|              [Step 2/6]  Resolution                  ^|
echo  +------------------------------------------------------+
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
if "!RES_CHOICE!"=="3" (set "RESOLUTION=1440p"          & set "FORMAT_STR=bestvideo[height<=1440]+bestaudio/best")
if "!RES_CHOICE!"=="4" (set "RESOLUTION=1080p"          & set "FORMAT_STR=bestvideo[height<=1080]+bestaudio/best")
if "!RES_CHOICE!"=="5" (set "RESOLUTION=720p"           & set "FORMAT_STR=bestvideo[height<=720]+bestaudio/best")
if "!RES_CHOICE!"=="6" (set "RESOLUTION=480p"           & set "FORMAT_STR=bestvideo[height<=480]+bestaudio/best")
if "!RES_CHOICE!"=="7" (set "RESOLUTION=360p"           & set "FORMAT_STR=bestvideo[height<=360]+bestaudio/best")
if "!RESOLUTION!"=="" (
    echo   [^^!] Invalid choice. Defaulting to Best Available.
    set "RESOLUTION=Best Available"
    set "FORMAT_STR=bestvideo+bestaudio/best"
    timeout /t 1 >nul
)


:DV_FMT
echo.
echo  +------------------------------------------------------+
echo  ^|             [Step 3/6]  Output Format                ^|
echo  +------------------------------------------------------+
echo.
echo   [1]  mp4    (recommended, universal)
echo   [2]  mkv    (high quality container)
echo   [3]  webm   (open format)
echo   [4]  mov    (Apple QuickTime)
echo   [5]  avi    (legacy, wide compat)
echo   [6]  flv    (Flash Video)
echo   [7]  Custom format string  (advanced)
echo   [B]  Back
echo.
set "VID_FORMAT="
set "FMT_CHOICE="
set /p "FMT_CHOICE=  Choose format [1-7, default=1]: "
if /i "!FMT_CHOICE!"=="B" goto DV_RES
if "!FMT_CHOICE!"=="" set "FMT_CHOICE=1"
if "!FMT_CHOICE!"=="1" set "VID_FORMAT=mp4"
if "!FMT_CHOICE!"=="2" set "VID_FORMAT=mkv"
if "!FMT_CHOICE!"=="3" set "VID_FORMAT=webm"
if "!FMT_CHOICE!"=="4" set "VID_FORMAT=mov"
if "!FMT_CHOICE!"=="5" set "VID_FORMAT=avi"
if "!FMT_CHOICE!"=="6" set "VID_FORMAT=flv"
if "!FMT_CHOICE!"=="7" (
    echo.
    echo   Example: bestvideo[height^<=1080][vcodec^^^=h264]+bestaudio[acodec^^^=aac]
    set "CUSTOM_FMT="
    set /p "CUSTOM_FMT=  Enter custom format string: "
    if "!CUSTOM_FMT!"=="" (
        set "VID_FORMAT=mp4"
    ) else (
        set "FORMAT_STR=!CUSTOM_FMT!"
        set "VID_FORMAT=mp4"
        set "RESOLUTION=Custom: !CUSTOM_FMT!"
    )
)
if "!VID_FORMAT!"=="" set "VID_FORMAT=mp4"


:DV_SUBS
echo.
echo  +------------------------------------------------------+
echo  ^|              [Step 4/6]  Subtitles                   ^|
echo  +------------------------------------------------------+
echo.
echo   [1]  No subtitles  (default)
echo   [2]  Auto-generated subtitles  (e.g. YouTube auto-captions)
echo   [B]  Back
echo.
set "SUB_OPTS="
set "SUB_LABEL=None"
set "SUB_CHOICE="
set /p "SUB_CHOICE=  Choose subtitle option [1-2, default=1]: "
if /i "!SUB_CHOICE!"=="B" goto DV_FMT
if "!SUB_CHOICE!"=="" set "SUB_CHOICE=1"
if "!SUB_CHOICE!"=="2" (
    echo.
    echo   Language codes: en  id  ja  es  ko  zh  etc.
    set "SUB_LANG_IN="
    set /p "SUB_LANG_IN=  Subtitle language [default=en]: "
    if "!SUB_LANG_IN!"=="" set "SUB_LANG_IN=en"
    :: --sub-langs <code> gets only that exact variant (avoids en + en-orig duplicates)
    :: --convert-subs srt converts json3/vtt to proper SRT
    set "SUB_OPTS=--write-auto-subs --sub-langs !SUB_LANG_IN! --convert-subs srt"
    set "SUB_LABEL=Auto-generated [!SUB_LANG_IN!]"
)


:DV_OUT
echo.
echo  +------------------------------------------------------+
echo  ^|             [Step 5/6]  Output Path                  ^|
echo  +------------------------------------------------------+
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
    if not exist "!BASE_OUTPUT_PATH!" (
        echo   [^^!] Could not create folder. Using default.
        set "BASE_OUTPUT_PATH=!DEFAULT_OUTPUT!"
        timeout /t 2 >nul
    )
)

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
::  DV_SUMMARY - [Step 6/6]
:: =====================================================
:DV_SUMMARY
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
echo  ^|             [Step 6/6]  Download Summary             ^|
echo  +------------------------------------------------------+
echo.
echo   URLs        : !URL_COUNT! URL(s^) queued
echo   Quality     : !RESOLUTION!
echo   Format      : !VID_FORMAT!
echo   Subtitles   : !SUB_LABEL!
echo   Playlist    : !PL_LABEL!
echo   Output      : !OUTPUT_PATH!
echo   Metadata    : !CFG_METADATA!    Thumbnail: !CFG_THUMBNAIL!
echo   SponsorBlock: !CFG_SPONSORBLOCK!
echo   Cookies     : !CFG_COOKIES_LABEL!
if not "!CFG_SPEED!"=="" echo   Speed       : !CFG_SPEED! limit
echo   Fragments   : !CFG_FRAGMENTS! concurrent

call :PREVIEW_URLS

echo  ------------------------------------------------------
echo   [Y]  Start Download   [N]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [Y/N/B] (default=Y): "
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DV_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   DOWNLOADING...                     ^|
echo  +------------------------------------------------------+
echo.

call :BUILD_DL_OPTS

"%YTDLP%" --ffmpeg-location "%BIN%" %COMMON_OPTS% -f "!FORMAT_STR!" --merge-output-format !VID_FORMAT! !SUB_OPTS! !PL_OPTS! !META_OPT! !CHAP_OPT! !THUMB_OPT! !SB_OPT! !COOKIE_OPT! !SLEEP_OPT! -N !CFG_FRAGMENTS! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s.%%(ext)s"

set "_DL_RC=!ERRORLEVEL!"
set "_DONE_COUNT=!URL_COUNT!"
set "_DONE_PATH=!OUTPUT_PATH!"
set "_DONE_MODE=Video - !VID_FORMAT!, !RESOLUTION! / Subs: !SUB_LABEL!"
set "_DONE_EXTRA="
if !_DL_RC! NEQ 0 (set "_DONE_STATUS=FAIL") else (set "_DONE_STATUS=OK")
goto POST_DOWNLOAD


:: #####################################################
::  DOWNLOAD AUDIO ONLY  (5 steps)
:: #####################################################

:DA_URL
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                 AUDIO ONLY DOWNLOAD                  ^|
echo  ^|              [Step 1/5]  URL Input                   ^|
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
        echo   [^^!] No URLs entered. Returning to menu...
        timeout /t 2 >nul
        goto MAIN_MENU
    )
    goto DA_FMT
)
set "_url=!NEXT_URL!"
call :VALIDATE_URL
if /i not "!_url_valid!"=="yes" (
    echo   [^^!] Invalid URL - must start with http:// or https://
    goto DA_URL_LOOP
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DA_URL_LOOP


:DA_FMT
echo.
echo  +------------------------------------------------------+
echo  ^|             [Step 2/5]  Audio Format                 ^|
echo  +------------------------------------------------------+
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
echo  +------------------------------------------------------+
echo  ^|             [Step 3/5]  Audio Quality                ^|
echo  +------------------------------------------------------+
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
echo  +------------------------------------------------------+
echo  ^|             [Step 4/5]  Output Path                  ^|
echo  +------------------------------------------------------+
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
    if not exist "!BASE_OUTPUT_PATH!" (
        echo   [^^!] Could not create folder. Using default.
        set "BASE_OUTPUT_PATH=!DEFAULT_OUTPUT!"
        timeout /t 2 >nul
    )
)

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
echo  ^|             [Step 5/5]  Download Summary             ^|
echo  +------------------------------------------------------+
echo.
echo   URLs        : !URL_COUNT! URL(s^) queued
echo   Format      : !AUD_FORMAT!
echo   Quality     : !AUD_QUALITY!
echo   Playlist    : !PL_LABEL!
echo   Output      : !OUTPUT_PATH!
echo   Metadata    : !CFG_METADATA!    Thumbnail: !CFG_THUMBNAIL!
echo   Cookies     : !CFG_COOKIES_LABEL!
if not "!CFG_SPEED!"=="" echo   Speed       : !CFG_SPEED! limit

call :PREVIEW_URLS

echo  ------------------------------------------------------
echo   [Y]  Start Download   [N]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [Y/N/B] (default=Y): "
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DA_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   DOWNLOADING...                     ^|
echo  +------------------------------------------------------+
echo.

call :BUILD_DL_OPTS

"%YTDLP%" --ffmpeg-location "%BIN%" %COMMON_OPTS% -x --audio-format !AUD_FORMAT! --audio-quality !AUD_QUALITY! !PL_OPTS! !META_OPT! !THUMB_OPT! !COOKIE_OPT! !SLEEP_OPT! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s.%%(ext)s"

set "_DL_RC=!ERRORLEVEL!"
set "_DONE_COUNT=!URL_COUNT!"
set "_DONE_PATH=!OUTPUT_PATH!"
set "_DONE_MODE=Audio Only - !AUD_FORMAT! @ !AUD_QUALITY!"
set "_DONE_EXTRA="
if !_DL_RC! NEQ 0 (set "_DONE_STATUS=FAIL") else (set "_DONE_STATUS=OK")
goto POST_DOWNLOAD


:: #####################################################
::  DOWNLOAD SEPARATE VIDEO + AUDIO  (5 steps)
:: #####################################################

:DS_URL
cls
echo.
echo  +------------------------------------------------------+
echo  ^|          SEPARATE VIDEO + AUDIO DOWNLOAD             ^|
echo  ^|              [Step 1/5]  URL Input                   ^|
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
        echo   [^^!] No URLs entered. Returning to menu...
        timeout /t 2 >nul
        goto MAIN_MENU
    )
    goto DS_RES
)
set "_url=!NEXT_URL!"
call :VALIDATE_URL
if /i not "!_url_valid!"=="yes" (
    echo   [^^!] Invalid URL - must start with http:// or https://
    goto DS_URL_LOOP
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DS_URL_LOOP


:DS_RES
echo.
echo  +------------------------------------------------------+
echo  ^|           [Step 2/5]  Video Resolution               ^|
echo  +------------------------------------------------------+
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
if "!RES_CHOICE!"=="3" (set "RESOLUTION=1440p"          & set "VID_FORMAT_STR=bestvideo[height<=1440]")
if "!RES_CHOICE!"=="4" (set "RESOLUTION=1080p"          & set "VID_FORMAT_STR=bestvideo[height<=1080]")
if "!RES_CHOICE!"=="5" (set "RESOLUTION=720p"           & set "VID_FORMAT_STR=bestvideo[height<=720]")
if "!RES_CHOICE!"=="6" (set "RESOLUTION=480p"           & set "VID_FORMAT_STR=bestvideo[height<=480]")
if "!RES_CHOICE!"=="7" (set "RESOLUTION=360p"           & set "VID_FORMAT_STR=bestvideo[height<=360]")
if "!RESOLUTION!"=="" (
    set "RESOLUTION=Best Available"
    set "VID_FORMAT_STR=bestvideo"
)


:DS_AUD_FMT
echo.
echo  +------------------------------------------------------+
echo  ^|        [Step 3/5]  Audio Format (separate file)      ^|
echo  +------------------------------------------------------+
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
echo  +------------------------------------------------------+
echo  ^|             [Step 4/5]  Output Path                  ^|
echo  +------------------------------------------------------+
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
    if not exist "!BASE_OUTPUT_PATH!" (
        echo   [^^!] Could not create folder. Using default.
        set "BASE_OUTPUT_PATH=!DEFAULT_OUTPUT!"
        timeout /t 2 >nul
    )
)

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
echo  ^|             [Step 5/5]  Download Summary             ^|
echo  +------------------------------------------------------+
echo.
echo   URLs          : !URL_COUNT! URL(s^) queued
echo   Video Quality : !RESOLUTION!
echo   Audio Format  : !AUD_FORMAT!
echo   Output        : !OUTPUT_PATH!
echo   Metadata      : !CFG_METADATA!    Thumbnail: !CFG_THUMBNAIL!
echo   Cookies       : !CFG_COOKIES_LABEL!
echo.
echo   NOTE: Video and audio will be saved as SEPARATE files.

call :PREVIEW_URLS

echo  ------------------------------------------------------
echo   [Y]  Start Download   [N]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [Y/N/B] (default=Y): "
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DS_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                 DOWNLOADING VIDEO...                 ^|
echo  +------------------------------------------------------+
echo.

call :BUILD_DL_OPTS

"%YTDLP%" --ffmpeg-location "%BIN%" %COMMON_OPTS% -f "!VID_FORMAT_STR!" !META_OPT! !CHAP_OPT! !COOKIE_OPT! !SLEEP_OPT! -N !CFG_FRAGMENTS! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s [VIDEO].%%(ext)s"

set "_DS_VID_RC=!ERRORLEVEL!"
if !_DS_VID_RC! NEQ 0 (
    set "_DONE_COUNT=!URL_COUNT!"
    set "_DONE_PATH=!OUTPUT_PATH!"
    set "_DONE_MODE=Video+Audio (separate) - failed during VIDEO step"
    set "_DONE_EXTRA=Audio step was skipped"
    set "_DONE_STATUS=FAIL"
    goto POST_DOWNLOAD
)

echo.
echo  +------------------------------------------------------+
echo  ^|                 DOWNLOADING AUDIO...                 ^|
echo  +------------------------------------------------------+
echo.

"%YTDLP%" --ffmpeg-location "%BIN%" %COMMON_OPTS% -x --audio-format !AUD_FORMAT! !META_OPT! !COOKIE_OPT! !SLEEP_OPT! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\%%(title)s [AUDIO].%%(ext)s"

set "_DS_AUD_RC=!ERRORLEVEL!"
set "_DONE_COUNT=!URL_COUNT!"
set "_DONE_PATH=!OUTPUT_PATH!"
set "_DONE_MODE=Video+Audio (separate) - !RESOLUTION! + !AUD_FORMAT!"
set "_DONE_EXTRA=Two files per URL: [VIDEO] and [AUDIO]"
if !_DS_AUD_RC! NEQ 0 (set "_DONE_STATUS=FAIL") else (set "_DONE_STATUS=OK")
goto POST_DOWNLOAD


:: =====================================================
:SETTINGS
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                      SETTINGS                        ^|
echo  +------------------------------------------------------+
echo.
echo   Output path     : !DEFAULT_OUTPUT!
if "!CFG_SPEED!"=="" (
    echo   Speed limit     : Unlimited
) else (
    echo   Speed limit     : !CFG_SPEED!
)
echo   Concurrent DL   : !CFG_FRAGMENTS! fragment(s^)
echo   Retries         : !CFG_RETRIES!
echo   Skip existing   : !CFG_SKIP_EXISTING!
echo   Playlist        : !CFG_PLAYLIST_LABEL!
echo   Embed metadata  : !CFG_METADATA!
echo   Embed chapters  : !CFG_CHAPTERS!
echo   Embed thumbnail : !CFG_THUMBNAIL!
echo   SponsorBlock    : !CFG_SPONSORBLOCK!
echo   Cookies         : !CFG_COOKIES_LABEL!
echo   Info preview    : !CFG_PREVIEW!
echo   Download history: !CFG_HISTORY!
if "!CFG_SLEEP!"=="" (
    echo   Sleep interval  : None
) else (
    echo   Sleep interval  : !CFG_SLEEP! sec  (anti-ban)
)
echo.
echo  ------------------------------------------------------
echo   [1]  Change default output path
echo   [2]  Open output folder in Explorer
echo   [3]  Set download speed limit
echo   [4]  Set concurrent fragments  (DASH/HLS)
echo   [5]  Set number of retries
echo   [6]  Toggle skip existing files
echo   [7]  Toggle metadata embedding
echo   [8]  Toggle chapter embedding
echo   [9]  Toggle thumbnail embedding
echo   [10] Toggle SponsorBlock removal
echo   [11] Cookie browser integration
echo   [12] Toggle info preview
echo   [13] Set sleep interval  (anti-ban throttle)
echo   [14] Update yt-dlp  (self-updater)
echo   [15] Show tool versions
echo   [16] Toggle download history log  (writes _history.txt)
echo   [B]  Back to Main Menu
echo.
set "SET_CHOICE="
set /p "SET_CHOICE=  Choose an option: "

:: Check B first to guarantee it always works
if /i "!SET_CHOICE!"=="B" goto MAIN_MENU
if "!SET_CHOICE!"=="1"  goto SET_PATH
if "!SET_CHOICE!"=="2"  goto SET_EXPLORER
if "!SET_CHOICE!"=="3"  goto SET_SPEED
if "!SET_CHOICE!"=="4"  goto SET_FRAGS
if "!SET_CHOICE!"=="5"  goto SET_RETRIES
if "!SET_CHOICE!"=="6"  goto SET_TOGGLE_SKIP
if "!SET_CHOICE!"=="7"  goto SET_TOGGLE_META
if "!SET_CHOICE!"=="8"  goto SET_TOGGLE_CHAP
if "!SET_CHOICE!"=="9"  goto SET_TOGGLE_THUMB
if "!SET_CHOICE!"=="10" goto SET_TOGGLE_SB
if "!SET_CHOICE!"=="11" goto COOKIE_MENU
if "!SET_CHOICE!"=="12" goto SET_TOGGLE_PREVIEW
if "!SET_CHOICE!"=="13" goto SET_SLEEP
if "!SET_CHOICE!"=="14" goto SET_UPDATE
if "!SET_CHOICE!"=="15" goto SET_VERSIONS
if "!SET_CHOICE!"=="16" goto SET_TOGGLE_HISTORY
goto SETTINGS


:SET_PATH
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

:SET_EXPLORER
explorer "!DEFAULT_OUTPUT!"
goto SETTINGS

:SET_SPEED
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

:SET_FRAGS
echo.
echo   Enter number of concurrent fragments [1-16, default=1]:
set "NEW_FRAG="
set /p "NEW_FRAG=  Fragments: "
if not "!NEW_FRAG!"=="" set "CFG_FRAGMENTS=!NEW_FRAG!"
echo   Concurrent fragments set to: !CFG_FRAGMENTS!
timeout /t 2 >nul
goto SETTINGS

:SET_RETRIES
echo.
echo   Enter number of retries [default=10, or type infinite]:
set "NEW_RETRY="
set /p "NEW_RETRY=  Retries: "
if not "!NEW_RETRY!"=="" set "CFG_RETRIES=!NEW_RETRY!"
echo   Retries set to: !CFG_RETRIES!
timeout /t 2 >nul
goto SETTINGS

:SET_TOGGLE_SKIP
if /i "!CFG_SKIP_EXISTING!"=="yes" (set "CFG_SKIP_EXISTING=no") else (set "CFG_SKIP_EXISTING=yes")
echo   Skip existing files: !CFG_SKIP_EXISTING!
timeout /t 1 >nul
goto SETTINGS

:SET_TOGGLE_META
if /i "!CFG_METADATA!"=="yes" (set "CFG_METADATA=no") else (set "CFG_METADATA=yes")
echo   Metadata embedding: !CFG_METADATA!
timeout /t 1 >nul
goto SETTINGS

:SET_TOGGLE_CHAP
if /i "!CFG_CHAPTERS!"=="yes" (set "CFG_CHAPTERS=no") else (set "CFG_CHAPTERS=yes")
echo   Chapter embedding: !CFG_CHAPTERS!
timeout /t 1 >nul
goto SETTINGS

:SET_TOGGLE_THUMB
if /i "!CFG_THUMBNAIL!"=="yes" (set "CFG_THUMBNAIL=no") else (set "CFG_THUMBNAIL=yes")
echo   Thumbnail embedding: !CFG_THUMBNAIL!
timeout /t 1 >nul
goto SETTINGS

:SET_TOGGLE_SB
if /i "!CFG_SPONSORBLOCK!"=="yes" (set "CFG_SPONSORBLOCK=no") else (set "CFG_SPONSORBLOCK=yes")
echo   SponsorBlock: !CFG_SPONSORBLOCK!
timeout /t 1 >nul
goto SETTINGS

:SET_TOGGLE_PREVIEW
if /i "!CFG_PREVIEW!"=="yes" (set "CFG_PREVIEW=no") else (set "CFG_PREVIEW=yes")
echo   Info preview: !CFG_PREVIEW!
timeout /t 1 >nul
goto SETTINGS

:SET_TOGGLE_HISTORY
if /i "!CFG_HISTORY!"=="yes" (set "CFG_HISTORY=no") else (set "CFG_HISTORY=yes")
echo   Download history log: !CFG_HISTORY!
if /i "!CFG_HISTORY!"=="yes" echo   ^(will write _history.txt in each download folder^)
timeout /t 2 >nul
goto SETTINGS

:SET_SLEEP
echo.
echo   Sleep interval throttles requests between downloads to avoid bans.
echo   Recommended: 1-5 seconds. Press Enter alone to disable.
set "NEW_SLEEP="
set /p "NEW_SLEEP=  Sleep seconds: "
set "CFG_SLEEP=!NEW_SLEEP!"
if "!CFG_SLEEP!"=="" (
    echo   Sleep interval disabled.
) else (
    echo   Sleep interval set to: !CFG_SLEEP! sec
)
timeout /t 2 >nul
goto SETTINGS

:SET_UPDATE
cls
echo.
echo  +------------------------------------------------------+
echo  ^|               UPDATING yt-dlp...                     ^|
echo  +------------------------------------------------------+
echo.
"%YTDLP%" -U
echo.
pause
goto SETTINGS

:SET_VERSIONS
call :SHOW_VERSIONS
goto SETTINGS


:: =====================================================
:COOKIE_MENU
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|              COOKIE BROWSER INTEGRATION              ^|
echo  +------------------------------------------------------+
echo.
echo   Current: !CFG_COOKIES_LABEL!
echo.
echo   Use cookies from a browser to access age-restricted,
echo   members-only, or login-required content.
echo.
echo   [1]  None  (no cookies)
echo   [2]  Chrome
echo   [3]  Firefox
echo   [4]  Edge
echo   [5]  Brave
echo   [6]  Opera
echo   [7]  Safari
echo   [8]  Chromium
echo   [9]  Vivaldi
echo   [B]  Back to Settings
echo.
set "CK_CHOICE="
set /p "CK_CHOICE=  Choose browser [1-9, default=1]: "
if /i "!CK_CHOICE!"=="B" goto SETTINGS
if "!CK_CHOICE!"=="" set "CK_CHOICE=1"
if "!CK_CHOICE!"=="1" (set "CFG_COOKIES=none"     & set "CFG_COOKIES_LABEL=No cookies")
if "!CK_CHOICE!"=="2" (set "CFG_COOKIES=chrome"   & set "CFG_COOKIES_LABEL=Chrome")
if "!CK_CHOICE!"=="3" (set "CFG_COOKIES=firefox"  & set "CFG_COOKIES_LABEL=Firefox")
if "!CK_CHOICE!"=="4" (set "CFG_COOKIES=edge"     & set "CFG_COOKIES_LABEL=Edge")
if "!CK_CHOICE!"=="5" (set "CFG_COOKIES=brave"    & set "CFG_COOKIES_LABEL=Brave")
if "!CK_CHOICE!"=="6" (set "CFG_COOKIES=opera"    & set "CFG_COOKIES_LABEL=Opera")
if "!CK_CHOICE!"=="7" (set "CFG_COOKIES=safari"   & set "CFG_COOKIES_LABEL=Safari")
if "!CK_CHOICE!"=="8" (set "CFG_COOKIES=chromium" & set "CFG_COOKIES_LABEL=Chromium")
if "!CK_CHOICE!"=="9" (set "CFG_COOKIES=vivaldi"  & set "CFG_COOKIES_LABEL=Vivaldi")
echo.
echo   Cookies source: !CFG_COOKIES_LABEL!
timeout /t 2 >nul
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
