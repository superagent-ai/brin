#!/usr/bin/env bash
set -euo pipefail

SCRIPT="./scripts/brin-check.sh"
PASS=0
FAIL=0

run_test() {
  local name="$1"
  local input="$2"
  local expect_exit="$3"
  local expect_pattern="${4:-}"

  local output exit_code
  output=$(echo "$input" | bash "$SCRIPT" 2>&1) && exit_code=$? || exit_code=$?

  local ok=true

  if [ "$exit_code" -ne "$expect_exit" ]; then
    ok=false
  fi

  if [ -n "$expect_pattern" ] && ! echo "$output" | grep -qE "$expect_pattern"; then
    ok=false
  fi

  if [ "$ok" = true ]; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    echo "        exit: $exit_code (expected $expect_exit)"
    if [ -n "$expect_pattern" ]; then
      echo "        pattern: $expect_pattern"
    fi
    echo "        output: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "brin-check.sh tests (live API)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "── npm registry ──"

run_test "npm install safe package" \
  '{"hook_event_name":"beforeShellExecution","command":"npm install express"}' \
  0

run_test "npm install multiple packages" \
  '{"hook_event_name":"beforeShellExecution","command":"npm install express lodash"}' \
  0

run_test "npm add with version" \
  '{"hook_event_name":"beforeShellExecution","command":"npm add express@4"}' \
  0

run_test "npx package" \
  '{"hook_event_name":"beforeShellExecution","command":"npx create-react-app my-app"}' \
  0

run_test "yarn add" \
  '{"hook_event_name":"beforeShellExecution","command":"yarn add express"}' \
  0

run_test "pnpm add" \
  '{"hook_event_name":"beforeShellExecution","command":"pnpm add express"}' \
  0

run_test "bun add" \
  '{"hook_event_name":"beforeShellExecution","command":"bun add express"}' \
  0

echo ""
echo "── pypi registry ──"

run_test "pip install returns verdict" \
  '{"hook_event_name":"beforeShellExecution","command":"pip install requests"}' \
  0

run_test "pip3 install" \
  '{"hook_event_name":"beforeShellExecution","command":"pip3 install flask"}' \
  0

run_test "uv pip install" \
  '{"hook_event_name":"beforeShellExecution","command":"uv pip install django"}' \
  0

run_test "uv add" \
  '{"hook_event_name":"beforeShellExecution","command":"uv add fastapi"}' \
  0

run_test "pip install with version spec" \
  '{"hook_event_name":"beforeShellExecution","command":"pip install requests>=2.28"}' \
  0

echo ""
echo "── crate registry ──"

run_test "cargo add" \
  '{"hook_event_name":"beforeShellExecution","command":"cargo add serde"}' \
  0

run_test "cargo install" \
  '{"hook_event_name":"beforeShellExecution","command":"cargo install ripgrep"}' \
  0

echo ""
echo "── domain/URL checks ──"

run_test "curl domain check" \
  '{"hook_event_name":"beforeShellExecution","command":"curl https://example.com/api"}' \
  0

run_test "wget domain check" \
  '{"hook_event_name":"beforeShellExecution","command":"wget https://github.com/file.tar.gz"}' \
  0

run_test "skips localhost" \
  '{"hook_event_name":"beforeShellExecution","command":"curl http://localhost:3000/api"}' \
  0

run_test "skips 127.0.0.1" \
  '{"hook_event_name":"beforeShellExecution","command":"curl http://127.0.0.1:8080/test"}' \
  0

run_test "skips brin API itself" \
  '{"hook_event_name":"beforeShellExecution","command":"curl https://api.brin.sh/npm/express"}' \
  0

echo ""
echo "── web search (postToolUse) ──"

run_test "web_search with URLs" \
  '{"hook_event_name":"postToolUse","tool_name":"web_search","content":"Results: https://example.com/docs https://github.com/repo"}' \
  0

run_test "WebSearch variant" \
  '{"hook_event_name":"postToolUse","tool_name":"WebSearch","content":"Found: https://example.com"}' \
  0

run_test "ignores non-web-search tools" \
  '{"hook_event_name":"postToolUse","tool_name":"read_file","content":"https://evil.example.com"}' \
  0

run_test "web search with no URLs" \
  '{"hook_event_name":"postToolUse","tool_name":"web_search","content":"No results found"}' \
  0

echo ""
echo "── edge cases ──"

run_test "empty input" \
  '{}' \
  0

run_test "no command field" \
  '{"hook_event_name":"beforeShellExecution"}' \
  0

run_test "non-matching command" \
  '{"hook_event_name":"beforeShellExecution","command":"ls -la"}' \
  0

run_test "npm install with no packages (bare)" \
  '{"hook_event_name":"beforeShellExecution","command":"npm install"}' \
  0

run_test "pip install with flags only" \
  '{"hook_event_name":"beforeShellExecution","command":"pip install -r requirements.txt"}' \
  0

run_test "unknown hook event falls back correctly" \
  '{"command":"npm install express"}' \
  0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
