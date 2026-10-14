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

**Contents:** [Quick start](#quick-start) · [Bash startup](#bash-startup) · [Options](#options) · [Compatibility](#compatibility) · [Development](#development)

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash
```

Or use `wget`:

```sh
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Use a trusted source and review the code before execution. The script prints
current information and exits without installing a copy.

## Bash startup

### Option A — GitHub, the default

Run once. This configures `~/.bashrc`, replacing legacy sysinfo entries with
one block containing a short description and repository link. No local script
installation is needed.

```bash
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash
```

If only `wget` is available:

```bash
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash
```

Each interactive Bash startup fetches the current `sysinfo.sh` from GitHub
and runs it from memory. It prefers `curl`, falls back to `wget` when curl is
absent, and suggests installing a downloader if neither exists.

Fetching starts only in interactive Bash with terminal stdin and stdout.
The fetched script checks these descriptors again through `--interactive-only`.
Non-interactive `ssh host command`, `scp`, cron jobs, and redirected output
stay free of the summary. `curl` has a total timeout of 5 seconds; `wget` uses
a 5-second network timeout and one attempt when supported.
Failed or empty downloads do not interrupt Bash startup.

#### Using a proxy

Specify the proxy for both the initial download and future startup downloads:

```bash
sysinfo_proxy='http://deb-proxy.lan:3128'
curl -fsSL --proxy "$sysinfo_proxy" https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash --proxy "$sysinfo_proxy"
```

The `--proxy` address is saved in the startup block and used by both `curl`
and `wget`. Pass it again when reconfiguring; without it, the hook uses normal
proxy settings from the environment. Use an `http://` proxy for compatibility
with both downloaders; an `https://` proxy requires `curl`.
For the initial download with `wget`, set `https_proxy` and `http_proxy`:

```bash
sysinfo_proxy='http://deb-proxy.lan:3128'
https_proxy="$sysinfo_proxy" http_proxy="$sysinfo_proxy" wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash --proxy "$sysinfo_proxy"
```

#### Migrating legacy startup entries

Setup removes old standalone `curl`/`wget` calls for this repository, including
`sysinfo_v2.sh` and calls with proxy options, documented local hooks, and blocks
from previous setup runs. A `# by NorD` comment immediately before a removed
entry is removed too. Other settings are preserved. If the old call used a
proxy, supply it with `--proxy`.

Before the first change, an existing profile is backed up to
`~/.bashrc.sysinfo.bak`; later runs preserve this backup. Repeating setup does
not add duplicates. Bash syntax is checked before replacing the profile.
If an old call is part of a complex construct that cannot be replaced
unambiguously, setup reports the issue and leaves the profile unchanged.
A symlink at `.bashrc` is also left unchanged. To disable startup, remove the
block from `# >>> sysinfo >>>` through `# <<< sysinfo <<<`, including both markers.

<details>
<summary><strong>Option B — local installation for offline use</strong></summary>

If GitHub is unavailable or a network request at login is unwanted, save a copy
to `~/.local/bin/sysinfo.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --install
```

Directories are created as needed, and the file gets mode `755`.
A managed copy is updated atomically; unrelated files and symlinks at the target
are preserved. Installation does not edit the shell profile.

For local startup, configure the same block in offline mode
(this replaces option A and legacy entries):

```bash
"$HOME/.local/bin/sysinfo.sh" --setup-bash --local
```

Run or remove the installed copy:

```sh
"$HOME/.local/bin/sysinfo.sh"
"$HOME/.local/bin/sysinfo.sh" --uninstall
```

Removal deletes only the script. Directories and shell settings remain intact;
the local startup line silently skips the missing executable.
From a checkout, use `sh sysinfo.sh --install` or `sh sysinfo.sh --uninstall`.

</details>

## Options

| Flag | Behavior |
| --- | --- |
| `--install` | Create or update `~/.local/bin/sysinfo.sh`. |
| `--uninstall` | Remove the installed copy. |
| `--setup-bash` | Configure GitHub startup in `~/.bashrc`, replacing legacy sysinfo entries. |
| `--proxy URL` | Save an HTTP(S) proxy for `--setup-bash`. |
| `--local` | With `--setup-bash`, run the installed local copy instead. |
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
`--setup-bash` additionally needs Bash, `cp`, `cmp`, and `mktemp`.

On OpenWrt, `/overlay` does not duplicate the root filesystem, `/tmp` is shown
separately, and immutable squashfs images are skipped. Stock `ash` does not read
`~/.bashrc`; put an equivalent `case $-` startup check in `~/.profile` instead.

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
