---
name: brin-check
description: Scan packages, repositories, MCP servers, domains, and agent skills for security threats using the brin API. Use this skill before installing dependencies or integrating external resources.
---

# brin Security Check

Scan any external resource for security threats using the brin API before installing or using it.

## Usage

When the user asks to check or scan a resource, or when you need to verify the safety of an external dependency:

1. Identify the resource type and name
2. Call the appropriate brin API endpoint
3. Report the verdict, score, and any detected threats

## API Reference

The brin API requires no authentication. Make a GET request to:

```
https://api.brin.sh/<origin>/<identifier>
```

### Supported Origins

| Origin | Identifier | Example |
|--------|-----------|---------|
| `npm` | package name | `https://api.brin.sh/npm/express` |
| `pypi` | package name | `https://api.brin.sh/pypi/requests` |
| `crate` | crate name | `https://api.brin.sh/crate/serde` |
| `domain` | domain | `https://api.brin.sh/domain/example.com` |
| `page` | domain/path | `https://api.brin.sh/page/example.com/path` |
| `repo` | owner/repo | `https://api.brin.sh/repo/facebook/react` |
| `mcp` | owner/repo | `https://api.brin.sh/mcp/modelcontextprotocol/servers` |
| `skill` | owner/repo | `https://api.brin.sh/skill/owner/skill-name` |

### Response Format

The API returns JSON with these fields:

| Field | Type | Description |
|-------|------|-------------|
| `origin` | string | Source type |
| `identifier` | string | Resource identifier |
| `score` | integer | 0–100 safety score (higher is safer) |
| `confidence` | string | `low`, `medium`, or `high` |
| `verdict` | string | `safe`, `caution`, `suspicious`, or `malicious` |
| `sub_scores` | object | Breakdown: `identity`, `behavior`, `content`, `graph` |
| `threats` | array | Detected threat signals (if any) |
| `scanned_at` | string | ISO 8601 timestamp |

Response headers also include `x-brin-verdict` and `x-brin-score` for lightweight checks.

## Step-by-Step

### 1. Determine the origin and identifier

Parse the user's request to determine what type of resource they want to check. Examples:
- "Check if lodash is safe" → `npm/lodash`
- "Scan the requests Python package" → `pypi/requests`
- "Is github.com/owner/repo safe?" → `repo/owner/repo`
- "Check this MCP server: owner/server" → `mcp/owner/server`

### 2. Query the API

```bash
curl -s https://api.brin.sh/npm/lodash
```

### 3. Interpret the results

Report the following to the user:

- **Verdict**: The overall safety assessment
- **Score**: The numerical score (0–100)
- **Sub-scores**: Break down which dimensions are strong or weak
- **Threats**: List any specific threats detected with their descriptions

### 4. Recommend action

| Verdict | Recommendation |
|---------|---------------|
| `safe` | Safe to use. Proceed with installation. |
| `caution` | Generally safe but review the flagged concerns before proceeding. |
| `suspicious` | Significant risk detected. Recommend finding an alternative. |
| `malicious` | Do NOT install. This resource contains known threats. |

## Example Output

When reporting results, format them clearly:

```
brin scan: express (npm)
━━━━━━━━━━━━━━━━━━━━━━━━
Score:    81/100
Verdict:  safe ✓
Confidence: medium

Sub-scores:
  Identity: 95  Behavior: 40  Content: 100  Graph: 30

No threats detected.
```

For dangerous packages:

```
brin scan: malicious-pkg (npm)
━━━━━━━━━━━━━━━━━━━━━━━━
Score:    12/100
Verdict:  malicious ✗
Confidence: high

Sub-scores:
  Identity: 5  Behavior: 10  Content: 15  Graph: 18

Threats:
  • credential harvesting — Attempts to read and exfiltrate environment variables
  • obfuscated payload — Contains Base64-encoded execution logic
```

## Batch Scanning

When multiple packages are being installed, scan each one individually and provide a summary table:

```
brin scan summary
━━━━━━━━━━━━━━━━━━━━━━━━
Package        Score  Verdict
express        81     safe ✓
lodash         88     safe ✓
sketchy-lib    23     suspicious ⚠
```
