+++
title = "Helix for Python Development"
description = "Set up Helix for Python development with LSP, ty type checking, Ruff formatting and linting, plus a few editor refinements."
date = 2026-03-29
draft = false

[taxonomies]
tags = ["helix", "python", "developer-tooling", "lsp"]

[extra]
keywords = "helix, python, developer-tooling, lsp, ty, ruff"
toc = false
static_thumbnail = "/images/social-helix-python.png"

+++

I use Visual Studio Code for work and personal projects. It has been my main editor for years, across several languages
and ecosystems.

Since I started using coding agents and chat-based interfaces, I've also wanted a more focused environment without
the panels, notifications, and status updates. This is especially useful when I'm reading a book and reimplementing
its examples. I've been using Helix, a terminal-based code editor, for this kind of work.

I previously configured Helix for Go but didn't record the steps. This note covers my Python setup: LSP support,
type checking with ty, formatting and linting with Ruff, and debugging with debugpy.

I use macOS, so some paths and shell commands are platform-specific. The Helix configuration should work on other
operating systems as well.

Start by checking Helix's Python configuration:

```bash
hx --health python
```

In my case, the output looks like this:

```shell
Configured language servers:
  ✘ ty: 'ty' not found in $PATH
  ✘ ruff: 'ruff' not found in $PATH
  ✘ jedi: 'jedi-language-server' not found in $PATH
  ✘ pylsp: 'pylsp' not found in $PATH
Configured debug adapter: None
Configured formatter: None
Tree-sitter parser: ✓
Highlight queries: ✓
Textobject queries: ✓
Indent queries: ✓
```

No language servers or formatters are available yet, but the Tree-sitter parser and queries are configured. I use
[uv](/uv/) to install Ruff and ty:

```bash
uv tool install ruff
uv tool install ty
```

This installs Ruff and ty as command-line tools. On macOS, `uv tool install` puts executables in a user bin directory
that must be on `PATH`. The exact path depends on your setup; a common configuration is:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

If needed, update the shell configuration and then check that both tools are available:

```bash
which ruff
which ty
```

If `which` prints nothing, Helix will not find the tools either. Check the configuration again:

```bash
hx --health python
```

The output should now look like this:

```shell
Configured language servers:
  ✓ ty: /Users/akrisanov/.local/bin/ty
  ✓ ruff: /Users/akrisanov/.local/bin/ruff
  ✘ jedi: 'jedi-language-server' not found in $PATH
  ✘ pylsp: 'pylsp' not found in $PATH
Configured debug adapter: None
Configured formatter: None
Tree-sitter parser: ✓
Highlight queries: ✓
Textobject queries: ✓
Indent queries: ✓
```

Open the Helix language configuration, usually `~/.config/helix/languages.toml`, and add:

```toml
[[language]]
name = "python"
language-servers = ["ruff", "ty"]
auto-format = true
formatter = { command = "ruff", args = ["format", "-"] }

[language-server.ruff]
command = "ruff"
args = ["server"]

[language-server.ty]
command = "ty"
args = ["server"]
```

For debugging, install `debugpy` with pip:

```bash
pip install debugpy
```

Then append this configuration to `languages.toml`:

```toml
[language.debugger]
name = "debugpy"
transport = "stdio"
command = "python3"
args = ["-m", "debugpy.adapter"]

[[language.debugger.templates]]
name = "source"
request = "launch"
completion = [
  { name = "entrypoint", completion = "filename", default = "." }
]
args = { mode = "debug", program = "{0}" }
```
