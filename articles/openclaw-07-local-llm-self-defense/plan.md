# LT 記事 Article Issue 起票 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 設計書 `docs/superpowers/specs/2026-05-27-lt-article-openclaw-qwen-self-defense-design.md` の内容を `miyashita337/openclaw-rpi5-ops` リポジトリに Article Issue として起票し、素材収集の出発点を作る。

**Architecture:**
- Article Issue 本文 markdown を一時ファイルに組み立て → `article` ラベルを必要なら作成 → `gh issue create --body-file` で起票 → URL を設計書 (本 plan ファイル含む) に追記して trace を残す。
- Issue は「素材ドキュメント (= 章立て + 必要素材チェックリスト + AC)」として使い、note 本文書き起こしは別フェーズ。

**Tech Stack:** GitHub CLI (`gh`)、bash heredoc、git。

---

## File Structure

| 操作 | パス | 役割 |
|---|---|---|
| Create (一時) | `/tmp/article-issue-body-2026-05-27.md` | gh に渡す本文 markdown (起票後削除) |
| Modify | `docs/superpowers/specs/2026-05-27-lt-article-openclaw-qwen-self-defense-design.md` | 起票後 §「関連リファレンス」末尾に Article Issue URL 追記 |
| Modify | `docs/superpowers/plans/2026-05-27-lt-article-issue-creation.md` (本ファイル) | 末尾「Execution Log」に起票結果 URL 追記 |

---

## Task 1: Article Issue 本文 markdown を作成

**Files:**
- Create: `/tmp/article-issue-body-2026-05-27.md`

- [ ] **Step 1: 一時ファイルに Issue 本文を書き出す**

設計書をベースに、Issue 本文として再構成 (素材チェックリスト + AC + 関連 Issue リンクを Issue 用に整形)。本文は以下:

```bash
cat > /tmp/article-issue-body-2026-05-27.md <<'EOF'
## 目的

note/Zenn 等で公開する LT 記事 (4,500-5,000 字 / 画像 5-7 枚) の素材ドキュメント。
本 Issue を「素材収集チェックリスト + 章立て + 引用ソース台帳 + 完成判定 AC」として運用し、
素材が揃ったら note 本文書き起こしフェーズへ移行する。

設計書: `docs/superpowers/specs/2026-05-27-lt-article-openclaw-qwen-self-defense-design.md`

## 想定読者 (4 層)

| # | 読者層 | 期待 |
|---|---|---|
| 1 | 自宅 AI bot / エージェント作りたい人 (OpenClaw/n8n/LangChain/Dify 興味層) | OpenClaw 実例・ハマりポイント・persona/dreaming の物語 |
| 2 | GPU 選定で悩んでる人 (RTX 4070 Ti SUPER vs 5070 Ti 迫り中) | 16GB VRAM で 27B モデルが「実際に動く/辛い」の境界線 |
| 3 | 雑談レベル (「AI と何か話したい」「ChatGPT 以外とも仲良くしたい」層) | Polka との対話例、「寝てる間に育つ AI」の体感 |
| 4 | 既存 AI サービスの価格高騰恐怖層 | OpenAI 課金 vs 自宅電気代の損益分岐 |

## 比較対象マシン

| 項目 | Win Tower (uss-enterprise) | DemoPC |
|---|---|---|
| GPU | RTX 4070 Ti SUPER 16GB | RTX A1000 8GB |
| RAM | 32GB DDR5-5600 | 64GB |
| 主モデル | qwen2.5:7b (primary) + qwen3.6:27b (fallback) | qwen2.5:7b |
| runtime 構成 | WSL2 + OpenClaw + Polka (24/7 自律 bot) | Win native Ollama + Discord bridge.py (OpenClaw なし) |
| 入手状況 | 手元あり (実測可) | **返却済み (実測不可、既知見積もり + 公開ベンチ引用)** |

**データ調達方針 (= Approach D):**
- Win Tower 側: Issue #14 の `scripts/bench-llm-runtime.sh` で qwen2.5:7b / qwen3.6:27b の TPS, first-token-ms, VRAM/RAM split を **新規実測**
- DemoPC 側: Issue #28 の事前見積もり (3-8 tps) + willitrunai.com の重み 16.8GB 情報を引用

## 章立て (8 セクション、合計 5,000 字目安)

| § | 章タイトル (仮) | 字数目安 | 主な素材 |
|---|---|---|---|
| 1 | プロローグ: AI サービス値上げの三波、自衛の必要 | 400 | 値上げエビデンス 3 件 (Cursor / Anthropic Max / OpenAI Teams) |
| 2 | 答え先出し (1 段落) | 200 | 結論ダイジェスト |
| 3 | 全体構成図 (Win Tower / Discord / Ollama / OpenClaw) | 500 | 画像 1: Mermaid 構成図 |
| 4 | ハード選定: なぜ 4070 Ti SUPER 16GB か + 実測表 | 1,000 | 画像 2: nvidia-smi 27B 動作中、画像 3: ollama ps の GPU/CPU split、ベンチ表 |
| 5 | ソフト選定: なぜ OpenClaw か (n8n/LangChain/Dify 比較) | 600 | 比較表 |
| 6 | 構築ハマり TOP3 (agentTurn vs systemEvent / Ollama-Qwen3 tool calling bug / 16GB ぎりぎり split) | 1,200 | 画像 4: jobs.json 抜粋、画像 5: bug Issue リンク |
| 7 | 動いた Polka の対話と「寝てる間に育つ」体験 | 600 | 画像 6: Discord DM スクショ、画像 7: heartbeat-log.md 抜粋 |
| 8 | コスト試算 + 結論 (4 読者層への餞別) | 500 | 試算表 |

## 必要素材リスト (収集 TODO)

### 実測データ (Win Tower で取得)

- [x] qwen2.5:7b で 1-2 prompt → TPS, first-token-ms, VRAM 使用量 ← 取得済 (Issue #30 コメント)
- [x] qwen3.6:27b で 1-2 prompt → TPS, first-token-ms, VRAM/RAM split 比率, CPU offload 層数 ← 取得済 (Issue #30 コメント)
- ⚠️ Issue #14 の `scripts/bench-llm-runtime.sh` は **本 repo に未 commit** だったため ad-hoc curl + jq で代替実装

### 画像エビデンス (7 枚、5 枚以上必須)

| # | 内容 | 出所 | 担当 |
|---|---|---|---|
| 1 | 構成図 (Win Tower + Discord + Ollama + OpenClaw + Polka) | Mermaid 図 → PNG 化 | Claude (本文執筆時) |
| 2 | nvidia-smi 27B 動作中の VRAM/プロセス画面 | Win Tower で `nvidia-smi` 実行スクショ | Claude (実測時) |
| 3 | `ollama ps` の GPU/CPU split 比率 (例: 30/65 layers) | Win Tower で `ollama ps` 実行スクショ | Claude (実測時) |
| 4 | `~/.openclaw/cron/jobs.json` の `agentTurn` schema 抜粋 | テキスト or スクショ | Claude (即可) |
| 5 | Ollama GitHub Issue #14493/#14601 (Qwen3 tool calling bug) スクショ | GitHub ページキャプチャ | Claude or ユーザー |
| 6 | **Discord DM スクショ (Polka との対話、エビデンス強)** | Discord アプリで取得 | **ユーザー提供予定** |
| 7 | `~/.openclaw/workspace/memory/heartbeat-log.md` 抜粋 | テキスト or スクショ | Claude (即可) |

### 引用ソース

**§1 プロローグ用 (fact-checker 調査済、2026-05-27):**

| 事例 | 値上げ概要 | 一次出典 |
|---|---|---|
| Cursor Pro (2025-06) | 500 リクエスト固定 → $20 クレジット制 (実質 -55%)、CEO 公開謝罪 | https://cursor.com/blog/june-2025-pricing |
| Anthropic Claude Pro → Max (2025-04) | Pro $20 制限強化 + Max $100/$200 新設で上位プラン誘導 | https://claude.com/blog/max-plan / https://techcrunch.com/2025/04/09/anthropic-rolls-out-a-200-per-month-claude-subscription/ |
| OpenAI ChatGPT Teams (2024-11) | $25 → $30 (+20%)、ブログ告知なしの静かな値上げ | https://acsapp.com/blog/openai-quietly-raises-chatgpt-team-plan-price-from-25-to-30-per-user-per-month/ / https://www.saaspricepulse.com/blog/chatgpt-pricing-history-2022-2025 |

**補助 (本文には出さない場合あり):**
- OpenAI ChatGPT Pro $200/月 新設 (2024-12): https://chatgpt.com/pricing/
- Devin $500→$20+ACU 従量 (2025-04): https://venturebeat.com/programming-development/devin-2-0-is-here-cognition-slashes-price-of-ai-software-engineer-to-20-per-month-from-500
- GitHub Copilot AI クレジット移行 (2026-06 予告): https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/ **【要再検証】**
- Anthropic ピーク時間帯制限 (2026-03): https://www.theregister.com/2026/03/26/anthropic_tweaks_usage_limits/ **【要再検証】**

**§4-7 用:**
- DemoPC 8GB 側の 27B 推定値: #28 (3-8 tps) + https://willitrunai.com/blog/qwen-3-6-27b-vram-requirements
- Ollama-Qwen3 tool calling bug: ollama/ollama#14493, #14601 (実 URL は #20 参照)

## 統合ジャーニーAC (Article 公開判定)

1. **操作**: 本 Issue の「必要素材リスト」未取得項目をチェックボックス更新しながら 1 つずつ収集
   - **期待結果**: 画像 5-7 枚、実測データ 4 種類、引用 3 件が Issue コメントに添付済み
   - **検証手段**: Issue コメントの添付ファイル数 + チェックボックス充足度

2. **操作**: 章立て 8 セクションに沿って本文を書き起こし、note 下書き保存
   - **期待結果**: 4,500-5,000 字 / 画像 5-7 枚 / コードブロック 3-5 個 (Mermaid + bash + json)
   - **検証手段**: note 下書き URL を Issue にコメント、文字数 + 画像数チェック

3. **操作**: 公開前に Issue 内で 4 読者層チェック (AI bot 民 / GPU 民 / 雑談民 / 価格高騰層) でそれぞれ「最低 1 段落は刺さる箇所がある」を目視確認
   - **期待結果**: 4 読者層すべてに対応する段落マーキング済み
   - **検証手段**: Issue コメントで「§N が読者層 X 向け」のマッピング表

## スコープ外

- 実コード (Polka persona file) のリポジトリ公開: 本記事には載せない
- DemoPC 側の qwen3.6:27b 実機ベンチ: DemoPC 返却済み、#28 を別途参照
- Zenn/Qiita への同時投稿手順: note 公開後の follow-up
- 自動公開ワークフロー: 本記事は手動公開 (ユーザー自身)
- Phase 7 (qwen3.6:27b on DemoPC) の完了: #28 で別途追跡

## 関連 Issue

- #10 (親: ローカル LLM 検討)
- #14 (CLOSED: runtime 選定ベンチ、`scripts/bench-llm-runtime.sh` 提供元)
- #15 (損益分岐: §8 コスト試算で参照)
- #19 (OpenClaw session token 飽和: §6 ハマり候補)
- #20 (Polka tool_call 漏れ + 300s stall: §6 ハマり TOP3 第 2 位)
- #21 (DemoPC Epic) + Sub #22-#28 (8GB 側構成の参照)
- #28 (qwen3.6:27b on DemoPC: §4 引用元)
EOF
```

- [ ] **Step 2: 一時ファイルの妥当性を確認**

Run:
```bash
wc -l /tmp/article-issue-body-2026-05-27.md && head -20 /tmp/article-issue-body-2026-05-27.md
```

Expected: 100 行前後 / ファイル先頭が `## 目的` で始まる

---

## Task 2: `article` ラベル作成

**Files:** なし (GitHub API のみ)

- [ ] **Step 1: 既存ラベル確認**

Run:
```bash
gh label list --repo miyashita337/openclaw-rpi5-ops | grep -i '^article'
```

Expected: 空 (ラベル未存在を確認)。既に存在する場合は Step 2 skip。

- [ ] **Step 2: `article` ラベル作成**

Run:
```bash
gh label create article \
  --repo miyashita337/openclaw-rpi5-ops \
  --color "0E8A16" \
  --description "note/Zenn/Qiita 等で公開する記事の素材ドキュメント"
```

Expected: `✓ Label "article" created` 表示

- [ ] **Step 3: ラベル作成確認**

Run:
```bash
gh label list --repo miyashita337/openclaw-rpi5-ops | grep '^article'
```

Expected: `article` 行が出力される

---

## Task 3: gh issue create で起票

**Files:** なし (一時ファイル `/tmp/article-issue-body-2026-05-27.md` を入力として使用)

- [ ] **Step 1: gh issue create 実行 (dry-run なし、直接起票)**

Run:
```bash
GH_REPO="miyashita337/openclaw-rpi5-ops" gh issue create \
  --title "[Article] OpenAI 課金高騰時代の自衛策 — VRAM 16GB GPU で Qwen3.6-27B + OpenClaw で 24/7 自宅 AI bot を立てた話" \
  --body-file /tmp/article-issue-body-2026-05-27.md \
  --label article \
  --label brainstorming
```

Expected: 出力末尾に `https://github.com/miyashita337/openclaw-rpi5-ops/issues/<N>` の URL が表示される。失敗時は エラーメッセージを元に Task 2 / ラベル設定をリトライ。

- [ ] **Step 2: 起票結果を変数に保存し検証**

Run:
```bash
ISSUE_URL=$(gh issue list --repo miyashita337/openclaw-rpi5-ops --label article --limit 1 --json url --jq '.[0].url')
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
echo "Created Issue: $ISSUE_URL (#$ISSUE_NUM)"
gh issue view "$ISSUE_NUM" --repo miyashita337/openclaw-rpi5-ops --json title,labels --jq '{title, labels: [.labels[].name]}'
```

Expected:
- `Created Issue: https://github.com/miyashita337/openclaw-rpi5-ops/issues/<N> (#<N>)`
- title が `[Article] OpenAI 課金高騰時代の自衛策 — ...` で始まる
- labels に `article` と `brainstorming` を含む

---

## Task 4: 起票結果を spec と plan に追記、一時ファイル削除

**Files:**
- Modify: `docs/superpowers/specs/2026-05-27-lt-article-openclaw-qwen-self-defense-design.md`
- Modify: `docs/superpowers/plans/2026-05-27-lt-article-issue-creation.md`

- [ ] **Step 1: 設計書に起票結果 URL を追記**

`docs/superpowers/specs/2026-05-27-lt-article-openclaw-qwen-self-defense-design.md` の `## 関連リファレンス` セクション末尾に以下を追加 (Edit tool 使用):

```markdown
- **Article Issue (起票済, 2026-05-27)**: <ISSUE_URL を Task 3 Step 2 の出力から取得して挿入>
```

- [ ] **Step 2: 本 plan ファイル末尾の Execution Log を更新**

本ファイル末尾 `## Execution Log` セクションに以下を追加:

```markdown
- 2026-05-27: Article Issue 起票完了 <ISSUE_URL>
- 起票時ラベル: article + brainstorming
- 起票時 body: /tmp/article-issue-body-2026-05-27.md (Task 5 で削除)
```

- [ ] **Step 3: 一時ファイル削除**

Run:
```bash
rm /tmp/article-issue-body-2026-05-27.md
```

Expected: エラー出力なし

- [ ] **Step 4: spec + plan の更新を commit**

Run:
```bash
git add docs/superpowers/specs/2026-05-27-lt-article-openclaw-qwen-self-defense-design.md \
        docs/superpowers/plans/2026-05-27-lt-article-issue-creation.md
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
docs: LT記事 Article Issue 起票完了、URL を spec/plan に追記

起票 Issue: <ISSUE_URL>
ラベル: article + brainstorming

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[master <hash>] docs: LT記事 Article Issue 起票完了...` の出力

---

## Task 5: 次フェーズ案内 (起票後ユーザーへの handoff)

**Files:** なし (会話メッセージのみ)

- [ ] **Step 1: ユーザーへ完了報告と次のアクション提示**

完了メッセージのテンプレ:

```
Article Issue #<N> を起票しました: <ISSUE_URL>

次のフェーズ候補 (どれから着手しますか?):

A. 実測タスク先行 — Win Tower で qwen2.5:7b/qwen3.6:27b の bench-llm-runtime.sh を回し、
   TPS/first-token/VRAM/RAM split データと nvidia-smi/ollama ps スクショを揃える
   (Sub-issue として切り出すか、本 Issue にコメント添付するかは判断)

B. 即取得可能な軽い素材から — jobs.json 抜粋, heartbeat-log.md 抜粋, Mermaid 構成図
   を先に作って Issue にコメントで添付

C. Discord DM スクショ依頼 — ユーザーが Discord アプリで Polka との対話を 1-2 枚スクショ取得、
   Issue にアップロード (ユーザー側作業)

D. 本文書き起こし開始 — 素材が揃った前提で note の下書きを書き始める (素材は徐々に追加)
```

Expected: ユーザーから A/B/C/D のいずれかの返信を受けて、次フェーズに進む

---

## Self-Review

**1. Spec coverage:**
- 設計書 §「メタ情報」 → Task 3 で title/labels/body 反映 ✅
- 設計書 §「章立て 8 セクション」 → Task 1 で本文に含む ✅
- 設計書 §「必要素材リスト」→ Task 1 で本文に含む ✅
- 設計書 §「統合ジャーニーAC」→ Task 1 で本文に含む ✅
- 設計書 §「スコープ外」→ Task 1 で本文に含む ✅
- 設計書 §「§1 プロローグ用エビデンス TOP3」→ Task 1 「引用ソース」に含む ✅
- 設計書 §「次のステップ」→ Task 5 で handoff ✅

**2. Placeholder scan:**
- `<ISSUE_URL>` / `<N>` / `<ハッシュ>` は Task 3 Step 2 で取得する実行時値なので OK (placeholder ではなく動的値プレースホルダ)
- TBD/TODO は plan 内には無い (Article Issue 本文の「未取得チェックボックス」は意図された collection list)

**3. Type consistency:**
- `ISSUE_URL` / `ISSUE_NUM` 変数名は Task 3 Step 2 で定義し Task 4 で使用、整合
- ラベル名 `article` は Task 2 で作成、Task 3 で `--label article` で使用、整合

---

## Execution Log

- **2026-05-27**: Article Issue 起票完了 — https://github.com/miyashita337/openclaw-rpi5-ops/issues/30
  - 起票時ラベル: `article` + `brainstorming`
  - title: `[Article] OpenAI 課金高騰時代の自衛策 — VRAM 16GB GPU で Qwen3.6-27B + OpenClaw で 24/7 自宅 AI bot を立てた話`
  - 起票時 body: `/tmp/article-issue-body-2026-05-27.md` (Task 4 で削除)
  - `article` ラベル新規作成 (color `#0E8A16`, description: note/Zenn/Qiita 等で公開する記事の素材ドキュメント)
