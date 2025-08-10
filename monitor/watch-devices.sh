#!/usr/bin/env bash
set -euo pipefail
CONFIG="${CONFIG:-monitor/devices.csv}"
LOG="${LOG:-monitor/watch.log}"
INTERVAL=10
TIMEOUT=1
RETRIES=3
JSON_OUTPUT=0
LOOP=0
STATE_FILE="${STATE_FILE:-monitor/.state}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --loop) LOOP=1;;
    --interval) INTERVAL="$2"; shift;;
    --timeout) TIMEOUT="$2"; shift;;
    --retries) RETRIES="$2"; shift;;
    --json) JSON_OUTPUT=1;;
    --help) echo "usage: $0 [--loop] [--interval N] [--timeout N] [--retries N] [--json]"; exit 0;;
    *) echo "unknown flag: $1" >&2; exit 2;;
  esac
  shift
done

probe_once(){
  local addr="$1" out
  if command -v fping >/dev/null 2>&1; then
    if out=$(fping -c1 -t $((TIMEOUT*1000)) "$addr" 2>&1); then
      PROBE_LATENCY=$(echo "$out" | grep -oE 'min/avg/max = [0-9.]+/[0-9.]+/[0-9.]+' | cut -d'/' -f2 || echo 0)
      return 0
    else
      return 1
    fi
  elif command -v ping >/dev/null 2>&1; then
    if [[ "$(uname)" == "Darwin" ]]; then
      out=$(ping -c1 -W $((TIMEOUT*1000)) "$addr" 2>&1) || return 1
    else
      out=$(ping -c1 -W "$TIMEOUT" "$addr" 2>&1) || return 1
    fi
    PROBE_LATENCY=$(echo "$out" | awk -F'time=' '/time=/{split($2,a," "); print a[1]; exit}' || echo 0)
    return 0
  else
    echo "No fping or ping available" >&2
    return 1
  fi
}

probe_host(){
  local name="$1" addr="$2" attempt=0 delay=1 state latency
  while (( attempt < RETRIES )); do
    if probe_once "$addr"; then
      state=UP
      latency="$PROBE_LATENCY"
      break
    else
      state=DOWN
      latency=0
      attempt=$(( attempt + 1 ))
      (( attempt < RETRIES )) && sleep "$delay" && delay=$(( delay * 2 ))
    fi
  done
  printf '%s,%s,%s,%s,%s\n' "$(date -Is)" "$state" "$name" "$addr" "$latency"
}

run_once(){
  mkdir -p "$(dirname "$LOG")"
  echo "=== start $(date -Is) ===" >>"$LOG"
  local tmpfile
  tmpfile=$(mktemp)
  while IFS=, read -r name addr _type; do
    [[ -z "${name// }" ]] && continue
    probe_host "$name" "$addr" >>"$tmpfile" &
  done < <(tail -n +2 "$CONFIG" | awk 'NF && $0 !~ /^[[:space:]]*#/')
  wait
  cat "$tmpfile" >>"$LOG"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    while IFS=, read -r ts state name addr latency; do
      printf '{"timestamp":"%s","state":"%s","name":"%s","addr":"%s","latency_ms":%s}\n' \
        "$ts" "$state" "$name" "$addr" "$latency"
    done < "$tmpfile"
  else
    cat "$tmpfile"
  fi
  declare -A prev
  [[ -f "$STATE_FILE" ]] && while IFS=, read -r n s; do prev["$n"]="$s"; done < "$STATE_FILE"
  local exit_status=0
: >"${STATE_FILE}.tmp"
  while IFS=, read -r ts state name addr latency; do
    [[ "$state" == "DOWN" ]] && exit_status=1
    if [[ -n "$WEBHOOK_URL" ]] && [[ "${prev[$name]:-}" != "$state" ]]; then
      curl -fsS -H 'Content-Type: application/json' \
        -d "$(printf '{"timestamp":"%s","state":"%s","name":"%s","addr":"%s","latency_ms":%s}' "$ts" "$state" "$name" "$addr" "$latency")" \
        "$WEBHOOK_URL" >/dev/null || true
    fi
    echo "$name,$state" >>"${STATE_FILE}.tmp"
  done < "$tmpfile"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
  rm "$tmpfile"
  return $exit_status
}

run_once
status=$?
if [[ "$LOOP" -eq 1 ]]; then
  while sleep "$INTERVAL"; do
    run_once
    status=$?
  done
fi
exit $status
