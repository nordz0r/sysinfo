#!/bin/sh
# sysinfo-managed-install: 1
# Run immediately; save a copy only with --install.
sysinfo_payload=$(cat <<'SYSINFO_PAYLOAD'
#!/bin/sh
# Sysinfo: one lightweight entry point for Linux, BusyBox/OpenWrt and macOS.
# Copyright (C) 2019 NorD. MIT license.

# Default: load the current GitHub script at each interactive Bash startup.
# Run once to configure ~/.bashrc (backs up and replaces legacy sysinfo entries).
# BEGIN BASH STARTUP
# curl -fsSL https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash
# END BASH STARTUP
# With a proxy (used now and saved for subsequent startup downloads):
# sysinfo_proxy='http://deb-proxy.lan:3128'
# curl -fsSL --proxy "$sysinfo_proxy" https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh | bash -s -- --setup-bash --proxy "$sysinfo_proxy"
# Without curl: wget -qO- <same URL> | bash -s -- --setup-bash
# Offline option B: --install saves a local executable; see README for its hook.
# --install/--uninstall never edit .bashrc; all collection/rendering stays here.

# POSIX syntax also works with the system Bash 3.2 on macOS.
# Decide on Unicode bars before forcing the C locale for parsing.
# Explicit locale wins; with no locale at all (OpenWrt) trust common UTF-8 terminals.
utf8=0
sysinfo_locale=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
case "$sysinfo_locale" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) utf8=1 ;;
    '') case "${TERM:-}" in xterm*|screen*|tmux*|rxvt*|alacritty|foot*|wezterm|vt220|linux) utf8=1 ;; esac ;;
esac
case "${SYSINFO_UTF8:-}" in 1) utf8=1 ;; 0) utf8=0 ;; esac
LC_ALL=C
export LC_ALL
set -f
details=0
all_interfaces=0
color=auto
action=report
interactive_only=0
setup_proxy=
setup_proxy_set=0
setup_local=0
while [ "$#" -gt 0 ]; do
    arg=$1
    shift
    case "$arg" in
        --install|--uninstall|--setup-bash)
            if [ "$action" != report ] && [ "$action" != "$arg" ]; then
                printf '%s\n' 'Use only one of --install, --uninstall or --setup-bash.' >&2
                exit 2
            fi
            action=$arg ;;
        --details) details=1; all_interfaces=1 ;;
        --all-interfaces) all_interfaces=1 ;;
        --interactive-only) interactive_only=1 ;;
        --local) setup_local=1 ;;
        --proxy)
            if [ "$#" -eq 0 ]; then
                printf '%s\n' '--proxy requires a URL (or an empty string to use environment settings).' >&2
                exit 2
            fi
            setup_proxy=$1; setup_proxy_set=1; shift ;;
        --no-color) color=never ;;
        --color) color=always ;;
        -h|--help)
            printf '%s\n' 'Usage: sysinfo.sh [--install|--uninstall] [--details] [--all-interfaces]' \
                '                  [--interactive-only] [--color|--no-color]' \
                '       sysinfo.sh --setup-bash [--proxy URL | --local]' \
                'Default: four local filesystems, three interfaces (all on OpenWrt).' \
                '--details: show all local filesystems and interfaces.' \
                '--interactive-only: print only when stdin and stdout are terminals.' \
                '--install: save an executable copy to ~/.local/bin/sysinfo.sh.' \
                '--uninstall: remove that copy; leave the directories in place.' \
                '--setup-bash: migrate sysinfo startup entries in ~/.bashrc (with backup).' \
                '--proxy URL: save an HTTP(S) proxy for GitHub startup; HTTPS needs curl.' \
                '--local: configure Bash startup using the installed copy instead.'
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
if { [ "$setup_proxy_set" -eq 1 ] || [ "$setup_local" -eq 1 ]; } && [ "$action" != --setup-bash ]; then
    printf '%s\n' '--proxy and --local require --setup-bash.' >&2
    exit 2
fi

# Profile changes are a separate, explicit action. Reporting stays read-only.
if [ "$action" = --setup-bash ]; then
    install_home=${HOME:-}
    case "$install_home" in
        /*) ;;
        *) printf '%s\n' 'HOME must be set to an absolute directory for Bash setup.' >&2; exit 1 ;;
    esac
    if [ "$setup_local" -eq 1 ] && [ "$setup_proxy_set" -eq 1 ]; then
        printf '%s\n' '--proxy cannot be combined with --local.' >&2
        exit 2
    fi
    case "$setup_proxy" in
        ''|http://?*|https://?*) ;;
        *) printf '%s\n' 'Use an http:// or https:// proxy URL for curl/wget.' >&2; exit 2 ;;
    esac
    for tool in bash awk cat mktemp cp cmp mv rm; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'Required Bash setup command missing: %s\n' "$tool" >&2
            exit 1
        fi
    done
    setup_profile=$install_home/.bashrc
    setup_backup=$setup_profile.sysinfo.bak
    if [ -L "$setup_profile" ] || { [ -e "$setup_profile" ] && [ ! -f "$setup_profile" ]; }; then
        printf 'Refusing to modify a symlink or non-regular file: %s\n' "$setup_profile" >&2
        exit 1
    fi
    setup_tmp=$(mktemp "$install_home/.sysinfo-bashrc.XXXXXX") || exit 1
    trap 'if [ -n "$setup_tmp" ]; then rm -f "$setup_tmp"; fi' 0
    trap 'exit 1' HUP INT TERM
    setup_input=/dev/null
    if [ -f "$setup_profile" ]; then
        setup_input=$setup_profile
        # Preserve the original permissions when replacing the profile.
        cp -p "$setup_profile" "$setup_tmp" || exit 1
    fi
    # Exact pre-marker hook emitted by older releases. Match it as a whole so
    # a user's larger case statement cannot lose unrelated commands.
    setup_legacy_hook=$(cat <<'SYSINFO_LEGACY_BASHRC'
case $- in
  *i*) if [ -t 0 ] && [ -t 1 ]; then (
    sysinfo_url=https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh;
    if command -v curl >/dev/null 2>&1; then
      sysinfo_code=$(curl -fsSL --connect-timeout 2 --max-time 5 "$sysinfo_url") || exit;
    elif command -v wget >/dev/null 2>&1; then
      sysinfo_args=(-qO- -T5);
      if wget --help 2>&1 | grep -q -- --tries; then sysinfo_args+=(-t1); fi;
      sysinfo_code=$(wget "${sysinfo_args[@]}" "$sysinfo_url") || exit;
    else
      printf '%s\n' 'sysinfo: install curl or wget for GitHub startup.' >&2; exit 1;
    fi;
    [ -n "$sysinfo_code" ] && "$BASH" -c "$sysinfo_code" sysinfo.sh --interactive-only;
  ) || :; fi ;;
esac
SYSINFO_LEGACY_BASHRC
    ) || exit 1
    # Match this repository and the documented local hooks, never just "sysinfo".
    # Unrecognised compound commands abort the update rather than losing content.
    if ! SYSINFO_LEGACY_HOOK="$setup_legacy_hook" awk '
        function flush() { if (pending != "") print pending; pending = "" }
        function normal(s) {
            gsub(/[[:space:]]+/, " ", s)
            sub(/^ /, "", s); sub(/ $/, "", s)
            return s
        }
        BEGIN {
            oldhook = normal(ENVIRON["SYSINFO_LEGACY_HOOK"])
            remote = "https://raw[.]githubusercontent[.]com/nordz0r/sysinfo/(master|main)/sysinfo(_v2)?[.]sh([[:space:]\047\042;]|$)"
            localpath = "(\\$HOME|\\$[{]HOME[}]|~)/[.]local/bin/sysinfo[.]sh"
            localfile = "[\042\047]?" localpath "[\042\047]?"
            localcall = localfile "([[:space:]]+--interactive-only)?"
            localguard = "\\[ ! -x " localfile " \\] [|][|] " localcall
        }
        {
            line = $0
            sub(/^[[:space:]]*/, "", line); sub(/[[:space:]]*$/, "", line)
            if (line == "# >>> sysinfo >>>") {
                if (managed) exit 2
                flush(); managed = 1; next
            }
            if (line == "# <<< sysinfo <<<") {
                if (!managed) exit 2
                managed = 0; next
            }
            if (managed) next
            if (line == "# by NorD") { flush(); pending = $0; next }
            if (line ~ /^#/ || line == "") { flush(); print; next }
            owned = line ~ remote || line ~ localpath
            legacy = 0
            if (line ~ remote) {
                if (line ~ /^(curl|wget)[[:space:]]/ && line ~ /[|][[:space:]]*(bash|sh)([[:space:]]+-s[[:space:]]+--)?([[:space:]]+#.*)?$/) {
                    download = line; sub(/[|].*$/, "", download)
                    legacy = download !~ /[;&`<>|]/ && download !~ /\$\(/
                }
                # Previous releases generated this complete, single-line hook.
                if (normal(line) == oldhook) legacy = 1
            } else if (line ~ localpath) {
                if (line ~ "^(sh[[:space:]]+|bash[[:space:]]+)?" localcall "$") legacy = 1
                if (line ~ "^case \\$- in [*]i[*][)] " localguard " ;; esac$") legacy = 1
                if (line ~ "^" localguard "$") legacy = 1
            }
            if (legacy) { pending = ""; next }
            if (owned) { bad = NR; exit 2 }
            flush(); print
        }
        END {
            flush()
            if (managed || bad) exit 2
        }
    ' "$setup_input" > "$setup_tmp"; then
        printf '%s\n' 'Could not safely migrate existing sysinfo entries; .bashrc was left unchanged.' >&2
        exit 1
    fi
    # Quote as Bash data, including spaces, quotes and shell metacharacters.
    setup_quoted_proxy=$(bash -c 'printf "%q" "$1"' sysinfo "$setup_proxy") || exit 1
    if ! {
        printf '%s\n' '# >>> sysinfo >>>' \
            '# Sysinfo: lightweight system summary at interactive Bash startup.' \
            '# https://github.com/nordz0r/sysinfo'
        if [ "$setup_local" -eq 1 ]; then
            cat <<'SYSINFO_LOCAL_BASHRC'
case $- in
  *i*) [ ! -x "$HOME/.local/bin/sysinfo.sh" ] || "$HOME/.local/bin/sysinfo.sh" --interactive-only ;;
esac
SYSINFO_LOCAL_BASHRC
        else
            printf 'case $- in\n  *i*) if [ -t 0 ] && [ -t 1 ]; then (\n    sysinfo_proxy=%s\n' "$setup_quoted_proxy"
            cat <<'SYSINFO_REMOTE_BASHRC'
    sysinfo_url=https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo.sh
    if command -v curl >/dev/null 2>&1; then
      set -- -fsSL --connect-timeout 2 --max-time 5
      if [ -n "$sysinfo_proxy" ]; then set -- "$@" --proxy "$sysinfo_proxy"; fi
      sysinfo_code=$(curl "$@" "$sysinfo_url") || exit
    elif command -v wget >/dev/null 2>&1; then
      set -- -qO- -T5
      if wget --help 2>&1 | grep -q -- --tries; then set -- "$@" -t1; fi
      if [ -n "$sysinfo_proxy" ]; then
        sysinfo_code=$(https_proxy="$sysinfo_proxy" http_proxy="$sysinfo_proxy" wget "$@" "$sysinfo_url") || exit
      else
        sysinfo_code=$(wget "$@" "$sysinfo_url") || exit
      fi
    else
      printf '%s\n' 'sysinfo: install curl or wget for GitHub startup.' >&2; exit 1
    fi
    [ -n "$sysinfo_code" ] && "$BASH" -c "$sysinfo_code" sysinfo.sh --interactive-only
  ) || :; fi ;;
esac
SYSINFO_REMOTE_BASHRC
        fi
        printf '%s\n' '# <<< sysinfo <<<'
    } >> "$setup_tmp"; then
        printf '%s\n' 'Could not write the Bash startup block.' >&2
        exit 1
    fi
    if ! bash -n "$setup_tmp"; then
        printf '%s\n' 'Bash syntax validation failed; .bashrc was left unchanged.' >&2
        exit 1
    fi
    if [ -f "$setup_profile" ] && cmp -s "$setup_tmp" "$setup_profile"; then
        printf 'Bash startup already configured: %s\n' "$setup_profile"
        exit 0
    fi
    if [ -f "$setup_profile" ] && [ ! -e "$setup_backup" ] && [ ! -L "$setup_backup" ]; then
        cp -p "$setup_profile" "$setup_backup" || exit 1
        printf 'Backup: %s\n' "$setup_backup"
    fi
    mv -f "$setup_tmp" "$setup_profile" || exit 1
    setup_tmp=
    printf 'Configured Bash startup: %s\n' "$setup_profile"
    exit 0
fi

# Installation is explicit. Neither reporting nor uninstall creates directories.
if [ "$action" != report ]; then
    install_home=${HOME:-}
    case "$install_home" in
        /*) ;;
        *) printf '%s\n' 'HOME must be set to an absolute directory for installation.' >&2; exit 1 ;;
    esac
    install_dir=$install_home/.local/bin
    install_target=$install_dir/sysinfo.sh
    if [ -L "$install_target" ] || { [ -e "$install_target" ] && [ ! -f "$install_target" ]; }; then
        printf 'Refusing to modify a symlink or non-regular file: %s\n' "$install_target" >&2
        exit 1
    fi
    if [ -e "$install_target" ]; then
        # Do not overwrite or remove an unrelated user file at the same path.
        {
            IFS= read -r install_first
            IFS= read -r install_marker
        } < "$install_target"
        if [ "$install_first" != '#!/bin/sh' ] || [ "$install_marker" != '# sysinfo-managed-install: 1' ]; then
            printf 'Refusing to modify an unmanaged file: %s\n' "$install_target" >&2
            exit 1
        fi
    fi
    if [ "$action" = --uninstall ]; then
        if [ ! -e "$install_target" ]; then
            printf 'Not installed: %s\n' "$install_target"
            exit 0
        fi
        if ! rm "$install_target"; then
            printf 'Could not remove: %s\n' "$install_target" >&2
            exit 1
        fi
        printf 'Uninstalled: %s\n' "$install_target"
        exit 0
    fi
    for tool in mkdir mktemp chmod mv rm; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'Required installation command missing: %s\n' "$tool" >&2
            exit 1
        fi
    done
    if ! mkdir -p "$install_dir"; then
        printf 'Could not create installation directory: %s\n' "$install_dir" >&2
        exit 1
    fi
    install_tmp=$(mktemp "$install_dir/.sysinfo.XXXXXX") || exit 1
    trap 'if [ -n "$install_tmp" ]; then rm -f "$install_tmp"; fi' 0
    trap 'exit 1' HUP INT TERM
    # Recreate the self-contained entry point from its in-memory source. This
    # also works when a shell received the script through a pipe: no HTTP retry.
    if ! {
        printf '%s\n' '#!/bin/sh' '# sysinfo-managed-install: 1' \
            '# Run immediately; save a copy only with --install.' \
            "sysinfo_payload=\$(cat <<'SYSINFO_PAYLOAD'"
        printf '%s\n' "$sysinfo_payload"
        # Preserve the variable reference for the installed script itself.
        # shellcheck disable=SC2016
        printf '%s\n' 'SYSINFO_PAYLOAD' ') || exit 1' 'eval "$sysinfo_payload"'
    } > "$install_tmp"; then
        printf '%s\n' 'Could not write the installed script.' >&2
        exit 1
    fi
    if ! chmod 755 "$install_tmp" || ! mv -f "$install_tmp" "$install_target"; then
        printf 'Could not install: %s\n' "$install_target" >&2
        exit 1
    fi
    install_tmp=
    printf 'Installed: %s\n' "$install_target"
    exit 0
fi

# The parent shell checks its interactive flag in the .bashrc hook. A script
# itself runs in a non-interactive child shell, so check terminal descriptors.
if [ "$interactive_only" -eq 1 ] && { [ ! -t 0 ] || [ ! -t 1 ]; }; then
    exit 0
fi

# Terminal width caps the separators (0 = unknown).
cols=${COLUMNS:-0}
case "$cols" in ''|*[!0-9]*) cols=0 ;; esac
if [ "$cols" = 0 ] && [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    cols=$(tput cols 2>/dev/null) || cols=0
    case "$cols" in ''|*[!0-9]*) cols=0 ;; esac
fi
openwrt=0
[ -s /etc/openwrt_release ] && openwrt=1

for tool in uname awk df; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 1
    fi
done
platform=$(uname -snrm) || exit 1
IFS=' ' read -r system host kernel arch <<EOF
$platform
EOF
case "$system" in
    Linux|Darwin) ;;
    *) printf 'Unsupported system: %s (supported: Linux and macOS).\n' "$system" >&2; exit 1 ;;
esac

# Downloaders are needed for remote installation, never for local metrics.
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    if command -v opkg >/dev/null 2>&1; then tip='opkg install curl'
    elif command -v apk >/dev/null 2>&1; then tip='apk add curl'
    elif [ "$system" = Darwin ]; then tip='use the built-in /usr/bin/curl'
    elif [ -f /etc/debian_version ]; then tip='sudo apt install curl'
    else tip='install curl or wget with your package manager'
    fi
    printf 'Tip: curl/wget not found; to download sysinfo, %s.\n' "$tip" >&2
fi
use_color=0
case "$color" in
    always) use_color=1 ;;
    auto) if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ "${NO_COLOR+x}" != x ]; then use_color=1; fi ;;
esac

collect() {
    if [ "$system" = Darwin ]; then
        printf '[OS]\n'
        if command -v sw_vers >/dev/null 2>&1; then sw_vers -productVersion; fi
        printf '[MACSYS]\n'
        if command -v sysctl >/dev/null 2>&1; then
            sysctl hw.ncpu hw.memsize hw.model machdep.cpu.brand_string kern.boottime vm.swapusage vm.loadavg 2>/dev/null
        fi
        printf '[MACMEM]\n'
        if command -v vm_stat >/dev/null 2>&1; then vm_stat; fi
        printf '[NOW]\n'
        date +%s
        printf '[ROUTE]\n'
        if command -v route >/dev/null 2>&1; then route -n get default 2>/dev/null; fi
        printf '[DISK]\n'
        # BSD df supports -l; do not query remote mounts.
        df -kPl 2>/dev/null || printf '[DISKERROR]\n'
    else
        # Supply only local mount points: BusyBox df has no portable -l option.
        set --
        sources='|'
        # OpenWrt: hide the overlay upper dir (same space as /), keep /tmp tmpfs.
        overlay_upper=
        if [ -r /proc/self/mounts ]; then
            while read -r source mount rest; do
                case "$source" in overlayfs:/*) overlay_upper=${source#overlayfs:} ;; esac
            done < /proc/self/mounts
            while read -r source mount type opts rest; do
                # Container/kubelet bind mounts duplicate real disks and are often unreadable.
                case "$mount" in
                    /run/*|/var/lib/kubelet/*|/var/lib/docker/*|/var/lib/containerd/*|/var/lib/rancher/*|/snap/*|/mnt/wsl*|/usr/lib/wsl/*|/usr/lib/modules*|/usr/src/*) continue ;;
                esac
                # Read-only images (WSL headers/modules, squashfs) are always "full".
                case "$mount,$opts" in /,*) ;; *,ro|*,ro,*) continue ;; esac
                if [ -n "$overlay_upper" ] && [ "$mount" = "$overlay_upper" ]; then continue; fi
                if [ "$openwrt" = 1 ] && [ "$type" = tmpfs ] && [ "$mount" = /tmp ]; then
                    sources="$sources$source|"; set -- "$@" "$mount"; continue
                fi
                case "$type" in
                    ext2|ext3|ext4|xfs|btrfs|zfs|overlay|f2fs|jffs2|ubifs|ufs|vfat|msdos|exfat|ntfs|ntfs3|fuseblk)
                        case "$sources" in *"|$source|"*) continue ;; esac
                        sources="$sources$source|"
                        case "$mount" in *\\*) mount=$(printf '%b' "$mount") ;; esac
                        set -- "$@" "$mount" ;;
                esac
            done < /proc/self/mounts
        fi
        printf '[DISK]\n'
        if [ "$#" -gt 0 ]; then
            df -kP "$@" 2>/dev/null || printf '[DISKERROR]\n'
        fi
    fi
    printf '[DT]\n'
    if [ -r /proc/device-tree/compatible ]; then tr '\000' '\n' < /proc/device-tree/compatible 2>/dev/null; echo; fi
    printf '[NET]\n'
    if [ "$system" = Linux ] && command -v ip >/dev/null 2>&1; then
        ip -4 addr show 2>/dev/null || printf '[NETERROR]\n'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null || printf '[NETERROR]\n'
    else
        printf '[NETERROR]\n'
    fi
}

# One awk process handles parsing, ranking, arithmetic and table rendering.
collect | awk -v os_type="$system" -v host="$host" -v kernel="$kernel" \
    -v arch="$arch" -v details="$details" -v all_interfaces="$all_interfaces" -v color="$use_color" -v utf8="$utf8" -v cols="$cols" -v openwrt="$openwrt" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function repeat(c, n, s) { if(n<=0) return ""; s=sprintf("%" n "s", ""); gsub(/ /, c, s); return s }
function fit(s, n) { if (length(s)>n) s=substr(s,1,n-1) "~"; return s }
function paint(s, c) { return color && c ? esc "[" c "m" s esc "[0m" : s }
function out(s) { buf[++nbuf]=s }
function rule() { buf[++nbuf]=RULE }
function vislen(s) { gsub(/\033\[[0-9;]*m/,"",s); gsub(/[\200-\277]/,"",s); return length(s) }
function flush( i,w,m) {
    m=0; for(i=1;i<=nbuf;i++) if(buf[i]!=RULE && (w=vislen(buf[i]))>m) m=w
    if(cols>0 && m>cols) m=cols
    for(i=1;i<=nbuf;i++) print (buf[i]==RULE ? paint(repeat("-",m),"2") : buf[i])
}
function row(k,v,c) { out(sprintf("%s : %s", paint(sprintf("%-" L "s",fit(k,L)),"32"), c=="raw"?v:paint(v,c?c:"36"))) }
function percent(used,total) { return total>0 ? int(used*100/total+0.5) : 0 }
function level(p) { return p>=95?"31":(p>=80?"33":"32") }
function bar(p,c, e,n,f,part) {
    p=p<0?0:(p>100?100:p)
    if(!utf8) { n=int(p*BW/100+0.5); return paint(repeat("=",n),c) paint(repeat("-",BW-n),"2") }
    n=int(p*BW/100+0.5)
    return paint(repeat("\342\226\210",n),c) paint(repeat("\342\226\221",BW-n),"2")
}
function human(k) { if(k>=1073741824) return sprintf("%.1fT",k/1073741824); if(k>=1048576) return sprintf("%.1fG",k/1048576); if(k<=0) return "0M"; return sprintf("%.1fM",k/1024) }
function resource(k,used,total,p, c) {
    c=level(p)
    out(sprintf("%s : %s %s  %s", paint(sprintf("%-" L "s",fit(k,L)),"32"), bar(p,c), \
        paint(sprintf("%3d%%",p) (p>=95?" !":"  "),c), human(used) " / " human(total)))
}
function cleancpu(s) { gsub(/\((R|r|TM|tm)\)/,"",s); gsub(/ CPU /," ",s); sub(/ CPU$/,"",s); sub(/^CPU /,"",s); gsub(/ Processor/,"",s); gsub(/  +/," ",s); return trim(s) }
function units(s, n) { n=s+0; if(s~/G$/) n*=1048576; else if(s~/M$/) n*=1024; else if(s~/T$/) n*=1073741824; return n }
function docker(s) { return s~/^docker[0-9]*$/ || s~/^veth/ || (length(s)==15 && s~/^br-[0-9a-f]+$/) }
function virtual(s) { return docker(s) || s~/^(flannel|cni|cali|vxlan|kube-|virbr|tunl|lxcbr|weave|cilium|genev)/ }
function linux_stats( line,a,key,value,free_mem,cache,available,model) {
    while((getline line < "/etc/os-release")>0) {
        if(line~/^PRETTY_NAME=/) { sub(/^PRETTY_NAME=/,"",line); sub(/^["\047]/,"",line); sub(/["\047]$/,"",line); os=line }
    }
    close("/etc/os-release")
    if(os=="") {
        while((getline line < "/etc/openwrt_release")>0) {
            if(line~/^DISTRIB_DESCRIPTION=/) { sub(/^DISTRIB_DESCRIPTION=/,"",line); sub(/^["\047]/,"",line); sub(/["\047]$/,"",line); os=line }
        }
        close("/etc/openwrt_release")
    }
    while((getline line < "/proc/cpuinfo")>0) {
        split(line,a,":"); key=trim(a[1]); value=trim(a[2])
        if(key=="processor") cpus++
        if(key=="CPU implementer" && implementer=="") implementer=value
        if(key=="CPU part" && part=="") part=value
        if((key=="model name" || key=="cpu model") && cpu=="") cpu=value
        if((key=="Hardware" || key=="Processor" || key=="system type" || key=="machine") && model=="") model=value
    }
    close("/proc/cpuinfo")
    if(cpu=="" && implementer=="0x41" && (part in ARM)) cpu="ARM " ARM[part]
    if((getline line < "/tmp/sysinfo/model")>0) { board=line; sub(/ *\(.*\)$/,"",board) }
    close("/tmp/sysinfo/model")
    if(cpu=="") cpu=model!=""?model:board
    else if(board!="" && board!=cpu) cpu=cpu " (" board ")"
    while((getline line < "/proc/meminfo")>0) {
        split(line,a,/[ \t]+/); key=a[1]; value=a[2]+0
        if(key=="MemTotal:") mem_total=value
        if(key=="MemAvailable:") { available=1; mem_available=value }
        if(key=="MemFree:") free_mem=value
        if(key=="Buffers:" || key=="Cached:" || key=="SReclaimable:") cache+=value
        if(key=="Shmem:") cache-=value
        if(key=="SwapTotal:") swap_total=value
        if(key=="SwapFree:") swap_free=value
    }
    close("/proc/meminfo")
    mem_used=mem_total-(available?mem_available:free_mem+cache)
    if(mem_used<0) mem_used=0
    if(mem_used>mem_total) mem_used=mem_total
    if((getline line < "/proc/uptime")>0) seconds=line+0
    close("/proc/uptime")
    if((getline line < "/proc/loadavg")>0) { split(line,a," "); load=a[1] ", " a[2] ", " a[3] }
    close("/proc/loadavg")
    while((getline line < "/proc/net/route")>0) {
        split(line,a,/[ \t]+/); if(a[2]=="00000000" && default_iface=="") default_iface=a[1]
    }
    close("/proc/net/route")
}
BEGIN { narm=split("0xc05 Cortex-A5 0xc07 Cortex-A7 0xc09 Cortex-A9 0xc0f Cortex-A15 0xd03 Cortex-A53 0xd04 Cortex-A35 0xd05 Cortex-A55 0xd07 Cortex-A57 0xd08 Cortex-A72 0xd09 Cortex-A73 0xd0b Cortex-A76",armt," "); for(i=1;i<narm;i+=2) ARM[armt[i]]=armt[i+1]
    esc=sprintf("%c",27); if(os_type=="Linux") linux_stats() }
/^\[[A-Z]+\]$/ { mode=$0; if(mode=="[DISKERROR]") disk_error=1; if(mode=="[NETERROR]") net_error=1; next }
mode=="[OS]" { os="macOS " $0; next }
mode=="[MACSYS]" {
    value=$0; sub(/^[^:]*:[ \t]*/,"",value)
    if($1=="hw.ncpu:") cpus=value+0
    if($1=="hw.memsize:") mem_total=value/1024
    if($1=="hw.model:") model=value
    if($1=="machdep.cpu.brand_string:") cpu=value
    if($1=="kern.boottime:") { split(value,a,"="); boot=a[2]+0 }
    if($1=="vm.swapusage:") { swap_total=units($4); swap_free=swap_total-units($7) }
    if($1=="vm.loadavg:") load=$3 ", " $4 ", " $5
    next
}
mode=="[MACMEM]" {
    if($0~/page size of/) { split($0,a,"page size of "); page_size=a[2]+0 }
    if($0~/^Pages free:/ || $0~/^Pages speculative:/) { split($0,a,":"); free_pages+=a[2]+0 }
    next
}
mode=="[NOW]" { if(boot>0) seconds=$0-boot; next }
mode=="[ROUTE]" { if($1=="interface:") default_iface=$2; next }
mode=="[DISK]" && NF>=6 && $2~/^[0-9]+$/ && $5~/^[0-9]+%$/ {
    if(seen_disk[$1]++ || seen_size[$2 " " $3]++) next
    ndisks++; disk_used[ndisks]=$3+0; disk_total[ndisks]=$2+0; disk_pct[ndisks]=$5+0
    mount=$6; for(i=7;i<=NF;i++) mount=mount " " $i
    disk_mount[ndisks]=mount; if(mount=="/") root_disk=ndisks
    next
}
mode=="[DT]" { if(soc=="" && $0~/^[a-z0-9-]+,[a-z]*[0-9]/ && $0!~/^(cudy|tplink|tp-link|xiaomi|asus|netgear|linksys|glinet|gl-inet|zyxel|dlink|d-link|tenda|huawei|raspberrypi)/) soc=$0; next }
mode=="[NET]" {
    if($1~/^[0-9]+:$/) { iface=$2; sub(/:$/,"",iface); sub(/@.*/,"",iface); down=$0~/state DOWN/ }
    else if($0~/^[^ \t]/) { iface=$1; sub(/:$/,"",iface); down=0 }
    address=""
    if($1=="inet") { address=$2; sub(/^addr:/,"",address); sub(/\/.*/,"",address) }
    if(address!="" && address!~/^127\./ && !down && iface!="") {
        if(!(iface in net_addr)) net_name[++nnets]=iface
        net_addr[iface]=net_addr[iface] ? net_addr[iface] ", " address : address
    }
}
END {
    if(os_type=="Darwin") {
        if(cpu=="") cpu=model
        if(page_size>0) {
            mem_used=mem_total-free_pages*page_size/1024
            if(mem_used<0) mem_used=0
            if(mem_used>mem_total) mem_used=mem_total
        } else mem_total=0
    }
    if(os=="") os=os_type
    L=10; for(i=1;i<=ndisks;i++) if(length(disk_mount[i])>L) L=length(disk_mount[i])
    if(L>14) L=14
    BW=20; RULE="\001rule"
    rule()
    row("Hostname",host)
    row("OS",paint(os ", " arch ", ","36") paint(kernel,"35"),"raw")
    if(soc!="") {
        split(soc,a,","); v=a[1]
        if(v=="mediatek") v="MediaTek"; else if(v=="qcom") v="Qualcomm"; else if(v=="brcm") v="Broadcom"
        else if(v=="rockchip") v="Rockchip"; else if(v=="allwinner") v="Allwinner"; else if(v=="ralink") v="Ralink"
        else if(v=="realtek") v="Realtek"; else if(v=="marvell") v="Marvell"; else if(v=="amlogic") v="Amlogic"
        cpu=v " " toupper(a[2]) (board!=""?" (" board ")":"")
    }
    c=cleancpu(cpu); row("CPU",(cpus?cpus (utf8?" \303\227 ":" x "):"") (c!=""?c:(cpus?"":"N/A")))
    up=seconds!="" ? sprintf("%dd %dh %dm",int(seconds/86400),int(seconds%86400/3600),int(seconds%3600/60)) : "N/A"
    row("Uptime",up)
    if(load!="") row("Load",load)
    rule()
    if(mem_total>0) resource("RAM",mem_used,mem_total,percent(mem_used,mem_total)); else row("RAM","N/A")
    if(swap_total>0) resource("Swap",swap_total-swap_free,swap_total,percent(swap_total-swap_free,swap_total)); else row("Swap","off","2")
    out("")
    limit=details?ndisks:4; count=0
    if(root_disk) { selected[root_disk]=1; count=1 }
    while(count<limit && count<ndisks) {
        best=0; for(i=1;i<=ndisks;i++) if(!selected[i] && (!best || disk_pct[i]>disk_pct[best])) best=i
        if(!best) break; selected[best]=1; count++
    }
    if(root_disk) { resource(disk_mount[root_disk],disk_used[root_disk],disk_total[root_disk],disk_pct[root_disk]); printed[root_disk]=1 }
    for(j=1;j<=count;j++) {
        best=0; for(i=1;i<=ndisks;i++) if(selected[i] && !printed[i] && (!best || disk_pct[i]>disk_pct[best])) best=i
        if(best) { resource(disk_mount[best],disk_used[best],disk_total[best],disk_pct[best]); printed[best]=1 }
    }
    if(!ndisks) row("Disks",disk_error?"unavailable":"no local filesystems","2")
    if(disk_error) row("Disks","incomplete disk data","33")
    rule()
    count=0; ips=""; if(openwrt) all_interfaces=1; nip=0
    if(default_iface in net_addr && (all_interfaces || !docker(default_iface))) {
        ip_item[++nip]=paint(default_iface,"2") " " paint(net_addr[default_iface],"35"); net_printed[default_iface]=1; count++
    }
    for(i=1;i<=nnets;i++) {
        name=net_name[i]; if(net_printed[name] || (!all_interfaces && virtual(name))) continue
        if(!all_interfaces && count>=3) break
        ip_item[++nip]=paint(name,"2") " " paint(net_addr[name],"35"); count++
    }
    if(!count) row("IP",net_error?"unavailable (install iproute2)":"no active IPv4","2")
    else {
        # One line if it fits (terminal or 72 cols), else one interface per line.
        for(i=1;i<=nip;i++) ips=ips (i>1?", ":"") ip_item[i]
        lim=cols>0?cols:72; if(lim>72) lim=72
        if(L+3+vislen(ips)<=lim) row("IP",ips,"raw")
        else for(i=1;i<=nip;i++) row(i==1?"IP":"",ip_item[i],"raw")
    }
    rule()
    flush()
    if(disk_error) exit 1
}'
SYSINFO_PAYLOAD
) || exit 1
eval "$sysinfo_payload"
