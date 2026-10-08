#!/usr/bin/env bash
# =============================================================================
# configure-flow-pilot.sh
# Lightweight helper — adds a single 'flow-pilot' MCP server entry to Bob.
# Use for quick setups or demos; use setup-flow-pilot.sh for full installs.
#
# Reference: https://community.ibm.com/community/user/blogs/sowbarnigaa-shanmugavadivel/2026/08/14/ibm-api-connect-flow-pilot
#
# Usage:
#   chmod +x configure-flow-pilot.sh
#   ./configure-flow-pilot.sh [--scope global|project] [--apic-url <url>]
#                             [--api-key <key>] [--client-id <id>]
#                             [--client-secret <secret>]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

SCOPE="project"
APIC_URL=""
API_KEY=""
CLIENT_ID=""
CLIENT_SECRET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)          SCOPE="$2";         shift 2 ;;
    --apic-url)       APIC_URL="$2";      shift 2 ;;
    --api-key)        API_KEY="$2";       shift 2 ;;
    --client-id)      CLIENT_ID="$2";     shift 2 ;;
    --client-secret)  CLIENT_SECRET="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--scope global|project] [--apic-url <url>]"
      echo "          [--api-key <key>] [--client-id <id>] [--client-secret <secret>]"
      exit 0 ;;
    *) die "Unknown option: $1. Run '$0 --help' for usage." ;;
  esac
done

[[ "$SCOPE" == "global" || "$SCOPE" == "project" ]] \
  || die "Invalid scope '$SCOPE'. Use 'global' or 'project'."

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║      IBM API Connect — FlowPilot MCP Quick Configure     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

info "Checking prerequisites..."
command -v node >/dev/null 2>&1 || die "Node.js is not installed. Install from https://nodejs.org"
NODE_VERSION=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
[[ "$NODE_VERSION" -ge 18 ]] || die "Node.js 18+ required (found v${NODE_VERSION})."
success "Node.js v$(node --version) detected."

echo ""
info "Connecting Bob to your IBM API Connect instance."
echo "   Leave any value blank to add it later in the config file."
echo ""

prompt_if_empty() {
  local var_name="$1" prompt_text="$2" secret="${3:-false}"
  if [[ -z "${!var_name}" ]]; then
    if [[ "$secret" == "true" ]]; then
      read -r -s -p "  ${BOLD}${prompt_text}${RESET}: " input; echo
    else
      read -r -p  "  ${BOLD}${prompt_text}${RESET}: " input
    fi
    printf -v "$var_name" '%s' "$input"
  fi
}

prompt_if_empty APIC_URL      "IBM API Connect Platform API URL (e.g. https://api.apps.<cluster>)"
prompt_if_empty CLIENT_ID     "OAuth Client ID"
prompt_if_empty CLIENT_SECRET "OAuth Client Secret" true
prompt_if_empty API_KEY       "API Key (optional — leave blank if using OAuth only)" true

if [[ "$SCOPE" == "global" ]]; then
  MCP_CONFIG_FILE="${HOME}/.bob/mcp.json"
  info "Scope: global  →  ${MCP_CONFIG_FILE}"
else
  MCP_CONFIG_FILE="${PWD}/.bob/mcp.json"
  info "Scope: project →  ${MCP_CONFIG_FILE}"
fi
mkdir -p "$(dirname "$MCP_CONFIG_FILE")"

ENV_ENTRIES=()
[[ -n "$APIC_URL" ]]      && ENV_ENTRIES+=("\"APIC_URL\": \"${APIC_URL}\"")
[[ -n "$CLIENT_ID" ]]     && ENV_ENTRIES+=("\"APIC_CLIENT_ID\": \"${CLIENT_ID}\"")
[[ -n "$CLIENT_SECRET" ]] && ENV_ENTRIES+=("\"APIC_CLIENT_SECRET\": \"${CLIENT_SECRET}\"")
[[ -n "$API_KEY" ]]       && ENV_ENTRIES+=("\"APIC_API_KEY\": \"${API_KEY}\"")

ENV_BLOCK=""
if [[ ${#ENV_ENTRIES[@]} -gt 0 ]]; then
  ENV_BLOCK=$(printf '        %s,\n' "${ENV_ENTRIES[@]}")
  ENV_BLOCK="${ENV_BLOCK%,}"
  ENV_BLOCK="\n      \"env\": {\n${ENV_BLOCK}\n      },"
fi

NEW_SERVER_BLOCK=$(cat <<SERVERBLOCK
    "flow-pilot": {
      "command": "npx",
      "args": ["-y", "@ibm-apiconnect/flow-pilot-mcp"],${ENV_BLOCK}
      "alwaysAllow": [],
      "disabled": false
    }
SERVERBLOCK
)

if [[ -f "$MCP_CONFIG_FILE" ]]; then
  command -v python3 >/dev/null 2>&1 || die "python3 is required to update an existing config."
  python3 -c "import sys, json; json.load(open('${MCP_CONFIG_FILE}'))" \
    || die "Existing ${MCP_CONFIG_FILE} contains invalid JSON. Fix it first."
  python3 - "$MCP_CONFIG_FILE" "$NEW_SERVER_BLOCK" <<'PYEOF'
import sys, json
config_path = sys.argv[1]
with open(config_path) as f:
    config = json.load(f)
config.setdefault("mcpServers", {})
block_json = json.loads("{" + sys.argv[2] + "}")
config["mcpServers"].update(block_json)
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYEOF
else
  cat > "$MCP_CONFIG_FILE" <<JSONEOF
{
  "mcpServers": {
${NEW_SERVER_BLOCK}
  }
}
JSONEOF
fi

echo ""
success "FlowPilot MCP server configured in ${BOLD}${MCP_CONFIG_FILE}${RESET}"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo "  1. Restart IBM Bob (or reload VS Code) to pick up the new MCP server."
echo "  2. In Bob, verify 'flow-pilot' appears in Settings > MCP."
echo "  3. Start a conversation: 'List all published APIs in the Sandbox catalog'"
echo ""
echo -e "  ${CYAN}Docs:${RESET} https://community.ibm.com/community/user/blogs/sowbarnigaa-shanmugavadivel/2026/08/14/ibm-api-connect-flow-pilot"
echo ""
