# instant-claw

Portable OpenClaw agent packages.

## Requirements

Install OpenClaw and `clawpacker` before importing packages:

```bash
npm install -g openclaw @cogineai/clawpacker
```

Verify both CLIs are available:

```bash
openclaw --version
clawpacker --version
```

`clawpacker` does the portable package work here: it imports `.ocpkg.tar.gz` archives into an OpenClaw workspace, writes the agent entry into the target `openclaw.json`, and validates the imported files against the package manifest.

## General Import

Use this template for any `.ocpkg.tar.gz` package:

```bash
PACKAGE="./your-agent.ocpkg.tar.gz"
PROFILE="your-profile"
AGENT_ID="your-agent"
WORKSPACE="$HOME/.openclaw-${PROFILE}/workspace-${AGENT_ID}"
CONFIG="$HOME/.openclaw-${PROFILE}/openclaw.json"

openclaw --profile "$PROFILE" config file

clawpacker import "$PACKAGE" \
  --target-workspace "$WORKSPACE" \
  --agent-id "$AGENT_ID" \
  --config "$CONFIG" \
  --force

clawpacker validate \
  --target-workspace "$WORKSPACE" \
  --agent-id "$AGENT_ID" \
  --config "$CONFIG"

openclaw --profile "$PROFILE" config validate
openclaw --profile "$PROFILE" agents list
openclaw --profile "$PROFILE" skills list
```

After import, configure the target OpenClaw instance's model provider, credentials, channels, and routing separately. Portable packages should not contain local secrets, sessions, or machine-specific runtime configuration.

## Bioinformatics Agent

Package:

```bash
bioinformatics-openclaw-agent.ocpkg.tar.gz
```

Import it into an isolated OpenClaw profile as a `bioinfo` agent:

```bash
openclaw --profile bioinfo-pkg-test config file

clawpacker import ./bioinformatics-openclaw-agent.ocpkg.tar.gz \
  --target-workspace "$HOME/.openclaw-bioinfo-pkg-test/workspace-bioinfo" \
  --agent-id bioinfo \
  --config "$HOME/.openclaw-bioinfo-pkg-test/openclaw.json" \
  --force

clawpacker validate \
  --target-workspace "$HOME/.openclaw-bioinfo-pkg-test/workspace-bioinfo" \
  --agent-id bioinfo \
  --config "$HOME/.openclaw-bioinfo-pkg-test/openclaw.json"
```

Confirm OpenClaw can discover key bioinformatics skills:

```bash
openclaw --profile bioinfo-pkg-test skills info scanpy
openclaw --profile bioinfo-pkg-test skills info biopython
openclaw --profile bioinfo-pkg-test skills info pydeseq2
```

Or run the bundled smoke test:

```bash
./scripts/test-bioinfo-package.sh
```

To also run a live model-backed agent turn and verify that the imported agent identifies as a bioinformatics assistant and reads `scanpy/SKILL.md`, use:

```bash
OPENCLAW_LIVE_AGENT_TEST=1 ./scripts/test-bioinfo-package.sh
```

The live test requires a working OpenClaw model provider. By default it uses `openai-codex/gpt-5.5`; override with `OPENCLAW_TEST_MODEL`.

The package intentionally excludes local credentials, sessions, channel bindings, and runtime provider configuration. Configure models/providers separately on the target OpenClaw instance.

## Paper Data Review Assistant

Package:

```bash
paper-data-review-assistant.ocpkg.tar.gz
```

Import it into an isolated OpenClaw profile as a `paper-data-review-assistant` agent:

```bash
openclaw --profile paper-data-review-pkg-test config file

clawpacker import ./paper-data-review-assistant.ocpkg.tar.gz \
  --target-workspace "$HOME/.openclaw-paper-data-review-pkg-test/workspace-paper-data-review-assistant" \
  --agent-id paper-data-review-assistant \
  --config "$HOME/.openclaw-paper-data-review-pkg-test/openclaw.json" \
  --force

clawpacker validate \
  --target-workspace "$HOME/.openclaw-paper-data-review-pkg-test/workspace-paper-data-review-assistant" \
  --agent-id paper-data-review-assistant \
  --config "$HOME/.openclaw-paper-data-review-pkg-test/openclaw.json"
```

This package includes the `geng-skills`, `paperconan`, `paper-fraud-auditor` (from `research-integrity-auditor`), and `benford-ocsvm-detection` skills for paper source-data and research-integrity screening. It is designed for statistical anomaly triage on paper source tables, PDFs, extracted tables, and Benford/OCSVM-style numeric checks.

Recommended setup after import:

```bash
cd "$HOME/.openclaw-paper-data-review-pkg-test/workspace-paper-data-review-assistant"
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install openpyxl numpy scipy pandas matplotlib scikit-learn pdfplumber reportlab pypdf
```

For `paperconan`, install the CLI when you want to scan local source-data directories directly:

```bash
python3 -m pip install paperconan
# or, from a local clone:
# python3 -m pip install -e /path/to/paperconan
```

Configure external credentials separately after import. MinerU tokens, model provider keys, sessions, and local channel bindings are intentionally not included in the package.

## SJTU WorkAssistant

Package:

```bash
sjtu-workassistant.ocpkg.tar.gz
```

Import it into an isolated OpenClaw profile as a `sjtu-workassistant` agent:

```bash
openclaw --profile sjtu-workassistant-pkg-test config file

clawpacker import ./sjtu-workassistant.ocpkg.tar.gz \
  --target-workspace "$HOME/.openclaw-sjtu-workassistant-pkg-test/workspace-sjtu-workassistant" \
  --agent-id sjtu-workassistant \
  --config "$HOME/.openclaw-sjtu-workassistant-pkg-test/openclaw.json" \
  --force

clawpacker validate \
  --target-workspace "$HOME/.openclaw-sjtu-workassistant-pkg-test/workspace-sjtu-workassistant" \
  --agent-id sjtu-workassistant \
  --config "$HOME/.openclaw-sjtu-workassistant-pkg-test/openclaw.json"
```

This package includes the `sjtu-canvas` and `lobster-square` workspace skills from `https://github.com/xhh678876/openclaw-sjtu`, local archive skills from `/home/hpccyf/Projects/skills.zip`: `agent-browser`, `email-mail-master-rose`, `martok9803-reminder-engine`, and `paper-daily-tracker`, plus ClawHub office-document skills: `minimax-docx`, `minimax-xlsx`, `minimax-pdf`, and `pptx-generator`. Configure local credentials such as Canvas tokens, jAccount mail credentials, SMTP/IMAP auth codes, PaperMind keys, Shuiyuan keys, SJTU Date credentials, or Dragon/Lobster Square API keys separately after import; portable packages should not include secrets.

Runtime tools are not bundled by clawpacker. For the MiniMax office-document skills, prepare Python 3, .NET 9 SDK for `minimax-docx`, `python-pptx` and `pillow` for `pptx-generator`, `openpyxl` and `pandas` for `minimax-xlsx`, and LibreOffice/Pandoc where the selected workflow requires them.

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

- `sjtu-canvas`: `requests`, `beautifulsoup4`, `python-pptx`, `pdfplumber`, `handright`, `Pillow`, `reportlab`.
- `minimax-xlsx`: `openpyxl`, `pandas`.
- `pptx-generator`: `python-pptx`, `Pillow`.
- `paper-daily-tracker`: `requests`, `PyYAML`, `python-dotenv`, `weasyprint`.
- `minimax-docx` optional helpers: `Pillow`, `matplotlib`, `playwright`.
- `email-mail-master-rose`: no extra Python packages for basic IMAP/SMTP flows; it uses Python standard-library mail modules.

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
