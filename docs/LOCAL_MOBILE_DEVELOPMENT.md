# EcoXchange Mobile Local Development

How to run the full stack locally for interactive testing:

```
Flutter app (Android emulator)
  → Laravel on Laragon (http://ecoxchange.test)
  → FastAPI AI service (127.0.0.1:8001)
  → EfficientNet-B0 (single-object classify) / RetinaNet + EfficientNet-B0 (multi-object detect, Beta)
```

Everything is real: no mock API or AI responses. Single-object classification is live, and
multi-object detection is live as a Beta feature (see `AI_MULTI_OBJECT_SCAN.md`).

## Repositories

`EcoXchange-Mobile` is an **independent Git repository** (the Flutter app only). The Laravel
backend, including the FastAPI AI service in its `ai_service/` folder, is a separate project and
repository. The two only need to be present on the same machine to run the stack.

## Prerequisites

| Component | Notes | Example location (this project's Windows dev machine) |
|---|---|---|
| Laragon | Apache serves `http://ecoxchange.test` (hosts file entry `127.0.0.1 Ecoxchange.test`). | `C:\laragon\laragon.exe` |
| PHP | Used by Laragon's Apache. For CLI `artisan`, use a PHP CLI build with `pdo_mysql` enabled (on the example machine the 8.5.x CLI builds cannot reach MySQL; the 8.3.30 build can). | `C:\laragon\bin\php\php-8.3.30-Win32-vs16-x64\php.exe` |
| MySQL | Laragon, port 3306, database `ecoxchange`. | — |
| Python | Environment with FastAPI, uvicorn and TensorFlow 2.20 for the AI service. | venv `C:\ml\venv` |
| Flutter | 3.38.5 stable, on PATH. | `C:\flutter` |
| Android SDK | adb and the emulator. The launcher expects it at `%LOCALAPPDATA%\Android\Sdk`. | `%LOCALAPPDATA%\Android\Sdk` |
| Android emulator | AVD `Medium_Phone_API_36.1` (Android 16, x86_64, WHPX acceleration). Change `AVD_NAME` at the top of the launcher to use another AVD. | — |

The example locations are the defaults of this project's development machine, not requirements.

## Project paths and launcher configuration

The launcher `start_ecoxchange_mobile.bat` lives in the Flutter project root and finds everything
as follows:

| What | How the launcher resolves it | Default when the variable is not set (example) |
|---|---|---|
| Flutter project | The folder the script is in (`%~dp0`). Never configured. | — |
| Laravel project | Environment variable `ECOXCHANGE_LARAVEL_DIR` | `C:\laragon\www\Ecoxchange` |
| AI service | `ai_service` inside the Laravel project | `<ECOXCHANGE_LARAVEL_DIR>\ai_service` |
| Python interpreter | Environment variable `ECOXCHANGE_PYTHON` | `C:\ml\venv\Scripts\python.exe` |
| Laragon executable | Environment variable `LARAGON_EXE` (only used when Apache/MySQL are not already running) | `C:\laragon\laragon.exe` |

To use other locations, set the variables before running the launcher, for example:

```bat
set ECOXCHANGE_LARAVEL_DIR=D:\projects\Ecoxchange
set ECOXCHANGE_PYTHON=D:\venvs\ecox\Scripts\python.exe
set LARAGON_EXE=D:\laragon\laragon.exe
start_ecoxchange_mobile.bat --check
```

(or set them permanently with `setx`, then open a new terminal). The launcher prints the paths
it is using, and if one is missing it stops with a `[FAIL] Paths: …` message naming the variable
to change.

## Start everything

1. Open **Laragon** and click **Start All** if Apache and MySQL are not already running. The
   script will also try to open Laragon.
2. Double-click `start_ecoxchange_mobile.bat` in the Flutter project folder, or run it from a
   terminal in that folder:

   ```bat
   cd /d <path-to>\EcoXchange-Mobile
   start_ecoxchange_mobile.bat
   ```

The script:

1. resolves and checks all paths (see above) and tools (`flutter`, `curl`, adb, emulator);
2. checks Laragon (:80, :3306) and Laravel (web 200, API 401 without a token);
3. starts the AI service in its own window (or reuses a healthy one on :8001);
4. restores `%USERPROFILE%\.android\adbkey.pub` if it is missing;
5. cold-boots the emulator (or reuses a running one) and waits for boot;
6. checks the emulator can reach Laravel via `10.0.2.2`;
7. runs `flutter run` in debug mode in the same window.

Any failure prints `[FAIL] <component>: <reason>` and stops. A cold start takes about 1.5–2
minutes plus the Flutter build.

`start_ecoxchange_mobile.bat --check` does everything except `flutter run`. Use it to verify or
warm up the environment.

## Start each service separately

Use these if the launcher fails; run each in its own terminal. Replace the placeholders with your
locations (on the example machine: `<laravel-dir>` = `C:\laragon\www\Ecoxchange`,
`<python>` = `C:\ml\venv\Scripts\python.exe`).

```bat
:: 1. Laravel — Laragon: open Laragon → Start All (Apache + MySQL). No artisan serve needed.

:: 2. AI service (keep this window open)
cd /d <laravel-dir>\ai_service
<python> -m uvicorn app.main:app --host 127.0.0.1 --port 8001

:: 3. Emulator (cold boot — see Troubleshooting for why)
"%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_36.1 -no-snapshot-load
:: wait until this prints "device" and boot is complete (prints 1):
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 shell getprop sys.boot_completed

:: 4. Flutter app (debug), from the Flutter project folder
cd /d <path-to>\EcoXchange-Mobile
flutter run -d emulator-5554
```

In `flutter run`: `r` hot reload, `R` hot restart, `q` quit.

## Check services

| Check | Command | Expected |
|---|---|---|
| Laravel web | `curl -s -o NUL -w "%{http_code}" http://ecoxchange.test/` | `200` |
| Laravel API | `curl -s -o NUL -w "%{http_code}" -H "Accept: application/json" http://ecoxchange.test/api/v1/customer/items` | `401` (reachable, needs token) |
| AI health | `curl http://127.0.0.1:8001/health` | `{"status":"ok","model_loaded":true,"model":"EfficientNet-B0","classes":8}` |
| AI model | `curl http://127.0.0.1:8001/model-info` | `model_sha256` starting `2250858b…` (the classifier) |
| ADB | `adb devices` | `emulator-5554  device` |
| Flutter | `flutter devices` | `sdk gphone64 x86 64 • emulator-5554` |

The app reaches Laravel at `http://10.0.2.2` (the emulator's alias for the host machine) and
sends `Host: ecoxchange.test` so Laragon's name-based virtual host answers. This is in
`lib/core/api/api_config.dart`; don't change it for the emulator.

## Stop everything

1. **Flutter:** press `q` in the `flutter run` window. This stops the app; the emulator keeps
   running.
2. **Emulator:** close the emulator window, or run `adb -s emulator-5554 emu kill`.
3. **FastAPI:** press `Ctrl+C` in the "EcoXchange AI service" window, then close it.
4. **Laravel:** Laragon → **Stop All** (optional; it can keep running).

No `artisan serve` is used, so there is nothing else to stop.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `[FAIL] Paths: Laravel not found …` / `AI service not found …` | The Laravel project is not at the default location. Set `ECOXCHANGE_LARAVEL_DIR` to the folder that contains `artisan` and `ai_service\`. |
| `[FAIL] Paths: Python not found …` | Set `ECOXCHANGE_PYTHON` to the `python.exe` of the environment that has the AI service's requirements. |
| `[FAIL] Laragon: … not found` | Apache/MySQL are not running and Laragon is not at the default location. Start Laragon yourself, or set `LARAGON_EXE`. |
| `[FAIL] Paths: no pubspec.yaml next to this script` | The launcher was copied out of the Flutter project. Run it from the project root. |
| App shows "The AI classification service is currently unavailable. Please try again shortly." (HTTP 503, `AI_SERVICE_UNAVAILABLE`) | The AI service is not running or still loading the model. Check `curl http://127.0.0.1:8001/health`, then start it (see above) or read the error in its window. Laravel uses `http://127.0.0.1:8001` by default (`config/services.php`). |
| `[FAIL] AI service: port 8001 is in use but /health is not OK` | Another program holds 8001. Find it with `netstat -ano \| findstr :8001`, end that PID (`taskkill /PID <pid> /F`) if it is a stale uvicorn, and re-run. |
| `adb devices` shows `authorizing` forever | `%USERPROFILE%\.android\adbkey.pub` is missing, so the emulator cannot trust adb. Fix: `adb pubkey %USERPROFILE%\.android\adbkey > %USERPROFILE%\.android\adbkey.pub`, then `adb kill-server`, and cold-boot the emulator. The launcher does this automatically. |
| Emulator shows `offline`, never registers with adb, or hangs at start | On the development machine the AVD's quick-boot snapshot was unreliable. Cold-boot with `-no-snapshot-load` (the launcher always does). If a device is stuck `offline`, `adb reconnect offline` often recovers it. If an emulator will not start at all, close every emulator window or end `qemu-system-x86_64.exe` and try again. |
| `flutter devices` / `flutter run` cannot find the emulator | Wait for `adb devices` to show `device` and `sys.boot_completed` = `1`, then run `flutter run -d emulator-5554`. If the serial differs, use the one `adb devices` shows. |
| App cannot reach the backend (connection error) from the emulator | Check Laragon is running and `http://ecoxchange.test/` returns 200 on the PC. From the emulator: `adb shell "printf 'GET /api/v1/customer/items HTTP/1.1\r\nHost: ecoxchange.test\r\nConnection: close\r\n\r\n' \| nc -w 5 10.0.2.2 80 \| head -1"` should print `HTTP/1.1 401`. If it doesn't, Apache is not listening on port 80 or a firewall is blocking it. |
| Laragon virtual host unavailable (`ecoxchange.test` does not resolve, or you get the wrong site) | Laragon → Menu → Apache → reload, or Stop All / Start All. Laragon auto-creates `sites-enabled\auto.Ecoxchange.test.conf` and the hosts entry. |
| `php artisan` fails with `could not find driver` | That PHP CLI build lacks `pdo_mysql`. Use a PHP CLI build that has it (example machine: `C:\laragon\bin\php\php-8.3.30-Win32-vs16-x64\php.exe artisan ...`). |
| App opens straight to the dashboard (no login screen) | A saved login token is still valid in the emulator's secure storage. Use the logout icon on the dashboard to see the login screen. |
| Script waits end instantly / "Input redirection is not supported" | Only when the script's input is redirected (e.g. run from another tool). The script uses a `ping`-based wait for this reason; run it normally from Explorer or `cmd`. |
| Gradle downloads fail with PKIX / certificate errors (e.g. antivirus HTTPS interception) | Configure a trust store for that machine in `~/.gradle/gradle.properties` (`javax.net.ssl.trustStore` / `trustStorePassword`), not in the project's `android/gradle.properties`. |
