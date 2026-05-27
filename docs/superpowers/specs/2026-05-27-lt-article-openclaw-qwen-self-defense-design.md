# LT 記事 Article Issue 設計: OpenAI 課金高騰時代の自衛策 — VRAM 16GB GPU で Qwen3.6-27B + OpenClaw

- **作成日**: 2026-05-27
- **作成者**: harieshokunin (壁打ち相手: Claude Opus 4.7)
- **目的**: note/Zenn 等で公開する LT 記事 (4,500-5,000 字) の素材ドキュメントを Article Issue として `miyashita337/openclaw-rpi5-ops` に起票する
- **アプローチ**: Approach 3 (ハイブリッド軸) — 実測 + 設計 + ハマり + コストをバランスよく配合し、4 読者層に幅広く刺す

## 想定読者 (4 層)

| # | 読者層 | 期待 |
|---|---|---|
| 1 | 自宅 AI bot / エージェント作りたい人 (OpenClaw/n8n/LangChain/Dify 興味層) | OpenClaw 実例・ハマりポイント・persona/dreaming の物語 |
| 2 | GPU 選定で悩んでる人 (RTX 4070 Ti SUPER vs 5070 Ti 迫り中) | 16GB VRAM で 27B モデルが「実際に動く/辛い」の境界線 |
| 3 | 雑談レベル (「AI と何か話したい」「ChatGPT 以外とも仲良くしたい」層) | Polka との対話例、「寝てる間に育つ AI」の体感 |
| 4 | 既存 AI サービスの価格高騰恐怖層 | OpenAI 課金 vs 自宅電気代の損益分岐 |

## 比較対象マシン (両者比較記事)

| 項目 | Win Tower (uss-enterprise) | DemoPC |
|---|---|---|
| GPU | RTX 4070 Ti SUPER 16GB | RTX A1000 8GB |
| RAM | 32GB DDR5-5600 | 64GB |
| 主モデル | qwen2.5:7b (primary) + qwen3.6:27b (fallback) | qwen2.5:7b |
| runtime 構成 | WSL2 + OpenClaw + Polka (24/7 自律 bot) | Win native Ollama + Discord bridge.py のみ (OpenClaw なし) |
| 入手状況 | 手元あり (実測可) | **返却済み (実測不可、既知見積もり + 公開ベンチ引用)** |

## データ調達方針 (= Approach D)

- Win Tower 側: 本セッション内で Issue #14 の `scripts/bench-llm-runtime.sh` を使って qwen2.5:7b / qwen3.6:27b の TPS, first-token-ms, VRAM/RAM split を **新規実測**
- DemoPC 側: Issue #28 の事前見積もり (VRAM 8GB で 27B は 3-8 tps) + willitrunai.com の重み 16.8GB 情報を引用
- 記事スタンスは「Win Tower で実際に動かしてみた、8GB 環境なら公開ベンチ・事前見積もりベースだとこうなる見込み」と明記

## メタ情報

| 項目 | 確定値 |
|---|---|
| 起票先 repo | `miyashita337/openclaw-rpi5-ops` |
| ラベル | `article` (新規追加候補) |
| Issue タイトル (仮) | `[Article] OpenAI 課金高騰時代の自衛策 — VRAM 16GB GPU で Qwen3.6-27B + OpenClaw で 24/7 自宅 AI bot を立てた話` |
| 想定媒体 | note (第一候補)、Zenn 同時投稿可 |
| 目標分量 | 4,500-5,000 字 / 画像 5-7 枚 |
| 完成条件 | 後述「統合ジャーニーAC」3 件 PASS |
| 関連 Issue | #10 #14 #15 #19 #20 #21 #28 |

## 章立て (8 セクション、合計 5,000 字目安)

| § | 章タイトル (仮) | 字数目安 | 主な素材 |
|---|---|---|---|
| 1 | プロローグ: AI サービス値上げの三波、自衛の必要 | 400 | 値上げエビデンス 3 件 (Cursor / Anthropic Max / OpenAI Teams) + コスト試算の触り |
| 2 | 答え先出し (1 段落) | 200 | 結論ダイジェスト |
| 3 | 全体構成図 (Win Tower / Discord / Ollama / OpenClaw) | 500 | 画像 1: Mermaid 構成図 |
| 4 | ハード選定: なぜ 4070 Ti SUPER 16GB か + 実測表 | 1,000 | 画像 2: nvidia-smi 27B 動作中、画像 3: ollama ps の GPU/CPU split、ベンチ表 |
| 5 | ソフト選定: なぜ OpenClaw か (n8n/LangChain/Dify 比較) | 600 | 比較表 |
| 6 | 構築ハマり TOP3 (agentTurn vs systemEvent / Ollama-Qwen3 tool calling bug / 16GB ぎりぎり split) | 1,200 | 画像 4: jobs.json 抜粋、画像 5: bug Issue リンク |
| 7 | 動いた Polka の対話と「寝てる間に育つ」体験 | 600 | 画像 6: Discord DM スクショ、画像 7: heartbeat-log.md 抜粋 |
| 8 | コスト試算 + 結論 (4 読者層への餞別) | 500 | 試算表 |

## 必要素材リストと収集 TODO

### 実測データ (Win Tower で取得。本セッションで実施するか別 Sub-issue として切り出すかは writing-plans フェーズで決定)

- [ ] qwen2.5:7b で 1-2 prompt → TPS, first-token-ms, VRAM 使用量
- [ ] qwen3.6:27b で 1-2 prompt → TPS, first-token-ms, VRAM/RAM split 比率, CPU offload 層数
- [ ] Issue #14 の `scripts/bench-llm-runtime.sh` を流用 (既存 commit 済)

### 画像エビデンス (7 枚、5 枚以上必須)

| # | 内容 | 出所 | 状態 |
|---|---|---|---|
| 1 | 構成図 (Win Tower + Discord + Ollama + OpenClaw + Polka) | Mermaid 図 → PNG 化 (記事作成時に生成) | 未取得 |
| 2 | nvidia-smi 27B 動作中の VRAM/プロセス画面 | Win Tower で `nvidia-smi` 実行スクショ | 未取得 |
| 3 | `ollama ps` の GPU/CPU split 比率 (例: 30/65 layers) | Win Tower で `ollama ps` 実行スクショ | 未取得 |
| 4 | `~/.openclaw/cron/jobs.json` の `agentTurn` schema 抜粋 | テキスト or スクショ | 未取得 (テキストは即可) |
| 5 | Ollama GitHub Issue #14493/#14601 (Qwen3 tool calling bug) スクショ | GitHub ページキャプチャ | 未取得 |
| 6 | **Discord DM スクショ (Polka との対話、エビデンス強)** | ユーザーが Discord アプリで取得 | **ユーザー提供予定** |
| 7 | `~/.openclaw/workspace/memory/heartbeat-log.md` 抜粋 | テキスト or スクショ | 未取得 |

### 引用ソース

#### §1 プロローグ用: AI サービス値上げ エビデンス TOP3 (fact-checker 調査済、2026-05-27)

記事の論旨「自衛策が必要」を裏付けるための一次資料。三形態（定価値上げ / 上位プラン誘導 / 無料枠縮小）を 1 件ずつ配置。

| # | 事例 | 値上げ概要 | 一次出典 |
|---|---|---|---|
| 1 | **Cursor Pro (2025-06)** | 500 リクエスト固定 → $20 クレジット制 (実質 -55%)、CEO 公開謝罪 | https://cursor.com/blog/june-2025-pricing |
| 2 | **Anthropic Claude Pro → Max (2025-04)** | Pro $20 制限強化 + Max $100/$200 新設で上位プラン誘導 | https://claude.com/blog/max-plan / https://techcrunch.com/2025/04/09/anthropic-rolls-out-a-200-per-month-claude-subscription/ |
| 3 | **OpenAI ChatGPT Teams (2024-11)** | $25 → $30 (+20%)、ブログ告知なしの静かな値上げ | https://acsapp.com/blog/openai-quietly-raises-chatgpt-team-plan-price-from-25-to-30-per-user-per-month/ / https://www.saaspricepulse.com/blog/chatgpt-pricing-history-2022-2025 |

**補助エビデンス (記事内では本文に出さず、設計書記録のみ):**

- OpenAI ChatGPT Pro $200/月 新設 (2024-12): Plus $20 の x10 上位プラン登場 — https://chatgpt.com/pricing/
- Devin (Cognition AI) $500/月 → $20+ACU 従量 (2025-04): per-ACU $2.00→$2.25 値上げ — https://venturebeat.com/programming-development/devin-2-0-is-here-cognition-slashes-price-of-ai-software-engineer-to-20-per-month-from-500
- GitHub Copilot AI クレジット従量制移行 (2026-06 予告): https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/ **【要再検証 — 2026 年予告のため執筆時点で実施済みか確認】**
- Anthropic ピーク時間帯制限強化 (2026-03): https://www.theregister.com/2026/03/26/anthropic_tweaks_usage_limits/ **【要再検証 — fact-checker 経由 2026 年ソース、URL 実在確認必要】**
- 円安要因 (1USD 150 円超、2022 年 115 円比 +30-35% 実質負担増) は本文では補足程度

#### その他

- DemoPC 8GB 側の 27B 推定値: Issue #28 (3-8 tps) + willitrunai.com (16.8GB 重み)
- Ollama-Qwen3 tool calling bug: ollama/ollama#14493, #14601 (実 URL は Issue #20 参照)
- VRAM 見積もり: Qwen 公式 + willitrunai

## 統合ジャーニーAC (Article 公開判定)

1. **操作**: 起票された Article Issue を読み、必要素材リストの未取得項目を `gh issue edit` でチェックボックス更新しながら 1 つずつ収集
   - **期待結果**: 画像 5-7 枚、実測データ 4 種類、引用 3 件が Issue コメントに添付済み
   - **検証手段**: Issue コメントの添付ファイル数 + チェックボックス充足度

2. **操作**: 章立て 8 セクションに沿って本文を書き起こし、note 下書き保存
   - **期待結果**: 4,500-5,000 字 / 画像 5-7 枚 / コードブロック 3-5 個 (Mermaid + bash + json)
   - **検証手段**: note 下書き URL を Issue にコメント、文字数 + 画像数チェック

3. **操作**: 公開前に Issue 内で 4 読者層チェック (AI bot 民 / GPU 民 / 雑談民 / 価格高騰層) でそれぞれ「最低 1 段落は刺さる箇所がある」を目視確認
   - **期待結果**: 4 読者層すべてに対応する段落マーキング済み
   - **検証手段**: Issue コメントで「§N が読者層 X 向け」のマッピング表

## スコープ外

- 実コード (Polka persona file) のリポジトリ公開: 本記事には載せない、OSS 化予定なし
- DemoPC 側の qwen3.6:27b 実機ベンチ: DemoPC 返却済み、Issue #28 を別途参照
- Zenn/Qiita への同時投稿手順: note 公開後の follow-up
- 自動公開ワークフロー: 本記事は手動公開 (ユーザー自身)
- Phase 7 (qwen3.6:27b on DemoPC) の完了: Issue #28 で別途追跡

## 既知の制約・前提

- 本セッションは Windows 11 Pro + WSL2 (Ubuntu-22.04) 上で実行中、Polka 本番マシンと一致
- DemoPC へのリモートアクセス手段なし (Tailscale ACL 不備 + 返却済)
- Win Tower の qwen3.6:27b は GPU/CPU split で 1-3 分/turn の体感値 (domain-expert.md 既知)
- 記事公開は手動、本ドキュメントは Article Issue 起票プランの設計書のみ

## 関連リファレンス

- `.claude/rules/domain-expert.md`: Polka 本番構成の暗黙知 (実測体感値・OpenClaw のハマり集)
- `docs/superpowers/specs/2026-04-12-openclaw-rpi5-ops-design.md`: プロジェクト全体設計
- Issue #14: runtime 選定ベンチ (CLOSED、`scripts/bench-llm-runtime.sh` あり)
- Issue #15: WoL on-demand vs 24/7 vs OpenAI API 損益分岐 (本記事の §8 コスト試算で参照)
- Issue #19: OpenClaw session token 飽和 (ハマりポイント候補)
- Issue #20: Polka tool_call 漏れ + 300s stall (ハマり TOP3 第 2 位の元ネタ)
- Issue #21: DemoPC Epic + Sub #22-#28 (8GB 側構成の参照)
- Issue #28: qwen3.6:27b on DemoPC (任意の発展、本記事では「公開ベンチ + 見積もり」として引用)
- **Article Issue #30 (起票済, 2026-05-27)**: https://github.com/miyashita337/openclaw-rpi5-ops/issues/30

## 次のステップ

1. 本設計書 commit
2. ユーザーレビュー (修正あれば差し戻し)
3. `superpowers:writing-plans` スキルへ移行し、Article Issue 起票プラン (gh issue create のコマンドを含む) を作成
4. プラン承認後に実際の `gh issue create` 実行 (別セッション or 同セッション継続)
