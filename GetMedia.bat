@echo off
setlocal EnableDelayedExpansion
title GetMedia v1.5

:: =====================================================
::  GetMedia v1.5  |  Powered by yt-dlp + ffmpeg
:: =====================================================

set "SCRIPT_DIR=%~dp0"
set "BIN=%SCRIPT_DIR%bin"
:: yt-dlp / ffmpeg are resolved at startup by :CHECK_TOOLS. It prefers
:: copies found on PATH (winget / pip / npm, etc.) and only falls back
:: to the local %BIN% folder if a package-manager copy isn't available.
set "YTDLP="
set "FFMPEG="
set "FFMPEG_DIR="
set "DEFAULT_OUTPUT=%SCRIPT_DIR%Output"
set "LOG_DIR=%SCRIPT_DIR%Logs"
set "LOG_TMP=%TEMP%\getmedia_run.log"
set "URL_TEMP=%TEMP%\getmedia_urls.txt"
set "FAILED_TEMP=%TEMP%\getmedia_failed.txt"
set "COMPLETED_TEMP=%TEMP%\getmedia_completed.txt"
set "ATTEMPTED_TEMP=%TEMP%\getmedia_attempted.txt"

:: ----- Default settings (changeable in Settings menu) -----
set "CFG_SPEED="
set "CFG_FRAGMENTS=3"
set "CFG_RETRIES=10"
set "CFG_SKIP_EXISTING=no"
set "CFG_METADATA=yes"
set "CFG_THUMBNAIL=yes"
set "CFG_SPONSORBLOCK=no"
set "CFG_COOKIES=none"
set "CFG_COOKIES_LABEL=No cookies"
set "CFG_PREVIEW=yes"
set "CFG_SLEEP="
set "CFG_CHAPTERS=yes"
set "CFG_HISTORY=no"
set "CFG_ARCHIVE=no"
set "CFG_ALWAYS_SUBFOLDER=ask"
set "CFG_COOKIES_FILE="
set "_PRESERVE_URLS=0"

:: Common yt-dlp flags applied to every download
set "COMMON_OPTS=--windows-filenames --console-title --mtime --no-warnings --fragment-retries infinite --file-access-retries 5 --throttled-rate 100K --retry-sleep linear=1::5 --retry-sleep fragment:exp=1:20"

:: ============== Tool Validation (ffmpeg + yt-dlp) ==============
call :CHECK_TOOLS
if errorlevel 1 exit /b 1

if not exist "%DEFAULT_OUTPUT%" mkdir "%DEFAULT_OUTPUT%"

goto MAIN_MENU


:: =====================================================
:: HELPER: CHECK_TOOLS
::   Resolves yt-dlp and ffmpeg. Priority order:
::     1) whatever is found on PATH (winget / pip / npm / manual PATH)
::     2) the local %BIN% folder (manual fallback only)
::   If a package-manager copy is found we use it and DO NOT create a
::   bin folder. If neither tool can be located (or one fails to run),
::   :TOOLS_MISSING_PROMPT offers a winget auto-install or a manual
::   bin-folder setup, then we re-detect.
:: =====================================================
:CHECK_TOOLS
:: Pull the live PATH from the registry first, in case this window was
:: opened before a package manager added the tools.
call :REFRESH_PATH
:_CT_DETECT
set "YTDLP="
set "FFMPEG="
set "FFMPEG_DIR="

:: 1) Prefer tools already available on PATH (package-manager installs)
for /f "delims=" %%I in ('where yt-dlp 2^>nul') do if not defined YTDLP set "YTDLP=%%I"
for /f "delims=" %%I in ('where ffmpeg 2^>nul') do if not defined FFMPEG set "FFMPEG=%%I"

:: 2) Check winget's shim folder directly (covers the case where PATH
::    still hasn't caught up after a fresh winget install)
if not defined YTDLP  if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\yt-dlp.exe"  set "YTDLP=%LOCALAPPDATA%\Microsoft\WinGet\Links\yt-dlp.exe"
if not defined FFMPEG if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe" set "FFMPEG=%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe"

:: 3) Fall back to the local bin folder for whichever wasn't found
if not defined YTDLP  if exist "%BIN%\yt-dlp.exe"  set "YTDLP=%BIN%\yt-dlp.exe"
if not defined FFMPEG if exist "%BIN%\ffmpeg.exe" set "FFMPEG=%BIN%\ffmpeg.exe"

set "_TOOLS_OK=yes"
if not defined YTDLP  set "_TOOLS_OK=no"
if not defined FFMPEG set "_TOOLS_OK=no"

:: 3) Validate that the located tools actually run (catch corrupt copies)
if /i "!_TOOLS_OK!"=="yes" (
    "!FFMPEG!" -version >nul 2>&1
    if errorlevel 1 set "_TOOLS_OK=no"
)
if /i "!_TOOLS_OK!"=="yes" (
    "!YTDLP!" --version >nul 2>&1
    if errorlevel 1 set "_TOOLS_OK=no"
)

if /i "!_TOOLS_OK!"=="yes" (
    :: Record the folder ffmpeg lives in so yt-dlp can be pointed at it
    for %%F in ("!FFMPEG!") do set "FFMPEG_DIR=%%~dpF"
    if "!FFMPEG_DIR:~-1!"=="\" set "FFMPEG_DIR=!FFMPEG_DIR:~0,-1!"
    exit /b 0
)

:: Tools missing or broken - show the installer / help menu, then retry
call :TOOLS_MISSING_PROMPT
if errorlevel 1 exit /b 1
goto _CT_DETECT


:: =====================================================
:: HELPER: TOOLS_MISSING_PROMPT
::   Returns errorlevel 0 to re-run detection (after a winget install),
::   or errorlevel 1 to abort the whole script.
:: =====================================================
:TOOLS_MISSING_PROMPT
cls
echo.
echo  +------------------------------------------------------+
echo  ^|            REQUIRED TOOLS NOT AVAILABLE              ^|
echo  +------------------------------------------------------+
echo.
echo   GetMedia needs BOTH yt-dlp and ffmpeg to run, and at least
echo   one of them is missing or could not be started (corrupted).
echo.
if defined YTDLP  (echo   yt-dlp : detected -^> !YTDLP!) else (echo   yt-dlp : NOT found)
if defined FFMPEG (echo   ffmpeg : detected -^> !FFMPEG!) else (echo   ffmpeg : NOT found)
echo.
echo   These tools are normally installed with a package manager.
echo   This script can install the missing one(s^) for you via winget:
echo       winget install yt-dlp
echo       winget install ffmpeg
echo.
echo  ------------------------------------------------------
echo   [1]  Install the missing tool(s^) automatically (winget)
echo   [2]  I will add them manually to a bin folder
echo   [B]  Exit GetMedia
echo  ------------------------------------------------------
set "_TM_CHOICE="
set /p "_TM_CHOICE=  Choose [1/2/B]: "
if /i "!_TM_CHOICE!"=="B" exit /b 1
if "!_TM_CHOICE!"=="1" goto _TM_WINGET
if "!_TM_CHOICE!"=="2" goto _TM_MANUAL
echo   [^^!] Invalid option. Try again.
timeout /t 1 >nul
goto TOOLS_MISSING_PROMPT

:_TM_WINGET
where winget >nul 2>&1
if errorlevel 1 (
    echo.
    echo   [^^!] winget is not available on this system.
    echo       Install "App Installer" from the Microsoft Store and
    echo       retry, or use option 2 to set up a bin folder instead.
    echo.
    pause
    goto TOOLS_MISSING_PROMPT
)
cls
echo.
echo  +------------------------------------------------------+
echo  ^|               INSTALLING VIA WINGET...               ^|
echo  +------------------------------------------------------+
echo.
if not defined YTDLP (
    echo   ^>^> winget install yt-dlp
    winget install --id yt-dlp.yt-dlp -e --accept-source-agreements --accept-package-agreements
    echo.
)
if not defined FFMPEG (
    echo   ^>^> winget install ffmpeg
    winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
    echo.
)
echo  ------------------------------------------------------
echo   Install attempt finished. Refreshing PATH...
:: winget adds tools to the PATH in the registry, but THIS already-open
:: window still holds the old PATH. Pull the fresh PATH from the registry
:: so the re-check below can see the newly installed tools immediately.
call :REFRESH_PATH
echo.
echo   Re-opening GetMedia so the newly-installed tools are visible.
echo   You have a 3 second countdown to read this message.
echo.
for /L %%I in (3,-1,1) do (
    echo    %%I...
    timeout /t 1 >nul
)
echo.
call :REFRESH_PATH
start "GetMedia" cmd.exe /c ""%~f0" %*"
exit

:_TM_MANUAL
if not exist "%BIN%" mkdir "%BIN%"
cls
echo.
echo  +------------------------------------------------------+
echo  ^|          MANUAL SETUP - bin FOLDER CREATED          ^|
echo  +------------------------------------------------------+
echo.
echo   A bin folder is ready at:
echo       %BIN%
echo.
echo   Download these two files and drop them inside it:
echo.
echo     yt-dlp.exe
echo       https://github.com/yt-dlp/yt-dlp/releases/latest
echo.
echo     ffmpeg.exe
echo       https://www.gyan.dev/ffmpeg/builds/
echo       (grab "ffmpeg-release-essentials", then copy ffmpeg.exe
echo        out of its bin\ folder)
echo.
echo   When BOTH files are in place, start GetMedia again.
echo  ------------------------------------------------------
echo.
pause
echo.
echo   If you want GetMedia to re-open now (to re-check for the
echo   newly-placed binaries), the script will restart in 3 seconds.
for /L %%I in (3,-1,1) do (
    echo    %%I...
    timeout /t 1 >nul
)
echo.
start "GetMedia" cmd.exe /c ""%~f0" %*"
exit


:: =====================================================
:: HELPER: BYTES_TO_MB
::   Converts a raw byte count to megabytes (decimal, /1,000,000)
::   with one decimal place using string math, so multi-gigabyte
::   sizes never overflow cmd's 32-bit set /a arithmetic.
::   Args: %1 = byte count, %2 = output variable name.
::   The output var is set to "?" when the input isn't numeric.
:: =====================================================
:: =====================================================
:: HELPER: REFRESH_PATH
::   Reload the PATH environment from the registry (Machine + User)
::   so newly-installed tools become visible to this process and
::   any child cmd.exe started after this call.
:: =====================================================
:REFRESH_PATH
setlocal EnableDelayedExpansion
set "_newPath="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "_newPath=%%P"
if defined _newPath (
    endlocal & set "PATH=%_newPath%"
) else (
    endlocal
)
exit /b 0

:: =====================================================
:BYTES_TO_MB
setlocal EnableDelayedExpansion
set "_b=%~1"
set "_bad="
if "!_b!"=="" set "_bad=1"
for /f "delims=0123456789" %%c in ("!_b!") do set "_bad=1"
if defined _bad (
    endlocal & set "%~2=?"
    exit /b 0
)
:: Strip leading zeros (keep at least one digit)
for /f "tokens=* delims=0" %%n in ("!_b!") do set "_b=%%n"
if "!_b!"=="" set "_b=0"
:: Measure digit length
set "_t=!_b!"
set "_len=0"
:_b2m_count
if not "!_t!"=="" (
    set "_t=!_t:~1!"
    set /a _len+=1
    goto _b2m_count
)
if !_len! GTR 6 (
    set "_int=!_b:~0,-6!"
    set "_dec=!_b:~-6,1!"
) else (
    set "_int=0"
    set "_pad=000000!_b!"
    set "_dec=!_pad:~-6,1!"
)
if "!_int!"=="" set "_int=0"
if "!_dec!"=="" set "_dec=0"
set "_out=!_int!.!_dec!"
endlocal & set "%~2=%_out%"
exit /b 0


:: =====================================================
:: HELPER: LOG_INIT
::   Starts a fresh per-run log capture in %LOG_TMP%. yt-dlp's
::   warnings/errors are appended to this file during the download
::   (via 2^>^>), and the user is offered to save it afterwards.
:: =====================================================
:LOG_INIT
>"%LOG_TMP%"  echo ====== GetMedia Download Log ======
>>"%LOG_TMP%" echo Started : %DATE% %TIME%
>>"%LOG_TMP%" echo Mode    : !_DL_MODE!
>>"%LOG_TMP%" echo Target  : !_DONE_RETRY_TARGET!
>>"%LOG_TMP%" echo Output  : !OUTPUT_PATH!
>>"%LOG_TMP%" echo Cookies : !CFG_COOKIES_LABEL!
if defined RESOLUTION    >>"%LOG_TMP%" echo Quality : !RESOLUTION!
if defined FORMAT_STR     >>"%LOG_TMP%" echo Format  : -f !FORMAT_STR!
if defined VID_FORMAT_STR >>"%LOG_TMP%" echo Format  : -f !VID_FORMAT_STR! (video stream)
if defined AUD_FORMAT     >>"%LOG_TMP%" echo Audio   : !AUD_FORMAT!
>>"%LOG_TMP%" echo.
>>"%LOG_TMP%" echo ------ URLs queued ------
type "%URL_TEMP%" >>"%LOG_TMP%" 2>nul
>>"%LOG_TMP%" echo.
>>"%LOG_TMP%" echo ------ yt-dlp output (stdout + stderr) ------
exit /b 0


:: =====================================================
:: HELPER: LOG_FINALIZE
::   Appends the run result (status + attempted/completed/failed)
::   to the log capture. Called from POST_DOWNLOAD.
:: =====================================================
:LOG_FINALIZE
if not defined LOG_TMP exit /b 0
if not exist "%LOG_TMP%" exit /b 0
>>"%LOG_TMP%" echo.
>>"%LOG_TMP%" echo ------ Result ------
>>"%LOG_TMP%" echo Status    : !_DONE_STATUS!
>>"%LOG_TMP%" echo Attempted : !_attempted_count!   Completed: !_completed_count!
if exist "%FAILED_TEMP%" (
    >>"%LOG_TMP%" echo ------ Failed items ------
    type "%FAILED_TEMP%" >>"%LOG_TMP%" 2>nul
)
>>"%LOG_TMP%" echo ------ Finished : %DATE% %TIME% ------
    :: Auto-save the full run log to the Logs folder with a timestamp
    if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
    set "_logts="
    for /f "usebackq tokens=* delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set "_logts=%%T"
    if "!_logts!"=="" set "_logts=log"
    set "_LAST_LOGPATH=%LOG_DIR%\getmedia_!_logts!.log"
    copy /y "%LOG_TMP%" "!_LAST_LOGPATH!" >nul 2>&1
    echo   Log auto-saved to: !_LAST_LOGPATH!
    exit /b 0


:: =====================================================
:: HELPER: LOG_PROMPT
::   Asks the user whether to keep the download log (default = no).
::   When kept, it is copied into the Logs folder with a timestamp.
:: =====================================================
:LOG_PROMPT
if not defined LOG_TMP exit /b 0
if not exist "%LOG_TMP%" exit /b 0
echo.
if defined _LAST_LOGPATH (
    echo   Full run log saved to: !_LAST_LOGPATH!
    set "_openlog="
    set /p "_openlog=  Open the log file now? (y/n) [n]: "
    if "!_openlog!"=="" set "_openlog=n"
    if /i "!_openlog!"=="y" start "" "!_LAST_LOGPATH!"
    echo.
    exit /b 0
)

set "_savelog="
set /p "_savelog=  Save the download log for troubleshooting? (y/n) [n]: "
if "!_savelog!"=="" set "_savelog=n"
if /i not "!_savelog!"=="y" exit /b 0
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "_logts="
for /f "usebackq tokens=* delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set "_logts=%%T"
if "!_logts!"=="" set "_logts=log"
copy /y "%LOG_TMP%" "%LOG_DIR%\getmedia_!_logts!.log" >nul
echo   Log saved to: %LOG_DIR%\getmedia_!_logts!.log
echo.
pause
exit /b 0


:: =====================================================
:: HELPER: DERIVE_STATUS
::   The live download is piped through a tee (output shown on screen
::   AND written to the log), so cmd's ERRORLEVEL reflects the tee, not
::   yt-dlp. We instead derive success from yt-dlp's own tracking files:
::     ATTEMPTED (before_dl hook)  vs  COMPLETED (after_move hook).
::   Sets _DL_RC = 0 (OK) when at least one item completed and nothing
::   is left unfinished, otherwise 1 (fail/partial -> triggers the
::   failed-items / retry flow in POST_DOWNLOAD).
:: =====================================================
:DERIVE_STATUS
set "_dac=0"
set "_dcc=0"
if exist "%ATTEMPTED_TEMP%" for /f "usebackq tokens=*" %%a in ("%ATTEMPTED_TEMP%") do set /a _dac+=1
if exist "%COMPLETED_TEMP%" for /f "usebackq tokens=*" %%a in ("%COMPLETED_TEMP%") do set /a _dcc+=1
set "_DL_RC=1"
if !_dcc! GTR 0 if !_dac! LEQ !_dcc! set "_DL_RC=0"
exit /b 0


:: =====================================================
:: HELPER: VALIDATE_URL
:: =====================================================
:VALIDATE_URL
set "_url_valid=no"
if "!_url!"=="" exit /b 0
if /i "!_url:~0,7!"=="http://"  set "_url_valid=yes"
if /i "!_url:~0,8!"=="https://" set "_url_valid=yes"
exit /b 0


:: =====================================================
:: HELPER: DELETE_URL_PROMPT
:: =====================================================
:DELETE_URL_PROMPT
:_DUP_ASK
set "_del_num="
set /p "_del_num=  Enter number to delete (or B to cancel): "
if /i "!_del_num!"=="B" exit /b 0
if "!_del_num!"=="" (
    echo   [^^!] Invalid input. Enter a number or B to cancel.
    goto _DUP_ASK
)
set "_nondigit="
for /f "delims=0123456789" %%c in ("!_del_num!") do set "_nondigit=%%c"
if defined _nondigit (
    echo   [^^!] Invalid input. Enter a number or B to cancel.
    goto _DUP_ASK
)
call :DELETE_URL !_del_num!
exit /b 0


:: =====================================================
:: HELPER: CHECK_DUPE_URL
:: =====================================================
:CHECK_DUPE_URL
set "_url_dupe=no"
if not exist "%URL_TEMP%" exit /b 0
findstr /x /i /c:"!_url!" "%URL_TEMP%" >nul 2>&1
if not errorlevel 1 set "_url_dupe=yes"
exit /b 0


:: =====================================================
:: HELPER: APPLY_CHANNEL_TAB
::   In channel mode, rewrites every URL in URL_TEMP to
::   append the tab suffix (e.g. /videos, /shorts).
::   Skips URLs that already end with a known tab suffix
::   so the user can paste a tab URL directly and it
::   won't double up. Also skips URLs that look like
::   individual video links (presence of /watch or
::   /shorts/<id>) so retry flows don't break.
::   No-op if _CH_TAB is empty (Everything) or mode != channel.
:: =====================================================
:APPLY_CHANNEL_TAB
if /i not "!_DL_MODE!"=="channel" exit /b 0
if "!_CH_TAB!"=="" exit /b 0
if not exist "%URL_TEMP%" exit /b 0
set "_CH_TMP=%TEMP%\getmedia_ch_rewrite.txt"
if exist "!_CH_TMP!" del "!_CH_TMP!"
for /f "usebackq tokens=* delims=" %%U in ("%URL_TEMP%") do (
    set "_u=%%U"
    :: Strip trailing slash so the suffix doesn't double up
    if "!_u:~-1!"=="/" set "_u=!_u:~0,-1!"
    :: Skip individual video URLs (would be mangled by appending /videos)
    set "_is_video=no"
    if /i not "!_u:/watch?v=!"=="!_u!"  set "_is_video=yes"
    if /i not "!_u:/watch/=!"=="!_u!"   set "_is_video=yes"
    if /i not "!_u:youtu.be/=!"=="!_u!" set "_is_video=yes"
    :: Detect existing tab suffix on the URL and leave it alone if present
    set "_has_tab=no"
    if /i not "!_u:/videos=!"=="!_u!"   set "_has_tab=yes"
    if /i not "!_u:/shorts=!"=="!_u!"   set "_has_tab=yes"
    if /i not "!_u:/streams=!"=="!_u!"  set "_has_tab=yes"
    if /i not "!_u:/releases=!"=="!_u!" set "_has_tab=yes"
    if /i not "!_u:/playlists=!"=="!_u!" set "_has_tab=yes"
    if /i not "!_u:/community=!"=="!_u!" set "_has_tab=yes"
    if /i "!_is_video!"=="yes" (
        echo !_u!>> "!_CH_TMP!"
    ) else if /i "!_has_tab!"=="yes" (
        echo !_u!>> "!_CH_TMP!"
    ) else (
        echo !_u!!_CH_TAB!>> "!_CH_TMP!"
    )
)
copy /y "!_CH_TMP!" "%URL_TEMP%" >nul
del "!_CH_TMP!"
exit /b 0


:: =====================================================
:: HELPER: LIST_URLS
:: =====================================================
:LIST_URLS
if not exist "%URL_TEMP%" (
    echo.
    echo   [ Queue is empty ]
    exit /b 0
)
echo.
echo   +--------------------------------------------------+
echo   ^|  URL Queue                                       ^|
echo   +--------------------------------------------------+
set "_line=0"
for /f "usebackq tokens=* delims=" %%U in ("%URL_TEMP%") do (
    set /a _line+=1
    echo    !_line!. %%U
)
echo   +--------------------------------------------------+
echo    Total: !_line! URL(s^)
echo   +--------------------------------------------------+
echo.
exit /b 0


:: =====================================================
:: HELPER: DELETE_URL
:: =====================================================
:DELETE_URL
set "_del_num=%~1"
if not exist "%URL_TEMP%" goto :eof
set "_total=0"
for /f "usebackq tokens=*" %%a in ("%URL_TEMP%") do set /a _total+=1
if !_del_num! lss 1 goto :eof
if !_del_num! gtr !_total! (
    echo   [^^!] Number out of range (1-!_total!^)
    exit /b 1
)
set "_newfile=%TEMP%\getmedia_urls_new.txt"
set "_cur=0"
(for /f "usebackq tokens=* delims=" %%U in ("%URL_TEMP%") do (
    set /a _cur+=1
    if not !_cur! == !_del_num! echo(%%U
)) > "!_newfile!"
if exist "!_newfile!" (
    move /y "!_newfile!" "%URL_TEMP%" >nul
    set /a URL_COUNT-=1
    echo   URL #!_del_num! deleted. !URL_COUNT! URL(s^) remain...
    echo.
) else (
    echo   [^^!] Failed to delete.
)
exit /b 0


:: =====================================================
:: HELPER: CLEAR_URLS
:: =====================================================
:CLEAR_URLS
echo.
:_CLEAR_ASK
set "_confirm="
set /p "_confirm=  Clear ALL URLs from queue? (y/n) [n]: "
if "!_confirm!"=="" set "_confirm=N"
if /i "!_confirm!"=="Y" goto _CLEAR_DO
if /i "!_confirm!"=="N" (
    echo   Canceled...
    echo.
    exit /b 0
)
echo   [^^!] Invalid input. Please enter Y or N.
goto _CLEAR_ASK
:_CLEAR_DO
if exist "%URL_TEMP%" del "%URL_TEMP%"
set "URL_COUNT=0"
echo   All URLs cleared...
echo.
exit /b 0


:: =====================================================
:: HELPER: SHOW_VERSIONS
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
:: HELPER: PREVIEW_URLS
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
set "_PV_FS=%TEMP%\getmedia_fsize.txt"
for /f "usebackq tokens=* delims=" %%U in ("%URL_TEMP%") do (
    set /a _pv_idx+=1
    echo   !_pv_idx!.
    "%YTDLP%" --no-warnings --skip-download --ignore-no-formats-error !_cookie_opt! --print "  Title    : %%(title)s" --print "  Uploader : %%(uploader)s" --print "  Duration : %%(duration_string)s" -I 1:1 "%%U" 2>nul
    if errorlevel 1 echo     [^^!] Could not fetch info for this URL.
    :: Filesize is captured separately so we can convert bytes -> MB
    "%YTDLP%" --no-warnings --skip-download --ignore-no-formats-error !_cookie_opt! --print "%%(filesize_approx)s" -I 1:1 "%%U" > "!_PV_FS!" 2>nul
    set "_fsize="
    for /f "usebackq tokens=* delims=" %%S in ("!_PV_FS!") do set "_fsize=%%S"
    call :BYTES_TO_MB "!_fsize!" _fmb
    if "!_fmb!"=="?" (echo     Filesize : ^(unknown^)) else (echo     Filesize : !_fmb! MB ^(approx^))
    echo.
)
if exist "%TEMP%\getmedia_fsize.txt" del "%TEMP%\getmedia_fsize.txt"
exit /b 0


:: =====================================================
:: HELPER: BUILD_DL_OPTS
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
if not "!CFG_COOKIES_FILE!"=="" (
    if exist "!CFG_COOKIES_FILE!" set COOKIE_OPT=--cookies "!CFG_COOKIES_FILE!"
) else (
    if not "!CFG_COOKIES!"=="none" set "COOKIE_OPT=--cookies-from-browser !CFG_COOKIES!"
)
set "SLEEP_OPT="
if not "!CFG_SLEEP!"=="" set "SLEEP_OPT=--sleep-interval !CFG_SLEEP! --max-sleep-interval !CFG_SLEEP!"
set "HISTORY_OPT="
if /i "!CFG_HISTORY!"=="yes" set HISTORY_OPT=--print-to-file "after_move:%%(upload_date)s - %%(title)s - %%(webpage_url)s" "!OUTPUT_PATH!\_history.txt"
set "ARCHIVE_OPT="
if /i "!CFG_ARCHIVE!"=="yes" set ARCHIVE_OPT=--download-archive "!OUTPUT_PATH!\_archive.txt" --break-on-existing
:: In channel mode, force archive ON regardless of CFG_ARCHIVE.
:: Channel grabs are the canonical incremental use case: re-running
:: should pick up new uploads only. --break-on-existing is correct
:: here because channel feeds list newest-first - hitting the first
:: already-downloaded item means everything older is also archived.
if /i "!_DL_MODE!"=="channel" set ARCHIVE_OPT=--download-archive "!OUTPUT_PATH!\_archive.txt" --break-on-existing
:: TRACK_OPT records each individual video yt-dlp processes:
::   before_dl  - fires for every item it attempts (expanded from playlists too)
::   after_move - fires only when the item completed cleanly
:: COMPLETED_TEMP minus ATTEMPTED_TEMP would be wrong (the other direction).
:: We compute failures as ATTEMPTED minus COMPLETED in playlist mode, or
:: URL_TEMP minus COMPLETED in single mode (handled in COLLECT_FAILED_URLS).
set TRACK_OPT=--print-to-file "before_dl:%%(webpage_url)s" "%ATTEMPTED_TEMP%" --print-to-file "after_move:%%(webpage_url)s" "%COMPLETED_TEMP%"
:: OUT_PREFIX prefixes the output template with %(uploader)s\ in channel mode.
:: This is what auto-creates per-channel subfolders without us having to
:: probe channel metadata in advance. yt-dlp creates the directory as
:: part of expanding the template; --windows-filenames sanitizes the
:: uploader name so weird characters don't break the path.
set "OUT_PREFIX="
if /i "!_DL_MODE!"=="channel" set "OUT_PREFIX=%%(uploader)s\"
exit /b 0
exit /b 0


:: =====================================================
:: HELPER: COLLECT_FAILED_URLS
::   Computes failed = SOURCE minus COMPLETED, where SOURCE is:
::     - URL_TEMP        in single mode (user-typed URLs)
::     - ATTEMPTED_TEMP  in playlist mode (yt-dlp-expanded items)
::   Using URL_TEMP for playlists is wrong because the queue
::   holds 1 playlist URL while COMPLETED holds N video URLs -
::   no match, false-positive "failure" with no items listed.
::   Uses yt-dlp's own success signal (after_move hook), not
::   log scraping. Strips ?query and #fragment before comparing
::   because yt-dlp normalizes webpage_url differently from the
::   URLs we pass in.
:: =====================================================
:COLLECT_FAILED_URLS
if exist "%FAILED_TEMP%" del "%FAILED_TEMP%"

set "_source_file=%URL_TEMP%"
if /i "!_DL_MODE!"=="playlist" set "_source_file=%ATTEMPTED_TEMP%"
if /i "!_DL_MODE!"=="channel"  set "_source_file=%ATTEMPTED_TEMP%"
if not exist "!_source_file!" exit /b 0

set "_completed_exists=no"
if exist "%COMPLETED_TEMP%" set "_completed_exists=yes"

for /f "usebackq tokens=* delims=" %%U in ("!_source_file!") do (
    set "_q_url=%%U"
    call :_STRIP_QUERY _q_url _q_stripped
    set "_was_completed=no"
    if /i "!_completed_exists!"=="yes" (
        for /f "usebackq tokens=* delims=" %%C in ("%COMPLETED_TEMP%") do (
            set "_c_url=%%C"
            call :_STRIP_QUERY _c_url _c_stripped
            if /i "!_q_stripped!"=="!_c_stripped!" set "_was_completed=yes"
        )
    )
    if /i "!_was_completed!"=="no" (
        :: Skip if already in FAILED_TEMP (playlist may list same URL twice)
        set "_already_failed=no"
        if exist "%FAILED_TEMP%" (
            findstr /x /i /c:"%%U" "%FAILED_TEMP%" >nul 2>&1
            if not errorlevel 1 set "_already_failed=yes"
        )
        if /i "!_already_failed!"=="no" echo %%U>> "%FAILED_TEMP%"
    )
)
exit /b 0


:: Internal: strip ?... and #... from a URL for comparison.
:: Args: %1 = input var name, %2 = output var name.
:_STRIP_QUERY
set "_sq=!%~1!"
for /f "tokens=1 delims=?#" %%X in ("!_sq!") do set "_sq=%%X"
set "%~2=!_sq!"
exit /b 0


:: =====================================================
:: HELPER: SHOW_FAILED_INFO
::   Displays info for each URL in FAILED_TEMP.
::   For each failed URL, probes yt-dlp for basic info
::   (title/uploader/duration) so the user can identify
::   which video failed. If even the info probe fails,
::   we report likely reasons.
:: =====================================================
:SHOW_FAILED_INFO
if not exist "%FAILED_TEMP%" exit /b 0
set "_fc=0"
for /f "usebackq tokens=*" %%a in ("%FAILED_TEMP%") do set /a _fc+=1
if !_fc!==0 exit /b 0

echo.
echo  +------------------------------------------------------+
echo  ^|              FAILED / UNAVAILABLE MEDIA              ^|
echo  +------------------------------------------------------+
echo.
echo   !_fc! item(s^) failed to download:
echo.

set "_cookie_opt_f="
if not "!CFG_COOKIES_FILE!"=="" (
    if exist "!CFG_COOKIES_FILE!" set "_cookie_opt_f=--cookies !CFG_COOKIES_FILE!"
) else (
    if not "!CFG_COOKIES!"=="none" set "_cookie_opt_f=--cookies-from-browser !CFG_COOKIES!"
)

set "_fi=0"
for /f "usebackq tokens=* delims=" %%U in ("%FAILED_TEMP%") do (
    set /a _fi+=1
    echo   [!_fi!] %%U
    "%YTDLP%" --no-warnings --skip-download --ignore-no-formats-error !_cookie_opt_f! --print "       Title    : %%(title)s" --print "       Uploader : %%(uploader)s" --print "       Duration : %%(duration_string)s" -I 1:1 "%%U" 2>nul
    if errorlevel 1 (
        echo       ^(Could not retrieve info - item may be private, deleted,^)
        echo       ^(age-restricted, region-locked, or the URL is invalid.^)
    )
    echo.
)
exit /b 0


:: =====================================================
:: HELPER: POST_DOWNLOAD
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
    echo   Status      : [^^!] Failed or interrupted
)
:: Count attempted and completed for an accurate summary
set "_attempted_count=0"
set "_completed_count=0"
if exist "%ATTEMPTED_TEMP%" (
    for /f "usebackq tokens=*" %%a in ("%ATTEMPTED_TEMP%") do set /a _attempted_count+=1
)
if exist "%COMPLETED_TEMP%" (
    for /f "usebackq tokens=*" %%a in ("%COMPLETED_TEMP%") do set /a _completed_count+=1
)
if /i "!_DL_MODE!"=="playlist" (
    echo   URLs queued : !_DONE_COUNT! playlist URL(s^)
    echo   Items found : !_attempted_count!  ^|  Completed: !_completed_count!
) else if /i "!_DL_MODE!"=="channel" (
    echo   URLs queued : !_DONE_COUNT! channel URL(s^)
    echo   Items found : !_attempted_count!  ^|  Completed: !_completed_count!
) else (
    echo   URLs queued : !_DONE_COUNT! URL(s^)
)
echo   Mode        : !_DONE_MODE!
echo   Saved to    : !_DONE_PATH!
if defined _DONE_EXTRA echo   Note        : !_DONE_EXTRA!
echo.

:: Reset the retry-available flag, then re-check failures
set "_RETRY_AVAILABLE=no"

if /i not "!_DONE_STATUS!"=="OK" (
    call :COLLECT_FAILED_URLS
    set "_failed_count=0"
    if exist "%FAILED_TEMP%" (
        for /f "usebackq tokens=*" %%a in ("%FAILED_TEMP%") do set /a _failed_count+=1
    )
    if !_failed_count! GTR 0 (
        echo   Detected !_failed_count! failed item(s^) in this batch.
        set "_RETRY_AVAILABLE=yes"
        call :SHOW_FAILED_INFO
    ) else (
        echo   Common causes: invalid URL, network issue, age-restricted
        echo   content, missing cookies, or outdated yt-dlp
        echo   ^(Settings -^> Update yt-dlp^).
        echo.
    )
)

:: --- Download log: record the result, then offer to save it ---
call :LOG_FINALIZE
call :LOG_PROMPT

echo  ------------------------------------------------------
if /i "!_RETRY_AVAILABLE!"=="yes" (
    echo   [R]  Retry failed item(s^) only
)
echo   [Y]  Return to Main Menu
echo   [N]  Exit GetMedia
echo   [O]  Open output folder
echo  ------------------------------------------------------

:POST_DOWNLOAD_PROMPT
set "POST_CHOICE="
if /i "!_RETRY_AVAILABLE!"=="yes" (
    set /p "POST_CHOICE=  Choose [Y/N/O/R]: "
) else (
    set /p "POST_CHOICE=  Choose [Y/N/O]: "
)

if /i "!POST_CHOICE!"=="Y" goto MAIN_MENU
if /i "!POST_CHOICE!"=="N" goto EXIT
if /i "!POST_CHOICE!"=="O" (
    if exist "!_DONE_PATH!" (
        start "" "!_DONE_PATH!"
    ) else (
        echo   [^^!] Folder not found: !_DONE_PATH!
    )
    goto POST_DOWNLOAD_PROMPT
)
if /i "!POST_CHOICE!"=="R" (
    if /i "!_RETRY_AVAILABLE!"=="yes" (
        goto RETRY_FAILED
    ) else (
        echo   [^^!] No failed items to retry.
        goto POST_DOWNLOAD_PROMPT
    )
)
echo   [^^!] Invalid option. Try again.
goto POST_DOWNLOAD_PROMPT


:: =====================================================
:: RETRY_FAILED
::   Replaces URL_TEMP with only failed URLs and re-runs
::   the same download via the saved _DONE_RETRY_TARGET
::   label (set in each download flow before yt-dlp runs).
:: =====================================================
:RETRY_FAILED
cls
echo.
echo  +------------------------------------------------------+
echo  ^|              RETRYING FAILED ITEM(S)                 ^|
echo  +------------------------------------------------------+
echo.

set "_rf_count=0"
for /f "usebackq tokens=*" %%a in ("%FAILED_TEMP%") do set /a _rf_count+=1
echo   Will retry !_rf_count! failed URL(s^):
echo.
set "_ri=0"
for /f "usebackq tokens=* delims=" %%U in ("%FAILED_TEMP%") do (
    set /a _ri+=1
    echo   !_ri!. %%U
)
echo.
echo  ------------------------------------------------------
echo   [Y]  Confirm retry   [N]  Cancel (back to menu)
echo  ------------------------------------------------------
set "_retry_confirm="
set /p "_retry_confirm=  Choose [Y/N] (default=Y): "
if "!_retry_confirm!"=="" set "_retry_confirm=Y"
if /i not "!_retry_confirm!"=="Y" goto MAIN_MENU

:: Replace queue, reset completed/failed trackers
copy /y "%FAILED_TEMP%" "%URL_TEMP%" >nul
set /a URL_COUNT=!_rf_count!
if exist "%COMPLETED_TEMP%" del "%COMPLETED_TEMP%"
if exist "%ATTEMPTED_TEMP%" del "%ATTEMPTED_TEMP%"
if exist "%FAILED_TEMP%"    del "%FAILED_TEMP%"

:: Dispatch back to the original download invocation
if /i "!_DONE_RETRY_TARGET!"=="DV_DOWNLOAD"  goto DV_DOWNLOAD
if /i "!_DONE_RETRY_TARGET!"=="DA_DOWNLOAD"  goto DA_DOWNLOAD
if /i "!_DONE_RETRY_TARGET!"=="DS_DOWNLOAD"  goto DS_DOWNLOAD

:: Unknown target - shouldn't happen but be safe
echo   [^^!] Internal: unknown retry target. Returning to menu.
timeout /t 3 >nul
goto MAIN_MENU


:: =====================================================
:MAIN_MENU
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   GetMedia  v1.5                     ^|
echo  ^|             Powered by yt-dlp + ffmpeg               ^|
echo  +------------------------------------------------------+
echo.
echo   --- SINGLE VIDEO ---
echo   [1]  Download Video
echo   [2]  Download Audio Only
echo   [3]  Download Video + Audio  (Separate Files)
echo.
echo   --- BATCH ---
echo   [4]  Download Playlist  (Video / Audio / Both)
echo   [5]  Download Channel   (all uploads from a creator)
echo.
echo   [S]  Settings
echo   [X]  Exit
echo  ------------------------------------------------------
set "MAIN_CHOICE="
set /p "MAIN_CHOICE=  Choose an option: "

set "_DL_MODE=single"
set "_CH_TAB="
:: Clear previous selection vars so a later run's log doesn't show stale values
set "FORMAT_STR="
set "VID_FORMAT_STR="
set "RESOLUTION="
set "AUD_FORMAT="
set "AUD_QUALITY="
set "DS_VID_FORMAT="
set "DS_VID_REMUX="
set "SUB_OPTS="
set "SUB_LABEL=None"
if "!MAIN_CHOICE!"=="1" goto DV_URL
if "!MAIN_CHOICE!"=="2" goto DA_URL
if "!MAIN_CHOICE!"=="3" goto DS_URL
if "!MAIN_CHOICE!"=="4" goto PLAYLIST_MENU
if "!MAIN_CHOICE!"=="5" goto CHANNEL_MENU
if /i "!MAIN_CHOICE!"=="S" goto SETTINGS
if /i "!MAIN_CHOICE!"=="X" goto EXIT
if /i "!MAIN_CHOICE!"=="Q" goto EXIT
echo.
echo   [^^!] Invalid option. Try again.
timeout /t 1 >nul
goto MAIN_MENU


:: =====================================================
:PLAYLIST_MENU
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                 PLAYLIST DOWNLOAD                    ^|
echo  +------------------------------------------------------+
echo.
echo   Each playlist URL will expand into ALL its items.
echo   Broken or unavailable items will be skipped automatically.
echo.
echo   What do you want from each item?
echo.
echo   [1]  Video             (merged video+audio file)
echo   [2]  Audio Only        (extract audio track)
echo   [3]  Video + Audio     (separate streams - advanced)
echo   [B]  Back to Main Menu
echo  ------------------------------------------------------
set "PLDL_CHOICE="
set /p "PLDL_CHOICE=  Choose a format: "
if /i "!PLDL_CHOICE!"=="B" goto MAIN_MENU
set "_DL_MODE=playlist"
if "!PLDL_CHOICE!"=="1" goto DV_URL
if "!PLDL_CHOICE!"=="2" goto DA_URL
if "!PLDL_CHOICE!"=="3" goto DS_URL
echo.
echo   [^^!] Invalid option. Try again.
timeout /t 1 >nul
goto PLAYLIST_MENU


:: =====================================================
:CHANNEL_MENU
:: =====================================================
cls
echo.
echo  +------------------------------------------------------+
echo  ^|                  CHANNEL DOWNLOAD                    ^|
echo  +------------------------------------------------------+
echo.
echo   Downloads every item from a channel/user/creator URL.
echo   Examples:
echo     YouTube : https://www.youtube.com/@NoCopyrightSounds
echo     YouTube : https://www.youtube.com/c/SomeChannel
echo.
echo   Each channel gets its own auto-named subfolder
echo   (based on the uploader metadata - no manual typing).
echo.
echo   Archive will be enabled automatically so re-runs only
echo   fetch NEW uploads since last time.
echo.
echo   --- Step 1: What to download from each item? ---
echo   [1]  Video             (merged video+audio file)
echo   [2]  Audio Only        (extract audio track)
echo   [3]  Video + Audio     (separate streams - advanced)
echo   [B]  Back to Main Menu
echo  ------------------------------------------------------
set "CHDL_CHOICE="
set /p "CHDL_CHOICE=  Choose a format: "
if /i "!CHDL_CHOICE!"=="B" goto MAIN_MENU
if not "!CHDL_CHOICE!"=="1" if not "!CHDL_CHOICE!"=="2" if not "!CHDL_CHOICE!"=="3" (
    echo.
    echo   [^^!] Invalid option. Try again.
    timeout /t 1 >nul
    goto CHANNEL_MENU
)

:CHANNEL_TAB_MENU
cls
echo.
echo  +------------------------------------------------------+
echo  ^|             CHANNEL DOWNLOAD - SCOPE                 ^|
echo  +------------------------------------------------------+
echo.
echo   Which tab(s) on the channel to fetch?
echo.
echo   [1]  Videos tab only   (recommended - main uploads)
echo   [2]  Shorts tab only
echo   [3]  Livestreams tab only
echo   [4]  Releases tab only (music releases / albums)
echo   [5]  Everything        (Videos + Shorts + Live + ...)
echo   [B]  Back
echo  ------------------------------------------------------
echo   TIP: Most channels have hundreds of items. Start with
echo        a single tab to avoid pulling thousands of files.
echo  ------------------------------------------------------
set "CHTAB_CHOICE="
set /p "CHTAB_CHOICE=  Choose tab scope [default=1]: "
if /i "!CHTAB_CHOICE!"=="B" goto CHANNEL_MENU
if "!CHTAB_CHOICE!"=="" set "CHTAB_CHOICE=1"
:: _CH_TAB holds the URL suffix yt-dlp will use; empty = no transform
set "_CH_TAB="
set "_CH_TAB_LABEL=Videos tab"
if "!CHTAB_CHOICE!"=="1" (set "_CH_TAB=/videos"   & set "_CH_TAB_LABEL=Videos tab only")
if "!CHTAB_CHOICE!"=="2" (set "_CH_TAB=/shorts"   & set "_CH_TAB_LABEL=Shorts tab only")
if "!CHTAB_CHOICE!"=="3" (set "_CH_TAB=/streams"  & set "_CH_TAB_LABEL=Livestreams tab only")
if "!CHTAB_CHOICE!"=="4" (set "_CH_TAB=/releases" & set "_CH_TAB_LABEL=Releases tab only")
if "!CHTAB_CHOICE!"=="5" (set "_CH_TAB="          & set "_CH_TAB_LABEL=Everything (all tabs)")

set "_DL_MODE=channel"
if "!CHDL_CHOICE!"=="1" goto DV_URL
if "!CHDL_CHOICE!"=="2" goto DA_URL
if "!CHDL_CHOICE!"=="3" goto DS_URL
goto CHANNEL_MENU


:: #####################################################
::  DOWNLOAD VIDEO  (6 steps)
:: #####################################################

:DV_URL
cls
echo.
if /i "!_DL_MODE!"=="channel" (
echo  +------------------------------------------------------+
echo  ^|               VIDEO CHANNEL DOWNLOAD                 ^|
echo  ^|  Step 1/6  ^|  URL Input  ^|  Mode: Channel            ^|
echo  +------------------------------------------------------+
echo.
echo   Tab scope : !_CH_TAB_LABEL!
) else if /i "!_DL_MODE!"=="playlist" (
echo  +------------------------------------------------------+
echo  ^|              VIDEO PLAYLIST DOWNLOAD                 ^|
echo  ^|  Step 1/6  ^|  URL Input  ^|  Mode: Playlist           ^|
echo  +------------------------------------------------------+
) else (
echo  +------------------------------------------------------+
echo  ^|                   VIDEO DOWNLOAD                     ^|
echo  ^|  Step 1/6  ^|  URL Input  ^|  Mode: Single video       ^|
echo  +------------------------------------------------------+
)
echo.
echo   Enter URLs one by one, then press Enter with no input to proceed.
echo   L = List queue    D = Delete a URL    C = Clear all    B = Back
echo  ------------------------------------------------------
echo.

if "!_PRESERVE_URLS!"=="0" (
    if exist "%URL_TEMP%" del "%URL_TEMP%"
    set "URL_COUNT=0"
) else (
    set "URL_COUNT=0"
    if exist "%URL_TEMP%" (
        for /f "usebackq tokens=*" %%a in ("%URL_TEMP%") do set /a URL_COUNT+=1
    )
    echo   [Preserving !URL_COUNT! existing URL(s^)]
    echo.
)
set "_PRESERVE_URLS=0"

:DV_URL_LOOP
set "NEXT_URL="
set /a "_url_n=URL_COUNT + 1"
set /p "NEXT_URL=  URL !_url_n! (or L=List, D=Delete, C=Clear, B=Back) ^> "
if /i "!NEXT_URL!"=="B" goto MAIN_MENU
if /i "!NEXT_URL!"=="L" (
    call :LIST_URLS
    goto DV_URL_LOOP
)
if /i "!NEXT_URL!"=="D" (
    call :LIST_URLS
    if exist "%URL_TEMP%" (
        call :DELETE_URL_PROMPT
    ) else (
        echo   [ Queue is empty - nothing to delete. ]
    )
    goto DV_URL_LOOP
)
if /i "!NEXT_URL!"=="C" (
    call :CLEAR_URLS
    goto DV_URL_LOOP
)
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
call :CHECK_DUPE_URL
if /i "!_url_dupe!"=="yes" (
    echo   [^^!] Duplicate - this URL is already in the queue. Skipped.
    goto DV_URL_LOOP
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DV_URL_LOOP


:DV_RES
cls
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
if /i "!RES_CHOICE!"=="B" (
    set "_PRESERVE_URLS=1"
    goto DV_URL
)
if "!RES_CHOICE!"==""  set "RES_CHOICE=1"
:: Each capped tier ends with "/bv*+ba/b" so that, if a video has no
:: stream at that height, yt-dlp falls back to the best available
:: instead of hard-failing with "Requested format is not available".
if "!RES_CHOICE!"=="1" (set "RESOLUTION=Best Available" & set "FORMAT_STR=bv*+ba/b")
if "!RES_CHOICE!"=="2" (set "RESOLUTION=4K (2160p)"     & set "FORMAT_STR=bv*[height<=2160]+ba/b[height<=2160]/bv*+ba/b")
if "!RES_CHOICE!"=="3" (set "RESOLUTION=1440p"          & set "FORMAT_STR=bv*[height<=1440]+ba/b[height<=1440]/bv*+ba/b")
if "!RES_CHOICE!"=="4" (set "RESOLUTION=1080p"          & set "FORMAT_STR=bv*[height<=1080]+ba/b[height<=1080]/bv*+ba/b")
if "!RES_CHOICE!"=="5" (set "RESOLUTION=720p"           & set "FORMAT_STR=bv*[height<=720]+ba/b[height<=720]/bv*+ba/b")
if "!RES_CHOICE!"=="6" (set "RESOLUTION=480p"           & set "FORMAT_STR=bv*[height<=480]+ba/b[height<=480]/bv*+ba/b")
if "!RES_CHOICE!"=="7" (set "RESOLUTION=360p"           & set "FORMAT_STR=bv*[height<=360]+ba/b[height<=360]/bv*+ba/b")
if "!RESOLUTION!"=="" (
    echo   [^^!] Invalid choice. Defaulting to Best Available.
    set "RESOLUTION=Best Available"
    set "FORMAT_STR=bv*+ba/b"
    timeout /t 1 >nul
    goto DV_RES
)


:DV_FMT
cls
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
if "!VID_FORMAT!"=="" (
    echo   [^^!] Invalid choice. Please try again.
    timeout /t 1 >nul
    goto DV_FMT
)


:DV_SUBS
cls
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
if "!SUB_CHOICE!"=="1" goto DV_OUT
if "!SUB_CHOICE!"=="2" (
    echo.
    echo   Language codes: en  id  ja  es  ko  zh  etc.
    set "SUB_LANG_IN="
    set /p "SUB_LANG_IN=  Subtitle language [default=en]: "
    if "!SUB_LANG_IN!"=="" set "SUB_LANG_IN=en"
    set "SUB_OPTS=--write-auto-subs --sub-langs !SUB_LANG_IN! --convert-subs srt"
    set "SUB_LABEL=Auto-generated [!SUB_LANG_IN!]"
    goto DV_OUT
)
echo   [^^!] Invalid choice. Please try again.
timeout /t 1 >nul
goto DV_SUBS


:DV_OUT
cls
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
if /i "!CFG_ALWAYS_SUBFOLDER!"=="yes" (
    set "CREATE_SUBFOLDER=y"
) else if /i "!CFG_ALWAYS_SUBFOLDER!"=="no" (
    set "CREATE_SUBFOLDER=n"
) else (
    echo.
    set /p "CREATE_SUBFOLDER=  Create subfolder for this download? (y/n) [y]: "
)
if "!CREATE_SUBFOLDER!"=="" set "CREATE_SUBFOLDER=y"
if /i "!CREATE_SUBFOLDER!"=="n" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!"
    goto DV_PATH_DONE
)

:DV_SUBNAME
set "SUBFOLDER_NAME=Video"
echo.
set "SF_NAME_IN="
set /p "SF_NAME_IN=  Subfolder name [default=Video] (B=back): "
if /i "!SF_NAME_IN!"=="B" goto DV_OUT
if not "!SF_NAME_IN!"=="" set "SUBFOLDER_NAME=!SF_NAME_IN!"
if /i "!_DL_MODE!"=="channel" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\Channel\!SUBFOLDER_NAME!"
    if not exist "!BASE_OUTPUT_PATH!\Channel" mkdir "!BASE_OUTPUT_PATH!\Channel"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: Channel\!SUBFOLDER_NAME!\^<channel^>\ ^(auto-named per channel^)
) else if /i "!_DL_MODE!"=="playlist" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\Playlist\!SUBFOLDER_NAME!"
    if not exist "!BASE_OUTPUT_PATH!\Playlist" mkdir "!BASE_OUTPUT_PATH!\Playlist"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: Playlist\!SUBFOLDER_NAME!
) else (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\!SUBFOLDER_NAME!"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: !SUBFOLDER_NAME!
)
:DV_PATH_DONE


:: =====================================================
::  DV_SUMMARY - [Step 6/6]
:: =====================================================
:DV_SUMMARY
if /i "!_DL_MODE!"=="channel" (
    set "PL_OPTS=--ignore-errors"
    set "PL_LABEL=Channel - !_CH_TAB_LABEL!, skip broken"
) else if /i "!_DL_MODE!"=="playlist" (
    set "PL_OPTS=--ignore-errors"
    set "PL_LABEL=Playlist - download all, skip broken"
) else (
    set "PL_OPTS=--no-playlist"
    set "PL_LABEL=Single video only"
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
echo   Archive     : !CFG_ARCHIVE!    History log: !CFG_HISTORY!
if not "!CFG_SPEED!"=="" echo   Speed       : !CFG_SPEED! limit
echo   Fragments   : !CFG_FRAGMENTS! concurrent

call :PREVIEW_URLS

echo  ------------------------------------------------------
echo   [Y]  Start Download   [N]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [y/n/b] (default=y): "
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DV_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   DOWNLOADING...                     ^|
echo  +------------------------------------------------------+
echo.

:: Retry routing target - RETRY_FAILED jumps back here
set "_DONE_RETRY_TARGET=DV_DOWNLOAD"
:DV_DOWNLOAD
call :BUILD_DL_OPTS
call :APPLY_CHANNEL_TAB

if exist "%COMPLETED_TEMP%" del "%COMPLETED_TEMP%"
if exist "%ATTEMPTED_TEMP%" del "%ATTEMPTED_TEMP%"
if exist "%FAILED_TEMP%"    del "%FAILED_TEMP%"

call :LOG_INIT
"%YTDLP%" --ffmpeg-location "!FFMPEG_DIR!" %COMMON_OPTS% --newline -f "!FORMAT_STR!" --merge-output-format !VID_FORMAT! !SUB_OPTS! !PL_OPTS! !META_OPT! !CHAP_OPT! !THUMB_OPT! !SB_OPT! !COOKIE_OPT! !SLEEP_OPT! -N !CFG_FRAGMENTS! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! !ARCHIVE_OPT! !TRACK_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\!OUT_PREFIX!%%(title).200B.%%(ext)s" 2>&1 | powershell -NoProfile -Command "$w=[IO.StreamWriter]::new('%LOG_TMP%',$true);try{while($null -ne ($l=[Console]::In.ReadLine())){[Console]::WriteLine($l);$w.WriteLine($l);$w.Flush()}}finally{$w.Close()}"

call :DERIVE_STATUS
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
if /i "!_DL_MODE!"=="channel" (
echo  +------------------------------------------------------+
echo  ^|               AUDIO CHANNEL DOWNLOAD                 ^|
echo  ^|  Step 1/5  ^|  URL Input  ^|  Mode: Channel            ^|
echo  +------------------------------------------------------+
echo.
echo   Tab scope : !_CH_TAB_LABEL!
) else if /i "!_DL_MODE!"=="playlist" (
echo  +------------------------------------------------------+
echo  ^|              AUDIO PLAYLIST DOWNLOAD                 ^|
echo  ^|  Step 1/5  ^|  URL Input  ^|  Mode: Playlist           ^|
echo  +------------------------------------------------------+
) else (
echo  +------------------------------------------------------+
echo  ^|                 AUDIO ONLY DOWNLOAD                  ^|
echo  ^|  Step 1/5  ^|  URL Input  ^|  Mode: Single track       ^|
echo  +------------------------------------------------------+
)
echo.
echo   Enter URLs one by one, then press Enter with no input to proceed.
echo   L = List queue    D = Delete a URL    C = Clear all    B = Back
echo  ------------------------------------------------------
echo.

if "!_PRESERVE_URLS!"=="0" (
    if exist "%URL_TEMP%" del "%URL_TEMP%"
    set "URL_COUNT=0"
) else (
    set "URL_COUNT=0"
    if exist "%URL_TEMP%" (
        for /f "usebackq tokens=*" %%a in ("%URL_TEMP%") do set /a URL_COUNT+=1
    )
    echo   [Preserving !URL_COUNT! existing URL(s^)]
    echo.
)
set "_PRESERVE_URLS=0"

:DA_URL_LOOP
set "NEXT_URL="
set /a "_url_n=URL_COUNT + 1"
set /p "NEXT_URL=  URL !_url_n! (or L=List, D=Delete, C=Clear, B=Back) ^> "
if /i "!NEXT_URL!"=="B" goto MAIN_MENU
if /i "!NEXT_URL!"=="L" (
    call :LIST_URLS
    goto DA_URL_LOOP
)
if /i "!NEXT_URL!"=="D" (
    call :LIST_URLS
    if exist "%URL_TEMP%" (
        call :DELETE_URL_PROMPT
    ) else (
        echo   [ Queue is empty - nothing to delete. ]
    )
    goto DA_URL_LOOP
)
if /i "!NEXT_URL!"=="C" (
    call :CLEAR_URLS
    goto DA_URL_LOOP
)
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
call :CHECK_DUPE_URL
if /i "!_url_dupe!"=="yes" (
    echo   [^^!] Duplicate - this URL is already in the queue. Skipped.
    goto DA_URL_LOOP
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DA_URL_LOOP


:DA_FMT
cls
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
if /i "!AUD_CHOICE!"=="B" (
    set "_PRESERVE_URLS=1"
    goto DA_URL
)
if "!AUD_CHOICE!"=="" set "AUD_CHOICE=1"
if "!AUD_CHOICE!"=="1" set "AUD_FORMAT=mp3"
if "!AUD_CHOICE!"=="2" set "AUD_FORMAT=aac"
if "!AUD_CHOICE!"=="3" set "AUD_FORMAT=flac"
if "!AUD_CHOICE!"=="4" set "AUD_FORMAT=m4a"
if "!AUD_CHOICE!"=="5" set "AUD_FORMAT=opus"
if "!AUD_CHOICE!"=="6" set "AUD_FORMAT=wav"
if "!AUD_CHOICE!"=="7" set "AUD_FORMAT=alac"
if "!AUD_CHOICE!"=="8" set "AUD_FORMAT=vorbis"
if "!AUD_FORMAT!"=="" (
    echo   [^^!] Invalid choice. Please try again.
    timeout /t 1 >nul
    goto DA_FMT
)


:DA_QUAL
cls
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
if "!AUD_QUALITY!"=="" (
    echo   [^^!] Invalid choice. Please try again.
    timeout /t 1 >nul
    goto DA_QUAL
)


:DA_OUT
cls
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
if /i "!CFG_ALWAYS_SUBFOLDER!"=="yes" (
    set "CREATE_SUBFOLDER=y"
) else if /i "!CFG_ALWAYS_SUBFOLDER!"=="no" (
    set "CREATE_SUBFOLDER=n"
) else (
    echo.
    set /p "CREATE_SUBFOLDER=  Create subfolder for this download? (y/n) [y]: "
)
if "!CREATE_SUBFOLDER!"=="" set "CREATE_SUBFOLDER=y"
if /i "!CREATE_SUBFOLDER!"=="n" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!"
    goto DA_PATH_DONE
)

:DA_SUBNAME
set "SUBFOLDER_NAME=Audio"
echo.
set "SF_NAME_IN="
set /p "SF_NAME_IN=  Subfolder name [default=Audio] (B=back): "
if /i "!SF_NAME_IN!"=="B" goto DA_OUT
if not "!SF_NAME_IN!"=="" set "SUBFOLDER_NAME=!SF_NAME_IN!"
if /i "!_DL_MODE!"=="channel" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\Channel\!SUBFOLDER_NAME!"
    if not exist "!BASE_OUTPUT_PATH!\Channel" mkdir "!BASE_OUTPUT_PATH!\Channel"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: Channel\!SUBFOLDER_NAME!\^<channel^>\ ^(auto-named per channel^)
) else if /i "!_DL_MODE!"=="playlist" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\Playlist\!SUBFOLDER_NAME!"
    if not exist "!BASE_OUTPUT_PATH!\Playlist" mkdir "!BASE_OUTPUT_PATH!\Playlist"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: Playlist\!SUBFOLDER_NAME!
) else (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\!SUBFOLDER_NAME!"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: !SUBFOLDER_NAME!
)
:DA_PATH_DONE


:DA_SUMMARY
if /i "!_DL_MODE!"=="channel" (
    set "PL_OPTS=--ignore-errors"
    set "PL_LABEL=Channel - !_CH_TAB_LABEL!, skip broken"
) else if /i "!_DL_MODE!"=="playlist" (
    set "PL_OPTS=--ignore-errors"
    set "PL_LABEL=Playlist - download all, skip broken"
) else (
    set "PL_OPTS=--no-playlist"
    set "PL_LABEL=Single track only"
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
echo   Archive     : !CFG_ARCHIVE!    History log: !CFG_HISTORY!
if not "!CFG_SPEED!"=="" echo   Speed       : !CFG_SPEED! limit

call :PREVIEW_URLS

echo  ------------------------------------------------------
echo   [Y]  Start Download   [N]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [y/n/b] (default=y): "
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DA_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                   DOWNLOADING...                     ^|
echo  +------------------------------------------------------+
echo.

set "_DONE_RETRY_TARGET=DA_DOWNLOAD"
:DA_DOWNLOAD
call :BUILD_DL_OPTS
call :APPLY_CHANNEL_TAB

if exist "%COMPLETED_TEMP%" del "%COMPLETED_TEMP%"
if exist "%ATTEMPTED_TEMP%" del "%ATTEMPTED_TEMP%"
if exist "%FAILED_TEMP%"    del "%FAILED_TEMP%"

call :LOG_INIT
"%YTDLP%" --ffmpeg-location "!FFMPEG_DIR!" %COMMON_OPTS% --newline -x --audio-format !AUD_FORMAT! --audio-quality !AUD_QUALITY! !PL_OPTS! !META_OPT! !THUMB_OPT! !COOKIE_OPT! !SLEEP_OPT! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! !ARCHIVE_OPT! !TRACK_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\!OUT_PREFIX!%%(title).200B.%%(ext)s" 2>&1 | powershell -NoProfile -Command "$w=[IO.StreamWriter]::new('%LOG_TMP%',$true);try{while($null -ne ($l=[Console]::In.ReadLine())){[Console]::WriteLine($l);$w.WriteLine($l);$w.Flush()}}finally{$w.Close()}"

call :DERIVE_STATUS
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
if /i "!_DL_MODE!"=="channel" (
echo  +------------------------------------------------------+
echo  ^|        VIDEO + AUDIO CHANNEL  (Separate Files^)       ^|
echo  ^|  Step 1/8  ^|  URL Input  ^|  Mode: Channel            ^|
echo  +------------------------------------------------------+
echo.
echo   Tab scope : !_CH_TAB_LABEL!
) else if /i "!_DL_MODE!"=="playlist" (
echo  +------------------------------------------------------+
echo  ^|       VIDEO + AUDIO PLAYLIST  (Separate Files^)      ^|
echo  ^|  Step 1/8  ^|  URL Input  ^|  Mode: Playlist           ^|
echo  +------------------------------------------------------+
) else (
echo  +------------------------------------------------------+
echo  ^|          SEPARATE VIDEO + AUDIO DOWNLOAD             ^|
echo  ^|  Step 1/8  ^|  URL Input  ^|  Mode: Single video       ^|
echo  +------------------------------------------------------+
)
echo.
echo   Enter URLs one by one, then press Enter with no input to proceed.
echo   L = List queue    D = Delete a URL    C = Clear all    B = Back
echo  ------------------------------------------------------
echo.

if "!_PRESERVE_URLS!"=="0" (
    if exist "%URL_TEMP%" del "%URL_TEMP%"
    set "URL_COUNT=0"
) else (
    set "URL_COUNT=0"
    if exist "%URL_TEMP%" (
        for /f "usebackq tokens=*" %%a in ("%URL_TEMP%") do set /a URL_COUNT+=1
    )
    echo   [Preserving !URL_COUNT! existing URL(s^)]
    echo.
)
set "_PRESERVE_URLS=0"

:DS_URL_LOOP
set "NEXT_URL="
set /a "_url_n=URL_COUNT + 1"
set /p "NEXT_URL=  URL !_url_n! (or L=List, D=Delete, C=Clear, B=Back) ^> "
if /i "!NEXT_URL!"=="B" goto MAIN_MENU
if /i "!NEXT_URL!"=="L" (
    call :LIST_URLS
    goto DS_URL_LOOP
)
if /i "!NEXT_URL!"=="D" (
    call :LIST_URLS
    if exist "%URL_TEMP%" (
        call :DELETE_URL_PROMPT
    ) else (
        echo   [ Queue is empty - nothing to delete. ]
    )
    goto DS_URL_LOOP
)
if /i "!NEXT_URL!"=="C" (
    call :CLEAR_URLS
    goto DS_URL_LOOP
)
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
call :CHECK_DUPE_URL
if /i "!_url_dupe!"=="yes" (
    echo   [^^!] Duplicate - this URL is already in the queue. Skipped.
    goto DS_URL_LOOP
)
echo !NEXT_URL!>> "%URL_TEMP%"
set /a URL_COUNT+=1
echo   [+] Added. Total: !URL_COUNT! URL(s^)
goto DS_URL_LOOP


:DS_RES
cls
echo.
echo  +------------------------------------------------------+
echo  ^|           [Step 2/8]  Video Resolution               ^|
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
if /i "!RES_CHOICE!"=="B" (
    set "_PRESERVE_URLS=1"
    goto DS_URL
)
if "!RES_CHOICE!"=="" set "RES_CHOICE=1"
:: bv*=best video (incl. muxed) is used as a fallback after bv (video-only)
:: so a video without a separate video-only stream still resolves instead
:: of failing with "Requested format is not available".
if "!RES_CHOICE!"=="1" (set "RESOLUTION=Best Available" & set "VID_FORMAT_STR=bv/bv*")
if "!RES_CHOICE!"=="2" (set "RESOLUTION=4K (2160p)"     & set "VID_FORMAT_STR=bv[height<=2160]/bv*[height<=2160]/bv/bv*")
if "!RES_CHOICE!"=="3" (set "RESOLUTION=1440p"          & set "VID_FORMAT_STR=bv[height<=1440]/bv*[height<=1440]/bv/bv*")
if "!RES_CHOICE!"=="4" (set "RESOLUTION=1080p"          & set "VID_FORMAT_STR=bv[height<=1080]/bv*[height<=1080]/bv/bv*")
if "!RES_CHOICE!"=="5" (set "RESOLUTION=720p"           & set "VID_FORMAT_STR=bv[height<=720]/bv*[height<=720]/bv/bv*")
if "!RES_CHOICE!"=="6" (set "RESOLUTION=480p"           & set "VID_FORMAT_STR=bv[height<=480]/bv*[height<=480]/bv/bv*")
if "!RES_CHOICE!"=="7" (set "RESOLUTION=360p"           & set "VID_FORMAT_STR=bv[height<=360]/bv*[height<=360]/bv/bv*")
if "!RESOLUTION!"=="" (
    echo   [^^!] Invalid choice. Please try again.
    timeout /t 1 >nul
    goto DS_RES
)


:DS_VID_FMT
cls
echo.
echo  +------------------------------------------------------+
echo  ^|        [Step 3/8]  Video Output Format               ^|
echo  +------------------------------------------------------+
echo.
echo   Container for the separate VIDEO file (remuxed, no re-encode).
echo.
echo   [1]  mp4    (recommended, universal)
echo   [2]  mkv    (high quality container)
echo   [3]  webm   (open format)
echo   [4]  mov    (Apple QuickTime)
echo   [5]  avi    (legacy, wide compat)
echo   [6]  flv    (Flash Video)
echo   [7]  Original  (keep source container, no remux)
echo   [B]  Back
echo.
set "DS_VID_FORMAT="
set "DS_VID_REMUX="
set "DS_VFMT_CHOICE="
set /p "DS_VFMT_CHOICE=  Choose video format [1-7, default=1]: "
if /i "!DS_VFMT_CHOICE!"=="B" goto DS_RES
if "!DS_VFMT_CHOICE!"=="" set "DS_VFMT_CHOICE=1"
if "!DS_VFMT_CHOICE!"=="1" set "DS_VID_FORMAT=mp4"
if "!DS_VFMT_CHOICE!"=="2" set "DS_VID_FORMAT=mkv"
if "!DS_VFMT_CHOICE!"=="3" set "DS_VID_FORMAT=webm"
if "!DS_VFMT_CHOICE!"=="4" set "DS_VID_FORMAT=mov"
if "!DS_VFMT_CHOICE!"=="5" set "DS_VID_FORMAT=avi"
if "!DS_VFMT_CHOICE!"=="6" set "DS_VID_FORMAT=flv"
if "!DS_VFMT_CHOICE!"=="7" set "DS_VID_FORMAT=Original"
if "!DS_VID_FORMAT!"=="" (
    echo   [^^!] Invalid choice. Please try again.
    timeout /t 1 >nul
    goto DS_VID_FMT
)
:: Only remux when a specific container was chosen (not "Original")
if /i not "!DS_VID_FORMAT!"=="Original" set "DS_VID_REMUX=--remux-video !DS_VID_FORMAT!"


:DS_AUD_FMT
cls
echo.
echo  +------------------------------------------------------+
echo  ^|        [Step 4/8]  Audio Format (separate file)      ^|
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
if /i "!AUD_CHOICE!"=="B" goto DS_VID_FMT
if "!AUD_CHOICE!"=="" set "AUD_CHOICE=1"
if "!AUD_CHOICE!"=="1" set "AUD_FORMAT=mp3"
if "!AUD_CHOICE!"=="2" set "AUD_FORMAT=aac"
if "!AUD_CHOICE!"=="3" set "AUD_FORMAT=flac"
if "!AUD_CHOICE!"=="4" set "AUD_FORMAT=m4a"
if "!AUD_CHOICE!"=="5" set "AUD_FORMAT=opus"
if "!AUD_CHOICE!"=="6" set "AUD_FORMAT=wav"
if "!AUD_CHOICE!"=="7" set "AUD_FORMAT=alac"
if "!AUD_CHOICE!"=="8" set "AUD_FORMAT=vorbis"
if "!AUD_FORMAT!"=="" (
    echo   [^^!] Invalid choice. Please try again.
    timeout /t 1 >nul
    goto DS_AUD_FMT
)


:DS_AUD_QUAL
cls
echo.
echo  +------------------------------------------------------+
echo  ^|             [Step 5/8]  Audio Quality                ^|
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
if /i "!QUAL_CHOICE!"=="B" goto DS_AUD_FMT
if "!QUAL_CHOICE!"=="" set "QUAL_CHOICE=1"
if "!QUAL_CHOICE!"=="1" set "AUD_QUALITY=0"
if "!QUAL_CHOICE!"=="2" set "AUD_QUALITY=2"
if "!QUAL_CHOICE!"=="3" set "AUD_QUALITY=5"
if "!QUAL_CHOICE!"=="4" set "AUD_QUALITY=9"
if "!QUAL_CHOICE!"=="5" set "AUD_QUALITY=320K"
if "!QUAL_CHOICE!"=="6" set "AUD_QUALITY=256K"
if "!QUAL_CHOICE!"=="7" set "AUD_QUALITY=192K"
if "!QUAL_CHOICE!"=="8" set "AUD_QUALITY=128K"
if "!AUD_QUALITY!"=="" (
    echo   [^^!] Invalid choice. Please try again.
    timeout /t 1 >nul
    goto DS_AUD_QUAL
)


:DS_SUBS
cls
echo.
echo  +------------------------------------------------------+
echo  ^|              [Step 6/8]  Subtitles                   ^|
echo  +------------------------------------------------------+
echo.
echo   Saved as a separate .srt file alongside the video.
echo.
echo   [1]  No subtitles  (default)
echo   [2]  Auto-generated subtitles  (e.g. YouTube auto-captions)
echo   [B]  Back
echo.
set "SUB_OPTS="
set "SUB_LABEL=None"
set "SUB_CHOICE="
set /p "SUB_CHOICE=  Choose subtitle option [1-2, default=1]: "
if /i "!SUB_CHOICE!"=="B" goto DS_AUD_QUAL
if "!SUB_CHOICE!"=="" set "SUB_CHOICE=1"
if "!SUB_CHOICE!"=="1" goto DS_OUT
if "!SUB_CHOICE!"=="2" (
    echo.
    echo   Language codes: en  id  ja  es  ko  zh  etc.
    set "SUB_LANG_IN="
    set /p "SUB_LANG_IN=  Subtitle language [default=en]: "
    if "!SUB_LANG_IN!"=="" set "SUB_LANG_IN=en"
    set "SUB_OPTS=--write-auto-subs --sub-langs !SUB_LANG_IN! --convert-subs srt"
    set "SUB_LABEL=Auto-generated [!SUB_LANG_IN!]"
    goto DS_OUT
)
echo   [^^!] Invalid choice. Please try again.
timeout /t 1 >nul
goto DS_SUBS


:DS_OUT
cls
echo.
echo  +------------------------------------------------------+
echo  ^|             [Step 7/8]  Output Path                  ^|
echo  +------------------------------------------------------+
echo.
echo   Default: !DEFAULT_OUTPUT!
echo.
echo   Press Enter to use default, or type a path. Type B to go back.
echo.
set "CUSTOM_PATH="
set "BASE_OUTPUT_PATH="
set /p "CUSTOM_PATH=  Output path: "
if /i "!CUSTOM_PATH!"=="B" goto DS_SUBS
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
if /i "!CFG_ALWAYS_SUBFOLDER!"=="yes" (
    set "CREATE_SUBFOLDER=y"
) else if /i "!CFG_ALWAYS_SUBFOLDER!"=="no" (
    set "CREATE_SUBFOLDER=n"
) else (
    echo.
    set /p "CREATE_SUBFOLDER=  Create subfolder for this download? (y/n) [y]: "
)
if "!CREATE_SUBFOLDER!"=="" set "CREATE_SUBFOLDER=y"
if /i "!CREATE_SUBFOLDER!"=="n" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!"
    goto DS_PATH_DONE
)

:DS_SUBNAME
set "SUBFOLDER_NAME=Video+Audio"
echo.
set "SF_NAME_IN="
set /p "SF_NAME_IN=  Subfolder name [default=Video+Audio] (B=back): "
if /i "!SF_NAME_IN!"=="B" goto DS_OUT
if not "!SF_NAME_IN!"=="" set "SUBFOLDER_NAME=!SF_NAME_IN!"
if /i "!_DL_MODE!"=="channel" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\Channel\!SUBFOLDER_NAME!"
    if not exist "!BASE_OUTPUT_PATH!\Channel" mkdir "!BASE_OUTPUT_PATH!\Channel"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: Channel\!SUBFOLDER_NAME!\^<channel^>\ ^(auto-named per channel^)
) else if /i "!_DL_MODE!"=="playlist" (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\Playlist\!SUBFOLDER_NAME!"
    if not exist "!BASE_OUTPUT_PATH!\Playlist" mkdir "!BASE_OUTPUT_PATH!\Playlist"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: Playlist\!SUBFOLDER_NAME!
) else (
    set "OUTPUT_PATH=!BASE_OUTPUT_PATH!\!SUBFOLDER_NAME!"
    if not exist "!OUTPUT_PATH!" mkdir "!OUTPUT_PATH!"
    echo   Subfolder: !SUBFOLDER_NAME!
)
:DS_PATH_DONE


:DS_SUMMARY
if /i "!_DL_MODE!"=="channel" (
    set "PL_OPTS=--ignore-errors"
    set "PL_LABEL=Channel - !_CH_TAB_LABEL!, skip broken"
) else if /i "!_DL_MODE!"=="playlist" (
    set "PL_OPTS=--ignore-errors"
    set "PL_LABEL=Playlist - download all, skip broken"
) else (
    set "PL_OPTS=--no-playlist"
    set "PL_LABEL=Single video only"
)
cls
echo.
echo  +------------------------------------------------------+
echo  ^|             [Step 8/8]  Download Summary             ^|
echo  +------------------------------------------------------+
echo.
echo   URLs          : !URL_COUNT! URL(s^) queued
echo   Video Quality : !RESOLUTION!
echo   Video Format  : !DS_VID_FORMAT!
echo   Audio Format  : !AUD_FORMAT!
echo   Audio Quality : !AUD_QUALITY!
echo   Subtitles     : !SUB_LABEL!
echo   Playlist      : !PL_LABEL!
echo   Output        : !OUTPUT_PATH!
echo   Metadata      : !CFG_METADATA!    Thumbnail: !CFG_THUMBNAIL!
echo   Cookies       : !CFG_COOKIES_LABEL!
echo   Archive       : !CFG_ARCHIVE!    History log: !CFG_HISTORY!
echo.
echo   NOTE: Video and audio will be saved as SEPARATE files.
echo   TIP:  The standard Video Download mode auto-merges them
echo         into one file - use that unless you specifically
echo         want raw separate streams.

call :PREVIEW_URLS

echo  ------------------------------------------------------
echo   [Y]  Start Download   [N]  Cancel   [B]  Back to Edit Options
echo  ------------------------------------------------------
set "CONFIRM="
set /p "CONFIRM=  Choose [y/n/b] (default=y): "
if "!CONFIRM!"=="" set "CONFIRM=Y"
if /i "!CONFIRM!"=="B" goto DS_OUT
if /i not "!CONFIRM!"=="Y" goto MAIN_MENU

cls
echo.
echo  +------------------------------------------------------+
echo  ^|                 DOWNLOADING VIDEO...                 ^|
echo  +------------------------------------------------------+
echo.

set "_DONE_RETRY_TARGET=DS_DOWNLOAD"
:DS_DOWNLOAD
call :BUILD_DL_OPTS
call :APPLY_CHANNEL_TAB

if exist "%COMPLETED_TEMP%" del "%COMPLETED_TEMP%"
if exist "%ATTEMPTED_TEMP%" del "%ATTEMPTED_TEMP%"
if exist "%FAILED_TEMP%"    del "%FAILED_TEMP%"

call :LOG_INIT
"%YTDLP%" --ffmpeg-location "!FFMPEG_DIR!" %COMMON_OPTS% --newline -f "!VID_FORMAT_STR!" !DS_VID_REMUX! !SUB_OPTS! !PL_OPTS! !META_OPT! !CHAP_OPT! !COOKIE_OPT! !SLEEP_OPT! -N !CFG_FRAGMENTS! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! !ARCHIVE_OPT! !TRACK_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\!OUT_PREFIX!%%(title).180B [VIDEO].%%(ext)s" 2>&1 | powershell -NoProfile -Command "$w=[IO.StreamWriter]::new('%LOG_TMP%',$true);try{while($null -ne ($l=[Console]::In.ReadLine())){[Console]::WriteLine($l);$w.WriteLine($l);$w.Flush()}}finally{$w.Close()}"

:: Piped output hides yt-dlp's exit code, so judge the video step by
:: whether anything was recorded as completed (after_move hook).
set "_DS_VID_RC=1"
if exist "%COMPLETED_TEMP%" for /f "usebackq tokens=*" %%a in ("%COMPLETED_TEMP%") do set "_DS_VID_RC=0"
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

:: For the audio pass we deliberately omit TRACK_OPT - we already tracked
:: success in the video pass; appending audio successes would double-count
:: and confuse the failed-items computation.
"%YTDLP%" --ffmpeg-location "!FFMPEG_DIR!" %COMMON_OPTS% --newline -x --audio-format !AUD_FORMAT! --audio-quality !AUD_QUALITY! !PL_OPTS! !META_OPT! !COOKIE_OPT! !SLEEP_OPT! -R !CFG_RETRIES! !SPEED_OPT! !SKIP_OPT! !HISTORY_OPT! !ARCHIVE_OPT! -a "%URL_TEMP%" -o "!OUTPUT_PATH!\!OUT_PREFIX!%%(title).180B [AUDIO].%%(ext)s" 2>&1 | powershell -NoProfile -Command "$w=[IO.StreamWriter]::new('%LOG_TMP%',$true);try{while($null -ne ($l=[Console]::In.ReadLine())){[Console]::WriteLine($l);$w.WriteLine($l);$w.Flush()}}finally{$w.Close()}"

:: Status is derived from the tracked video pass (the audio pass has no
:: tracking hooks); a completed video step counts the URL as done.
call :DERIVE_STATUS
set "_DONE_COUNT=!URL_COUNT!"
set "_DONE_PATH=!OUTPUT_PATH!"
set "_DONE_MODE=Video+Audio (separate) - !RESOLUTION! !DS_VID_FORMAT! + !AUD_FORMAT! @ !AUD_QUALITY! / Subs: !SUB_LABEL!"
set "_DONE_EXTRA=Two files per URL: [VIDEO] and [AUDIO]"
if !_DL_RC! NEQ 0 (set "_DONE_STATUS=FAIL") else (set "_DONE_STATUS=OK")
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
echo   Embed metadata  : !CFG_METADATA!
echo   Embed chapters  : !CFG_CHAPTERS!
echo   Embed thumbnail : !CFG_THUMBNAIL!
echo   SponsorBlock    : !CFG_SPONSORBLOCK!
echo   Cookies         : !CFG_COOKIES_LABEL!
if not "!CFG_COOKIES_FILE!"=="" echo   Cookies file    : !CFG_COOKIES_FILE!
echo   Info preview    : !CFG_PREVIEW!
echo   Always subfolder: !CFG_ALWAYS_SUBFOLDER!
echo   Download history: !CFG_HISTORY!
echo   Download archive: !CFG_ARCHIVE!
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
echo   [11] Cookie integration  (browser or cookies.txt file)
echo   [12] Toggle info preview
echo   [13] Set sleep interval  (anti-ban throttle)
echo   [14] Update yt-dlp  (self-updater)
echo   [15] Show tool versions
echo   [16] Toggle download history log  (writes _history.txt)
echo   [17] Toggle download archive  (skip already-downloaded videos)
echo   [18] Set subfolder mode  (ask/yes/no)  [Playlist gets Playlist\Type\ nesting]
echo   [B]  Back to Main Menu
echo.
set "SET_CHOICE="
set /p "SET_CHOICE=  Choose an option: "

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
if "!SET_CHOICE!"=="17" goto SET_TOGGLE_ARCHIVE
if "!SET_CHOICE!"=="18" goto SET_SUBFOLDER_MODE
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

:SET_TOGGLE_ARCHIVE
if /i "!CFG_ARCHIVE!"=="yes" (set "CFG_ARCHIVE=no") else (set "CFG_ARCHIVE=yes")
echo   Download archive: !CFG_ARCHIVE!
if /i "!CFG_ARCHIVE!"=="yes" (
    echo   ^(will write _archive.txt and skip already-downloaded videos^)
    echo   ^(delete the file in the output folder to reset^)
)
timeout /t 3 >nul
goto SETTINGS

:SET_SUBFOLDER_MODE
echo.
echo   Subfolder mode controls where downloads are saved inside
echo   the output path. When enabled, the structure is:
echo.
echo     Single downloads : Output\Video\
echo                        Output\Audio\
echo                        Output\Video+Audio\
echo.
echo     Playlist downloads : Output\Playlist\Video\
echo                          Output\Playlist\Audio\
echo                          Output\Playlist\Video+Audio\
echo.
echo   [1]  Ask each time   (default)
echo   [2]  Always create   (skip prompt, always make subfolder)
echo   [3]  Never create    (skip prompt, save to base path)
echo.
set "SF_CHOICE="
set /p "SF_CHOICE=  Choose [1-3, default=1]: "
if "!SF_CHOICE!"=="" set "SF_CHOICE=1"
if "!SF_CHOICE!"=="1" set "CFG_ALWAYS_SUBFOLDER=ask"
if "!SF_CHOICE!"=="2" set "CFG_ALWAYS_SUBFOLDER=yes"
if "!SF_CHOICE!"=="3" set "CFG_ALWAYS_SUBFOLDER=no"
echo   Subfolder mode set to: !CFG_ALWAYS_SUBFOLDER!
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
echo  ^|                COOKIE INTEGRATION                    ^|
echo  +------------------------------------------------------+
echo.
if not "!CFG_COOKIES_FILE!"=="" (
    echo   Current: cookies.txt file
    echo            !CFG_COOKIES_FILE!
) else (
    echo   Current: !CFG_COOKIES_LABEL!
)
echo.
echo   Use cookies to access age-restricted, members-only, or
echo   login-required content.
echo.
echo   --- BROWSER COOKIES ---
echo   [1]  None  (no cookies)
echo   [2]  Chrome
echo   [3]  Firefox
echo   [4]  Edge
echo   [5]  Brave
echo   [6]  Opera
echo   [7]  Safari
echo   [8]  Chromium
echo   [9]  Vivaldi
echo.
echo   --- COOKIE FILE (more reliable than browser cookies) ---
echo   [10] Use cookies.txt file path
echo   [11] Clear cookies.txt file path
echo.
echo   [B]  Back to Settings
echo.
set "CK_CHOICE="
set /p "CK_CHOICE=  Choose option [default=1]: "
if /i "!CK_CHOICE!"=="B" goto SETTINGS
if "!CK_CHOICE!"=="" set "CK_CHOICE=1"
if "!CK_CHOICE!"=="10" goto COOKIE_FILE_SET
if "!CK_CHOICE!"=="11" (
    set "CFG_COOKIES_FILE="
    echo   Cookies file cleared. Will use browser source: !CFG_COOKIES_LABEL!
    timeout /t 2 >nul
    goto SETTINGS
)
set "_was_browser=no"
if "!CK_CHOICE!"=="1" (set "CFG_COOKIES=none"     & set "CFG_COOKIES_LABEL=No cookies"  & set "_was_browser=yes")
if "!CK_CHOICE!"=="2" (set "CFG_COOKIES=chrome"   & set "CFG_COOKIES_LABEL=Chrome"      & set "_was_browser=yes")
if "!CK_CHOICE!"=="3" (set "CFG_COOKIES=firefox"  & set "CFG_COOKIES_LABEL=Firefox"     & set "_was_browser=yes")
if "!CK_CHOICE!"=="4" (set "CFG_COOKIES=edge"     & set "CFG_COOKIES_LABEL=Edge"        & set "_was_browser=yes")
if "!CK_CHOICE!"=="5" (set "CFG_COOKIES=brave"    & set "CFG_COOKIES_LABEL=Brave"       & set "_was_browser=yes")
if "!CK_CHOICE!"=="6" (set "CFG_COOKIES=opera"    & set "CFG_COOKIES_LABEL=Opera"       & set "_was_browser=yes")
if "!CK_CHOICE!"=="7" (set "CFG_COOKIES=safari"   & set "CFG_COOKIES_LABEL=Safari"      & set "_was_browser=yes")
if "!CK_CHOICE!"=="8" (set "CFG_COOKIES=chromium" & set "CFG_COOKIES_LABEL=Chromium"    & set "_was_browser=yes")
if "!CK_CHOICE!"=="9" (set "CFG_COOKIES=vivaldi"  & set "CFG_COOKIES_LABEL=Vivaldi"     & set "_was_browser=yes")
if /i "!_was_browser!"=="yes" (
    set "CFG_COOKIES_FILE="
    if not "!CK_CHOICE!"=="1" (
        echo.
        echo  +------------------------------------------------------+
        echo  ^|                    [!] WARNING                       ^|
        echo  +------------------------------------------------------+
        echo   Using browser cookies will pass YOUR LOGGED-IN session
        echo   to yt-dlp. Only use this for URLs you trust. A malicious
        echo   site URL could expose your account.
        echo.
        echo   Close the browser before downloading if you hit cookie
        echo   database lock errors (especially on Chrome/Edge/Brave).
        echo  ------------------------------------------------------
        pause
    )
    echo.
    echo   Cookies source: !CFG_COOKIES_LABEL!
    timeout /t 2 >nul
)
goto SETTINGS


:COOKIE_FILE_SET
echo.
echo   How to export cookies.txt:
echo     1. Install browser extension "Get cookies.txt LOCALLY"
echo     2. Open the target site, log in
echo     3. Click the extension - Export as Netscape format
echo     4. Save as cookies.txt
echo.
echo   Type the full path to the cookies.txt file, or B to cancel:
set "NEW_COOKIE_FILE="
set /p "NEW_COOKIE_FILE=  Path: "
if /i "!NEW_COOKIE_FILE!"=="B" goto COOKIE_MENU
if "!NEW_COOKIE_FILE!"=="" goto COOKIE_MENU
if not exist "!NEW_COOKIE_FILE!" (
    echo   [^^!] File not found. No changes made.
    timeout /t 3 >nul
    goto COOKIE_MENU
)
set "CFG_COOKIES_FILE=!NEW_COOKIE_FILE!"
echo.
echo  +------------------------------------------------------+
echo  ^|                    [!] WARNING                       ^|
echo  +------------------------------------------------------+
echo   This file contains your logged-in session. Anyone with
echo   read access can impersonate you on those sites. Keep it
echo   in a private folder.
echo  ------------------------------------------------------
echo   Cookies file set: !CFG_COOKIES_FILE!
pause
goto SETTINGS


:: =====================================================
:EXIT
:: =====================================================
if exist "%URL_TEMP%"       del "%URL_TEMP%"
if exist "%COMPLETED_TEMP%" del "%COMPLETED_TEMP%"
if exist "%ATTEMPTED_TEMP%" del "%ATTEMPTED_TEMP%"
if exist "%FAILED_TEMP%"    del "%FAILED_TEMP%"
if exist "%LOG_TMP%"        del "%LOG_TMP%"
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
