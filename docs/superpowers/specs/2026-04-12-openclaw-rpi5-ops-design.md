# OpenClaw + Raspberry Pi 5 Ops — 設計仕様書

**作成日**: 2026-04-12
**ステータス**: Draft（初版）
**作成方法**: brainstorming セッションで固めた設計を spec 化

---

## 1. プロジェクト要約

個人開発者（Hiroyuki Miyashita / harieshokunin）のリポジトリ開発・運用を自動化するため、OpenClaw を Raspberry Pi 5 上で 24/7 稼働させる。iPhone からの要件指示に対して **承認 2 箇所（Visual AC 確認 + PR マージ）** でほぼ自律的に「要件 → 実装 → 検証 → PR → デプロイ」を回す。

### 非機能要件（優先度順）

| 順位 | 要件 | 根拠 |
|---|---|---|
| 1 | **出戻りゼロ** を最優先 | brainstorming で「出戻り嫌」と明示された最重要要件 |
| 2 | 承認は 2 箇所・各 1 タップ・合計 10 秒以内 | モデル 2 採用 |
| 3 | 24/7 安定稼働 | NVMe SSD 化・熱対策・公式 PSU |
| 4 | セキュリティ必須 | OpenClaw CVE 138 件・41% High/Critical |
| 5 | ランニングコスト年間 ¥2,000 以下 | RPi5 電気代のみ |

### 何を達成しないか（YAGNI）

- ❌ 完全無人ゼロタッチ（LLM の要件解釈能力に律速される領域）
- ❌ Windows デスクトップ GUI 操作（公式対応未確認、quickconv.cc 用途には不要）
- ❌ RPi5 上で LLM ローカル実行（OpenClaw 公式が「クラウド API で実行」と明記）
- ❌ iMessage / BlueBubbles 連携（MacBook スリープ化と両立不能のため除外）

---

## 2. システム構成

### 2.1 ハードウェア（購入確定・2026-04-12 発注済み）

| 要素 | 型番 / 仕様 | ASIN | 価格（税込） | 到着予定 |
|---|---|---|---|---|
| Raspberry Pi 5 8GB + 付属品一式 | Vesiri Raspberry Pi 5 Starter Kit（8GB・Active Cooler・PD PSU・64GB SD・ABS ケース・MicroHDOUT ケーブル・カードリーダー・日本語マニュアル） | B0CTQRCH8H | ¥31,964 | 2026-04-13（明日） |
| M.2 HAT+ 対応ケース | GeeekPi DeskPi Lite Pi5（電源ボタン・PCIe to M.2 HAT・Active Cooler・デュアルフルサイズ HDMI・M.2 NVMe M-Key 2230/2242/2260/**2280** 対応） | B0DPH2DYBP | ¥6,500 | 2026-04-13（明日） |
| NVMe SSD 256GB | Silicon Power P34A60 256GB 3D NAND M.2 2280 PCIe 3.0×4 NVMe1.3（TLC・5 年保証・SP256GBP34A60M28） | — | ¥8,488 | 2026-04-12（本日 14:00〜17:59） |
| MicroSD 64GB（Vesiri 付属） | Class10 UHS-1 | 付属 | ¥0 | — |
| **合計** | | | **¥46,952** | |

#### ハードウェア選定の根拠

- **Vesiri キット**: RPi5 8GB + Active Cooler + PD PSU + MicroSD + HDMI ケーブル + ABS ケース + カードリーダー + 日本語マニュアルを一式で最安調達
- **GeeekPi DeskPi Lite**: PCIe to M.2 HAT + Active Cooler + 電源ボタン + デュアル HDMI が一体のオールインワンケース。2280 SSD 対応で、日本市場で 2242 NVMe が ¥21,000+ と異常高騰していたため 2280 路線に変更して約 ¥15,000 節約
- **Silicon Power P34A60**: 日本市場で指定ブランド（Kioxia/Samsung/Crucial/WD/Kingston）の 256GB NVMe 2280 新品が軒並み廃番 or 入手不可だったため、TLC・5 年保証・¥8,488 の SP Silicon Power を採用。台湾上場企業で信頼性は Transcend と同格
- **Vesiri 付属部品の再利用**: ABS ケースは予備保管。Active Cooler は DeskPi Lite に内蔵されているため予備扱い
- **NVMe 256GB 採用理由**: RPi5 は PCIe Gen2 x1（500 MB/s 実効）で律速されるため高 Gen 帯域は無意味。TLC NAND・5 年保証・信頼ブランドを優先。SD カードの 24/7 書き込み耐久問題を NVMe で根本解決

### 2.2 OS・ソフトウェアスタック

| 要素 | バージョン / 指定 | 備考 |
|---|---|---|
| OS | Raspberry Pi OS 64-bit | OpenClaw 公式で 64-bit 必須 |
| Node.js | v24（推奨） or v22.16+ | OpenClaw 公式要件 |
| OpenClaw | `npm install -g openclaw@latest` | Daemon で常駐 |
| Claude Code | ARM64 ビルド最新 | RPi5 単体で GitHub push 可能 |
| Tailscale | 最新 | 既存 tailnet に join |
| LUKS | システム標準 | NVMe 全ディスク暗号化 |

### 2.3 ネットワーク・トポロジー

```
iPhone ─[Telegram 第一 / Discord 副]─ インターネット
                                         │
                                     Webhook
                                         ↓
                          OCI Always Free VM（第一候補・未設定）
                                         │
                                  Tailscale VPN
                                         ↓
            Raspberry Pi 5（24/7・OpenClaw Gateway + Claude Code）
                                         │
               ┌────────────────────────┼────────────────────────┐
               ↓                        ↓                        ↓
         MacBook Pro           Windows Tower                 GitHub
        （スリープ可・           （quickconv.cc 動画変換・        （gh skill ・
          必要時のみ）            Wake-on-LAN 起動専用）            webhook）
```

**主軸メッセージング**: Telegram  
**副**: Discord（必要時）  
**除外**: iMessage / BlueBubbles（MacBook スリープ化と両立不能のため）  
**外部公開の fallback**: OCI スペック不足時は Cloudflare Tunnel または Tailscale Funnel

---

## 3. 実行ワークフロー — モデル 2（承認 2 箇所 + 出戻りゼロ）

### 3.1 全体フロー

```
[Phase 1] 要件受理
  1. iPhone から Telegram で要件を投稿
     （テキスト必須 + 任意で画像 / 図 / 動画 / モックを添付）
  2. OpenClaw Gateway が受理 → DM pairing で送信者認証
  3. Claude Code スキルに委譲

[Phase 2] Visual AC 形成 ★承認 1 箇所目★
  4. AC 素材の有無を Claude Code が判定:
     a. ユーザー提供あり:
        ├ 画像 → Vision API で要素抽出 → AC 化
        ├ 図（Mermaid/手書き）→ 構造化 → AC 化
        ├ 動画 → videodb スキルで解析 → 要点抽出 → AC 化
        └ モック → そのまま基準として採用
     b. ユーザー提供なし:
        └ Claude Code が「こういう動きにさせます」を自動生成:
          - HTML モックアップ（UI 変更系）
          - Mermaid 図（フロー・状態変化系）
          - Before/After 比較画像（修正系）
          - 画面録画シナリオ（インタラクション系）
  5. 生成した Visual AC を iPhone に送信:
     - 軽いもの → Telegram に画像 push
     - インタラクティブ → 一時 URL（Tailscale 内）付き通知
  6. iPhone で 3 秒で判別:
     「この見た目・動きで OK か？」
     → ★Approve（承認 1 箇所目）→ Phase 3 に進む
     → ★修正要求 → Phase 2 の 4 に戻る（無制限ループ許容）

[Phase 3] 自動実装・検証ループ（全自動・無人）
  7. Visual AC を基準に Claude Code が実装
  8. テスト・AC 検証を実行:
     - exit code で判定
     - 出力パターンマッチで判定
     - 画像差分で判定（UI 変更の場合）
  9. 赤なら Claude Code が自己修復ループ（最大 5 回）
 10. 5 回失敗 → iPhone にエスカレーション通知（人間介入フォールバック）

[Phase 4] PR 作成 → 最終承認 ★承認 2 箇所目★
 11. PR 作成。PR 本文に必ず以下を明記:
     - Phase 2 で承認済みの Visual AC（そのまま再掲）
     - 完成スクショ / 動作 GIF / diff
     - AC 検証結果（コマンド出力付き）
     - 内部リトライ回数
 12. OpenClaw が iPhone に PR 通知:
     - PR URL
     - Visual 比較（Phase 2 AC vs 実装結果）
 13. iPhone で 30 秒内に判別:
     → ★Approve（承認 2 箇所目）→ マージ → Phase 5 に進む
     → ★修正要求 → Phase 3 または Phase 2 に戻る

[Phase 5] 自動デプロイ
 14. GitHub Actions が起動 → テスト → デプロイ
 15. デプロイ成功 → iPhone に情報通知（承認不要）
 16. デプロイ失敗 → iPhone にエスカレーション通知
```

### 3.2 承認特性の表

| 項目 | モデル 1（旧案） | **モデル 2（採用）** |
|---|:---:|:---:|
| 承認ポイント数 | 1 | **2** |
| 各承認の所要時間 | 30 秒（PR 読解必要） | **各 3〜30 秒（Visual 判別）** |
| 合計所要時間 | 30 秒 | **6〜60 秒** |
| 要件取り違え検出タイミング | 実装後 PR 段階 | **実装前 Phase 2 で検出** |
| 出戻り発生リスク | 中（B 型取り違え残る） | **ほぼゼロ** |
| 心理的コスト | 中（長文 PR を読む） | **低（画像 1 枚見るだけ）** |

---

## 4. AC 駆動開発ルール

CLAUDE.md 既存ルールを厳格適用（再発明しない）。

| ルール | 出典 | 本 spec での適用 |
|---|---|---|
| AC は決定的判定 | `~/agent-base/rules/general/acceptance-criteria.md` | exit code / 出力パターン / 画像差分のみ。LLM の主観判定禁止 |
| サイレントフォールバック禁止 | `~/agent-base/rules/general/agent-output-quality.md` | 空の try/catch 禁止・エラー握りつぶし禁止 |
| 検証の 3 層責務分担 | `~/agent-base/rules/general/validation-layers.md` | hooks (fmt/lint/型) + /verify (テスト/SAST) + CI (E2E/cov) |
| rework-patterns 記録 | `~/agent-base/rules/general/rework-patterns.md` | 出戻り発生時は RW-XXX として蓄積 |
| 内部リトライ上限 | 本 spec | 最大 5 回、失敗時は iPhone エスカレーション |
| **Text-only AC 禁止** | 本 spec | Phase 2 で Visual AC が生成できない要件は Phase 3 に進まない（ガード） |

---

## 5. Visual AC 運用ルール

### 5.1 要件タイプ別 Visual AC 形式

| 要件タイプ | Visual AC 形式 | 生成手段 |
|---|---|---|
| UI 変更（ボタン追加・レイアウト変更） | HTML モックアップ + スクショ | Claude Code + Puppeteer / Playwright |
| 画面フロー変更 | Mermaid シーケンス図 | Claude Code が Mermaid 直接生成 |
| データ表示変更 | Before/After 比較画像 | Claude Code で diff 画像合成 |
| インタラクション系 | GIF または画面録画 | Claude Code + ffmpeg / OBS |
| バックエンドロジック | フロー図 + 入出力例テーブル | Mermaid + Markdown テーブル |

### 5.2 ユーザー提供素材の処理

| 提供物 | 処理 |
|---|---|
| スクショ・画像 | Claude Vision API で要素抽出 → AC 化 |
| 手書き図 | Vision API + OCR → 構造化 → AC 化 |
| 動画 | `everything-claude-code:videodb` スキルで解析 → 要点抽出 → AC 化 |
| 既存 URL | Browse してキャプチャ → 改善案 mockup 生成 |
| テキストのみ | Claude Code が 2〜3 案の候補を自動生成 → iPhone で選択 |

### 5.3 禁則事項

- **Text-only AC での実装着手を禁止** — 視覚判別できる形式が必ず存在すること
- **複雑すぎる AC は要件分解** — 1 つの Visual AC で収まらなければ要件自体を分割して複数 PR に
- **AC skip 不可** — ユーザーが急いで「AC なしで進めて」と言っても、必ず Phase 2 を通過する（ハードゲート）

---

## 6. セキュリティ設計

### 6.1 必須設定（OpenClaw + Infra）

| 優先度 | 設定 | 具体実装 |
|:---:|---|---|
| 🔴 必須 | Gateway bind | `127.0.0.1` に変更（Tailscale 経由のみ受理） |
| 🔴 必須 | DM pairing | OpenClaw 標準 pairing code モデル採用 |
| 🔴 必須 | 認証トークン | 256bit ランダム・`.env` + `chmod 600` |
| 🔴 必須 | allowFrom | 自分の Telegram user ID / GitHub username のみ |
| 🔴 必須 | OpenClaw 定期更新 | 毎週 `npm update -g openclaw` cron（CVE 138 件対策） |
| 🔴 必須 | NVMe フルディスク暗号化 | LUKS で `/home` と `/var/log` を暗号化 |
| 🔴 必須 | Destructive action は built-in 承認必須 | OpenClaw の既定挙動のまま、変更しない |
| 🟡 推奨 | API キー分離 | Anthropic / OpenAI / GitHub 別 env var、`.env.local` |
| 🟡 推奨 | elevated 制限 | 自分の ID のみ（`allowRoot=false`） |
| 🟡 推奨 | mDNS 最小化 | `OPENCLAW_DISABLE_BONJOUR=1` |
| 🟢 任意 | 小型 UPS | 停電時の NVMe 保護（後回し可） |

### 6.2 CVE 対応方針

OpenClaw には 2026 年 4 月時点で CVE 138 件（41% が High/Critical）が存在する（doc §12 記載）。以下で対処:

1. **毎週自動更新 cron** — `0 3 * * 0 npm update -g openclaw 2>&1 | tee /var/log/openclaw-update.log`
2. **リリースノート監視** — 毎週月曜朝に iPhone 通知で新リリースの有無を確認
3. **Emergency patch 手順** — Critical CVE 発表時、手動即時更新 + 影響範囲調査を Phase 0 タスクとして実行

---

## 7. セットアップ順序（RPi5 到着後 Day 1〜3）

### Day 1: ハードウェア構築と OS（所要 2〜3 時間）

1. Vesiri キットから RPi5 本体・PSU・HDMI ケーブル取り出し
2. Vesiri ABS ケースと Active Cooler は予備として保管（DeskPi Lite に Active Cooler 内蔵のため）
3. GeeekPi DeskPi Lite に RPi5 本体を組込み（PCIe to M.2 HAT + SP P34A60 NVMe SSD 同時装着）
4. 64-bit Raspberry Pi OS を NVMe に直接焼く（Imager 使用、別 PC から）
5. 初回起動・基本設定:
   - SSH 有効化
   - swap 2GB 設定
   - mDNS 最小化（`OPENCLAW_DISABLE_BONJOUR=1`）
6. Tailscale インストール → 既存 tailnet に join
7. LUKS で `/home` と `/var/log` を暗号化

### Day 2: OpenClaw セットアップ（所要 2〜3 時間）

8. Node 24 インストール
9. `npm install -g openclaw@latest`
10. `openclaw onboard --install-daemon`
11. セキュリティ設定:
    - Gateway bind 127.0.0.1
    - 認証トークン生成（256bit）
    - allowFrom に自分の Telegram user ID
    - `.env` ファイル chmod 600
12. Telegram skill 設定 + DM pairing テスト
13. ハローワールド疎通: iPhone → Telegram → OpenClaw → echo レスポンス

### Day 3: Claude Code 統合と End-to-End（所要 2〜3 時間）

14. Claude Code ARM64 ビルドインストール
15. GitHub skill 設定（`gh` CLI auth）
16. agent-base リポジトリとの skill 呼び出し経路確立
17. **E2E リハーサル**:
    - iPhone から「テスト用リポジトリに README を追加する PR を作って」を投入
    - Phase 1〜5 全通しで動作確認
    - Visual AC が生成されることを確認
    - 承認 2 箇所で完走することを確認

---

## 8. 初期 MVP 達成基準

以下がすべて ✅ になったら MVP 達成:

- [ ] RPi5 が 24/7 で起動し、Tailscale で他デバイスと疎通
- [ ] NVMe SSD から起動、SD カードは予備扱い
- [ ] LUKS 暗号化が有効
- [ ] OpenClaw Gateway が Telegram 経由で自分からの指示を受理
- [ ] DM pairing が機能し、自分以外からは拒否される
- [ ] 「hello world リポジトリに README を追加する PR を作って」を iPhone から投入し Phase 1〜5 完走
- [ ] Phase 2 で Visual AC が 1 枚以上生成される
- [ ] Phase 2 の Approve が 3 秒以内に 1 タップで完了
- [ ] Phase 4 の PR マージが 30 秒以内に 1 タップで完了
- [ ] 内部リトライで 1 回以上の自動修復が発生する E2E ケースを確認（落ちるテストから green まで）
- [ ] 週次 OpenClaw 自動更新 cron が動作

---

## 9. リスク・未決事項

| ID | 項目 | 対応 |
|---|---|---|
| R-1 | ~~GeeekPi N07 / DeskPi Lite 入手不可~~ **解決済み**: DeskPi Lite（B0DPH2DYBP）を購入確定。PCIe to M.2 HAT + Active Cooler + 電源ボタン + 2280 対応を商品説明で確認済み | 2026-04-12 購入完了 |
| R-2 | Visual AC 生成スキルが OpenClaw 公式レジストリに存在するか未確認 | Day 2 で調査、存在しなければ Claude Code の自前スキルとして実装 |
| R-3 | Windows Tower デスクトップ GUI 操作の公式対応が未確認 | quickconv.cc 動画変換では不要なので無視、必要になったら再調査 |
| R-4 | OpenClaw CVE 138 件・High/Critical 41% | 毎週 auto-update cron + リリースノート監視で継続対応 |
| R-5 | RPi5 単一障害点（停電・SD/NVMe 故障） | Phase 2 では許容、将来 UPS + バックアップ戦略を検討 |
| R-6 | 要件取り違えの「根本的」パターン（Visual AC でも捉えられない） | rework-patterns.md に RW-XXX として記録、再発時は要件抽出プロンプト改善 |

---

## 10. 進行管理

- リポジトリ: `miyashita337/openclaw-rpi5-ops`（本プロジェクト）
- 連動リポジトリ: `miyashita337/agent-base`（エージェント基盤）
- Issue 管理: GitHub Issues（本リポジトリ）
- 進捗同期: 週次 iPhone 通知

---

## 11. 変更履歴

| 日付 | 変更 | 理由 |
|---|---|---|
| 2026-04-12 | 初版作成 | brainstorming セッションの結論を文書化 |
| 2026-04-12 | § 2.1 ハードウェア確定 | 発注完了を反映: Vesiri Kit + GeeekPi DeskPi Lite + SP P34A60 256GB = ¥46,952。R-1 解決済みに変更 |

---

*このドキュメントは brainstorming セッション（2026-04-12、約 4 時間）の結論をもとに作成されました。*
