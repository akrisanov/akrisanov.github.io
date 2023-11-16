+++
title = "Расширения для Jupyter Notebook"
description = "Как расширить возможности Jupyter Notebook через плагины."
date = 2020-03-30
draft = false

[taxonomies]
tags = ["jupyter", "анализ данных"]

[extra]
keywords = "jupyter, jupyter notebook, анализ данных, python"
toc = false
+++

Jupyter Notebook — один из часто используемых мною инструментов. Несмотря на всю мощь этого
решения, «из коробки» иногда не хватает какой-нибудь маленькой, но полезной функциональности,
например, генерации содержания по заголовкам разметки Markdown.

К счастью исправить подобные мелочи отчасти помогают расширения, которые можно найти на Github.
Существуют как официальные пакеты, поддерживаемые JupyterLab, так и созданные сообществом пакеты.

Хороший пример
[jupyter_contrib_nbextensions](https://github.com/ipython-contrib/jupyter_contrib_nbextensions) —
большая коллекция неофициальных дополнений к Jupyter. Полный список расширений доступен на
[странице документации](https://jupyter-contrib-nbextensions.readthedocs.io/en/latest/nbextensions.html).

Для их подключения к вашему Jupyter Notebook потребуется выполнить три простых шага.

Установить pip пакет с расширениями:

```shell
pip3 install jupyter_contrib_nbextensions
```

Скопировать JavaScript и CSS файлы:

```shell
jupyter contrib nbextension install --user
```

Активировать выбранное расширение:

```shell
jupyter nbextension enable toc2/main
```

В ответ вы должны получить следующее сообщение:

```shell
Enabling notebook extension toc2/main...
      - Validating: OK
```

Запустив заново Jupyter Notebook, можно убедиться, что расширение было успешно установлено и активировано:

![Сайдбар с оглавлением](/images/jupyter.png)
