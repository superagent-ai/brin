---
name: brin-check
description: Scan packages, repositories, MCP servers, domains, web pages, and agent skills for security threats using the brin API. Use this skill before installing dependencies, visiting URLs, or integrating external resources.
---

# brin Security Check

Scan any external resource for security threats using the brin API before installing, visiting, or using it.

## Usage

When the user asks to check or scan a resource, when you need to verify the safety of an external dependency, or when you encounter unfamiliar URLs or domains:

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
- "Is example.com safe?" → `domain/example.com`
- "Check this URL: https://example.com/path" → `page/example.com/path`
- "Scan the domains from my web search results" → `domain/<each-domain>`

### 2. Query the API

```bash
curl -s https://api.brin.sh/npm/lodash
curl -s https://api.brin.sh/domain/example.com
curl -s https://api.brin.sh/page/example.com/some/path
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

## Web Search and URL Scanning

When web search results return URLs or the user provides links, scan the domains before visiting:

### Scanning domains from web search

```bash
curl -s https://api.brin.sh/domain/example.com
```

### Scanning a specific page

```bash
curl -s https://api.brin.sh/page/example.com/docs/guide
```

### Example output for a domain scan

```
brin scan: example.com (domain)
━━━━━━━━━━━━━━━━━━━━━━━━
Score:    92/100
Verdict:  safe ✓
Confidence: high

Sub-scores:
  Identity: 95  Behavior: 90  Content: 95  Graph: 88

No threats detected.
```

For a dangerous domain:

```
brin scan: malicious-site.xyz (domain)
━━━━━━━━━━━━━━━━━━━━━━━━
Score:    8/100
Verdict:  malicious ✗
Confidence: high

Sub-scores:
  Identity: 5  Behavior: 3  Content: 10  Graph: 15

Threats:
  • prompt injection — Hidden instructions embedded in page content
  • credential harvesting — Login form mimicking a legitimate service
  • cloaking — Different content served to bots vs. browsers
```

### When to scan URLs

- After a web search returns results with unfamiliar domains
- Before following links from external documentation or READMEs
- When a user asks you to visit or read content from a URL
- Before scraping or extracting data from any web page
- When evaluating third-party API documentation links

### Batch URL scanning

For multiple URLs from search results, scan each domain and provide a summary:

```
brin domain scan summary
━━━━━━━━━━━━━━━━━━━━━━━━
Domain              Score  Verdict
docs.example.com    95     safe ✓
blog.trusted.io     88     safe ✓
free-tools.xyz      15     suspicious ⚠
```
