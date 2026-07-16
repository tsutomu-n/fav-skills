#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly LOCK_FILE="${SCRIPT_DIR}/skills.lock"
readonly DEFAULT_TARGET="${HOME}/.agents/skills"

TARGET_DIR="${CODEX_SKILLS_DIR:-$DEFAULT_TARGET}"
FORCE=0

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

[[ -r "$LOCK_FILE" ]] || die "skills.lockを読み込めません: $LOCK_FILE"

removed=0
while IFS='|' read -r name _owner _gist _revision _filename _extra; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  path="${TARGET_DIR}/${name}"
  [[ -e "$path" || -L "$path" ]] || continue

  if (( FORCE == 0 )); then
    [[ -f "${path}/SKILL.md" ]] || die "SKILL.mdがないため削除を停止しました: $path"
    header="$(awk 'NR == 1 { next } /^---[[:space:]]*$/ { exit } { print }' "${path}/SKILL.md")"
    grep -Eq "^name:[[:space:]]*${name}[[:space:]]*$" <<< "$header" \
      || die "nameを確認できないため削除を停止しました: $path"
  fi

  rm -rf -- "$path"
  printf '[fav-skills] 削除しました: %s\n' "$path"
  removed=1
done < "$LOCK_FILE"

if (( removed == 0 )); then
  printf '[fav-skills] 削除対象はありません。\n'
fi
