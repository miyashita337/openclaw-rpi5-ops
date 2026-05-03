#!/usr/bin/env bash
# scripts/verify-wayvnc.sh
# wells (trixie + Pi5 + labwc) で WayVNC を実機検証するための一発スクリプト。
#
# 使い方 (Mac 側ターミナルから):
#   ssh harieshokunin@wells 'bash -s' < ~/openclaw-rpi5-ops/scripts/verify-wayvnc.sh
# または wells に SSH 後:
#   bash ~/openclaw-rpi5-ops/scripts/verify-wayvnc.sh
#
# 結果は /tmp/wayvnc-verify-YYYYMMDD-HHMMSS.log に保存される。
# 全文をチャットに貼ってください。

set -uo pipefail
LOG=/tmp/wayvnc-verify-$(date +%Y%m%d-%H%M%S).log

# 全出力を log にも書く
exec > >(tee "$LOG") 2>&1

hr() { printf '\n────────────────────────────────────────\n%s\n────────────────────────────────────────\n' "$1"; }

echo "=== WayVNC verification on $(hostname) at $(date -Iseconds) ==="

hr "1. 環境情報"
. /etc/os-release; echo "OS:           $PRETTY_NAME ($VERSION_CODENAME)"
echo "Kernel:       $(uname -srm)"
echo "Desktop:      ${XDG_CURRENT_DESKTOP:-unknown}"
echo "Session:      ${XDG_SESSION_TYPE:-unknown}"
echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-(none)}"
labwc --version 2>/dev/null | head -1 || echo "labwc: not installed (no GUI session?)"

hr "2. wayvnc パッケージ状態(現在)"
dpkg -l wayvnc 2>/dev/null | tail -1 || echo "wayvnc: not installed yet"
dpkg -l neatvnc 2>/dev/null | tail -1 || echo "neatvnc: not installed yet"

hr "3. インストール(既に入っていればスキップ)"
sudo apt-get update -qq
sudo apt-get install -y wayvnc tigervnc-tools 2>&1 | tail -5

hr "4. バージョン情報"
wayvnc --version 2>&1 | head -3 || true

hr "5. systemd user service の有無"
systemctl --user list-unit-files 2>/dev/null | grep -i wayvnc || echo "(user service なし — on-demand 起動 or 自前で .service を書く必要あり)"
ls /etc/systemd/system/ /usr/lib/systemd/system/ 2>/dev/null | grep -i wayvnc | head -5 || echo "(system service なし)"

hr "6. 既存の listen 状態(起動前)"
ss -tlnp 2>/dev/null | grep -E ':5900|wayvnc' || echo "port 5900: nobody listening"

hr "7. on-demand 起動テスト(foreground 8秒)"
echo "[wayvnc を 0.0.0.0:5900 で 8秒間バックグラウンド起動して状態を確認します]"

# WAYLAND_DISPLAY が無いと wayvnc は起動できない
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "⚠️  WAYLAND_DISPLAY が未設定 → SSH セッションからは Wayland に届かない。"
    echo "    解決策: GUI ログイン中に同じユーザーで実行する or systemd --user で起動する。"
    echo "    今回は起動テストをスキップし、想定 .service ファイル例を表示します。"
    cat <<'EOF'

[~/.config/systemd/user/wayvnc.service の雛形]
[Unit]
Description=WayVNC server
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/wayvnc 0.0.0.0 5900
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
else
    timeout 8 wayvnc 0.0.0.0 5900 &
    WAYVNC_PID=$!
    sleep 3
    echo "--- 起動後 3秒の listen 状態 ---"
    ss -tlnp 2>/dev/null | grep -E ':5900|wayvnc' || echo "(listen 失敗)"
    echo "--- プロセス ---"
    ps -p "$WAYVNC_PID" -o pid,ppid,cmd 2>/dev/null || echo "(プロセス終了済)"
    wait "$WAYVNC_PID" 2>/dev/null || true
    echo "--- 終了後 ---"
    ss -tlnp 2>/dev/null | grep -E ':5900|wayvnc' || echo "port 5900: 解放済み"
fi

hr "8. Tailscale 接続性(VNC を Tailnet 内に閉じるための前提)"
if command -v tailscale >/dev/null 2>&1; then
    echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo none)"
    tailscale status 2>/dev/null | head -5 || echo "(tailscale status 取得失敗)"
else
    echo "tailscale: 未インストール"
fi

hr "9. 既知バグの該当チェック"
echo "[forum 395430 / 393161 / 395318 で報告されている事象]"
echo "- port 5900 競合(他の VNC server が居ないか): "
ss -tlnp 2>/dev/null | grep ':5900' || echo "  → 該当なし"
echo "- realvnc-vnc-server が共存していないか: "
dpkg -l realvnc-vnc-server 2>/dev/null | tail -1 || echo "  → 該当なし(クリーン)"

hr "10. 完了"
echo "ログ全文: $LOG"
echo
echo "次のアクション(Mac 側で実施):"
echo "  1. brew install --cask tigervnc-viewer  (または App Store の VNC Viewer)"
echo "  2. wells を tailscale ip -4 で確認した 100.x.x.x:5900 へ接続"
echo "  3. 接続成否・遅延・日本語入力の打ち心地をメモ"
