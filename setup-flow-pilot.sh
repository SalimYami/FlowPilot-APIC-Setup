#!/usr/bin/env bash
# =============================================================================
# setup-flow-pilot.sh - IBM API Connect Flow Pilot Automated Setup
# =============================================================================
# Platforms : macOS (ARM / Intel), Ubuntu / Debian / RHEL / CentOS
# Features  :
#   - Automatic or interactive target detection
#   - Bi-directional sync with flow-pilot.properties
#   - Generates ~/.bob/mcp.json (5 APIC Flow Pilot MCP servers)
#   - OpenShift / TechZone auto-discovery via oc get route
#   - Installs 10 Flow Pilot skills globally
#
# Usage:
#   chmod +x setup-flow-pilot.sh
#   ./setup-flow-pilot.sh
#
# See README.md for full documentation.
# =============================================================================

set -euo pipefail

# ── Colours and helpers ───────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── OS detection ──────────────────────────────────────────────────────────────
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Darwin*) PLATFORM="macOS" ;;
    Linux*)  PLATFORM="Linux" ;;
    *)       PLATFORM="Unix" ;;
esac

# ── Path resolution ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${SCRIPT_DIR}"
KIT_DIR="${WORKSPACE_ROOT}/DonneesDipo/IBM_API_Connect_Flow_Pilot-12.1.1.2.4"
MCP_DIR="${KIT_DIR}/mcp-servers"
BOB_CONFIG_DIR="${HOME}/.bob"
BOB_MCP_JSON="${BOB_CONFIG_DIR}/mcp.json"
PROP_FILE="${WORKSPACE_ROOT}/flow-pilot.properties"

clear 2>/dev/null || true
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║          IBM API Connect Flow Pilot — Setup Assistant                  ║"
echo "║          Platform: ${PLATFORM}                                               ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# =============================================================================
# PHASE 1: System Prerequisites
# =============================================================================
echo -e "\n${BOLD}${PURPLE}=== [1/4] Checking System Prerequisites ===${RESET}"

# Node.js >= 24
if command -v node >/dev/null 2>&1; then
    NODE_VER=$(node -v | tr -d 'v')
    NODE_MAJOR=$(echo "$NODE_VER" | cut -d'.' -f1)
    if [[ "$NODE_MAJOR" -ge 24 ]]; then
        success "Node.js v${NODE_VER} detected (>= 24 required)."
    else
        warn "Node.js v${NODE_VER} detected. Flow Pilot requires Node.js >= 24. Some features may not work."
    fi
else
    die "Node.js is not installed. Install Node.js 24 LTS from https://nodejs.org"
fi

# apic CLI (@apistudio/apim-cli)
info "Checking APIC Studio CLI (@apistudio/apim-cli)..."
if ! command -v apic >/dev/null 2>&1 || ! apic schema list >/dev/null 2>&1; then
    info "Installing @apistudio/apim-cli@latest..."
    if [[ "$PLATFORM" == "Linux" ]] && [[ "$EUID" -ne 0 ]]; then
        sudo npm install -g @apistudio/apim-cli@latest || npm install -g @apistudio/apim-cli@latest
    else
        npm install -g @apistudio/apim-cli@latest
    fi
    success "apic CLI installed."
else
    success "apic CLI operational."
fi

# OpenShift CLI (optional)
if command -v oc >/dev/null 2>&1; then
    success "OpenShift CLI (oc) detected."
    if oc whoami >/dev/null 2>&1; then
        CURRENT_USER=$(oc whoami 2>/dev/null || echo "connected")
        CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null || echo "active")
        success "Active OpenShift session: ${CURRENT_USER} @ ${CURRENT_SERVER}"
    else
        info "oc present but no active session."
    fi
else
    warn "oc CLI not found in PATH — OpenShift auto-discovery will be skipped."
fi

# Validate local Flow Pilot kit
[[ -d "$MCP_DIR" ]] || die "MCP servers folder not found: $MCP_DIR\nHave you extracted the IBM_API_Connect_Flow_Pilot kit into DonneesDipo/?\nSee README.md Step 1."
success "Local IBM API Connect Flow Pilot kit validated."

# =============================================================================
# PHASE 2: Target Discovery
# =============================================================================
echo -e "\n${BOLD}${PURPLE}=== [2/4] Target Discovery ===${RESET}"

DEPLOYMENT_MODE="auto"
OPENSHIFT_API_URL=""
OPENSHIFT_TOKEN=""
OPENSHIFT_NAMESPACE="apic"
OPENSHIFT_MGMT_URL=""
OPENSHIFT_PLATFORM_URL=""
SAAS_REGION=""
SAAS_MGMT_URL=""
SAAS_PLATFORM_URL=""
PROVIDER_ORG=""
CLIENT_ID=""
CLIENT_SECRET=""
API_KEY=""
NODE_TLS_REJECT_UNAUTHORIZED=""

# Read properties file if present
if [[ -f "$PROP_FILE" ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | tr -d '\r' | xargs)
        value=$(echo "$value" | tr -d '\r' | xargs)
        [[ -z "$value" ]] && continue
        case "$key" in
            DEPLOYMENT_MODE)              DEPLOYMENT_MODE="$value" ;;
            OPENSHIFT_API_URL)            OPENSHIFT_API_URL="$value" ;;
            OPENSHIFT_TOKEN)              OPENSHIFT_TOKEN="$value" ;;
            OPENSHIFT_NAMESPACE)          OPENSHIFT_NAMESPACE="$value" ;;
            OPENSHIFT_MGMT_URL)           OPENSHIFT_MGMT_URL="$value" ;;
            OPENSHIFT_PLATFORM_URL)       OPENSHIFT_PLATFORM_URL="$value" ;;
            SAAS_REGION)                  SAAS_REGION="$value" ;;
            SAAS_MGMT_URL)                SAAS_MGMT_URL="$value" ;;
            SAAS_PLATFORM_URL)            SAAS_PLATFORM_URL="$value" ;;
            PROVIDER_ORG)                 PROVIDER_ORG="$value" ;;
            CLIENT_ID)                    CLIENT_ID="$value" ;;
            CLIENT_SECRET)                CLIENT_SECRET="$value" ;;
            API_KEY)                      API_KEY="$value" ;;
            NODE_TLS_REJECT_UNAUTHORIZED) NODE_TLS_REJECT_UNAUTHORIZED="$value" ;;
        esac
    done < "$PROP_FILE"
fi

RESOLVED_MGMT_URL=""
RESOLVED_PLATFORM_URL=""
DETERMINED_MODE=""

# OpenShift / TechZone detection
if [[ "$DEPLOYMENT_MODE" == "openshift" ]] || \
   { [[ "$DEPLOYMENT_MODE" == "auto" ]] && \
     { [[ -n "$OPENSHIFT_MGMT_URL" ]] || [[ -n "$OPENSHIFT_API_URL" ]] || command -v oc >/dev/null 2>&1; }; }; then

    DETERMINED_MODE="OpenShift"
    info "Target: Red Hat OpenShift / TechZone"

    [[ -n "$OPENSHIFT_MGMT_URL" ]]     && RESOLVED_MGMT_URL="$OPENSHIFT_MGMT_URL"
    [[ -n "$OPENSHIFT_PLATFORM_URL" ]] && RESOLVED_PLATFORM_URL="$OPENSHIFT_PLATFORM_URL"

    # Auto-login if token + server provided
    if [[ -n "$OPENSHIFT_API_URL" ]] && [[ -n "$OPENSHIFT_TOKEN" ]] && command -v oc >/dev/null 2>&1; then
        info "Attempting automatic oc login..."
        CLEAN_TOKEN=$(echo "$OPENSHIFT_TOKEN" | sed -E 's/.*--token[ ="]*([^" ]+).*/\1/' | tr -d '<>' | xargs)
        CLEAN_SERVER=$(echo "$OPENSHIFT_API_URL" | sed -E 's/.*--server[ ="]*([^" ]+).*/\1/' | tr -d '<>' | xargs)
        oc login --token="$CLEAN_TOKEN" --server="$CLEAN_SERVER" --insecure-skip-tls-verify=true \
            >/dev/null 2>&1 && success "oc login successful." || warn "oc login failed — continuing without auto-connect."
    fi

    # Auto-discover APIC routes via oc
    if [[ -z "$RESOLVED_MGMT_URL" ]] && command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
        DETECTED_NS=$(oc get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null \
            | tr ' ' '\n' | grep -E "^(iwhi-apic|apic|cp4i)$" | head -n 1 || echo "$OPENSHIFT_NAMESPACE")
        [[ -n "$DETECTED_NS" ]] && OPENSHIFT_NAMESPACE="$DETECTED_NS"
        info "Discovering APIC routes in namespace '${OPENSHIFT_NAMESPACE}'..."
        MGMT_HOST=$(oc get route -n "$OPENSHIFT_NAMESPACE" \
            -l app.kubernetes.io/component=management,app.kubernetes.io/name=api-manager \
            -o jsonpath='{.items[0].spec.host}' 2>/dev/null \
            || oc get routes -n "$OPENSHIFT_NAMESPACE" \
               -o jsonpath='{.items[?(@.spec.to.name=="management-api-manager")].spec.host}' 2>/dev/null \
            || oc get routes -n "$OPENSHIFT_NAMESPACE" 2>/dev/null | awk '/api-manager/ {print $2}' | head -n 1 \
            || echo "")
        PLAT_HOST=$(oc get route -n "$OPENSHIFT_NAMESPACE" \
            -l app.kubernetes.io/component=management,app.kubernetes.io/name=platform-api \
            -o jsonpath='{.items[0].spec.host}' 2>/dev/null \
            || oc get routes -n "$OPENSHIFT_NAMESPACE" \
               -o jsonpath='{.items[?(@.spec.to.name=="management-platform-api")].spec.host}' 2>/dev/null \
            || oc get routes -n "$OPENSHIFT_NAMESPACE" 2>/dev/null | awk '/platform-api/ {print $2}' | head -n 1 \
            || echo "")
        [[ -n "$MGMT_HOST" ]] && RESOLVED_MGMT_URL="https://${MGMT_HOST}"
        [[ -n "$PLAT_HOST" ]] && RESOLVED_PLATFORM_URL="https://${PLAT_HOST}"
    fi

    [[ -z "$NODE_TLS_REJECT_UNAUTHORIZED" ]] && NODE_TLS_REJECT_UNAUTHORIZED="0"

elif [[ "$DEPLOYMENT_MODE" == "saas" ]] || \
     { [[ "$DEPLOYMENT_MODE" == "auto" ]] && \
       { [[ -n "$SAAS_REGION" ]] || [[ -n "$SAAS_MGMT_URL" ]]; }; }; then

    DETERMINED_MODE="SaaS"
    info "Target: IBM API Connect SaaS / IWHI"

    if [[ -n "$SAAS_REGION" ]]; then
        case "$SAAS_REGION" in
            us-east-1|us-east)
                RESOLVED_MGMT_URL="https://api-manager.us-east-a.apiconnect.automation.ibm.com"
                RESOLVED_PLATFORM_URL="https://platform-api.us-east-a.apiconnect.automation.ibm.com" ;;
            eu-central-1|eu-central)
                RESOLVED_MGMT_URL="https://api-manager.eu-central-a.apiconnect.automation.ibm.com"
                RESOLVED_PLATFORM_URL="https://platform-api.eu-central-a.apiconnect.automation.ibm.com" ;;
            eu-west-2|eu-west)
                RESOLVED_MGMT_URL="https://api-manager.eu-west-a.apiconnect.automation.ibm.com"
                RESOLVED_PLATFORM_URL="https://platform-api.eu-west-a.apiconnect.automation.ibm.com" ;;
            ap-south-1|ap-south)
                RESOLVED_MGMT_URL="https://api-manager.ap-south-a.apiconnect.automation.ibm.com"
                RESOLVED_PLATFORM_URL="https://platform-api.ap-south-a.apiconnect.automation.ibm.com" ;;
            ap-southeast-2|ap-southeast)
                RESOLVED_MGMT_URL="https://api-manager.ap-southeast-a.apiconnect.automation.ibm.com"
                RESOLVED_PLATFORM_URL="https://platform-api.ap-southeast-a.apiconnect.automation.ibm.com" ;;
        esac
    fi

    [[ -n "$SAAS_MGMT_URL" ]]     && RESOLVED_MGMT_URL="$SAAS_MGMT_URL"
    [[ -n "$SAAS_PLATFORM_URL" ]] && RESOLVED_PLATFORM_URL="$SAAS_PLATFORM_URL"
    [[ -z "$NODE_TLS_REJECT_UNAUTHORIZED" ]] && NODE_TLS_REJECT_UNAUTHORIZED="1"
fi

# Interactive fallback
if [[ -z "$RESOLVED_MGMT_URL" ]] || [[ -z "$RESOLVED_PLATFORM_URL" ]]; then
    warn "Could not determine APIC URLs automatically."
    echo "Select your deployment target:"
    echo "  [1] OpenShift / TechZone / On-premises"
    echo "  [2] SaaS Cloud"
    read -r -p "Choice [1/2]: " MANUAL_CHOICE
    if [[ "$MANUAL_CHOICE" == "1" ]]; then
        DETERMINED_MODE="OpenShift"
        [[ -z "$NODE_TLS_REJECT_UNAUTHORIZED" ]] && NODE_TLS_REJECT_UNAUTHORIZED="0"
    else
        DETERMINED_MODE="SaaS"
        [[ -z "$NODE_TLS_REJECT_UNAUTHORIZED" ]] && NODE_TLS_REJECT_UNAUTHORIZED="1"
    fi
    while [[ -z "$RESOLVED_MGMT_URL" ]]; do
        read -r -p "APIC Management URL (e.g. https://manager.apps.<cluster>): " RESOLVED_MGMT_URL
    done
    while [[ -z "$RESOLVED_PLATFORM_URL" ]]; do
        read -r -p "APIC Platform API URL (e.g. https://api.apps.<cluster>): " RESOLVED_PLATFORM_URL
    done
fi

success "Mode:                  ${DETERMINED_MODE}"
success "APIC Management URL:   ${RESOLVED_MGMT_URL}"
success "APIC Platform URL:     ${RESOLVED_PLATFORM_URL}"

# =============================================================================
# PHASE 3: Credentials
# =============================================================================
echo -e "\n${BOLD}${PURPLE}=== [3/4] Credentials ===${RESET}"

if [[ -z "$PROVIDER_ORG" ]]; then
    echo -e "${CYAN}Tip: The provider org name is visible top-left in the API Manager UI.${RESET}"
    read -r -p "Provider Organization (e.g. demo-org): " PROVIDER_ORG
fi

if [[ -z "$CLIENT_ID" ]]; then
    echo -e "\n${CYAN}To get Client ID & Secret:${RESET}"
    echo "  1. Open: ${RESOLVED_MGMT_URL}"
    echo "  2. Click Download Tools > Toolkit > Download Toolkit credentials"
    echo "  3. Open credentials.json — copy values from the 'toolkit' section"
    read -r -p "Toolkit Client ID: " CLIENT_ID
fi

if [[ -z "$CLIENT_SECRET" ]]; then
    read -r -s -p "Toolkit Client Secret: " CLIENT_SECRET; echo ""
fi

if [[ -z "$API_KEY" ]]; then
    echo -e "\n${YELLOW}${BOLD}To generate an API Key:${RESET}"
    echo "  1. Open: ${BOLD}${RESOLVED_MGMT_URL}${RESET}"
    echo "  2. Click your profile icon (top-right) > My API Keys"
    echo "  3. Click Add > set a name > check Enable multiple use > Create"
    read -r -s -p "Paste your API Key: " API_KEY; echo ""
fi

# Write back to flow-pilot.properties
info "Saving credentials to '${PROP_FILE}'..."
cat <<EOF > "$PROP_FILE"
# =============================================================================
# flow-pilot.properties — IBM API Connect Flow Pilot Configuration
# =============================================================================
# Auto-updated by setup-flow-pilot.sh on $(date)
# =============================================================================

# 1. MODE
DEPLOYMENT_MODE=${DEPLOYMENT_MODE}

# 2. OPENSHIFT / TECHZONE
OPENSHIFT_API_URL=${OPENSHIFT_API_URL}
OPENSHIFT_TOKEN=${OPENSHIFT_TOKEN}
OPENSHIFT_NAMESPACE=${OPENSHIFT_NAMESPACE}
OPENSHIFT_MGMT_URL=${RESOLVED_MGMT_URL}
OPENSHIFT_PLATFORM_URL=${RESOLVED_PLATFORM_URL}

# 3. SAAS CLOUD
SAAS_REGION=${SAAS_REGION}
SAAS_MGMT_URL=${SAAS_MGMT_URL}
SAAS_PLATFORM_URL=${SAAS_PLATFORM_URL}

# 4. CREDENTIALS
PROVIDER_ORG=${PROVIDER_ORG}
CLIENT_ID=${CLIENT_ID}
CLIENT_SECRET=${CLIENT_SECRET}
API_KEY=${API_KEY}

# 5. TLS
NODE_TLS_REJECT_UNAUTHORIZED=${NODE_TLS_REJECT_UNAUTHORIZED}
EOF
success "flow-pilot.properties saved."

# =============================================================================
# PHASE 4: MCP Registration & Skills Installation
# =============================================================================
echo -e "\n${BOLD}${PURPLE}=== [4/4] MCP Registration & Skills Installation ===${RESET}"

mkdir -p "$BOB_CONFIG_DIR"

cat <<EOF > "$BOB_MCP_JSON"
{
  "mcpServers": {
    "apic-management-mcp-server": {
      "command": "npx",
      "args": ["-y", "-p", "${MCP_DIR}/management/apic-management-mcp-server-0.0.1.tgz", "apic-management-mcp-server"],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "${NODE_TLS_REJECT_UNAUTHORIZED}",
        "PROVIDER_ORG": "${PROVIDER_ORG}",
        "API_KEY": "${API_KEY}",
        "client_id": "${CLIENT_ID}",
        "client_secret": "${CLIENT_SECRET}",
        "APIC_PLATFORM_URL": "${RESOLVED_PLATFORM_URL}",
        "APIC_MANAGEMENT_URL": "${RESOLVED_MGMT_URL}"
      }
    },
    "apic-analytics-mcp-server": {
      "command": "npx",
      "args": ["-y", "-p", "${MCP_DIR}/analytics/apic-analytics-mcp-server-0.0.1.tgz", "apic-analytics-mcp-server"],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "${NODE_TLS_REJECT_UNAUTHORIZED}",
        "PROVIDER_ORG": "${PROVIDER_ORG}",
        "API_KEY": "${API_KEY}",
        "client_id": "${CLIENT_ID}",
        "client_secret": "${CLIENT_SECRET}",
        "APIC_PLATFORM_URL": "${RESOLVED_PLATFORM_URL}",
        "APIC_MANAGEMENT_URL": "${RESOLVED_MGMT_URL}"
      }
    },
    "apic-governance-mcp-server": {
      "command": "npx",
      "args": ["-y", "-p", "${MCP_DIR}/governance/apic-governance-mcp-server-0.0.1.tgz", "apic-governance-mcp-server"],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "${NODE_TLS_REJECT_UNAUTHORIZED}",
        "PROVIDER_ORG": "${PROVIDER_ORG}",
        "API_KEY": "${API_KEY}",
        "client_id": "${CLIENT_ID}",
        "client_secret": "${CLIENT_SECRET}",
        "APIC_PLATFORM_URL": "${RESOLVED_PLATFORM_URL}",
        "APIC_MANAGEMENT_URL": "${RESOLVED_MGMT_URL}"
      }
    },
    "apic-genai-spec-mcp-server": {
      "command": "npx",
      "args": ["-y", "-p", "${MCP_DIR}/genai-spec/apic-genai-spec-mcp-server-0.0.1.tgz", "apic-genai-spec-mcp-server"],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "${NODE_TLS_REJECT_UNAUTHORIZED}",
        "PROVIDER_ORG": "${PROVIDER_ORG}",
        "API_KEY": "${API_KEY}",
        "client_id": "${CLIENT_ID}",
        "client_secret": "${CLIENT_SECRET}",
        "APIC_PLATFORM_URL": "${RESOLVED_PLATFORM_URL}",
        "APIC_MANAGEMENT_URL": "${RESOLVED_MGMT_URL}"
      }
    },
    "ai-gateway-management-mcp-server": {
      "command": "npx",
      "args": ["-y", "-p", "${MCP_DIR}/ai-gateway-management/ai-gateway-management-mcp-server-0.0.1.tgz", "ai-gateway-management-mcp-server"],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "${NODE_TLS_REJECT_UNAUTHORIZED}",
        "PROVIDER_ORG": "${PROVIDER_ORG}",
        "API_KEY": "${API_KEY}",
        "client_id": "${CLIENT_ID}",
        "client_secret": "${CLIENT_SECRET}",
        "APIC_PLATFORM_URL": "${RESOLVED_PLATFORM_URL}",
        "APIC_MANAGEMENT_URL": "${RESOLVED_MGMT_URL}"
      }
    }
  }
}
EOF

success "MCP config generated: ${BOB_MCP_JSON}"

# Install skills globally
info "Installing Flow Pilot skills..."
(cd "$KIT_DIR" && npx skills add . -g >/dev/null 2>&1) || true
success "Skills installed."

echo -e "\n${GREEN}${BOLD}════════════════════════════════════════════════════════════════════════"
echo "  ✓ SETUP COMPLETE ON ${PLATFORM}!"
echo "════════════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "  Credentials saved to : flow-pilot.properties"
echo "  MCP config written to : ${BOB_MCP_JSON}"
echo "  Skills installed      : global"
echo ""
echo "  → Restart IBM Bob (or your AI agent) to load the MCP servers."
echo "  → Then type: /setup-agent-kit"
echo ""
