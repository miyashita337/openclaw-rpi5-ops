# OpenClaw on RPi5 実装チェックリスト

> 4専門家エージェント(Security/SRE/テクニカルライター/RPi-ARM)の合意点を時系列に分解。
> 本丸方針: ハイブリッド(本番=Lite+SSH, GUI必要時のみWayVNC on-demand)。
> 作成日: 2026-05-03

---

## Day 0 (RPi5受け取り・初回ブート)

- [ ] **OS選択**: Raspberry Pi OS 13 (trixie) 64-bit **Lite** をインストール (Desktop 版は入れない)
- [ ] HDMI + USB キーボードで初回ブート → `raspi-config`:
  - [ ] `Interface Options > SSH` 有効化
  - [ ] `System Options > Hostname` を `wells` に
  - [ ] `Localisation Options > Locale` で `ja_JP.UTF-8` 生成
  - [ ] `Advanced Options > Boot Order` を NVMe/USB Boot に変更(NVMe 移行後に有効化)
- [ ] Tailscale インストール: 公式 keyring を `/etc/apt/keyrings/` に配置(deb822形式・**`apt-key add` は使わない**)
- [ ] `tailscale up --ssh` で Tailnet に追加・Tailscale SSH 有効化
- [ ] `tailscale set --accept-dns=false` の必要性を `/etc/resolv.conf` の symlink 先で判断

## Day 1 (基盤確定)

- [ ] **NVMe ルート移行**(SD ルートは捨てる、6-18ヶ月で死ぬため):
  - [ ] `sudo apt install piclone`(`rpi-clone` は trixie + Pi5 で partition naming バグあり、使わない)
  - [ ] `sudo piclone -s /dev/mmcblk0 -d /dev/nvme0n1 -n` (新 PARTUUID を発行)
  - [ ] `sudo raspi-config` で Boot Order を NVMe/USB Boot に
  - [ ] 再起動して `lsblk` で `/` が `nvme0n1p2` 由来になっていることを確認
- [ ] **dhcpcd → NetworkManager 統一**(trixie 既定):
  - [ ] `systemctl disable --now dhcpcd`
  - [ ] `systemctl enable --now NetworkManager`
  - [ ] `nmcli` で接続を再構成
- [ ] **DNS resolver 確認**: `ls -l /etc/resolv.conf` で symlink 先確認、Tailscale MagicDNS との競合がないか

## Week 1 (OpenClaw 導入)

- [ ] **install.sh の安全な実行手順**(`curl|bash` 直は禁止):
  - [ ] `curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh`
  - [ ] `sha256sum /tmp/openclaw-install.sh` を公式公開ハッシュと照合
  - [ ] `less /tmp/openclaw-install.sh` で内容を目視確認
  - [ ] `bash /tmp/openclaw-install.sh` を実行
  - [ ] **公式が `.sha256` も `.sig` も提供していない場合**は運用適格性の Red flag として記録
- [ ] **system user 作成**: `sudo useradd --system --no-create-home --shell /usr/sbin/nologin openclaw`
- [ ] **systemd unit を自前で書く**(hardening 込み、`/etc/systemd/system/openclaw-gateway.service`):
  ```ini
  [Unit]
  Description=OpenClaw Gateway
  After=network-online.target tailscaled.service
  Wants=network-online.target
  StartLimitIntervalSec=300
  StartLimitBurst=5

  [Service]
  Type=notify
  WatchdogSec=60s
  ExecStart=/usr/local/bin/openclaw-gateway
  Restart=on-failure
  RestartSec=10s
  User=openclaw
  Group=openclaw
  EnvironmentFile=/etc/openclaw/openclaw.env
  NoNewPrivileges=yes
  ProtectSystem=strict
  ProtectHome=yes
  PrivateTmp=yes
  ReadWritePaths=/var/lib/openclaw /var/log/openclaw
  ProtectKernelTunables=yes
  ProtectKernelModules=yes
  RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
  LockPersonality=yes
  MemoryDenyWriteExecute=yes
  MemoryMax=2G
  TasksMax=512

  [Install]
  WantedBy=multi-user.target
  ```
  - [ ] `Type=notify` を OpenClaw が対応している前提。非対応なら wrapper script で `/healthz` を curl して `sd_notify` する
- [ ] **OpenClaw 設定**:
  - [ ] bind: `127.0.0.1` のみ
  - [ ] 認証トークン: `openssl rand -hex 32` で 256bit 生成
  - [ ] allowFrom: 自分のチャンネルID/ユーザーIDのみ許可
- [ ] **secrets**: `/etc/openclaw/openclaw.env` を `chmod 600 root:openclaw`、`EnvironmentFile=` で読む
- [ ] **自動更新**: `unattended-upgrades` を on(個人で patch 追えない前提)
- [ ] **OpenClaw CVE 追跡**: 週次で CVE フィードを Slack に流す cron を仕込む(または GitHub Dependabot 連携)

## Week 2 (運用基盤)

- [ ] **journald 設定** (`/etc/systemd/journald.conf`):
  - [ ] `SystemMaxUse=500M`
  - [ ] `SystemMaxFileSize=200M`
  - [ ] `Compress=yes`
- [ ] **swap**: SD swap=0 を維持(`/etc/dphys-swapfile`)、必要なら NVMe に 1GB だけ
- [ ] **熱・throttling 監視**:
  - [ ] `vcgencmd measure_temp` を 1分 cron で `/var/log/openclaw/thermal.log` へ追記
  - [ ] `vcgencmd get_throttled` が `0x0` 以外を返したら Telegram 通知
- [ ] **バックアップ**(restic 一択):
  - [ ] バックアップ先: Cloudflare R2 Free 10GB または Backblaze B2 Free 10GB
  - [ ] 対象: `/etc/openclaw`, `/var/lib/openclaw`, `~/.config/tailscale`, Ansible vault, GH SSH 鍵
  - [ ] スケジュール: 日次 incremental + 週次 forget --keep-daily 7 --keep-weekly 4
- [ ] **secrets 暗号化コミット**: SOPS + age を `openclaw-rpi5-ops` に導入、git に暗号化コミット可能化
- [ ] **外形監視**: Cloudflare Workers Cron(無料枠)で 5分毎に `/healthz` を叩き、失敗で Telegram 通知

## Week 3 (公開設計 Phase 2 — 必要時のみ)

- [ ] **Cloudflare Tunnel(cloudflared)を RPi5 に直結**(インバウンドポート開放不要):
  - [ ] cloudflared インストール(`/etc/apt/keyrings/` 経由・deb822)
  - [ ] tunnel token は SOPS 暗号化
  - [ ] `tunnel ingress` で OpenClaw だけを限定公開
- [ ] **Cloudflare Access(Zero Trust)を前段に**:
  - [ ] IdP / Email OTP / GitHub SSO + MFA を強制
  - [ ] Service Token で Webhook 受信を許可(Telegram bot 等)
- [ ] **OpenClaw 側 HMAC 署名検証**を実装
- [ ] **OCI VM の処遇**: プロジェクト概要 v4 で「実験用」に降格 or 削除(エンジニア3名一致の推奨)
- [ ] **Tailscale Funnel は不採用**(OpenClaw のような CVE 多数アプリには公開リスク高)

## Week 4 (自動化・nightly)

- [ ] **systemd timer**(cron の代替):
  - [ ] `OnCalendar=*-*-* 06:30:00`
  - [ ] `RandomizedDelaySec=300` (thundering herd 防止)
  - [ ] `Persistent=true` (停電復帰後にキャッチアップ)
- [ ] **冪等性**:
  - [ ] 各タスクは `run_id` を生成、`/var/lib/openclaw/runs/<id>/state.json` に進捗保存
  - [ ] Slack 投稿等の side effect には `idempotency_key`
  - [ ] 長尺ワークフローは SQLite ベース job queue(`litequeue`) または file-based `task spooler`
- [ ] **失敗時挙動**:
  - [ ] 指数バックオフ + jitter
  - [ ] max 5回リトライ
  - [ ] dead-letter ファイルに退避
- [ ] **ログ redaction**:
  - [ ] systemd unit に `LogFilterPatterns=` で `(?i)(token|api[_-]?key|bearer|authorization|secret)=[^\s]+` をマスク
  - [ ] Slack 投稿前に必ず redaction を挟む
- [ ] **送信先 channel allowlist**(Telegram/Discord/Slack)
- [ ] **secrets 階層昇格**(Tier 1 → Tier 2):
  - [ ] `.env` から SOPS+age または 1Password CLI へ 1ヶ月以内に移行
  - [ ] HashiCorp Vault は個人運用には過剰、不採用

## 物理 break-glass(最後の砦)

- [ ] Cloudflare Access / Tailscale 同時障害時の復旧手順を **紙1枚に印刷して RPi5 ケースに貼る**:
  - HDMI + USB キーボード接続
  - 物理ログイン → `tailscale up --auth-key <旧key>` で復旧

## 後日: RD 検証(ハイブリッド方針)

- [ ] WayVNC on-demand 起動で実機検証(`apt install wayvnc`、`systemctl --user start/stop wayvnc`)
- [ ] Raspberry Pi Connect の Issue #70 修正状況を確認
- [ ] xrdp + Xorg fallback の挙動確認
- [ ] **記事化** → GH issue で追跡(`.github/ISSUE_DRAFT_rd-verification-article.md` 参照)

---

## 連載構成(編集者推奨)

| # | 記事 | 状態 |
|---|---|---|
| 02 | RPi5 + Tailscale | 明日投稿予定 |
| 03 | OpenClaw SSH本番インストール | 別セッションで執筆 |
| 04 | Tailscale Funnel で OpenClaw Web UI 公開 | 後日 |
| 05 | Cloudflare Tunnel + Access(MFA)で Webhook 受付 | 後日 |
| 06 | OpenClaw セキュリティ全網羅(CVE 138件再検証含む) | 後日 |
| 07 | cron + Telegram + iPhone から PR 自動化 | 後日 |
| 別軸 | RD検証記事(WayVNC vs Pi Connect vs xrdp) | GH issue 追跡 |

---

## 必ず記事化前に再検証する数値・事実

- OpenClaw CVE 138件・41% High/Critical(プロジェクト概要 v3 由来、独立未検証)→ NVD/CVE.org で再確認
- Pi Connect Issue #70 の現在の状態(2026-05-03 時点で active と記載されている、修正済の可能性も)
- Tailscale 越し WayVNC の IPv6 ICE STUN packet loss 34% 報告(個別環境差あり、実機計測)
- OCI Always Free 7日 reclaim ポリシー(2026-05時点の Oracle 規約を再確認)

---

## 参照ファイル

- `openclaw_rpi5_project_overview.md` — プロジェクト概要 v3
- `zenn-article-02-tailscale.md` — 連載 02
- `docs/superpowers/specs/2026-04-12-openclaw-rpi5-ops-design.md` — 設計仕様
- `.github/ISSUE_DRAFT_rd-verification-article.md` — RD 検証記事用 GH issue 下書き
