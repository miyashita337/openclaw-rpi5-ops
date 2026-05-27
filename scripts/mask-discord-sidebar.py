#!/usr/bin/env python3
"""Discord DM スクショの左サイドバー (DM リスト・他ユーザー名) を blur マスクする。

PUBLIC repo に貼るため、サイドバーに映り込む他ユーザー名・DM リストを隠す。
会話本文 (中央〜右) は記事素材として残す。OCR 不要、座標ベースの汎用マスク。
"""
import sys
from PIL import Image, ImageFilter

# 左サイドバー比率 (サーバーアイコン列 + DM/チャンネルリスト)。Discord 標準レイアウト基準。
SIDEBAR_RATIO = 0.24
BLUR_RADIUS = 20

files = sys.argv[1:] if len(sys.argv) > 1 else [
    "docs/screenshots/discord-dm-1.png",
    "docs/screenshots/discord-dm-2.png",
    "docs/screenshots/discord-dm-3.png",
]

for f in files:
    img = Image.open(f).convert("RGB")
    w, h = img.size
    sidebar_w = int(w * SIDEBAR_RATIO)
    region = img.crop((0, 0, sidebar_w, h))
    region = region.filter(ImageFilter.GaussianBlur(radius=BLUR_RADIUS))
    img.paste(region, (0, 0))
    out = f.replace(".png", "-masked.png")
    img.save(out)
    print(f"{out} size={img.size} sidebar_w={sidebar_w}")
