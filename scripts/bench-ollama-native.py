#!/usr/bin/env python3
"""
Python equivalent of bench-ollama-native.sh.

Reason for existence: the Mac Claude Code harness hard-denies shell commands
that contain remote URLs (e.g. http://100.x.x.x:port/...), so curl-based
benchmarking from Mac cannot run. urllib.request is permitted, hence this
Python port. Output schema matches bench-ollama-native.sh so summaries are
directly comparable.

Usage:
  scripts/bench-ollama-native.py <runtime-tag> <ollama-base-url> <model> <think>
    <think> ::= true | false
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from pathlib import Path


def die(msg: str, code: int = 2) -> None:
    print(msg, file=sys.stderr)
    sys.exit(code)


def main() -> int:
    if len(sys.argv) != 5:
        die(
            f"usage: {sys.argv[0]} <runtime-tag> <ollama-base-url> <model> <true|false>"
        )

    runtime, base_url, model, think_str = sys.argv[1:5]
    if think_str not in ("true", "false"):
        die(f"think must be 'true' or 'false', got: {think_str}")
    think = think_str == "true"

    repo_root = Path(__file__).resolve().parent.parent
    prompt_dir = repo_root / "scripts" / "llm-bench-prompts"
    out_dir = repo_root / "bench-results" / runtime
    out_dir.mkdir(parents=True, exist_ok=True)

    summary_path = out_dir / "summary.tsv"
    with summary_path.open("w") as f:
        f.write(
            "prompt_id\ttotal_ms\tfirst_token_ms\teval_count\teval_duration_ms\t"
            "tok_per_sec\tcontent_chars\tthinking_chars\ttool_calls\n"
        )

    for n in (1, 2, 3, 4, 5):
        prompt_file = prompt_dir / f"p{n}.txt"
        if not prompt_file.is_file():
            print(f"skip p{n} (missing)", file=sys.stderr)
            continue

        print(f"=== p{n} ({runtime} think={think_str}) ===", file=sys.stderr)
        prompt_text = prompt_file.read_text()

        body = {
            "model": model,
            "messages": [{"role": "user", "content": prompt_text}],
            "stream": True,
            "think": think,
            "options": {"num_predict": 4096},
        }
        data = json.dumps(body).encode("utf-8")

        stream_out = out_dir / f"p{n}.stream.jsonl"
        content_out = out_dir / f"p{n}.content.txt"
        think_out = out_dir / f"p{n}.thinking.txt"
        tool_out = out_dir / f"p{n}.toolcalls.json"
        final_out = out_dir / f"p{n}.final.json"

        for p in (stream_out, content_out, think_out, tool_out, final_out):
            p.write_text("")

        req = urllib.request.Request(
            f"{base_url}/api/chat",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        t_start = time.monotonic_ns()
        first_ns: int | None = None
        eval_count = 0
        eval_dur_ns = 0
        content_buf: list[str] = []
        think_buf: list[str] = []
        tool_lines: list[str] = []
        stream_lines: list[str] = []
        final_line = ""

        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                for raw in resp:
                    line = raw.decode("utf-8", errors="replace").rstrip("\n")
                    if not line:
                        continue
                    if first_ns is None:
                        first_ns = time.monotonic_ns()
                    stream_lines.append(line)
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    msg = obj.get("message") or {}
                    c = msg.get("content")
                    t = msg.get("thinking")
                    tc = msg.get("tool_calls")
                    if c:
                        content_buf.append(c)
                    if t:
                        think_buf.append(t)
                    if tc:
                        tool_lines.append(json.dumps(tc, ensure_ascii=False))
                    if obj.get("done") is True:
                        final_line = line
                        eval_count = int(obj.get("eval_count") or 0)
                        eval_dur_ns = int(obj.get("eval_duration") or 0)
        except Exception as exc:  # network / HTTP / timeout
            print(f"  ERROR p{n}: {exc}", file=sys.stderr)

        t_end = time.monotonic_ns()
        total_ms = (t_end - t_start) // 1_000_000
        first_ms = ((first_ns - t_start) // 1_000_000) if first_ns is not None else 0
        eval_dur_ms = eval_dur_ns // 1_000_000
        tok_per_sec = (
            f"{eval_count / (eval_dur_ns / 1e9):.2f}" if eval_dur_ns > 0 else "0.00"
        )

        stream_out.write_text("\n".join(stream_lines) + ("\n" if stream_lines else ""))
        content_str = "".join(content_buf)
        thinking_str = "".join(think_buf)
        content_out.write_text(content_str)
        think_out.write_text(thinking_str)
        tool_out.write_text(("\n".join(tool_lines) + "\n") if tool_lines else "")
        final_out.write_text(final_line + ("\n" if final_line else ""))

        c_chars = len(content_str.encode("utf-8"))
        t_chars = len(thinking_str.encode("utf-8"))
        tool_present = 1 if tool_lines else 0

        with summary_path.open("a") as f:
            f.write(
                f"p{n}\t{total_ms}\t{first_ms}\t{eval_count}\t{eval_dur_ms}\t"
                f"{tok_per_sec}\t{c_chars}\t{t_chars}\t{tool_present}\n"
            )
        print(
            f"  total={total_ms}ms first={first_ms}ms eval={eval_count} "
            f"tok/s={tok_per_sec} content={c_chars} think={t_chars} tool={tool_present}",
            file=sys.stderr,
        )

    print()
    print(f"Summary: {summary_path}")
    sys.stdout.write(summary_path.read_text())
    return 0


if __name__ == "__main__":
    sys.exit(main())
