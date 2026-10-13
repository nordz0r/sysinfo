#!/bin/sh
# sysinfo-managed-install: 1
# Run immediately; save a copy only with --install.
sysinfo_payload=$(cat <<'SYSINFO_PAYLOAD'
#!/bin/sh
# Sysinfo: one lightweight entry point for Linux, BusyBox/OpenWrt and macOS.
# Copyright (C) 2019 NorD. MIT license.

# Install this running script: --install; remove the copy: --uninstall.
# After --install, add Bash startup manually (run these two lines once):
# sysinfo_hook='[ ! -x "$HOME/.local/bin/sysinfo.sh" ] || "$HOME/.local/bin/sysinfo.sh"'
# grep -qxF "$sysinfo_hook" "$HOME/.bashrc" 2>/dev/null || printf '\n%s\n' "$sysinfo_hook" >> "$HOME/.bashrc"
# Installation never changes .bashrc; all collection/rendering stays here.

# POSIX syntax also works with the system Bash 3.2 on macOS.
LC_ALL=C
export LC_ALL
set -f
details=0
all_interfaces=0
color=auto
action=report
for arg do
    case "$arg" in
        --install|--uninstall)
            if [ "$action" != report ] && [ "$action" != "$arg" ]; then
                printf '%s\n' 'Use either --install or --uninstall, not both.' >&2
                exit 2
            fi
            action=$arg ;;
        --details) details=1; all_interfaces=1 ;;
        --all-interfaces) all_interfaces=1 ;;
        --no-color) color=never ;;
        --color) color=always ;;
        -h|--help)
            printf '%s\n' 'Usage: sysinfo.sh [--install|--uninstall] [--details] [--all-interfaces] [--color|--no-color]' \
                'Default: three local filesystems, two interfaces, Docker hidden.' \
                '--details: show all local filesystems and interfaces.' \
                '--install: save an executable copy to ~/.local/bin/sysinfo.sh.' \
                '--uninstall: remove that copy; leave the directories in place.'
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

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
        if [ -r /proc/self/mounts ]; then
            while read -r source mount type rest; do
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
    -v arch="$arch" -v details="$details" -v all_interfaces="$all_interfaces" -v color="$use_color" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function repeat(c, n, s) { s=sprintf("%" n "s", ""); gsub(/ /, c, s); return s }
function fit(s, n) { if (length(s)>n) s=substr(s,1,n-3) "..."; return sprintf("%-" n "s",s) }
function paint(s, c) { return color && c ? esc "[" c "m" s esc "[0m" : s }
function border() { printf "+%s+\n", repeat("-",67) }
function section(s) { printf "| %s |\n", paint(fit(s,65),"36") }
function row(k,v) { printf "| %s | %s |\n", fit(k,10), fit(v,52) }
function note(s,c) { printf "| %s |\n", paint(fit(s,65),c) }
function percent(used,total) { return total>0 ? int(used*100/total+0.5) : 0 }
function bar(p, n) { p=p<0?0:(p>100?100:p); n=int(p*16/100+0.5); return "[" repeat("#",n) repeat("-",16-n) "]" }
function human(k) { if(k>=1048576) return sprintf("%.1f GiB",k/1048576); if(k>=1024) return sprintf("%.1f MiB",k/1024); return sprintf("%.0f KiB",k) }
function resource(k,used,total,p,warn, c) {
    c=warn ? (p>=90?"31":(p>=80?"33":"")) : "36"
    printf "| %s | %s | %s | %s |\n", fit(k,10), paint(fit(bar(p),18),c), \
        paint(fit(p "%" (warn && p>=90?" !":""),6),c), fit(human(used) " / " human(total),22)
}
function units(s, n) { n=s+0; if(s~/G$/) n*=1048576; else if(s~/M$/) n*=1024; else if(s~/T$/) n*=1073741824; return n }
function docker(s) { return s~/^docker[0-9]*$/ || s~/^veth/ || (length(s)==15 && s~/^br-[0-9a-f]+$/) }
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
        if((key=="model name" || key=="cpu model") && cpu=="") cpu=value
        if((key=="Hardware" || key=="Processor" || key=="system type" || key=="machine") && model=="") model=value
    }
    close("/proc/cpuinfo"); if(cpu=="") cpu=model
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
BEGIN { esc=sprintf("%c",27); if(os_type=="Linux") linux_stats() }
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
    if(seen_disk[$1]++) next
    ndisks++; disk_used[ndisks]=$3+0; disk_total[ndisks]=$2+0; disk_pct[ndisks]=$5+0
    mount=$6; for(i=7;i<=NF;i++) mount=mount " " $i
    disk_mount[ndisks]=mount; if(mount=="/") root_disk=ndisks
    next
}
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
    border(); section("SYSTEM")
    row("Host",host); row("OS",os " / " arch)
    row("CPU",(cpus?cpus " logical CPUs":"N/A") (cpu!=""?" / " cpu:""))
    row("Kernel",kernel)
    up=seconds!="" ? sprintf("%dd %dh %dm",int(seconds/86400),int(seconds%86400/3600),int(seconds%3600/60)) : "N/A"
    row("Uptime",up (load!=""?" / Load: " load:""))
    border(); section("RESOURCES")
    printf "| %s | %s | %s | %s |\n",fit("Resource",10),fit("Usage",18),fit("%",6),fit("Used / Total",22)
    printf "+%s+%s+%s+%s+\n",repeat("-",12),repeat("-",20),repeat("-",8),repeat("-",24)
    if(mem_total>0) resource("RAM",mem_used,mem_total,percent(mem_used,mem_total),0); else row("RAM","N/A")
    if(swap_total>0) resource("Swap",swap_total-swap_free,swap_total,percent(swap_total-swap_free,swap_total),0); else row("Swap","Disabled")
    limit=details?ndisks:3
    if(root_disk && !details) { selected[root_disk]=1; count=1 }
    while(count<limit && count<ndisks) {
        best=0; for(i=1;i<=ndisks;i++) if(!selected[i] && (!best || disk_pct[i]>disk_pct[best])) best=i
        if(!best) break; selected[best]=1; count++
    }
    for(j=1;j<=count;j++) {
        best=0; for(i=1;i<=ndisks;i++) if(selected[i] && !printed[i] && (!best || disk_pct[i]>disk_pct[best])) best=i
        if(best) { resource(disk_mount[best],disk_used[best],disk_total[best],disk_pct[best],1); printed[best]=1 }
    }
    hidden=ndisks-count; warnings=0; critical=0
    for(i=1;i<=ndisks;i++) if(!selected[i]) {
        if(disk_pct[i]>=80) warnings++
        if(disk_pct[i]>=90) critical++
    }
    if(hidden>0) note("+" hidden " other filesystems" (warnings?" (" warnings " warning" (warnings==1?"":"s") (critical?", " critical " critical":"") ")":""),critical?"31":(warnings?"33":""))
    if(!ndisks) row("Disks",disk_error?"Unavailable":"No supported local filesystems")
    if(disk_error) note("Warning: incomplete disk data")
    border(); section("NETWORK")
    count=0; eligible=0; omitted_docker=0
    for(i=1;i<=nnets;i++) { name=net_name[i]; if(!all_interfaces && docker(name)) omitted_docker++; else eligible++ }
    if(default_iface in net_addr && (all_interfaces || !docker(default_iface))) {
        row(default_iface,net_addr[default_iface] (docker(default_iface)?" [Docker]":"")); net_printed[default_iface]=1; count++
    }
    for(i=1;i<=nnets;i++) {
        name=net_name[i]; if(net_printed[name] || (!all_interfaces && docker(name))) continue
        if(!all_interfaces && count>=2) break
        row(name,net_addr[name] (docker(name)?" [Docker]":"")); count++
    }
    if(!count) note(net_error?"IP data unavailable (install iproute2 or ifconfig)":"No active IPv4 interfaces")
    summary=""; if(eligible>count) summary="+" (eligible-count) " other interfaces"
    if(omitted_docker) summary=summary (summary?" / ":"") omitted_docker " Docker interface" (omitted_docker==1?"":"s") " hidden"
    if(summary!="") note(summary)
    border()
    if(disk_error) exit 1
}'
SYSINFO_PAYLOAD
) || exit 1
eval "$sysinfo_payload"
