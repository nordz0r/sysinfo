# sysinfo

Get Info v.1 and v.2

## Version 1 (Original)
Usage (curl): curl -Lso- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash

Usage (wget): wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash

## Version 2 (Backward Compatible)
Improved version with better compatibility for embedded systems like OpenWRT/BusyBox.

Usage (curl): curl -Lso- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash

Usage (wget): wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash

### Changes in v2:
- Fallback logic for hostname if /etc/hostname doesn't exist
- Alternative load average collection when 'w' command is unavailable
- CPU bitness detection without 'getconf' command
- Fixed 'df' command for BusyBox compatibility (removed -l option)
- Command availability checks before usage
- Improved IP detection
