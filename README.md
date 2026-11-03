# fav-skills

個人のUbuntu環境へ、Codex用のスキルを導入するためのbootstrap Repoです。

- `japanese-tech-writing`：明示起動
- `cognitive-rhythm-writing`：明示起動
- `ui-design`：関連するWeb画面の作業で自動選択の対象

ライティングスキルの本文は`skills.lock`で固定したGistリビジョンから取得します。`ui-design`は既存の同名スキルを再利用し、必要な参照資料とともに`skills/ui-design/`に同梱しています。

同梱版は、2026-11-04時点のChatGPT用「UI設計・実装ガイド」からのスナップショットであり、双方向に自動同期されません。更新時は差分を確認して反映してください。プロジェクトごとの設計資料は同梱せず、そのプロジェクトの既存資料を正本として参照します。

## 必要なもの

- Ubuntu、Bash、Git
- `curl`または`wget`（ライティングスキルの取得時）
- Codex CLIまたはCodex IDE extension

## インストール

```bash
git clone https://github.com/tsutomu-n/fav-skills.git
cd fav-skills
./install.sh
```

インストール先はCodexのユーザースコープです。

```text
~/.agents/skills/
├── japanese-tech-writing/
├── cognitive-rhythm-writing/
└── ui-design/
```

既にライティングスキルを導入済みで、UIスキルだけを追加するとき：

```bash
./install.sh --only ui-design
```

`--only`を使う場合、他のスキルには触れません。`cognitive-rhythm-writing`を単独で導入する場合は、参照先の`japanese-tech-writing`を先に導入してください。

同名スキルが既にある場合、標準動作では停止します。対象を確認して置換する場合は、`--force`を追加します。UIだけを置換する例：

```bash
./install.sh --only ui-design --force
```

置換前の内容は`~/.local/state/fav-skills/backups/`に退避されます。全件の置換には`./install.sh --force`を使います。

インストール先を変える場合は、`--target`または`CODEX_SKILLS_DIR`を使います。

```bash
./install.sh --target /path/to/skills
```

## Codexでの使用

`/skills`で認識を確認します。ライティングスキルはプロンプトで明示して利用します。

```text
$japanese-tech-writing を使って、この設計書を推敲してください。
$cognitive-rhythm-writing を使って、この解説文のリズムを調整してください。
```

インストーラーはライティングスキルのみに次の設定を追加します。

```yaml
policy:
  allow_implicit_invocation: false
```

一方、`ui-design`は同梱の`agents/openai.yaml`で`allow_implicit_invocation: true`とし、画面の新設・改修・レビュー、スマートフォン対応、UIの設計方針などを選択対象にしています。画面に影響しない内部処理やビルドなどは対象外です。選択はCodexが依頼と文脈から判断するため、必ず発動するわけではありません。

`ui-design`はまず対象プロジェクトの既存実装・UI設計資料を確認し、必要な場合だけ同梱の参照資料を読みます。すべての作業で設計資料を自動読込みする設定ではありません。別の探索範囲にも同名の`ui-design`がある場合は、利用する版と重複の有無を確認してください。

## 更新

ライティングスキルの上流更新は、`skills.lock`のリビジョンをレビューして反映します。`ui-design`の更新は同梱版と元のスキルの差分をレビューして反映します。利用端末では、変更内容と置換対象を確認したうえで実行します。

```bash
git pull --ff-only
./install.sh --force
```

UIだけを置換する場合は`./install.sh --only ui-design --force`を使います。`--force`は選択対象の既存スキルをバックアップして置換します。

## アンインストール

```bash
./uninstall.sh
```

UIスキルのみを対象にする場合は`./uninstall.sh --only ui-design`を使います。削除前に対象を確認してください。

`install.sh --force`が作成したバックアップは自動復元しません。必要な場合はバックアップディレクトリから手動で戻してください。

## 検証

```bash
bash tests/test-install.sh
```

このテストは一時ディレクトリを使い、Gist取得のみを固定のテストデータに置き換えて、インストール・設定・既存スキルの保全を確認します。実際のCodexによる自動選択は別の確認が必要です。確認例と判定方法は[選択の確認](tests/skill-selection.md)を参照してください。

## 上流

- [japanese-tech-writing](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)
- [cognitive-rhythm-writing](https://gist.github.com/k16shikano/eb2929f13ed19c97188393d297be8432)
- [OpenAI公式: Build skills](https://developers.openai.com/codex/skills/)

このRepoのMIT Licenseは、インストーラーとこのRepo内の文書に適用されます。取得される上流ライティングスキル本文の権利条件は、それぞれの配布元に従います。
