+++
title = "Choosing Apache Kafka for a New Project"
description = "A checklist for evaluating Kafka throughput, retention, delivery guarantees, partitioning, and consumer groups before starting a project."
date = 2023-08-29
draft = false

[taxonomies]
tags = ["kafka", "event-driven-architecture", "system-design"]

[extra]
keywords = "kafka, event-driven-architecture, system-design"
toc = false
static_thumbnail = "/images/social-choosing-kafka.png"

+++

Apache Kafka is often proposed whenever a project needs to process events, messages, or data streams.
The choice is not always deliberate. A conventional message broker such as ActiveMQ may be enough,
but Kafka's popularity can influence the decision.

If Kafka has been selected deliberately or mandated by the infrastructure team, settle the following
points before configuring the brokers and writing producers and consumers.

1. **Estimate producer data volume.** Confirm that the network can handle the load across the system,
   especially on critical paths. Evaluate
   [message compression](https://www.conduktor.io/kafka/kafka-message-compression/) where appropriate.

2. **Define the [data retention policy](https://strimzi.io/blog/2021/12/17/kafka-segment-retention/).**
   Set the retention period from the product's business and data-protection requirements, then account
   for the storage cost.

3. **Choose producer [acknowledgement settings](https://www.conduktor.io/kafka/kafka-producer-acks-deep-dive/).**
   Balance latency against reliability and durability under replication.

4. **Define delivery guarantees.** Establish how the product handles message loss and duplicate messages.
   Decide whether it needs
   [idempotent producers](https://www.conduktor.io/kafka/idempotent-kafka-producer/) or
   [transactions](https://www.confluent.io/blog/transactions-apache-kafka/).

5. **Choose a [partitioning strategy](https://redpanda.com/guides/kafka-tutorial/kafka-partition-strategy).**
   Verify that Kafka's default partitioner matches the required ordering and load distribution.

6. **Choose the topic cleanup policy.** Keep the complete message log when every record matters. If only
   the latest value for each key matters, consider
   [log-compacted topics](https://docs.confluent.io/kafka/design/log_compaction.html).

7. **Plan [consumer groups](https://www.conduktor.io/kafka/kafka-consumer-groups-and-consumer-offsets/).**
   Define how consumers will scale, what throughput they need, and how they will behave during
   [group rebalancing](https://www.verica.io/blog/understanding-kafkas-consumer-group-rebalancing/).

This checklist covers application-facing decisions. Encryption, authentication, authorization, and
cluster configuration still need explicit ownership, even when an SRE team or a PaaS manages them.
