#!/usr/bin/env bash
set -euo pipefail

BRIN_API="https://api.brin.sh"
BRIN_TIMEOUT=10

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')

if [ "$tool_name" != "web_search" ] && [ "$tool_name" != "WebSearch" ]; then
  exit 0
fi

content=$(echo "$input" | jq -r '.content // .input // .parameters // empty' 2>/dev/null)
if [ -z "$content" ]; then
  exit 0
fi

extract_domains() {
  local text="$1"
  echo "$text" | \
    grep -oE 'https?://[^/"'"'"'[:space:]>)]+' | \
    sed -E 's|^https?://||' | \
    sed 's|/.*||' | \
    sed 's|:.*||' | \
    grep -v '^$' | \
    grep -v '^\(localhost\|127\.0\.0\.1\|0\.0\.0\.0\|::1\)$' | \
    grep -v '^api\.brin\.sh$' | \
    sort -u | \
    head -20
}

check_domain() {
  local domain="$1"

  if [ -z "$domain" ]; then
    return 0
  fi

  local url="${BRIN_API}/domain/${domain}"
  local response
  response=$(curl -s -m "$BRIN_TIMEOUT" -D - -o /dev/null "$url" 2>/dev/null) || return 0

  local verdict
  verdict=$(echo "$response" | grep -i 'x-brin-verdict' | tr -d '\r' | awk '{print $2}')

  local score
  score=$(echo "$response" | grep -i 'x-brin-score' | tr -d '\r' | awk '{print $2}')

  if [ -z "$verdict" ]; then
    return 0
  fi

  echo "$domain|$verdict|$score"
}

domains=$(extract_domains "$content")

if [ -z "$domains" ]; then
  exit 0
fi

dangerous=()
warnings=()

while IFS= read -r domain; do
  [ -z "$domain" ] && continue

  result=$(check_domain "$domain" 2>/dev/null) || continue

  if [ -z "$result" ]; then
    continue
  fi

  d_name=$(echo "$result" | cut -d'|' -f1)
  d_verdict=$(echo "$result" | cut -d'|' -f2)
  d_score=$(echo "$result" | cut -d'|' -f3)

  case "$d_verdict" in
    malicious|suspicious)
      dangerous+=("${d_name} (verdict: ${d_verdict}, score: ${d_score})")
      ;;
    caution)
      warnings+=("${d_name} (verdict: ${d_verdict}, score: ${d_score})")
      ;;
  esac
done <<< "$domains"

msg_parts=()

if [ ${#dangerous[@]} -gt 0 ]; then
  msg_parts+=("THREAT DETECTED: $(IFS=', '; echo "${dangerous[*]}")")
fi

if [ ${#warnings[@]} -gt 0 ]; then
  msg_parts+=("Caution: $(IFS=', '; echo "${warnings[*]}")")
fi

if [ ${#msg_parts[@]} -gt 0 ]; then
  full_msg="brin web scan: $(IFS='; '; echo "${msg_parts[*]}"). See https://brin.sh for details."
  echo "{\"message\": \"$full_msg\"}"
fi

exit 0
