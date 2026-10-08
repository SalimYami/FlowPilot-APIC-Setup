# IBM API Connect Flow Pilot — Setup Kit

> **A community-maintained setup automation for [IBM API Connect Flow Pilot](https://www.ibm.com/docs/en/api-connect) — the AI-native toolkit for API lifecycle management.**

[![IBM API Connect](https://img.shields.io/badge/IBM%20API%20Connect-v12.1-0062FF?style=flat-square&labelColor=1a1a2e)](https://www.ibm.com/products/api-connect)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-7C3AED?style=flat-square&labelColor=1a1a2e)]()
[![Node.js](https://img.shields.io/badge/Node.js-%E2%89%A524-339933?style=flat-square&labelColor=1a1a2e&logo=node.js)](https://nodejs.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-0062FF?style=flat-square&labelColor=1a1a2e)](LICENSE)

---

## What is IBM API Connect Flow Pilot?

**IBM API Connect Flow Pilot** is IBM's AI-powered toolkit that brings large language model (LLM) intelligence directly into the API lifecycle. Rather than writing YAML configurations manually or navigating complex UIs, developers describe their intent in plain language and the AI agent handles creation, linting, building, publishing, and testing APIs — all from a conversational interface.

Built on the **Model Context Protocol (MCP)**, Flow Pilot exposes IBM API Connect's full platform (management, analytics, governance, AI gateway) as structured tools that any compatible AI coding assistant can call natively.

### What can you do with it?

| Capability | Description |
|---|---|
| **API Authoring** | Generate OpenAPI specs, policy sequences, Plans, and Products from natural language |
| **Governance** | Lint APIs against OWASP Top 10 and custom Spectral rulesets before publishing |
| **Build & Publish** | Compile projects into deployable `.zip` archives and push to any catalog |
| **Analytics** | Query live API usage, latency, and AI/LLM consumption metrics |
| **AI Gateway** | Convert REST APIs to MCP tools, manage LLM providers, proxy MCP-to-MCP |
| **Test Generation** | Generate and execute test suites (Newman/Postman) from OpenAPI specs |

### Compatible AI agents

| Agent | Support |
|---|---|
| [IBM Bob](https://www.ibm.com/products/bob) | ✅ Full support |
| [Claude Code](https://claude.ai) | ✅ Full support |
| [GitHub Copilot (VS Code)](https://github.com/features/copilot) | ✅ Full support |
| Any [skills.sh](https://skills.sh)-compatible agent | ✅ |

### Supported IBM API Connect platforms

| Deployment | Notes |
|---|---|
| **IBM API Connect SaaS** | AWS multi-region: us-east-1, eu-central-1, eu-west-2, ap-south-1, ap-southeast-2 |
| **IBM webMethods Hybrid Integration (IWHI)** | iPaaS / cloud-managed |
| **On-premises (CP4I / OpenShift)** | IBM Cloud Pak for Integration |
| **DataPower Interact Gateway Standalone** | On-premises AI gateway |

---

## What is in this repo?

This repository contains **only the setup automation** — the scripts and configuration templates needed to install and configure IBM API Connect Flow Pilot on your machine. The actual Flow Pilot kit (23 MB, containing skills and MCP server binaries) must be downloaded separately from IBM.

```
FlowPilot-APIC-Setup/
├── README.md                    ← This file
├── setup-flow-pilot.sh          ← Main setup script (macOS / Linux)
├── setup-flow-pilot.ps1         ← Main setup script (Windows PowerShell)
├── flow-pilot.properties        ← Configuration template (fill before running)
└── configure-flow-pilot.sh      ← Lightweight helper (single MCP server)
```

---

## Prerequisites

Before running the setup, ensure the following are installed:

| Requirement | Version | Install |
|---|---|---|
| **Node.js** | ≥ 24 LTS | [nodejs.org/download](https://nodejs.org/en/download) |
| **npm** | ≥ 10 | Bundled with Node.js |
| **IBM Bob** (or compatible AI agent) | latest | [ibm.com/products/bob](https://www.ibm.com/products/bob) |
| **`oc` CLI** *(optional, OpenShift only)* | any | [mirror.openshift.com](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/) |

> **Note:** Node.js 26 works but produces a `[WARNING]: Using unsupported node version` message from the `apic` CLI. For production use, pin to Node.js 24 LTS with `nvm install 24 && nvm use 24`.

### Verify your environment

```bash
node --version    # should be v24.x.x or higher
npm --version     # should be 10.x or higher
apic --version    # installed automatically by the setup script if absent
```

---

## Step 1 — Download the Flow Pilot kit from IBM

The Flow Pilot kit is **not included in this repo** (IBM intellectual property). Download it from the official page:

**https://www.ibm.com/resources/mrs/assets/DownloadList?source=WebMtds_FlowPilot&lang=en_US**

Three packages are available on that page. For API Connect (this setup):

| Package | Size | For |
|---|---|---|
| `IBM_API_Connect_Flow_Pilot-12.1.1.2.4.zip` | 23.2 MB | **This setup — download this one** |
| `wm-integration-flow-pilot-12.1.0.3.zip` | 5 MB | webMethods Integration Server users |
| `ibm-integration-vscode-extension-1.0.0.zip` | 1.6 MB | IBM Integration Software VS Code extension |

Extract the downloaded archive into `resources/ibm-apic-flow-pilot-kit/` next to these scripts:

```bash
mkdir -p resources
unzip IBM_API_Connect_Flow_Pilot-12.1.1.2.4.zip -d resources/ibm-apic-flow-pilot-kit
```

After extraction, the layout should look like:

```
your-project/
├── setup-flow-pilot.sh
├── setup-flow-pilot.ps1
├── flow-pilot.properties
├── configure-flow-pilot.sh
└── resources/
    ├── ibm-apic-flow-pilot-kit/     ← IBM API Connect skills + MCP servers
    │   ├── README.md
    │   ├── skills/                  ← 10 AI skill definitions
    │   └── mcp-servers/             ← 5 MCP server packages (.tgz)
    └── ibm-wm-flow-pilot-kit/       ← (optional) webMethods kit
```

---

## Step 2 — Configure `flow-pilot.properties`

Edit `flow-pilot.properties` with your IBM API Connect instance details. The setup script reads this file and skips any prompts for values already filled in.

```properties
# Deployment mode: auto | openshift | saas
DEPLOYMENT_MODE=auto

# --- OpenShift / TechZone (on-premises) ---
OPENSHIFT_API_URL=
OPENSHIFT_TOKEN=
OPENSHIFT_NAMESPACE=apic
OPENSHIFT_MGMT_URL=https://manager.apps.<your-cluster>
OPENSHIFT_PLATFORM_URL=https://api.apps.<your-cluster>

# --- SaaS Cloud (fill SAAS_REGION OR the two URLs) ---
SAAS_REGION=              # us-east-1 | eu-central-1 | eu-west-2 | ap-south-1 | ap-southeast-2
SAAS_MGMT_URL=
SAAS_PLATFORM_URL=

# --- API Connect credentials ---
PROVIDER_ORG=             # e.g. demo-org
CLIENT_ID=                # from Download Tools > Toolkit credentials
CLIENT_SECRET=
API_KEY=                  # from Profile > My API Keys

# TLS: 0 = accept self-signed (on-prem/TechZone), 1 = strict (SaaS)
NODE_TLS_REJECT_UNAUTHORIZED=
```

### Where to find each credential

#### On-premises / OpenShift / TechZone

| Variable | Where to find it |
|---|---|
| `OPENSHIFT_MGMT_URL` | `https://manager.apps.<cluster-domain>` |
| `OPENSHIFT_PLATFORM_URL` | `https://api.apps.<cluster-domain>` |
| `PROVIDER_ORG` | Top-left breadcrumb in the API Manager UI |
| `CLIENT_ID` / `CLIENT_SECRET` | API Manager Home → **Download Tools** → **Toolkit** → **Toolkit credentials** → `credentials.json`, section `toolkit` |
| `API_KEY` | Profile icon (top-right) → **My API Keys** → **Add** → check **Enable multiple use** |

#### SaaS Cloud

| Variable | Where to find it |
|---|---|
| `SAAS_REGION` | Match your instance region (see table below) |
| `PROVIDER_ORG` | API Manager header, top-left |
| `CLIENT_ID` / `CLIENT_SECRET` | Profile → **My API Keys** → **Authenticating for the platform REST API** curl block |
| `API_KEY` | Profile → **My API Keys** → **Add** → check **Enable multiple use** |

**Regional SaaS URLs**

| Region | `SAAS_REGION` value | Management URL |
|---|---|---|
| N. Virginia | `us-east-1` | `https://api-manager.us-east-a.apiconnect.automation.ibm.com` |
| Frankfurt | `eu-central-1` | `https://api-manager.eu-central-a.apiconnect.automation.ibm.com` |
| London | `eu-west-2` | `https://api-manager.eu-west-a.apiconnect.automation.ibm.com` |
| Mumbai | `ap-south-1` | `https://api-manager.ap-south-a.apiconnect.automation.ibm.com` |
| Sydney | `ap-southeast-2` | `https://api-manager.ap-southeast-a.apiconnect.automation.ibm.com` |
| Jakarta | `ap-southeast-3` | `https://api-manager.ap-southeast-b.apiconnect.automation.ibm.com` |

---

## Step 3 — Run the setup script

### macOS / Linux

```bash
# Make executable (first time only)
chmod +x setup-flow-pilot.sh

# Run
./setup-flow-pilot.sh
```

### Windows (PowerShell)

```powershell
# Allow script execution (first time only, run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run
.\setup-flow-pilot.ps1
```

### What the script does — 4 phases

```
Phase 1 — System prerequisites
  ├── Checks Node.js >= 24
  ├── Installs @apistudio/apim-cli if absent  (npm install -g)
  ├── Detects active oc (OpenShift CLI) session
  └── Validates resources/ibm-apic-flow-pilot-kit/

Phase 2 — Target discovery
  ├── Reads flow-pilot.properties
  ├── Auto-connects oc login if OPENSHIFT_TOKEN is set
  ├── Auto-discovers APIC routes via oc get route (Kubernetes labels)
  └── Falls back to interactive prompt if URLs cannot be resolved

Phase 3 — Credential collection & persistence
  ├── Prompts for any missing value (PROVIDER_ORG, CLIENT_ID, etc.)
  └── Writes all values back to flow-pilot.properties

Phase 4 — MCP registration & skills installation
  ├── Generates ~/.bob/mcp.json with 5 MCP server entries
  └── Runs: npx skills add . -g  (installs 10 skills globally)
```

### Expected output

```
╔════════════════════════════════════════════════════════════════════════╗
║          IBM API Connect Flow Pilot — Setup Assistant                  ║
╚════════════════════════════════════════════════════════════════════════╝

=== [1/4] Checking System Prerequisites ===
[OK]    Node.js v24.x.x detected (>= 24 required).
[OK]    apic CLI operational.
[OK]    OpenShift session active: admin @ https://api.<cluster>:6443
[OK]    Local IBM API Connect Flow Pilot kit validated.

=== [2/4] Target Discovery ===
[OK]    Mode: OpenShift
[OK]    APIC Management URL: https://manager.apps.<cluster>
[OK]    APIC Platform URL:   https://api.apps.<cluster>

=== [3/4] Credentials ===
[OK]    flow-pilot.properties saved.

=== [4/4] MCP & Skills Registration ===
[OK]    MCP config generated: /Users/<you>/.bob/mcp.json

════════════════════════════════════════════════════════════════════════
  ✓ SETUP COMPLETE!
```

---

## Step 4 — Verify the installation

```bash
# Check that 5 MCP servers are registered
python3 -c "import json; d=json.load(open('/Users/$USER/.bob/mcp.json')); \
  [print(k) for k in d['mcpServers'].keys()]"

# Expected:
# apic-management-mcp-server
# apic-analytics-mcp-server
# apic-governance-mcp-server
# apic-genai-spec-mcp-server
# ai-gateway-management-mcp-server
```

Restart IBM Bob (or your AI agent) to load the MCP servers. Then test with:

```
/setup-agent-kit
```

or directly:

```
List all published APIs in the Sandbox catalog
```

---

## What gets installed — the 5 MCP servers

Each MCP server is launched on demand by Bob as a Node.js subprocess via `npx -p <local .tgz> <entrypoint>`.

| Server | Key tools |
|---|---|
| `apic-management-mcp-server` | ListPublishedApis, CreateSubscription, ListConsumerApps, ListCatalogs, ListGateways, CreateProject |
| `apic-analytics-mcp-server` | GetAnalyticsUsage, GetAnalyticsLatency, GetAnalyticsUsers, GetAnalyticsAILLM, GetAnalyticsMCP |
| `apic-governance-mcp-server` | ValidateOpenAPI, ValidateProduct, Scan, GetAllRulesets, RuleRemediation, DownloadScanReportCsv |
| `apic-genai-spec-mcp-server` | AI-assisted OpenAPI spec generation and enhancement |
| `ai-gateway-management-mcp-server` | LLMProviderGenerator, RestToMCPGenerator, MCPToolsEnhancer, IDIGPublishProject |

## What gets installed — the 10 skills

| Skill | Description |
|---|---|
| `setup-agent-kit` | One-time onboarding — configures all MCP servers interactively |
| `project-manager` | Create, list, rename, and delete API Connect projects |
| `build-project` | Build projects into deployable `.zip` artifacts |
| `lint-project` | Static analysis, OWASP hardening, conformance rules |
| `publish-project` | Publish to catalogs via MCP tools or curl |
| `asset-manager` | Author APIs, Products, Plans, Policies, Routes |
| `test-generator` | Generate and run Newman test suites from OpenAPI specs |
| `rest-to-mcp-generator` | Convert REST API specs into MCP KIND file sets |
| `operation-selector` | Select OpenAPI operations for MCP tool generation |
| `setup-mcp-asset` | Register a published MCP asset into your agent config |

---

## Repository structure

```
FlowPilot-APIC-Setup/
├── setup-flow-pilot.sh              ← Main setup script (macOS / Linux)
├── setup-flow-pilot.ps1             ← Main setup script (Windows PowerShell)
├── configure-flow-pilot.sh          ← Lightweight single-MCP-server helper
├── flow-pilot.properties            ← Configuration template
├── resources/                       ← IBM kit (git-ignored, download from IBM)
│   ├── ibm-apic-flow-pilot-kit/     ← IBM API Connect Flow Pilot 12.1.1.2.4
│   │   ├── skills/                  ← 10 AI skill definitions
│   │   └── mcp-servers/             ← 5 MCP server packages (.tgz)
│   └── ibm-wm-flow-pilot-kit/       ← webMethods Integration Flow Pilot
├── README.md
├── LICENSE
└── .gitignore
```

---

## MCP server logs

All MCP servers write rotating daily logs to:

| Platform | Log location |
|---|---|
| macOS / Linux | `~/apic-mcp/logs/apic-mcp-YYYY-MM-DD.log` |
| Windows | `%USERPROFILE%\apic-mcp\logs\apic-mcp-YYYY-MM-DD.log` |

To enable DEBUG level logging, add `"LOG_LEVEL": "debug"` to a server's `env` block in `~/.bob/mcp.json`.

```bash
# Tail live logs
tail -f ~/apic-mcp/logs/apic-mcp-$(date +%Y-%m-%d).log
```

---

## Lightweight alternative — `configure-flow-pilot.sh`

If you only need to register a single MCP endpoint (e.g. for a quick demo), use the helper script:

```bash
chmod +x configure-flow-pilot.sh

# Global scope (available across all projects)
./configure-flow-pilot.sh --scope global \
  --apic-url https://api.apps.<cluster> \
  --client-id <id> \
  --client-secret <secret> \
  --api-key <key>

# Project scope only
./configure-flow-pilot.sh --scope project
```

This script merges a single `flow-pilot` entry into `~/.bob/mcp.json` (or `.bob/mcp.json` for project scope) using safe Python3-based JSON merging that preserves existing entries.

---

## Areas for improvement

### Script improvements

| Area | Current state | Suggested improvement |
|---|---|---|
| **Node.js version** | Warning on Node.js > 24, script continues | Add `nvm` auto-install and `nvm use 24` to pin the correct version automatically |
| **Secret handling** | Credentials written to `flow-pilot.properties` in plaintext | Integrate with macOS Keychain / Linux secret-service / Windows Credential Manager |
| **Token expiry** | Token set once and not refreshed | Add token validity check and automatic re-authentication before each run |
| **Idempotency** | Script always regenerates `~/.bob/mcp.json` from scratch | Use Python3 JSON-merge logic (like `configure-flow-pilot.sh`) to preserve existing entries |
| **Multiple environments** | Single `flow-pilot.properties` file | Support named profiles (`flow-pilot.dev.properties`, `flow-pilot.prod.properties`) |
| **Dry-run mode** | No preview of what would be changed | Add a `--dry-run` flag that prints what would happen without executing |
| **Uninstall** | No cleanup mechanism | Add an `--uninstall` flag that removes MCP entries and unregisters skills |
| **Windows parity** | PowerShell script lacks `oc` auto-discovery | Port the OpenShift route auto-discovery logic from the bash script to PowerShell |

### IBM API Connect Flow Pilot — General improvement ideas

| Area | Observation | Opportunity |
|---|---|---|
| **MCP server versioning** | All servers are `0.0.1` | Semantic versioning and a changelog would help adopters track breaking changes |
| **Authentication** | Only `API_KEY` + `client_id/secret` | Native IBMid OAuth 2.0 PKCE flow would remove the need to generate long-lived API keys |
| **Installation simplicity** | Kit requires downloading a 23 MB zip + extracting locally | A single `npm install -g @ibm-apiconnect/flow-pilot` that pulls all components would dramatically simplify onboarding |
| **npm registry publishing** | MCP servers are launched via `npx -p <local .tgz>` | Publishing packages to the public npm registry would enable `npx @ibm-apiconnect/...` without local archives |
| **Test coverage visibility** | Test execution feedback is terminal-only | An HTML test report output (e.g. `newman-reporter-html`) would improve visibility and shareability |
| **IDIG standalone parity** | `interact-gateway-onprem` has analytics; other servers don't fully cover standalone scenarios | A unified server that adapts to both APIC-backed and standalone modes would reduce configuration complexity |
| **Multi-catalog support** | Current setup targets one catalog per `mcp.json` entry | Support for multiple catalogs (dev/staging/prod) via a single server instance with a catalog selector parameter |
| **AsyncAPI support** | `apic-genai-spec-mcp-server` generates OpenAPI only | Extending to AsyncAPI would cover event-driven API scenarios (Event Streams / Kafka) |

---

## Troubleshooting

**`apic` command not found after setup**
```bash
npm install -g @apistudio/apim-cli@latest
export PATH="$(npm root -g)/.bin:$PATH"
```

**`oc login` fails with TLS error**
```bash
oc login --token=<token> --server=https://api.<cluster>:6443 --insecure-skip-tls-verify=true
```

**MCP server does not appear in Bob after setup**
1. Verify `~/.bob/mcp.json` contains the server entry
2. Restart Bob completely (not just reload window)
3. Check logs: `tail -f ~/apic-mcp/logs/apic-mcp-$(date +%Y-%m-%d).log`

**`npx skills` not found**
```bash
npm install -g skills
```

**`apic schema list` fails**
```bash
# The apic CLI uses a local schema cache. Re-initialise it:
apic init
```

---

## Sources & official documentation

- **IBM API Connect Documentation** — https://www.ibm.com/docs/en/api-connect
- **IBM DataPower Interact Gateway** — https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1
- **IBM API Connect Product Page** — https://www.ibm.com/products/api-connect
- **Flow Pilot Download** — https://www.ibm.com/resources/mrs/assets/DownloadList?source=WebMtds_FlowPilot&lang=en_US
- **IBM Community — From intent to Live API in minutes** — https://community.ibm.com/community/user/blogs/sowbarnigaa-shanmugavadivel/2026/08/14/ibm-api-connect-flow-pilot
- **IBM Community — API Connect MCP Server** — https://community.ibm.com/community/user/blogs/goutham-shivanna/2026/01/26/ibm-api-connect-mcp-server
- **IBM Community — API Analytics with the API Agent** — https://community.ibm.com/community/user/blogs/michael-osullivan/2025/12/23/apic-api-analytics-with-the-api-agent
- **skills.sh** — https://skills.sh
- **agentskills.io** — https://agentskills.io

---

## License

The setup scripts in this repository are released under the [Apache 2.0 License](LICENSE).

The IBM API Connect Flow Pilot kit itself is subject to IBM's own license terms, available in `resources/ibm-apic-flow-pilot-kit/Licenses/` after extraction.

---

*This repository is a community contribution and is not officially maintained by IBM. For official support, refer to the links in the [Sources](#sources--official-documentation) section above.*
