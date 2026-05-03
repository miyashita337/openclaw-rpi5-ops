---
title: "Raspberry Pi 5 に Tailscale を入れて、外出先から自宅サーバーに 5分で SSH する"
emoji: "🔐"
type: "tech"
topics: ["raspberrypi", "tailscale", "vpn", "wireguard", "ssh"]
published: false  # 公開前に true に
---

## TL;DR

1. Raspberry Pi 5 に **Tailscale** を入れて、ポート開放ゼロ・5分で外出先 SSH を実現
2. 公式 `install.sh` が **Raspberry Pi OS 13 (Debian trixie)** を自動判定
3. `--ssh` フラグで **SSH 鍵配布も不要** に(Tailscale SSH)
4. MagicDNS で `ssh wells` のホスト名だけで届く
5. 常時稼働サーバーは **Key Expiry を Disable** にしておくのが定石

![Tailscale 管理画面に wells が SSH バッジ付きで並ぶ様子](/images/zenn-article-02-tailscale/01-tailscale-admin.png)

## はじめに

[前回の記事](https://zenn.dev/harieshokunin/articles/9caa728de35b1f) で Raspberry Pi 5 (`wells.local`) を初期セットアップした。
今回はその続編として、**外出先からも自宅の RPi5 に安全にアクセスできる状態** を作る。

定期実行・ブラウザ自動化・通知などの軽量タスクを RPi5 に任せたいので、LAN 内に居ないと触れないままだと不便すぎる。かといって、自宅ルーターのポートを世界に開けるのは怖い。
そこで、**ポート開放なしで NAT を貫通できる Mesh VPN** を導入する。

## なぜ Tailscale を選んだか

主要候補と比較した結果、Tailscale が最短かつ最安だった。

| サービス | 料金 (2026年5月時点) | NAT越え | セットアップ | 備考 |
|---|---|---|---|---|
| **Tailscale** | 個人無料(〜100台 / 3ユーザー) | ◎ DERP 中継 | 1コマンド | WireGuard ベース。`tailscale ssh` で鍵管理不要 |
| ZeroTier | 無料(〜25台/ネットワーク) | ◎ | 中 | レイヤ2 VPN |
| Cloudflare Tunnel | 完全無料 | ◎ | 中 | tunnel 方式、L4限定 |
| PiVPN (WireGuard 自前) | 無料 | △ ポート開放必須 | 高 | CGNAT環境では詰む |
| OpenVPN | 無料 | △ | 高 | レガシー |

Tailscale を選んだ決め手は3つ。

1. **ルーターのポート開放が不要** — CGNAT 配下でも DERP 中継で貫通する
2. **`tailscale ssh` で SSH 鍵配布から解放される** — Tailnet 認証がそのまま SSH 認証になる
3. **MagicDNS で `ssh wells` だけで届く** — `.local` も IP も覚えなくていい

:::message
Tailscale のコントロールプレーン(座標サーバー)は商用クラウドに依存します。完全自前でやりたい人は OSS 互換実装の [Headscale](https://github.com/juanfont/headscale) を選択肢に入れてください。本記事は手早く動かすことを優先して Tailscale を採用します。
:::

## セットアップ

### 1. Tailscale をインストール

公式インストーラを使う。**Raspberry Pi OS 13 (Debian trixie) を自動判定** してくれる。

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale version
```

:::details 実行ログ (抜粋)
```
Installing Tailscale for debian trixie, using method apt
+ curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg
...
Setting up tailscale (1.96.4) ...
Created symlink '/etc/systemd/system/multi-user.target.wants/tailscaled.service' → '/usr/lib/systemd/system/tailscaled.service'.
Installation complete!
```
:::

### 2. 起動 + Tailscale SSH を有効化

```bash
sudo tailscale up --ssh --hostname=wells
```

| オプション | 意味 |
|---|---|
| `--ssh` | Tailscale SSH を有効化(SSH鍵不要、Tailnet認証で接続) |
| `--hostname=wells` | MagicDNS 用ホスト名を明示 |

実行すると `https://login.tailscale.com/a/xxxxxx` が表示される。手元の PC ブラウザで開いてアカウントで承認すると、wells が Tailnet に参加する。

### 3. 接続確認

```bash
tailscale ip -4
# → 100.72.2xxxxx

tailscale status
# 100.72.2xxxxx    wells                me@  linux    -
# 100.67.2xxxxx    iphone174            me@  iOS      -
# 100.80.1xxxxx    sg1atrantis-2        me@  macOS    -
```

Tailscale 管理画面 (login.tailscale.com/admin/machines) にも `wells` が **`SSH` バッジ付き** で現れる。
さらに後述の Key Expiry を無効化すると `Expiry disabled` バッジも追加される。

### 4. 手元の Mac からアクセス

`.local` も IP も書かない。**MagicDNS でホスト名だけで届く**。

```bash
# 通常の SSH (MagicDNS 経由)
ssh harieshokunin@wells

# Tailscale SSH (鍵もパスワードも不要)
tailscale ssh harieshokunin@wells
```

![Mac メニューバーで Tailscale が Connected の状態](/images/zenn-article-02-tailscale/02-mac-menubar.png)

初回は次のような追加認証が走る。これは Tailscale のデフォルト ACL の **`check` モード** の挙動で、Tailnet オーナー自身でも 12時間ごとにブラウザ確認が要求される(後述)。

```
# Tailscale SSH requires an additional check.
# To authenticate, visit: https://login.tailscale.com/a/xxxxx
# Authentication checked with Tailscale SSH.
```

### 5. キー有効期限を無効化(常時稼働サーバーでは必須)

デフォルトでは Tailscale の認証キーは **180日で期限切れ** になる。
常時稼働の自宅サーバーが定期的に切れるのは事故の元なので、wells に限り無効化しておく。

login.tailscale.com/admin/machines で wells の `…` メニューから:

> `Disable key expiry`

これで明示的に取り消さない限り再認証不要になる。一覧に `Expiry disabled` バッジが付けば成功。

:::message alert
個人 PC やスマホなど「紛失リスクのある端末」では Key Expiry は **無効化しない** のが原則。常時稼働サーバーだけ例外的に外す、という運用にする。
:::

## ハマりどころ

### Raspberry Pi OS 13 は Bookworm ではなく Trixie

`/etc/os-release` を見るとわかるが、**Raspberry Pi OS 13 のベースは Debian trixie (13)**。Bookworm 前提で書かれた古い記事のコマンドをコピペすると `pkgs.tailscale.com/stable/raspbian/bookworm` を見に行って詰むケースがある。
公式 `install.sh` は trixie を自動判定して `pkgs.tailscale.com/stable/debian/trixie` を使ってくれるので、迷ったら `install.sh` 一択。

### locale 警告 `LC_CTYPE = "ja_JP.UTF-8"` が消えない

Mac の SSH クライアントは `SendEnv LC_*` で Mac 側のロケールを wells に送ってくる。wells 側で `ja_JP.UTF-8` が **生成されていない** と、apt 実行のたびに `perl: warning: Setting locale failed.` が連発する。

`locales-all` パッケージを入れただけでは足りず、**`/etc/locale.gen` の有効化と `locale-gen` の実行が別途必要**。

```bash
sudo sed -i 's/^# *\(ja_JP.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen
locale -a | grep -i ja_JP   # ja_JP.utf8 が出ればOK
```

新しい SSH セッションから警告は消える。

### `ssh wells` で `Tailscale SSH requires an additional check` が出る

これは設定した覚えがなくても出る。**新規 Tailnet を作ると Tailscale 側がデフォルト ACL を自動投入** していて、その中の `ssh` セクションが `check` モードになっているのが原因。

login.tailscale.com/admin/acls で確認できる。デフォルトはおおよそ次の形:

```jsonc
{
  "acls": [
    { "action": "accept", "src": ["*"], "dst": ["*:*"] }
  ],
  "ssh": [
    {
      "action": "check",                    // 追加ブラウザ認証
      "src":    ["autogroup:member"],       // Tailnet メンバーから
      "dst":    ["autogroup:self"],         // 自分所有のノードへ
      "users":  ["autogroup:nonroot", "root"]
      // checkPeriod を書かないとデフォルト 12h
    }
  ]
}
```

つまり、自分のマシンに自分で SSH するときも 12時間ごとにブラウザ確認が走る。
仕様であり、セキュリティ的にもむしろ推奨設定。煩わしければ ACL を `"action": "accept"` に変えれば即接続になるが、**サーバーが侵入された時に横移動を止められなくなる** ため、1人運用でも `check` のまま使うのがおすすめ。

参考リンク:

https://tailscale.com/kb/1018/acls

https://tailscale.com/kb/1193/tailscale-ssh

## まとめ

- 公式インストーラ → `tailscale up --ssh` → ブラウザ認証、の3ステップで RPi5 へのリモート SSH が完成した
- ポート開放ゼロ、SSH 鍵管理ゼロ、ホスト名 `wells` だけでどこからでも届く
- 常時稼働サーバーには Key Expiry の無効化を忘れずに
- Tailscale の `check` モードは煩わしく感じても、運用上残す価値あり

## 次回予告

- Tailscale Funnel で wells 上の Web サービスを HTTPS で外部公開する
- OpenClaw を入れて、定期実行・ブラウザ操作・通知を RPi5 に任せる

---

<!--
公開前チェックリスト
- [ ] published を true に
- [ ] images/zenn-article-02-tailscale/ に以下2枚を配置
       - 01-tailscale-admin.png … Tailscale 管理画面の machines 一覧 (wells SSH/Expiry disabled バッジ)
       - 02-mac-menubar.png    … Mac メニューバーの Tailscale Connected
       (zenn-cli を使わず Web editor で書く場合は、ドラッグ&ドロップで添付すれば URL は自動置換される)
- [ ] 自分の IP は下5桁を xxxxx でマスク済 (100.72.2xxxxx 等) — 公開時に再確認
- [ ] 前回記事との内部リンクが正しいか確認
- [ ] zenn preview で表組み・details が崩れていないか確認 (`npx zenn preview`)
-->
