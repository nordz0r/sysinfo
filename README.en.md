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
- **Optional installation:** run immediately without flags; save a local copy only with `--install`.

**Contents:** [Quick start](#quick-start) · [Shell startup](#shell-startup) · [Options](#options) · [Compatibility](#compatibility) · [Development](#development)

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Or use `wget`:

```sh
wget -q -O - -T 5 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Use a trusted source and review the code before execution. Piping is simple, but
downloading to a file is safer if the download is incomplete.

## Shell startup

### Configure GitHub startup

Install a copy at `~/.local/bin/sysinfo.sh`:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
```

Configure startup for the installed copy separately:

```sh
sh "$HOME/.local/bin/sysinfo.sh" setup --local
```

`SHELL` selects the profile: Bash uses `~/.bashrc`; all other values, including
an unset `SHELL`, use `~/.profile`.

**OpenWrt:**

```sh
wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
```

Then configure startup separately with `sh "$HOME/.local/bin/sysinfo.sh" setup --local`.
The `wget` options are written separately for OpenWrt compatibility.

#### Optional: run remotely without installing a local copy

To configure remote startup, run:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- setup
```

Setup detects `curl`, or `wget` if curl is absent. If neither downloader is
available, it leaves the profile unchanged. The remote hook fetches the current
script and pipes it to `sh` only in an interactive shell with terminal stdin and
stdout. Commands such as `ssh host command`, `scp`, cron jobs, and redirected
output do not print the summary; download failures do not interrupt startup. An
incomplete download may execute a partial script; downloading to a file is safer.

`~/.profile` is the standard POSIX login profile, but not every shell reads it.
Startup hooks in that file are not universal for shells that do not read it or
do not support POSIX shell hooks; configure the appropriate file manually for
those shells.

#### Using a proxy

For the remote-startup option, set a proxy for the initial download and future
fetches; replace `proxy.example.com:3128` with your proxy address.

```sh
sysinfo_proxy='http://proxy.example.com:3128'; curl -fsSL --proxy "$sysinfo_proxy" https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- setup --proxy "$sysinfo_proxy"
```

The `--proxy` address is saved in the selected downloader command. Pass it again
when reconfiguring; without it, the hook uses normal proxy settings from the
environment. Use an `http://` proxy for compatibility with both downloaders; an
`https://` proxy requires curl. For the initial download with `wget`, set
`https_proxy` and `http_proxy`:

```sh
sysinfo_proxy='http://proxy.example.com:3128'; https_proxy="$sysinfo_proxy" http_proxy="$sysinfo_proxy" wget -q -O - -T 20 https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- setup --proxy "$sysinfo_proxy"
```

#### Migrating legacy startup entries

To replace settings created by the former `--setup-bash` option, run `setup`
again. It updates the startup file selected from `SHELL` and removes recognized
sysinfo entries only from that file, including `sysinfo_v2.sh`, proxy variants,
local calls, and previous managed blocks. Entries in another startup file are
not changed. If an old call used a proxy, pass it again with `--proxy`; other
settings in the selected profile are preserved.

Before the first change, the selected profile is backed up with the
`.sysinfo.bak` suffix; an existing backup is never overwritten. Repeating setup
does not add duplicates. A symlink at the profile path is left unchanged. To
disable startup, remove the block from `# >>> sysinfo >>>` through
`# <<< sysinfo <<<`, including both markers.

<details>
<summary><strong>Offline use after installation</strong></summary>

The primary command above installs `~/.local/bin/sysinfo.sh` and configures
startup to run that local copy, so later logins do not need network access.
To update an already installed copy from a checkout, run:

```sh
sh sysinfo.sh --install
```

Installation does not edit the profile. If you installed the local copy
separately, configure its startup hook with:

```sh
sh "$HOME/.local/bin/sysinfo.sh" setup --local
```

Run or remove the installed copy:

```sh
sh "$HOME/.local/bin/sysinfo.sh"
sh "$HOME/.local/bin/sysinfo.sh" --uninstall
```

Removal deletes only the script. Directories and shell settings remain intact;
the local startup line silently skips the missing executable.

</details>


## Options

| Command / option | Behavior |
| --- | --- |
| `--install` | Create or update `~/.local/bin/sysinfo.sh`. |
| `--uninstall` | Remove the installed copy. |
| `setup` | Configure startup in `~/.bashrc` for Bash or `~/.profile` for other shells, replacing legacy sysinfo entries. |
| `--proxy URL` | Save an HTTP(S) proxy for startup configured with `setup`. |
| `--local` | With `setup`, run the installed local copy instead. |
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
`setup` needs `cp`, `cmp`, and `mktemp`; Bash is not required.

On OpenWrt, the automatic setup command above works with `wget`, `mktemp`, `rm`,
and stock `ash` (`sh`). `/overlay` does not duplicate the root filesystem,
`/tmp` is shown separately, and immutable squashfs images are skipped. Setup selects
`~/.profile` when `SHELL` does not identify Bash.

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
