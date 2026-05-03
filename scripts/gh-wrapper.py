#!/usr/bin/env python3
"""
gh-wrapper.py — Python製ghコマンド互換ラッパー

背景: Coworkサンドボックスのproxy allowlistにより、
公式gh CLI バイナリを取得できないため、PyGithub経由で
GitHub APIを叩く最小限のgh互換CLIを提供する。

サポートコマンド:
    gh auth status
    gh auth login --with-token            (stdinからトークン読込)
    gh repo view [REPO]
    gh repo set-default REPO
    gh issue list   [-R REPO] [--state {open,closed,all}] [-L LIMIT]
    gh issue create [-R REPO] -t TITLE -b BODY [-l LABEL ...]
    gh issue view   NUMBER [-R REPO]
    gh issue close  NUMBER [-R REPO]
    gh pr list      [-R REPO] [--state {open,closed,merged,all}]
    gh pr view      NUMBER [-R REPO]
    gh api ENDPOINT [--method M] [-f K=V ...]

トークン解決順:
    1. --with-token (stdin)
    2. 環境変数 GH_TOKEN / GITHUB_TOKEN
    3. ~/.config/gh-wrapper/token
    4. リポ直下 .env の GH_TOKEN

デフォルトリポ解決順:
    1. -R/--repo フラグ
    2. ~/.config/gh-wrapper/default_repo
    3. git config --get remote.origin.url
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

CONFIG_DIR = Path.home() / ".config" / "gh-wrapper"
TOKEN_FILE = CONFIG_DIR / "token"
DEFAULT_REPO_FILE = CONFIG_DIR / "default_repo"


def info(msg: str) -> None:
    print(msg, file=sys.stderr)


def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def load_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def find_repo_root() -> Optional[Path]:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
        )
        return Path(out.decode().strip())
    except Exception:
        return None


def resolve_token() -> str:
    # 1. env
    for var in ("GH_TOKEN", "GITHUB_TOKEN"):
        v = os.environ.get(var)
        if v:
            return v
    # 2. token file
    if TOKEN_FILE.is_file():
        t = TOKEN_FILE.read_text(encoding="utf-8").strip()
        if t:
            return t
    # 3. .env in repo root
    root = find_repo_root()
    if root:
        env = load_dotenv(root / ".env")
        if env.get("GH_TOKEN"):
            return env["GH_TOKEN"]
    die("認証トークンが見つかりません。`gh auth login --with-token` を実行するか .env に GH_TOKEN を設定してください")


def resolve_repo(explicit: Optional[str]) -> str:
    if explicit:
        return explicit
    if DEFAULT_REPO_FILE.is_file():
        v = DEFAULT_REPO_FILE.read_text(encoding="utf-8").strip()
        if v:
            return v
    # try git remote
    try:
        out = subprocess.check_output(
            ["git", "config", "--get", "remote.origin.url"],
            stderr=subprocess.DEVNULL,
        ).decode().strip()
        m = re.match(r"^(?:https://github\.com/|git@github\.com:)([^/]+/[^/]+?)(?:\.git)?$", out)
        if m:
            return m.group(1)
    except Exception:
        pass
    die("リポジトリが指定されていません。-R OWNER/REPO を指定するか `gh repo set-default OWNER/REPO` を実行してください")


def get_client():
    try:
        from github import Auth, Github  # type: ignore
    except ImportError:
        die("PyGithub が必要です: pip install --break-system-packages PyGithub")
    token = resolve_token()
    return Github(auth=Auth.Token(token))


# ----- subcommands -----


def cmd_auth_login(args: argparse.Namespace) -> None:
    if not args.with_token:
        die("--with-token のみサポートしています（インタラクティブログインは未対応）")
    token = sys.stdin.read().strip()
    if not token:
        die("stdin からトークンを読み取れませんでした")
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.write_text(token, encoding="utf-8")
    TOKEN_FILE.chmod(0o600)
    # 検証
    os.environ["GH_TOKEN"] = token
    try:
        g = get_client()
        user = g.get_user()
        info(f"✓ Logged in to github.com as {user.login}")
    except Exception as e:
        die(f"トークン検証失敗: {e}")


def cmd_auth_status(args: argparse.Namespace) -> None:
    try:
        g = get_client()
        user = g.get_user()
        rate = g.get_rate_limit().core
        print(f"github.com")
        print(f"  ✓ Logged in to github.com as {user.login}")
        print(f"  ✓ Token: ***{resolve_token()[-4:]}")
        print(f"  ✓ Rate limit: {rate.remaining}/{rate.limit} (reset {rate.reset.isoformat()})")
    except Exception as e:
        die(f"認証エラー: {e}")


def cmd_repo_view(args: argparse.Namespace) -> None:
    repo_name = resolve_repo(args.repo or args.target)
    g = get_client()
    repo = g.get_repo(repo_name)
    if args.json:
        print(json.dumps({
            "name": repo.name,
            "full_name": repo.full_name,
            "description": repo.description,
            "url": repo.html_url,
            "default_branch": repo.default_branch,
            "private": repo.private,
            "stars": repo.stargazers_count,
            "open_issues": repo.open_issues_count,
        }, indent=2, ensure_ascii=False))
        return
    print(f"name:        {repo.full_name}")
    print(f"description: {repo.description or '(none)'}")
    print(f"url:         {repo.html_url}")
    print(f"branch:      {repo.default_branch}")
    print(f"private:     {repo.private}")
    print(f"open issues: {repo.open_issues_count}")


def cmd_repo_set_default(args: argparse.Namespace) -> None:
    if not re.match(r"^[^/]+/[^/]+$", args.repo_arg):
        die("OWNER/REPO 形式で指定してください")
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    DEFAULT_REPO_FILE.write_text(args.repo_arg, encoding="utf-8")
    info(f"✓ default repo: {args.repo_arg}")


def cmd_issue_list(args: argparse.Namespace) -> None:
    repo_name = resolve_repo(args.repo)
    g = get_client()
    repo = g.get_repo(repo_name)
    state = "all" if args.state == "all" else args.state
    issues = repo.get_issues(state=state)
    rows = []
    for i, iss in enumerate(issues):
        if iss.pull_request is not None:
            continue  # ghはissue listでPRを除外
        if i >= args.limit:
            break
        rows.append(iss)
    if args.json:
        print(json.dumps(
            [{
                "number": i.number,
                "title": i.title,
                "state": i.state,
                "labels": [l.name for l in i.labels],
                "url": i.html_url,
                "createdAt": i.created_at.isoformat(),
            } for i in rows],
            indent=2, ensure_ascii=False))
        return
    if not rows:
        print(f"no open issues in {repo_name}")
        return
    print(f"\nShowing {len(rows)} issue(s) in {repo_name}\n")
    for i in rows:
        labels = ",".join(l.name for l in i.labels)
        print(f"#{i.number:<5} {i.state:<7} {i.title}   {f'({labels})' if labels else ''}")


def cmd_issue_create(args: argparse.Namespace) -> None:
    repo_name = resolve_repo(args.repo)
    g = get_client()
    repo = g.get_repo(repo_name)
    body = args.body or ""
    labels = args.label or []
    issue = repo.create_issue(title=args.title, body=body, labels=labels)
    print(issue.html_url)


def cmd_issue_view(args: argparse.Namespace) -> None:
    repo_name = resolve_repo(args.repo)
    g = get_client()
    repo = g.get_repo(repo_name)
    iss = repo.get_issue(args.number)
    if args.json:
        print(json.dumps({
            "number": iss.number,
            "title": iss.title,
            "state": iss.state,
            "body": iss.body,
            "url": iss.html_url,
            "author": iss.user.login,
            "labels": [l.name for l in iss.labels],
            "createdAt": iss.created_at.isoformat(),
        }, indent=2, ensure_ascii=False))
        return
    print(f"#{iss.number} {iss.title}")
    print(f"state:  {iss.state}")
    print(f"author: {iss.user.login}")
    print(f"url:    {iss.html_url}")
    print(f"labels: {','.join(l.name for l in iss.labels)}")
    print()
    print(iss.body or "(no body)")


def cmd_issue_close(args: argparse.Namespace) -> None:
    repo_name = resolve_repo(args.repo)
    g = get_client()
    repo = g.get_repo(repo_name)
    iss = repo.get_issue(args.number)
    iss.edit(state="closed")
    print(f"✓ Closed issue #{iss.number}")


def cmd_pr_list(args: argparse.Namespace) -> None:
    repo_name = resolve_repo(args.repo)
    g = get_client()
    repo = g.get_repo(repo_name)
    state = args.state if args.state != "merged" else "closed"
    prs = repo.get_pulls(state=state)
    rows = []
    for i, pr in enumerate(prs):
        if args.state == "merged" and not pr.merged:
            continue
        if i >= args.limit:
            break
        rows.append(pr)
    if not rows:
        print(f"no PRs in {repo_name}")
        return
    print(f"\nShowing {len(rows)} PR(s) in {repo_name}\n")
    for pr in rows:
        merged = " [merged]" if pr.merged else ""
        print(f"#{pr.number:<5} {pr.state:<7} {pr.title}{merged}")


def cmd_pr_view(args: argparse.Namespace) -> None:
    repo_name = resolve_repo(args.repo)
    g = get_client()
    repo = g.get_repo(repo_name)
    pr = repo.get_pull(args.number)
    print(f"#{pr.number} {pr.title}")
    print(f"state:  {pr.state}{' (merged)' if pr.merged else ''}")
    print(f"author: {pr.user.login}")
    print(f"branch: {pr.head.ref} -> {pr.base.ref}")
    print(f"url:    {pr.html_url}")
    print()
    print(pr.body or "(no body)")


def cmd_api(args: argparse.Namespace) -> None:
    g = get_client()
    method = args.method or "GET"
    fields: dict[str, str] = {}
    for f in args.fields or []:
        if "=" not in f:
            die(f"-f は KEY=VALUE 形式: {f}")
        k, v = f.split("=", 1)
        fields[k] = v
    headers, data = g._Github__requester.requestJsonAndCheck(  # type: ignore[attr-defined]
        method, args.endpoint if args.endpoint.startswith("/") else "/" + args.endpoint,
        input=fields if fields else None,
    )
    print(json.dumps(data, indent=2, ensure_ascii=False))


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="gh", description="Python wrapper for gh (subset)")
    sub = p.add_subparsers(dest="cmd", required=True)

    # auth
    auth = sub.add_parser("auth")
    asub = auth.add_subparsers(dest="auth_cmd", required=True)
    a_login = asub.add_parser("login")
    a_login.add_argument("--with-token", action="store_true")
    a_login.add_argument("--hostname", default="github.com")
    a_login.set_defaults(func=cmd_auth_login)
    a_status = asub.add_parser("status")
    a_status.set_defaults(func=cmd_auth_status)

    # repo
    repo = sub.add_parser("repo")
    rsub = repo.add_subparsers(dest="repo_cmd", required=True)
    r_view = rsub.add_parser("view")
    r_view.add_argument("target", nargs="?")
    r_view.add_argument("-R", "--repo", default=None)
    r_view.add_argument("--json", action="store_true")
    r_view.set_defaults(func=cmd_repo_view)
    r_setd = rsub.add_parser("set-default")
    r_setd.add_argument("repo_arg")
    r_setd.set_defaults(func=cmd_repo_set_default)

    # issue
    issue = sub.add_parser("issue")
    isub = issue.add_subparsers(dest="issue_cmd", required=True)
    i_list = isub.add_parser("list")
    i_list.add_argument("-R", "--repo", default=None)
    i_list.add_argument("--state", choices=["open", "closed", "all"], default="open")
    i_list.add_argument("-L", "--limit", type=int, default=30)
    i_list.add_argument("--json", action="store_true")
    i_list.set_defaults(func=cmd_issue_list)
    i_create = isub.add_parser("create")
    i_create.add_argument("-R", "--repo", default=None)
    i_create.add_argument("-t", "--title", required=True)
    i_create.add_argument("-b", "--body", default="")
    i_create.add_argument("-l", "--label", action="append", default=[])
    i_create.set_defaults(func=cmd_issue_create)
    i_view = isub.add_parser("view")
    i_view.add_argument("number", type=int)
    i_view.add_argument("-R", "--repo", default=None)
    i_view.add_argument("--json", action="store_true")
    i_view.set_defaults(func=cmd_issue_view)
    i_close = isub.add_parser("close")
    i_close.add_argument("number", type=int)
    i_close.add_argument("-R", "--repo", default=None)
    i_close.set_defaults(func=cmd_issue_close)

    # pr
    pr = sub.add_parser("pr")
    psub = pr.add_subparsers(dest="pr_cmd", required=True)
    p_list = psub.add_parser("list")
    p_list.add_argument("-R", "--repo", default=None)
    p_list.add_argument("--state", choices=["open", "closed", "merged", "all"], default="open")
    p_list.add_argument("-L", "--limit", type=int, default=30)
    p_list.set_defaults(func=cmd_pr_list)
    p_view = psub.add_parser("view")
    p_view.add_argument("number", type=int)
    p_view.add_argument("-R", "--repo", default=None)
    p_view.set_defaults(func=cmd_pr_view)

    # api
    api = sub.add_parser("api")
    api.add_argument("endpoint")
    api.add_argument("--method", default="GET")
    api.add_argument("-f", "--field", action="append", dest="fields", default=[])
    api.set_defaults(func=cmd_api)

    return p


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.func(args)
    except SystemExit:
        raise
    except Exception as e:
        die(str(e))


if __name__ == "__main__":
    main()
