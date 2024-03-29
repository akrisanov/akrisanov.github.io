+++
title = "Чеклист по старту проекта с Apache Kafka®"
description = "О чем стоит подумать перед началом проекта с Apache Kafka®."
date = 2021-11-01
draft = false

[taxonomies]
tags = ["kafka", "system-design"]

[extra]
keywords = "kafka, system design, выбор технологии"
toc = false
+++

В любом современном проекте, где появляется необходимость обрабатывать какие-либо события — набор
сообщений или поток данных, в качестве инфраструктурного решения разработчики часто предлагают Apache Kafka®.
Не всегда этот выбор выглядит взвешенно — там, где достаточно классического брокера типа ActiveMQ, побеждает маркетинг.

Допустим все же, вы обдуманно пришли к выбору Кафки или же ваша централизованная инфраструктура
не оставила вам выбора. На какие вопросы стоит ответить перед тем, как начать писать продюсеры,
консьюмеры и настраивать какие-то параметры брокера? Мой базовый чеклист-опросник ниже:

1. Объем данных, который планируется генерировать продьюсерами → хватит ли вашего сетевого канала
   для всей системы и ее критичных компонент.
2. Как долго вам необходимо хранить данные: Data Retention Policy → бизнес-требования продукта,
   который вы разрабатываете и стоимость хранения данных, см. в том числе пункт первый.
   Кроме перечисленного не стоит забывать и про комплаенс.
3. Нужны ли гарантии отправки сообщения: Acks → поиск баланса между временем ожидания latency и
   надежностью в рамках репликации durability.
4. Гарантия доставки → насколько критично для нашей бизнес задачи потеря или дублирование сообщений,
   важны ли идемпотентность и транзакционность.
5. Какая стратегия партиционирования будет использоваться продьюсерами — подходит ли стратегия по умолчанию.
6. Для выбранного топика важно ли нам хранить весь лог сообщений или достаточно последних изменений
   → см. Compacted Topics в официальной документации.
7. Потребуется ли консьюмер-группа для ваших топиков; как вы планируете масштабировать консьюмеры
   и их пропускную способность; что будет в случае ребаласировки группы.

За рамками чеклиста остаются вопросы шифрования данных, аутентификации и авторизации,
а также траблшутинга — предполагая, что за вас это решит SRE или PAAS.
