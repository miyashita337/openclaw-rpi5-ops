# 記事: RPi5 + trixie でのリモートデスクトップ実機検証(WayVNC vs Pi Connect vs xrdp+X11)

## 背景・動機

Zenn 連載 03 (OpenClaw SSH本番インストール) を執筆完了後、続編としてリモートデスクトップ検証記事を書く。本丸の意思決定でハイブリッド方針(本番=SSH、検証=RD)を採用済み。

trixie + Pi5 + Tailscale 環境では、長年の主流である RealVNC / xrdp が Wayland(labwc 既定)非対応で物理的に機能しないという「公式は SSH しか書かない理由」が存在している。これを実機検証して文書化することは日本語圏で空白地帯であり、Zenn 読者層(シニアエンジニア)に強く刺さる素材。

## 検証対象(優先順)

1. **WayVNC** + Tailscale (推奨候補・on-demand起動)
   - `apt install wayvnc` → `systemctl --user start wayvnc` の挙動確認
   - port 5900 競合・boot race(forum 395430, 393161, 395318)の再現確認
   - Tailscale 越しでのIPv6 ICE STUN packet loss(34%報告)の実測
2. **Raspberry Pi Connect** (公式)
   - [trixie-feedback Issue #70](https://github.com/raspberrypi/trixie-feedback/issues/70) 「黒画面」の修正状況確認(2026-05時点で再現するか)
   - WayVNC直結回避策の検証
3. **xrdp + Xorg fallback**
   - labwc を切って Xorg に戻したときのRDP挙動
   - PulseAudio→PipeWire 移行で音声ch がどうなるか
4. **RealVNC Connect**(参考程度)
   - raspi-config で X11 に戻したときの動作・retreat path の罠

## 評価軸

| 軸 | 内容 |
|---|---|
| 動作 | trixie + Pi5 で素直に動くか、エラー再現 |
| Wayland 互換 | labwc 既定維持で動くか、X11 切替が必要か |
| Tailscale 親和性 | Tailnet IP直結、IPv6 vs IPv4、MagicDNS との競合 |
| 速度・遅延 | HHKB Studio JIS で日本語入力の打ち心地 |
| 攻撃面増加 | 常時 listen するか on-demand 化できるか |
| 設定の煩雑度 | 初心者再現性・記事化のしやすさ |

## 期待される記事構成案

タイトル候補(編集者推奨):
- 「公式が SSH しか書かない OpenClaw を、Tailscale + WayVNC で GUI セットアップしてみた(RPi5 / trixie / 2026年版)」
- 「Raspberry Pi 5 + trixie でリモートデスクトップを動かす — RealVNC が動かない時代の正解」
- 「『SSH ヘッドレスで入れろ』は本当に正解か — OpenClaw on RPi5 を WayVNC / Pi Connect / xrdp で実測比較」

構成:
- TL;DR(数字付き5項目)
- 結論先出し: WayVNC + Tailscale + on-demand起動
- 各候補の実機検証(スクショ豊富)
- ハマりどころ(Issue #70, IPv6 STUN packet loss, port 5900 競合)
- セキュリティ配慮(常時listenしない・Tailnet内に閉じる)
- 比較表

## 前提条件・依存タスク

- [ ] 連載 03 (OpenClaw SSH本番インストール) 完成・投稿済み
- [ ] RPi5 が NVMe ルートで稼働している(SD root のままでは検証中に I/O ボトルネックを踏む)
- [ ] OpenClaw が Lite + SSH 構成で 1ヶ月以上 stable に動いている(本番が壊れない安心感がある状態で検証)
- [ ] WayVNC / Pi Connect / xrdp の package が trixie で apt 配布されていることを確認

## 注意事項

- セキュリティで叩かれないため、冒頭で「Tailnet 内に閉じる・常時 listen しない・on-demand起動」を明示
- OpenClaw CVE 138件・41% High/Critical の数字は **NVD/CVE.org で再検証してから記載**(プロジェクト概要 v3 由来の数値、未独立検証)
- Issue #70 は 2026-05 時点で active のため、検証時に最新状況を再確認

## 関連リソース

- Zenn 連載 02: RPi5 + Tailscale (`zenn-article-02-tailscale.md`)
- プロジェクト概要: `openclaw_rpi5_project_overview.md`
- 設計仕様: `docs/superpowers/specs/2026-04-12-openclaw-rpi5-ops-design.md`

## ラベル候補

- `article`
- `verification`
- `rpi5`
- `low-priority` (連載03完成後に着手)
