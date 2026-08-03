+++
title = "Understand How Services Run and Operate in Production"
description = "Software engineers should understand the runtime model, resource requirements, and capacity of the services they operate."
date = 2023-09-06
draft = false

[taxonomies]
tags = ["software-engineering", "production", "devops", "platform-engineering"]

[extra]
keywords = "software-engineering, production, devops, platform-engineering"
toc = false
static_thumbnail = "/images/social-understand-how-services-are-run-and-operate-in-production.png"

+++

Over the past few years, I have interviewed dozens of software engineers who could not explain how the services they
developed ran in production. Infrastructure or platform teams often manage deployment, but that division of
responsibility does not remove the need to understand a service's runtime behavior.

<!-- more -->

A typical conversation goes like this:

<blockquote class="dialogue" aria-label="Interview transcript">
<p class="q"><strong>Interviewer:</strong> How do you ship your service to production?</p>
<p class="a"><strong>Candidate:</strong> We build Docker images and run containers.</p>

<p class="q"><strong>Interviewer:</strong> What are the resource requirements for a container?</p>
<p class="a"><strong>Candidate:</strong> I don't know the details. The DevOps team handles that.</p>

<p class="q"><strong>Interviewer:</strong> Which application server does the Python service use?</p>
<p class="a"><strong>Candidate:</strong> Application server? Do you mean WSGI?</p>

<p class="q"><strong>Interviewer:</strong> Yes, the thing that handles web requests and runs your Python code.</p>
<p class="a"><strong>Candidate:</strong> Let me check the repository. It uses Gunicorn.</p>
<p class="q"><strong>Interviewer:</strong> Can you estimate how many requests the application can handle?</p>

<p class="a"><strong>Candidate:</strong> No. We don't run load tests.</p>
<p class="q"><strong>Interviewer:</strong> Can you make a rough estimate?</p>

<p class="a"><strong>Candidate:</strong> No.</p>
<p class="q"><strong>Interviewer:</strong> What happens at the process and thread level when the application server handles a request?</p>
<p class="a"><strong>Candidate:</strong> I can't explain it.</p>
</blockquote>

Not knowing a configuration value from memory is reasonable. Being unable to explain the runtime model or how the
team measures capacity is a problem. For synchronous and asynchronous services, the chosen
[Gunicorn server model](https://docs.gunicorn.org/en/stable/design.html#server-model) affects concurrency, resource
allocation, and throughput.

Platform and SRE teams can manage the infrastructure, but engineers still need to understand the processes and
threads that execute their code, the CPU and memory those processes require, and the service's approximate capacity.
