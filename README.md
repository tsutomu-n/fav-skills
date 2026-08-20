# fav-skills

個人のUbuntu環境へ、Codex用のSkillをまとめて導入するためのbootstrap Repoです。

現在は次の3スキルを対象にしています。

| Skill | 用途 | 配布方法 |
|---|---|---|
| `japanese-tech-writing` | 日本語の技術文書を推敲する | `skills.lock`で固定したGistから取得 |
| `cognitive-rhythm-writing` | 日本語文章の認知的リズムを調整する | `skills.lock`で固定したGistから取得 |
| `tabler-icons` | Tabler Iconsを実在確認して選定・実装・レビューする | このRepoの`skills/tabler-icons/`に同梱 |

## 必要なもの

- Ubuntu
- Bash
- Git
- `curl`または`wget`
- Codex CLI 0.148以上、または対応するCodex IDE extension
- `tabler-icons`の検索補助スクリプトを使う場合はNode.js 18以上

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
└── tabler-icons/
```

同名Skillが既にある場合、標準動作では停止します。置換する場合は次を実行します。

```bash
./install.sh --force
```

置換前の内容は次へ退避されます。

```text
~/.local/state/fav-skills/backups/
```

インストール先を変える場合は、`--target`または`CODEX_SKILLS_DIR`を使います。

```bash
./install.sh --target /path/to/skills
```

## Codexでの使用

Codexを起動中だった場合は再起動し、`/skills`で認識を確認します。

```text
$japanese-tech-writing を使って、この設計書を推敲してください。
```

```text
$cognitive-rhythm-writing を使って、この解説文のリズムを調整してください。
```

```text
$tabler-icons を使って、この保存ボタンに合うTabler Iconを実在確認して実装してください。
```

各Skillは`agents/openai.yaml`で暗黙呼び出しを無効化しています。プロンプトで明示的に指定してください。

### `tabler-icons`の要点

`tabler-icons`はアイコン名を記憶から推測しません。対象プロジェクトへ実際にインストールされている`@tabler/icons`の`icons.json`を検索し、利用中のフレームワーク用パッケージに合わせたimport名を返します。

補助スクリプトだけを直接使う例です。

```bash
node ~/.agents/skills/tabler-icons/scripts/search-icons.mjs \
  search save disk --project . --json
```

```bash
node ~/.agents/skills/tabler-icons/scripts/search-icons.mjs \
  verify IconDeviceFloppy --project .
```

## 更新

上流Skillの更新を反映するときは、`skills.lock`のリビジョンをレビューして更新します。同梱SkillはこのRepo内で通常のコードレビューを行います。利用端末では次を実行します。

```bash
git pull --ff-only
./install.sh --force
```

## アンインストール

```bash
./uninstall.sh
```

`install.sh --force`が作成したバックアップは自動復元しません。必要な場合はバックアップディレクトリから手動で戻してください。

## 検証

```bash
./tests/test.sh
```

テストはネットワークを使わず、インストール、検索、実在確認、アンインストールを一時ディレクトリで検証します。

## 上流

- [Tabler Icons](https://github.com/tabler/tabler-icons)
- [japanese-tech-writing](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)
- [cognitive-rhythm-writing](https://gist.github.com/k16shikano/eb2929f13ed19c97188393d297be8432)
- [OpenAI公式: Build skills](https://developers.openai.com/codex/skills/)

このRepoのMIT Licenseは、インストーラー、このRepo内の文書、同梱Skillに適用されます。取得される上流Skill本文の権利条件は、それぞれの配布元に従います。
