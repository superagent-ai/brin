#!/usr/bin/env bash
set -euo pipefail

BRIN_API="https://api.brin.sh"
BRIN_TIMEOUT=10

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

if [ -z "$command" ]; then
  exit 0
fi

detect_origin_and_packages() {
  local cmd="$1"
  local origin=""
  local packages=()

  if echo "$cmd" | grep -qE '(npm install|npm add|npm i |npx )'; then
    origin="npm"
    packages=($(echo "$cmd" | grep -oE '(npm install|npm add|npm i|npx)\s+.*' | \
      sed -E 's/^(npm install|npm add|npm i|npx)\s+//' | \
      tr ' ' '\n' | \
      grep -v '^-' | \
      grep -v '^$' | \
      sed 's/@[^/]*$//' | \
      head -20))
  elif echo "$cmd" | grep -qE '(yarn add|yarn install)'; then
    origin="npm"
    packages=($(echo "$cmd" | grep -oE 'yarn add\s+.*' | \
      sed 's/^yarn add\s*//' | \
      tr ' ' '\n' | \
      grep -v '^-' | \
      grep -v '^$' | \
      sed 's/@[^/]*$//' | \
      head -20))
  elif echo "$cmd" | grep -qE '(pnpm add|pnpm install|pnpm i )'; then
    origin="npm"
    packages=($(echo "$cmd" | grep -oE '(pnpm add|pnpm i)\s+.*' | \
      sed -E 's/^(pnpm add|pnpm i)\s+//' | \
      tr ' ' '\n' | \
      grep -v '^-' | \
      grep -v '^$' | \
      sed 's/@[^/]*$//' | \
      head -20))
  elif echo "$cmd" | grep -qE '(bun add|bun install|bun i )'; then
    origin="npm"
    packages=($(echo "$cmd" | grep -oE '(bun add|bun i)\s+.*' | \
      sed -E 's/^(bun add|bun i)\s+//' | \
      tr ' ' '\n' | \
      grep -v '^-' | \
      grep -v '^$' | \
      sed 's/@[^/]*$//' | \
      head -20))
  elif echo "$cmd" | grep -qE '(pip install|pip3 install|uv pip install|uv add)'; then
    origin="pypi"
    packages=($(echo "$cmd" | grep -oE '(pip3? install|uv pip install|uv add)\s+.*' | \
      sed -E 's/^(pip3? install|uv pip install|uv add)\s+//' | \
      tr ' ' '\n' | \
      grep -v '^-' | \
      grep -v '^$' | \
      grep -v '/' | \
      sed 's/[>=<~!].*//' | \
      head -20))
  elif echo "$cmd" | grep -qE '(cargo add|cargo install)'; then
    origin="crate"
    packages=($(echo "$cmd" | grep -oE '(cargo add|cargo install)\s+.*' | \
      sed -E 's/^(cargo add|cargo install)\s+//' | \
      tr ' ' '\n' | \
      grep -v '^-' | \
      grep -v '^$' | \
      sed 's/@.*//' | \
      head -20))
  fi

  echo "$origin"
  printf '%s\n' "${packages[@]}"
}

check_package() {
  local origin="$1"
  local package="$2"

  if [ -z "$package" ] || [ -z "$origin" ]; then
    return 0
  fi

  local url="${BRIN_API}/${origin}/${package}"
  local response
  response=$(curl -s -m "$BRIN_TIMEOUT" -D - -o /dev/null "$url" 2>/dev/null) || return 0

  local verdict
  verdict=$(echo "$response" | grep -i 'x-brin-verdict' | tr -d '\r' | awk '{print $2}')

  local score
  score=$(echo "$response" | grep -i 'x-brin-score' | tr -d '\r' | awk '{print $2}')

  if [ -z "$verdict" ]; then
    return 0
  fi

  case "$verdict" in
    malicious|suspicious)
      echo "BLOCKED"
      echo "$package"
      echo "$verdict"
      echo "$score"
      return 1
      ;;
    caution)
      echo "WARNING"
      echo "$package"
      echo "$verdict"
      echo "$score"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

result=$(detect_origin_and_packages "$command")

origin=$(echo "$result" | head -1)
packages=$(echo "$result" | tail -n +2)

if [ -z "$origin" ] || [ -z "$packages" ]; then
  exit 0
fi

blocked=()
warnings=()

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue

  check_output=$(check_package "$origin" "$pkg" 2>&1) || true

  status=$(echo "$check_output" | head -1)

  if [ "$status" = "BLOCKED" ]; then
    pkg_name=$(echo "$check_output" | sed -n '2p')
    pkg_verdict=$(echo "$check_output" | sed -n '3p')
    pkg_score=$(echo "$check_output" | sed -n '4p')
    blocked+=("${pkg_name} (verdict: ${pkg_verdict}, score: ${pkg_score})")
  elif [ "$status" = "WARNING" ]; then
    pkg_name=$(echo "$check_output" | sed -n '2p')
    pkg_verdict=$(echo "$check_output" | sed -n '3p')
    pkg_score=$(echo "$check_output" | sed -n '4p')
    warnings+=("${pkg_name} (verdict: ${pkg_verdict}, score: ${pkg_score})")
  fi
done <<< "$packages"

if [ ${#warnings[@]} -gt 0 ]; then
  warning_msg="brin: caution for: $(IFS=', '; echo "${warnings[*]}")"
  echo "{\"message\": \"$warning_msg\"}" >&2
fi

if [ ${#blocked[@]} -gt 0 ]; then
  block_msg="brin: blocked installation — threat detected in: $(IFS=', '; echo "${blocked[*]}"). See https://brin.sh for details."
  echo "{\"exitCode\": 2, \"message\": \"$block_msg\"}"
  exit 2
fi

exit 0
