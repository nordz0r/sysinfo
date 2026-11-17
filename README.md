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

**Содержание:** [Быстрый старт](#быстрый-старт) · [Автозапуск](#автозапуск) · [Параметры](#параметры) · [Совместимость](#совместимость) · [Разработка](#разработка)

## Быстрый старт

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Или через `wget`:

```sh
wget -q -O - -T 5 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Используйте доверенный источник и просмотрите код перед запуском. Потоковый запуск
проще, но скачивание в файл безопаснее при неполной загрузке.

## Автозапуск

### Настройка через GitHub

Установите копию в `~/.local/bin/sysinfo.sh`:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
```

Отдельно настройте автозапуск установленной копии:

```sh
sh "$HOME/.local/bin/sysinfo.sh" setup --local
```

Файл запуска выбирается по `SHELL`: если имя оболочки — `bash`, используется
`~/.bashrc`; иначе, включая незаданную `SHELL`, — `~/.profile`.

**OpenWrt:**

```sh
wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
```

Затем отдельно настройте автозапуск той же командой `sh "$HOME/.local/bin/sysinfo.sh" setup --local`.
Параметры `wget` указаны раздельно для совместимости с OpenWrt.

#### Вариант без локальной установки

Для настройки удалённого запуска выполните:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- setup
```

**OpenWrt (удалённая настройка без локальной установки):**

```sh
wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- setup
```

При настройке проверяются загрузчики и выбирается `curl`, а при его отсутствии —
`wget`. Если оба отсутствуют, профиль не меняется. Удалённый автозапуск загружает
актуальный `sysinfo.sh` и передаёт его в `sh` только в интерактивной оболочке,
когда stdin и stdout подключены к терминалу; `ssh host command`, `scp`, cron и
перенаправленный вывод не запускают сводку. Загрузка не прерывает вход в оболочку.
При неполной загрузке потоковый запуск может выполнить частичный скрипт;
скачивание в файл безопаснее.

`~/.profile` — стандартный профиль входа POSIX, но его читает не каждая оболочка.
Автозапуск в нём не универсален для оболочек, которые не читают `~/.profile`
или не поддерживают POSIX shell hooks; для них настройте подходящий файл вручную.

#### Через прокси

Для удалённого варианта укажите прокси для первой загрузки и будущих запусков;
замените `proxy.example.com:3128` на адрес своего прокси.

```sh
sysinfo_proxy='http://proxy.example.com:3128'; curl -fsSL --proxy "$sysinfo_proxy" https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- setup --proxy "$sysinfo_proxy"
```

Адрес из `--proxy` сохраняется в команде выбранного загрузчика. При повторной
настройке передавайте этот параметр снова; без него используются обычные
настройки прокси из окружения. Для совместимости с обоими загрузчиками
используйте `http://`-прокси; адрес `https://` требует `curl`. Для первой
загрузки через `wget` задайте `https_proxy` и `http_proxy`:

```sh
sysinfo_proxy='http://proxy.example.com:3128'; https_proxy="$sysinfo_proxy" http_proxy="$sysinfo_proxy" wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- setup --proxy "$sysinfo_proxy"
```

`~/.profile` — стандартный профиль входа POSIX, но его читает не каждая оболочка.
Автозапуск в нём не универсален для оболочек, которые не читают `~/.profile`
или не поддерживают POSIX shell hooks; для них настройте подходящий файл вручную.

#### Через прокси

Для удалённого варианта укажите прокси для первой загрузки и будущих запусков;
замените `proxy.example.com:3128` на адрес своего прокси.

```sh
sysinfo_proxy='http://proxy.example.com:3128'; (tmp=$(mktemp) || exit; trap 'rm -f "$tmp"' 0; curl -fsSL --proxy "$sysinfo_proxy" https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh -o "$tmp" && sh "$tmp" setup --proxy "$sysinfo_proxy")
```
Адрес из `--proxy` сохраняется в команде выбранного загрузчика. При повторной
настройке передавайте этот параметр снова; без него используются обычные
настройки прокси из окружения. Для совместимости с обоими загрузчиками
используйте `http://`-прокси; адрес `https://` требует `curl`. Для первой
загрузки через `wget` задайте `https_proxy` и `http_proxy`:

```sh
sysinfo_proxy='http://proxy.example.com:3128'; (tmp=$(mktemp) || exit; trap 'rm -f "$tmp"' 0; https_proxy="$sysinfo_proxy" http_proxy="$sysinfo_proxy" wget -q -O "$tmp" -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh && sh "$tmp" setup --proxy "$sysinfo_proxy")
```
#### Переход со старого автозапуска

Чтобы заменить настройки, созданные прежней опцией `--setup-bash`, повторно
выполните команду `setup`. Она обновит профиль, выбранный по переменной `SHELL`,
и удалит распознанные записи sysinfo только из этого файла: вызовы `sysinfo_v2.sh`,
прокси-варианты, локальные вызовы и предыдущие блоки. Записи в другом файле
профиля команда не меняет. Если старый вызов использовал прокси, укажите его
через `--proxy`. Остальные настройки выбранного профиля сохраняются.

Перед первым изменением профиль сохраняется в резервную копию с суффиксом
`.sysinfo.bak`; существующая копия не перезаписывается. Повторный запуск не
создаёт дубли. Символьные ссылки вместо файла профиля остаются без изменений.
Чтобы отключить автозапуск, удалите блок между `# >>> sysinfo >>>` и
`# <<< sysinfo <<<` включительно.

<details>
<summary><strong>Работа офлайн после установки</strong></summary>

Основная команда выше сохраняет скрипт в `~/.local/bin/sysinfo.sh` и настраивает
запуск этой локальной копии, поэтому последующие входы в оболочку не требуют сети.
Если копия уже установлена, обновить её из checkout можно так:

```sh
sh sysinfo.sh --install
```

Установка не редактирует профиль. Если локальная копия была установлена отдельно,
настройте её автозапуск этой командой:

```sh
sh "$HOME/.local/bin/sysinfo.sh" setup --local
```

Ручной запуск и удаление:

```sh
sh "$HOME/.local/bin/sysinfo.sh"
sh "$HOME/.local/bin/sysinfo.sh" --uninstall
```

Удаляется только файл скрипта. Каталоги и настройки оболочки остаются на месте;
локальная строка автозапуска после удаления молча пропускается.

</details>


## Параметры

| Команда / ключ | Действие |
| --- | --- |
| `--install` | Создать или обновить `~/.local/bin/sysinfo.sh`. |
| `--uninstall` | Удалить установленную копию. |
| `setup` | Настроить автозапуск в `~/.bashrc` для Bash или `~/.profile` для остальных оболочек, заменив старые записи sysinfo. |
| `--proxy URL` | Сохранить HTTP(S)-прокси для автозапуска, настроенного через `setup`. |
| `--local` | Вместе с `setup` запускать установленную локальную копию. |
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
Для `setup` требуются `cp`, `cmp` и `mktemp`; Bash не нужен.

На OpenWrt команда автоматической настройки выше работает с `wget` и штатным
`ash` (`sh`). `/overlay` не дублирует корневую файловую систему, `/tmp`
показывается отдельно, неизменяемый squashfs пропускается. Настройка выбирает
`~/.profile`, если `SHELL` не указывает на Bash.

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

