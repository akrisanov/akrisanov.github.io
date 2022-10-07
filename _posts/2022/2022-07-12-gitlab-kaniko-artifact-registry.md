---
layout: post
title:  "Сборка образов на Gitlab CI для GCP Artifact Registry"
tags: ["gitlab", "CI", "Google Cloud"]
---

Пару дней назад потребовалось автоматизировать сборку образов для релизов веб-платформы, которая
разворачивается в Kubernetes (GKE). До этого момента сборка выполнялась локально на машинах
разработчиков при помощи Docker и собранные образы отправлялись в Google Artifact Registry.
Кроме того, стали появляться дополнительные тестовые и демо-окружения, требующие небольших изменений,
например, в конфигурации фронтенда. Перечисленное усложняло жизнь и команде solution и sales-инженеров
разворачивающих систему у клиентов.

Чтобы сэкономить время и другие ресурсы, решено было добавить дополнительный этап в существующий
пайплайн с банальным именем `build` и выполнять рутиные операции после успешного прохождения линтеров и тестов.

Первое с чем я столкнулся, это непонимание как запущен и сконфигурирован Gitlab Runner.
Так как наш DevOps-инженер в это удачное время оказался в отпуске, пришлось самому проверять настройки CI.
От того, какой тип раннера используется для выполнения пайплайнов, зависят в том числе и возможности сборки.
В моем случае используется Kubernetes Runner и задачи прогоняются в контейнерах. Следовательно, чтобы
собрать образы в таком окружении, потребуется [Docker внутри контейнера](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker). И с этим сразу начинаются проблемы, которые связаны с привелегированным доступом к сокету Docker, стабильностью пайплайна в целом, безопасностью [желанием Kubernets уйти от Docker-образов](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.20.md#deprecation) в будущем. Проведя несколько экспериментов, решил отказаться от этой идеи.

Обойтись без dind (Docker-in-Docker) помогает Kaniko. [Официальная страница документации Gitlab](https://docs.gitlab.com/ee/ci/docker/using_kaniko.html) неплохо описывает весь процесс сборки. Единственная сложность, которая у меня возникла, была связана с аутентификацией GCP Artifact Registry.

Для аутентификации раннера нужно создать [сервисный аккаунт](https://console.cloud.google.com/iam-admin/serviceaccounts) в разделе IAM & Admin.

![Создание сервисного аккаунта](/assets/images/gcp-service-account.png)

Далее сгенерировать приватный ключ в формате JSON и скачать его.

![Генерация нового приватного ключа](/assets/images/gcp-private-key.png)

Выдать права доступа к Artifact Registry для сервисного аккаунта.

![Назначение ролей Artifact Registry Reader и Artifact Registry Writer](/assets/images/gcp-roles.png)

Роль `Artifact Registry Reader` необходима для скачивания образов и кеширования, роль `Artifact Registry Writer` – для публикации образов. В интернете можно найти руководства, которые предлагают указывать роль Storage Admin, но, на мой взгляд, это плохая практика.

С настройкой на стороне облака закончено, остается раннер и Kaniko, который для аутентификации GCP читает специальную переменную `GOOGLE_APPLICATION_CREDENTIALS` . Чтобы записать в нее содержимое приватного ключа в формате JSON, потребуется перевести его в base64.

В настройках CI/CD репозитория добавить переменную окружения и скопировать в качестве значения base64 строку.

![Создание переменной GOOGLE_APPLICATION_CREDENTIALS](/assets/images/gitlab-env.png)

Теперь раннер сможет декодировать значение переменной аутентификации и успешно публиковать образы.

После добавления этапа сборки в `.gitlab-ci.yml`, она будет запускаться при тегировании определенного коммита.

Сборка образа бекенда при помощи Kaniko и его публикация

Как результат, в GCP Artifact Registry после успешного выполнения пайплайна появится образ с именем вида `backend:v1.11`.