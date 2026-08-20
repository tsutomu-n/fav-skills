# フレームワーク別の公式パッケージ

対象リポジトリの既存依存関係を優先する。未導入で、依頼が実装または移行を含む場合だけ追加する。

| 対象 | パッケージ | 基本import |
|---|---|---|
| Svelte 5 / SvelteKit | `@tabler/icons-svelte-runes` | `import { IconSearch } from '@tabler/icons-svelte-runes';` |
| Svelte 4以下 | `@tabler/icons-svelte` | `import { IconSearch } from '@tabler/icons-svelte';` |
| Astro 4以上 | `@tabler/icons-astro` | `import { IconSearch } from '@tabler/icons-astro';` |
| React / Next.js | `@tabler/icons-react` | `import { IconSearch } from '@tabler/icons-react';` |
| Vue / Nuxt | `@tabler/icons-vue` | `import { IconSearch } from '@tabler/icons-vue';` |
| Preact | `@tabler/icons-preact` | `import { IconSearch } from '@tabler/icons-preact';` |
| Solid | `@tabler/icons-solidjs` | `import { IconSearch } from '@tabler/icons-solidjs';` |
| HTML / SVG直接利用 | `@tabler/icons` | `@tabler/icons/outline/search.svg`など |

Filledコンポーネントはcanonical nameへ`Filled`を付ける。

```ts
import { IconHeart, IconHeartFilled } from '@tabler/icons-svelte-runes';
```

## パッケージ追加

lockfileから既存のパッケージマネージャーを判定する。

| lockfile | コマンド |
|---|---|
| `bun.lock` / `bun.lockb` | `bun add <package>` |
| `pnpm-lock.yaml` | `pnpm add <package>` |
| `yarn.lock` | `yarn add <package>` |
| `package-lock.json` | `npm install <package>` |

複数lockfileがある場合は勝手に選ばない。`packageManager`フィールド、CI、README、既存コマンドから実際の運用を確認する。

## 実装規則

### Svelte 5

```svelte
<script lang="ts">
  import { IconSearch } from '@tabler/icons-svelte-runes';
</script>

<button aria-label="検索">
  <IconSearch aria-hidden="true" class="size-5" />
</button>
```

### Astro

```astro
---
import { IconArrowRight } from '@tabler/icons-astro';
---

<a href="/details">
  詳細
  <IconArrowRight aria-hidden="true" size={20} />
</a>
```

### React

```tsx
import { IconSettings } from '@tabler/icons-react';

export function SettingsButton() {
  return (
    <button type="button" aria-label="設定">
      <IconSettings aria-hidden="true" size={20} />
    </button>
  );
}
```

### Vue

```vue
<script setup lang="ts">
import { IconSearch } from '@tabler/icons-vue';
</script>

<template>
  <button type="button" aria-label="検索">
    <IconSearch aria-hidden="true" :size="20" />
  </button>
</template>
```

## 色・サイズ・stroke

- TablerのOutlineは24×24、既定stroke 2、`currentColor`を前提とする。
- `color`を各アイコンへ直書きするより、親要素または既存tokenから色を継承する。
- Tailwindでは既存規約がなければ`size-4`、`size-5`、`size-6`のいずれかを使用場面に合わせる。
- strokeを1.5や1.75へ変える場合は、既存画面の統一規約または明確な視認性理由を確認する。
