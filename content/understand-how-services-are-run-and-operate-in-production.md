+++
title = "Understand How Services Are Run And Operate In Production"
description = "Over the past few years, I've been interviewing dozens of software engineers who didn't know how their developed services run in production."
date = 2023-09-06
draft = false

[taxonomies]
tags = ["engineering"]

[extra]
keywords = "backend, server model, job interview"
toc = false
+++

Over the past few years, I've been interviewing dozens of software engineers who didn't know how
their developed services run and operate in production. The reason for that is a rising trend in
software engineering trusting in an infrastructure team, the magic of the cloud, Docker,
Kubernetes, and whatnot.

A conversation with a talent usually looks the following:

<blockquote>
– How do you ship your service to production?

– We build Docker images and run containers.

– Sounds cool! Can you tell me about the resource requirements for a container?

– Hmm, to be honest, I don't know the details. DevOps folks take care of that.

– (discussing Python app) OK. And what application server do you use?

– Application Server? (Some people even reply: "You mean WSGI?")

– Yes, the thing that handles web requests and runs your Python code.

– Hmm, let me open a project repo and check..

– It's...Gunicorn!

– Great. Can you estimate how many requests the web application can handle?

– I don't think so because we don't do load testing.

– So, it's not possible to do even a rough estimation?

– Nope.

– OK. Do you understand what happens on a processes and threads level when the application server processes a request?
</blockquote>

This is where the conversation hits a dead end. Many talents don't. And this is a red sign to me.
It gets worse when a candidate claims they have experience with (semi)async services in production
but can't explain [a service model](https://docs.gunicorn.org/en/stable/design.html?ref=akrisanov.com#server-model)
they have chosen and how the services operate because of that (including resources allocating and consumption).

You might say: "Why do I need to know all that low-level stuff in the 2020s?".
Fair enough...if you don't develop software for thousands of users, have an unlimited budget for
underutilized hardware, don't design distributed systems, or, simply, have an SRE team ready to
solve all possible issues for you. Otherwise, please do.
