+++
title = "Сертификат для LDAPS в Keycloak"
description = "Как добавить сапомодписанный сертификат в Keycloak для подключения к Active Directory."
date = 2021-05-15
draft = false

[taxonomies]
tags = ["keycloak", "docker", "аутентификация"]

[extra]
keywords = "keycloak, docker, ldap, аутентификация"
toc = false
+++

В нескольких рабочих проектах я использую в качестве сервиса аутентификации [Keycloak](https://www.keycloak.org/).
Проект спонсируется компанией RedHat, активно развивается и адаптирован для cloud-native окружения.
Хотя документация у Keycloak достаточная для основных пользовательских сценариев, иногда ее
не хватает для решения специфичных вопросов. Последнее с чем я столкнулся — подключение
Active Directory как User Federation через протокол LDAPS (LDAP over SSL).

Как и полагается внутренним корпоративным сервисам, наш сервер LDAPS предоставляет самоподписанный сертификат.
Keycloak в этом случае для успешного соединения с `ldaps://ldap.orgname.com:636` требует, чтобы
сертификат находился в truststore. Вариантов конфигурирования несколько:

1. глобальный cacerts ОС, в которой запускается сервис
2. cacerts из каталога установленного JDK
3. системное свойство `javax.net.ssl.trustStore` для JVM
4. truststore в каталоге Keycloak

Если вам необходимо просто добавить самоподписанный сертификат или root.crt, то самым простым
способом будет добавление его в источники на уровне ОС и обновление списка доверенных сертификатов.
Тогда вам не придется каждый раз искать где находиться JDK в системе, переписывать startup-скрипты
сервиса или заботиться о безопасной работе с паролями для своего truststore.

Для разворачивания в Kubernetes или OpenShift можно собрать образ следующим способом:

```Dockerfile
FROM jboss/keycloak:13.0.0

USER root

ARG CERT="root.crt"

COPY $CERT /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust

USER 1000
```

Убедиться, что сертификат был добавлен в список доверенных:

```bash
cd /etc/pki/ca-trust/extracted/java
keytool -list -keystore cacerts
```

```bash
>> Your keystore contains 137 entries
```

В оригинальном образе их 136.
