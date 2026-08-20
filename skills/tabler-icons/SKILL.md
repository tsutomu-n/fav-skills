---
name: tabler-icons
description: Select, verify, implement, replace, or audit Tabler Icons in frontend UI code. Use for exact icon/component names, official framework packages and imports, outline/filled states, accessibility, or migration to Tabler in Svelte/SvelteKit, Astro, React/Next.js, Vue/Nuxt, Preact, Solid, and HTML. Trigger on Tabler Icons, アイコン選定, アイコン実装, or アイコン置換. Do not use for custom logos, illustrations, or unrelated icon libraries except explicit migration.
---

# Tabler Icons

対象リポジトリに実在するTabler Iconだけを選び、既存のUI規約へ合わせて実装・置換・レビューする。

## 成功条件

- フレームワーク、Tablerパッケージ、パッケージマネージャー、既存アイコン規約を実物から確認する。
- 候補名を記憶で決めず、対象プロジェクトにインストールされた`@tabler/icons`のメタデータで確認する。
- アイコンの意味、状態、視認性、アクセシブルネームを使用場面に合わせる。
- 既存コードと同じimport方式を使い、不要な全量import、独自ラッパー、別アイコンライブラリを増やさない。
- 変更後に対象プロジェクトの最小限の型検査、lint、testまたはbuildを実行する。

## 手順

### 1. 対象を確認する

最初に次を必要な範囲だけ読む。

- `package.json`とlockfile
- Svelte、Astro、React、Vueなどの版
- 既存のTabler importと共通Iconコンポーネント
- TailwindまたはCSSのサイズ、色、stroke規約
- 変更対象のラベル、ツールチップ、選択状態、エラー状態

Tablerが未導入なら、依頼が実装・移行を含む場合だけ公式の対応パッケージを追加する。単なる相談やレビューでは依存関係を変更しない。対応表とimport例は`references/frameworks.md`を読む。

### 2. 意図を検索語へ変換する

UIの目的を、英語の名詞・動詞2〜5語へ変換する。

例:

- 保存: `save disk storage`
- 入札案件: `gavel file search`
- 工事場所: `map pin construction`
- 折りたたむ: `chevron collapse panel`

見た目ではなく、利用者が起こす行動または対象物を先に表す。

### 3. 実在候補を検索する

この`SKILL.md`があるディレクトリを`<skill-dir>`として、補助スクリプトを実行する。

```bash
node <skill-dir>/scripts/search-icons.mjs \
  search save disk storage \
  --project . \
  --limit 8 \
  --json
```

Filledが必要な場合だけ指定する。

```bash
node <skill-dir>/scripts/search-icons.mjs \
  search favorite selected \
  --project . \
  --style filled \
  --json
```

スクリプトがメタデータを見つけられない場合、アイコン名を推測して続行しない。依存関係が未インストール、作業ディレクトリが誤り、または特殊なパッケージ配置であることを切り分ける。

### 4. 候補を決める

候補が複数ある場合は、次の順で1つへ絞る。

1. 既存画面と同じ意味・同じアイコン
2. 行動または対象を最も直接表すもの
3. 16〜24pxで識別しやすいもの
4. 文化や業務知識を過度に要求しないもの
5. 隣接アイコンと輪郭が衝突しないもの

Filledは「選択済み」「お気に入り済み」など明確な状態差に限定する。装飾目的でOutlineとFilledを混在させない。詳しい判断規則は`references/selection-and-accessibility.md`を読む。

### 5. 名前を再確認して実装する

採用名を実装直前に確認する。

```bash
node <skill-dir>/scripts/search-icons.mjs \
  verify IconDeviceFloppy \
  --project . \
  --json
```

Svelte 5のFilled例:

```bash
node <skill-dir>/scripts/search-icons.mjs \
  verify IconHeartFilled \
  --project . \
  --json
```

出力された`import`を基準に、既存ファイルの方式へ合わせる。

- named importを使う。
- `import * as Icons`や全量オブジェクト化を、動的選択が実要件でない限り追加しない。
- 色は原則`currentColor`を継承させる。
- サイズとstrokeは既存規約を優先し、理由なく全画面を統一し直さない。
- 独自SVGへコピーしてTabler由来の更新可能性を捨てない。

### 6. アクセシビリティを付ける

- 表示テキストに添える装飾アイコンは`aria-hidden="true"`にする。
- アイコンだけのボタンには、ボタン側へ具体的な`aria-label`または視覚的に隠したテキストを付ける。
- 重要な状態を色やアイコンだけで伝えない。
- Tooltipだけをアクセシブルネームの代用にしない。
- クリック不能な装飾SVGへ不要な`role="button"`やtab focusを与えない。

実装例は`references/selection-and-accessibility.md`を読む。

### 7. 検証する

変更範囲に応じて次を実行する。

1. import名の再確認
2. TypeScriptまたはフレームワークの型検査
3. lint
4. 対象test、なければbuild
5. 可能なら対象画面を16px、20px、24pxおよび選択・disabled・dark modeで確認

結果では、採用したcanonical name、style、package、実行した検証、未確認事項を簡潔に報告する。

## 禁止事項

- TablerのWebサイトを見た記憶だけで名前を生成しない。
- 存在しないFilled版をOutline版からCSSで塗り潰さない。
- アイコン追加だけのために別ライブラリを併用しない。
- ラベルで意味が明確な場所へ、意味の薄いアイコンを機械的に増やさない。
- アクセシビリティを`title`属性だけで済ませない。
