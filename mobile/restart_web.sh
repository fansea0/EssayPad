#!/usr/bin/env bash
# EssayPad Mobile Web: build and restart the local static page service.
# Usage:
#   ./restart_web.sh
#   ./restart_web.sh --no-build --port 4180

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=4180
BUILD=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build) BUILD=0 ;;
    --port)
      PORT="${2:?--port requires a port number}"
      shift
      ;;
    --help|-h)
      printf 'Usage: %s [--no-build] [--port PORT]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

PID_FILE="/tmp/essaypad-mobile-web-$PORT.pid"
LOG_FILE="/tmp/essaypad-mobile-web-$PORT.log"

info() { printf '\033[1;36m%s\033[0m\n' "$1"; }
success() { printf '\033[1;32m%s\033[0m\n' "$1"; }
error() { printf '\033[1;31m%s\033[0m\n' "$1" >&2; }

stop_previous() {
  local pids
  pids="$(lsof -ti ":$PORT" 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    info "Stopping service on port $PORT: $pids"
    kill $pids 2>/dev/null || true
    sleep 1
  fi
  pids="$(lsof -ti ":$PORT" 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    kill -9 $pids 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
}

cd "$SCRIPT_DIR"

if [[ "$BUILD" == "1" ]]; then
  info 'Building Flutter Web release bundle'
  flutter build web --release
elif [[ ! -f build/web/index.html ]]; then
  error 'build/web/index.html is missing; run without --no-build first.'
  exit 1
fi

stop_previous

info "Starting static page service on port $PORT"
nohup python3 -m http.server "$PORT" --directory build/web >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

for _ in {1..10}; do
  if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
    success "EssayPad Mobile Web is running: http://127.0.0.1:$PORT"
    success "PID: $(cat "$PID_FILE")  Log: $LOG_FILE"
    exit 0
  fi
  sleep 1
done

error "Page service failed to start. Check $LOG_FILE"
tail -20 "$LOG_FILE" 2>/dev/null || true
exit 1
