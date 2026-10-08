# =============================================================================
# setup-flow-pilot.ps1 - IBM API Connect Flow Pilot Automated Setup (Windows)
# =============================================================================
# Features:
#   - Automatic or interactive target detection
#   - Reads / writes flow-pilot.properties
#   - Generates $env:USERPROFILE\.bob\mcp.json (5 MCP servers)
#   - Installs 10 Flow Pilot skills globally
#
# Usage:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#   .\setup-flow-pilot.ps1
#
# See README.md for full documentation.
# =============================================================================

$ErrorActionPreference = "Stop"

function Write-Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Clear-Host
Write-Host "========================================================================" -ForegroundColor Blue
Write-Host "        IBM API Connect Flow Pilot - Setup Assistant                    " -ForegroundColor Blue
Write-Host "        Platform: Windows PowerShell                                    " -ForegroundColor Blue
Write-Host "========================================================================" -ForegroundColor Blue

# ── Path resolution ───────────────────────────────────────────────────────────
$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WorkspaceRoot  = $ScriptDir
$KitDir         = Join-Path $WorkspaceRoot "resources\ibm-apic-flow-pilot-kit"
$McpDir         = Join-Path $KitDir "mcp-servers"
$BobConfigDir   = Join-Path $env:USERPROFILE ".bob"
$BobMcpJson     = Join-Path $BobConfigDir "mcp.json"
$PropFile       = Join-Path $WorkspaceRoot "flow-pilot.properties"

# =============================================================================
# PHASE 1: System Prerequisites
# =============================================================================
Write-Host "`n=== [1/4] Checking System Prerequisites ===" -ForegroundColor Magenta

if (Get-Command node -ErrorAction SilentlyContinue) {
    $NodeVer   = (node -v).TrimStart('v')
    $NodeMajor = [int]($NodeVer.Split('.')[0])
    if ($NodeMajor -ge 24) {
        Write-Success "Node.js v$NodeVer detected (>= 24 required)."
    } else {
        Write-Warn "Node.js v$NodeVer detected. Flow Pilot requires Node.js >= 24."
    }
} else {
    Write-Err "Node.js is not installed. Install Node.js 24 LTS from https://nodejs.org"
    exit 1
}

Write-Info "Checking APIC Studio CLI (@apistudio/apim-cli)..."
if (-not (Get-Command apic -ErrorAction SilentlyContinue)) {
    Write-Info "Installing @apistudio/apim-cli@latest..."
    npm install -g @apistudio/apim-cli@latest
    Write-Success "apic CLI installed."
} else {
    Write-Success "apic CLI operational."
}

if (-not (Test-Path $McpDir)) {
    Write-Err "MCP servers folder not found: $McpDir"
    Write-Err "Have you extracted the IBM_API_Connect_Flow_Pilot kit into resources/ibm-apic-flow-pilot-kit/? See README.md Step 1."
    exit 1
}
Write-Success "Local IBM API Connect Flow Pilot kit validated."

# =============================================================================
# PHASE 2: Target Discovery
# =============================================================================
Write-Host "`n=== [2/4] Target Discovery ===" -ForegroundColor Magenta

$DeploymentMode          = "auto"
$OpenShiftApiUrl         = ""
$OpenShiftToken          = ""
$OpenShiftNamespace      = "apic"
$OpenShiftMgmtUrl        = ""
$OpenShiftPlatformUrl    = ""
$SaasRegion              = ""
$SaasMgmtUrl             = ""
$SaasPlatformUrl         = ""
$ProviderOrg             = ""
$ClientId                = ""
$ClientSecret            = ""
$ApiKey                  = ""
$NodeTlsRejectUnauthorized = ""

if (Test-Path $PropFile) {
    Get-Content $PropFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split('=', 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim()
            if ($v -ne "") {
                switch ($k) {
                    "DEPLOYMENT_MODE"              { $DeploymentMode = $v }
                    "OPENSHIFT_API_URL"            { $OpenShiftApiUrl = $v }
                    "OPENSHIFT_TOKEN"              { $OpenShiftToken = $v }
                    "OPENSHIFT_NAMESPACE"          { $OpenShiftNamespace = $v }
                    "OPENSHIFT_MGMT_URL"           { $OpenShiftMgmtUrl = $v }
                    "OPENSHIFT_PLATFORM_URL"       { $OpenShiftPlatformUrl = $v }
                    "SAAS_REGION"                  { $SaasRegion = $v }
                    "SAAS_MGMT_URL"                { $SaasMgmtUrl = $v }
                    "SAAS_PLATFORM_URL"            { $SaasPlatformUrl = $v }
                    "PROVIDER_ORG"                 { $ProviderOrg = $v }
                    "CLIENT_ID"                    { $ClientId = $v }
                    "CLIENT_SECRET"                { $ClientSecret = $v }
                    "API_KEY"                      { $ApiKey = $v }
                    "NODE_TLS_REJECT_UNAUTHORIZED" { $NodeTlsRejectUnauthorized = $v }
                }
            }
        }
    }
}

$ResolvedMgmtUrl     = ""
$ResolvedPlatformUrl = ""
$DeterminedMode      = ""

if ($DeploymentMode -eq "openshift" -or ($DeploymentMode -eq "auto" -and ($OpenShiftMgmtUrl -ne "" -or $OpenShiftApiUrl -ne ""))) {
    $DeterminedMode = "OpenShift"
    Write-Info "Target: Red Hat OpenShift / TechZone"
    if ($OpenShiftMgmtUrl -ne "")     { $ResolvedMgmtUrl = $OpenShiftMgmtUrl }
    if ($OpenShiftPlatformUrl -ne "") { $ResolvedPlatformUrl = $OpenShiftPlatformUrl }
    if ($NodeTlsRejectUnauthorized -eq "") { $NodeTlsRejectUnauthorized = "0" }
} elseif ($DeploymentMode -eq "saas" -or ($DeploymentMode -eq "auto" -and ($SaasRegion -ne "" -or $SaasMgmtUrl -ne ""))) {
    $DeterminedMode = "SaaS"
    Write-Info "Target: IBM API Connect SaaS"
    switch ($SaasRegion) {
        "us-east-1"      { $ResolvedMgmtUrl = "https://api-manager.us-east-a.apiconnect.automation.ibm.com";      $ResolvedPlatformUrl = "https://platform-api.us-east-a.apiconnect.automation.ibm.com" }
        "eu-central-1"   { $ResolvedMgmtUrl = "https://api-manager.eu-central-a.apiconnect.automation.ibm.com";   $ResolvedPlatformUrl = "https://platform-api.eu-central-a.apiconnect.automation.ibm.com" }
        "eu-west-2"      { $ResolvedMgmtUrl = "https://api-manager.eu-west-a.apiconnect.automation.ibm.com";      $ResolvedPlatformUrl = "https://platform-api.eu-west-a.apiconnect.automation.ibm.com" }
        "ap-south-1"     { $ResolvedMgmtUrl = "https://api-manager.ap-south-a.apiconnect.automation.ibm.com";     $ResolvedPlatformUrl = "https://platform-api.ap-south-a.apiconnect.automation.ibm.com" }
        "ap-southeast-2" { $ResolvedMgmtUrl = "https://api-manager.ap-southeast-a.apiconnect.automation.ibm.com"; $ResolvedPlatformUrl = "https://platform-api.ap-southeast-a.apiconnect.automation.ibm.com" }
    }
    if ($SaasMgmtUrl -ne "")     { $ResolvedMgmtUrl = $SaasMgmtUrl }
    if ($SaasPlatformUrl -ne "") { $ResolvedPlatformUrl = $SaasPlatformUrl }
    if ($NodeTlsRejectUnauthorized -eq "") { $NodeTlsRejectUnauthorized = "1" }
}

if ($ResolvedMgmtUrl -eq "" -or $ResolvedPlatformUrl -eq "") {
    Write-Warn "Could not determine APIC URLs automatically."
    $Choice = Read-Host "Select target [1: OpenShift/TechZone, 2: SaaS]"
    if ($Choice -eq "1") {
        $DeterminedMode = "OpenShift"
        if ($NodeTlsRejectUnauthorized -eq "") { $NodeTlsRejectUnauthorized = "0" }
    } else {
        $DeterminedMode = "SaaS"
        if ($NodeTlsRejectUnauthorized -eq "") { $NodeTlsRejectUnauthorized = "1" }
    }
    while ($ResolvedMgmtUrl -eq "")     { $ResolvedMgmtUrl     = Read-Host "APIC Management URL (e.g. https://manager.apps.<cluster>)" }
    while ($ResolvedPlatformUrl -eq "") { $ResolvedPlatformUrl = Read-Host "APIC Platform API URL (e.g. https://api.apps.<cluster>)" }
}

Write-Success "Mode:                $DeterminedMode"
Write-Success "APIC Management URL: $ResolvedMgmtUrl"
Write-Success "APIC Platform URL:   $ResolvedPlatformUrl"

# =============================================================================
# PHASE 3: Credentials
# =============================================================================
Write-Host "`n=== [3/4] Credentials ===" -ForegroundColor Magenta

if ($ProviderOrg -eq "") { $ProviderOrg = Read-Host "Provider Organization (e.g. demo-org)" }
if ($ClientId -eq "") {
    Write-Host "Tip: Download Tools > Toolkit > Toolkit credentials > credentials.json > toolkit.client_id" -ForegroundColor Cyan
    $ClientId = Read-Host "Toolkit Client ID"
}
if ($ClientSecret -eq "") {
    $Sec   = Read-Host -AsSecureString "Toolkit Client Secret"
    $BSTR  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Sec)
    $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}
if ($ApiKey -eq "") {
    Write-Host "Tip: Profile icon > My API Keys > Add > Enable multiple use" -ForegroundColor Yellow
    $SecKey  = Read-Host -AsSecureString "API Key"
    $BSTRKey = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecKey)
    $ApiKey  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRKey)
}

Write-Info "Saving credentials to '$PropFile'..."
@"
# flow-pilot.properties — Auto-updated by setup-flow-pilot.ps1 on $(Get-Date)

DEPLOYMENT_MODE=$DeploymentMode
OPENSHIFT_API_URL=$OpenShiftApiUrl
OPENSHIFT_TOKEN=$OpenShiftToken
OPENSHIFT_NAMESPACE=$OpenShiftNamespace
OPENSHIFT_MGMT_URL=$ResolvedMgmtUrl
OPENSHIFT_PLATFORM_URL=$ResolvedPlatformUrl
SAAS_REGION=$SaasRegion
SAAS_MGMT_URL=$SaasMgmtUrl
SAAS_PLATFORM_URL=$SaasPlatformUrl
PROVIDER_ORG=$ProviderOrg
CLIENT_ID=$ClientId
CLIENT_SECRET=$ClientSecret
API_KEY=$ApiKey
NODE_TLS_REJECT_UNAUTHORIZED=$NodeTlsRejectUnauthorized
"@ | Out-File -FilePath $PropFile -Encoding utf8
Write-Success "flow-pilot.properties saved."

# =============================================================================
# PHASE 4: MCP Registration & Skills Installation
# =============================================================================
Write-Host "`n=== [4/4] MCP Registration & Skills Installation ===" -ForegroundColor Magenta

if (-not (Test-Path $BobConfigDir)) { New-Item -ItemType Directory -Path $BobConfigDir | Out-Null }

$McpContent = @{
    mcpServers = @{
        "apic-management-mcp-server" = @{
            command = "npx"
            args    = @("-y", "-p", "$McpDir\management\apic-management-mcp-server-0.0.1.tgz", "apic-management-mcp-server")
            env     = @{ NODE_TLS_REJECT_UNAUTHORIZED=$NodeTlsRejectUnauthorized; PROVIDER_ORG=$ProviderOrg; API_KEY=$ApiKey; client_id=$ClientId; client_secret=$ClientSecret; APIC_PLATFORM_URL=$ResolvedPlatformUrl; APIC_MANAGEMENT_URL=$ResolvedMgmtUrl }
        }
        "apic-analytics-mcp-server" = @{
            command = "npx"
            args    = @("-y", "-p", "$McpDir\analytics\apic-analytics-mcp-server-0.0.1.tgz", "apic-analytics-mcp-server")
            env     = @{ NODE_TLS_REJECT_UNAUTHORIZED=$NodeTlsRejectUnauthorized; PROVIDER_ORG=$ProviderOrg; API_KEY=$ApiKey; client_id=$ClientId; client_secret=$ClientSecret; APIC_PLATFORM_URL=$ResolvedPlatformUrl; APIC_MANAGEMENT_URL=$ResolvedMgmtUrl }
        }
        "apic-governance-mcp-server" = @{
            command = "npx"
            args    = @("-y", "-p", "$McpDir\governance\apic-governance-mcp-server-0.0.1.tgz", "apic-governance-mcp-server")
            env     = @{ NODE_TLS_REJECT_UNAUTHORIZED=$NodeTlsRejectUnauthorized; PROVIDER_ORG=$ProviderOrg; API_KEY=$ApiKey; client_id=$ClientId; client_secret=$ClientSecret; APIC_PLATFORM_URL=$ResolvedPlatformUrl; APIC_MANAGEMENT_URL=$ResolvedMgmtUrl }
        }
        "apic-genai-spec-mcp-server" = @{
            command = "npx"
            args    = @("-y", "-p", "$McpDir\genai-spec\apic-genai-spec-mcp-server-0.0.1.tgz", "apic-genai-spec-mcp-server")
            env     = @{ NODE_TLS_REJECT_UNAUTHORIZED=$NodeTlsRejectUnauthorized; PROVIDER_ORG=$ProviderOrg; API_KEY=$ApiKey; client_id=$ClientId; client_secret=$ClientSecret; APIC_PLATFORM_URL=$ResolvedPlatformUrl; APIC_MANAGEMENT_URL=$ResolvedMgmtUrl }
        }
        "ai-gateway-management-mcp-server" = @{
            command = "npx"
            args    = @("-y", "-p", "$McpDir\ai-gateway-management\ai-gateway-management-mcp-server-0.0.1.tgz", "ai-gateway-management-mcp-server")
            env     = @{ NODE_TLS_REJECT_UNAUTHORIZED=$NodeTlsRejectUnauthorized; PROVIDER_ORG=$ProviderOrg; API_KEY=$ApiKey; client_id=$ClientId; client_secret=$ClientSecret; APIC_PLATFORM_URL=$ResolvedPlatformUrl; APIC_MANAGEMENT_URL=$ResolvedMgmtUrl }
        }
    }
}

$McpContent | ConvertTo-Json -Depth 5 | Out-File -FilePath $BobMcpJson -Encoding utf8
Write-Success "MCP config generated: $BobMcpJson"

Write-Info "Installing Flow Pilot skills..."
Push-Location $KitDir
try { npx skills add . -g 2>$null } catch {}
Pop-Location
Write-Success "Skills installed."

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host "  OK  SETUP COMPLETE ON WINDOWS!" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Credentials saved to : $PropFile"
Write-Host "  MCP config written to : $BobMcpJson"
Write-Host ""
Write-Host "  -> Restart IBM Bob (or your AI agent) to load the MCP servers."
Write-Host "  -> Then type: /setup-agent-kit"
Write-Host ""
