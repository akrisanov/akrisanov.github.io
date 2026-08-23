+++
title = "Hidden Costs of LiteLLM's Health Checks"
description = "How LiteLLM model health checks generated unexpected external-model spend, and how we kept checks for local models only."
date = 2026-08-15
draft = false

[taxonomies]
tags = ["litellm", "llm-inference", "ai-infrastructure", "observability", "cost-optimization", "kubernetes"]

[extra]
selected = true
keywords = "litellm health checks, litellm proxy, llm gateway, background health checks, health check routing, kubernetes probes, llm cost optimization"
toc = true

+++

We run LiteLLM as an internal gateway in front of two kinds of models: local vLLM deployments and paid external
models. At the time of the incident, the proxy was running LiteLLM 1.82.x with four replicas, Redis for shared state,
and background model health checks enabled.

The relevant part of the configuration looked like this:

```yaml
general_settings:
  background_health_checks: true
  use_shared_health_check: true
  health_check_interval: 30
  health_check_concurrency: 4
```

The problem showed up in the external provider's usage view. Over roughly one to two weeks, a key reserved for
LiteLLM health checks accumulated 63,011 successful requests, 9.0 million tokens, and $372.59 in spend. One
deep-research model accounted for $295.40. Similar spend appeared in other environments, so this was not a one-off
request or a single-model anomaly.

## What was not causing the spend

Our Kubernetes probes were configured like this:

```yaml
startupProbe:
  httpGet:
    path: /health/liveliness
    port: 4000

livenessProbe:
  httpGet:
    path: /health/liveliness
    port: 4000

readinessProbe:
  httpGet:
    path: /health/readiness
    port: 4000
```

These probes were not generating model traffic. LiteLLM documents `/health/liveliness` and `/health/readiness` as
lightweight proxy probes that do not make LLM calls. Liveness only checks that the process is up.
Readiness checks whether the worker can accept traffic and, when a database is configured,
returns 503 if the database is unreachable.

We also had `use_shared_health_check: true`. With Redis coordination working, LiteLLM uses a distributed lock and
cached results so that multiple proxy pods do not all perform the same model checks independently.

The paid traffic came from LiteLLM's **model** health checks. In our configuration, background checks were enabled
for both local and external deployments.

## Root cause

A LiteLLM model health check is a real model request, not just an HTTP connectivity check.

For a deployment with `model_info.mode: chat`, LiteLLM tests the `/chat/completions` path. In LiteLLM
v1.82.0, a non-wildcard route defaulted to one output token unless `health_check_max_tokens` was set
explicitly. In LiteLLM 1.96.2, the default is 16, with additional model-specific and global overrides. In both
versions, the provider processes the prompt and generated tokens, so a paid upstream can charge for the request
according to the selected model's pricing. The one-output-token limit in v1.82.0 did not bound other billable
work performed by a research model, which explains how these small probes could still accumulate substantial usage.

The exact request volume needs one qualification. `health_check_interval` controls how often the background loop runs,
but with shared health checks enabled it is not necessarily the same as the upstream model-call interval.

Both the incident-era and current implementations cache shared health-check results in Redis. The default shared-cache
TTL is 300 seconds, so a background loop running every 30 seconds can reuse a cached result instead of calling every
model on every iteration. The effective upstream request rate therefore depends on both the loop interval and whether
shared coordination is actually working.

The incident-era implementation in LiteLLM v1.82.0 had another important detail. If a pod could not acquire
the shared Redis lock, it waited only two seconds for the lock holder to publish cached results. If no cache was
available after that wait, the pod fell back to running the model health checks locally. Redis could therefore be
available and the shared-health-check feature enabled, yet slow health-check cycles could still cause several proxy
pods to issue overlapping paid probes.

We did not have enough evidence to prove that this fallback path accounted for every one of the 63,011 requests,
but it is a plausible contributor in a multi-pod deployment and makes `use_shared_health_check: true` insufficient
as the only cost-control measure.

LiteLLM has since changed this logic. In the current implementation, a pod that misses the lock polls for cached
results for up to the lock TTL instead of falling back after a fixed two-second wait. This is one reason the article
distinguishes the v1.82.x incident from the current configuration.

Without shared caching, a 30-second model-check interval would be roughly:

```text
2 checks/minute x 60 minutes x 24 hours = 2,880 checks/day
2,880 x 30 days ≈ 86,400 checks/month per deployment
```

That is an upper-bound calculation for a setup that effectively executes every scheduled probe upstream. It is not the
expected request count when shared health-check caching is working correctly.

`health_check_concurrency: 4` does not lower the number of model checks.
It only bounds how many health-check requests LiteLLM runs concurrently.

This is the distinction that matters:

| Mechanism                  | Purpose                                         | Calls a model |
| -------------------------- | ----------------------------------------------- | ------------- |
| `/health/liveliness`       | Proxy liveness                                  | No            |
| `/health/readiness`        | Proxy readiness and configured DB reachability  | No            |
| LiteLLM model health check | Test a deployment and update model health state | Yes           |

{% <key_point> %}
A LiteLLM model health check is inference traffic.
For a paid upstream API, health-check policy is also a cost-control decision.
{% </key_point> %}

## What we changed

We still wanted proactive checks for local models. Those deployments are part of the infrastructure we operate, and
LiteLLM can use their health state to avoid routing new requests to an unhealthy deployment. For paid external models,
the same probe policy had a direct dollar cost and much less operational value in our setup.

Current LiteLLM uses global enablement with per-deployment opt-out. The equivalent configuration in LiteLLM 1.96.2
keeps background checks enabled:

```yaml
general_settings:
  background_health_checks: true
  use_shared_health_check: true

  health_check_interval: 30
  health_check_staleness_threshold: 90
  health_check_concurrency: 4
  enable_health_check_routing: true
  health_check_ignore_transient_errors: true

  health_check_skip_disabled_background_models: true
```

Local deployments remain eligible for background checks by default:

```yaml
model_list:
  - model_name: internal-model
    litellm_params:
      model: hosted_vllm/internal-model
      api_base: http://internal-vllm:8000/v1
    model_info:
      mode: chat
```

For paid external deployments, we set `disable_background_health_check` in `model_info`:

```yaml
model_list:
  - model_name: external-model
    litellm_params:
      model: "<provider>/<model>"
      api_key: os.environ/EXTERNAL_PROVIDER_API_KEY
    model_info:
      mode: chat
      disable_background_health_check: true
```

`disable_background_health_check: true` excludes that deployment from the background loop.
The default is `false`, so local deployments do not need an explicit enable flag.

`health_check_skip_disabled_background_models: true` extends the opt-out to on-demand `/health` and shared health checks.
Without it, a deployment excluded from the background loop can still be probed by an on-demand model health check.
This setting is part of the current configuration and was not available in LiteLLM v1.82.0-stable.

This flag only controls health-check participation; it does not disable the deployment for normal user traffic.

## What I would configure from the start

For an in-house setup that mixes self-hosted and paid models:

- Use `/health/liveliness` and `/health/readiness` for Kubernetes probes.
- Keep model health checks for deployments where proactive routing state is useful and the probe cost is acceptable.
- Opt paid external deployments out of background checks unless continuous active probing is a deliberate requirement.
- If an external provider needs synthetic monitoring, run it at a deliberate interval with an explicit cost budget.
- Use shared health checks for a multi-pod LiteLLM deployment, but do not rely on them as the only cost-control measure.
  Monitor Redis coordination and understand the fallback behavior of the LiteLLM version you run.
- Check both `health_check_interval` and `DEFAULT_SHARED_HEALTH_CHECK_TTL` when estimating probe frequency.
  They control different parts of the mechanism.
- Measure actual provider-side health-check traffic instead of deriving spend from the interval alone. The provider's
  usage view was what exposed this incident.

For shared checks, LiteLLM exposes:

```text
GET /health/shared-status
```

It reports Redis availability, lock state, cache age, and the pod that produced the cached result.
This is useful for verifying that cross-pod coordination is actually working.

{% <scope_note as_of="August 15, 2026" datetime="2026-08-15"> %}
The incident occurred on LiteLLM 1.82.x. The present-day behavior and configuration in this article were verified
against LiteLLM 1.96.2 as of August 15, 2026. Health-check behavior has changed over time, so verify it against the
version you deploy.
{% </scope_note> %}

## Sources and further reading

{% <further_reading> %}

- [LiteLLM: Health Checks](https://docs.litellm.ai/docs/proxy/health)
  <span class="further-reading-description">Proxy and model health-check endpoints, configuration, and behavior.</span>
- [LiteLLM: Shared Health Check State Across Pods](https://docs.litellm.ai/docs/proxy/shared_health_check)
  <span class="further-reading-description">Redis-backed coordination and caching for multi-pod deployments.</span>
- [LiteLLM: Health Check Driven Routing](https://docs.litellm.ai/docs/proxy/health_check_routing)
  <span class="further-reading-description">How health-check results affect deployment routing.</span>
- [LiteLLM 1.82.0 source: `proxy/health_check.py`](https://github.com/BerriAI/litellm/blob/v1.82.0-stable/litellm/proxy/health_check.py)
  <span class="further-reading-description">The incident-era health-check request and one-token default.</span>
- [LiteLLM 1.82.0 source: `shared_health_check_manager.py`](https://github.com/BerriAI/litellm/blob/v1.82.0-stable/litellm/proxy/health_check_utils/shared_health_check_manager.py)
  <span class="further-reading-description">The incident-era shared locks, cached results, and two-second fallback to local checks.</span>
- [LiteLLM 1.96.2 source: `proxy/health_check.py`](https://github.com/BerriAI/litellm/blob/v1.96.2/litellm/proxy/health_check.py)
  <span class="further-reading-description">The current health-check request, token defaults, and model opt-out filtering.</span>
- [LiteLLM 1.96.2 source: `shared_health_check_manager.py`](https://github.com/BerriAI/litellm/blob/v1.96.2/litellm/proxy/health_check_utils/shared_health_check_manager.py)
  <span class="further-reading-description">The current lock-TTL polling and fallback behavior.</span>
{% </further_reading> %}
