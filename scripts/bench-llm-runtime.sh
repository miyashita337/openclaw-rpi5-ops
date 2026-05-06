#!/usr/bin/env bash
# Qwen3.6-27B Q4 benchmark across runtimes (Ollama / LM Studio / llama.cpp / vLLM)
# Usage: bench-llm-runtime.sh <runtime-name> <endpoint-url> <model-name>
#   e.g. bench-llm-runtime.sh ollama http://localhost:11434/v1 qwen3.6:27b
#
# Prerequisites:
#   - curl (Win10+ built-in / macOS / Linux)
#   - jq
#   - prompts in scripts/llm-bench-prompts/p1.txt .. p5.txt
#
# Output: bench-results/<runtime>/{summary.tsv,p<N>.{stream.jsonl,timing.txt,output.txt}}

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <runtime-name> <endpoint-url> <model-name>" >&2
  exit 2
fi

RUNTIME="$1"
URL="$2"
MODEL="$3"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_DIR="$REPO_ROOT/scripts/llm-bench-prompts"
OUT_DIR="$REPO_ROOT/bench-results/$RUNTIME"
mkdir -p "$OUT_DIR"

SUMMARY="$OUT_DIR/summary.tsv"
printf 'prompt_id\ttotal_ms\tfirst_token_ms\toutput_chars\ttok_per_sec_est\n' > "$SUMMARY"

for N in 1 2 3 4 5; do
  PROMPT_FILE="$PROMPT_DIR/p${N}.txt"
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "skip p$N: $PROMPT_FILE not found" >&2
    continue
  fi

  echo "=== p$N ($RUNTIME) ===" >&2
  PROMPT_JSON=$(jq -Rs . < "$PROMPT_FILE")
  REQ_BODY=$(jq -n \
    --arg model "$MODEL" \
    --argjson content "$PROMPT_JSON" \
    '{model:$model, messages:[{role:"user", content:$content}], stream:true, max_tokens:1024}')

  STREAM_OUT="$OUT_DIR/p${N}.stream.jsonl"
  TIMING_OUT="$OUT_DIR/p${N}.timing.txt"
  TEXT_OUT="$OUT_DIR/p${N}.output.txt"

  T_START=$(date +%s%N)
  T_FIRST=""

  : > "$STREAM_OUT"
  : > "$TEXT_OUT"

  curl -sN "$URL/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$REQ_BODY" \
  | while IFS= read -r LINE; do
      [[ -z "$LINE" ]] && continue
      [[ "$LINE" == "data: [DONE]" ]] && break
      LINE="${LINE#data: }"
      printf '%s\n' "$LINE" >> "$STREAM_OUT"
      if [[ -z "$T_FIRST" ]]; then
        T_FIRST=$(date +%s%N)
        printf 'first_token_ns=%s\n' "$T_FIRST" > "$TIMING_OUT"
      fi
      DELTA=$(printf '%s' "$LINE" | jq -r '.choices[0].delta.content // empty' 2>/dev/null || true)
      [[ -n "$DELTA" ]] && printf '%s' "$DELTA" >> "$TEXT_OUT"
    done

  T_END=$(date +%s%N)
  TOTAL_MS=$(( (T_END - T_START) / 1000000 ))
  if [[ -f "$TIMING_OUT" ]]; then
    FIRST_NS=$(grep -oE '[0-9]+' "$TIMING_OUT" | head -1)
    FIRST_MS=$(( (FIRST_NS - T_START) / 1000000 ))
  else
    FIRST_MS=0
  fi
  CHARS=$(wc -c < "$TEXT_OUT" | tr -d ' ')
  # Rough tok/sec: assume 1 token ~ 2.5 chars for Japanese mix; refine later from API metrics
  if (( TOTAL_MS > 0 )); then
    TOK_EST=$(awk -v c="$CHARS" -v ms="$TOTAL_MS" 'BEGIN { printf "%.1f", (c/2.5)/(ms/1000) }')
  else
    TOK_EST="0"
  fi
  printf 'p%d\t%d\t%d\t%d\t%s\n' "$N" "$TOTAL_MS" "$FIRST_MS" "$CHARS" "$TOK_EST" >> "$SUMMARY"
  printf '  total=%dms first=%dms chars=%d tok/s_est=%s\n' "$TOTAL_MS" "$FIRST_MS" "$CHARS" "$TOK_EST" >&2
done

echo
echo "Summary written to: $SUMMARY"
column -t -s$'\t' "$SUMMARY"
