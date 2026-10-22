<#
.SYNOPSIS
    One-command launcher for EcoXchange Mobile: detects this laptop's
    current LAN IPv4 address and runs `flutter run` with
    --dart-define=API_BASE_URL set to it, so the installed app can reach
    the Laravel backend over Wi-Fi without hand-editing the dev command
    every time the laptop joins a different network.

.DESCRIPTION
    Goal B of the "Automatic API IP Detection" work: the laptop's IP
    changes every time it switches Wi-Fi networks, so the previous fixed
    command
        flutter run -d 81a73b47 --dart-define=API_BASE_URL=http://10.82.144.176
    goes stale. This script re-detects the IP every time it runs instead.

    It does NOT change Laragon, Apache, MySQL, or any project configuration
    -- it only detects an address and constructs the flutter command.

.PARAMETER DeviceId
    The target Android device ID, as reported by `flutter devices`.
    Defaults to 81a73b47 (this project's usual test device).

.PARAMETER Port
    Optional backend port, if the Laravel server isn't on the default
    port 80 (e.g. 8000 for `php artisan serve`). Omit this for the normal
    Laragon/Apache setup.

.EXAMPLE
    .\run_ecoxchange.ps1

.EXAMPLE
    .\run_ecoxchange.ps1 -DeviceId 81a73b47

.EXAMPLE
    .\run_ecoxchange.ps1 -Port 8000

.NOTES
    The IP is detected ONCE, when this script starts. If you switch Wi-Fi
    networks while `flutter run` from this script is still running, the
    already-running app keeps using the OLD address -- stop it (q) and
    re-run this script to pick up the new one. This script does not watch
    for network changes while Flutter is running.
#>

[CmdletBinding()]
param(
    [string]$DeviceId = '81a73b47',
    [int]$Port
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message, [string]$Color = 'Cyan')
    Write-Host $Message -ForegroundColor $Color
}

function Get-EcoXchangeLanIPv4 {
    <#
        Prefers an active Wi-Fi adapter's IPv4 address over blindly
        picking the first one Windows reports -- a laptop commonly also
        has a virtual Ethernet/VPN/Hyper-V/vEthernet adapter with its own
        IPv4 address that is NOT the one the phone can actually reach.
    #>
    $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike '169.254.*' -and
            $_.IPAddress -ne '127.0.0.1' -and
            $_.PrefixOrigin -ne 'WellKnown'
        }

    if (-not $candidates) {
        return $null
    }

    $wifiNameHints = @('Wi-Fi', 'WiFi', 'Wireless', 'WLAN')

    # Pass 1: an UP adapter whose name/description looks like Wi-Fi.
    foreach ($candidate in $candidates) {
        $adapter = Get-NetAdapter -InterfaceIndex $candidate.InterfaceIndex -ErrorAction SilentlyContinue
        if (-not $adapter -or $adapter.Status -ne 'Up') {
            continue
        }
        foreach ($hint in $wifiNameHints) {
            if ($adapter.Name -like "*$hint*" -or $adapter.InterfaceDescription -like "*$hint*") {
                return [PSCustomObject]@{ IPAddress = $candidate.IPAddress; AdapterName = $adapter.Name }
            }
        }
    }

    # Pass 2: no Wi-Fi match -- fall back to any other UP, non-virtual
    # adapter with a usable IPv4 address (e.g. wired Ethernet).
    foreach ($candidate in $candidates) {
        $adapter = Get-NetAdapter -InterfaceIndex $candidate.InterfaceIndex -ErrorAction SilentlyContinue
        if ($adapter -and $adapter.Status -eq 'Up' -and -not $adapter.Virtual) {
            return [PSCustomObject]@{ IPAddress = $candidate.IPAddress; AdapterName = $adapter.Name }
        }
    }

    return $null
}

# ── 1-3. Detect and validate the LAN IPv4 address ───────────────────────
$lan = Get-EcoXchangeLanIPv4
if (-not $lan) {
    Write-Error @"
Could not detect a usable local network IPv4 address.

Likely causes:
  - Wi-Fi is not connected (check the Windows network icon).
  - Only a virtual/VPN adapter is currently up.

Connect to Wi-Fi and try again.
"@
    exit 1
}

# ── 4. Detect/validate the target Android device ────────────────────────
Write-Step "Checking for Android device '$DeviceId'..."
$devicesOutput = & flutter devices 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "`flutter devices` failed to run. Is Flutter installed and on PATH?`n$devicesOutput"
    exit 1
}
if (($devicesOutput | Out-String) -notmatch [regex]::Escape($DeviceId)) {
    Write-Error @"
Android device '$DeviceId' was not found by 'flutter devices'.

Likely causes:
  - The phone is not connected via USB (or Wi-Fi debugging is off).
  - USB debugging is not enabled on the phone.
  - The device ID changed -- run 'flutter devices' to see the current one,
    then pass it with -DeviceId <id>.
"@
    exit 1
}

# ── 5-6. Construct the API URL and run Flutter ──────────────────────────
$portSuffix = if ($Port) { ":$Port" } else { '' }
$apiBaseUrl = "http://$($lan.IPAddress)$portSuffix"

# ── 7. Print what was detected ───────────────────────────────────────────
Write-Step ''
Write-Step '=== EcoXchange Mobile launcher ===' 'Green'
Write-Step "Network adapter:    $($lan.AdapterName)"
Write-Step "Detected local IP:  $($lan.IPAddress)"
Write-Step "Effective API URL:  $apiBaseUrl"
Write-Step "Target device:      $DeviceId"
Write-Step ''
Write-Host 'NOTE: switching Wi-Fi networks while this keeps running will NOT update the address automatically.' -ForegroundColor Yellow
Write-Host '      Stop Flutter (q) and re-run this script after switching networks.' -ForegroundColor Yellow
Write-Step ''

& flutter run -d $DeviceId "--dart-define=API_BASE_URL=$apiBaseUrl"
exit $LASTEXITCODE
