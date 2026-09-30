@echo off
REM ==========================================================================
REM  EcoXchange Mobile - start the full local development environment.
REM
REM    start_ecoxchange_mobile.bat           start everything, then run the app
REM    start_ecoxchange_mobile.bat --check   start/verify services only, no flutter run
REM
REM  Order: Laragon (Apache+MySQL, serves http://ecoxchange.test)
REM         -> FastAPI AI service on 127.0.0.1:8001 (own window)
REM         -> Android emulator -> flutter run (debug) in THIS window.
REM  Services that are already running are reused, never started twice.
REM  Any failure stops the script with a message naming the failed component.
REM
REM  Paths: the Flutter project is the folder this script is in. The external
REM  dependencies can be overridden with environment variables; when a
REM  variable is not set, the default below is used:
REM    ECOXCHANGE_LARAVEL_DIR  Laravel project (contains artisan and ai_service\)
REM    ECOXCHANGE_PYTHON       Python interpreter that runs the FastAPI AI service
REM    LARAGON_EXE             Laragon executable (only used if Laragon is not running)
REM  See docs\LOCAL_MOBILE_DEVELOPMENT.md.
REM ==========================================================================
setlocal EnableExtensions EnableDelayedExpansion

REM Flutter project = this script's own folder (no trailing backslash).
for %%I in ("%~dp0.") do set "FLUTTER_DIR=%%~fI"

REM External dependencies: environment variable if set, otherwise the default.
if not defined ECOXCHANGE_LARAVEL_DIR set "ECOXCHANGE_LARAVEL_DIR=C:\laragon\www\Ecoxchange"
if not defined ECOXCHANGE_PYTHON set "ECOXCHANGE_PYTHON=C:\ml\venv\Scripts\python.exe"
if not defined LARAGON_EXE set "LARAGON_EXE=C:\laragon\laragon.exe"

set "LARAVEL_DIR=%ECOXCHANGE_LARAVEL_DIR%"
set "AI_DIR=%LARAVEL_DIR%\ai_service"
set "VENV_PY=%ECOXCHANGE_PYTHON%"
set "ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk"
set "ADB=%ANDROID_SDK%\platform-tools\adb.exe"
set "EMULATOR=%ANDROID_SDK%\emulator\emulator.exe"
set "AVD_NAME=Medium_Phone_API_36.1"
set "LARAVEL_HOST=ecoxchange.test"

set "PATH=%ANDROID_SDK%\platform-tools;%ANDROID_SDK%\emulator;%PATH%"

set "CHECK_ONLY=0"
if /I "%~1"=="--check" set "CHECK_ONLY=1"

echo.
echo === EcoXchange Mobile local environment ===
echo.

REM ---------- 0. Required paths / tools ----------------------------------------
echo [ .. ] Flutter project: %FLUTTER_DIR%
echo [ .. ] Laravel project: %LARAVEL_DIR%
echo [ .. ] Python:          %VENV_PY%
if not exist "%FLUTTER_DIR%\pubspec.yaml" (
    echo [FAIL] Paths: no pubspec.yaml next to this script - keep start_ecoxchange_mobile.bat in the Flutter project root.
    goto :fail
)
if not exist "%LARAVEL_DIR%\artisan" (
    echo [FAIL] Paths: Laravel not found - missing "!LARAVEL_DIR!\artisan". Set ECOXCHANGE_LARAVEL_DIR to your Laravel project folder.
    goto :fail
)
if not exist "%AI_DIR%\app\main.py" (
    echo [FAIL] Paths: AI service not found - missing "!AI_DIR!\app\main.py". Set ECOXCHANGE_LARAVEL_DIR to the Laravel folder that contains ai_service.
    goto :fail
)
if not exist "%VENV_PY%" (
    echo [FAIL] Paths: Python not found - missing "!VENV_PY!". Set ECOXCHANGE_PYTHON to the python.exe of the AI service environment.
    goto :fail
)
for %%P in ("%ADB%" "%EMULATOR%") do (
    if not exist "%%~P" (
        echo [FAIL] Paths: Android SDK tool missing - %%~P. Install the Android SDK platform-tools and emulator under %%LOCALAPPDATA%%\Android\Sdk.
        goto :fail
    )
)
where flutter >nul 2>&1 || (echo [FAIL] Flutter: 'flutter' is not on PATH & goto :fail)
where curl >nul 2>&1 || (echo [FAIL] curl.exe not found ^(ships with Windows 10/11^) & goto :fail)
echo [ OK ] Required paths and tools found

REM ---------- 1. Laragon: Apache :80 + MySQL :3306 ------------------------------
call :is_listening 80 & set "WEB_UP=!LISTENING!"
call :is_listening 3306 & set "DB_UP=!LISTENING!"
if "!WEB_UP!!DB_UP!"=="11" (
    echo [ OK ] Laragon already running ^(Apache :80, MySQL :3306^)
    goto :laragon_done
)
if not exist "!LARAGON_EXE!" (echo [FAIL] Laragon: "!LARAGON_EXE!" not found. Start Laragon yourself, or set LARAGON_EXE to laragon.exe. & goto :fail)
echo [....] Starting Laragon - if it does not auto-start services, click "Start All" in Laragon
start "" "%LARAGON_EXE%"
set /a WAITED=0
:wait_laragon
call :sleep 3
set /a WAITED+=3
call :is_listening 80 & set "WEB_UP=!LISTENING!"
call :is_listening 3306 & set "DB_UP=!LISTENING!"
if "!WEB_UP!!DB_UP!"=="11" goto :laragon_started
if !WAITED! LSS 90 goto :wait_laragon
echo [FAIL] Laragon: Apache :80 and/or MySQL :3306 not listening after 90s. Open Laragon and click "Start All", then re-run.
goto :fail
:laragon_started
echo [ OK ] Laragon started
:laragon_done

REM ---------- 2. Laravel responds through the ecoxchange.test vhost -------------
for /f %%C in ('curl -s -o NUL -m 15 -w "%%{http_code}" -H "Host: %LARAVEL_HOST%" http://127.0.0.1/') do set "WEB_CODE=%%C"
if not "!WEB_CODE!"=="200" (
    echo [FAIL] Laravel: http://%LARAVEL_HOST%/ returned HTTP !WEB_CODE! ^(expected 200^). Check Laragon's virtual host / Apache.
    goto :fail
)
for /f %%C in ('curl -s -o NUL -m 15 -w "%%{http_code}" -H "Host: %LARAVEL_HOST%" -H "Accept: application/json" http://127.0.0.1/api/v1/customer/items') do set "API_CODE=%%C"
if not "!API_CODE!"=="401" (
    echo [FAIL] Laravel API: /api/v1/customer/items returned HTTP !API_CODE! ^(expected 401 without a token^).
    goto :fail
)
echo [ OK ] Laravel responding ^(web 200, API 401 = auth required^)

REM ---------- 3. FastAPI AI service on 127.0.0.1:8001 ---------------------------
call :is_listening 8001
if "!LISTENING!"=="1" (
    call :ai_healthy
    if "!AI_OK!"=="1" (
        echo [ OK ] AI service already running on :8001 - reusing it
        goto :ai_done
    )
    echo [FAIL] AI service: port 8001 is in use but /health is not OK. Close whatever is on port 8001 ^(see docs^) and re-run.
    goto :fail
)
echo [....] Starting AI service in a new window "EcoXchange AI service" ^(model load takes ~30-60s^)
start "EcoXchange AI service" /D "%AI_DIR%" cmd /k ""%VENV_PY%" -m uvicorn app.main:app --host 127.0.0.1 --port 8001"
set /a WAITED=0
:wait_ai
call :sleep 3
set /a WAITED+=3
call :ai_healthy
if not "!AI_OK!"=="1" (
    if !WAITED! LSS 180 goto :wait_ai
    echo [FAIL] AI service: /health not OK after 180s. Read the error in the "EcoXchange AI service" window.
    goto :fail
)
echo [ OK ] AI service healthy ^(EfficientNet-B0 loaded^)
:ai_done

REM ---------- 4. ADB key (the emulator needs adbkey.pub to authorise adb) -------
if exist "%USERPROFILE%\.android\adbkey" if not exist "%USERPROFILE%\.android\adbkey.pub" (
    echo [....] Restoring missing %USERPROFILE%\.android\adbkey.pub from the existing adbkey
    "%ADB%" pubkey "%USERPROFILE%\.android\adbkey" > "%USERPROFILE%\.android\adbkey.pub" || (echo [FAIL] ADB: could not create adbkey.pub & goto :fail)
    "%ADB%" kill-server >nul 2>&1
)
"%ADB%" start-server >nul 2>&1 || (echo [FAIL] ADB: server did not start & goto :fail)

REM ---------- 5. Android emulator ------------------------------------------------
call :find_emulator
if defined EMU_SERIAL (
    echo [ OK ] Emulator already running: !EMU_SERIAL! - reusing it
) else (
    "%EMULATOR%" -list-avds | findstr /x /c:"%AVD_NAME%" >nul || (
        echo [FAIL] Emulator: AVD "%AVD_NAME%" not found. Available AVDs:
        "%EMULATOR%" -list-avds
        echo        Edit AVD_NAME at the top of this script.
        goto :fail
    )
    REM Cold boot on purpose: on this machine the AVD's quick-boot snapshot
    REM repeatedly left the emulator hung or stuck "offline"/"authorizing" for adb,
    REM while a cold boot was ready in ~70s. The AVD's own settings are not changed.
    echo [....] Cold-booting emulator %AVD_NAME% in its own window ^(~1-2 min^)
    start "Android emulator" "%EMULATOR%" -avd %AVD_NAME% -no-snapshot-load
)
set /a WAITED=0
:wait_boot
call :find_emulator
set "BOOTED="
if defined EMU_SERIAL (
    for /f "delims=" %%B in ('adb -s !EMU_SERIAL! shell getprop sys.boot_completed 2^>nul') do set "BOOTED=%%B"
)
if not "!BOOTED!"=="1" (
    if !WAITED! GEQ 300 (
        echo [FAIL] Emulator: not fully booted after 300s. Current adb state:
        "%ADB%" devices
        echo        If it shows "authorizing" or "offline", see Troubleshooting in docs\LOCAL_MOBILE_DEVELOPMENT.md.
        goto :fail
    )
    REM After a quick-boot snapshot restore adb can stay "offline"; reconnecting fixes it.
    if !WAITED! GEQ 30 adb reconnect offline >nul 2>&1
    call :sleep 3
    set /a WAITED+=3
    goto :wait_boot
)
echo [ OK ] Emulator ready: !EMU_SERIAL!

REM ---------- 6. Emulator can reach Laravel via 10.0.2.2 ------------------------
REM Retried: right after boot the emulator's network can take a few seconds to come up.
set /a NET_TRIES=0
:wait_net
set "EMU_HTTP="
for /f "tokens=2" %%S in ('adb -s !EMU_SERIAL! shell "printf 'GET /api/v1/customer/items HTTP/1.1\r\nHost: %LARAVEL_HOST%\r\nAccept: application/json\r\nConnection: close\r\n\r\n' | nc -w 5 10.0.2.2 80 | head -1" 2^>nul') do set "EMU_HTTP=%%S"
set /a NET_TRIES+=1
if not "!EMU_HTTP!"=="401" if !NET_TRIES! LSS 10 (
    call :sleep 3
    goto :wait_net
)
if "!EMU_HTTP!"=="401" (
    echo [ OK ] Emulator reaches Laravel at 10.0.2.2 with Host %LARAVEL_HOST%
) else (
    echo [WARN] Could not confirm emulator -^> 10.0.2.2 connectivity ^(got "!EMU_HTTP!"^). The app may fail to reach the API.
)

echo.
if "%CHECK_ONLY%"=="1" (
    echo All services are up. --check given, so Flutter was not started.
    echo Run the app with:  cd /d "%FLUTTER_DIR%" ^&^& flutter run -d !EMU_SERIAL!
    exit /b 0
)

REM ---------- 7. Flutter app (debug, interactive: r = hot reload, q = quit) -----
echo [....] Launching the app on !EMU_SERIAL! ^(debug^). Keys: r hot reload, R hot restart, q quit.
echo.
cd /d "%FLUTTER_DIR%"
flutter run -d !EMU_SERIAL!
exit /b %ERRORLEVEL%

REM ============================ helpers ======================================
:sleep
REM usage: call :sleep SECONDS  (ping-based: works even when stdin is redirected, unlike timeout)
set /a "_PINGS=%~1+1"
ping -n %_PINGS% 127.0.0.1 >nul
exit /b 0

:is_listening
REM usage: call :is_listening PORT  -> sets LISTENING=1/0
set "LISTENING=0"
netstat -ano -p TCP | findstr /R /C:":%~1 .*LISTENING" >nul && set "LISTENING=1"
exit /b 0

:ai_healthy
set "AI_OK=0"
curl -s -m 5 http://127.0.0.1:8001/health 2>nul | findstr /C:"\"model_loaded\":true" >nul && set "AI_OK=1"
exit /b 0

:find_emulator
set "EMU_SERIAL="
for /f "tokens=1,2" %%A in ('adb devices 2^>nul ^| findstr /B "emulator-"') do (
    if "%%B"=="device" if not defined EMU_SERIAL set "EMU_SERIAL=%%A"
)
exit /b 0

:fail
echo.
echo Environment NOT ready - fix the [FAIL] above and re-run this script.
exit /b 1
