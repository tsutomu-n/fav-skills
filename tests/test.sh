#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fav-skills-test.XXXXXXXX")"

cleanup() {
  rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[test] FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "ファイルがありません: $1"
}

assert_not_exists() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "削除されていません: $1"
}

printf '[test] shell syntax\n'
bash -n "${ROOT_DIR}/install.sh"
bash -n "${ROOT_DIR}/uninstall.sh"

printf '[test] node syntax\n'
node --check "${ROOT_DIR}/skills/tabler-icons/scripts/search-icons.mjs"

printf '[test] static skill structure\n'
grep -Fq 'name: tabler-icons' "${ROOT_DIR}/skills/tabler-icons/SKILL.md"
grep -Fq 'allow_implicit_invocation: false' \
  "${ROOT_DIR}/skills/tabler-icons/agents/openai.yaml"
assert_file "${ROOT_DIR}/skills/tabler-icons/references/frameworks.md"
assert_file "${ROOT_DIR}/skills/tabler-icons/references/selection-and-accessibility.md"

fake_bin="${TMP_DIR}/bin"
target="${TMP_DIR}/target"
mkdir -p -- "$fake_bin" "$target"

cat > "${fake_bin}/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -Eeuo pipefail

output=""
url=""

while (( $# > 0 )); do
  case "$1" in
    --output)
      output="$2"
      shift 2
      ;;
    --fail|--location|--silent|--show-error)
      shift
      ;;
    --retry|--connect-timeout|--max-time)
      shift 2
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

[[ -n "$output" && -n "$url" ]] || exit 2

case "$url" in
  *fd287c3133457c4fd8f5601d34aa817d*)
    name='japanese-tech-writing'
    body='日本語技術文書を扱うテストSkill。'
    ;;
  *eb2929f13ed19c97188393d297be8432*)
    name='cognitive-rhythm-writing'
    body='基礎参照: ../japanese-tech-writing/SKILL.md'
    ;;
  *)
    exit 3
    ;;
esac

cat > "$output" <<EOF_SKILL
---
name: ${name}
description: Offline fixture for installer tests.
---

${body}
EOF_SKILL
FAKE_CURL
chmod 0755 "${fake_bin}/curl"

printf '[test] install\n'
PATH="${fake_bin}:${PATH}" "${ROOT_DIR}/install.sh" --target "$target" >/dev/null

for name in japanese-tech-writing cognitive-rhythm-writing tabler-icons; do
  assert_file "${target}/${name}/SKILL.md"
done
assert_file "${target}/tabler-icons/scripts/search-icons.mjs"
[[ -x "${target}/tabler-icons/scripts/search-icons.mjs" ]] \
  || fail 'search-icons.mjsに実行権限がありません。'

project="${TMP_DIR}/project"
mkdir -p \
  "${project}/node_modules/@tabler/icons" \
  "${project}/node_modules/@tabler/icons-svelte-runes/dist"

cat > "${project}/package.json" <<'JSON'
{
  "name": "fixture",
  "private": true,
  "dependencies": {
    "@tabler/icons-svelte-runes": "3.46.0"
  }
}
JSON

cat > "${project}/node_modules/@tabler/icons/package.json" <<'JSON'
{
  "name": "@tabler/icons",
  "version": "3.46.0"
}
JSON

cat > "${project}/node_modules/@tabler/icons-svelte-runes/package.json" <<'JSON'
{
  "name": "@tabler/icons-svelte-runes",
  "version": "3.46.0"
}
JSON

cat > "${project}/node_modules/@tabler/icons-svelte-runes/dist/icons-list.js" <<'JS'
export default [
  "a-b",
  "device-floppy",
  "heart",
  "heart-filled",
  "search",
  "search-filled"
];
JS

cat > "${project}/node_modules/@tabler/icons/icons.json" <<'JSON'
{
  "a-b": {
    "name": "a-b",
    "category": "Letters",
    "tags": ["letters", "compare"],
    "styles": {
      "outline": {"version": "1.0"}
    }
  },
  "device-floppy": {
    "name": "device-floppy",
    "category": "Devices",
    "tags": ["save", "disk", "storage"],
    "styles": {
      "outline": {"version": "1.0"}
    }
  },
  "heart": {
    "name": "heart",
    "category": "Shapes",
    "tags": ["favorite", "like", "love"],
    "styles": {
      "outline": {"version": "1.0"},
      "filled": {"version": "1.0"}
    }
  },
  "search": {
    "name": "search",
    "category": "System",
    "tags": ["find", "magnify"],
    "styles": {
      "outline": {"version": "1.0"},
      "filled": {"version": "1.0"}
    }
  },
  "future-only": {
    "name": "future-only",
    "category": "System",
    "tags": ["future"],
    "styles": {
      "outline": {"version": "9.9"}
    }
  }
}
JSON

search_script="${target}/tabler-icons/scripts/search-icons.mjs"

printf '[test] catalog search\n'
search_json="$(
  node "$search_script" search save disk --project "$project" --json
)"
grep -Fq '"component": "IconDeviceFloppy"' <<< "$search_json" \
  || fail 'IconDeviceFloppyが検索結果にありません。'
grep -Fq '"packageName": "@tabler/icons-svelte-runes"' <<< "$search_json" \
  || fail 'Svelte 5パッケージを検出できません。'
grep -Fq '"adapterCatalog":' <<< "$search_json" \
  || fail 'adapter icons-listを検出できません。'
grep -Fq 'installed adapter icons-list' <<< "$search_json" \
  || fail 'adapter exportによる検証結果がありません。'

printf '[test] exact verification\n'
node "$search_script" verify IconDeviceFloppy --project "$project" --json >/dev/null
node "$search_script" verify IconHeartFilled --project "$project" --json >/dev/null
node "$search_script" verify IconAB --project "$project" --json >/dev/null

if node "$search_script" verify IconDeviceFloppyFilled --project "$project" --json >/dev/null 2>&1; then
  fail '存在しないFilled版の確認が成功しました。'
fi

if node "$search_script" verify IconDefinitelyMissing --project "$project" --json >/dev/null 2>&1; then
  fail '存在しないアイコンの確認が成功しました。'
fi

if node "$search_script" verify IconFutureOnly --project "$project" --json >/dev/null 2>&1; then
  fail 'adapterがexportしない新しいcore iconの確認が成功しました。'
fi

printf '[test] idempotent reinstall\n'
reinstall_output="$(
  PATH="${fake_bin}:${PATH}" HOME="${TMP_DIR}/home" \
    "${ROOT_DIR}/install.sh" --target "$target"
)"
grep -Fq '既に最新です: japanese-tech-writing' <<< "$reinstall_output" \
  || fail '再実行時にremote Skillを最新と判定できません。'
grep -Fq '既に最新です: tabler-icons' <<< "$reinstall_output" \
  || fail '再実行時に同梱Skillを最新と判定できません。'
[[ ! -e "${TMP_DIR}/home/.local/state/fav-skills/backups" ]] \
  || fail '変更がない再実行で不要なバックアップを作成しました。'

printf '[test] changed install requires force\n'
printf 'old\n' > "${target}/tabler-icons/OLD"
if PATH="${fake_bin}:${PATH}" HOME="${TMP_DIR}/home" \
  "${ROOT_DIR}/install.sh" --target "$target" >/dev/null 2>&1; then
  fail '既存内容が異なるのに--forceなしで置換しました。'
fi
assert_file "${target}/tabler-icons/OLD"
[[ ! -e "${TMP_DIR}/home/.local/state/fav-skills/backups" ]] \
  || fail '--forceなしの停止でバックアップを作成しました。'

printf '[test] force replacement and backup\n'
PATH="${fake_bin}:${PATH}" HOME="${TMP_DIR}/home" \
  "${ROOT_DIR}/install.sh" --target "$target" --force >/dev/null
[[ ! -e "${target}/tabler-icons/OLD" ]] || fail '--forceで既存Skillを置換できません。'
find "${TMP_DIR}/home/.local/state/fav-skills/backups" -name OLD -print -quit \
  | grep -q . || fail '既存Skillのバックアップがありません。'

printf '[test] uninstall preflight is atomic\n'
cp "${target}/cognitive-rhythm-writing/SKILL.md" "${TMP_DIR}/cognitive.SKILL.md"
printf 'invalid\n' > "${target}/cognitive-rhythm-writing/SKILL.md"
if "${ROOT_DIR}/uninstall.sh" --target "$target" >/dev/null 2>&1; then
  fail '不正なSkillがあるのにアンインストールが成功しました。'
fi
for name in japanese-tech-writing cognitive-rhythm-writing tabler-icons; do
  [[ -e "${target}/${name}" ]] || fail "事前検証失敗後に一部削除されました: $name"
done
mv "${TMP_DIR}/cognitive.SKILL.md" "${target}/cognitive-rhythm-writing/SKILL.md"

printf '[test] uninstall\n'
"${ROOT_DIR}/uninstall.sh" --target "$target" >/dev/null
for name in japanese-tech-writing cognitive-rhythm-writing tabler-icons; do
  assert_not_exists "${target}/${name}"
done

printf '[test] PASS\n'
