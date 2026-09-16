# ドメインエキスパート: 自宅サーバ運用（RPi5 + OpenClaw + self-hosted LLM）

## プロジェクト概要

Raspberry Pi 5（`wells`）上の OpenClaw Gateway / Discord Bot「polka」を、Windows タワー（`uss-enterprise`）の Ollama をバックエンドに 24h 運用する。運用スクリプト・systemd ユニット・Zenn 連載記事を管理する。環境の正本は `README.md`「環境一覧」。

## ドメイン知識

- **非対称分担**: Discord 受信は wells（8 GB、27B モデルはロード不能）、推論は uss-enterprise（RTX 4070 Ti SUPER 16 GB）。wells にローカル LLM を置く提案はしない
- **経路は Tailscale**: `win-ollama` = `scripts/ollama-health-monitor.sh` の `TARGET_URL` 先（= Mac の `ssh win11` と同一機、SSH ホスト鍵一致で確認済み）。旧設計メモの LAN アドレスは無効
- **Windows は落ちる前提**: 38 日 / 16 日のオフライン前歴。監視は `ollama-health-monitor`（#36）、常時稼働化は #37 未完
- **Windows への SSH 鍵は未登録**: BatchMode では入れない。鍵登録はユーザーのパスワード入力が要る（Claude は代行しない）
- **OpenClaw gateway は hardening 済み systemd ユニット**（記事 #5）。`ProtectSystem=strict` / `SystemCallFilter` / `MemoryMax=2G` を崩す変更は理由必須
- **Qwen3.6 系は `/api/chat` + `think:false`**（OpenAI 互換 `/v1` では thinking が混入、#14）

## 技術スタック

- wells: Debian 13 trixie / aarch64 / OpenClaw 2026.5.x / node 22 / systemd（system + user unit）/ wayvnc / rpi-connect
- uss-enterprise: Windows 11 / Ollama native / OpenSSH for Windows / schtasks `OllamaServe`
- Mac: Claude Code / Cowork / gh / Tailscale。`.claude/settings.json` で `ssh wells` 許可、`cat` `curl` `sudo` `bash` は deny（ファイルは Read tool、HTTP は wells 経由 `curl`）
- 記事: Zenn CLI（`npx zenn preview`）

## レビュー時の重点チェック項目

- 機密（Discord token、Pushover key、`/etc/openclaw/openclaw.env`、`.env`）をコミット・出力していないか。リポは **PUBLIC**
- systemd hardening を弱める変更に根拠があるか
- 監視・通知の変更で「送った」ではなく「届いた」を検証しているか（Pushover 受信 / Discord 到達）
- Windows 依存の手順に「ユーザー操作が必要」と明示されているか（鍵未登録のため自動化できない箇所）
- 記事本文が gitignore 済み `docs/` を参照していないか（公開時にリンク切れ）
