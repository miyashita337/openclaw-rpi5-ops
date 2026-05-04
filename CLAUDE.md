# openclaw-rpi5-ops — Cowork / Claude 利用ガイド

## このリポでClaude（Cowork含む）が必ず守ること

### 1. セッション初回は必ず bootstrap を実行する

サンドボックス（Coworkのbash環境）はセッション間で初期化される可能性があるため、
ghコマンド等が使えない場合は **何より先に** 以下を実行する。

```bash
bash scripts/cowork-bootstrap.sh
```

判定方法（in_progressに入れる前にチェック）:

```bash
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
  || bash scripts/cowork-bootstrap.sh
```

完了マーカー: `.cowork-bootstrap.done`（gitignore済）

### 2. 認証情報の扱い

- `.env` （gitignore済）に `GH_TOKEN` を保存
- `.env.example` がテンプレート
- 絶対に `.env` をコミットしない / チャットに貼り出さない / メモリに保存しない

### 3. GitHub操作はghコマンド経由

- リポは `miyashita337/openclaw-rpi5-ops`
- issue・PR・release作成はすべて `gh` で
- ブラウザ操作で代替しない（速度・履歴の観点で `gh` が優位）

### 4. ユーザーに作業させない原則

- 「このコマンドをターミナルで実行してください」は禁止
- 必要な操作はCoworkのbash・file toolsで完結させる
- どうしてもユーザー操作が必要な場合（ブラウザ承認等）は明示し、最小限に

## ファイル構成

| 公開 (git tracked) | 非公開 (gitignore 済、ローカル参照のみ) |
|---|---|
| `README.md` (リポ landing) | `docs/IMPLEMENTATION_CHECKLIST.md` (hardening 実装チェックリスト) |
| `CLAUDE.md` (本ファイル、Claude 向け規約) | `docs/openclaw_rpi5_project_overview.md` (連載全体構成) |
| `articles/<slug>.md` (Zenn 公開記事) | `docs/ISSUE_DRAFT_rd-verification-article.md` (Issue ドラフト) |
| `etc/systemd/system/openclaw-gateway.service` | `docs/review-checklist/<slug>.md` (記事レビュー checklist) |
| `scripts/` (cowork-bootstrap 等の運用スクリプト) | `docs/superpowers/specs/<date>-<slug>.md` (内部設計 spec) |
| `package.json`, `node_modules/` (zenn-cli) | `images/<slug>/*.png` (記事用 screenshot、Zenn が local preview で参照) |
| `.gitignore`, `.claude/settings.json` | `.claude/settings.local.json` (個人 SSH allow 等) |

### 参照ルール

- 内部 docs は **Claude が編集・参照する場合は絶対パス** で扱う (`/Users/harieshokunin/openclaw-rpi5-ops/docs/<file>.md`)
- 公開記事の本文中で内部 docs を参照しない (URL リンクが解決しなくなる)
- 内部 docs を新規作成する場合は **必ず `docs/` 配下** に置く (root 直下に置かない)
- gitignore 解除して公開したい docs があれば該当ファイルだけ `!docs/specific-file.md` を `.gitignore` に追記する設計
