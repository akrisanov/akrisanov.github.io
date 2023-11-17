+++
title = "Building Multi-Arch Images for Arm and x86"
description = "In situations where CI is not available, building multi-arch images locally can save the day."
date = 2023-08-10
draft = false

[taxonomies]
tags = ["docker", "devops"]

[extra]
keywords = "docker, devops, arm, x86, multi-arch"
toc = false
+++

At work, I am involved in the development of a machine learning SDK and cloud services for
privacy and data protection. Like almost every company in this space, we rely heavily on
Python's scientific ecosystem. Because it's quite mature and depends on native library
development that started years ago, getting these packages to work on new architectures
can be tedious.

I am one of the few developers on our team who has stuck with MacOS and have a Macbook Pro
with M1 chip. There is no easy way for me to bootstrap our development environment in a matter
of minutes. I have to use Conda, install specific versions of Python packages, patch some native
libraries, and even create a symlink from an OS-specific package to its generic name
(I'm talking to you, Tensorflow). People on the `x86_64` architecture generally won't have
this problem – almost every package we use comes with a pre-built wheel for a chosen OS.
Moreover, to install the SDK as a dependency of, say, an HTTP API service, I had to assemble
it from sources: `pip install -e '.'`

A few months ago we didn't even support the Arm64 architecture at a build level. This changed when
I introduced a Github Action pipeline to build Python wheels for Linux `x86_64`, `aarch64`, and `universal`.
Instead of manually compiling some native libraries on my machine, I moved the work to GitHub and
its Linux instances. From that moment on, I could just get the package from a private PyPI registry.
The sad truth is that I still use Conda and sometimes patch one or two transitive dependencies for
my M1 chip. But other than that, no hard times to date.

Today I needed to distribute a newly created API service with the SDK inside as a Docker image.
And I haven't found an easy way to define a Dockerfile that can be built and run on
Apple Silicon without Conda:

```Dockerfile
FROM python:3.9-slim-buster AS base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install Conda

RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y --no-install-recommends build-essential g++ gcc libssl-dev cmake git wget
RUN rm -rf /var/lib/apt/lists/*

ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"

RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh \
    && mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-aarch64.sh -b \
    && rm -f Miniconda3-latest-Linux-aarch64.sh

# Create a Conda environment and install native dependencies

RUN --mount=type=cache,target=/root/.cache \
    conda init bash && . /root/.bashrc && \
    conda update conda && \
    conda create -n de_agent python=3.9 && \
    conda env config vars set -n de_agent LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1 && \
    conda activate de_agent && \
    conda install gdal llvmdev dm-tree -y && \
    pip install --upgrade pip setuptools wheel && \
    pip install h3

# Copy application files

WORKDIR /app

COPY app/ .
COPY logging.yaml .
COPY main.py .
COPY requirements.txt ./

# Install Python packages

ARG DE_AGENT_PYPI_TOKEN

RUN --mount=type=cache,target=/root/.cache \
    . /root/.bashrc && conda activate de_agent && \
    pip install -r requirements.txt --extra-index-url=https://${DE_AGENT_PYPI_TOKEN}:@pypi.****.ai/pypi/ && \
    pip install numpy==1.23.5

# Cleanup

RUN apt -qy purge --auto-remove build-essential g++ gcc libssl-dev cmake git wget
RUN apt autoremove && apt clean
RUN rm -rf /var/lib/apt/lists/*

# Create a user

RUN groupadd -r de_agent && useradd -r -m -g de_agent de_agent
RUN chown -R de_agent:de_agent /app

USER de_agent

# Run the web application

EXPOSE 8000

ENTRYPOINT ["PYTHONPATH=.", "python", "main.py"]
```

As you can see, the manifest is quite verbose. It also adds the Conda binaries and related
files to a release image. It is a price that must be paid.

Fortunately, for Linux, we don't need all of this machinery:

```Dockerfile
FROM python:3.9-slim-buster AS base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system packages

RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y --no-install-recommends build-essential g++ gcc libssl-dev cmake git wget
RUN rm -rf /var/lib/apt/lists/*

# Copy application files

WORKDIR /app

COPY app/ .
COPY logging.yaml .
COPY main.py .
COPY requirements.txt ./

# Install Python dependencies

ARG DE_AGENT_PYPI_TOKEN

RUN --mount=type=cache,target=/root/.cache \
    pip install -r requirements.txt --extra-index-url=https://${DE_AGENT_PYPI_TOKEN}:@pypi.****.ai/pypi/

# Cleanup

RUN apt -qy purge --auto-remove build-essential g++ gcc libssl-dev cmake git wget
RUN apt autoremove && apt clean
RUN rm -rf /var/lib/apt/lists/*

# Create a user

RUN groupadd -r de_agent && useradd -r -m -g de_agent de_agent
RUN chown -R de_agent:de_agent /app

USER de_agent

# Run the web application

EXPOSE 8000

ENTRYPOINT ["PYTHONPATH=.", "python", "main.py"]
```

The question now is how to build Docker images for both architectures on a Mac.
This is where Docker comes in. Docker Desktop officially supports [building multi-arch images
for Arm and x86](https://www.docker.com/blog/multi-arch-images/). Learning this, I was able to
add a few targets to my Makefile to quickly build images:

```Makefile
build: # Build a Docker image for x86_64
 docker buildx build --platform linux/amd64 -t de-agent:amd64-latest --build-arg DE_AGENT_PYPI_TOKEN=${DE_AGENT_PYPI_TOKEN} -f Dockerfile.amd64 --no-cache .

build-arm: # Build a Docker image for arm64
 docker  buildx build --platform linux/arm64 -t de-agent:arm64-latest --build-arg DE_AGENT_PYPI_TOKEN=${DE_AGENT_PYPI_TOKEN} -f Dockerfile.arm64 --no-cache .
```

```bash
make build
```

![Docker Image For Arm](/images/docker-arm-build.png)
<span class="img-title">Docker image built for the amd64 architecture</span>

One can say, it's so much hassle for doing all of this locally and a proper CI can solve such
a case easily. I agree – as I've mentioned, I like shifting work out of my shoulders and giving it
to some machine in the cloud. But in situations where CI is not available, creating multi-arch
images can save the day. It certainly did for me.
