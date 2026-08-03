+++
title = "Why vLLM Scales: Paging the KV-Cache for Faster LLM Inference"
description = "How vLLM improves LLM serving efficiency with PagedAttention, better KV-cache utilization, higher throughput, and steadier latency."
date = 2026-01-27
draft = false

[taxonomies]
tags = ["vllm", "llm-inference", "gpu", "performance"]

[extra]
keywords = "vllm, llm-inference, gpu, performance, ai-infrastructure"
toc = true
static_thumbnail = "/images/social-vllm.png"

+++

[vLLM](https://vllm.ai/) is an LLM inference engine designed to improve GPU utilization.
Its key mechanism is [PagedAttention](https://arxiv.org/abs/2309.06180), which manages the KV-cache
without the memory waste common in traditional LLM serving stacks. More efficient memory use supports
larger batches and steadier latency under load.

## KV-cache fragmentation

In traditional LLM serving systems, the KV-cache (the keys and values representing token context)
must live in a single contiguous block of GPU memory.

The system does not know in advance how long the model’s answer will be.

It therefore reserves memory for the maximum context length—say, 2048 or 4096 tokens—for every request.

- Large chunks of VRAM are reserved but never used
- Memory becomes fragmented
- Up to 60–80% of KV-cache memory is effectively wasted

That VRAM could instead serve more requests in parallel.

## PagedAttention

PagedAttention takes inspiration from virtual memory and paging in operating systems.

Instead of allocating one large contiguous region per request, it uses fixed-size blocks:

1. **Split the KV-cache into fixed-size blocks.** Each request’s KV-cache is divided into blocks, such as 16 or 32 tokens per block.
2. **Store blocks non-contiguously.** The blocks can reside anywhere in VRAM.
3. **Map logical to physical blocks.** A block table maps the logical token order to physical GPU memory blocks.
4. **Allocate blocks as needed.** vLLM allocates new blocks as it generates tokens instead of reserving the maximum space up front.

This block-based allocation accounts for much of vLLM’s performance improvement.

## Effects of a paged KV-cache

- **Less external fragmentation.** Because blocks do not need to be contiguous, free memory can be reused instead of becoming unusable holes.
- **Limited internal fragmentation.** Only the last block of a sequence may be partially empty. With reasonable block sizes, memory loss is typically below 4%.
- **Larger batch sizes.** Better memory efficiency allows more concurrent requests per GPU, a main driver of performance on modern GPUs.
- **Higher throughput.** In practice, this enables 2–4× throughput compared with TGI and up to about 24× compared with naïve Hugging Face serving setups.
- **Continuous batching.** New requests can be added as soon as completed requests free blocks, without waiting for a full batch boundary.
- **Prefix and prompt caching.** Multiple requests can point to the same physical blocks for shared prefixes, such as system prompts and long examples.
- **Copy-on-write.** When generating multiple completions from the same prompt, vLLM allocates new blocks only after the outputs diverge. This can save up to about 55% of KV-cache memory.
- **Lower TTFT under load.** PagedAttention does not reduce the computation required for the first token. Higher throughput can clear queues faster, reducing the queue-time component of TTFT.
- **Preemption and swapping.** If VRAM runs low, individual blocks can be swapped to CPU memory instead of causing an out-of-memory error.
- **No recomputation.** Unlike approaches that discard the KV-cache under pressure, PagedAttention preserves progress and resumes generation without processing the prompt again.

## Block size

Block size affects:

- Internal fragmentation
- Metadata and indexing overhead
- Eviction and preemption behavior (if used)

Smaller blocks improve memory efficiency but increase overhead.

Larger blocks reduce overhead but waste more space at the end of sequences.

The best value depends on the workload.

## Prefill and decode

The two phases have different bottlenecks:

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

then decode improved, but queueing or prefill remains the bottleneck.
