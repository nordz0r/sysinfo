"""Functional checks for the single entry point; no third-party test packages."""
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMMON = ROOT / "sysinfo.sh"
COMPAT = ROOT / "sysinfo_v2.sh"
ANSI = re.compile(r"\x1b\[[0-9;]*m")

DISKS = """Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/root 104857600 52428800 30000000 70% /
/dev/data 104857600 96468992 8388608 92% /data
/dev/backup 209715200 176160768 33554432 84% /backup
/dev/extra 104857600 84934656 15000000 81% /extra
/dev/small 104857600 1741 100000000 1% /small
/dev/root 104857600 52428800 30000000 70% /duplicate
"""
IP = """1: lo: <LOOPBACK,UP> state UNKNOWN
    inet 127.0.0.1/8 scope host lo
2: eth0: <UP> state UP
    inet 192.168.1.20/24 scope global eth0
3: br-lan: <UP> state UP
    inet 10.0.0.1/24 scope global br-lan
4: wlan0: <UP> state UP
    inet 10.1.0.1/24 scope global wlan0
5: docker0: <UP> state UP
    inet 172.17.0.1/16 scope global docker0
6: br-a1b2c3d4e5f6: <UP> state UP
    inet 172.18.0.1/16 scope global br-a1b2c3d4e5f6
7: veth123@eth0: <UP> state UP
    inet 172.19.0.1/16 scope global veth123
"""
IFCONFIG = """lo0: flags=8049<UP,LOOPBACK,RUNNING> mtu 16384
    inet 127.0.0.1 netmask 0xff000000
en1: flags=8863<UP,BROADCAST,RUNNING> mtu 1500
    inet 10.0.0.12 netmask 0xffffff00
en0: flags=8863<UP,BROADCAST,RUNNING> mtu 1500
    inet 192.168.1.20 netmask 0xffffff00
"""


class Fixture:
    def __init__(self, system="Linux"):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysinfo-test-")
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands"
        self.home = self.root / "user home"
        self.target = self.home / ".local" / "bin" / "sysinfo.sh"
        self.common = self.root / "sysinfo.sh"
        source = COMMON.read_text()
        # Redirect this test copy's install destination; never override HOME.
        source = source.replace("install_home=${HOME:-}", f"install_home={shlex.quote(str(self.home))}")
        files = {
            "/etc/os-release": 'PRETTY_NAME="Debian GNU/Linux 13"\n',
            "/etc/openwrt_release": "",
            "/proc/cpuinfo": "processor : 0\nmodel name : Fixture CPU\nprocessor : 1\n",
            "/proc/meminfo": "MemTotal: 16777216 kB\nMemAvailable: 12582912 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n",
            "/proc/uptime": "187440.00 20000.00\n",
            "/proc/loadavg": "0.10 0.20 0.30 1/100 100\n",
            "/proc/net/route": "Iface Destination Gateway Flags\nbr-lan 00000000 00000000 0003\n",
            "/proc/self/mounts": "/dev/root / ext4 rw 0 0\nserver:/share /remote nfs rw 0 0\ntmpfs /tmp tmpfs rw 0 0\n/dev/root /bind ext4 rw 0 0\n",
        }
        self.files = {}
        for index, (original, contents) in enumerate(files.items()):
            file = self.root / f"fixture-{index}"
            file.write_text(contents)
            self.files[original] = file
            source = source.replace(original, str(file))
        self.common.write_text(source)
        self.compat = self.root / "sysinfo_v2.sh"
        self.compat.write_text(source)
        self.env = {**{k: v for k, v in os.environ.items() if k != "LANG" and not k.startswith("LC_")}, "PATH": str(self.bin), "TERM": "xterm",
                    "SYSINFO_COMMAND_LOG": str(self.log)}
        self.shell = os.environ.get("SYSINFO_TEST_SH", "/bin/sh")
        for tool in ("sh", "awk", "cat", "mkdir", "mktemp", "chmod", "mv", "rm", "grep"):
            (self.bin / tool).symlink_to(os.environ.get(f"SYSINFO_TEST_{tool.upper()}", shutil.which(tool)))
        self.command("uname", f"{system} server 24.0.0 {'arm64' if system == 'Darwin' else 'x86_64'}\n")
        self.command("df", DISKS)
        self.command("curl")
        if system == "Linux":
            self.command("ip", IP)
        else:
            self.command("sw_vers", "15.0\n")
            self.command("sysctl", """hw.ncpu: 8
hw.memsize: 17179869184
hw.model: Mac14,2
machdep.cpu.brand_string: Apple M2
kern.boottime: { sec = 1000000, usec = 0 } Sun Jan 1
vm.swapusage: total = 1024.00M used = 256.00M free = 768.00M
vm.loadavg: { 0.10 0.20 0.30 }
""")
            self.command("vm_stat", """Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free: 524287.
Pages speculative: 1.
""")
            self.command("date", "1187440\n")
            self.command("route", "    interface: en0\n")
            self.command("ifconfig", IFCONFIG)

    def command(self, name, output="", status=0):
        executable = self.bin / name
        if executable.is_symlink():
            executable.unlink()
        executable.write_text("#!/bin/sh\n"
                              f'printf "%s\\n" "{name}:$*" >> "$SYSINFO_COMMAND_LOG"\n'
                              f"printf '%s' {shlex.quote(output)}\nexit {status}\n")
        executable.chmod(0o755)

    def run(self, *args, wrapper=False, piped=False):
        path = self.compat if wrapper else self.common
        cmd = [self.shell, "-s", "--"] if piped else [self.shell, str(path)]
        return subprocess.run([*cmd, *args], input=path.read_text() if piped else None,
                              capture_output=True, text=True, env=self.env, timeout=10)

    def close(self):
        self.tmp.cleanup()


class SysinfoTests(unittest.TestCase):
    def fixture(self, system="Linux"):
        fixture = Fixture(system)
        self.addCleanup(fixture.close)
        return fixture

    def table(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = ANSI.sub("", result.stdout).splitlines()
        self.assertTrue(lines)
        self.assertTrue(set(lines[0]) == {"-"} and lines[-1] == lines[0], lines)
        self.assertTrue(all(" : " in line for line in lines if set(line) != {"-"}), lines)
        self.assertNotIn("+-", "".join(lines))  # No table borders.
        return "\n".join(lines)

    def line(self, text, label):
        return next(line for line in text.splitlines() if line.startswith(label + " ") or line.startswith(label + ":"))

    def test_live_linux_with_sh_and_bash(self):
        for shell in ("/bin/sh", "/bin/bash"):
            p = subprocess.run([shell, str(COMMON)], capture_output=True, text=True, timeout=10)
            text = self.table(p)
            for label in ("Hostname", "OS", "Kernel", "CPU", "Uptime", "RAM", "IP"):
                self.line(text, label)
            self.assertNotIn("\x1b", p.stdout)

    def test_compact_layout_disks_and_default_route(self):
        f = self.fixture()
        text = self.table(f.run())
        lines = text.splitlines()
        self.assertLessEqual(len(lines), 16)
        self.assertIn("2 x Fixture", self.line(text, "CPU"))
        self.assertIn("2d 4h 4m  load 0.10, 0.20, 0.30", self.line(text, "Uptime"))
        mounts = [l.split(" :")[0].strip() for l in lines if l.startswith("/")]
        self.assertEqual(mounts, ["/", "/data", "/backup", "/extra"])  # root first, then fullest.
        self.assertIn("70%", self.line(text, "/"))  # df capacity, not used/total = 50%.
        self.assertNotIn("other", text)
        ip = self.line(text, "IP")
        self.assertLess(ip.index("br-lan"), ip.index("eth0"))
        self.assertNotIn("172.17.0.1", text)
        self.assertNotIn("Warning", text)
        commands = f.log.read_text().splitlines()
        self.assertEqual(sorted(line.split(":")[0] for line in commands), ["df", "ip", "uname"])
        df = next(line for line in commands if line.startswith("df:"))
        self.assertEqual(df, "df:-kP /")  # No NFS, tmpfs or duplicate bind mount.

    def test_details_includes_all_disks_and_interfaces(self):
        f = self.fixture()
        f.command("df", DISKS + "/dev/x 1048576 1741 900000 1% /x\n")
        text = self.table(f.run("--details"))
        self.assertIn("/x ", text)
        self.assertIn("1.7M", text)
        self.assertIn("172.17.0.1", text)

    def test_warning_colors_and_boundaries(self):
        f = self.fixture()
        f.command("df", "Filesystem 1024-blocks Used Available Capacity Mounted on\n"
                  + "".join(f"/dev/d{i} 1048576 800000 100000 {pct}% /d{i}\n"
                            for i, pct in enumerate((79, 80, 94, 95))))
        p = f.run("--details", "--color")
        text = self.table(p)
        for mount, pct, color in (("/d0", 79, "32"), ("/d1", 80, "33"),
                                  ("/d2", 94, "33"), ("/d3", 95, "31")):
            line = next(line for line in p.stdout.splitlines() if f"/{mount[1:]} " in ANSI.sub("", line)[:12])
            self.assertIn(f"\x1b[{color}m", line)
            self.assertIn(f"{pct}%", line)
        self.assertIn("95% !", text)
        self.assertNotIn("94% !", text)
        self.assertIn("disk >= 95%: /d3 95%", self.line(text, "Warning"))

    def test_unicode_bars_and_ascii_fallback(self):
        f = self.fixture()
        f.env["LANG"] = "ru_RU.UTF-8"
        text = self.table(f.run())
        ram = self.line(text, "RAM")
        self.assertIn("\u2588", ram)
        self.assertNotIn("[", ram)
        self.assertNotIn("#", ram)
        f.env["LANG"] = "C"
        ram = self.line(self.table(f.run()), "RAM")
        self.assertTrue(set(ram.split(" : ")[1].split()[0]) <= {"=", "-"}, ram)

    def test_many_disks_and_interfaces_stay_bounded(self):
        f = self.fixture()
        f.command("df", "Filesystem 1024-blocks Used Available Capacity Mounted on\n"
                  + "".join(f"/dev/d{i} 1048576 800000 100000 96% /disk{i}\n" for i in range(100)))
        f.command("ip", "".join(f"{i+1}: eth{i}: <UP> state UP\n    inet 10.0.0.{i+1}/24\n" for i in range(100)))
        text = self.table(f.run())
        self.assertLessEqual(len(text.splitlines()), 17)
        self.assertIn("(+97)", self.line(text, "Warning"))
        self.assertEqual(self.line(text, "IP").count("eth"), 3)

    def test_virtual_interfaces_hidden_unless_requested(self):
        f = self.fixture()
        f.command("ip", IP + "8: flannel.1: <UP> state UNKNOWN\n    inet 10.42.0.0/32\n")
        self.assertNotIn("flannel", self.table(f.run()))
        text = self.table(f.run("--all-interfaces"))
        self.assertIn("172.17.0.1", text)
        self.assertIn("wlan0", text)

    def test_container_and_readonly_mounts_skipped(self):
        f = self.fixture()
        with f.files["/proc/self/mounts"].open("a") as mounts:
            mounts.write("/dev/k /var/lib/kubelet/pods/x ext4 rw 0 0\n/dev/m /usr/lib/modules ext4 rw 0 0\n"
                         "/dev/h /usr/src/h overlay ro,relatime 0 0\n/dev/d /data ext4 rw 0 0\n")
        self.table(f.run())
        df = next(line for line in f.log.read_text().splitlines() if line.startswith("df:"))
        self.assertEqual(df, "df:-kP / /data")

    def test_macos_metrics_and_default_interface(self):
        f = self.fixture("Darwin")
        text = self.table(f.run())
        self.assertIn("macOS 15.0, arm64", text)
        self.assertIn("8 x Apple M2", text)
        self.assertIn("2d 4h 4m", text)
        self.assertIn("8.0G / 16.0G", text)
        self.assertIn("256.0M / 1.0G", text)
        ip = self.line(text, "IP")
        self.assertLess(ip.index("en0"), ip.index("en1"))
        self.assertIn("df:-kPl", f.log.read_text())

    def test_macos_intel_and_cpu_model_fallback(self):
        f = self.fixture("Darwin")
        f.command("uname", "Darwin server 24.0.0 x86_64\n")
        f.command("sysctl", "hw.ncpu: 4\nhw.model: MacBookPro11,1\n")
        text = self.table(f.run())
        self.assertIn("macOS 15.0, x86_64", text)
        self.assertIn("4 x MacBookPro11,1", text)
        self.assertRegex(self.line(text, "RAM"), r": N/A")

    def test_cpu_model_is_cleaned(self):
        f = self.fixture()
        f.files["/proc/cpuinfo"].write_text("processor : 0\nmodel name : Intel(R) Core(TM) i5-10400 CPU @ 2.90GHz\n"
                                            "processor : 1\nprocessor : 2\nprocessor : 3\n")
        f.env["LANG"] = "C.UTF-8"
        self.assertIn("4 \u00d7 Intel Core i5-10400 @ 2.90GHz", self.line(self.table(f.run()), "CPU"))

    def test_openwrt_ifconfig_and_old_kernel_memory_fallback(self):
        f = self.fixture()
        f.files["/etc/os-release"].write_text("")
        f.files["/etc/openwrt_release"].write_text("DISTRIB_DESCRIPTION='OpenWrt 24.10'\n")
        with f.files["/proc/self/mounts"].open("a") as mounts:
            mounts.write("/dev/rom /rom squashfs ro 0 0\n")
        f.files["/proc/meminfo"].write_text(
            "MemTotal: 262144 kB\nMemFree: 65536 kB\nBuffers: 16384 kB\nCached: 32768 kB\nSwapTotal: 0 kB\n")
        (f.bin / "ip").unlink()
        f.command("ifconfig", "br-lan    Link encap:Ethernet\n"
                  "          inet addr:192.168.1.1  Bcast:192.168.1.255\n")
        text = self.table(f.run())
        self.assertIn("OpenWrt 24.10", text)
        self.assertIn("144.0M / 256.0M", text)
        self.assertIn("192.168.1.1", text)
        df = next(line for line in f.log.read_text().splitlines() if line.startswith("df:"))
        self.assertNotIn("/rom", df)

    def test_no_downloader_suggests_install_but_local_metrics_work(self):
        f = self.fixture()
        (f.bin / "curl").unlink()
        p = f.run()
        self.table(p)
        self.assertIn("sudo apt install curl", p.stderr)

    def test_compat_is_identical_and_runs_without_extra_downloads(self):
        self.assertEqual(COMMON.read_bytes(), COMPAT.read_bytes())
        f = self.fixture()
        p = f.run("--help", wrapper=True)
        self.assertEqual(p.returncode, 0)
        self.assertIn("Usage:", p.stdout)
        self.assertFalse(f.log.exists())
        for downloader in ("curl", "wget"):
            if downloader == "wget":
                (f.bin / "curl").unlink()
                f.command("wget")
            self.table(f.run(wrapper=True, piped=True))
        self.assertNotIn("curl:", f.log.read_text())
        self.assertNotIn("wget:", f.log.read_text())
        self.assertFalse(f.home.exists())

    def test_default_piped_run_does_not_install_or_fetch(self):
        f = self.fixture()
        self.table(f.run(piped=True))
        self.assertFalse(f.home.exists())
        self.assertNotIn("curl:", f.log.read_text())
        self.assertNotIn("wget:", f.log.read_text())

    def test_install_creates_executable_self_contained_copy_and_is_repeatable(self):
        f = self.fixture()
        expected = f.common.read_bytes()
        self.assertFalse(f.home.exists())
        for _ in range(2):
            p = f.run("--install")
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("Installed:", p.stdout)
            self.assertNotIn("SYSTEM", p.stdout)
            self.assertEqual(f.target.read_bytes(), expected)
            self.assertEqual(f.target.stat().st_mode & 0o777, 0o755)
            self.assertFalse((f.home / ".bashrc").exists())
        f.common.unlink()
        p = subprocess.run([str(f.target)], env=f.env,
                           capture_output=True, text=True, timeout=10)
        self.table(p)
        self.assertNotIn("curl:", f.log.read_text())
        self.assertNotIn("wget:", f.log.read_text())

    def test_piped_install_and_uninstall_leave_shell_profile_untouched(self):
        for system in ("Linux", "Darwin"):
            f = self.fixture(system)
            f.home.mkdir()
            profile = f.home / ".bashrc"
            profile.write_text("# existing user configuration\n")
            for wrapper in (False, True):
                p = f.run("--install", piped=True, wrapper=wrapper)
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertEqual(f.target.read_bytes(), f.common.read_bytes())
                self.assertEqual(profile.read_text(), "# existing user configuration\n")
                p = subprocess.run([str(f.target)], env=f.env,
                                   capture_output=True, text=True, timeout=10)
                self.table(p)
                p = f.run("--uninstall", piped=True, wrapper=wrapper)
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertFalse(f.target.exists())
                self.assertTrue(f.target.parent.is_dir())
                self.assertEqual(profile.read_text(), "# existing user configuration\n")
            self.assertNotIn("curl:", f.log.read_text())

    def test_uninstall_before_install_creates_nothing(self):
        f = self.fixture()
        p = f.run("--uninstall", piped=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("Not installed:", p.stdout)
        self.assertFalse(f.home.exists())

    def test_bash_piped_install_and_installed_uninstall(self):
        f = self.fixture()
        p = subprocess.run(["/bin/bash", "-s", "--", "--install"],
                           input=f.common.read_text(), env=f.env, capture_output=True,
                           text=True, timeout=10)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(f.target.read_bytes(), f.common.read_bytes())
        p = subprocess.run([str(f.target), "--uninstall"], env=f.env,
                           capture_output=True, text=True, timeout=10)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(f.target.exists())

    def test_install_rejects_missing_or_relative_home(self):
        for home in ("", "relative"):
            f = self.fixture()
            source = f.common.read_text().replace(
                f"install_home={shlex.quote(str(f.home))}", f"install_home={shlex.quote(home)}")
            f.common.write_text(source)
            p = f.run("--install")
            self.assertEqual(p.returncode, 1)
            self.assertIn("HOME must be set to an absolute directory", p.stderr)
            self.assertFalse(f.home.exists())

    def test_install_and_uninstall_refuse_unrelated_files_and_symlinks(self):
        for kind in ("file", "directory", "symlink"):
            f = self.fixture()
            f.target.parent.mkdir(parents=True)
            unrelated = f.root / "unrelated"
            unrelated.write_text("preserve me")
            if kind == "file":
                f.target.write_text("user file")
            elif kind == "directory":
                f.target.mkdir()
            else:
                f.target.symlink_to(unrelated)
            for option in ("--install", "--uninstall"):
                p = f.run(option)
                self.assertEqual(p.returncode, 1)
                self.assertIn("Refusing", p.stderr)
            self.assertEqual(unrelated.read_text(), "preserve me")
            if kind == "file":
                self.assertEqual(f.target.read_text(), "user file")
            elif kind == "directory":
                self.assertTrue(f.target.is_dir())
            else:
                self.assertTrue(f.target.is_symlink())

    def test_failed_update_preserves_installed_copy_and_removes_temp_file(self):
        f = self.fixture()
        self.assertEqual(f.run("--install").returncode, 0)
        previous = f.target.read_bytes()
        f.common.write_text(f.common.read_text().replace("# POSIX syntax", "# Updated payload\n# POSIX syntax"))
        f.command("chmod", status=1)
        p = f.run("--install")
        self.assertEqual(p.returncode, 1)
        self.assertEqual(f.target.read_bytes(), previous)
        self.assertFalse(list(f.target.parent.glob(".sysinfo.*")))

    def test_blocked_parent_and_conflicting_modes(self):
        f = self.fixture()
        f.home.mkdir()
        (f.home / ".local").write_text("user file")
        self.assertEqual(f.run("--install").returncode, 1)
        self.assertEqual((f.home / ".local").read_text(), "user file")
        self.assertEqual(f.run("--install", "--uninstall").returncode, 2)

    def test_header_startup_command_is_manual_and_idempotent(self):
        f = self.fixture()
        self.assertEqual(f.run("--install").returncode, 0)
        profile = f.home / ".bashrc"
        profile.write_text("# existing user configuration")
        integration = "\n".join(line[2:] for line in COMMON.read_text().splitlines()
                                if line.startswith(("# sysinfo_hook=", "# grep -qxF")))
        integration = integration.replace("$HOME/.local/bin/sysinfo.sh", str(f.target))
        integration = integration.replace("$HOME/.bashrc", str(profile))
        for _ in range(2):
            p = subprocess.run(["/bin/bash", "-c", integration], env=f.env,
                               capture_output=True, text=True, timeout=10)
            self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(profile.read_text().count(str(f.target)), 2)
        self.assertTrue(profile.read_text().startswith("# existing user configuration\n"))
        p = subprocess.run(["/bin/bash", str(profile)], env=f.env,
                           capture_output=True, text=True, timeout=10)
        self.table(p)

    def test_failed_disk_query_does_not_report_success(self):
        f = self.fixture()
        f.command("df", DISKS, 1)
        p = f.run()
        self.assertEqual(p.returncode, 1)
        self.assertIn("incomplete disk data", p.stdout)

    def test_bad_option_and_unsupported_platform(self):
        f = self.fixture()
        self.assertEqual(f.run("--unknown").returncode, 2)
        f.command("uname", "FreeBSD server 14.0 amd64\n")
        p = f.run()
        self.assertEqual(p.returncode, 1)
        self.assertIn("Unsupported system: FreeBSD", p.stderr)


if __name__ == "__main__":
    unittest.main()
