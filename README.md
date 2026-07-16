# fav-skills

個人のUbuntu環境へ、Codex用の日本語ライティングスキルをまとめて導入するためのbootstrap Repoです。

現在は次の2スキルを対象にしています。

- `japanese-tech-writing`
- `cognitive-rhythm-writing`

スキル本文はこのRepoへ転載せず、`skills.lock`で固定したGistリビジョンからインストール時に取得します。

## 必要なもの

- Ubuntu
- Bash
- Git
- `curl`または`wget`
- Codex CLIまたはCodex IDE extension

## インストール

```bash
git clone https://github.com/tsutomu-n/fav-skills.git
cd fav-skills
./install.sh
```

インストール先は、Codexのユーザースコープである次のディレクトリです。

```text
~/.agents/skills/
├── japanese-tech-writing/
└── cognitive-rhythm-writing/
```

同名スキルが既にある場合、標準動作では停止します。置換する場合は次を実行します。

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

インストーラーは各スキルへ次の設定を追加します。

```yaml
policy:
  allow_implicit_invocation: false
```

このため、スキルはプロンプトで明示した場合だけ発動します。

## 更新

上流スキルの更新を反映するときは、`skills.lock`のリビジョンをレビューして更新します。利用端末では次を実行します。

```bash
git pull --ff-only
./install.sh --force
```

## アンインストール

```bash
./uninstall.sh
```

`install.sh --force`が作成したバックアップは自動復元しません。必要な場合は、バックアップディレクトリから手動で戻してください。

## 上流

- [japanese-tech-writing](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)
- [cognitive-rhythm-writing](https://gist.github.com/k16shikano/eb2929f13ed19c97188393d297be8432)
- [OpenAI公式: Build skills](https://developers.openai.com/codex/skills/)

このRepoのMIT Licenseは、インストーラーとこのRepo内の文書に適用されます。取得される上流スキル本文の権利条件は、それぞれの配布元に従います。
