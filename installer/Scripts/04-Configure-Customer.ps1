# ============================================================================
# Apply Customer Configuration to All Config Files
# ----------------------------------------------------------------------------
# Reads customer-config.ini (written by Inno Setup installer wizard) and
# applies the values to:
#   - drone-api/config.json
#   - bin/mediamtx/mediamtx.yml
# Also generates an API key if not provided.
# ============================================================================

param(
    [string]$InstallPath = "C:\DroneServer"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

function New-RandomApiKey {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return [Convert]::ToBase64String($bytes).Replace("/", "_").Replace("+", "-").Replace("=", "").Substring(0, 32)
}

function Read-IniValue {
    param([string]$Path, [string]$Section, [string]$Key)
    if (-not (Test-Path $Path)) { return $null }
    
    $inSection = $false
    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()
        if ($line -match "^\[(.+)\]$") {
            $inSection = ($matches[1] -eq $Section)
            continue
        }
        if ($inSection -and $line -match "^$([regex]::Escape($Key))=(.*)$") {
            return $matches[1].Trim()
        }
    }
    return $null
}

function Save-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding $false))
}

# Read installer values
$configIni = Join-Path $InstallPath "customer-config.ini"
Write-Log "Reading customer config from $configIni"

$customerName = Read-IniValue $configIni "Customer" "Name"
$serverIP = Read-IniValue $configIni "Customer" "ServerIP"
$lanSubnet = Read-IniValue $configIni "Customer" "LANSubnet"
$apiKey = Read-IniValue $configIni "Customer" "APIKey"
$baseLat = Read-IniValue $configIni "Drone" "BaseLat"
$baseLon = Read-IniValue $configIni "Drone" "BaseLon"
$geofenceRadius = Read-IniValue $configIni "Drone" "GeofenceRadius"

# Generate API key if blank
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = New-RandomApiKey
    Write-Log "Generated new API key"
}

# Default geofence if blank
if ([string]::IsNullOrWhiteSpace($geofenceRadius)) {
    $geofenceRadius = "500"
}

# Validate critical values
if ([string]::IsNullOrWhiteSpace($serverIP)) {
    Write-Log "Server IP is empty - using 0.0.0.0 (bind all)" "WARN"
    $serverIP = "0.0.0.0"
}

Write-Log "Customer: $customerName"
Write-Log "Server IP: $serverIP"
Write-Log "API key: $($apiKey.Substring(0,8))..."
Write-Log "Base coords: $baseLat, $baseLon"
Write-Log "Geofence: $geofenceRadius m"

# ----- Write drone-api/config.json -----
$apiConfigPath = Join-Path $InstallPath "drone-api\config.json"
$adbPath = Join-Path $InstallPath "bin\platform-tools\adb.exe"
$adbPathEscaped = $adbPath.Replace("\", "\\")

$baseLatNum = if ($baseLat) { $baseLat } else { "0.0" }
$baseLonNum = if ($baseLon) { $baseLon } else { "0.0" }

$apiConfig = @"
{
  "apiKey": "$apiKey",
  "adbPath": "$adbPathEscaped",
  "port": 3000,
  "bindAddress": "0.0.0.0",
  "adbTimeoutMs": 8000,
  "flyToConfig": {
    "baseLat": $baseLatNum,
    "baseLon": $baseLonNum,
    "maxRangeMeters": $geofenceRadius,
    "droneSpeedMps": 10,
    "startupOverheadSec": 10,
    "requireAccuracyMeters": 50
  }
}
"@

Save-Utf8NoBom -Path $apiConfigPath -Content $apiConfig
Write-Log "Wrote $apiConfigPath"

# ----- Write mediamtx.yml -----
$mediamtxPath = Join-Path $InstallPath "bin\mediamtx\mediamtx.yml"
$mediamtxConfig = @"
rtspAddress: :8554
hlsAddress: :8888
hlsAllowOrigins: ['*']
hlsAlwaysRemux: yes
webrtcAddress: :8889
webrtcAllowOrigins: ['*']
webrtcLocalUDPAddress: :8189
webrtcICEServers2: []
webrtcAdditionalHosts: ['$serverIP']
api: yes
apiAddress: :9997
paths:
  standard_clean:
    source: publisher
"@

Save-Utf8NoBom -Path $mediamtxPath -Content $mediamtxConfig
Write-Log "Wrote $mediamtxPath"

# ----- Save credentials summary for tech reference -----
$credsPath = Join-Path $InstallPath "INSTALL-INFO.txt"
$credsInfo = @"
=============================================================
DJI Drone Server - Customer Installation Info
=============================================================

Customer:       $customerName
Server IP:      $serverIP
LAN Subnet:     $lanSubnet
Install Date:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Drone Base GPS: $baseLat, $baseLon
Geofence:       $geofenceRadius meters

API Key (give to Control4 driver):
$apiKey

API Endpoint:   http://$serverIP:3000
Video Stream:   ws://$serverIP:8091
HLS Stream:     http://$serverIP:8888/standard_clean/index.m3u8
RTSP Stream:    rtsp://$serverIP:8554/standard_clean
WebRTC Stream:  http://$serverIP:8889/standard_clean/whep

=============================================================
KEEP THIS FILE SECURE - contains the API key
=============================================================
"@

Save-Utf8NoBom -Path $credsPath -Content $credsInfo
Write-Log "Wrote install info to $credsPath"

Write-Log "Customer configuration complete" "OK"
