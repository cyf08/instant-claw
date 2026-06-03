#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="${ROOT_DIR}/bioinformatics-openclaw-agent.ocpkg.tar.gz"
PROFILE="${OPENCLAW_TEST_PROFILE:-bioinfo-pkg-test}"
AGENT_ID="${OPENCLAW_TEST_AGENT_ID:-bioinfo}"
STATE_DIR="${HOME}/.openclaw-${PROFILE}"
WORKSPACE="${STATE_DIR}/workspace-bioinfo"
CONFIG="${STATE_DIR}/openclaw.json"

if [[ ! -f "${PACKAGE}" ]]; then
  echo "Package not found: ${PACKAGE}" >&2
  exit 1
fi

command -v openclaw >/dev/null
command -v clawpacker >/dev/null

rm -rf "${STATE_DIR}"
mkdir -p "${STATE_DIR}"

clawpacker import "${PACKAGE}" \
  --target-workspace "${WORKSPACE}" \
  --agent-id "${AGENT_ID}" \
  --config "${CONFIG}" \
  --force >/tmp/bioinfo-agent-import.log

clawpacker validate \
  --target-workspace "${WORKSPACE}" \
  --agent-id "${AGENT_ID}" \
  --config "${CONFIG}" >/tmp/bioinfo-agent-validate.log

openclaw --profile "${PROFILE}" config validate

identity_name="$(python3 - "${CONFIG}" "${AGENT_ID}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
agent_id = sys.argv[2]
for agent in data.get("agents", {}).get("list", []):
    if agent.get("id") == agent_id:
        print(agent.get("identity", {}).get("name") or agent.get("name") or "")
        break
PY
)"
if [[ "${identity_name}" != "生信小龙虾" ]]; then
  echo "Bioinformatics package identity mismatch: expected 生信小龙虾, got ${identity_name:-<empty>}" >&2
  exit 1
fi

openclaw --profile "${PROFILE}" skills info scanpy >/tmp/bioinfo-agent-scanpy.log
openclaw --profile "${PROFILE}" skills info biopython >/tmp/bioinfo-agent-biopython.log
openclaw --profile "${PROFILE}" skills info pydeseq2 >/tmp/bioinfo-agent-pydeseq2.log

skill_count="$(find "${WORKSPACE}/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"

if [[ "${OPENCLAW_LIVE_AGENT_TEST:-0}" == "1" ]]; then
  MODEL="${OPENCLAW_TEST_MODEL:-openai-codex/gpt-5.5}"

  openclaw --profile "${PROFILE}" config set agents.defaults.model.primary "${MODEL}" >/tmp/bioinfo-agent-model-config.log

  live_json="/tmp/bioinfo-agent-live.json"
  openclaw --profile "${PROFILE}" agent \
    --local \
    --agent "${AGENT_ID}" \
    --message "请用一句话说明你的身份，然后说明你会优先使用哪个 skill 处理 h5ad 单细胞 RNA-seq QC、归一化、PCA、UMAP 和聚类。不要写代码。" \
    --timeout 180 \
    --json >"${live_json}" 2>&1

  if ! grep -Eq "生物信息学.*助手" "${live_json}"; then
    echo "Live agent test failed: identity phrase not found." >&2
    exit 1
  fi

  if ! grep -q "scanpy" "${live_json}"; then
    echo "Live agent test failed: scanpy skill not mentioned." >&2
    exit 1
  fi

  session_dir="${STATE_DIR}/agents/${AGENT_ID}/sessions"
  if ! grep -R "workspace-bioinfo/skills/scanpy/SKILL.md" "${session_dir}" >/dev/null; then
    echo "Live agent test failed: scanpy/SKILL.md was not read in session logs." >&2
    exit 1
  fi
fi

echo "Bioinformatics package smoke test passed."
echo "Profile: ${PROFILE}"
echo "Workspace: ${WORKSPACE}"
echo "Skills installed: ${skill_count}"
if [[ "${OPENCLAW_LIVE_AGENT_TEST:-0}" == "1" ]]; then
  echo "Live agent identity and scanpy skill-read test passed."
fi
