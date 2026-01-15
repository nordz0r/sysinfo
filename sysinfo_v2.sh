#!/usr/bin/env bash
#
# Description: Sysinfo v2 - Backward Compatible System Information Script
#
# Copyright (C) 2019 NorD
# Updated for better compatibility with embedded systems like OpenWRT
#
# usage (curl): curl -Lso- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash
# usage (wget): wget -qO- https://raw.githubusercontent.com/nordz0r/sysinfo/master/sysinfo_v2.sh | bash
##########################


if [ ! -e '/usr/bin/curl' ] && [ ! -e '/usr/bin/wget' ]; then
    echo "Error: Neither curl nor wget command was found. You must install curl or wget at first."
    exit 1
fi


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'

get_opsy() {
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5,$6}' /etc/os-release && return
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

get_os_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

next() {
    printf "%-70s\n" "-" | sed 's/\s/-/g'
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "K" ] && size=0
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

# Get hostname with fallback
if [ -f /etc/hostname ]; then
    hostname=$( cat /etc/hostname )
else
    hostname=$( hostname 2>/dev/null || uname -n )
fi

cname=$( awk -F: '/model name|Processor/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
cores=$( awk -F: '/processor/ {core++} END {print core}' /proc/cpuinfo )
freq=$( awk -F'[ :]' '/cpu MHz|CPU MHz/ {print $4;exit}' /proc/cpuinfo )
# Use free without -m for BusyBox compatibility, convert from KiB to MiB
tram=$( LANG=C free | awk '/Mem:/ {print int($2/1024)}' )
uram=$( LANG=C free | awk '/Mem:/ {print int($3/1024)}' )
swap=$( LANG=C free | awk '/Swap:/ {print int($2/1024)}' )
uswap=$( LANG=C free | awk '/Swap:/ {print int($3/1024)}' )
up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime )

# Get load average with fallback
if command -v w >/dev/null 2>&1; then
    load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
else
    load=$( uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    if [ -z "$load" ]; then
        load=$( cat /proc/loadavg | awk '{print $1", "$2", "$3}' )
    fi
fi

opsy=$( get_opsy )
arch=$( uname -m )

# Get CPU bitness with fallback
if command -v getconf >/dev/null 2>&1; then
    lbit=$( getconf LONG_BIT )
else
    case $(uname -m) in
        x86_64|amd64|aarch64) lbit=64 ;;
        *) lbit=32 ;;
    esac
fi

kern=$( uname -r )

# Fix df command for BusyBox compatibility (remove -l option)
disk_size1=($( LANG=C df -hP | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker' | awk '{print $2}' ))
disk_size2=($( LANG=C df -hP | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker' | awk '{print $3}' ))
disk_total_size=$( calc_disk "${disk_size1[@]}" )
disk_used_size=$( calc_disk "${disk_size2[@]}" )

# Last logon - skip if commands not available
if command -v who >/dev/null 2>&1 && command -v whoami >/dev/null 2>&1; then
    last_logon=$( who | grep `whoami` | head -1 | awk '{print $3,$4,$5}' )
else
    last_logon=""
fi

ips=$( /sbin/ip addr show 2>/dev/null | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}' | egrep -v "127.0.0.1" | xargs )
if [ -z "$ips" ]; then
    ips=$( hostname -I 2>/dev/null | xargs )
fi

# clear
next
echo -e "${PLAIN}Hostname             : ${BLUE}$hostname${PLAIN}"
echo -e "CPU model            : ${BLUE}$cname${PLAIN}"
echo -e "Number of cores      : ${BLUE}$cores${PLAIN}"
echo -e "CPU frequency        : ${BLUE}$freq MHz${PLAIN}"
echo -e "Total size of Disk   : ${BLUE}$disk_total_size GB ($disk_used_size GB Used)${PLAIN}"
echo -e "Total amount of Mem  : ${BLUE}$tram MB ($uram MB Used)${PLAIN}"
echo -e "Total amount of Swap : ${BLUE}$swap MB ($uswap MB Used)${PLAIN}"
echo -e "System uptime        : ${BLUE}$up${PLAIN}"
echo -e "Load average         : ${BLUE}$load${PLAIN}"
echo -e "OS                   : ${BLUE}$opsy${PLAIN}"
echo -e "Arch                 : ${BLUE}$arch ($lbit Bit)${PLAIN}"
echo -e "Kernel               : ${BLUE}$kern${PLAIN}"
echo -e "IP(s)                : ${BLUE}$ips${PLAIN}"
if [ -n "$last_logon" ]; then
    echo -e "Last login           : ${BLUE}$last_logon${PLAIN}"
fi
next