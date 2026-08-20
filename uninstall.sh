#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REMOTE_LOCK_FILE="${SCRIPT_DIR}/skills.lock"
readonly BUNDLED_LOCK_FILE="${SCRIPT_DIR}/bundled-skills.lock"
readonly DEFAULT_TARGET="${HOME}/.agents/skills"

TARGET_DIR="${CODEX_SKILLS_DIR:-$DEFAULT_TARGET}"
FORCE=0

declare -a SKILL_NAMES=()
declare -a REMOVE_NAMES=()
declare -A SEEN_NAMES=()

die() {
  printf '[fav-skills] エラー: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
使い方:
  ./uninstall.sh [--force] [--target DIR]

オプション:
  --force       SKILL.mdのnameを確認できない場合も削除する
  --target DIR  削除対象のスキルディレクトリを変更する
  -h, --help    このヘルプを表示する
USAGE
}

add_skill_name() {
  local name="$1"

  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "不正なスキル名です: $name"
  [[ -z "${SEEN_NAMES[$name]+x}" ]] || die "スキル名が重複しています: $name"

  SEEN_NAMES["$name"]=1
  SKILL_NAMES+=("$name")
}

while (( $# > 0 )); do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --target)
      [[ $# -ge 2 ]] || die '--targetにはディレクトリを指定してください。'
      TARGET_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "不明な引数です: $1"
      ;;
  esac
done

[[ -r "$REMOTE_LOCK_FILE" ]] || die "skills.lockを読み込めません: $REMOTE_LOCK_FILE"
[[ -r "$BUNDLED_LOCK_FILE" ]] || die "bundled-skills.lockを読み込めません: $BUNDLED_LOCK_FILE"

while IFS='|' read -r name _owner _gist _revision _filename extra; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ -z "${extra:-}" ]] || die "skills.lockの列数が不正です: $name"
  add_skill_name "$name"
done < "$REMOTE_LOCK_FILE"

while IFS='|' read -r name relative_path extra; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ -z "${extra:-}" ]] || die "bundled-skills.lockの列数が不正です: $name"
  [[ "$relative_path" == "skills/${name}" ]] \
    || die "同梱スキルのパスが不正です: ${name}|${relative_path}"
  add_skill_name "$name"
done < "$BUNDLED_LOCK_FILE"

for name in "${SKILL_NAMES[@]}"; do
  path="${TARGET_DIR}/${name}"
  [[ -e "$path" || -L "$path" ]] || continue

  if (( FORCE == 0 )); then
    [[ -f "${path}/SKILL.md" ]] || die "SKILL.mdがないため削除を停止しました: $path"
    header="$(awk 'NR == 1 { next } /^---[[:space:]]*$/ { exit } { print }' "${path}/SKILL.md")"
    grep -Eq "^name:[[:space:]]*${name}[[:space:]]*$" <<< "$header" \
      || die "nameを確認できないため削除を停止しました: $path"
  fi

  REMOVE_NAMES+=("$name")
done

if (( ${#REMOVE_NAMES[@]} == 0 )); then
  printf '[fav-skills] 削除対象はありません。\n'
  exit 0
fi

for name in "${REMOVE_NAMES[@]}"; do
  path="${TARGET_DIR}/${name}"
  rm -rf -- "$path"
  printf '[fav-skills] 削除しました: %s\n' "$path"
done
