# Redmine Gantt Holiday plugin

Redmine 6.x のガントチャートに「休日カレンダー」「ヘッダー固定」「ユーザー毎の設定記憶」「親子関係の一括編集（親子丼）」を追加するプラグイン。

- 国別／会社別の休日カレンダーを管理し、ガント上で土曜・日曜・祝日を色分け表示
- 縦スクロール時に日付ヘッダーをオーバーレイ方式で固定
- マウスドラッグでガント領域を横スクロール（Grab to Scroll）
- ガントの表示設定（ズーム／表示月数／関連線／イナズマ線／カラム）をユーザーごとに記憶
- ガント画面上で複数の子チケットを親チケットへ一括集約・離脱（親子丼機能）
- 5言語対応（日本語／英語／フランス語／韓国語／中国語）

---

## 主な機能

### 1. 休日カレンダー管理 & 割当
* **複数カレンダー対応** — 「標準」「会社A」「会社B」などを自由に追加・プロジェクト毎に割当。
* **CSVインポート** — 内閣府公開の祝日CSV等をそのまま投入可能（Shift_JIS/UTF-8 自動判定）。
* **公式／非公式の自動制御** — 公式祝日のチェックOFFは「稼働日扱い（論理削除）」。手動追加分は物理削除。

### 2. ガントチャート表示の最適化
* 土曜は青系、日曜・祝日は赤系の透過色で着色（稼働日設定された祝日は色抜けする）。
* 日付ヘッダーを最前面で固定し、縦スクロール時も日付を見失わない（追従オーバーレイ）。
* `mousedown` による掴みスクロール（Grab to Scroll）をガントエリアに実装（テキスト選択やリンククリックを邪魔しないお行儀の良い実装）。

### 3. 表示設定の永続化（記憶）
* ズーム倍率、表示月数、開始年月、関連線、進捗線（イナズマ線）、選択カラムの表示状態を `User#preference` に自動保存。プロジェクトを跨いでも前回の表示状態を100%復元。「クリア」ボタンで一括リセット可能。

### 4. 親子丼 (Oyakodon) 機能 — ガント上での親子関係一括編集
ガントチャート画面で、複数の子チケットを親チケットへ視覚的に一括集約・離脱させる超軽量な編集モード。

> 💡 **What is "Oyakodon" ? (For English Speakers / Overseas Developers)**
> *"Oyakodon"* literally means "Parent-and-Child Rice Bowl" (a traditional Japanese dish with chicken and egg). In this plugin, it is implemented as a playful development slang for **"Bulk Parent-Child Issue Assignment"** via the Gantt chart context menu.
> * **"Devour child issues" (子チケットを食べる)**: Starts the editing mode. The selected issue becomes the "Parent" (Bowl), and any issues you click on after that are treated as "Children" (Ingredients / *Gu*).
> * **"Itadakimasu" (いただきます / Let's eat)**: Commits the relationship. Updates `parent_issue_id` for all selected children at once (Up to 200 issues, safety guards included).
> * **"Gochisousama" (ごちそうさま / Thank you for the feast)**: Instantly detaches the child issue from its parent right from the context menu.

---

## 動作要件

* **Redmine**: 6.0+（6.1対応）
* **Ruby**: 3.2+
* **Rails**: 7.2
* **DB**: DB: PostgreSQL / MySQL / SQLite3

---

## インストール

```bash
# 1. クローン
cd /path/to/redmine/plugins
git clone https://github.com/seraph3000/redmine_gantt_holiday.git

# 2. マイグレーション
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# 3. アセットコンパイル & 再起動
bundle exec rake assets:clobber assets:precompile RAILS_ENV=production
systemctl restart httpd

```

---

## アンインストール

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate NAME=redmine_gantt_holiday VERSION=0 RAILS_ENV=production
rm -rf plugins/redmine_gantt_holiday
systemctl restart httpd

```

---

## 変更履歴

v2.0.16 (2026-06)
- ガント画面上での親子関係一括編集機能（親子丼：Oyakodon）および一括離脱機能（ごちそうさま）を新規実装。コンテキストメニューをガント画面に最適化。

v2.0.15 (2026-05)
- 公開リリース。休日色分け／ヘッダー固定／設定の記憶／CSVインポート／5言語対応

---

## ライセンス

MIT License

## 作者

**Seraph3000** — [GitHub](https://github.com/seraph3000)
