# 選定とアクセシビリティ

## 意味の決め方

アイコンは次の3要素を分けて考える。

1. **対象**: file、folder、user、building、mapなど
2. **行動**: add、remove、download、search、editなど
3. **状態**: selected、warning、disabled、lockedなど

同じボタンへ3要素を全部背負わせない。たとえば「保存済みで同期エラー」を1個の謎めいた図形に圧縮せず、主行動のアイコンと状態表示を分ける。

## 候補比較

候補ごとに次を確認する。

- ラベルなしでも一般利用者が誤解しにくいか
- 16〜20pxで主要な形が潰れないか
- 同じツールバー内の別アイコンと見分けられるか
- 日本の業務UIで意味が通るか
- 既存画面ですでに別の意味へ割り当てられていないか
- OutlineとFilledの状態差が実際に必要か

「格好よい」「新しい」「検索結果の先頭」は選定根拠にしない。人間は意味不明な小さい線画を前にしても、なぜか説明なしで理解できるふりをするためである。

## OutlineとFilled

原則:

- 通常状態: Outline
- 選択済み、登録済み、お気に入り済み: Filled
- 警告やエラー: Outline/filledの差ではなく、ラベル・色・説明を組み合わせる
- Filled版が存在しない: 別の実在候補を探すか、Outlineのまま状態表現を追加する

CSSの`fill: currentColor`でOutlineを強制的にFilled化しない。形状はFilled版として設計されていない。

## アクセシビリティ

### テキストに添える装飾アイコン

```html
<button type="button">
  <svg aria-hidden="true" focusable="false"><!-- icon --></svg>
  保存
</button>
```

SVGは支援技術から隠す。表示テキストが名前になる。

### アイコンだけのボタン

```html
<button type="button" aria-label="案件を検索">
  <svg aria-hidden="true" focusable="false"><!-- icon --></svg>
</button>
```

`aria-label="検索"`より、対象を含む`aria-label="案件を検索"`の方が同種ボタンを区別しやすい。

### 単独で情報を伝えるアイコン

```html
<svg role="img" aria-label="同期エラー"><!-- icon --></svg>
```

ただし、重要な状態では隣に可視テキストまたは詳細説明も置く。色覚、画面拡大、認知負荷という、人類がCSSだけでは解決できない現実がある。

### Tooltip

Tooltipは補足説明として使う。キーボード操作や支援技術で確実に読める実装であっても、ボタン自体のアクセシブルネームを省略しない。

## レビュー時の失敗例

- `IconTrash`なのに確認なしで即削除する
- `IconX`を「閉じる」「削除」「解除」の3用途で混在させる
- `IconInfoCircle`へクリック処理を付けたのにbutton要素を使わない
- 選択状態をFilledだけで示し、`aria-pressed`やテキスト状態がない
- disabled状態を薄い色だけで示す
- 同じ意味に`IconSettings`と`IconAdjustments`を画面ごとに混在させる
