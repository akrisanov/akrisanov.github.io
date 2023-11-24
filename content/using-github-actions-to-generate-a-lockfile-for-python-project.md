+++
title = "Generating A Lockfile For Python Project Using Github Actions"
description = "Using Github Actions and pip-tools to compile a requirements.txt file from your dependencies."
date = 2023-10-12
draft = false

[taxonomies]
tags = ["python", "github-actions"]

[extra]
keywords = "python, github-actions, lockfile"
toc = false
+++

If you're working on a project that needs to be packaged for a specific environment other than your
machine, the CI/CD server is your best friend. Products like Github Actions can save you time and
the hassle of building dependencies you won't use in development.

For example, many developers love Mac computers, especially the ones that come with Apple silicon.
The sad truth is that we rarely deploy our code on servers with these processors and MacOS.
Most of the time, projects run on Linux. Unfortunately, Python can't guarantee a deterministic
or reproducible environment.

Running the command to create a list of all the dependencies that your package will need gives
a different result on MacOS, Linux, Windows, and so on:

```bash
pip-compile --allow-unsafe --generate-hashes --no-emit-index-url --output-file=requirements-lock.txt > requirements-lock.txt
```

<span class="img-title">Using pip-tools to compile a requirements.txt file from your dependencies</span>

Not all dependencies have universal wheels. Moreover, users can install different Python versions.

Now that you see the problem, let's take a quick look at possible solutions.

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
          pip-compile --allow-unsafe --generate-hashes --no-emit-index-url --output-file=requirements-lock.txt > requirements-lock.txt
      - name: Upload requirements-lock artifact
        uses: actions/upload-artifact@v3.1.1
        with:
          name: requirements-lock
          path: requirements-lock.txt
          retention-days: 3
```

<span class="img-title">build-requirements-lock-workflow</span>

The Github Actions manifest above defines a workflow that can be triggered manually
on any branch you like.

Suppose you're upgrading some dependencies in requirement.txt. `pip install -r requirements.txt`
works fine. Now you want to generate a new lock file for the users. You commit the changes to your
branch, wait for the tests to pass, and trigger the workflow:

![](/images/gh-actions-lockfile.png)
<span class="img-title">Github Actions Workflow</span>

A freshly generated requirements-lock.txt appears in downloadable artifacts.
You download the file and add it to the repo.

Another option might be to run a similar workflow in a Docker container. I posted a note about
multi-architecture builds a few months ago. [Take a look!](https://dev.to/akrisanov/building-multi-arch-images-for-arm-and-x86-2802)
Just make sure you choose the same architecture and Python version that you want to distribute your project to.

<div class="callout callout-bdc">
Other tools like Poetry might do the job better and provide more convenient ways of managing lock files.
But if you have reasons to not use them, it's totally fine to stick with good old pip.
</div>
