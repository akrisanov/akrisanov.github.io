+++
title = "Синхронизация пользователей через LDAP в Keycloak"
description = "Как вытащить пользователей из Active Directory при наличии неочевидной структуры учетных записей."
date = 2021-05-14
draft = false

[taxonomies]
tags = ["keycloak", "аутентификация"]

[extra]
keywords = "keycloak, ldap, аутентификация"
toc = false
+++

Один из способов подключения провайдера существующих пользователей к Keycloak – механизм,
который называется User Federation. Он позволяет используя Kerberos или LDAP синхронизировать
учетные записи из корпоративного хранилища. Если пользователей в хранилище много, и оргструктура
организации предполагает иерархию, то это может усложнить получение (под)группы учетных записей.

Так, например, в Active Directory используются следующие сущности:

- `CN` = Common Name
- `OU` = Organizational Unit
- `DC` = Domain Component

Документация по LDAP с расшифровкой аббревиатур есть на сайте
[Microsoft](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ldap/distinguished-names).

В настройках LDAP провайдера необходимо указать `User DN`. Самый простой вариант – когда все учетные
записи разложены по организационным единицам:

```bash
OU=Main,DC=Orgname,DC=ru
```

В этом случае Keycloak с легкостью найдет все учетные записи в юните, даже если внутри него есть
какая-то вложенная структура. Для этого, правда, придется включить дополнительный
параметр *Search Scope: Subtree*.

Но что делать если администраторы Active Directory вместо создания `OU` сущностей добавляют нужных
вам пользователей в `CN`? Другого способа, как дополнить описанное выше решение дополнительным
фильтром для LDAP, я не нашел. В настройке `Custom User LDAP Filter` можно прописать все `CN` группы
через оператор «Или» `|`:

```bash
(&(objectCategory=Person)(sAMAccountName=*)(|(memberOf=CN=CMS_EDITOR,OU=Security,OU=Groups,OU=Central,OU=Main,DC=Orgname,DC=ru)))
```

В примере указана только одна группа – `CMS_EDITOR`.
