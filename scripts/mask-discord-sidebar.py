#!/usr/bin/env python3
"""Discord DM スクショの左サイドバー (DM リスト・他ユーザー名) を塗りつぶしマスクする。

PUBLIC repo に貼るため、サイドバーに映り込む他ユーザー名・DM リストを隠す。
会話本文 (中央〜右) は記事素材として残す。OCR 不要、座標ベースの汎用マスク。
blur は可逆リスクがあるため Discord ダークサイドバー色の単色矩形で不可逆に覆う。
"""
import argparse
from pathlib import Path

from PIL import Image

SIDEBAR_RATIO = 0.24  # サーバーアイコン列 + DM/チャンネルリスト。Discord 標準レイアウト基準。
SIDEBAR_COLOR = "#2b2d31"  # Discord dark theme のサイドバー背景色

DEFAULT_IMAGES = [
    "articles/openclaw-07-local-llm-self-defense/images/discord-dm-1.png",
    "articles/openclaw-07-local-llm-self-defense/images/discord-dm-2.png",
    "articles/openclaw-07-local-llm-self-defense/images/discord-dm-3.png",
]

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("images", nargs="*", default=DEFAULT_IMAGES)
parser.add_argument("--crop-top", type=int, default=0, help="上端から crop する px 数")
parser.add_argument("--crop-bottom", type=int, default=0, help="下端から crop する px 数")
args = parser.parse_args()

for name in args.images:
    src = Path(name)
    if not src.is_file():
        parser.exit(1, f"error: input file not found: {src}\n")
    img = Image.open(src).convert("RGB")
    w, h = img.size
    bottom = h - args.crop_bottom
    if args.crop_top >= bottom:
        parser.exit(1, f"error: crops exceed image height for {src}\n")
    img = img.crop((0, args.crop_top, w, bottom))
    w, h = img.size
    sidebar_w = int(w * SIDEBAR_RATIO)
    img.paste(Image.new("RGB", (sidebar_w, h), SIDEBAR_COLOR), (0, 0))
    out = src.with_name(f"{src.stem}-masked{src.suffix}")
    img.save(out)
    print(f"{out} size={img.size} sidebar_w={sidebar_w}")
