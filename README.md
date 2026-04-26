# instant-claw

Portable OpenClaw agent packages.

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
