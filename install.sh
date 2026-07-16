#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly LOCK_FILE="${SCRIPT_DIR}/skills.lock"
readonly DEFAULT_TARGET="${HOME}/.agents/skills"

TARGET_DIR="${CODEX_SKILLS_DIR:-$DEFAULT_TARGET}"
FORCE=0
TMP_DIR=""
BACKUP_DIR=""
ROLLBACK=0

declare -a SKILL_NAMES=()
declare -a SKILL_OWNERS=()
declare -a SKILL_GISTS=()
declare -a SKILL_REVISIONS=()
declare -a SKILL_FILES=()
declare -a EXISTING_NAMES=()
declare -a INSTALLED_NAMES=()

usage() {
  cat <<'USAGE'
Ubuntu上のCodexユーザースキルをインストールします。

使い方:
  ./install.sh [--force] [--target DIR]

オプション:
  --force       既存の同名スキルをバックアップして置換する
  --target DIR  インストール先を変更する
                既定値: $HOME/.agents/skills
  -h, --help    このヘルプを表示する

環境変数:
  CODEX_SKILLS_DIR  --target未指定時のインストール先
USAGE
}

log() {
  printf '[fav-skills] %s\n' "$*"
}

die() {
  printf '[fav-skills] エラー: %s\n' "$*" >&2
  exit 1
}

on_exit() {
  local status="$1"
  trap - EXIT

  if (( status != 0 && ROLLBACK == 1 )); then
    log 'インストールに失敗したため、変更を戻します。' >&2

    local name
    for name in "${INSTALLED_NAMES[@]}"; do
      rm -rf -- "${TARGET_DIR}/${name}"
    done

    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
      for name in "${EXISTING_NAMES[@]}"; do
        if [[ -e "${BACKUP_DIR}/${name}" || -L "${BACKUP_DIR}/${name}" ]]; then
          rm -rf -- "${TARGET_DIR:?}/${name}"
          mv -- "${BACKUP_DIR}/${name}" "${TARGET_DIR}/${name}"
        fi
      done
    fi
  fi

  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf -- "$TMP_DIR"
  fi

  exit "$status"
}
trap 'on_exit $?' EXIT

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

if [[ "${EUID:-$(id -u)}" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  die 'sudoで実行しないでください。通常ユーザーで ./install.sh を実行してください。'
fi

[[ -r "$LOCK_FILE" ]] || die "skills.lockを読み込めません: $LOCK_FILE"

while IFS='|' read -r name owner gist revision filename extra; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ -z "${extra:-}" ]] || die "skills.lockの列数が不正です: $name"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "不正なスキル名です: $name"
  [[ "$owner" =~ ^[A-Za-z0-9-]+$ ]] || die "不正なGist所有者です: $owner"
  [[ "$gist" =~ ^[0-9a-f]{32}$ ]] || die "不正なGist IDです: $gist"
  [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || die "不正なリビジョンです: $revision"
  [[ "$filename" == 'SKILL.md' ]] || die "未対応のファイル名です: $filename"

  SKILL_NAMES+=("$name")
  SKILL_OWNERS+=("$owner")
  SKILL_GISTS+=("$gist")
  SKILL_REVISIONS+=("$revision")
  SKILL_FILES+=("$filename")
done < "$LOCK_FILE"

(( ${#SKILL_NAMES[@]} > 0 )) || die 'skills.lockにスキルがありません。'

mkdir -p -- "$TARGET_DIR"
TARGET_DIR="$(cd -- "$TARGET_DIR" && pwd -P)"

for name in "${SKILL_NAMES[@]}"; do
  if [[ -e "${TARGET_DIR}/${name}" || -L "${TARGET_DIR}/${name}" ]]; then
    EXISTING_NAMES+=("$name")
  fi
done

if (( ${#EXISTING_NAMES[@]} > 0 && FORCE == 0 )); then
  printf '[fav-skills] 次のスキルは既に存在します:\n' >&2
  printf '  - %s\n' "${EXISTING_NAMES[@]}" >&2
  die '置換する場合は ./install.sh --force を実行してください。'
fi

if command -v curl >/dev/null 2>&1; then
  download() {
    curl --fail --location --silent --show-error \
      --retry 3 --connect-timeout 10 --max-time 60 \
      --output "$2" "$1"
  }
elif command -v wget >/dev/null 2>&1; then
  download() {
    wget --quiet --tries=3 --timeout=60 --output-document="$2" "$1"
  }
else
  die 'curlまたはwgetが必要です。'
fi

validate_skill() {
  local expected_name="$1"
  local path="$2"
  local size header

  [[ -s "$path" ]] || die "ダウンロードしたファイルが空です: $expected_name"
  size="$(wc -c < "$path")"
  (( size <= 1048576 )) || die "SKILL.mdが1MiBを超えています: $expected_name"
  [[ "$(sed -n '1p' "$path")" == '---' ]] || die "YAML front matterがありません: $expected_name"

  header="$(awk 'NR == 1 { next } /^---[[:space:]]*$/ { exit } { print }' "$path")"
  grep -Eq "^name:[[:space:]]*${expected_name}[[:space:]]*$" <<< "$header" \
    || die "SKILL.mdのnameが一致しません: $expected_name"
  grep -Eq '^description:[[:space:]]*[^[:space:]].*$' <<< "$header" \
    || die "SKILL.mdにdescriptionがありません: $expected_name"
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fav-skills.XXXXXXXX")"
mkdir -p -- "${TMP_DIR}/stage"

for index in "${!SKILL_NAMES[@]}"; do
  name="${SKILL_NAMES[$index]}"
  owner="${SKILL_OWNERS[$index]}"
  gist="${SKILL_GISTS[$index]}"
  revision="${SKILL_REVISIONS[$index]}"
  filename="${SKILL_FILES[$index]}"
  skill_dir="${TMP_DIR}/stage/${name}"
  url="https://gist.githubusercontent.com/${owner}/${gist}/raw/${revision}/${filename}"

  log "取得中: ${name}@${revision:0:12}"
  mkdir -p -- "${skill_dir}/agents"
  download "$url" "${skill_dir}/SKILL.md"
  validate_skill "$name" "${skill_dir}/SKILL.md"

  cat > "${skill_dir}/agents/openai.yaml" <<'YAML'
policy:
  allow_implicit_invocation: false
YAML
  chmod 0644 "${skill_dir}/SKILL.md" "${skill_dir}/agents/openai.yaml"
done

if [[ -f "${TMP_DIR}/stage/cognitive-rhythm-writing/SKILL.md" ]]; then
  grep -Fq '../japanese-tech-writing/SKILL.md' \
    "${TMP_DIR}/stage/cognitive-rhythm-writing/SKILL.md" \
    || die 'cognitive-rhythm-writingの基礎スキル参照を確認できません。'
fi

ROLLBACK=1

if (( ${#EXISTING_NAMES[@]} > 0 )); then
  state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/fav-skills/backups"
  BACKUP_DIR="${state_root}/$(date -u +%Y%m%dT%H%M%SZ)-$$"
  mkdir -p -- "$BACKUP_DIR"

  for name in "${EXISTING_NAMES[@]}"; do
    mv -- "${TARGET_DIR}/${name}" "${BACKUP_DIR}/${name}"
  done
fi

for name in "${SKILL_NAMES[@]}"; do
  mv -- "${TMP_DIR}/stage/${name}" "${TARGET_DIR}/${name}"
  INSTALLED_NAMES+=("$name")
done

ROLLBACK=0

log "インストール先: $TARGET_DIR"
for name in "${SKILL_NAMES[@]}"; do
  log "インストール完了: $name"
done

if [[ -n "$BACKUP_DIR" ]]; then
  log "既存スキルのバックアップ: $BACKUP_DIR"
fi

cat <<'NEXT'

Codexを起動中なら再起動し、/skills で確認してください。
スキルは暗黙には発動しません。プロンプトで明示的に指定します。

  $japanese-tech-writing を使って、この文書を推敲してください。
  $cognitive-rhythm-writing を使って、この解説文のリズムを調整してください。
NEXT
