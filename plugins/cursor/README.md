# brin cursor plugin

this is a [cursor plugin](https://cursor.com/docs/reference/plugins) that integrates brin's security scanning directly into your cursor workflow.

## what it does

- **pre-install hook** — automatically scans packages before `npm install`, `pip install`, `cargo add`, and other package manager commands. blocks `suspicious` or `malicious` packages and warns on `caution` verdicts.
- **url/domain hook** — automatically scans domains before `curl`, `wget`, and other HTTP commands to catch malicious URLs, prompt injection, and phishing.
- **web search hook** — scans domains returned by web search results after each search, warning about dangerous or suspicious sites.
- **brin-check skill** — invoke with `/brin-check` in agent chat to scan any package, repo, MCP server, domain, web page, or skill on demand.
- **brin-scan command** — invoke with `/brin-scan <resource>` for a quick security check (e.g. `/brin-scan express`, `/brin-scan domain:example.com`).
- **security rules** — teaches the AI agent to always consider brin scores when suggesting dependencies, visiting URLs, or integrating external resources.

## install

install the plugin from the cursor marketplace, or add it manually:

1. clone this repo into your cursor plugins directory, or
2. copy the `plugins/cursor` directory into your project:

```
plugins/cursor/
  .cursor-plugin/plugin.json    # plugin manifest
  hooks/hooks.json               # hook configuration
  scripts/brin-check.sh          # brin security check (all hooks)
  rules/brin-security.mdc       # AI agent security rules
  skills/brin-check/SKILL.md    # brin scanning skill
  commands/brin-scan.md          # brin scan command
```

3. make the hook script executable:

```bash
chmod +x plugins/cursor/scripts/brin-check.sh
```

4. restart cursor to load the plugin.

## supported package managers

| registry | package managers matched |
|----------|------------------------|
| npm | `npm install`, `npm add`, `npm i`, `npx`, `yarn add`, `yarn install`, `pnpm add`, `pnpm install`, `pnpm i`, `bun add`, `bun install`, `bun i` |
| pypi | `pip install`, `pip3 install`, `uv pip install`, `uv add` |
| crate | `cargo add`, `cargo install` |

## web and url scanning

the plugin also protects against malicious web content:

| hook | trigger | what it does |
|------|---------|--------------|
| url check | `curl`, `wget`, `http`, `fetch` | scans domains before HTTP requests are made |
| web search | after any `web_search` tool use | scans domains from search results for threats |

brin detects prompt injection, phishing, cloaking, credential harvesting, and exfiltration hidden in web pages.

## testing

the plugin includes a test suite that runs against the live brin API:

```bash
make test
```

requires `bash`, `curl`, and `jq`.

## usage

the hooks run automatically. for manual scans, use:

- `/brin-check` — full security analysis with scores and confidence
- `/brin-scan <resource>` — quick scan of a specific resource (packages, domains, URLs, repos, etc.)
