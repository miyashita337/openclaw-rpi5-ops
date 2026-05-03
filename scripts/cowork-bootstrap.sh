#!/usr/bin/env bash
# cowork-bootstrap.sh
# Cowork (Linux sandbox) 用ブートストラップ:
#
# Coworkサンドボックスのproxy allowlistにより公式gh CLIバイナリを取得できない
# (api.github.com / release-assets.githubusercontent.com / codeload.github.com
#  などが blocked-by-allowlist) ため、Python製ghラッパー方式で代替する。
#
# 処理:
#   1. PyGithub を pip install (PyPI は通る)
#   2. scripts/gh-wrapper.py を ~/.local/bin/gh としてリンク
#   3. ~/.bashrc に PATH 追加
#   4. .env から GH_TOKEN を読み、~/.config/gh-wrapper/token に保存（永続化）
#   5. デフォルトリポを設定
#
# 冪等。何度実行してもOK。
#
# 注意: bash callは独立プロセスなので、各callで以下のいずれかを使う:
#   - PATH に ~/.local/bin を含める: `export PATH="$HOME/.local/bin:$PATH" && gh ...`
#   - 絶対パス:                      `~/.local/bin/gh ...`

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
INSTALL_DIR="${HOME}/.local/bin"
WRAPPER_SRC="${REPO_ROOT}/scripts/gh-wrapper.py"
WRAPPER_DST="${INSTALL_DIR}/gh"
GH_CONFIG_DIR="${HOME}/.config/gh-wrapper"
STATE_FILE="${REPO_ROOT}/.cowork-bootstrap.done"

mkdir -p "${INSTALL_DIR}" "${GH_CONFIG_DIR}"
chmod 700 "${GH_CONFIG_DIR}"
export PATH="${INSTALL_DIR}:${PATH}"

log() { printf "\033[36m[bootstrap]\033[0m %s\n" "$*"; }
err() { printf "\033[31m[bootstrap ERR]\033[0m %s\n" "$*" >&2; }

# --- 1. PyGithub インストール ---
if ! python3 -c "from github import Github, Auth" >/dev/null 2>&1; then
  log "PyGithub をインストール"
  pip install --break-system-packages --quiet PyGithub
else
  log "PyGithub 検出済み"
fi

# --- 2. gh wrapper を ~/.local/bin/gh に配置 ---
if [[ ! -f "${WRAPPER_SRC}" ]]; then
  err "wrapper ソース未存在: ${WRAPPER_SRC}"
  exit 1
fi
chmod +x "${WRAPPER_SRC}"
# シンボリックリンク貼り直し（リポを再mountしてもパスが追従）
ln -sf "${WRAPPER_SRC}" "${WRAPPER_DST}"
log "gh wrapper 配置: ${WRAPPER_DST} -> ${WRAPPER_SRC}"

# --- 3. PATH を .bashrc に永続化 ---
if ! grep -q '\.local/bin' "${HOME}/.bashrc" 2>/dev/null; then
  {
    echo ''
    echo '# Added by cowork-bootstrap.sh'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "${HOME}/.bashrc"
  log ".bashrc に PATH 追加"
fi

# --- 4. .env 読み込み ---
if [[ ! -f "${ENV_FILE}" ]]; then
  err ".env が存在しません: ${ENV_FILE}"
  err ".env.example をコピーして GH_TOKEN を入れてください"
  exit 1
fi

# shellcheck disable=SC1090
set -a; source "${ENV_FILE}"; set +a

if [[ -z "${GH_TOKEN:-}" ]]; then
  err ".env に GH_TOKEN が設定されていません"
  exit 1
fi

# --- 5. トークンを ~/.config/gh-wrapper/token に永続化 ---
TOKEN_VALUE="${GH_TOKEN}"
echo "${TOKEN_VALUE}" | "${WRAPPER_DST}" auth login --with-token

# --- 6. デフォルトリポ設定 ---
if [[ -n "${GH_REPO:-}" ]]; then
  "${WRAPPER_DST}" repo set-default "${GH_REPO}"
fi

# --- 7. 動作確認 ---
log "gh auth status:"
"${WRAPPER_DST}" auth status

# --- 完了マーカー ---
date -u +"%Y-%m-%dT%H:%M:%SZ" > "${STATE_FILE}"
log "ブートストラップ完了 ✅"
log ""
log "Coworkで gh を使うには各bash callの先頭で:"
log "  export PATH=\"\$HOME/.local/bin:\$PATH\""
log "を実行してください（.bashrcにも記載済）"
