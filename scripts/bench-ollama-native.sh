#!/usr/bin/env bash
# Ollama native /api/chat benchmark with think:false support.
#
# Differs from bench-llm-runtime.sh (OpenAI compat) in two key ways:
#   1. Uses Ollama's native /api/chat endpoint, which accepts a top-level
#      "think" field that explicitly disables Qwen3.6's thinking mode
#      (the OpenAI-compat layer does not honor /no_think directives).
#   2. Reads eval_count + eval_duration from the final stream chunk,
#      giving a real tokens/sec instead of a chars-based estimate.
#
# Usage:
#   bench-ollama-native.sh <runtime-tag> <ollama-base-url> <model> <think>
#     <think> ::= true | false
#   e.g. bench-ollama-native.sh ollama-thinkOFF http://localhost:11434 qwen3.6:27b false

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <runtime-tag> <ollama-base-url> <model> <true|false>" >&2
  exit 2
fi

RUNTIME="$1"
URL="$2"
MODEL="$3"
THINK="$4"

case "$THINK" in
  true|false) ;;
  *) echo "think must be 'true' or 'false', got: $THINK" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_DIR="$REPO_ROOT/scripts/llm-bench-prompts"
OUT_DIR="$REPO_ROOT/bench-results/$RUNTIME"
mkdir -p "$OUT_DIR"

SUMMARY="$OUT_DIR/summary.tsv"
printf 'prompt_id\ttotal_ms\tfirst_token_ms\teval_count\teval_duration_ms\ttok_per_sec\tcontent_chars\tthinking_chars\ttool_calls\n' > "$SUMMARY"

for N in 1 2 3 4 5; do
  PROMPT_FILE="$PROMPT_DIR/p${N}.txt"
  [[ -f "$PROMPT_FILE" ]] || { echo "skip p$N (missing)" >&2; continue; }

  echo "=== p$N ($RUNTIME think=$THINK) ===" >&2
  PROMPT_JSON=$(jq -Rs . < "$PROMPT_FILE")
  REQ_BODY=$(jq -n \
    --arg model "$MODEL" \
    --argjson content "$PROMPT_JSON" \
    --argjson think "$THINK" \
    '{model:$model, messages:[{role:"user", content:$content}], stream:true, think:$think, options:{num_predict:4096}}')

  STREAM_OUT="$OUT_DIR/p${N}.stream.jsonl"
  CONTENT_OUT="$OUT_DIR/p${N}.content.txt"
  THINK_OUT="$OUT_DIR/p${N}.thinking.txt"
  TOOL_OUT="$OUT_DIR/p${N}.toolcalls.json"
  FINAL_OUT="$OUT_DIR/p${N}.final.json"
  TIMING_OUT="$OUT_DIR/p${N}.timing.txt"

  : > "$STREAM_OUT"; : > "$CONTENT_OUT"; : > "$THINK_OUT"
  : > "$TOOL_OUT"; : > "$FINAL_OUT"
  rm -f "$TIMING_OUT"

  T_START=$(date +%s%N)

  curl -sN "$URL/api/chat" \
    -H "Content-Type: application/json" \
    -d "$REQ_BODY" \
  | while IFS= read -r LINE; do
      [[ -z "$LINE" ]] && continue
      printf '%s\n' "$LINE" >> "$STREAM_OUT"
      if [[ ! -f "$TIMING_OUT" ]]; then
        printf 'first_token_ns=%s\n' "$(date +%s%N)" > "$TIMING_OUT"
      fi
      C=$(printf '%s' "$LINE" | jq -r '.message.content // empty' 2>/dev/null || true)
      T=$(printf '%s' "$LINE" | jq -r '.message.thinking // empty' 2>/dev/null || true)
      TOOL=$(printf '%s' "$LINE" | jq -c '.message.tool_calls // empty' 2>/dev/null || true)
      DONE=$(printf '%s' "$LINE" | jq -r '.done // false' 2>/dev/null || true)
      [[ -n "$C" ]] && printf '%s' "$C" >> "$CONTENT_OUT"
      [[ -n "$T" ]] && printf '%s' "$T" >> "$THINK_OUT"
      [[ -n "$TOOL" && "$TOOL" != "null" ]] && printf '%s\n' "$TOOL" >> "$TOOL_OUT"
      if [[ "$DONE" == "true" ]]; then
        printf '%s\n' "$LINE" > "$FINAL_OUT"
      fi
    done

  T_END=$(date +%s%N)
  TOTAL_MS=$(( (T_END - T_START) / 1000000 ))
  if [[ -f "$TIMING_OUT" ]]; then
    FIRST_NS=$(grep -oE '[0-9]+' "$TIMING_OUT" | head -1)
    FIRST_MS=$(( (FIRST_NS - T_START) / 1000000 ))
  else
    FIRST_MS=0
  fi

  EVAL_COUNT=0
  EVAL_DUR_NS=0
  if [[ -s "$FINAL_OUT" ]]; then
    EVAL_COUNT=$(jq -r '.eval_count // 0' "$FINAL_OUT")
    EVAL_DUR_NS=$(jq -r '.eval_duration // 0' "$FINAL_OUT")
  fi
  EVAL_DUR_MS=$(( EVAL_DUR_NS / 1000000 ))
  if (( EVAL_DUR_NS > 0 )); then
    TOK_PER_SEC=$(awk -v n="$EVAL_COUNT" -v dur="$EVAL_DUR_NS" 'BEGIN { printf "%.2f", n / (dur/1e9) }')
  else
    TOK_PER_SEC="0"
  fi
  C_CHARS=$(wc -c < "$CONTENT_OUT" | tr -d ' ')
  T_CHARS=$(wc -c < "$THINK_OUT"  | tr -d ' ')
  TOOL_PRESENT=0
  [[ -s "$TOOL_OUT" ]] && TOOL_PRESENT=1

  printf 'p%d\t%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\n' \
    "$N" "$TOTAL_MS" "$FIRST_MS" "$EVAL_COUNT" "$EVAL_DUR_MS" "$TOK_PER_SEC" \
    "$C_CHARS" "$T_CHARS" "$TOOL_PRESENT" >> "$SUMMARY"
  printf '  total=%dms first=%dms eval=%d tok/s=%s content=%d think=%d tool=%d\n' \
    "$TOTAL_MS" "$FIRST_MS" "$EVAL_COUNT" "$TOK_PER_SEC" \
    "$C_CHARS" "$T_CHARS" "$TOOL_PRESENT" >&2
done

echo
echo "Summary: $SUMMARY"
column -t -s$'\t' "$SUMMARY"
