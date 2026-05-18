# ============================================================================
# Configure Firewall Rules for DJI Drone Server
# ----------------------------------------------------------------------------
# Opens inbound TCP/UDP ports required by the server stack, scoped to the
# customer's LAN subnet. Reads the subnet from customer-config.ini.
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

# Read customer subnet
$configPath = Join-Path $InstallPath "customer-config.ini"
if (-not (Test-Path $configPath)) {
    Write-Log "Customer config not found at $configPath, using default subnet 10.0.0.0/16" "WARN"
    $subnet = "10.0.0.0/16"
} else {
    $content = Get-Content $configPath -Raw
    if ($content -match "LANSubnet=(.+)") {
        $subnet = $matches[1].Trim()
    } else {
        $subnet = "10.0.0.0/16"
    }
}

Write-Log "Configuring firewall for subnet: $subnet"

# Rules to create
$rules = @(
    @{ Name = "DroneAPI"; Protocol = "TCP"; Port = 3000; Description = "Drone Command API" }
    @{ Name = "MediaMTX RTSP"; Protocol = "TCP"; Port = 8554; Description = "RTSP stream" }
    @{ Name = "MediaMTX HLS"; Protocol = "TCP"; Port = 8888; Description = "HLS stream" }
    @{ Name = "MediaMTX WebRTC"; Protocol = "TCP"; Port = 8889; Description = "WebRTC stream" }
    @{ Name = "MediaMTX WebRTC UDP"; Protocol = "UDP"; Port = 8189; Description = "WebRTC media" }
    @{ Name = "WebSocket MJPEG"; Protocol = "TCP"; Port = 8091; Description = "WebSocket video for iOS" }
)

foreach ($rule in $rules) {
    $displayName = "DroneServer - $($rule.Name)"
    
    # Remove existing rule if present
    Get-NetFirewallRule -DisplayName $displayName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    
    # Create new rule
    New-NetFirewallRule `
        -DisplayName $displayName `
        -Description $rule.Description `
        -Direction Inbound `
        -Protocol $rule.Protocol `
        -LocalPort $rule.Port `
        -RemoteAddress $subnet `
        -Action Allow | Out-Null
    
    Write-Log "Created rule: $displayName (${rule.Protocol}/${rule.Port})"
}

Write-Log "Firewall configuration complete" "OK"
