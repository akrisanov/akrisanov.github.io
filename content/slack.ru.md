+++
title = "Slack в распределенной команде"
description = "Как использовать Slack в распределенной команде, чтобы не терять фокус и не отвлекать коллег."
date = 2019-06-08
draft = false

[taxonomies]
tags = ["slack", "remote"]

[extra]
keywords = "slack, mattermost, удаленная работа, распределенная команда, эффективная коммуникация"
toc = true
+++

Вот уже несколько лет я работаю удаленно, и все коммуникации даже в текущей компании мы строим на
основе асинхронного подхода. Делаем мы это умышленно и стараемся предоставить сотрудникам возможность
сфокусироваться на своих задачах, при этом не блокируя других членов команды, которые от них зависят.

Slack для нас — основной инструмент коммуникации. Он позволяет команде общаться в течение дня
используя правильные каналы для организации диалогов. В Slack мы синхронизируем рабочий процесс,
договариваемся о звонках, или просто общаемся на отвлеченные темы. При этом, мы условились, что
Slack не является:

- потоком сообщений, которые нужно постоянно проверять и немедленно реагировать на них
- местом для хранения важных ссылок, документации и обратной связи сотрудников
- местом для принятия важных решений

Как и любой чат, Slack нельзя назвать асинхронным, что усложняет наше виденье распределенной команды.
Основные причины этому — частые прерывания и многозадачность. Довольно быстро можно заметить что
работая удаленно и используя чат по назначению, коллеги ожидают от вас почти немедленного ответа.
При этом люди не учитывают и не знают заняты ли вы сейчас, общаетесь ли вы с другим членом команды,
или же сделали небольшой перерыв. Подобное общение может вызывать стресс и мало отличаться от
офисной трясины митингов, и снова возникает ощущение, что планируемая работа не завершена к концу дня.

Однако, при правильном подходе, которому придерживается вся команда и руководство, Slack тоже может
быть асинхронным. Ниже я привожу несколько практик, которые направлены на создание такого процесса.

### Управляйте своим отсутствием

Если все члены команды будут ответственны за оффлайн-режим, то это подарит команде свободу в коммуникациях. Ответственность заключается в том, чтобы разобрать полученные сообщениями тогда, когда это удобно именно вам.

1. Установите `Do Not Disturb` режим в случае оффлайна или нерабочего времени
2. Настройте нотификации на мобильном, если боитесь пропустить что-то важное
3. Помечайте сообщения как непрочитанные, кликайте на звездочку чтобы сохранить их на потом,
или ставьте напоминание для того, чтобы позже вернуться к нужному обсуждению

### Используйте публичные каналы

Всегда старайтесь делать коммуникации общедоступными и прозрачными, чтобы любой член команды мог их
увидеть, осознать, и, возможно, дополнить своими предложениями и вопросами. Только приватные
обсуждения должны оставаться в стороне.

### Используйте статус и профиль как индикатор доступности

Заполните свой профиль — аватар, реальное имя, часовой пояс, роль, телефонный номер, Skype или
Telegram (опционально).

[Делитесь своим статусом с коллегами](https://slackhq.com/set-your-status-in-slack-28a793914b98) —
дайте знать если вы заболели, в отпуске, работаете в своем нестандартном режиме, или вам просто
нужен период для фокуса над задачами.

![Установка информативного статуса в Slack](/images/slack-status.png)

### Настройте уведомления

Убедитесь, что ваши настройки соответствуют рекомендованным Slack: только прямые (direct)
сообщения, `@you` и подсвечиваемые слова (highlight words). Эти настройки позволяют фокусироваться
на важных сообщениях и не беспокоиться, что вы что-то пропустили когда находитесь не у компьютера.

![Настройка уведомлений в Slack](/images/slack-notifications.png)

### Общайтесь проактивно

Когда вы отправляете кому-нибудь сообщение, старайтесь давать этому человеку больше контекста.
Особенно это важно при асинхронных ответах, например, если у коллеги другой часовой пояс.
Добавляйте ссылки, документы, ваш дедлайн по проблеме или желаемое время ответа на ваше сообщение
— все что может продвинуть обсуждение вперед в асинхронном режиме.

### Создавайте треды когда это возможно

Когда вы ведете обсуждение с несколькими людьми одновременно, бывает довольно сложно уследить за
ответами конкретным лицам в рамках обсуждения. Идеи и мысли могут теряться в потоке сообщений.
Использование тредов позволяет структурировать общение.

![Пример треда с двумя вложенными сообщениями](/images/slack-threads.png)

### Используйте away режим когда вам нужен фокус

Несколько опций, которые позволят вам сфокусироваться:

- Установка away статуса в вашем профиле
- Режим «Не беспокоить» — `Do Not Disturb`
- Явное сообщение, чтобы коллеги знали, что вас не стоит отвлекать

### Перестаньте постоянно проверять сообщения

Наличие непрочитанных сообщений в Slack не означает, что их нужно прочитать немедленно!
Дайте людям возможность выполнять их задачи, пока вы выполняете свои.

### @channel или @here

Включение `@channel` в сообщение уведомит всех членов чата, в то время как `@here` только тех, кто
сейчас находится онлайн. @channel и @everyone всегда лучше использовать только для важных анонсов —
Slack отсылает пуш-уведомление и email каждому, включая людей, которые находятся оффлайн или в отпуске.

### Отвечайте к концу своего рабочего дня

Отправляя сообщение вы должны ожидать, что ответ будет сделан в концу рабочего дня если:

- вы связались с коллегой используя `@` или написав личное сообщение если контент приватный
- вы не установили дедлайн для ответа — старайтесь всегда делать это
- коллега работает обычный день — не болен/отъезде/отпуске и т. д.

### Непредвиденные ситуации

Используйте `@channel`, `@everyone`, а также слово СРОЧНО в своем сообщении. Если вам нужно связаться
с коллегой после рабочих часов или в рамках режима «Не беспокоить», все равно отправьте сообщение —
Slack бот попросит подтвердить ваши намерения. Используйте телефонный номер, указанный в профиле.

## Заключение

Все вышеперечисленные советы работают не только для Slack, но и для любого другого мессенджера.
Их можно адаптировать для [Mattermost](https://mattermost.com/), Zoolip или Telegram.

Основная идея — сделать коммуникации эффективными, асинхронными и прозрачными, а не переживать
по поводу онлайн-статуса или неотвеченных вообщений.
