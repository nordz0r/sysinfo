<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset=".github/assets/banner-light.svg">
    <img alt="nordz0r/sysinfo — system summary" src=".github/assets/banner-light.svg" width="100%">
  </picture>
</p>

<p align="center"><a href="README.md">Русский</a> · <b>English</b></p>

<p align="center">
  <strong>Your system at a glance, in one command.</strong><br>
  Linux, macOS, and OpenWrt — one lightweight script, no background processes.
</p>

<p align="center">
  <img alt="POSIX shell" src="https://img.shields.io/badge/shell-POSIX%20sh%20%2F%20Bash-4eaa25?style=flat-square&logo=gnubash&logoColor=white">
  <img alt="Linux, macOS, OpenWrt" src="https://img.shields.io/badge/Linux%20%7C%20macOS%20%7C%20OpenWrt-supported-0969da?style=flat-square">
  <img alt="BusyBox" src="https://img.shields.io/badge/BusyBox-compatible-00b5e2?style=flat-square">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"></a>
</p>

**sysinfo** prints the OS, kernel, CPU, uptime, load average, RAM, swap, disk
usage, and IP addresses. Terminal labels stay in English across servers and routers.

- **Quick to run:** standard system tools, no Python or Node.js, and no network requests during local execution.
- **Readable resources:** usage bars and colored warnings when storage runs low.
- **Compact output:** up to four filesystems and three interfaces by default; OpenWrt shows all active IPv4 interfaces.
- **Optional installation:** run immediately without flags; `--install` configures remote startup without saving a local script.

**Contents:** [Quick start](#quick-start) · [Shell startup](#shell-startup) · [Options](#options) · [Compatibility](#compatibility) · [Development](#development)

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Or use `wget`:

```sh
wget -q -O - -T 5 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Use a trusted source and review the code before execution. Piping can execute a
partial script if the download is incomplete; downloading to a file and checking
it first is safer.

## Shell startup

### Remote startup on login

The primary command downloads the script from GitHub and configures startup in
one step:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
```

It does not save a local copy. On each interactive login, the configured profile
downloads a fresh script from GitHub and pipes it to `sh`. The install status
message appears only after the initial download: `curl`/`wget` fetches the script
before it starts, so the script cannot report that first download.

**OpenWrt:**

```sh
wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
```

The profile is selected from the shell name in `SHELL`: Bash uses `~/.bashrc`;
all other values, including an unset `SHELL`, use `~/.profile`. Installation checks
for downloaders and selects `curl`, or `wget` if curl is absent. If neither is
available, it leaves the profile unchanged. The hook runs only in an interactive
shell with terminal stdin and stdout; commands such as `ssh host command`, `scp`,
cron jobs, and redirected output do not print the summary. A download failure
does not interrupt login, but an incomplete download may execute a partial script.

`~/.profile` is the standard POSIX login profile, but not every shell reads it.
If your shell does not read that file or support POSIX shell hooks, configure the
appropriate file manually.

### Optional local mode

For offline startup on later logins, save the script at
`~/.local/bin/sysinfo.sh` and configure startup for that local copy in one step:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install --local
```

On OpenWrt:

```sh
wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install --local
```

The local copy is not updated automatically. Repeat the install command to update it.

### Using a proxy

For remote startup, set a proxy for the initial download and future fetches;
replace `proxy.example.com:3128` with your proxy address:

```sh
sysinfo_proxy='http://proxy.example.com:3128'; curl -fsSL --proxy "$sysinfo_proxy" https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install --proxy "$sysinfo_proxy"
```

The `--proxy` address is saved in the selected downloader command. For the
initial download with `wget`, set `https_proxy` and `http_proxy`:

```sh
sysinfo_proxy='http://proxy.example.com:3128'; https_proxy="$sysinfo_proxy" http_proxy="$sysinfo_proxy" wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install --proxy "$sysinfo_proxy"
```

Pass `--proxy` again when reconfiguring; without it, the hook uses normal proxy
settings from the environment. Use an `http://` proxy for compatibility with
both downloaders; an `https://` proxy requires curl.

### Migrating from an older version

Older versions used the positional `setup` command to configure a profile
separately. In the current version, use `--install` for remote startup or
`--install --local` to save a local copy and configure its startup in one step.
Reinstallation replaces recognized sysinfo entries only in the profile selected
from `SHELL`; it does not change other startup files. Other settings in the
selected profile are preserved.

Before the first change, the profile is backed up with the `.sysinfo.bak` suffix;
an existing backup is never overwritten. Reinstalling does not add duplicates.
A symlink at the profile path is left unchanged. To remove startup manually,
delete the block from `# >>> sysinfo >>>` through `# <<< sysinfo <<<`, including
both markers.

After startup, the script reports the action and affected file or profile. These
messages are in Russian when the first non-empty value among `LC_ALL`,
`LC_MESSAGES`, and `LANG` starts with `ru_RU` (optionally followed by
`.encoding` and/or `@modifier`); they are English otherwise. System metrics remain
in English.

Remove the managed startup and any managed local copy with:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --uninstall
```

On OpenWrt, replace `curl` with `wget -q -O - -T 20` and keep the same URL.

Uninstallation is safe to repeat, leaves unrelated profile text intact, and
keeps the directories themselves.

## Options

| Command / option | Behavior |
| --- | --- |
| `--install` | Configure remote startup; do not save a local script. |
| `--install --local` | Save `~/.local/bin/sysinfo.sh` and configure startup for it. |
| `--uninstall` | Remove managed startup and any installed local copy. |
| `--proxy URL` | With `--install`, save a proxy for remote startup. |
| `--interactive-only` | Print only when stdin/stdout are attached to terminals. |
| `--details` | Show all selected local filesystems and IPv4 interfaces. |
| `--all-interfaces` | Show all IPv4 interfaces, including virtual ones. |
| `--color` / `--no-color` | Force ANSI colors on or off. |
| `--help` | Show usage. |

### Bars and colors

| Usage | Color |
| --- | --- |
| Below 80% | Green |
| 80–94% | Yellow |
| 95% and above | Red with `!` |

Percentages come from `df`, accounting for available space and filesystem
reserves. Capacities are not added together, and repeated mounts are hidden.
Color turns off automatically for redirected output, `TERM=dumb`, or `NO_COLOR`.

UTF-8 uses even-width `█`/`░` cells; the fallback uses `=`/`-`.
On OpenWrt without a configured locale, UTF-8 is inferred from the terminal.
Override it with `SYSINFO_UTF8=1` or `SYSINFO_UTF8=0`.
Separator lengths follow the output and terminal width (`COLUMNS`).

## Compatibility

| Platform | Notes |
| --- | --- |
| Linux / Debian | Reads `/proc`, local disks through `df`, and networks through `ip` or `ifconfig`. Docker and other service interfaces are hidden by default. |
| OpenWrt / BusyBox | Uses `ash`, `awk`, `df`, and `ip`; Bash is unnecessary. Shows all active IPv4 interfaces, SoC/ARM CPU, and board model when available. |
| macOS | Uses built-in `sysctl`, `vm_stat`, `sw_vers`, BSD `df`, and `ifconfig`. |

Base requirements are `sh`, `cat`, `uname`, `awk`, and `df`. Installation also
needs `mkdir`, `mktemp`, `chmod`, `mv`, and `rm`. Local execution needs neither
`curl` nor `wget`; if both are absent, the script suggests installing a downloader.
Configuring startup needs `cp`, `cmp`, and `mktemp`; Bash is not required.

On OpenWrt, the remote startup command above works with `wget`, `mktemp`, `rm`,
and stock `ash` (`sh`). `/overlay` does not duplicate the root filesystem,
`/tmp` is shown separately, and immutable squashfs images are skipped. The profile
selector uses `~/.profile` when `SHELL` does not identify Bash.

macOS behavior is covered by system-command fixtures; testing on a real Mac
remains necessary. RAM derived from `vm_stat` estimates usage, not Activity
Monitor's memory-pressure measurement.

<details>
<summary><strong>Upgrading from an older version</strong></summary>

`sysinfo.sh` is the sole entry point. The old `sysinfo_v2.sh` has been removed;
replace that filename in URLs and local commands with `sysinfo.sh`.
The full example `.bashrc` is also removed. Use the short startup command above
and preserve your own shell settings.

</details>

## Development

```sh
sh sysinfo.sh
sh sysinfo.sh --details
python3 -m unittest discover -s tests -v
```

Tests cover Linux, macOS/OpenWrt command fixtures, interactive Bash with a
terminal, silent non-interactive startup, repeated installation/removal,
legacy startup migration, proxy downloads, profile backups, and write failures.

<details>
<summary><strong>Additional checks</strong></summary>

Run with actual BusyBox applets:

```sh
SYSINFO_TEST_SH=/path/to/busybox-bin/sh \
SYSINFO_TEST_AWK=/path/to/busybox-bin/awk \
python3 -m unittest discover -s tests -v
```

Lint the entry point and embedded implementation:

```sh
shellcheck sysinfo.sh
awk 'BEGIN { print "sysinfo_payload=" } /^sysinfo_payload=\$\(cat/ { body=1; next } /^SYSINFO_PAYLOAD$/ { exit } body' sysinfo.sh | shellcheck -s sh -
```

</details>

## License

[MIT](LICENSE) © NorD.
