#!/usr/bin/env bash
set -euo pipefail

BRIN_API="https://api.brin.sh"
BRIN_TIMEOUT=10

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

if [ -z "$command" ]; then
  exit 0
fi

extract_domains() {
  local cmd="$1"
  echo "$cmd" | \
    grep -oE 'https?://[^/"'"'"'[:space:]]+' | \
    sed -E 's|^https?://||' | \
    sed 's|/.*||' | \
    sed 's|:.*||' | \
    grep -v '^$' | \
    grep -v '^\(localhost\|127\.0\.0\.1\|0\.0\.0\.0\|::1\)$' | \
    grep -v '^api\.brin\.sh$' | \
    sort -u | \
    head -10
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

  case "$verdict" in
    dangerous|malicious)
      echo "BLOCKED"
      echo "$domain"
      echo "$verdict"
      echo "$score"
      return 1
      ;;
    suspicious)
      echo "BLOCKED"
      echo "$domain"
      echo "$verdict"
      echo "$score"
      return 1
      ;;
    caution)
      echo "WARNING"
      echo "$domain"
      echo "$verdict"
      echo "$score"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

domains=$(extract_domains "$command")

if [ -z "$domains" ]; then
  exit 0
fi

blocked=()
warnings=()

while IFS= read -r domain; do
  [ -z "$domain" ] && continue

  check_output=$(check_domain "$domain" 2>&1) || true

  status=$(echo "$check_output" | head -1)

  if [ "$status" = "BLOCKED" ]; then
    d_name=$(echo "$check_output" | sed -n '2p')
    d_verdict=$(echo "$check_output" | sed -n '3p')
    d_score=$(echo "$check_output" | sed -n '4p')
    blocked+=("${d_name} (verdict: ${d_verdict}, score: ${d_score})")
  elif [ "$status" = "WARNING" ]; then
    d_name=$(echo "$check_output" | sed -n '2p')
    d_verdict=$(echo "$check_output" | sed -n '3p')
    d_score=$(echo "$check_output" | sed -n '4p')
    warnings+=("${d_name} (verdict: ${d_verdict}, score: ${d_score})")
  fi
done <<< "$domains"

if [ ${#warnings[@]} -gt 0 ]; then
  warning_msg="brin: caution for domain(s): $(IFS=', '; echo "${warnings[*]}")"
  echo "{\"message\": \"$warning_msg\"}" >&2
fi

if [ ${#blocked[@]} -gt 0 ]; then
  block_msg="brin: blocked request — threat detected for domain(s): $(IFS=', '; echo "${blocked[*]}"). See https://brin.sh for details."
  echo "{\"exitCode\": 2, \"message\": \"$block_msg\"}"
  exit 2
fi

exit 0
