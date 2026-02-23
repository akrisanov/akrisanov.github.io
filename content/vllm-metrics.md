+++
title = "vLLM Metrics in Production"
description = "A hands-on guide to vLLM monitoring: the key Prometheus metrics (TTFT, TPOT, queueing, KV cache, swapping), Grafana panels, and alert rules that help you debug latency and plan capacity."
date = 2026-01-28
draft = false

[taxonomies]
tags = ["vllm", "llm", "inference", "metrics", "performance", "monitoring"]

[extra]
keywords = "vLLM metrics, vLLM monitoring, Prometheus, Grafana, TTFT, time to first token, TPOT, time per output token, KV cache, swapping, LLM latency, LLM throughput, inference performance, capacity planning"
toc = true
+++

## Why this cheat sheet exists

If you operate vLLM in production, you already know the feeling: the model is "up", GPUs look busy,
but users complain that the chat is sluggish. Someone suggests "add more GPUs", someone else says
"the prompts got longer", and the discussion goes in circles.

The fastest way to stop guessing is to watch a small set of vLLM metrics and interpret them consistently.

This post is a practical playbook for software and AI engineers:

- what each metric *really* tells you
- how to query it in Prometheus
- what actions typically fix the problem

It's intentionally opinionated and optimized for on-call reality.

## How vLLM metrics are named

vLLM exports Prometheus metrics with the `vllm:` prefix. When Prometheus scrapes them, the colon becomes an underscore.

- `vllm:num_requests_running` becomes `vllm_num_requests_running`

Also pay attention to **metric types**, because they decide how you query:

- **Latency** metrics are **histograms** (`*_seconds_bucket`). You compute percentiles with `histogram_quantile()`.
- **Throughput** metrics are **counters** (`*_total`). You compute rates with `rate()`.
- **State / saturation** metrics are **gauges**. You graph them directly and alert on thresholds.

One more thing: vLLM shows you what happens **inside the inference engine**. For end-to-end production visibility,
you still need gateway metrics (HTTP status codes, upstream latency, timeouts) and infrastructure metrics
(GPU clocks/thermals/memory).

## The two latency numbers that define user experience

In practice, you can reduce "LLM feels slow" to two metrics:

**TTFT (Time To First Token)** — how quickly the user sees *anything*

- Metric: `vllm:time_to_first_token_seconds`
- Includes queueing + prefill
- This is the metric that makes chat feel "snappy" or "dead"

**TPOT (Time Per Output Token)** — how fast text streams once it starts

- Metric: `vllm:time_per_output_token_seconds`
- Mostly decode phase
- This is what users perceive as "typing speed"

There are also two supporting latency metrics that help you pinpoint the cause:

- **Queue Time**: `vllm:request_queue_time_seconds`
- **E2E latency**: `vllm:e2e_request_latency_seconds`

### PromQL: the percentile queries you'll actually use

### P95 TTFT

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(vllm_time_to_first_token_seconds_bucket[5m]))
)
```

### P99 TPOT

```promql
histogram_quantile(
  0.99,
  sum by (le) (rate(vllm_time_per_output_token_seconds_bucket[5m]))
)
```

### P95 Queue Time

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(vllm_request_queue_time_seconds_bucket[5m]))
)
```

> vLLM reports latencies in **seconds**. If your brain works in milliseconds, just set the Grafana panel unit to `Time → milliseconds (ms)`.

### The interpretation shortcut

This is the fastest diagnostic rule I know:

- **Queue Time grows, TPOT stays stable** → you're short on *capacity* (not enough vLLM replicas / GPU capacity)
- **TPOT grows** → generation slowed down (often long contexts, GPU contention, throttling, or overly aggressive concurrency)

Keep that in your head. It prevents most "random tuning".

## Throughput: are we doing useful work?

Latency tells you what users feel. Throughput tells you whether your system is doing real work.

vLLM exposes token counters:

- Prompt (input) tokens: `vllm:prompt_tokens_total`
- Generated (output) tokens: `vllm:generation_tokens_total`

### PromQL

### Input tokens per second

```promql
sum(rate(vllm_prompt_tokens_total[5m]))
```

### Output tokens per second

```promql
sum(rate(vllm_generation_tokens_total[5m]))
```

If output tokens/s drops while traffic stays similar, you're usually looking at **cache pressure**,
**swapping**, or **too much concurrency**.

## Saturation & concurrency: how close are we to the cliff?

When a system degrades, it rarely does it politely. For vLLM, the "cliff" is typically KV cache pressure and swapping.

### Request state (scheduler pressure)

- **Running**: `vllm:num_requests_running` — requests actively executing on GPU
- **Waiting**: `vllm:num_requests_waiting` — queue size; if it's consistently > 0, you're operating at/above capacity
- **Swapped**: `vllm:num_requests_swapped` — requests evicted to CPU RAM (this is bad)

If you only alert on one gauge, make it this:

> **Any swapped requests (`num_requests_swapped > 0`) should be treated as a production incident.**

### KV cache pressure (the silent killer)

- **GPU cache usage**: `vllm:gpu_cache_usage_perc` (0.0–1.0)
  - Under sustained load, a stable zone is often **0.7–0.9**
  - If it sits at **1.0**, swapping becomes likely
- **CPU cache usage**: `vllm:cpu_cache_usage_perc`

The reason this matters: once swapping starts, you'll see brutal latency spikes because you're moving blocks between GPU and CPU.

## Errors: why requests finish (and what "abort" usually means)

vLLM tracks why requests stop via:

- `vllm:finished_request_total{finish_reason="..."}`

Common reasons:

- `stop` — normal completion (EOS)
- `length` — hit `max_tokens`
- `abort` — cancelled by user or failed due to an error

### PromQL: breakdown by finish reason

```promql
sum by (finish_reason) (rate(vllm_finished_request_total[5m]))
```

What I've seen in production:

- Spikes in `length` often mean your `max_tokens` default is too low for a real workload
- Spikes in `abort` often correlate with gateway timeouts, client disconnects, or engine-level failures

## The "golden signals" dashboard for vLLM

If you want one dashboard that's worth opening during an incident, build it around these signals:

1. **P95 TTFT** — responsiveness
2. **P99 TPOT** — generation speed stability
3. **Queue size** (`num_requests_waiting`) — capacity pressure
4. **Swapped requests** — must be zero
5. **GPU KV cache usage** — predictive saturation
6. **Token throughput** — real work (input/output tokens per second)

### A practical Grafana dashboard JSON

You can import this as a starting point:

```json
{
  "dashboard": {
    "id": null,
    "title": "vLLM Production Golden Signals",
    "tags": ["vllm", "llm", "inference"],
    "timezone": "browser",
    "schemaVersion": 38,
    "panels": [
      {
        "title": "System Saturation (GPU Cache & Swapping)",
        "type": "gauge",
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
        "targets": [
          { "expr": "vllm_gpu_cache_usage_perc * 100", "legendFormat": "GPU Cache Fill %" }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0, "max": 100, "unit": "percent",
            "thresholds": {
              "mode": "absolute",
              "steps": [
                { "color": "green", "value": null },
                { "color": "orange", "value": 80 },
                { "color": "red", "value": 95 }
              ]
            }
          }
        }
      },
      {
        "title": "Active & Waiting Requests",
        "type": "timeseries",
        "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 },
        "targets": [
          { "expr": "vllm_num_requests_running", "legendFormat": "Running (Concurrency)" },
          { "expr": "vllm_num_requests_waiting", "legendFormat": "Waiting in Queue" },
          { "expr": "vllm_num_requests_swapped", "legendFormat": "Swapped (Preemption!)" }
        ]
      },
      {
        "title": "Latency P95 (TTFT vs TPOT)",
        "type": "timeseries",
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 8 },
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum by (le) (rate(vllm_time_to_first_token_seconds_bucket[5m])))",
            "legendFormat": "P95 TTFT"
          },
          {
            "expr": "histogram_quantile(0.95, sum by (le) (rate(vllm_time_per_output_token_seconds_bucket[5m])))",
            "legendFormat": "P95 TPOT"
          }
        ],
        "fieldConfig": { "defaults": { "unit": "s" } }
      },
      {
        "title": "Token Throughput",
        "type": "timeseries",
        "gridPos": { "h": 8, "w": 12, "x": 12, "y": 8 },
        "targets": [
          { "expr": "sum(rate(vllm_generation_tokens_total[5m]))", "legendFormat": "Output Tokens/s" },
          { "expr": "sum(rate(vllm_prompt_tokens_total[5m]))", "legendFormat": "Input Tokens/s" }
        ]
      }
    ],
    "templating": {
      "list": [
        {
          "name": "datasource",
          "type": "datasource",
          "query": "prometheus",
          "refresh": 1
        }
      ]
    }
  }
}
```

## Alerts that save you before users start complaining

You don't need 30 alerts. You need 5 that are hard to ignore.

### PrometheusRule example

```yaml
groups:
- name: vLLM.Alerts
  rules:

    - alert: vLLMHighTTFT
      expr: histogram_quantile(0.95, sum by (le, instance) (rate(vllm_time_to_first_token_seconds_bucket[5m]))) > 3
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High TTFT on instance {{ $labels.instance }}"
        description: "P95 TTFT is {{ $value | printf \"%.2f\" }}s. Users see long delays before the first token."

    - alert: vLLMQueueBacklog
      expr: histogram_quantile(0.95, sum by (le, instance) (rate(vllm_request_queue_time_seconds_bucket[5m]))) > 5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Requests are queuing on {{ $labels.instance }}"
        description: "P95 Queue Time is {{ $value | printf \"%.2f\" }}s. Engine cannot keep up."

    - alert: vLLMRequestSwapping
      expr: vllm_num_requests_swapped > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "vLLM is swapping requests to CPU"
        description: "Instance {{ $labels.instance }} has {{ $value }} swapped requests. This indicates severe KV cache pressure and causes latency spikes."

    - alert: vLLMGPUCacheFull
      expr: vllm_gpu_cache_usage_perc > 0.95
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "GPU KV Cache is nearly full"
        description: "Cache usage on {{ $labels.instance }} is {{ $value | printf \"%.2f\" }} (fraction). Expect queueing or swapping soon."

    - alert: vLLMHighAbortRate
      expr: |
        sum by (instance) (rate(vllm_finished_request_total{finish_reason="abort"}[5m]))
        /
        sum by (instance) (rate(vllm_finished_request_total[5m])) > 0.1
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "High abort rate on {{ $labels.instance }}"
        description: "Abort ratio > 10% (current: {{ $value | printf \"%.2f\" }}). Investigate client timeouts and engine errors."
```

## Runbook: metrics → diagnosis → action

When an alert fires or users complain, here's a quick guide to interpret the signals and take action.

### Scenario 1: TTFT is high

#### What you see

- P95 TTFT rises
- Queue Time rises
- `num_requests_waiting` > 0

#### What it usually means

- You're under-provisioned for current RPS, *or* prompts got longer (prefill became expensive).

#### What to do

- Scale out (more vLLM replicas / GPU nodes)
- If scaling is slow: reduce concurrency temporarily to avoid swapping spirals
- Consider routing “cheap/system” prompts to a smaller model pool

### Scenario 2: TPOT is high (generation slowed)

#### What you see

- P99 TPOT rises
- Output tokens/s drops

#### What it usually means

- Longer contexts / more decode work, GPU contention, throttling, or too aggressive concurrency.

#### What to do

- Check GPU-level signals (clocks, thermals, power limits, utilization)
- Reduce concurrency limits (e.g., `max_num_seqs`) if decode becomes unstable
- Revisit prompt/output length distributions; enforce sane `max_tokens` defaults

### Scenario 3: Swapping detected

#### What you see

- `num_requests_swapped` > 0
- Latency spikes; throughput collapses

#### What it means

- KV cache doesn’t fit the current working set (too many concurrent contexts).

#### What to do (in order)

1) Reduce load or concurrency fast (stabilize the system)
2) Reduce memory pressure (often: reduce `max_num_batched_tokens`)
3) Scale out (more replicas / more GPU capacity)
4) Separate model pools and route workloads more carefully

### Scenario 4: Abort rate spikes

#### What you see

- `finish_reason="abort"` rises

#### What it usually means

- Client disconnects / gateway timeouts, or engine-level failures.

#### What to do

- Check gateway timeout configs (upstream read timeouts, streaming timeouts)
- Inspect vLLM logs for CUDA/runtime errors
- Correlate abort spikes with queue time spikes (clients often give up)

## Final checklist

- **One golden signals dashboard**: TTFT, TPOT, queue, swapped, KV cache, tokens/s
- **Gateway metrics**: HTTP codes, upstream latency, timeouts (otherwise you'll misdiagnose aborts)
- **Five alerts**: high TTFT, backlog, swapping, KV cache near full, abort ratio spike
- **A runbook**: "queue vs TPOT vs swapping" → clear actions

If you want one mental model: **queueing means you’re out of capacity; swapping means you’ve crossed the line.**
