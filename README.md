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

**Содержание:** [Быстрый старт](#быстрый-старт) · [Автозапуск в Bash](#автозапуск-в-bash) · [Параметры](#параметры) · [Совместимость](#совместимость) · [Разработка](#разработка)

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

## Автозапуск в Bash

### Вариант А — с GitHub, по умолчанию

Выполните один раз. Команда настроит `~/.bashrc`, заменив старые записи sysinfo
одним блоком с кратким описанием и ссылкой на репозиторий. Скрипт локально
не устанавливается.

```bash
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash
```

Если есть только `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash
```

При каждом интерактивном запуске Bash актуальный `sysinfo.sh` загружается
из GitHub и выполняется из памяти. При настройке выбирается `curl`,
при его отсутствии — `wget`; если нет обоих, команда предлагает установить
загрузчик и оставляет профиль без изменений.

В `.bashrc` добавляются пустая строка, комментарии и одна строка запуска
с уже подставленными URL и параметрами прокси. Проверки загрузчиков и выбор
параметров выполняются при настройке. Если выбранный загрузчик удалён,
повторите `--setup-bash`, чтобы выбрать доступный.

Загрузка начинается только в интерактивном Bash, когда stdin и stdout подключены
к терминалу. Полученный скрипт дополнительно проверяет это через `--interactive-only`.
Так автозапуск не мешает `ssh host command`, `scp`, cron и перенаправлению вывода.
`curl` получает общий таймаут 5 секунд; `wget` — таймаут ожидания 5 секунд
и одну попытку, если поддерживает соответствующий параметр.
При неудачной или пустой загрузке вход в Bash продолжается.

#### Через прокси

Укажите прокси и для первой загрузки, и для будущего автозапуска:

```bash
sysinfo_proxy='http://deb-proxy.lan:3128'
curl -fsSL --proxy "$sysinfo_proxy" https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash --proxy "$sysinfo_proxy"
```

Адрес из `--proxy` подставляется в команду выбранного загрузчика.
При повторной настройке передавайте этот параметр снова;
без него используются обычные настройки прокси из окружения.
Для совместимости с обоими загрузчиками используйте `http://`-прокси;
адрес `https://` требует `curl`.
Для первой загрузки через `wget` задайте `https_proxy` и `http_proxy`:

```bash
sysinfo_proxy='http://deb-proxy.lan:3128'
https_proxy="$sysinfo_proxy" http_proxy="$sysinfo_proxy" wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash --proxy "$sysinfo_proxy"
```

#### Переход со старого автозапуска

Команда убирает прежние отдельные вызовы `curl`/`wget` для этого репозитория,
включая `sysinfo_v2.sh` и параметры прокси, старые локальные вызовы и блоки,
созданные предыдущей настройкой. Комментарий `# by NorD` непосредственно
перед удаляемой строкой также убирается. Остальные настройки сохраняются.
Если старый вызов использовал прокси, укажите его через `--proxy`.

Перед первым изменением существующий профиль сохраняется в
`~/.bashrc.sysinfo.bak`; последующие настройки эту копию не перезаписывают.
Повторный запуск не создаёт дубли. Перед заменой проверяется синтаксис Bash.
Если старый вызов встроен в сложную конструкцию, которую нельзя однозначно
заменить, команда оставляет профиль без изменений и сообщает об этом.
Символьные ссылки вместо `.bashrc` также остаются без изменений.
Чтобы отключить автозапуск, удалите блок между `# >>> sysinfo >>>` и
`# <<< sysinfo <<<` включительно.

<details>
<summary><strong>Вариант Б — локальная установка для офлайн-сценария</strong></summary>

Если GitHub недоступен или сетевой запрос при входе нежелателен, сохраните копию
в `~/.local/bin/sysinfo.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --install
```

Каталоги создаются при необходимости, файл получает права `755`.
Собственная копия обновляется атомарно; посторонние файлы и символьные ссылки
в целевом пути сохраняются. Установка не редактирует профиль оболочки.

Для автозапуска локальной копии настройте тот же блок в офлайн-режиме
(он заменит вариант А и старые записи):

```bash
"$HOME/.local/bin/sysinfo.sh" --setup-bash --local
```

Ручной запуск и удаление:

```sh
"$HOME/.local/bin/sysinfo.sh"
"$HOME/.local/bin/sysinfo.sh" --uninstall
```

Удаляется только файл скрипта. Каталоги и настройки оболочки остаются на месте;
локальная строка автозапуска после удаления молча пропускается.
Из checkout также доступны `sh sysinfo.sh --install` и `sh sysinfo.sh --uninstall`.

</details>

## Параметры

| Ключ | Действие |
| --- | --- |
| `--install` | Создать или обновить `~/.local/bin/sysinfo.sh`. |
| `--uninstall` | Удалить установленную копию. |
| `--setup-bash` | Настроить автозапуск с GitHub в `~/.bashrc`, заменив старые записи sysinfo. |
| `--proxy URL` | Сохранить HTTP(S)-прокси для `--setup-bash`. |
| `--local` | Вместе с `--setup-bash` запускать установленную локальную копию. |
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
Для `--setup-bash` дополнительно нужны Bash, `cp`, `cmp` и `mktemp`.

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
молчаливый неинтерактивный запуск, повторную установку и удаление, миграцию
старого автозапуска, загрузку через прокси, резервную копию профиля и отказы записи.

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

