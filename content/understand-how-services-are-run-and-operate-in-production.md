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

<blockquote class="dialogue">
<p class="q"><strong>Interviewer:</strong> How do you ship your service to production?</p>
<p class="a"><strong>Candidate:</strong> We build Docker images and run containers.</p>

<p class="q"><strong>Interviewer:</strong> Sounds cool! Can you tell me about the resource requirements for a container?</p>
<p class="a"><strong>Candidate:</strong> Hmm, to be honest, I don't know the details. DevOps folks take care of that.</p>

<p class="q"><strong>Interviewer:</strong> (discussing Python app) OK. And what application server do you use?</p>
<p class="a"><strong>Candidate:</strong> Application Server? (Some people even reply: "You mean WSGI?")</p>

<p class="q"><strong>Interviewer:</strong> Yes, the thing that handles web requests and runs your Python code.</p>
<p class="a"><strong>Candidate:</strong> Hmm, let me open a project repo and check..</p>

<p class="a"><strong>Candidate:</strong> It's...Gunicorn!</p>
<p class="q"><strong>Interviewer:</strong> Great. Can you estimate how many requests the web application can handle?</p>

<p class="a"><strong>Candidate:</strong> I don't think so because we don't do load testing.</p>
<p class="q"><strong>Interviewer:</strong> So, it's not possible to do even a rough estimation?</p>

<p class="a"><strong>Candidate:</strong> Nope.</p>
<p class="q"><strong>Interviewer:</strong> OK. Do you understand what happens on a processes and threads level when the application server processes a request?</p>
</blockquote>

This is where the conversation hits a dead end. Many talents don't. And this is a red sign to me.
It gets worse when a candidate claims they have experience with (semi)async services in production
but can't explain [a service model](https://docs.gunicorn.org/en/stable/design.html?ref=akrisanov.com#server-model)
they have chosen and how the services operate because of that (including resources allocating and consumption).

You might say: "Why do I need to know all that low-level stuff in the 2020s?".
Fair enough...if you don't develop software for thousands of users, have an unlimited budget for
underutilized hardware, don't design distributed systems, or, simply, have an SRE team ready to
solve all possible issues for you. Otherwise, please do.
