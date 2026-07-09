#!/bin/bash
# EssayPad 一键编译 + 重启脚本
# 编译后端 Go 二进制 + 客户端 macOS app,杀掉旧进程,启动新进程。
#
# 用法:
#   ./build_and_run.sh            # 完整流程
#   ./build_and_run.sh --no-build # 只重启,跳过编译
#   ./build_and_run.sh --client   # 只编译+重启客户端
#   ./build_and_run.sh --server   # 只编译+重启后端

set -e

REPO_ROOT="/Users/Shared/lab_project"
SERVER_DIR="$REPO_ROOT/essaypad/server"
MAC_DIR="$REPO_ROOT/essaypad/mac"
APP="$HOME/Applications/EssayPad.app"
LOG="/tmp/essaypad.log"
SDK=$(xcrun --sdk macosx --show-sdk-path)
TARGET="arm64-apple-macos14.0"

BUILD=1
CLIENT=1
SERVER=1

for arg in "$@"; do
  case $arg in
    --no-build) BUILD=0 ;;
    --client)   SERVER=0 ;;
    --server)   CLIENT=0 ;;
    --help|-h)
      echo "用法: $0 [选项]"
      echo "  --no-build   跳过编译,只重启"
      echo "  --client     只构建/重启客户端"
      echo "  --server     只构建/重启后端"
      exit 0
      ;;
  esac
done

cyan() { printf "\033[1;36m%s\033[0m\n" "$1"; }
green() { printf "\033[1;32m%s\033[0m\n" "$1"; }
red() { printf "\033[1;31m%s\033[0m\n" "$1"; }
yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }

kill_port() {
  local port=$1
  # lsof -ti 强杀占用端口的进程(最稳)
  local pids
  pids=$(lsof -ti :"$port" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    yellow "  杀掉占用端口 $port 的进程: $pids"
    echo "$pids" | xargs kill -9 2>/dev/null || true
    sleep 1
  fi
}

kill_app() {
  local name=$1
  local pids
  pids=$(pgrep -f "$name" || true)
  if [ -n "$pids" ]; then
    yellow "  杀掉 $name: $pids"
    echo "$pids" | xargs kill 2>/dev/null || true
    sleep 1
    # 强杀兜底
    pids=$(pgrep -f "$name" || true)
    if [ -n "$pids" ]; then
      echo "$pids" | xargs kill -9 2>/dev/null || true
      sleep 1
    fi
  fi
}

# ============== SERVER ==============
if [ "$SERVER" = "1" ]; then
  cyan "▶ 后端 Go 编译"
  if [ "$BUILD" = "1" ]; then
    (cd "$SERVER_DIR" && go build -o bin/essaypad .)
    green "  ✓ bin/essaypad 编译完成"
  else
    if [ ! -f "$SERVER_DIR/bin/essaypad" ]; then
      red "  ✗ bin/essaypad 不存在,需要先 build"
      exit 1
    fi
    yellow "  ⊘ 跳过编译(--no-build)"
  fi

  cyan "▶ 重启后端"
  kill_port 18888
  kill_app "essaypad/server/bin/essaypad"

  # 启动后端:用 at/bg 模式避开子 shell 等待
  cd "$SERVER_DIR" || exit 1
  # 把 nohup 写到独立脚本,执行后立即退出
  nohup ./bin/essaypad > "$LOG" 2>&1 &
  disown $! 2>/dev/null || true
  cd - > /dev/null

  sleep 2

  if curl -s --max-time 3 http://127.0.0.1:18888/health | grep -q ok; then
    green "  ✓ 后端已启动,健康检查 ok"
  else
    red "  ✗ 后端启动失败,查看日志: $LOG"
    tail -20 "$LOG"
    exit 1
  fi
fi

# ============== CLIENT ==============
if [ "$CLIENT" = "1" ]; then
  cyan "▶ 客户端 Swift 编译"
  if [ "$BUILD" = "1" ]; then
    SOURCES=$(find "$MAC_DIR/EssayPad" -name '*.swift' | sort)
    if [ -z "$SOURCES" ]; then
      red "  ✗ 找不到源文件"
      exit 1
    fi

    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

    if xcrun swiftc -O -target "$TARGET" -sdk "$SDK" \
        -o "$APP/Contents/MacOS/EssayPad" $SOURCES 2>&1; then
      green "  ✓ EssayPad 编译完成"
    else
      red "  ✗ 编译失败"
      exit 1
    fi
    codesign --force --deep --sign - "$APP" 2>&1 | tail -2
    green "  ✓ 签名完成"
  else
    yellow "  ⊘ 跳过编译(--no-build)"
  fi

  cyan "▶ 重启客户端"
  kill_app "EssayPad.app/Contents/MacOS/EssayPad"

  open "$APP"
  sleep 2
  if pgrep -f "EssayPad.app/Contents/MacOS/EssayPad" >/dev/null; then
    green "  ✓ 客户端已启动"
  else
    red "  ✗ 客户端启动失败"
    exit 1
  fi
fi

green ""
green "✓ 全部完成"
green "  后端: http://127.0.0.1:18888/health"
green "  客户端: $APP"
green "  日志: $LOG"
