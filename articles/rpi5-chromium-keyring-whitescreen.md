---
title: "Raspberry Pi 5 で Chromium が真っ白で操作不能 — 犯人は --no-decommit-pooled-pages じゃなく Gnome Keyring だった"
emoji: "🔑"
type: "tech"
topics: ["raspberrypi", "chromium", "wayland", "gnomekeyring", "trixie"]
published: false
---

## TL;DR（数行でまとめ）

Raspberry Pi 5 (Trixie / Wayland) で Chromium がデスクトップ上で真っ白のまま URL バーが反応しなくなる症状を 1 セッションで切り分けた話です。**犯人は 3 つ目の仮説**でした。

1. **仮説 1 (Debian launcher の `--js-flags=--no-decommit-pooled-pages`) は red herring** — Debian chromium パッケージが aarch64 + 16KB page kernel に対して [Debian Bug #1089647](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1089647) のワークアラウンドとして自動付与するフラグですが、Chromium 147 の V8 はこのフラグを廃止済みで warning のみ。**真っ白問題とは無関係**でした
2. **仮説 2 (前回クラッシュの「ページを復元しますか？」ダイアログ) は副次原因** — `~/.config/chromium/Default/Preferences` の `exit_type` を `Normal` に書き換える + SIGTERM clean shutdown 運用で解消
3. **仮説 3 (Gnome Keyring 認証ダイアログ) が真犯人** — wells で `pam_gnome_keyring.so` の auto-unlock が機能しておらず、Chromium 起動時に keyring unlock 用のモーダルダイアログが出てフォーカスを独占 → URL バー無反応 → 画面共有越しでは「真っ白で固まった」に見える、という構造でした
4. **永続化は sudo 不要で 2 経路** — `~/.local/share/applications/chromium.desktop` (ユーザー scope override) + `~/.local/bin/chromium` wrapper の合わせ技で、CLI / デスクトップアイコンどちらの起動経路でも `--password-store=basic` が乗ります

<!-- TODO: 00-cover.png を撮影 (Pi Connect の画面共有越しに Chromium が真っ白で keyring ダイアログだけ手前に出ている構図) -->

## はじめに

Raspberry Pi 5 (wells) を 24h 稼働させていて、ブラウザでちょっと URL を開きたい場面で症状に出会いました。Pi Connect の画面共有越しに見ると **Chromium のタブと URL バーは描画されているのに、URL を入れても enter を押してもページが遷移しない**。同じ画面のターミナルでは別作業 (`gh auth login --hostname`) を走らせていて、そっちには `Error: unrecognized flag --no-decommit-pooled-pages` のエラーが連発で流れていました。

このエラーログがちょうどよく目に入った結果、調査の初動を **完全に間違った方向にスタート** させてしまいました。ここから先は「正解にたどり着くまでの寄り道」を寄り道として書き残します。同じハマり方をする人のためのナレッジということで。

:::message
個人 Raspberry Pi 5 / Raspberry Pi OS Trixie (Debian 13 ベース) / Wayland session (Wayfire) / Tailscale SSH + Pi Connect で画面共有という構成を前提にしています。X11 セッションや別ディストリでは症状の出方が違う可能性があります。
:::

## Step 0: 観察した症状と環境

- **症状**: Chromium 起動済み、タブ・URL バー・bookmark bar は表示される。URL 入力に反応しない、リロードしてもダメ
- **環境**: Pi 5 / `Linux 6.12.75+rpt-rpi-2712` / Debian Trixie / Wayland (Wayfire) / Chromium 147.0.7727.101 (Debian パッケージ)
- **ターミナルログ**: `Error: unrecognized flag --no-decommit-pooled-pages` が `gh` 操作中に大量出力
- **アクセス経路**: Tailscale SSH (`ssh wells`) + Pi Connect screen-sharing-session

## Step 1: 仮説 1 — `--no-decommit-pooled-pages` フラグが真犯人 (→ red herring)

ターミナルに出続けている `unrecognized flag` をまず疑いました。`pgrep -af chromium` で起動コマンドラインを見ると、自分が指定していない `--js-flags=--no-decommit-pooled-pages` が確かに混入しています。

```
/usr/lib/chromium/chromium --js-flags=--no-decommit-pooled-pages
    --force-renderer-accessibility --enable-remote-extensions
    --show-component-extension-options --enable-gpu-rasterization
    --no-default-browser-check --disable-pings --media-router=0
    --enable-remote-extensions --load-extension --use-angle=gles
    --no-sandbox about:blank
```

どこから入っているのか。`/etc/chromium.d/` / `~/.config/chromium-flags.conf` / `~/.config/chromium/` / `/usr/share/chromium/` / `/usr/lib/chromium/` を全部 `grep -rln 'decommit-pooled-pages'` で舐めても **0 件**。ディスク上に文字列が無いのに、なぜか実プロセスには付いている。

ここで気付くのが「`/usr/bin/chromium` は POSIX shell script ラッパー」だということです。中を読みに行きました。

```sh
# /usr/bin/chromium の抜粋
aarch64)
    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1089647
    if [ "$(getconf PAGESIZE)" -gt "4096" ]; then
        CHROMIUM_FLAGS="$CHROMIUM_FLAGS --js-flags=--no-decommit-pooled-pages"
    fi
    ;;
```

**Debian chromium パッケージが aarch64 + 16KB page kernel の組み合わせで自動付与するワークアラウンド**でした。Pi 5 では `getconf PAGESIZE` が `16384` を返すので、まさに発動条件。Debian Bug #1089647 によると、V8 のヒープ管理が 16KB page だと壊れるので無効化、という意図のフラグだそうです。

ただし、Chromium 147 の V8 ではこのフラグが廃止または改名されており、launcher 側が追従していないため warning だけが出続けている状態。

**ここで早合点しました**: 「これだ、このフラグが Chromium のレンダラを壊しているに違いない」と。launcher をバイパスして `/usr/lib/chromium/chromium` を直接叩けば検証できます。

```bash
DISPLAY=:0 /usr/lib/chromium/chromium --no-sandbox about:blank
```

ところがこれを `nohup` で投げてから `scrot` でスクリーンショットを取ろうとしたら **真っ黒の画像** が返ってきました。

<!-- TODO: 01-scrot-black.png を貼る (scrot で取った真っ黒な screenshot を実機で再撮影) -->

ここで「真っ白問題以前に、画面取得の経路自体が壊れている」と気付きます。

## Step 2: 環境発見 — Wayland セッション + `grim` の三点セット

`loginctl show-session` で確認したところ:

```
Type=wayland
Display=tty1
Class=user
Remote=no
State=active
```

**Wayland session が active** でした。`scrot` は X11 用のスクリーンショットツールで、Wayland では使えません。Wayland では **`grim`** を使います。さらに SSH 経由で grim を動かすには 3 つの環境変数を揃える必要があります。

```bash
ssh wells '
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
  export WAYLAND_DISPLAY=wayland-0
  grim /tmp/screen.png
'
```

`$XDG_RUNTIME_DIR` は systemd-logind がユーザー session 開始時に作る `/run/user/<uid>` を指定。`WAYLAND_DISPLAY` は同ディレクトリ下の socket 名 (`wayland-0` がデフォルト)。さらに Chromium 側も Wayland に明示でつなぐには `--ozone-platform=wayland` が必要です。

これで初めて Pi 5 のデスクトップ画面が SSH 経由で「決定的に」観察できるようになりました。grim 経由で取った Chromium 起動直後の画面はこちらです。

<!-- TODO: 02-wayland-grim-restore-dialog.png を貼る (grim で取った復元ダイアログ表示画面) -->

## Step 3: 仮説 2 — クラッシュ復元ダイアログ (副次原因)

grim screenshot を見て初めて気付きました。**Chromium 本体の手前に「Chromium はほぼし(終了)しました/ページを復元しますか？」ダイアログが乗っていた**のです。Pi Connect の画面共有越しでは、このダイアログがレイアウト的に画面端だったり半透明だったりして気付きにくい位置にあったのでした。

原因は単純で、調査中に `pkill -9 chromium` (SIGKILL) を何度か叩いていたため、Chromium 視点では unclean shutdown が連発、Preferences の `exit_type` が `"Crashed"` 扱いになっていたからです。

対策は `~/.config/chromium/Default/Preferences` の該当キーを書き換え:

```bash
PREFS=~/.config/chromium/Default/Preferences
python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.setdefault("profile", {})
d["profile"]["exit_type"] = "Normal"
d["profile"]["exited_cleanly"] = True
open(p, "w").write(json.dumps(d))
' "$PREFS"
```

それと並行して、以後は `pkill -TERM chromium` (SIGTERM) で clean shutdown を待つ運用に切り替えました。

```bash
pkill -TERM chromium 2>/dev/null
for i in 1 2 3 4 5 6 7 8; do pgrep -x chromium >/dev/null || break; sleep 1; done
pkill -9 chromium 2>/dev/null  # 8 秒待っても残っていれば最終手段
```

これで復元ダイアログは消えました。一件落着 — のつもりが、再度 grim で screenshot を取ると **次は別のダイアログが出ていた**のです。

## Step 4: 仮説 3 — Gnome Keyring 認証ダイアログ (真因 ✅)

新しく出ていたのは「**Authentication required — An application wants access to the keyring "Default Keyring", but it is locked**」というダイアログでした。

<!-- TODO: 03-keyring-unlock-dialog.png を貼る (grim で取った keyring ダイアログ画面) -->

これがフォーカスを独占しているので Chromium 本体の URL バーは反応しない、というのが「真っ白」の正体でした。前回までは「復元ダイアログを閉じれば真っ白も解消」と思っていたのですが、復元ダイアログを潰した直後にこの第二のダイアログが顔を出していて、結果として「真っ白で URL バー無反応」が継続していた、という構造です。

### Gnome Keyring とは何か

Linux デスクトップの「秘密情報の金庫」(D-Bus サービス `org.freedesktop.secrets`) で、macOS のキーチェーンや Windows の資格情報マネージャーに相当します。Chromium / NetworkManager / Git / SSH / メールクライアントなどが保存パスワード・WiFi credentials・トークン類の保管先として使います。

通常は **ログイン時に PAM module (`pam_gnome_keyring.so`) が同じパスワードで auto-unlock** するので、ダイアログは出ません。今回の wells では何らかの理由でこの auto-unlock が機能しておらず、Chromium 起動時に手動で unlock を求められた、というわけです。

原因の細かい確定は割愛します (PAM 経由しないログイン経路 / keyring パスワードとログインパスワードの mismatch / 初回設定で空パスワードを選ばなかった、のいずれか)。今回は**そもそも keyring を使わない**方向で解決しました。

### 解決方法 (即効、sudo 不要)

Chromium には `--password-store=basic` という起動フラグがあり、これを付けると Chromium は keyring を完全に無視して平文の JSON ファイルにパスワードを保存します。個人用 Pi で Chromium に保存させるパスワードが特に無いなら、これで十分です。

```bash
# 1. 既存 keyring を backup して空にする
TS=$(date +%s)
mkdir -p ~/.local/share/keyrings.bak.$TS
mv ~/.local/share/keyrings/* ~/.local/share/keyrings.bak.$TS/
pkill -9 gnome-keyring-daemon 2>/dev/null

# 2. Chromium を停止して再起動
pkill -TERM chromium; sleep 3; pkill -9 chromium

# 3. --password-store=basic で起動
chromium --password-store=basic about:blank
```

これで keyring ダイアログは出なくなり、Chromium が正常に操作可能になりました。

<!-- TODO: 04-fixed-chromium.png を貼る (grim で取った復旧後の Chromium 画面、ダイアログなし) -->

## Step 5: 永続化 (sudo 不要、2 経路)

`--password-store=basic` を毎回手で付けるのは現実的ではないので、永続化します。`/etc/chromium.d/` 配下に書ければ sudo が必要ですが、**sudo 無しで 2 経路の起動経路をカバーする方法** があります。

### (a) ユーザー scope の `.desktop` ファイル上書き (XDG 仕様活用)

XDG Desktop Entry Specification では、`~/.local/share/applications/<name>.desktop` が `/usr/share/applications/<name>.desktop` より優先されます。これを利用して `Exec=` 行だけ書き換えます。

```bash
awk '/^Exec=/{sub(/chromium /, "chromium --password-store=basic ")} {print}' \
    /usr/share/applications/chromium.desktop \
    > ~/.local/share/applications/chromium.desktop
update-desktop-database ~/.local/share/applications/
```

これで以下のようになります。`%U` (URL argv 展開) はそのまま保持されます。

```
Exec=/usr/bin/chromium --password-store=basic %U
```

`sed` で同じことをしようとして `\2` の後方参照や `[[:space:]]` のクラス参照を組み合わせると、GNU sed のバージョン差で `unknown option to s` エラーが出ます。awk の `sub()` の方が壊れにくいです。

### (b) `~/.local/bin/chromium` wrapper (PATH 先頭優先)

デスクトップアイコン経由ではなく、ターミナルから `chromium ...` と叩く場合は `.desktop` を見ないので、wrapper 経路も用意します。

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/chromium <<'WRAP'
#!/bin/sh
exec /usr/bin/chromium --password-store=basic "$@"
WRAP
chmod +x ~/.local/bin/chromium
```

Raspberry Pi OS の `~/.profile` には標準で `PATH=$HOME/.local/bin:$PATH` が含まれているので、interactive shell から叩く `chromium` はこの wrapper を経由します (`which -a chromium` で `/home/<user>/.local/bin/chromium` が先頭になっていることを確認できます)。

### 動作確認

```bash
pgrep -af "chromium.*about:blank" | head -1
# → /usr/lib/chromium/chromium --js-flags=--no-decommit-pooled-pages ...
#     ... --password-store=basic --ozone-platform=wayland about:blank
```

cmdline に `--password-store=basic` が乗っていれば永続化成功です。

<!-- TODO: 05-permanent-fix.png を貼る (grim で取った再起動後の Chromium 画面、ダイアログなしで永続化済) -->

## ハマりまとめ

1. **エラーログの目立つ方を犯人扱いしない** — `unrecognized flag --no-decommit-pooled-pages` は完全に red herring でした。warning だからといって調査開始の起点として正しいとは限らない
2. **Wayland セッションで scrot は無意味** — `failed to create display` で固まるか、真っ黒画像が返るだけ。`grim` + `XDG_RUNTIME_DIR` + `WAYLAND_DISPLAY` の 3 点セットを覚えておく
3. **Pi Connect の画面共有はモーダルダイアログを見落としやすい** — レイアウトが歪んで端に追いやられたり、画面共有のキャッシュで前のフレームが残ったりして気付きにくい。`grim` で「決定的に」見るほうが速い
4. **`pkill -9` の連打が次のダイアログを呼ぶ** — Chromium にとっては unclean shutdown 扱いになるので、次回起動時に復元ダイアログが出る。原則 SIGTERM で待ってから SIGKILL
5. **`sed` で desktop file を書き換えるのは壊れやすい** — 後方参照と `[[:space:]]` の組み合わせはバージョン差でコケる。`awk '/^Exec=/{sub(...)}'` のほうが堅実
6. **Gnome Keyring auto-unlock が壊れる原因は複数** — PAM module 未読込 / パスワード mismatch / 初回設定で空パスワード未選択。今回はそもそも keyring を使わない方向で迂回した

## 次回予告

[#7](https://github.com/miyashita337/openclaw-rpi5-ops/issues/11) で OpenClaw daemon の Discord → Windows タワー forward を開通させる予定です。本記事はその開通作業を Pi 5 上のブラウザでやろうとして詰まった「寄り道」の記録という位置付けでした。

## 参考

- [Debian Bug #1089647 — chromium: spurious --js-flags=--no-decommit-pooled-pages on aarch64](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1089647)
- [Chromium password-store flag (chromium.org)](https://chromium.googlesource.com/chromium/src/+/main/docs/linux/password_storage.md)
- [grim — Grab images from a Wayland compositor](https://wayland.emersion.fr/grim/)
- [XDG Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html)
- 本記事の元 Issue: [openclaw-rpi5-ops#29](https://github.com/miyashita337/openclaw-rpi5-ops/issues/29)
