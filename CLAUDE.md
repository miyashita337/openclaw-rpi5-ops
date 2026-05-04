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
