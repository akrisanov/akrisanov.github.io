+++
title = "Why vLLM Scales: Paging the KV-Cache for Faster LLM Inference"
description = "Why traditional LLM serving wastes GPU memory – and how vLLM’s PagedAttention model enables larger batches, higher throughput, and more predictable latency."
date = 2026-01-27
draft = false

[taxonomies]
tags = ["vllm", "llm", "inference"]

[extra]
keywords = "vLLM, LLM, inference, serving, AI, backend, infrastructure"
+++

If you’ve ever tried to serve large language models at scale, you’ve probably hit the same wall:
VRAM runs out much earlier than expected, batching stops scaling, and latency becomes unpredictable.

[vLLM](https://vllm.ai/) exists almost entirely to fix this.

At its core, vLLM is a high-performance LLM inference engine that dramatically improves GPU utilization.
The key idea behind it is [PagedAttention](https://arxiv.org/abs/2309.06180) – a different way to manage
the KV-cache that removes most of the memory waste common in traditional LLM serving stacks.

Let’s break down why this is such a big deal.

## The Core Problem: KV-Cache Fragmentation

In traditional LLM serving systems, the KV-cache (the keys and values representing token context)
must live in a single contiguous block of GPU memory.

There’s a catch: you don’t know in advance how long the model’s answer will be.

So the system plays it safe and reserves memory for the maximum context length – say,
2048 or 4096 tokens – for every request.

The result?

- Large chunks of VRAM are reserved but never used
- Memory becomes fragmented
- Up to 60–80% of KV-cache memory is effectively wasted

That wasted VRAM could have been used to serve more requests in parallel.

## PagedAttention: Borrowing an Idea from Operating Systems

PagedAttention takes inspiration from virtual memory and paging in operating systems.

Instead of allocating one big contiguous block per request, it does this:

1. **Split KV-cache into fixed-size blocks.** Each request’s KV-cache is divided into blocks (for example, 16 or 32 tokens per block).
2. **No need for physical continuity.** These blocks can live anywhere in VRAM – they don’t have to be next to each other.
3. **Virtual addressing with a Block Table.** vLLM keeps a mapping from logical token order to physical memory blocks on the GPU.
4. **Allocate memory only when needed.** New blocks are allocated only when new tokens are generated – no upfront over-reservation.

This single change unlocks most of vLLM’s performance gains.

## Key Effects of Paged KV-cache

### Almost no external fragmentation

Because blocks don’t need to be contiguous, free memory can be reused efficiently instead of becoming unusable holes.

### Minimal internal fragmentation

Only the last block of a sequence may be partially empty. With reasonable block sizes, memory loss is typically below 4%.

### Much larger batch sizes

Better memory efficiency means more concurrent requests per GPU, which is the main driver of performance on modern GPUs.

### Massive throughput gains

In practice, this enables:

- 2–4× throughput vs. TGI
- Up to ~24× vs. naïve Hugging Face serving setups

### True continuous batching

New requests can be added as soon as finished ones free blocks – no need to wait for a full batch boundary.

### Memory sharing (prefix / prompt caching)

Multiple requests can point to the same physical blocks for shared prefixes (system prompts, long examples).

### Copy-on-write when sequences diverge

If you generate multiple completions from the same prompt, new blocks are allocated only when outputs differ.
This can save up to ~55% of KV-cache memory.

### Better TTFT under load (indirectly)

PagedAttention doesn’t speed up the first token itself, but higher throughput clears queues faster –
reducing queue time, which users perceive as better TTFT.

### Graceful preemption and swapping

If VRAM runs low, individual blocks can be swapped to CPU memory instead of crashing the server with OOM.

### No recomputation

Unlike approaches that drop KV-cache under pressure, PagedAttention preserves progress and resumes generation
without re-processing the prompt.

## Block Size: A Subtle but Important Knob

Block size affects:

- Internal fragmentation
- Metadata and indexing overhead
- Eviction and preemption behavior (if used)

Smaller blocks = better memory efficiency, higher overhead.

Larger blocks = lower overhead, more wasted tail space.

There’s no universal best value – it depends on workload shape.

## A Note About Prefill vs Decode

It’s important to separate these phases:

### Prefill

- Often compute- or memory-bound
- Cost grows with input sequence length

### Decode

- Usually memory-bandwidth-bound
- Heavily dependent on KV-cache efficiency and batching
- TTFT (Time to First Token) = queue time + prefill latency

PagedAttention mainly improves decode throughput.

So if you see this pattern:

- tokens/sec ↑
- p99 TTFT unchanged (or worse)

You optimized decode, but you’re still bottlenecked on queueing or prefill.

## Why vLLM Became the Default Choice

vLLM didn’t win because of a single micro-optimization.
It won because PagedAttention fundamentally changes how GPU memory is used for LLM serving.

If you care about:

- high throughput
- stable latency under load
- efficient use of expensive GPUs

then understanding vLLM is no longer optional – it’s baseline knowledge for modern LLM infrastructure.
