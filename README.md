<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset=".github/assets/banner-light.svg">
    <img alt="nordz0r/sysinfo — сводка о системе Linux" src=".github/assets/banner-light.svg" width="100%">
  </picture>
</p>

<p align="center"><b>Русский</b> · <a href="README.en.md">English</a></p>

<p align="center">
  <img alt="bash" src="https://img.shields.io/badge/bash-script-4eaa25?style=flat-square&logo=gnubash&logoColor=white">
  <img alt="OpenWrt" src="https://img.shields.io/badge/OpenWrt%2FBusyBox-v2-00b5e2?style=flat-square">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"></a>
</p>

Скрипт на bash, который одной командой выводит сводку о машине: hostname, модель и число ядер CPU, частоту, объём и занятость диска, RAM и swap, uptime, load average, ОС, архитектуру, ядро и IP-адреса.

## Использование

Версия 1 (исходная):

```bash
curl -Lso- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash
# или
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash
```

Версия 2 (обратно совместимая, для встраиваемых систем вроде OpenWrt/BusyBox):

```bash
curl -Lso- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash
# или
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash
```

Нужен `curl` или `wget`. Перед запуском через `| bash` просмотрите скрипт.

### Изменения в v2

- Запасной способ получить hostname, если нет `/etc/hostname`
- Альтернативный сбор load average, когда нет команды `w`
- Определение разрядности CPU без `getconf`
- `df` совместим с BusyBox (убран ключ `-l`)
- Проверка наличия команд перед использованием
- Улучшено определение IP

## Лицензия

MIT, см. [LICENSE](LICENSE).
