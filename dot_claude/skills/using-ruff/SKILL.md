---
name: using-ruff
description: Use when linting or formatting Python code, setting up a new Python project's tooling, fixing ruff errors/warnings, choosing rule sets, configuring pyproject.toml, or replacing flake8/black/isort/pyupgrade/pylint.
---

# Using Ruff

## Overview
Ruff is a single fast (Rust) tool that replaces flake8, black, isort, pyupgrade, and most pylint checks. One binary, one config block, no plugin zoo.

## Quick Reference

| Task | Command |
|---|---|
| Lint | `ruff check .` |
| Lint + autofix | `ruff check --fix .` |
| Format (black-compatible) | `ruff format .` |
| Check formatting only (CI) | `ruff format --check .` |
| Show rule explanation | `ruff rule E501` |
| Add as dev dep (uv) | `uv add --dev ruff` |
| Run via uv | `uv run ruff check .` |

Lint and format are **separate subcommands** — running one doesn't run the other. Don't also run black/isort/pyupgrade alongside ruff; pick ruff for both or neither, running both fights over line endings and import order.

**Fix issues by running the tool, not by hand-editing.** When `ruff check` or `ruff format` reports a problem, run `ruff check --fix` / `ruff format` and let it rewrite the file, then read the diff. Don't manually retype the fixed line(s) — manual edits drift from ruff's actual formatting rules (quote style, trailing commas, import order) and re-trigger the same finding next run.

## Config (pyproject.toml)

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "C4", "SIM"]
# E/F = pyflakes+pycodestyle, I = isort, UP = pyupgrade, B = bugbear, C4 = comprehensions, SIM = simplify

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["S101"]  # allow assert in tests

[tool.ruff.format]
quote-style = "double"
```

`select = ["ALL"]` is tempting but noisy on real codebases — start from a curated set above and widen deliberately.

## Suppressing a single line

```python
import unused_thing  # noqa: F401
```

Prefer a narrow `# noqa: <code>` over a bare `# noqa` (silences everything) or a project-wide ignore (hides the rule everywhere, not just here).

## Pre-commit integration

```yaml
- repo: https://github.com/astral-sh/ruff-pre-commit
  rev: v0.8.0  # pin, then bump deliberately
  hooks:
    - id: ruff
      args: [--fix]
    - id: ruff-format
```

## Common Mistakes

- Running black/isort/pyupgrade in addition to ruff — redundant and can conflict on formatting decisions.
- Unpinned ruff version in CI vs local dev — rule sets change between releases, causing "works on my machine" lint diffs. Pin in both `pyproject.toml`/lockfile and pre-commit `rev`.
- `select = ["ALL"]` without triage — buries real issues under hundreds of stylistic nits.
- Bare `# noqa` instead of `# noqa: CODE` — silences future errors on that line too.
- Forgetting `ruff format --check` in CI (only running `ruff check`) — formatting drift ships unnoticed.
