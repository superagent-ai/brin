<p align="center">
  <img src="assets/logo.png" alt="brin" height="120">
</p>

<h1 align="center">brin</h1>
<p align="center">
  credit score for context
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  &nbsp;
  <a href="https://www.ycombinator.com"><img src="https://img.shields.io/badge/Backed%20by-Y%20Combinator-orange" alt="Backed by Y Combinator"></a>
  &nbsp;
  <a href="https://discord.gg/spZ7MnqFT4"><img src="https://img.shields.io/badge/Discord-Join-7289da?logo=discord&logoColor=white" alt="Discord"></a>
  &nbsp;
  <a href="https://x.com/superagent_ai"><img src="https://img.shields.io/badge/X-Follow-000000?logo=x&logoColor=white" alt="X"></a>
  &nbsp;
  <a href="https://www.linkedin.com/company/superagent-sh/"><img src="https://img.shields.io/badge/LinkedIn-Follow-0077b5?logo=linkedin&logoColor=white" alt="LinkedIn"></a>
</p>

---

every time an ai agent pulls in a package, repo, skill, or web page, it trusts that context blindly. brin scores each one - detecting malware, prompt injection, and supply chain attacks before your agent acts.

this repo contains the **brin dataset** - open source threat scan records produced by brin's scoring pipeline, covering packages, domains, repositories, agent skills, mcp servers, and commits. free to use for research, red-teaming, and model training.

---

## schema

each record is a single brin scan result. the fields are:

| field | type | description |
|-------|------|-------------|
| `origin` | string | source type: `npm`, `pypi`, `crate`, `domain`, `page`, `repo`, `skill`, `mcp` |
| `identifier` | string | identifier within the origin (e.g. `express`, `example.com`) |
| `version` | string | version or ref (optional) |
| `score` | integer | 0–100 safety score. higher is safer |
| `confidence` | string | `low`, `medium`, or `high` |
| `verdict` | string | `safe`, `caution`, `suspicious`, or `malicious` |
| `sub_scores` | object | breakdown across four dimensions (see below) |
| `threats` | array | detected threat signals with type and description (optional, omitted if none) |
| `scanned_at` | string | ISO 8601 timestamp of when the scan was run |

### sub_scores

| dimension | description |
|-----------|-------------|
| `identity` | publisher reputation, domain age, ownership signals |
| `behavior` | runtime behavior, network calls, install scripts |
| `content` | source code, prompt content, instruction analysis |
| `graph` | dependency graph, transitive risk, maintainer overlap |

### example record

```json
{
  "origin": "npm",
  "identifier": "express",
  "version": "4.18.2",
  "score": 81,
  "confidence": "medium",
  "verdict": "safe",
  "sub_scores": {
    "identity": 95.0,
    "behavior": 40.0,
    "content": 100.0,
    "graph": 30.0
  },
  "scanned_at": "2026-02-25T09:00:00Z"
}
```

---

## coverage

| origin | what is scored | threats detected |
|--------|---------------|-----------------|
| `npm` / `pypi` / `crate` | open source packages | install-time attacks, credential harvesting, typosquatting |
| `domain` / `page` | websites and web pages | prompt injection, phishing, cloaking, exfiltration via hidden content |
| `repo` | github repositories | agent config injection, malicious commits, compromised dependencies |
| `skill` | agent skills | description injection, output poisoning, instruction override |
| `mcp` | mcp servers | tool shadowing, schema abuse, silent capability escalation |

---

## format

records are stored as **jsonl** (newline-delimited json) - one record per line. this makes the dataset trivially streamable and parseable without loading everything into memory.

files are organized by origin under `data/`:

```
data/
  npm.jsonl
  pypi.jsonl
  crate.jsonl
  domain.jsonl
  page.jsonl
  repo.jsonl
  skill.jsonl
  mcp.jsonl
```

---

## contributing

see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## license

MIT

---

<p align="center">
  <sub>built by <a href="https://superagent.sh">superagent</a> - ai security for the agentic era</sub>
</p>
