# instant-claw

## Project Overview

`instant-claw` stores portable OpenClaw agent packages. Each package is a
`.ocpkg.tar.gz` archive that can be imported with `clawpacker` into an
OpenClaw workspace.

The packages are intended to carry reusable agent assets such as instructions,
skills, workspace files, and package metadata. They intentionally do not carry
machine-local runtime state such as secrets, model provider keys, channel
sessions, conversation history, or local message routing bindings.

Use this repository when you want to:

- Move an OpenClaw agent between machines.
- Recreate an agent from a known package.
- Load multiple specialized agents into one OpenClaw instance.
- Validate that an imported agent has the expected skills and workspace files.

## Dependencies

Install OpenClaw and `clawpacker` before importing packages:

```bash
npm install -g openclaw @cogineai/clawpacker
```

Verify both CLIs are available:

```bash
openclaw --version
clawpacker --version
```

`clawpacker` imports `.ocpkg.tar.gz` archives into an OpenClaw workspace, writes
the agent entry into the selected `openclaw.json`, and validates the imported
files against the package manifest.

Runtime dependencies are not bundled by `clawpacker`. Install the Python,
system, model-provider, and external-tool dependencies required by each agent
after import. The `Instant Agents` section below lists the known runtime
dependencies for the packages in this repository.

## Importing An Agent

For testing or one-off use, import a package into an isolated OpenClaw profile.
This keeps the package separate from your default OpenClaw instance.

```bash
PACKAGE="./your-agent.ocpkg.tar.gz"
PROFILE="your-profile"
AGENT_ID="your-agent"
WORKSPACE="$HOME/.openclaw-${PROFILE}/workspace-${AGENT_ID}"
AGENT_DIR="$HOME/.openclaw-${PROFILE}/agents/${AGENT_ID}/agent"
CONFIG="$HOME/.openclaw-${PROFILE}/openclaw.json"

openclaw --profile "$PROFILE" config file

clawpacker import "$PACKAGE" \
  --target-workspace "$WORKSPACE" \
  --agent-id "$AGENT_ID" \
  --target-agent-dir "$AGENT_DIR" \
  --config "$CONFIG" \
  --force

clawpacker validate \
  --target-workspace "$WORKSPACE" \
  --agent-id "$AGENT_ID" \
  --target-agent-dir "$AGENT_DIR" \
  --config "$CONFIG"

openclaw --profile "$PROFILE" config validate
openclaw --profile "$PROFILE" agents list
openclaw --profile "$PROFILE" skills list
```

After import, configure the target profile's model provider, credentials,
channel accounts, and routing separately. Portable packages should not contain
local secrets, sessions, or machine-specific runtime configuration.

Test the imported agent directly:

```bash
openclaw --profile "$PROFILE" agent \
  --agent "$AGENT_ID" \
  --message "health check: reply OK" \
  --timeout 180 \
  --json
```

## Importing Multiple Agents Into One OpenClaw Instance

To load several agents into the same OpenClaw instance, give every imported
agent its own agent id, workspace, and agent directory. Do not import multiple
packages into the default `~/.openclaw/workspace` unless you intentionally want
to replace that workspace's files.

For an existing OpenClaw instance, create the isolated agent entry first, then
import the package into that agent's workspace:

```bash
PACKAGE="./your-agent.ocpkg.tar.gz"
AGENT_ID="your-agent"
WORKSPACE="$HOME/.openclaw/workspace-${AGENT_ID}"
AGENT_DIR="$HOME/.openclaw/agents/${AGENT_ID}/agent"
CONFIG="$HOME/.openclaw/openclaw.json"

openclaw agents add "$AGENT_ID" \
  --workspace "$WORKSPACE" \
  --agent-dir "$AGENT_DIR" \
  --non-interactive

clawpacker import "$PACKAGE" \
  --target-workspace "$WORKSPACE" \
  --agent-id "$AGENT_ID" \
  --target-agent-dir "$AGENT_DIR" \
  --config "$CONFIG" \
  --force

clawpacker validate \
  --target-workspace "$WORKSPACE" \
  --agent-id "$AGENT_ID" \
  --target-agent-dir "$AGENT_DIR" \
  --config "$CONFIG"

openclaw gateway restart
openclaw agents list
```

If the agent already exists, skip `openclaw agents add` and rerun
`clawpacker import` with the same `--agent-id`, `--target-workspace`, and
`--target-agent-dir`.

Example: import the current packages into one OpenClaw instance:

```bash
CONFIG="$HOME/.openclaw/openclaw.json"

# Paper data review assistant
AGENT_ID="paper-data-review-assistant"
openclaw agents add "$AGENT_ID" \
  --workspace "$HOME/.openclaw/workspace-${AGENT_ID}" \
  --agent-dir "$HOME/.openclaw/agents/${AGENT_ID}/agent" \
  --non-interactive
clawpacker import ./paper-data-review-assistant.ocpkg.tar.gz \
  --target-workspace "$HOME/.openclaw/workspace-${AGENT_ID}" \
  --agent-id "$AGENT_ID" \
  --target-agent-dir "$HOME/.openclaw/agents/${AGENT_ID}/agent" \
  --config "$CONFIG" \
  --force

# SJTU work assistant
AGENT_ID="sjtu-workassistant"
openclaw agents add "$AGENT_ID" \
  --workspace "$HOME/.openclaw/workspace-${AGENT_ID}" \
  --agent-dir "$HOME/.openclaw/agents/${AGENT_ID}/agent" \
  --non-interactive
clawpacker import ./sjtu-workassistant.ocpkg.tar.gz \
  --target-workspace "$HOME/.openclaw/workspace-${AGENT_ID}" \
  --agent-id "$AGENT_ID" \
  --target-agent-dir "$HOME/.openclaw/agents/${AGENT_ID}/agent" \
  --config "$CONFIG" \
  --force

openclaw gateway restart
openclaw agents list
```

The import is independent when `openclaw agents list` shows each imported agent
with its own workspace path. If imported files appear under the default
workspace, or calls without `--agent <id>` start using the imported behavior,
the package was imported into the main/default agent by mistake.

## Binding Message Channels

Importing an agent package does not automatically route chat messages to that
agent. If no routing binding exists, inbound channel messages continue to use
the default agent, even when the imported agent is present and valid.

Check the current routing state:

```bash
openclaw agents list
openclaw agents bindings
```

Bind a channel account to the imported agent when you want messages from that
account to enter the new agent:

```bash
AGENT_ID="your-agent"
openclaw agents bind --agent "$AGENT_ID" --bind feishu:default
openclaw agents bindings
```

Use the channel/account id that exists on the target OpenClaw instance. For
Feishu/Lark deployments this is commonly `feishu:default`, but another account
id may be used if multiple accounts are configured.

Direct CLI calls do not require channel routing:

```bash
openclaw agent --agent "$AGENT_ID" \
  --message "health check: reply OK" \
  --timeout 180 \
  --json
```

No-reply troubleshooting:

- If inbound logs show a session key such as `agent:work:feishu:...`, the
  message is still routed to the default `work` agent. Bind the channel account
  to the intended agent.
- If logs show the intended agent id but later show
  `dispatch complete (replies=0)`, inspect provider and tool logs.
- Model/provider failures often include `provider-transport-fetch`,
  `UND_ERR_SOCKET`, `fetch failed`, long `elapsedMs=600000` timeouts, or
  repeated `stalled session` diagnostics.

Useful commands:

```bash
openclaw gateway status
openclaw health
openclaw agents list
openclaw agents bindings
journalctl --user -u openclaw-gateway.service --since "30 min ago" --no-pager -o cat
```

Restarting the gateway can clear a stuck run, but it does not fix a broken
model endpoint, missing provider credentials, network/proxy problems, rate
limits, or unavailable upstream services.

## Instant Agents

Available packages:

| Package | Recommended agent id | Purpose |
| --- | --- | --- |
| `bioinformatics-openclaw-agent.ocpkg.tar.gz` | `bioinfo` | Bioinformatics analysis assistant. |
| `paper-data-review-assistant.ocpkg.tar.gz` | `paper-data-review-assistant` | Paper source-data and research-integrity review assistant. |
| `sjtu-workassistant.ocpkg.tar.gz` | `sjtu-workassistant` | SJTU work and office-document assistant. |

Use the recommended agent id with the import commands above unless you have a
reason to choose a different id.

### Bioinformatics Agent

Package:

```bash
bioinformatics-openclaw-agent.ocpkg.tar.gz
```

Recommended agent id:

```bash
bioinfo
```

After import, confirm OpenClaw can discover key bioinformatics skills:

```bash
openclaw --profile bioinfo-pkg-test skills info scanpy
openclaw --profile bioinfo-pkg-test skills info biopython
openclaw --profile bioinfo-pkg-test skills info pydeseq2
```

Run the bundled smoke test:

```bash
./scripts/test-bioinfo-package.sh
```

To also run a live model-backed agent turn and verify that the imported agent
identifies as a bioinformatics assistant and reads `scanpy/SKILL.md`, use:

```bash
OPENCLAW_LIVE_AGENT_TEST=1 ./scripts/test-bioinfo-package.sh
```

The live test requires a working OpenClaw model provider. By default it uses
`openai-codex/gpt-5.5`; override with `OPENCLAW_TEST_MODEL`.

### Paper Data Review Assistant

Package:

```bash
paper-data-review-assistant.ocpkg.tar.gz
```

Recommended agent id:

```bash
paper-data-review-assistant
```

This package includes `geng-skills`, `paperconan`, `paper-fraud-auditor`
(from `research-integrity-auditor`), and `benford-ocsvm-detection` for paper
source-data and research-integrity screening. It is designed for statistical
anomaly triage on paper source tables, PDFs, extracted tables, and
Benford/OCSVM-style numeric checks.

Recommended Python setup after import:

```bash
cd "$HOME/.openclaw-paper-data-review-pkg-test/workspace-paper-data-review-assistant"
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install openpyxl numpy scipy pandas matplotlib scikit-learn pdfplumber reportlab pypdf
```

For `paperconan`, install the CLI when you want to scan local source-data
directories directly:

```bash
python3 -m pip install paperconan
# or, from a local clone:
# python3 -m pip install -e /path/to/paperconan
```

To route Feishu/Lark messages to this assistant on an existing OpenClaw
instance:

```bash
openclaw agents bind --agent paper-data-review-assistant --bind feishu:default
openclaw agents bindings
```

Configure MinerU tokens, model provider keys, sessions, and local channel
bindings separately after import.

### SJTU WorkAssistant

Package:

```bash
sjtu-workassistant.ocpkg.tar.gz
```

Recommended agent id:

```bash
sjtu-workassistant
```

This package includes the `sjtu-canvas` and `lobster-square` workspace skills
from `https://github.com/xhh678876/openclaw-sjtu`, local archive skills from
`/home/hpccyf/Projects/skills.zip` (`agent-browser`, `email-mail-master-rose`,
`martok9803-reminder-engine`, and `paper-daily-tracker`), plus ClawHub
office-document skills: `minimax-docx`, `minimax-xlsx`, `minimax-pdf`, and
`pptx-generator`.

Configure local credentials such as Canvas tokens, jAccount mail credentials,
SMTP/IMAP auth codes, PaperMind keys, Shuiyuan keys, SJTU Date credentials, or
Dragon/Lobster Square API keys separately after import.

Runtime tools are not bundled by `clawpacker`. For the MiniMax
office-document skills, prepare Python 3, .NET 9 SDK for `minimax-docx`,
`python-pptx` and `pillow` for `pptx-generator`, `openpyxl` and `pandas` for
`minimax-xlsx`, and LibreOffice/Pandoc where the selected workflow requires
them.

Recommended Python setup after import:

```bash
cd "$HOME/.openclaw-sjtu-workassistant-pkg-test/workspace-sjtu-workassistant"
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install \
  requests beautifulsoup4 python-pptx pdfplumber handright Pillow reportlab \
  openpyxl pandas PyYAML python-dotenv weasyprint matplotlib playwright
python3 -m playwright install chromium
```

Dependency coverage:

- `sjtu-canvas`: `requests`, `beautifulsoup4`, `python-pptx`, `pdfplumber`,
  `handright`, `Pillow`, `reportlab`.
- `minimax-xlsx`: `openpyxl`, `pandas`.
- `pptx-generator`: `python-pptx`, `Pillow`.
- `paper-daily-tracker`: `requests`, `PyYAML`, `python-dotenv`, `weasyprint`.
- `minimax-docx` optional helpers: `Pillow`, `matplotlib`, `playwright`.
- `email-mail-master-rose`: no extra Python packages for basic IMAP/SMTP flows;
  it uses Python standard-library mail modules.

Optional advanced Shuiyuan RAG dependencies:

```bash
source .venv/bin/activate
python3 -m pip install -r skills/sjtu-canvas/scripts/requirements-rag.txt
```

Optional model-evaluation helpers used by selected SJTU scripts:

```bash
source .venv/bin/activate
python3 -m pip install openai anthropic google-generativeai
```
