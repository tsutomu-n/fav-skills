#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
export XDG_STATE_HOME="${test_root}/state"
mkdir -p "${test_root}/bin" "${test_root}/existing/japanese-tech-writing" "${test_root}/existing/cognitive-rhythm-writing"

# Gistへのネットワークだけを置き換え、インストーラーとファイル操作は実行する。
cat > "${test_root}/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${FAIL_DOWNLOAD:-0}" == 0 ]] || exit 1
while (( $# )); do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --retry|--connect-timeout|--max-time) shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  https://gist.githubusercontent.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d/raw/209db7d6d19bc4727139844c0e8d786542e9ff68/SKILL.md)
    printf '%s\n' '---' 'name: japanese-tech-writing' 'description: fixture' '---' > "$output" ;;
  https://gist.githubusercontent.com/k16shikano/eb2929f13ed19c97188393d297be8432/raw/a3b1e26beced71d582e13314fb6f5b179b023c76/SKILL.md)
    printf '%s\n' '---' 'name: cognitive-rhythm-writing' 'description: fixture' '---' '../japanese-tech-writing/SKILL.md' > "$output" ;;
  *) exit 1 ;;
esac
CURL
chmod +x "${test_root}/bin/curl"
export PATH="${test_root}/bin:${PATH}"

printf '%s\n' existing-japanese > "${test_root}/existing/japanese-tech-writing/sentinel"
printf '%s\n' existing-cognitive > "${test_root}/existing/cognitive-rhythm-writing/sentinel"

# UIのみの導入はネットワークも既存ライティングスキルの置換も必要としない。
FAIL_DOWNLOAD=1 "${repo}/install.sh" --only ui-design --target "${test_root}/existing"
[[ "$(cat "${test_root}/existing/japanese-tech-writing/sentinel")" == existing-japanese ]]
[[ "$(cat "${test_root}/existing/cognitive-rhythm-writing/sentinel")" == existing-cognitive ]]
[[ -f "${test_root}/existing/ui-design/references/project-guide.md" ]]
[[ -f "${test_root}/existing/ui-design/references/sources.md" ]]
grep -Eq '^  allow_implicit_invocation: true[[:space:]]*$' "${test_root}/existing/ui-design/agents/openai.yaml"

# 同名スキルは --force なしで変更されず、--force では選択分のみ退避される。
printf '%s\n' original-ui > "${test_root}/existing/ui-design/sentinel"
if "${repo}/install.sh" --only ui-design --target "${test_root}/existing"; then
  printf '%s\n' '既存UIの無断置換を検出できませんでした。' >&2
  exit 1
fi
[[ "$(cat "${test_root}/existing/ui-design/sentinel")" == original-ui ]]
FAIL_DOWNLOAD=1 "${repo}/install.sh" --only ui-design --force --target "${test_root}/existing"
backup="$(find "${XDG_STATE_HOME}/fav-skills/backups" -name sentinel -path '*/ui-design/sentinel' -print -quit)"
[[ -n "$backup" && "$(cat "$backup")" == original-ui ]]
[[ "$(cat "${test_root}/existing/japanese-tech-writing/sentinel")" == existing-japanese ]]

# cognitiveのみの導入では参照先が存在することが必要。
if "${repo}/install.sh" --only cognitive-rhythm-writing --target "${test_root}/dependency"; then
  printf '%s\n' '不足する前提スキルを検出できませんでした。' >&2
  exit 1
fi
"${repo}/install.sh" --only japanese-tech-writing --target "${test_root}/dependency"
"${repo}/install.sh" --only cognitive-rhythm-writing --target "${test_root}/dependency"
[[ ! -e "${test_root}/dependency/ui-design" ]]

# 全件導入では2つは明示起動、UIは自動選択可能。
"${repo}/install.sh" --target "${test_root}/fresh"
grep -Eq '^  allow_implicit_invocation: false[[:space:]]*$' "${test_root}/fresh/japanese-tech-writing/agents/openai.yaml"
grep -Eq '^  allow_implicit_invocation: false[[:space:]]*$' "${test_root}/fresh/cognitive-rhythm-writing/agents/openai.yaml"
grep -Eq '^  allow_implicit_invocation: true[[:space:]]*$' "${test_root}/fresh/ui-design/agents/openai.yaml"

# UIだけをアンインストールしてもライティングスキルは残る。
"${repo}/uninstall.sh" --only ui-design --target "${test_root}/fresh"
[[ ! -e "${test_root}/fresh/ui-design" ]]
[[ -f "${test_root}/fresh/japanese-tech-writing/SKILL.md" ]]
[[ -f "${test_root}/fresh/cognitive-rhythm-writing/SKILL.md" ]]

# 未知のスキル名やダウンロード失敗では既存スキルを変更しない。
if "${repo}/install.sh" --only unknown-skill --target "${test_root}/fresh"; then
  printf '%s\n' '未知のスキル名を検出できませんでした。' >&2
  exit 1
fi
if FAIL_DOWNLOAD=1 "${repo}/install.sh" --force --target "${test_root}/fresh"; then
  printf '%s\n' '取得失敗を検出できませんでした。' >&2
  exit 1
fi
[[ -f "${test_root}/fresh/japanese-tech-writing/SKILL.md" ]]
[[ -f "${test_root}/fresh/cognitive-rhythm-writing/SKILL.md" ]]
printf '%s\n' 'インストーラーのテストに成功しました。'
