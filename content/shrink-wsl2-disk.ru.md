+++
title = "Как освободить место на диске WSL2"
description = "Необходимое упражнение в ожидании новых релизов от Microsoft."
date = 2022-05-13
draft = false

[taxonomies]
tags = ["wsl", "windows", "devtools", "linux"]

[extra]
keywords = "wsl, windows, devtools, linux"
toc = false
+++

WSL2 создает виртуальный диск в формате .vhdx, который хранит файлы гостевой операционной системы.
Это включает в себя в том числе Docker-образы, скачиваемые для запуска контейнеров.
С течением времени размер диска сильно растет и начинает отъедать полезное место на диске `C:\`.

WSL2 не поддерживает высвобождение места на виртуальном диске, поэтому делать это нужно вручную.

Для начала удаляем неиспользуемые Docker-образы:

```bash
$ docker system prune --all

WARNING! This will remove:
  - all stopped containers
  - all networks not used by at least one container
  - all images without at least one container associated to them
  - all build cache

Are you sure you want to continue? [y/N] y
Deleted Images:
untagged: postgres:13.4-alpine3.14

...
Total reclaimed space: 76.84GB
```

А также выполняем удаление неиспользуемых системных пакетов:

```bash
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove
```

76.84GB высвободилось на виртуальном диске. На диске `C:\` 76.84GB все еще недоступны для пользования.

Ситуация исправляется следующим образом. Открываем PowerShell с правами администратора и выполняем:

```bash
> wsl.exe --list --verbose  # получаем список виртуальных машин

> wsl.exe --terminate Ubuntu-20.04  # останавливаем нужную

> diskpart  # запускаем дисковую утилиту

DISKPART> select vdisk file=C:\Users\devel\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu20.04onWindows_79rhkp1fndgsc\LocalState\ext4.vhdx  # указываем путь к файлу диска

DiskPart successfully selected the virtual disk file.

DISKPART> compact vdisk

100 percent completed

DiskPart successfully compacted the virtual disk file.
```

То же самое проделываем для диска Docker:

```bash
DISKPART> select vdisk file=C:\Users\devel\AppData\Local\Docker\wsl\data\ext4.vhdx

DiskPart successfully selected the virtual disk file.

DISKPART> compact vdisk

100 percent completed

DiskPart successfully compacted the virtual disk file.
```

Ура, на диске `C:\` появились 76.84GB и даже больше.
