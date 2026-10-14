<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset=".github/assets/banner-light.svg">
    <img alt="nordz0r/sysinfo — сводка о системе" src=".github/assets/banner-light.svg" width="100%">
  </picture>
</p>

<p align="center"><b>Русский</b> · <a href="README.en.md">English</a></p>

<p align="center">
  <strong>Сводка о системе одной командой.</strong><br>
  Linux, macOS и OpenWrt — один лёгкий скрипт, без фоновых процессов.
</p>

<p align="center">
  <img alt="POSIX shell" src="https://img.shields.io/badge/shell-POSIX%20sh%20%2F%20Bash-4eaa25?style=flat-square&logo=gnubash&logoColor=white">
  <img alt="Linux, macOS, OpenWrt" src="https://img.shields.io/badge/Linux%20%7C%20macOS%20%7C%20OpenWrt-supported-0969da?style=flat-square">
  <img alt="BusyBox" src="https://img.shields.io/badge/BusyBox-compatible-00b5e2?style=flat-square">
  <a href="LICENSE"><img alt="Лицензия MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"></a>
</p>

**sysinfo** показывает ОС, ядро, процессор, uptime, load average, RAM, swap,
занятость дисков и IP-адреса. Вывод остаётся на английском, чтобы одинаково
читаться в терминалах на серверах и роутерах.

- **Быстрый запуск:** системные утилиты, без Python, Node.js и обращения к сети при локальном запуске.
- **Наглядные ресурсы:** полоски заполнения и цветовые предупреждения о нехватке места.
- **Компактный вывод:** до четырёх файловых систем и трёх интерфейсов по умолчанию; для OpenWrt показываются все активные IPv4-интерфейсы.
- **Установка по желанию:** без ключей скрипт выполняется сразу, локальная копия создаётся только с `--install`.

**Содержание:** [Быстрый старт](#быстрый-старт) · [Установка](#установка-и-удаление) ·
[Автозапуск в Bash](#автозапуск-в-bash) · [Параметры](#параметры) · [Совместимость](#совместимость) · [Разработка](#разработка)

## Быстрый старт

```bash
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash
```

Или через `wget`:

```sh
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Используйте доверенный источник и просмотрите код перед запуском. Скрипт выводит
текущие данные и завершается, ничего не устанавливая.

## Установка и удаление

Сохраните исполняемую копию в `~/.local/bin/sysinfo.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --install
```

Каталоги создаются при необходимости, файл получает права `755`. При повторной
установке собственная копия обновляется атомарно. Посторонние файлы и символьные
ссылки в целевом пути сохраняются; повторной загрузки внутри скрипта нет.

Запуск установленной копии и удаление:

```sh
"$HOME/.local/bin/sysinfo.sh"
"$HOME/.local/bin/sysinfo.sh" --uninstall
```

Удаляется только файл скрипта. Каталоги и настройки оболочки остаются на месте.
Из локального checkout также доступны `sh sysinfo.sh --install` и `sh sysinfo.sh --uninstall`.

## Автозапуск в Bash

После установки выполните эти две строки:

```bash
sysinfo_hook='case $- in *i*) [ ! -x "$HOME/.local/bin/sysinfo.sh" ] || "$HOME/.local/bin/sysinfo.sh" --interactive-only ;; esac'
grep -qxF "$sysinfo_hook" "$HOME/.bashrc" 2>/dev/null || printf '\n%s\n' "$sysinfo_hook" >> "$HOME/.bashrc"
```

Команда добавляет строку в `~/.bashrc` один раз и создаёт файл, если его ещё нет.
Проверки выполняются на двух уровнях:

1. `case $-` разрешает автозапуск только в интерактивном Bash.
2. `--interactive-only` внутри скрипта проверяет, что stdin и stdout подключены к терминалу.

Так сводка не появляется в неинтерактивных `ssh host command`, `scp`, заданиях cron
и выводе, перенаправленном в файл. Прямой запуск без этого ключа, включая
`curl | bash`, по-прежнему работает. Сам `--install` не редактирует `~/.bashrc`.

После удаления скрипта строка автозапуска молча пропускается. Если ранее добавляли
другую строку запуска sysinfo, замените её новой, чтобы не получать двойной вывод.

## Параметры

| Ключ | Действие |
| --- | --- |
| `--install` | Создать или обновить `~/.local/bin/sysinfo.sh`. |
| `--uninstall` | Удалить установленную копию. |
| `--interactive-only` | Выводить сводку только при stdin/stdout, подключённых к терминалу. |
| `--details` | Показать все выбранные локальные файловые системы и IPv4-интерфейсы. |
| `--all-interfaces` | Показать все IPv4-интерфейсы, включая виртуальные. |
| `--color` / `--no-color` | Принудительно включить или выключить ANSI-цвета. |
| `--help` | Показать справку. |

### Полоски и цвета

| Заполненность | Цвет |
| --- | --- |
| Менее 80% | Зелёный |
| От 80% до 94% | Жёлтый |
| От 95% | Красный и знак `!` |

Проценты берутся из `df`, с учётом доступного места и резерва файловой системы.
Размеры не складываются; повторные монтирования скрываются. Цвет автоматически
отключается при перенаправлении вывода, `TERM=dumb` или установленном `NO_COLOR`.

В UTF-8 используются ровные символы `█`/`░`, иначе — `=`/`-`.
На OpenWrt без настроенной локали UTF-8 определяется по типу терминала;
переопределение доступно через `SYSINFO_UTF8=1` или `SYSINFO_UTF8=0`.
Длина разделителей учитывает вывод и ширину терминала (`COLUMNS`).

## Совместимость

| Среда | Особенности |
| --- | --- |
| Linux / Debian | Данные из `/proc`, локальные диски через `df`, сеть через `ip` или `ifconfig`. Docker и другие служебные виртуальные интерфейсы по умолчанию скрыты. |
| OpenWrt / BusyBox | Достаточно `ash`, `awk`, `df` и `ip`; Bash не требуется. Показываются все активные IPv4-интерфейсы, SoC/ARM CPU и модель платы, если данные доступны. |
| macOS | Используются штатные `sysctl`, `vm_stat`, `sw_vers`, BSD `df` и `ifconfig`. |

Базовые зависимости — `sh`, `cat`, `uname`, `awk`, `df`. Для установки нужны
`mkdir`, `mktemp`, `chmod`, `mv` и `rm`. Локальный запуск не требует `curl`/`wget`;
при отсутствии обоих скрипт подсказывает команду установки загрузчика.

На OpenWrt `/overlay` не дублирует корневую файловую систему, `/tmp` показывается
отдельно, неизменяемый squashfs пропускается. Штатный `ash` не читает `~/.bashrc`:
для него аналогичную проверку `case $-` размещают в `~/.profile`.

macOS проверена на образцах вывода системных команд; проверка на настоящем Mac
остаётся необходимой. Расчёт RAM через `vm_stat` — оценка занятости, не показатель
memory pressure из Activity Monitor.

<details>
<summary><strong>Переход со старой версии</strong></summary>

Единственная точка входа — `sysinfo.sh`. Старый `sysinfo_v2.sh` удалён;
замените его имя в URL или локальных командах на `sysinfo.sh`.
Полного примера `.bashrc` в репозитории больше нет: используйте короткую команду
из раздела автозапуска, сохраняя собственные настройки оболочки.

</details>

## Разработка

```sh
sh sysinfo.sh
sh sysinfo.sh --details
python3 -m unittest discover -s tests -v
```

Тесты проверяют Linux, образцы macOS/OpenWrt, интерактивный Bash с терминалом,
молчаливый неинтерактивный запуск, повторную установку и удаление, сохранность
профилей и поведение при отказах записи.

<details>
<summary><strong>Дополнительные проверки</strong></summary>

Проверка на настоящих апплетах BusyBox:

```sh
SYSINFO_TEST_SH=/path/to/busybox-bin/sh \
SYSINFO_TEST_AWK=/path/to/busybox-bin/awk \
python3 -m unittest discover -s tests -v
```

ShellCheck для точки входа и встроенного кода:

```sh
shellcheck sysinfo.sh
awk 'BEGIN { print "sysinfo_payload=" } /^sysinfo_payload=\$\(cat/ { body=1; next } /^SYSINFO_PAYLOAD$/ { exit } body' sysinfo.sh | shellcheck -s sh -
```

</details>

## Лицензия

[MIT](LICENSE) © NorD.

