+++
title = "Сборка образов на Gitlab CI для GCP Artifact Registry"
description = "Как собрать Docker-образы в Gitlab CI и отправить их в Google Artifact Registry."
date = 2022-07-12
draft = false

[taxonomies]
tags = ["devops", "docker", "gitlab", "Google Cloud"]

[extra]
keywords = "docker, gitlab, CI, Google Cloud, GCP, Artifact Registry"
toc = false
+++

Пару дней назад потребовалось автоматизировать сборку образов для контейнеров веб-платформы, которая
разворачивается в Google Kubernetes Engine (GKE). До этого момента сборка выполнялась локально на
машинах разработчиков при помощи Docker и собранные образы отправлялись в Google Artifact Registry.
Кроме того, стали появляться дополнительные тестовые и демо-окружения, требующие небольших изменений,
например, в конфигурации фронтенда. Перечисленное также усложняло жизнь solution и sales-инженерам,
разворачивающих систему у клиентов.

Чтобы сэкономить время и другие ресурсы, решено было добавить дополнительный этап в существующий
пайплайн с банальным именем `build` и выполнять рутиные операции после успешного прохождения
линтеров и тестов.

Первое с чем я столкнулся, это непонимание как запущен и сконфигурирован Gitlab Runner.
Так как наш DevOps-инженер в это удачное время оказался в отпуске, пришлось самому проверять настройки CI.
От того, какой тип раннера используется для выполнения пайплайнов, зависят в том числе и возможности сборки.
В моем случае используется Kubernetes Runner и задачи прогоняются в контейнерах.
Следовательно, чтобы собрать образы в таком окружении, потребуется [Docker внутри контейнера](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker).
И с этим сразу начинаются проблемы, которые связаны с привелегированным доступом к сокету Docker,
стабильностью пайплайна в целом, безопасностью и [желанием Kubernets уйти от Docker-образов](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.20.md#deprecation)
в будущем. Проведя несколько экспериментов, решил отказаться от изначального плана.

Обойтись без dind (Docker-in-Docker) помогает Kaniko. [Официальная страница документации Gitlab](https://docs.gitlab.com/ee/ci/docker/using_kaniko.html)
неплохо описывает весь процесс сборки. Единственная сложность, которая у меня возникла, была связана
с аутентификацией GCP Artifact Registry.

Для аутентификации раннера нужно создать [сервисный аккаунт](https://console.cloud.google.com/iam-admin/serviceaccounts)
в разделе IAM & Admin.

![Создание сервисного аккаунта](/images/gcp-service-account.png)
<span class="imgtitle">Создание сервисного аккаунта</span>

Далее сгенерировать приватный ключ в формате JSON и скачать его.

![Генерация нового приватного ключа](/images/gcp-private-key.png)
<span class="imgtitle">Генерация нового приватного ключа</span>

Выдать права доступа к Artifact Registry для сервисного аккаунта.

![Назначение ролей Artifact Registry Reader и Artifact Registry Writer](/images/gcp-roles.png)
<span class="imgtitle">Назначение ролей Artifact Registry Reader и Artifact Registry Writer</span>

Роль `Artifact Registry Reader` необходима для скачивания образов и кеширования,
роль `Artifact Registry Writer` – для публикации образов. В интернете можно найти руководства,
которые предлагают указывать роль `Storage Admin`, но, на мой взгляд, это плохая практика.

С настройкой на стороне облака закончено, остается раннер и Kaniko, который для аутентификации GCP
читает специальную переменную `GOOGLE_APPLICATION_CREDENTIALS`. Чтобы записать в нее содержимое
приватного ключа в формате JSON, потребуется перевести его в base64.

В настройках CI/CD репозитория следует добавить переменную окружения и скопировать в качестве
значения base64 строку.

![Создание переменной GOOGLE_APPLICATION_CREDENTIALS](/images/gitlab-env.png)
<span class="imgtitle">Создание переменной `GOOGLE_APPLICATION_CREDENTIALS`</span>

```yml
backend:build:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  variables:
    GOOGLE_APPLICATION_CREDENTIALS: /kaniko/kaniko-secret.json
    IMAGE_NAME: backend
  before_script:
    - echo $GOOGLE_APPLICATION_CREDENTIALS_BASE64 | base64 -d > /kaniko/kaniko-secret.json
  script:
    - >-
      /kaniko/executor
      --context "$CI_PROJECT_DIR"
      --dockerfile "$CI_PROJECT_DIR/backend.Dockerfile"
      --destination "$IMAGE_REPO/$IMAGE_NAME:$CI_COMMIT_TAG"
      --build-arg STATICE_PYTOKEN="$STATICE_PYTOKEN"
  only:
    - tags
```

После добавления нового этапа в `.gitlab-ci.yml`, сборка будет запускаться при тегировании
определенного коммита.

![Пайплайн проекта](/images/kaniko-build-pipeline.png)
<span class="imgtitle">Пайплайн проекта</span>

Как результат, в GCP Artifact Registry после успешного выполнения пайплайна появится образ
с именем вида `backend:{tag_name}`.
