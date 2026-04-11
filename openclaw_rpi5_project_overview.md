# OpenClaw + Raspberry Pi 5 プロジェクト概要
> Windows Claude / 新規参加者向け・ゼロから理解できる資料  
> 作成日：2026-04-12

---

## 1. このプロジェクトは何か

**個人開発者（Hiroyuki Miyashita / harieshokunin）が、AIエージェント「OpenClaw」を自宅ハードウェアで24/7稼働させ、リポジトリ開発・運用・自動化を実現するプロジェクト。**

- Claude Codeでは難しかった「デスクトップ操作・スクリーンショット・自律的リリース」を、OpenClaw + RPI5 + 既存環境で実現する
- 個人事業主としての開発速度と品質向上が最終目標

---

## 2. 現在の保有デバイス一覧

| デバイス | 名前 | スペック | 役割 |
|---|---|---|---|
| MacBook Pro | sg1atrantis-2 (macOS 15.7.4) | M2 Pro | **メイン開発機**（毎日使用・触らない） |
| Windows Tower | LAPTOP-9CPJP82V (Windows 11) | Ryzen 7 7700 + RTX 4070 Ti SUPER + 32GB DDR5 | 重い処理・Claude Code・ゲーム |
| iPhone | iphone174 (iOS 26.3.1) | — | 操作端末・iMessage |
| OCI Always Free VM | — | ARM Ubuntu・パブリックIP | 外部ゲートウェイ候補 |
| **Raspberry Pi 5** | **購入予定** | **8GB・スターターキット** | **OpenClaw実行エンジン・24/7稼働** |

**Tailscale**で全デバイスが同一プライベートネットワークに接続済み（3台接続確認済み）。

---

## 3. 購入決定事項

### Raspberry Pi 5 スターターキット（8GB）
- **購入先**: Amazon（Vesonn JP 出品・Amazon発送）
- **価格**: ¥31,964（税込）
- **セット内容**: 本体8GB・公式ケース（ファン付き）・電源5.1V/5A・64GB SD（OS済み）・HDMIケーブル・アクティブクーラー
- **技適**: 取得済み確認
- **理由**: OpenClaw + Cloud API中継専用なら8GBで十分。ランニングコスト年間¥1,900。

---

## 4. 全体アーキテクチャ（決定済み）

```
iPhoneから指示（iMessage / Telegram / Discord）
          ↓
OCI Always Free VM
（外部Webhook受付・パブリックIP・OpenClaw Gateway候補）
          ↓ Tailscale経由
RPI5-8GB（自宅・24/7稼働）
  ├─ OpenClaw Node（スキル実行・ブラウザ自動化・cron）
  ├─ 開発サンドボックス（本番MacBookと切り離し）
  └─ Claude Code（インストール予定）
          ↓ Tailscale経由
MacBook Pro M2 Pro（sg1atrantis-2）
  ├─ Claude Code（メイン開発）
  ├─ iMessage連携（BlueBubbles経由）
  └─ 本番開発機（OpenClawは走らせない）

Windows Tower（LAPTOP-9CPJP82V）
  ├─ Claude Code（重い処理・RTX 4070 Ti SUPER活用）
  └─ quickconv.cc バックエンド処理候補（別途検討）
```

**外部公開方法**: Cloudflare Tunnel または Tailscale Funnel（追加費用ゼロ）

---

## 5. ランニングコスト（年間）

| 項目 | 年額 |
|---|---|
| RPI5 電気代（7W・24/7） | 約 ¥1,900 |
| OCI Always Free VM | ¥0 |
| Tailscale（Personal・デバイス無制限） | ¥0 |
| Cloud API（Claude Max サブスク定額内） | ¥0 追加 |
| **合計** | **約 ¥1,900/年** |

※ Windows Towerを24/7サーバーにした場合：約¥27,000〜40,000/年（非推奨）

---

## 6. OpenClawとは

**OpenClaw（旧名：Clawdbot → Moltbot）**  
- オープンソースの自律型AIエージェント（GitHub Stars: 247,000+）
- LLMを使ってWhatsApp・Telegram・Slack・Discord・iMessageなどのメッセージプラットフォーム経由でタスクを実行
- 2025年11月登場、2026年1月にウイルスしてMac miniが品切れになるほど話題に
- 開発者：Peter Steinberger（オーストリア）→ 2026年2月にOpenAIに入社

### OpenClawでできること

| 機能 | 可否 | 備考 |
|---|---|---|
| メッセージ受信・返信 | ✅ | Telegram/Discord/Slack/iMessage等 |
| Cloud API中継（Claude/GPT） | ✅ | RPI5はゲートウェイのみ |
| ブラウザ自動化（Chromium） | ✅ | メモリ8GBで安定動作 |
| cron・定時タスク | ✅ | 毎朝ニュース収集・Slack投稿等 |
| デスクトップ操作 | ✅ | macOS/Windowsノード経由で可能 |
| スクリーンショット取得 | ✅ | iOSノード・macOSノード経由 |
| ファイル操作 | ✅ | |
| GitHub連携 | ✅ | Skills経由 |
| **完全無人・ゼロタッチ開発** | ❌ | 人間の確認ステップが設計上必要 |

### 重要な認識訂正

「要件を出すだけで開発・実装・運用・検証に一切タッチしない」は**現時点では実現しません**。  
ただし「iPhoneから指示 → Claude Codeが自律実行 → PR作成まで自動」という**ほぼ自律**な構成は実現可能。

---

## 7. やりたいことリスト（RPI5 + OpenClaw）

### メイン用途：OpenClaw AIエージェント
- [ ] OpenClaw Gateway インストール・設定
- [ ] Tailscale 経由で OCI VM・MacBook と接続
- [ ] セキュリティ設定（bind:127.0.0.1・認証トークン・allowFrom）
- [ ] Telegram / Discord / Slack チャンネル接続
- [ ] iMessage連携（MacBookのBlueBubbles経由）
- [ ] cron 定時タスク（毎朝ニュース収集・要約・Slack投稿）
- [ ] GitHub連携（リポジトリ監視・PR自動化）
- [ ] ブラウザ自動化スキル

### 開発自動化（Claude Code連携）
- [ ] `agent-base` リポジトリを起点にOpenClaw→Claude Code連携
- [ ] iPhoneから「このリポジトリのテスト直して」→ 自動実行・PR作成
- [ ] デスクトップ操作・スクリーンショットによる動作検証自動化

### 外部公開・ゲートウェイ
- [ ] Cloudflare Tunnel または Tailscale Funnel で外部公開（無料）
- [ ] OCI VM との役割分担（外部受付 → RPI5実行）

---

## 8. 管理リポジトリ一覧

| リポジトリ | 概要 |
|---|---|
| miyashita337/agent-base | エージェント基盤テンプレート（最重要） |
| miyashita337/claude-context-manager | Claudeセッション管理ユーティリティ（Rust製） |
| miyashita337/dev_tool | AutoHotkey v2スクリプト・開発ツール集 |
| miyashita337/segment-anything | AI画像セグメンテーション |
| miyashita337/video-qa | 動画QAシステム |
| miyashita337/obsidian_img_annotator | Obsidian画像アノテーター |
| miyashita337/claude-hub | Claudeハブ |
| miyashita337/vive-reading | 読書系ツール |
| miyashita337/discord-markdown-enhancer | Discord Markdown拡張 |
| miyashita337/team_salary | チーム給与管理 |
| miyashita337/team_salary_kdp | KDP（Kindle）収益管理 |
| miyashita337/team_salary_digital | デジタル収益管理 |
| miyashita337/team_salary_trading | トレーディング管理 |
| miyashita337/oci_develop | OCI開発環境 |

---

## 9. 別途進行中のタスク（別セッションで対応）

### quickconv.cc バックエンド処理の自宅化
- **サービス**: https://quickconv.cc（Cloudflare Workers運用中の画像・動画変換サービス）
- **アイデア**: 外部インスタンスの代わりにWindowsタワー（RTX 4070 Ti SUPER + FFmpeg NVEnc）で処理
- **構成**: Cloudflare Workers → Cloudflare Tunnel → Windows Tower
- **状態**: 設計検討中・別セッションでClaude Codeに依頼予定

---

## 10. 次のアクション

### 今すぐやること
1. **Amazonでスターターキット購入**（¥31,964・Vesonn JP・Amazon発送確認済み）
2. 届いたら開封・OS起動確認

### RPI5到着後
3. Tailscaleインストール・既存tailnetに追加
4. OpenClaw Gatewayセットアップ（`docs/install/raspberry-pi`参照）
5. Telegram チャンネル接続テスト
6. OCI VM との連携設定

### 新しいセッションで使う引き継ぎ文
```
RPI5-8GB スターターキット（Amazon ¥31,964）購入済み。
OCI Always Free VM・MacBook Pro M2 Pro（sg1atrantis-2）・
Windows Tower（LAPTOP-9CPJP82V）・Tailscale 全接続済み構成。
OpenClaw Gateway セットアップを開始したい。
セキュリティ設定（bind:127.0.0.1・認証トークン・allowFrom）まで一気に設定したい。
```

---

## 11. セキュリティ設定チェックリスト（OpenClaw必須）

| 優先度 | 設定 | 内容 |
|---|---|---|
| 🔴 必須 | Gateway bind | `127.0.0.1` に変更（デフォルト0.0.0.0はNG） |
| 🔴 必須 | 認証トークン | 256bit以上のランダムトークン設定 |
| 🔴 必須 | allowFrom | 自分の番号/IDのみ許可 |
| 🔴 必須 | 最新版に更新 | CVE-2026-25253（CVSS 8.8 RCE）等138件のCVEあり |
| 🟡 推奨 | APIキー分離 | `.env`ファイル化・`chmod 600` |
| 🟡 推奨 | elevated制限 | 自分のIDのみに限定 |
| 🟡 推奨 | mDNS最小化 | `OPENCLAW_DISABLE_BONJOUR=1` |
| 🟢 任意 | NVMe SSD化 | SDカードより信頼性が高い（後回しOK） |

---

*このドキュメントは2026-04-12時点の情報をもとに作成。*
