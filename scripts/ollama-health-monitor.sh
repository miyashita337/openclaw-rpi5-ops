#!/bin/bash
# win-ollama (uss-enterprise) health monitor for wells (Issue #36)
#
# OpenClaw Gateway のバックエンド LLM ホスト (100.123.241.106:11434) を
# 定期ヘルスチェックし、状態遷移 (UP→DOWN / DOWN→UP) を Pushover 通知する。
# 背景: uss-enterprise が 38 日間オフラインでも誰も気づかなかった (Epic #34)。
#
# 設計メモ:
# - ~/network-monitor/monitor.sh (Mac 版とペアの ping 監視) には統合しない。
#   あちらは Mac 側と同一実装を保つ制約があり、HTTP チェック + 通知を足すと
#   ペア性が壊れるため別ユニットとして分離 (Issue #36 記載の判断基準)。
# - 瞬断での誤通知を避けるため、連続 FAIL_THRESHOLD 回失敗で初めて DOWN 判定。

set -u

TARGET_URL="${OLLAMA_HEALTH_URL:-http://100.123.241.106:11434/api/version}"
TARGET_NAME="${OLLAMA_HEALTH_NAME:-win-ollama}"
INTERVAL_SEC="${OLLAMA_HEALTH_INTERVAL_SEC:-60}"
FAIL_THRESHOLD="${OLLAMA_HEALTH_FAIL_THRESHOLD:-3}"
CURL_TIMEOUT_SEC="${OLLAMA_HEALTH_CURL_TIMEOUT_SEC:-5}"
LOG_DIR="${OLLAMA_HEALTH_LOG_DIR:-$HOME/ollama-health-monitor}"
NOTIFY_SCRIPT="${OLLAMA_HEALTH_NOTIFY_SCRIPT:-$HOME/agent-base/scripts/pushover-notify.sh}"
LOG_MAX_BYTES=$((1024 * 1024))

LOG_FILE="$LOG_DIR/health.log"
STATE_FILE="$LOG_DIR/state"
DOWN_SINCE_FILE="$LOG_DIR/down_since"
FAIL_COUNT_FILE="$LOG_DIR/fail_count"
mkdir -p "$LOG_DIR"

log() {
  printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

rotate_log_if_needed() {
  [ -f "$LOG_FILE" ] || return 0
  local size
  size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$size" -gt "$LOG_MAX_BYTES" ]; then
    mv "$LOG_FILE" "$LOG_FILE.1"
    log "ROTATE	previous log moved to health.log.1"
  fi
}

notify() {
  local title="$1" message="$2" priority="$3"
  if [ ! -x "$NOTIFY_SCRIPT" ] && [ ! -f "$NOTIFY_SCRIPT" ]; then
    log "NOTIFY_FAIL	script not found: $NOTIFY_SCRIPT"
    return 1
  fi
  if ! bash "$NOTIFY_SCRIPT" "$title" "$message" "$priority" >/dev/null 2>&1; then
    # 通知失敗を握りつぶさずログに残す (agent-output-quality #1)
    log "NOTIFY_FAIL	pushover send failed: $title"
    return 1
  fi
  log "NOTIFY	$title"
}

check_once() {
  curl -sf -m "$CURL_TIMEOUT_SEC" "$TARGET_URL" >/dev/null 2>&1
}

format_duration() {
  local sec="$1"
  printf '%dh%02dm' $((sec / 3600)) $((sec % 3600 / 60))
}

prev_state="UP"
[ -f "$STATE_FILE" ] && prev_state=$(cat "$STATE_FILE")
fail_count=0
[ -f "$FAIL_COUNT_FILE" ] && fail_count=$(cat "$FAIL_COUNT_FILE")

log "STARTUP	ollama-health-monitor PID=$$ url=$TARGET_URL interval=${INTERVAL_SEC}s threshold=$FAIL_THRESHOLD"
trap 'log "SHUTDOWN	ollama-health-monitor PID=$$"; exit 0' TERM INT

while true; do
  rotate_log_if_needed

  if check_once; then
    fail_count=0
    if [ "$prev_state" = "DOWN" ]; then
      down_since=$(cat "$DOWN_SINCE_FILE" 2>/dev/null || date '+%s')
      duration=$(( $(date '+%s') - down_since ))
      log "RECOVER	$TARGET_NAME	downtime=$(format_duration "$duration")"
      notify "$TARGET_NAME RECOVER" "$TARGET_NAME が復旧しました (down時間: $(format_duration "$duration"))" 0
      rm -f "$DOWN_SINCE_FILE"
    fi
    prev_state="UP"
  else
    fail_count=$((fail_count + 1))
    log "FAIL	$TARGET_NAME	consecutive=$fail_count"
    if [ "$prev_state" = "UP" ] && [ "$fail_count" -ge "$FAIL_THRESHOLD" ]; then
      log "DROP	$TARGET_NAME	after $fail_count consecutive failures"
      date '+%s' > "$DOWN_SINCE_FILE"
      notify "$TARGET_NAME DOWN" "$TARGET_NAME ($TARGET_URL) が ${fail_count} 回連続で応答しません。polka の LLM バックエンドが停止しています。" 1
      prev_state="DOWN"
    fi
  fi

  echo "$prev_state" > "$STATE_FILE"
  echo "$fail_count" > "$FAIL_COUNT_FILE"
  sleep "$INTERVAL_SEC"
done
