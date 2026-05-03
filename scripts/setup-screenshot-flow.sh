#!/bin/bash
# setup-screenshot-flow.sh - スクショ自動化セットアップ (一回だけ実行)
#
# やること:
#   A. macOS スクショの保存先を workspace の screenshots/ に変更
#   B. pngpaste をインストールして clipsave コマンドを PATH に登録

set -euo pipefail

WORKSPACE="$HOME/openclaw-rpi5-ops"
SCRIPTS_DIR="$WORKSPACE/scripts"
SCREENSHOT_DIR="$WORKSPACE/screenshots"

echo "==> [A] スクショ保存先を変更"
mkdir -p "$SCREENSHOT_DIR"
defaults write com.apple.screencapture location "$SCREENSHOT_DIR"
killall SystemUIServer
echo "    → $SCREENSHOT_DIR"

echo "==> [B] pngpaste をインストール"
if command -v pngpaste >/dev/null 2>&1; then
  echo "    すでにインストール済み: $(pngpaste -v 2>&1 | head -1 || echo present)"
else
  if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew が見つかりません。https://brew.sh からインストールしてください" >&2
    exit 1
  fi
  brew install pngpaste
fi

echo "==> [B] clipsave コマンドを PATH に登録"
chmod +x "$SCRIPTS_DIR/clipsave.sh"

# PATH に通っている書き込み可能な bin ディレクトリを探す
LINK_TARGET=""
for dir in "/opt/homebrew/bin" "/usr/local/bin" "$HOME/.local/bin"; do
  if [[ -d "$dir" ]] && [[ ":$PATH:" == *":$dir:"* ]] && [[ -w "$dir" ]]; then
    LINK_TARGET="$dir/clipsave"
    break
  fi
done

if [[ -n "$LINK_TARGET" ]]; then
  ln -sf "$SCRIPTS_DIR/clipsave.sh" "$LINK_TARGET"
  echo "    → $LINK_TARGET (symlink)"
else
  echo "    PATH 内に書き込み可能な bin が見つからないので alias を提案します:"
  echo ""
  echo "    次の行を ~/.zshrc または ~/.bash_profile に追加してください:"
  echo "        alias clipsave='$SCRIPTS_DIR/clipsave.sh'"
  echo ""
fi

cat <<EOF

==> セットアップ完了

【macOS スクショショートカット早見表】
  ┌─────────────────────────┬──────────────┬─────────────────┐
  │ ショートカット          │ 保存先       │ 取り出し方      │
  ├─────────────────────────┼──────────────┼─────────────────┤
  │ Cmd+Shift+3 / 4 / 5     │ ファイル     │ A の保存先変更  │
  │ Cmd+Ctrl+Shift+3 / 4    │ クリップボード │ B の clipsave   │
  └─────────────────────────┴──────────────┴─────────────────┘

【A: ファイル保存系】
  Cmd+Shift+4 等で撮ったスクショは自動的に下記に保存されます:
    $SCREENSHOT_DIR

【B: クリップボード系】
  Cmd+Ctrl+Shift+4 でコピー後、ターミナルで:
    clipsave                              # screenshots/ にタイムスタンプ名
    clipsave 01-tailscale-admin           # screenshots/01-tailscale-admin.png
    clipsave 01-tailscale-admin images/zenn-article-02-tailscale
                                          # images/zenn-article-02-tailscale/01-tailscale-admin.png

【A の保存先を元に戻す場合】
  defaults delete com.apple.screencapture location
  killall SystemUIServer
EOF
