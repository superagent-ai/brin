---
name: brin-scan
description: Scan a package, repo, MCP server, domain, or skill for security threats using the brin API.
---

# brin Scan

Scan the specified resource for security threats using the brin API.

## Instructions

1. Parse the user's input to determine the resource type and identifier. If the user provides a type prefix (e.g., `npm:lodash`), use it directly. Otherwise, infer the type from context.

2. Run the following command to query the brin API:

```bash
curl -s "https://api.brin.sh/{origin}/{identifier}"
```

Replace `{origin}` with one of: `npm`, `pypi`, `crate`, `domain`, `page`, `repo`, `mcp`, `skill`.
Replace `{identifier}` with the resource name.

3. Parse the JSON response and report the results to the user, including:
   - The overall verdict and score
   - Sub-score breakdown (identity, behavior, content, graph)
   - Any detected threats with descriptions
   - A clear recommendation on whether to proceed

4. If the verdict is `suspicious` or `malicious`, strongly advise the user NOT to use the resource and suggest alternatives if possible.

## Examples

- `/brin-scan express` — Scans the npm package `express`
- `/brin-scan pypi:requests` — Scans the PyPI package `requests`
- `/brin-scan repo:facebook/react` — Scans the GitHub repository `facebook/react`
- `/brin-scan mcp:modelcontextprotocol/servers` — Scans an MCP server
- `/brin-scan domain:example.com` — Scans a domain
