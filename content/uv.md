+++
title = "uv: Cargo-like Python Tool That Replaces pipx, pyenv, and more"
description = "A concise cheat sheet for uv: managing Python versions, dependencies, virtual environments, scripts, and tools in one fast, cross-platform tool."
date = 2025-09-10
draft = false

[taxonomies]
tags = ["python", "tooling", "cheat-sheet"]

[extra]
keywords = "python, virtualenv, pip, pipx, poetry, uv, packaging, cheat-sheet"
toc = true
+++

## Overview

> `uv` is an end-to-end solution for managing [Python projects](https://docs.astral.sh/uv/guides/projects/),
[command-line tools](https://docs.astral.sh/uv/guides/tools/),
[single-file scripts](https://docs.astral.sh/uv/guides/scripts/), and even
[Python itself](https://docs.astral.sh/uv/guides/install-python/).

Think of it as Python’s Cargo: a unified, cross‑platform tool that’s fast, reliable, and easy to use.

This post is not a deep introduction to uv — many excellent articles already exist; instead,
it’s a concise cheat sheet for everyday use.

## Installation & Updates

```bash
# Install
curl -LsSf https://astral.sh/uv/install.sh | sh

# Update
uv self update
```

## Managing Python Versions

Instead of juggling tools like pyenv, mise, asdf, or OS‑specific hacks, you can simply use uv:

```bash
# List available versions
uv python list

# Install Python 3.13
uv python install 3.13
```

- Works the same across all OSes
- No admin rights required
- Independent of system Python

You can also use [mise](https://github.com/jdx/mise) alongside uv if you prefer a global version manager.

## Projects & Dependencies

Initialize a new project (creates a pyproject.toml automatically):

```bash
uv init myproject or # uv init -p 3.13 --name myproject
cd myproject
```

Sync dependencies (similar to `pip install -r requirements.txt`, but faster and more reliable):

```bash
uv sync
```

Add dependencies:

```bash
uv add litestar
uv add pytest --dev
```

Lock dependencies (generates a cross‑platform lockfile, like Pipfile.lock or poetry.lock):

```bash
uv lock
```

> 💡 The lock file is cross platform, so you can develop on Windows and deploy on Linux.

## Fast Virtual Environments

```bash
# Create & activate venv automatically
uv venv
source .venv/bin/activate

# Or skip activation and run directly with uv:
uv run python app.py
```

## Scripts

```bash
# Create a new script
uv init --script
```

```python
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "requests",
# ]
# ///
import requests

print(requests.get("https://akrisanov.com"))
```

Run single‑file scripts with automatic dependency installation:

```bash
uv run script.py
```

> 💡  On *nix, add `#!/usr/bin/env -S uv run` (then `chmod +x`) to automatically call `uv run` for a script.

## Tools

Install CLI tools globally, isolated from system Python:

```bash
uv tool install ruff # replaces pipx
uv tool install httpie

uvx httpie # a shortcut

# --with [temp dependency] runs jupyter in the current project
# without adding it and its dependencies to the project
uv run --with jupyter jupyter notebook
```

> 💡 `uv` run is fast enough that it implicitly re‑locks and re‑syncs the project each time, keeping your environment
> up to date automatically.

If you're developing a CLI tool, uv can help minimize the friction:

```bash
uv init --package your_tool
uv tool install . -e
```

See the [tools documentation](https://docs.astral.sh/uv/concepts/tools/)

## Replacing pip-tools

```bash
uv pip compile # replaces pip-tools compile
uv pip sync    # replaces pip-tools sync
```

## Building and publishing packages

```bash
# Build a `.whl` package for PyPI
uv build
# Upload your Python package to PyPI
uv publish
```

## Pre-commit hooks

```bash
uv run --with pre-commit-uv pre-commit run --all-files
pre-commit-uv
```

## GitHub Actions

```yaml
astral-sh/setup-uv # brings UV to GitHub Actions
```

## Docker

Official Docker images provide uv and Python preinstalled:

```dockerfile
ghcr.io/astral-sh/uv:latest
```

Also, check [Production-ready Python Docker Containers with uv](https://hynek.me/articles/docker-uv/) by Hynek Schlawack.

## Workspaces

`uv` supports organizing one or more packages into a [workspace](https://docs.astral.sh/uv/concepts/projects/workspaces/)
to manage them together.

*Example*: you might have a FastAPI web application alongside several libraries, all versioned and maintained as separate
Python packages in the same Git repository.

In a workspace, each package has its own `pyproject.toml`, but the workspace shares a single lockfile, ensuring that
the workspace operates with a consistent set of dependencies.

## Things to Keep in Mind

- `uv sync` respects `.python-version`, but the `UV_PYTHON` environment variable takes precedence
- Uses python‑build‑standalone, which can be slightly slower than system builds (~1–3%) and lacks CPU‑specific optimizations
- Cache size can grow large (a trade‑off for speed and reliability)
- Legacy projects may fail if they depended on pip’s older, looser dependency resolution rules

## Why uv Matters

Python has always had a fragmented ecosystem of tools: pip, pip-tools, virtualenv, venv, pipx, pyenv, poetry, tox…

With uv, we finally get something closer to Rust’s Cargo or JavaScript’s npm/pnpm:
a single, consistent, cross‑platform tool for environments, dependencies, scripts, and tools — and it’s fast.

## References & Further Reading

- [Dependency Sources](https://docs.astral.sh/uv/concepts/projects/dependencies/#dependency-sources)
  — explains how uv resolves dependencies
- [UV with Django](https://blog.pecar.me/uv-with-django)
- [PEP 723 – Inline script metadata](https://peps.python.org/pep-0723/)
- [WIP: Using uv run as a task runner](https://github.com/astral-sh/uv/issues/5903)

## Additional Notes

- While some people don’t care about uv being fast, it’s shaved minutes off CI builds and container rebuilds —
  saving money and energy.
- Astral capitalized on a very promising project called
  [python-build-standalone](https://github.com/astral-sh/python-build-standalone) and now maintains it.
  These are Python builds that work without installers.
