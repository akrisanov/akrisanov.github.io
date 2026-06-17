+++
title = "Monitoring vLLM in Production: Metrics, PromQL, Alerts, and Runbooks"
description = "A production-oriented guide to monitoring vLLM 0.23.x with Prometheus and Grafana: latency, queueing, preemption, KV-cache pressure, throughput, alerting, and incident diagnosis."
date = 2026-01-28
draft = false

[taxonomies]
tags = ["vllm", "llm", "inference", "metrics", "performance", "monitoring"]

[extra]
keywords = "vLLM metrics, vLLM monitoring, Prometheus, Grafana, TTFT, time to first token, ITL, inter-token latency, TPOT, KV cache, preemption, LLM latency, LLM throughput, inference performance, capacity planning"
toc = true
+++

> **Version scope:** This guide targets vLLM 0.23.x and its default V1 engine. Metric names and semantics change between releases, so verify the `/metrics` output of the exact version and serving configuration you run before copying queries or alerts into production.

## Why this guide exists

A vLLM server can be healthy from Kubernetes' point of view while users still experience slow or unstable responses.
The pods are running, the GPUs are busy, and the API answers health checks—but requests wait in the scheduler,
long prompts make prefill expensive, or token streaming becomes uneven.

The goal of this guide is not to list every metric exported by vLLM. It is to connect a small set of signals to
the questions engineers ask during incidents and capacity reviews:

1. Are users receiving the first token quickly enough?
2. Does token streaming remain smooth after generation starts?
3. Is the scheduler accepting work faster than the engine can process it?
4. Is KV-cache pressure causing preemption and recomputation?
5. Is the deployment doing useful work at the expected throughput?
6. Did the workload change, or did the serving system regress?

The examples use Prometheus and Grafana, but the mental model applies to other monitoring backends as well.

## Start with the observability boundary

vLLM metrics describe the inference server and engine. They do not describe the entire request path.

A production request usually crosses several layers:

```text
Client
  -> API gateway or ingress
  -> authentication, quotas, and routing
  -> vLLM API server
  -> scheduler and model executor
  -> streaming response
  -> client
```

A user-visible latency regression can originate in any of these layers. A useful monitoring stack therefore combines:

- **Gateway metrics:** incoming request rate, HTTP status codes, upstream latency, retries, timeouts, and client disconnects
- **vLLM metrics:** queueing, TTFT, inter-token latency, request latency, throughput, preemption, and KV-cache usage
- **GPU and host metrics:** utilization, memory, power, clocks, throttling, PCIe or NVLink errors, and node health

Engine metrics explain what happens inside vLLM. They cannot, by themselves, prove that the complete service is healthy.

## Metric names and Prometheus conventions

vLLM exposes Prometheus metrics on the OpenAI-compatible server's `/metrics` endpoint.

Metric names use the `vllm:` prefix:

```text
vllm:num_requests_running
vllm:time_to_first_token_seconds
vllm:prompt_tokens_total
```

Standard Prometheus preserves the colon. Some OpenTelemetry pipelines, managed monitoring products, or custom ingestion
layers may normalize metric names. Always check the names stored in your monitoring backend:

```bash
curl -s http://<vllm-host>:8000/metrics | grep '^vllm:' | head -50
```

Metric type determines how to query it:

- **Histograms** have `_bucket`, `_sum`, and `_count` series. Use `rate()` and `histogram_quantile()` to calculate latency percentiles.
- **Counters** are exposed with a `_total` suffix. Use `rate()` or `increase()`.
- **Gauges** represent current state. Query them directly or aggregate them across replicas.

The examples below group by `model_name`. Add stable labels such as `cluster`, `namespace`, or `service` where appropriate.
Avoid aggregating unrelated models into one percentile: a fast small model can hide a regression in a much larger one.

## The latency metrics that users notice

Three latency metrics cover most user-visible complaints.

### TTFT: time to first token

Metric:

```text
vllm:time_to_first_token_seconds
```

TTFT measures how long vLLM takes to produce the first output token. At the serving boundary, it includes request processing,
scheduler waiting, prefill, and the first generation step. Client-visible TTFT also includes gateway, routing, network,
and streaming overhead.

A high TTFT does not automatically mean the GPU is slow. It may indicate queueing, longer prompts, lower prefix-cache reuse,
or a slow first model-execution step.

### ITL: inter-token latency

Metric:

```text
vllm:inter_token_latency_seconds
```

ITL measures the delay between streamed output tokens. This is the most direct engine-level metric for visible pauses during streaming.

### Request-level TPOT

Metric:

```text
vllm:request_time_per_output_token_seconds
```

This metric records the average time per output token for a completed request. It is useful for comparing decode
efficiency across requests, but it can hide individual stalls. A request may have acceptable average TPOT while still
containing several poor ITL samples.

For interactive services, monitor both ITL and request-level TPOT. Use ITL for streaming smoothness and TPOT for
request-level decode efficiency.

### Supporting latency metrics

- Queue time: `vllm:request_queue_time_seconds`
- End-to-end latency inside the vLLM serving boundary: `vllm:e2e_request_latency_seconds`
- Prefill time: `vllm:request_prefill_time_seconds`
- Decode time: `vllm:request_decode_time_seconds`

## PromQL for latency percentiles

### P95 TTFT

```promql
histogram_quantile(
  0.95,
  sum by (le, model_name) (
    rate(vllm:time_to_first_token_seconds_bucket[5m])
  )
)
```

### P99 inter-token latency

```promql
histogram_quantile(
  0.99,
  sum by (le, model_name) (
    rate(vllm:inter_token_latency_seconds_bucket[5m])
  )
)
```

### P95 request-level TPOT

```promql
histogram_quantile(
  0.95,
  sum by (le, model_name) (
    rate(vllm:request_time_per_output_token_seconds_bucket[5m])
  )
)
```

### P95 queue time

```promql
histogram_quantile(
  0.95,
  sum by (le, model_name) (
    rate(vllm:request_queue_time_seconds_bucket[5m])
  )
)
```

### P95 vLLM end-to-end latency

```promql
histogram_quantile(
  0.95,
  sum by (le, model_name) (
    rate(vllm:e2e_request_latency_seconds_bucket[5m])
  )
)
```

Percentiles need enough observations. P99 over five minutes is often noisy for low-volume models.
Show request volume next to percentile panels, use a longer range when traffic is sparse, and remember that classic
Prometheus histogram quantiles are estimated from configured buckets.

## A practical interpretation matrix

No single metric identifies the cause. Use combinations of signals:

| TTFT | Queue time | ITL | Likely direction |
|------|------------|-----|------------------|
| High | High | Stable | Offered load exceeds capacity, or large prefills occupy the scheduler |
| High | Low | Stable | Prefill or the first execution step is slow; prompts may be longer or prefix-cache reuse may have fallen |
| Stable | Low | High | Decode is slow or uneven; investigate concurrency, memory bandwidth, throttling, and distributed-execution overhead |
| High | High | High | Severe saturation, preemption, infrastructure degradation, or an overloaded shared deployment |

Treat this table as triage, not proof. Confirm the hypothesis with workload-shape metrics, preemption counters, prefix-cache metrics, GPU telemetry, and request traces.

## Throughput and offered load

Latency tells you what users experience. Throughput tells you how much work the engine completes.

### Prompt tokens per second

```promql
sum by (model_name) (
  rate(vllm:prompt_tokens_total[5m])
)
```

### Generated tokens per second

```promql
sum by (model_name) (
  rate(vllm:generation_tokens_total[5m])
)
```

### Completed engine requests per second

```promql
sum by (model_name) (
  rate(vllm:request_success_total[5m])
)
```

The last query measures completed engine requests, not incoming demand. During overload, completion rate may flatten
while new requests continue to arrive. Measure true offered load at the gateway or API-server boundary.

Token throughput is meaningful only alongside workload shape. A drop in generated tokens per second may mean:

- lower request volume;
- shorter outputs;
- more prefill-heavy traffic;
- slower decode;
- scheduler contention;
- a model or configuration change.

Before calling it a serving regression, compare request rate, prompt-token rate, output-length distributions, TTFT,
ITL, queue time, and active concurrency.

## Workload shape: the missing part of many dashboards

The same model and hardware can behave very differently when prompt and output lengths change.

Useful request histograms include:

- `vllm:request_prompt_tokens`
- `vllm:request_generation_tokens`
- `vllm:request_params_max_tokens`
- `vllm:request_prefill_kv_computed_tokens`

These metrics answer questions such as:

- Did prompts become longer after a product release?
- Are users requesting much larger outputs?
- Did prefix caching reduce the amount of prefill work?
- Is a latency change explained by traffic composition rather than infrastructure?

Keep workload-shape panels near latency and throughput panels. Otherwise, engineers will repeatedly misdiagnose
legitimate workload changes as serving regressions.

## Scheduler and KV-cache pressure

The current V1 engine normally handles KV-cache pressure through preemption and recomputation. When the active working
set no longer fits cleanly, vLLM can evict request state and later recompute it. Correctness is preserved, but useful
compute is repeated and latency increases.

### Scheduler state

- `vllm:num_requests_running` — requests included in active model-execution batches
- `vllm:num_requests_waiting` — requests waiting for scheduler capacity
- `vllm:num_requests_waiting_by_reason` — waiting requests partitioned by reason
- `vllm:num_preemptions_total` — cumulative number of preemptions

A non-zero waiting gauge is not automatically an incident. Short queues are normal under bursty traffic and
continuous batching. Alert on sustained queue time, a growing backlog, or queueing that violates the service objective.

### KV-cache usage

Metric:

```text
vllm:kv_cache_usage_perc
```

This gauge represents the fraction of allocated KV-cache capacity currently in use.

High usage is not inherently bad. A healthy operating range depends on model architecture, context-length distribution,
concurrency, prefix-cache reuse, speculative decoding, and cache configuration. Do not copy a universal threshold such
as 80% or 95% without testing your own deployment.

A stronger pressure signal is the combination of:

- KV-cache usage near its normal ceiling;
- increasing queue time;
- increasing preemptions;
- worsening TTFT, ITL, or vLLM end-to-end latency.

### Preemption rate

```promql
sum by (model_name) (
  rate(vllm:num_preemptions_total[5m])
)
```

An occasional preemption during a short burst may not justify an incident. The meaningful condition is sustained
preemption above a tested baseline, especially when latency or queueing also degrades.

### Prefix-cache effectiveness

When automatic prefix caching is enabled, calculate the hit ratio from its counters:

```promql
sum by (model_name) (
  rate(vllm:prefix_cache_hits_total[5m])
)
/
clamp_min(
  sum by (model_name) (
    rate(vllm:prefix_cache_queries_total[5m])
  ),
  1
)
```

Interpret this together with workload composition. A low ratio may be expected for diverse prompts.
A sudden drop for a stable workload may explain increased prefill cost and TTFT.

## Request completion and failures

vLLM exposes a counter of completed engine requests partitioned by the `finished_reason` label:

```text
vllm:request_success_total{finished_reason="..."}
```

### Completed requests by reason

```promql
sum by (model_name, finished_reason) (
  rate(vllm:request_success_total[5m])
)
```

Despite its name, this metric is not a complete service-level success-rate metric. Requests can fail before they reach
the engine because of authentication, quota enforcement, malformed input, routing failures, gateway timeouts,
or connection errors. Client disconnects and cancellations may also be represented differently depending on
the serving path and version.

Use `request_success_total` as an engine-completion signal. Measure service availability and error rate at the HTTP boundary.

## The production dashboard

A useful incident dashboard should answer four questions: what users experience, whether work is queueing,
whether the engine is under memory pressure, and whether the workload changed.

Include at least:

1. Incoming request rate and HTTP error rate at the gateway or API server
2. P95 and P99 TTFT
3. P95 and P99 ITL
4. P95 request-level TPOT
5. P95 vLLM end-to-end latency
6. P95 queue time and current waiting requests
7. Preemption rate and KV-cache usage
8. Prompt and generation token throughput
9. Prompt-length and output-length distributions
10. Prefix-cache hit ratio when prefix caching is enabled
11. GPU utilization, memory, power, clocks, throttling, and hardware errors

vLLM ships reference Grafana and Perses dashboards. Use them as a baseline, then add your deployment labels,
gateway metrics, SLO panels, and links to pod-level GPU telemetry.

## Alerts that reflect user impact

Alert thresholds should come from SLOs and representative load tests, not generic constants copied from another deployment.

The following rules demonstrate useful alert shapes. Replace example thresholds and selectors with values derived from your service.

```yaml
groups:
  - name: vllm-serving
    rules:
      - alert: VLLMHighTTFT
        expr: |
          histogram_quantile(
            0.95,
            sum by (le, cluster, model_name) (
              rate(vllm:time_to_first_token_seconds_bucket[5m])
            )
          ) > 3
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "vLLM TTFT is above the service objective"
          description: "P95 TTFT for {{ $labels.model_name }} is {{ $value | printf \"%.2f\" }} seconds."

      - alert: VLLMQueueTimeHigh
        expr: |
          histogram_quantile(
            0.95,
            sum by (le, cluster, model_name) (
              rate(vllm:request_queue_time_seconds_bucket[5m])
            )
          ) > 2
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "vLLM requests are spending too long in the scheduler queue"
          description: "P95 queue time for {{ $labels.model_name }} is {{ $value | printf \"%.2f\" }} seconds."

      - alert: VLLMPreemptionRelatedDegradation
        expr: |
          sum by (cluster, model_name) (
            increase(vllm:num_preemptions_total[10m])
          ) > 0
          and
          histogram_quantile(
            0.95,
            sum by (le, cluster, model_name) (
              rate(vllm:time_to_first_token_seconds_bucket[5m])
            )
          ) > 3
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "vLLM preemptions correlate with degraded TTFT"
          description: "Requests are being recomputed while TTFT is above the service objective."
```

The preemption expression is intentionally correlated with latency and aggregated to the same
`cluster` and `model_name` labels as TTFT. Page on user impact, not on an isolated internal event.

In a mature SRE setup, prefer multi-window burn-rate alerts for availability and latency SLOs.
Raw percentile alerts are easier to explain in a compact guide, but they should not replace a complete SLO strategy.

## Runbook: metrics to diagnosis

### Scenario 1: TTFT rises and queue time rises

#### What you see

- P95 TTFT increases
- P95 queue time increases
- `vllm:num_requests_waiting` remains above its normal baseline

#### Likely causes

- offered load exceeds serving capacity;
- prompt lengths increased;
- large prefills occupy scheduler capacity;
- traffic is distributed unevenly across replicas.

#### What to do

1. Compare incoming request rate and prompt-length distributions with the previous healthy period.
2. Check whether all replicas receive comparable traffic and remain healthy.
3. Confirm whether the bottleneck is prefill, decode, or queueing.
4. Apply admission control or shed non-critical load if latency is unstable.
5. Scale out only after confirming that additional replicas address the actual bottleneck.

### Scenario 2: ITL rises while queue time remains low

#### What you see

- P95 or P99 ITL increases
- queue time remains close to normal
- generated tokens per second may fall

#### Likely causes

- excessive active concurrency;
- GPU memory-bandwidth pressure;
- GPU clock or power throttling;
- distributed-execution or communication overhead;
- a model, kernel, or runtime change.

#### What to do

1. Check GPU clocks, power, temperature, utilization, and hardware-error metrics.
2. Compare the model and vLLM configuration with the last healthy release.
3. Run a representative load test before changing `max_num_seqs` or `max_num_batched_tokens`.
4. Remember that lower concurrency may improve ITL while reducing aggregate throughput or increasing queue time.

### Scenario 3: Preemptions increase

#### What you see

- `rate(vllm:num_preemptions_total[5m])` becomes elevated
- KV-cache usage is near its normal ceiling
- queue time, TTFT, ITL, or end-to-end latency worsens

#### What it means

The active KV-cache working set does not fit cleanly. vLLM evicts request state and recomputes it later,
which wastes compute and increases latency.

#### What to do

1. Stabilize admitted load before tuning the engine.
2. Check whether prompt lengths, output limits, or concurrency changed.
3. Reproduce the workload in a controlled load test.
4. Test `max_num_seqs` and `max_num_batched_tokens` as trade-offs, not one-directional fixes.
5. Increase `gpu_memory_utilization` only after validating startup and peak-load memory behavior.
   Leave headroom for CUDA graphs, communication buffers, runtime workspaces, and model-specific allocation spikes.
6. Add replicas or GPU capacity if the working set is legitimate and sustained.

### Scenario 4: HTTP errors or client cancellations rise

#### What you see

- gateway or API-server 4xx/5xx rates increase;
- upstream timeouts or client disconnects increase;
- vLLM engine completion rate may fall or remain flat.

#### Likely causes

- authentication or quota failures;
- gateway timeout configuration;
- malformed or unsupported requests;
- overloaded routing or admission layers;
- clients giving up while requests wait;
- engine or CUDA failures.

#### What to do

1. Start at the HTTP boundary: status codes, timeout reasons, and upstream latency.
2. Correlate failures with vLLM queue time and TTFT.
3. Inspect vLLM and GPU logs for runtime or hardware errors.
4. Do not infer the service error rate from `request_success_total` alone.

## Final checklist

- **User experience:** TTFT, ITL, request-level TPOT, and end-to-end latency
- **Offered load:** incoming HTTP requests, status codes, and timeouts
- **Scheduler pressure:** queue time, waiting requests, and active requests
- **Memory pressure:** KV-cache usage and preemptions
- **Useful work:** prompt and generation tokens per second
- **Workload shape:** prompt lengths, output lengths, and requested limits
- **Infrastructure:** GPU, host, network, and distributed-execution telemetry
- **Operations:** tested thresholds, SLO-based alerts, and an incident runbook

The core mental model is simple: **request-level latency tells you what users experience; scheduler, cache,
workload-shape, and infrastructure metrics explain why.**

## References

- [vLLM production metrics](https://docs.vllm.ai/en/v0.23.0/usage/metrics/)
- [vLLM metrics design](https://docs.vllm.ai/en/v0.23.0/design/metrics/)
- [vLLM monitoring dashboards](https://github.com/vllm-project/vllm/tree/v0.23.0/examples/observability/dashboards)
- [Prometheus metric and label naming](https://prometheus.io/docs/concepts/data_model/)
