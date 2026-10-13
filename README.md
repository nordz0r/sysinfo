<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset=".github/assets/banner-light.svg">
    <img alt="nordz0r/sysinfo — system summary" src=".github/assets/banner-light.svg" width="100%">
  </picture>
</p>

One lightweight script that detects its platform and prints a compact English
table. `sysinfo.sh` handles Linux (including Debian and OpenWrt/BusyBox) and macOS.
It works with POSIX `sh`, BusyBox `ash`, and Bash, including macOS's system Bash.

## Usage

From a checkout:

```sh
sh sysinfo.sh
sh sysinfo.sh --details
```

Run from the remote entry point without saving a file:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
# Alternatively:
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh
```

Use a trusted source; review the script before executing it. Without an install
flag the script collects current information immediately and saves no copy.

Local execution needs `cat`, `uname`, `awk`, and `df`, which are normally system tools.
Linux uses `/proc`; macOS uses `sysctl`, `vm_stat`, `sw_vers`, and `date`.
Network information uses `ip` when available on Linux, otherwise `ifconfig`.
Missing optional data is marked as unavailable.

`curl` or `wget` is only required for downloading. If neither is available, the
script suggests installation and still collects local information.
On Debian use `sudo apt install curl`; on OpenWrt use `opkg install curl` or
`apk add curl`, depending on the release. macOS includes `/usr/bin/curl`.
Bash does not need to be installed on OpenWrt.

The old `sysinfo_v2.sh` URL contains a generated, identical compatibility copy.
It runs directly without fetching a second script. Existing `| bash` invocations
still work. All implementation changes belong in `sysinfo.sh`; synchronize the
compatibility copy with `cp sysinfo.sh sysinfo_v2.sh`. Tests check byte equality.

## Install and uninstall

Saving a local executable is optional and explicit:

```sh
sh sysinfo.sh --install
"$HOME/.local/bin/sysinfo.sh"
sh sysinfo.sh --uninstall
```

`--install` creates `~/.local/bin` as needed and writes `sysinfo.sh` with mode
`755`. Reinstalling atomically updates a managed copy. Unrelated files,
directories, and symlinks at the target are preserved and reported.
`--uninstall` removes only the managed script, leaves directories in place, and
succeeds if no copy is installed. Neither operation changes shell profiles.

Installation also works through a pipe, without another network request:

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
# Alternatively:
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | sh -s -- --install
```

To enable the installed copy at every Bash startup, run the manual commands
shown in the script header. The startup line invokes the script; all collection
and rendering functions remain inside it:

```sh
sysinfo_hook='[ ! -x "$HOME/.local/bin/sysinfo.sh" ] || "$HOME/.local/bin/sysinfo.sh"'
grep -qxF "$sysinfo_hook" "$HOME/.bashrc" 2>/dev/null || printf '\n%s\n' "$sysinfo_hook" >> "$HOME/.bashrc"
```

The command adds the line once and handles a missing `.bashrc`. After uninstall,
the startup line silently does nothing; it can be removed manually if desired.

## Output

A compact `Label : value` list (about 12-17 lines), no table borders, thin
dashed separators:

```
--------------------------------------------------------
Hostname   : dd.goldfinches.ru
OS         : Debian GNU/Linux 12 (bookworm), x86_64, 6.1.0-52-amd64
CPU        : 4 × Intel Core i5-10400 @ 2.90GHz
Uptime     : 6d 23h 37m
Load       : 0.17, 0.49, 0.65
--------------------------------------------------------
RAM        : █████████████████░░░  84%    8.1G / 9.7G
Swap       : █████░░░░░░░░░░░░░░░  27%    1.1G / 4.0G

/          : ███████████████░░░░░  75%    34.8G / 49.0G
/mnt/hdd   : ███████████████████░  95% !  87.4G / 97.9G
/mnt/iscsi : ███████████░░░░░░░░░  56%    76.3G / 143.6G
--------------------------------------------------------
IP         : ens160 10.0.0.118
--------------------------------------------------------
```

- OS line also carries the architecture and kernel; load average has its own line.
- CPU model is cleaned of `(R)`, `(TM)` and the word `CPU`.
- RAM and swap, then (after a blank line) up to four local filesystems (root first, then the fullest).
  Container/kubelet bind mounts, `/run`, WSL helper mounts and read-only
  images are skipped. `--details` shows every filesystem.
- Separators follow the longest line, capped by the terminal width (`COLUMNS`/`tput cols`).
- Filesystems with identical size and usage (e.g. `/` and `/overlay`) are shown once.
- IP: up to three `interface address` pairs, default route first (all on OpenWrt);
  one interface per line when they do not fit.
  Docker and overlay interfaces (`docker*`, `br-<hex>`, `veth*`, `flannel*`,
  `cni*`, `cali*`, `vxlan*`, ...) are hidden unless `--all-interfaces`.

Bars use full blocks `█` with a dim `░` remainder when the locale is UTF-8, or when
no locale is set and `TERM` is a common UTF-8 terminal (OpenWrt); `SYSINFO_UTF8=0|1`
overrides (no
fractional blocks: they render unevenly in many fonts) and fall back to ASCII
(`=`/`-`) otherwise. Colors: green below **80%**, yellow from 80%, red with `!`
from **95%**.
Percentages come from `df`, accounting for available space and filesystem
reserves, rather than being recomputed from rounded display sizes.

Disk capacities are not summed: repeated mounts of the same device are deduplicated,
and APFS volumes are displayed individually without adding shared capacity.
Linux queries recognized local filesystem types from `/proc/self/mounts`; macOS
uses BSD `df -l`. Network mounts, memory filesystems, and immutable squashfs
firmware images are excluded on Linux.
Sizes use KiB/MiB/GiB. macOS RAM usage is an estimate from `vm_stat`, not Activity
Monitor's memory-pressure measurement.

| Option | Behavior |
| --- | --- |
| `--install` | Save an executable copy to `~/.local/bin/sysinfo.sh`. |
| `--uninstall` | Remove only the managed local copy. |
| `--details` | Show all selected local filesystems and all IPv4 interfaces, including Docker. |
| `--all-interfaces` | Expand only the network list, including Docker. |
| `--color` | Force ANSI colors. |
| `--no-color` | Disable ANSI colors. |
| `--help` | Show usage. |

Colors are enabled automatically only for a terminal, unless `TERM=dumb` or
`NO_COLOR` is set. Long labels and values are shortened to preserve table width.
Local execution makes no network requests, uses one `awk` process for parsing
and rendering, and invokes `df` and the network tool once.

## Validation

The functional suite needs Python 3 and no third-party packages:

```sh
python3 -m unittest discover -s tests -v
```

It covers live Linux execution, macOS/OpenWrt command-output fixtures, warning
thresholds, compact limits with 100 disks and interfaces, missing tools, and
transient pipe execution, self-install/uninstall, and unchanged shell profiles.
macOS fixtures do not replace testing on a real Mac.

To repeat the fixture suite with actual BusyBox applets, point these variables at
its `sh` and `awk` applet symlinks (named `sh` and `awk`):

```sh
SYSINFO_TEST_SH=/path/to/busybox-bin/sh \
SYSINFO_TEST_AWK=/path/to/busybox-bin/awk \
python3 -m unittest discover -s tests -v
```

Optional lint for the entry point and embedded implementation:

```sh
shellcheck sysinfo.sh sysinfo_v2.sh
awk 'BEGIN { print "sysinfo_payload=" } /^sysinfo_payload=\$\(cat/ { body=1; next } /^SYSINFO_PAYLOAD$/ { exit } body' sysinfo.sh | shellcheck -s sh -
```

## License

MIT, see [LICENSE](LICENSE).

## OpenWrt

BusyBox `ash`/`awk`/`df`/`ip` are enough; nothing to install. On OpenWrt the
overlay upper dir (`/overlay`, same space as `/`) is hidden, `/tmp` (tmpfs) is
shown, ARM CPUs are named from `CPU part` (e.g. `ARM Cortex-A53`) plus the board
from `/tmp/sysinfo/model`; the SoC comes from the device tree, e.g.
`2 × MediaTek MT7981 (Cudy WBR3000UAX v1)`.

Offline-safe autostart for interactive logins only (keeps `scp`/`ssh host cmd` clean):

```sh
curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh -o /usr/bin/sysinfo
chmod 755 /usr/bin/sysinfo
cat > /etc/profile.d/90-sysinfo.sh <<'X'
case $- in *i*) [ -t 1 ] && [ -x /usr/bin/sysinfo ] && /usr/bin/sysinfo ;; esac
X
printf '%s\n' /usr/bin/sysinfo /etc/profile.d/90-sysinfo.sh >> /etc/sysupgrade.conf
```

