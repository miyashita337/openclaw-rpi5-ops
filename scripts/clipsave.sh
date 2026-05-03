#!/bin/bash
# clipsave - クリップボードの画像を workspace に保存する
#
# 使い方:
#   clipsave                       -> screenshots/screenshot-YYYYMMDD-HHMMSS.png
#   clipsave myname                -> screenshots/myname.png
#   clipsave myname images/zenn-article-02-tailscale
#                                  -> images/zenn-article-02-tailscale/myname.png
#   clipsave myname /abs/path      -> /abs/path/myname.png
#
# 依存: pngpaste (Homebrew: `brew install pngpaste`)

set -euo pipefail

WORKSPACE="$HOME/openclaw-rpi5-ops"
DEFAULT_DIR="$WORKSPACE/screenshots"

# 引数解釈
NAME="${1:-screenshot-$(date +%Y%m%d-%H%M%S)}"
DIR="${2:-$DEFAULT_DIR}"

# .png 拡張子を強制
[[ "$NAME" == *.png ]] || NAME="${NAME}.png"

# 相対パスは workspace 基準で解釈
[[ "$DIR" = /* ]] || DIR="$WORKSPACE/$DIR"

mkdir -p "$DIR"

# pngpaste が無ければ案内して終了
if ! command -v pngpaste >/dev/null 2>&1; then
  echo "Error: pngpaste が見つかりません。次でインストールしてください:" >&2
  echo "  brew install pngpaste" >&2
  exit 127
fi

# クリップボードから保存
if pngpaste "$DIR/$NAME" 2>/dev/null; then
  echo "Saved: $DIR/$NAME"
else
  echo "Error: クリップボードに画像がありません" >&2
  exit 1
fi
