+++
title = "uv: Managing Python Versions, Dependencies, Tools, and Scripts"
description = "A concise uv cheat sheet for managing Python versions, environments, dependencies, tools, and scripts in one workflow."
date = 2025-09-10
draft = false

[taxonomies]
tags = ["python", "uv", "developer-tooling", "package-management", "cheat-sheet"]

[extra]
keywords = "python, uv, developer-tooling, package-management, virtualenv, cheat-sheet"
toc = true
static_thumbnail = "/images/social-uv.png"

+++

`uv` provides a Cargo-like, cross-platform workflow for managing [Python projects](https://docs.astral.sh/uv/guides/projects/),
[command-line tools](https://docs.astral.sh/uv/guides/tools/),
[single-file scripts](https://docs.astral.sh/uv/guides/scripts/), and
[Python versions](https://docs.astral.sh/uv/guides/install-python/).

## Installation & Updates

```bash
# Install
curl -LsSf https://astral.sh/uv/install.sh | sh

# Update
uv self update
```

## Managing Python Versions

uv can manage Python versions instead of pyenv, mise, asdf, or OS-specific installation methods:

```bash
# List available versions
uv python list

# Install Python 3.13
uv python install 3.13
```

- Works across operating systems
- No admin rights required
- Independent of system Python

You can also use [mise](https://github.com/jdx/mise) alongside uv if you prefer a global version manager.

## Projects & Dependencies

Initialize a project and create `pyproject.toml`:

```bash
uv init myproject
# Or specify the Python version and project name:
uv init -p 3.13 --name myproject
cd myproject
```

Sync dependencies:

```bash
uv sync
```

Add dependencies:

```bash
uv add litestar
uv add pytest --dev
```

Generate a cross-platform lockfile, similar to `Pipfile.lock` or `poetry.lock`:

```bash
uv lock
```

The lockfile is cross-platform, so it can be generated on Windows and used for deployment on Linux.

## Virtual Environments

```bash
# Create and activate a virtual environment
uv venv
source .venv/bin/activate

# Or run in the environment without activating it
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

Run a single-file script and install its declared dependencies automatically:

```bash
uv run script.py
```

On Unix-like systems, add `#!/usr/bin/env -S uv run` and run `chmod +x script.py` to make the script executable.

## Tools

Install CLI tools in environments isolated from the system Python:

```bash
uv tool install ruff # replaces pipx
uv tool install httpie

uvx httpie # Run the tool without installing it permanently

# --with [temp dependency] runs jupyter in the current project
# without adding it and its dependencies to the project
uv run --with jupyter jupyter notebook
```

`uv run` checks the lockfile and environment before each command and updates them when needed.

For local CLI tool development:

```bash
uv init --package your_tool
uv tool install . -e
```

See the [tools documentation](https://docs.astral.sh/uv/concepts/tools/).

## Replacing pip-tools

```bash
uv pip compile # replaces pip-tools compile
uv pip sync    # replaces pip-tools sync
```

## Building and Publishing Packages

```bash
# Build a `.whl` package for PyPI
uv build
# Upload your Python package to PyPI
uv publish
```

## Pre-commit Hooks

```bash
uv run --with pre-commit-uv pre-commit run --all-files
pre-commit-uv
```

## GitHub Actions

```yaml
astral-sh/setup-uv # brings UV to GitHub Actions
```

## Docker

The official Docker images include uv and Python:

```dockerfile
ghcr.io/astral-sh/uv:latest
```

See also Hynek Schlawack’s [Production-ready Python Docker Containers with uv](https://hynek.me/articles/docker-uv/).

## Workspaces

Use a [workspace](https://docs.astral.sh/uv/concepts/projects/workspaces/) to manage multiple packages together.

For example, a repository can contain a FastAPI application and several libraries, each maintained as a separate Python
package.

Each package has its own `pyproject.toml`, while the workspace uses one lockfile and a consistent set of dependencies.

## Notes and Limitations

- `uv sync` respects `.python-version`, but the `UV_PYTHON` environment variable takes precedence
- Uses [python-build-standalone](https://github.com/astral-sh/python-build-standalone), whose builds can be slightly slower
  than system builds (~1–3%) and lack CPU-specific optimizations
- The cache can grow large
- Legacy projects may fail if they depended on pip’s older, looser dependency resolution rules
- Faster dependency installation can reduce CI and container build times
- Astral maintains python-build-standalone, which provides Python builds that do not require installers

## Further Reading

- [Dependency Sources](https://docs.astral.sh/uv/concepts/projects/dependencies/#dependency-sources)
  — explains how uv resolves dependencies
- [UV with Django](https://blog.pecar.me/uv-with-django)
- [PEP 723 – Inline script metadata](https://peps.python.org/pep-0723/)
- [WIP: Using uv run as a task runner](https://github.com/astral-sh/uv/issues/5903)
