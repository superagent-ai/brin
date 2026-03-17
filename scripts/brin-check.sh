#!/usr/bin/env bash
set -uo pipefail

BRIN_API="https://api.brin.sh"
BRIN_TIMEOUT=10

input=$(cat)
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')
command=$(echo "$input" | jq -r '.command // empty')
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

check_brin() {
  local origin="$1"
  local name="$2"

  if [ -z "$name" ] || [ -z "$origin" ]; then
    return 0
  fi

  local response
  response=$(curl -s -m "$BRIN_TIMEOUT" -D - -o /dev/null "${BRIN_API}/${origin}/${name}" 2>/dev/null) || return 0

  local verdict score
  verdict=$(echo "$response" | grep -i 'x-brin-verdict' | tr -d '\r' | awk '{print $2}') || true
  score=$(echo "$response" | grep -i 'x-brin-score' | tr -d '\r' | awk '{print $2}') || true

  [ -z "$verdict" ] && return 0

  echo "${name}|${verdict}|${score}"
}

extract_packages() {
  local cmd="$1"
  local origin=""
  local packages=""

  if echo "$cmd" | grep -qE '(npm install|npm add|npm i |npx )'; then
    origin="npm"
    packages=$(echo "$cmd" | grep -oE '(npm install|npm add|npm i|npx)\s+.*' | \
      sed -E 's/^(npm install|npm add|npm i|npx)\s+//' | \
      tr ' ' '\n' | { grep -v '^-' || true; } | { grep -v '^$' || true; } | \
      sed 's/@[^/]*$//' | head -20)
  elif echo "$cmd" | grep -qE '(yarn add)'; then
    origin="npm"
    packages=$(echo "$cmd" | grep -oE 'yarn add\s+.*' | \
      sed 's/^yarn add\s*//' | \
      tr ' ' '\n' | { grep -v '^-' || true; } | { grep -v '^$' || true; } | \
      sed 's/@[^/]*$//' | head -20)
  elif echo "$cmd" | grep -qE '(pnpm add|pnpm i )'; then
    origin="npm"
    packages=$(echo "$cmd" | grep -oE '(pnpm add|pnpm i)\s+.*' | \
      sed -E 's/^(pnpm add|pnpm i)\s+//' | \
      tr ' ' '\n' | { grep -v '^-' || true; } | { grep -v '^$' || true; } | \
      sed 's/@[^/]*$//' | head -20)
  elif echo "$cmd" | grep -qE '(bun add|bun i )'; then
    origin="npm"
    packages=$(echo "$cmd" | grep -oE '(bun add|bun i)\s+.*' | \
      sed -E 's/^(bun add|bun i)\s+//' | \
      tr ' ' '\n' | { grep -v '^-' || true; } | { grep -v '^$' || true; } | \
      sed 's/@[^/]*$//' | head -20)
  elif echo "$cmd" | grep -qE '(pip install|pip3 install|uv pip install|uv add)'; then
    origin="pypi"
    packages=$(echo "$cmd" | grep -oE '(pip3? install|uv pip install|uv add)\s+.*' | \
      sed -E 's/^(pip3? install|uv pip install|uv add)\s+//' | \
      tr ' ' '\n' | { grep -v '^-' || true; } | { grep -v '^$' || true; } | \
      { grep -v '/' || true; } | sed 's/[>=<~!].*//' | head -20)
  elif echo "$cmd" | grep -qE '(cargo add|cargo install)'; then
    origin="crate"
    packages=$(echo "$cmd" | grep -oE '(cargo add|cargo install)\s+.*' | \
      sed -E 's/^(cargo add|cargo install)\s+//' | \
      tr ' ' '\n' | { grep -v '^-' || true; } | { grep -v '^$' || true; } | \
      sed 's/@.*//' | head -20)
  fi

  echo "$origin"
  echo "$packages"
}

extract_domains() {
  local text="$1"
  echo "$text" | \
    { grep -oE 'https?://[^/"'"'"'[:space:]>)]+' || true; } | \
    sed -E 's|^https?://||' | sed 's|/.*||' | sed 's|:.*||' | \
    { grep -v '^$' || true; } | \
    { grep -vE '^(localhost|127\.0\.0\.1|0\.0\.0\.0|::1|api\.brin\.sh)$' || true; } | \
    sort -u | head -10
}

handle_shell() {
  [ -z "$command" ] && exit 0

  local result origin packages
  result=$(extract_packages "$command")
  origin=$(echo "$result" | head -1)
  packages=$(echo "$result" | tail -n +2)

  if [ -z "$origin" ] || [ -z "$packages" ]; then
    local domains
    domains=$(extract_domains "$command")
    [ -z "$domains" ] && exit 0
    origin="domain"
    packages="$domains"
  fi

  local blocked=()
  local warnings=()

  while IFS= read -r item; do
    [ -z "$item" ] && continue
    local out
    out=$(check_brin "$origin" "$item") || true
    [ -z "$out" ] && continue

    local v
    v=$(echo "$out" | cut -d'|' -f2)
    case "$v" in
      malicious|suspicious) blocked+=("$out") ;;
      caution) warnings+=("$out") ;;
    esac
  done <<< "$packages"

  if [ ${#warnings[@]} -gt 0 ]; then
    local parts=()
    for w in "${warnings[@]}"; do
      local n v s
      n=$(echo "$w" | cut -d'|' -f1)
      v=$(echo "$w" | cut -d'|' -f2)
      s=$(echo "$w" | cut -d'|' -f3)
      parts+=("${n} (${v}, score: ${s})")
    done
    echo "{\"message\": \"brin: caution for: $(IFS=', '; echo "${parts[*]}")\"}" >&2
  fi

  if [ ${#blocked[@]} -gt 0 ]; then
    local parts=()
    for b in "${blocked[@]}"; do
      local n v s
      n=$(echo "$b" | cut -d'|' -f1)
      v=$(echo "$b" | cut -d'|' -f2)
      s=$(echo "$b" | cut -d'|' -f3)
      parts+=("${n} (${v}, score: ${s})")
    done
    echo "{\"exitCode\": 2, \"message\": \"brin: blocked — threat detected: $(IFS=', '; echo "${parts[*]}"). See https://brin.sh\"}"
    exit 2
  fi

  exit 0
}

handle_web_search() {
  if [ "$tool_name" != "web_search" ] && [ "$tool_name" != "WebSearch" ]; then
    exit 0
  fi

  local content
  content=$(echo "$input" | jq -r '.content // .input // .parameters // empty' 2>/dev/null) || true
  [ -z "$content" ] && exit 0

  local domains
  domains=$(extract_domains "$content")
  [ -z "$domains" ] && exit 0

  local dangerous=()
  local warnings=()

  while IFS= read -r domain; do
    [ -z "$domain" ] && continue
    local out
    out=$(check_brin "domain" "$domain") || true
    [ -z "$out" ] && continue

    local v
    v=$(echo "$out" | cut -d'|' -f2)
    case "$v" in
      malicious|suspicious) dangerous+=("$out") ;;
      caution) warnings+=("$out") ;;
    esac
  done <<< "$domains"

  local msg_parts=()

  if [ ${#dangerous[@]} -gt 0 ]; then
    local parts=()
    for d in "${dangerous[@]}"; do
      local n v s
      n=$(echo "$d" | cut -d'|' -f1)
      v=$(echo "$d" | cut -d'|' -f2)
      s=$(echo "$d" | cut -d'|' -f3)
      parts+=("${n} (${v}, score: ${s})")
    done
    msg_parts+=("THREAT: $(IFS=', '; echo "${parts[*]}")")
  fi

  if [ ${#warnings[@]} -gt 0 ]; then
    local parts=()
    for w in "${warnings[@]}"; do
      local n v s
      n=$(echo "$w" | cut -d'|' -f1)
      v=$(echo "$w" | cut -d'|' -f2)
      s=$(echo "$w" | cut -d'|' -f3)
      parts+=("${n} (${v}, score: ${s})")
    done
    msg_parts+=("Caution: $(IFS=', '; echo "${parts[*]}")")
  fi

  if [ ${#msg_parts[@]} -gt 0 ]; then
    echo "{\"message\": \"brin web scan: $(IFS='; '; echo "${msg_parts[*]}"). See https://brin.sh\"}"
  fi

  exit 0
}

case "$hook_event" in
  beforeShellExecution) handle_shell ;;
  postToolUse)          handle_web_search ;;
  *)
    if [ -n "$command" ]; then
      handle_shell
    elif [ -n "$tool_name" ]; then
      handle_web_search
    fi
    ;;
esac

exit 0
