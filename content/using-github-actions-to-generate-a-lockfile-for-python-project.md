+++
title = "Generate a Python Lockfile with GitHub Actions"
description = "Generate a Python requirements lockfile with pip-tools on the same operating system and Python version used for deployment."
date = 2023-10-12
draft = false

[taxonomies]
tags = ["python", "github-actions", "dependency-management", "pip-tools"]

[extra]
keywords = "python, github-actions, dependency-management, pip-tools"
toc = false
static_thumbnail = "/images/social-using-github-actions-to-generate-a-lockfile-for-python-project.png"

+++

When development and deployment use different operating systems or processor architectures, generate the Python
lockfile in the deployment environment. GitHub Actions can run this step without requiring the same environment on
the developer's machine.

I develop on macOS with Apple silicon, while most of my projects run on Linux. Resolved dependencies can differ
between these environments because not every package provides wheels for every platform. The Python version can
also affect the result.

For example, `pip-compile` can produce different lockfiles on macOS, Linux, and Windows:

```bash
pip-compile --allow-unsafe --generate-hashes --no-emit-index-url --output-file=requirements-lock.txt
```

<p class="media-caption code-caption">Using pip-tools to compile a requirements lockfile</p>

<!-- more -->

The following workflow generates `requirements-lock.txt` on Ubuntu with Python 3.9:

```yaml
name: Build requirements-lock.txt

on:
  workflow_dispatch:

jobs:
  build-requirements-lock:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python 3.9
        uses: actions/setup-python@v3
        with:
          python-version: "3.9"
      - name: Install pip and pip-tools
        run: |
          pip install --upgrade pip
          pip install --upgrade pip-tools
      - name: Run pip-compile
        run: |
          pip-compile --allow-unsafe --generate-hashes --no-emit-index-url --output-file=requirements-lock.txt
      - name: Upload requirements-lock artifact
        uses: actions/upload-artifact@v3.1.1
        with:
          name: requirements-lock
          path: requirements-lock.txt
          retention-days: 3
```

<p class="media-caption code-caption">The <code>build-requirements-lock</code> workflow</p>

The `workflow_dispatch` event makes the workflow manually available for a selected branch.

After updating the project's dependencies, commit the changes, wait for the tests to pass, and trigger the workflow:

<figure class="article-figure">
  <img
    src="/images/gh-actions-lockfile.webp"
    alt="GitHub Actions page showing a successful lockfile workflow run"
    width="2992"
    height="1318"
    loading="lazy"
    decoding="async"
  />
  <figcaption class="media-caption">GitHub Actions workflow</figcaption>
</figure>

The completed run provides `requirements-lock.txt` as a downloadable artifact. Download the file and commit it to
the repository.

You can also generate the lockfile in a Docker container. Use the same operating system, architecture, and Python
version as the deployment target. See [Building Multi-Arch Images for Arm and x86](/multi-arch-docker-images/).

<aside class="callout callout-bdc" aria-label="Alternative dependency tools">
  <p>
    Tools such as Poetry provide their own lockfile workflows. This GitHub Actions approach is useful for projects
    that use pip and pip-tools.
  </p>
</aside>
