#!/usr/bin/env python3
"""
Discord ↔ Ollama 最小 forward bot.

設計判断 (#11 Phase 2 のピボット理由):
  OpenClaw 経由で Discord → Ollama 経路を作ろうとして session affinity / gateway
  token / mention filter 等の壁に詰まり、AgentTeams 診断で「要件外の agentic
  framework は overkill」と全員一致でピボット推奨されたため、純粋な forward
  だけを担う最小 bot を別 systemd unit で常駐させる。OpenClaw (#14 で採用判定し
  たが Discord 経路は破棄) は OpenAI 経路として温存。

要件:
  - Discord で @mention → Tailscale 越しに Win Ollama (qwen3.6:27b) → 応答
  - tool calling / memory / MCP / web search 等は持たない (要件外)
  - systemd で常駐、エラー時 reply に出す (silent fail 禁止)

依存:
  pip install discord.py>=2.3 httpx>=0.27 python-dotenv>=1.0

env (~/.env):
  DISCORD_TOKEN=<新規 bot token>
  OLLAMA_URL=http://100.123.241.106:11434
  OLLAMA_MODEL=qwen3.6:27b
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from typing import Iterator

import discord
import httpx
from dotenv import load_dotenv

load_dotenv()

LOG = logging.getLogger("discord-ollama-bridge")
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

TOKEN = os.environ.get("DISCORD_TOKEN")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://100.123.241.106:11434").rstrip("/")
MODEL = os.environ.get("OLLAMA_MODEL", "qwen3.6:27b")
TIMEOUT_SECONDS = int(os.environ.get("OLLAMA_TIMEOUT", "300"))
MAX_DISCORD_CHARS = 1900  # Discord hard limit 2000、余裕を見て 1900

if not TOKEN:
    sys.exit("DISCORD_TOKEN env var is required")

intents = discord.Intents.default()
intents.message_content = True
intents.guilds = True
intents.messages = True
client = discord.Client(intents=intents)


async def query_ollama(prompt: str) -> str:
    """Ollama native /api/chat を non-stream で叩く。think:false で thinking 無効化。"""
    async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as http:
        resp = await http.post(
            f"{OLLAMA_URL}/api/chat",
            json={
                "model": MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "stream": False,
                "think": False,
                "options": {"num_predict": 4096},
            },
        )
        resp.raise_for_status()
        body = resp.json()
        message = body.get("message") or {}
        content = (message.get("content") or "").strip()
        if not content:
            raise RuntimeError(f"empty response: {body!r}")
        return content


def chunk_for_discord(text: str) -> Iterator[str]:
    """Discord 2000 文字制限を超えたら分割。改行優先で切る。"""
    if len(text) <= MAX_DISCORD_CHARS:
        yield text
        return
    remaining = text
    while remaining:
        if len(remaining) <= MAX_DISCORD_CHARS:
            yield remaining
            return
        cut = remaining.rfind("\n", 0, MAX_DISCORD_CHARS)
        if cut <= 0:
            cut = MAX_DISCORD_CHARS
        yield remaining[:cut]
        remaining = remaining[cut:].lstrip("\n")


def strip_mention(content: str, bot_user: discord.ClientUser) -> str:
    raw = content.replace(f"<@{bot_user.id}>", "").replace(f"<@!{bot_user.id}>", "")
    return raw.strip()


@client.event
async def on_ready() -> None:
    LOG.info(
        "logged in as %s (id=%s) ollama=%s/%s",
        client.user,
        client.user.id if client.user else "?",
        OLLAMA_URL,
        MODEL,
    )


@client.event
async def on_message(message: discord.Message) -> None:
    if not client.user or message.author == client.user or message.author.bot:
        return
    is_dm = isinstance(message.channel, discord.DMChannel)
    mentioned = client.user in message.mentions
    if not (is_dm or mentioned):
        return

    prompt = strip_mention(message.content, client.user)
    if not prompt:
        await message.reply("メッセージ本文が空です。質問を書いてください。")
        return

    LOG.info(
        "msg author=%s channel=%s len=%d",
        message.author.id,
        getattr(message.channel, "id", "dm"),
        len(prompt),
    )

    async with message.channel.typing():
        try:
            reply = await query_ollama(prompt)
        except httpx.HTTPStatusError as exc:
            LOG.exception("ollama HTTP error")
            await message.reply(
                f"⚠️ Ollama HTTP {exc.response.status_code}: {exc.response.text[:200]}"
            )
            return
        except Exception as exc:
            LOG.exception("ollama error")
            await message.reply(f"⚠️ Ollama error: {exc}")
            return

    for chunk in chunk_for_discord(reply):
        await message.reply(chunk)


def main() -> None:
    try:
        client.run(TOKEN, log_handler=None)
    except KeyboardInterrupt:
        asyncio.run(client.close())


if __name__ == "__main__":
    main()
