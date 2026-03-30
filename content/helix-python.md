+++
title = "Helix for Python Development"
description = "Configure modern Python tooling in Helix: LSP, type checker (ty), code formatter (ruff) and more."
date = 2026-03-29
draft = false

[taxonomies]
tags = ["helix", "python", "tooling"]

[extra]
keywords = "helix, python, lsp, ty, ruff, formatter, type checker, code analysis"
+++

In a day to day life, I'm big Visual Studio Code user. I use it for all my working and personal projects, and most
of the time, I love it. I've been using this editor for years while switching between different languages and ecosystems,
and it has been a great companion for my development journey. I truly appreciate the effort that Microsoft has put
into making VS Code a versatile and powerful tool for all sorts of developers.

However, with the rise of coding agents and chat-based interfaces, I've found myself looking for a less distracting
and more focused coding environment. I want something that allows me to immerse myself in the code without the
constant notifications and status updates that come in panels and sidebars. Especially when I read books and try
to reimplement the concepts and examples in code. For that reason, I've been exploring Helix, a terminal-based code
editor that promises to be fast, efficient, and yet powerful enough for modern development.

I've already configured Helix for working with code in Go, and it has been a great experience. Unfortunately, I haven't
written a note for myself about setting up Helix back then. Such a pitty. To avoid the same mistake, here's a note
about how I set up Helix for Python development, including LSP, type checker (ty), code formatter (ruff) and more.
I hope this cheat sheet will be useful for anyone else and save you some time.

A quick disclaimer: I'm a macOS user, so some of the instructions may be specific to that platform.
However, most of the tools and configurations should work on other operating systems as well.

Before we start, how do you even check whether Helix is configured for Python development?
The easiest way is to run this command in the terminal:

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

As you can see, I haven't configured any language servers or formatters yet, but I have the Tree-sitter parser and queries set up.
Let's fix that. As many of us, I'm a big fan of Astral's tools, so I'll be using [uv](/uv) to manage dependencies.

```bash
uv tool install ruff
uv tool install ty
```

This will install ruff (code formatter) and ty (type checker) as command-line tools that we can use in Helix.
On macOS, uv tool install puts executables in a user bin directory that must be on your PATH.
The exact path depends on your setup, but a very common fix is:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Execute the command above if you haven't already, and then check that the tools are available:

```bash
which ruff
which ty
```

If which shows nothing, Helix will not see them either. Now, let's check the health again:

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

To make the tools work in Helix, we need to add some configuration. Open the Helix configuration file
(usually located at `~/.config/helix/languages.toml`) and add the following lines:

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

The final part is to make `debugpy` available for debugging. You can install it with pip:

```bash
pip install debugpy
```

and then append the following lines to the Helix configuration file:

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

Now you should have a fully configured Helix for Python development, with `ruff` as the code formatter and `ty` as the type checker.

Enjoy!
