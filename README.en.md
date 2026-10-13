<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset=".github/assets/banner-light.svg">
    <img alt="nordz0r/sysinfo — Linux system summary" src=".github/assets/banner-light.svg" width="100%">
  </picture>
</p>

<p align="center"><a href="README.md">Русский</a> · <b>English</b></p>

<p align="center">
  <img alt="bash" src="https://img.shields.io/badge/bash-script-4eaa25?style=flat-square&logo=gnubash&logoColor=white">
  <img alt="OpenWrt" src="https://img.shields.io/badge/OpenWrt%2FBusyBox-v2-00b5e2?style=flat-square">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"></a>
</p>

A bash script that prints a machine summary in one command: hostname, CPU model and core count, frequency, disk size and usage, RAM and swap, uptime, load average, OS, architecture, kernel, and IP addresses.

## Usage

Version 1 (original):

```bash
curl -Lso- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash
# or
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash
```

Version 2 (backward compatible, for embedded systems like OpenWrt/BusyBox):

```bash
curl -Lso- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash
# or
wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash
```

Requires `curl` or `wget`. Review the script before piping it to `bash`.

### Changes in v2

- Fallback logic for hostname if `/etc/hostname` doesn't exist
- Alternative load average collection when `w` is unavailable
- CPU bitness detection without `getconf`
- `df` fixed for BusyBox compatibility (removed `-l`)
- Command availability checks before usage
- Improved IP detection

## License

MIT, see [LICENSE](LICENSE).
