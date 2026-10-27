"""Turn `bt time_limit` logs and a description of this machine into one JSON report."""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from importlib.metadata import version
from pathlib import Path

SCHEMA = 1
LOG_LIMIT = 256 * 1024
RUNS = ["stock", "tuned"]

CPU = Path("/sys/devices/system/cpu")
DMI = Path("/sys/class/dmi/id")

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
PROBLEM = re.compile(r"^PROBLEM (\S+)$")
# Lines printed by Problem.determine_time_limit, e.g.
#   slowest:      0.123s @ data/secret/04.in (submissions/accepted/sol.cpp)
TIMED = re.compile(r"^(slowest|fastest TLE):\s+([\d.]+)s @ (.+) \((.+)\)$")
LIMIT = re.compile(r"^(time limit|safety limit|timeout):\s+([\d.]+)s >=")
MESSAGE = re.compile(r"^(?:FATAL )?(ERROR|WARNING): (.*)$")


def read(path, default=None):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def cpu_state():
    cpufreq = CPU / "cpu0" / "cpufreq"
    if (CPU / "intel_pstate").is_dir():
        turbo = read(CPU / "intel_pstate" / "no_turbo") == "0"
    elif (CPU / "cpufreq" / "boost").exists():
        turbo = read(CPU / "cpufreq" / "boost") == "1"
    else:
        turbo = None
    return {
        "online": read(CPU / "online"),
        "turbo": turbo,
        "governor": read(cpufreq / "scaling_governor"),
        "min_khz": read(cpufreq / "scaling_min_freq"),
        "max_khz": read(cpufreq / "scaling_max_freq"),
    }


def primary_mac():
    net = Path("/sys/class/net")
    for dev in sorted(net.iterdir() if net.is_dir() else []):
        if "/devices/virtual/" in str(dev.resolve()):
            continue
        mac = read(dev / "address")
        if mac:
            return mac
    return None


def machine():
    cpuinfo = read("/proc/cpuinfo", "")
    model = re.search(r"^model name\s*:\s*(.*)$", cpuinfo, re.M)
    meminfo = re.search(r"^MemTotal:\s*(\d+) kB", read("/proc/meminfo", ""), re.M)
    dmi = {
        key: read(DMI / key)
        for key in [
            "sys_vendor",
            "product_name",
            "product_version",
            "product_uuid",
            "board_vendor",
            "board_name",
            "bios_version",
        ]
    }
    mac = primary_mac()
    return {
        # The live system gets a fresh /etc/machine-id every boot, so identify the
        # hardware instead: the DMI UUID if the firmware sets one, else the NIC.
        "id": dmi["product_uuid"] or mac,
        "mac": mac,
        "cpu_model": model.group(1) if model else None,
        "cpus_present": read(CPU / "present"),
        "memory_kib": int(meminfo.group(1)) if meminfo else None,
        "kernel": os.uname().release,
        "dmi": dmi,
    }


def parse_log(text):
    problems = {}
    current = None
    for raw in text.splitlines():  # also splits on the \r of progress bars
        line = ANSI.sub("", raw).strip()
        if m := PROBLEM.match(line):
            current = problems.setdefault(m.group(1), {"errors": [], "warnings": []})
        elif current is None:
            continue
        elif m := TIMED.match(line):
            key = "slowest" if m.group(1) == "slowest" else "fastest_tle"
            current[key] = {
                "seconds": float(m.group(2)),
                "test_case": m.group(3),
                "submission": m.group(4),
            }
        elif m := LIMIT.match(line):
            current[m.group(1).replace(" ", "_") + "_s"] = float(m.group(2))
        elif m := MESSAGE.match(line):
            current["errors" if m.group(1) == "ERROR" else "warnings"].append(m.group(2))
    return problems


def run(state, label):
    log = read(state / f"{label}.log")
    if log is None:
        return {"skipped": read(state / "tune.log", "not run")}
    return {
        "exit_status": int(read(state / f"{label}.status", "-1")),
        "cpu": json.loads(read(state / f"{label}.cpu.json", "null")),
        "problems": parse_log(log),
        "log": log[-LOG_LIMIT:],
    }


def build(args):
    # Imported here so `summary` runs on any plain python3, e.g. a jury laptop.
    from ruamel.yaml import YAML

    contest = YAML(typ="safe").load(args.contest / "contest.yaml") or {}
    report = {
        "schema": SCHEMA,
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "machine": machine(),
        "contest": {
            "id": contest.get("id"),
            "name": contest.get("name"),
            "revision": args.problemset_rev,
        },
        "bapctools": version("bapctools"),
        "jobs": args.jobs,
        "tune_log": read(args.state / "tune.log"),
        "runs": {label: run(args.state, label) for label in RUNS},
    }
    json.dump(report, sys.stdout, indent=2)


def seconds(value):
    return "-" if value is None else f"{value:.3f}s"


def summary(args):
    report = json.loads(args.report.read_text())
    m = report["machine"]
    print(f"{m['dmi']['sys_vendor']} {m['dmi']['product_name']}, {m['cpu_model']}")
    print()
    runs = report["runs"]
    names = sorted({name for r in runs.values() for name in r.get("problems", {})})
    header = ["problem"] + [f"{label} slowest" for label in RUNS] + ["tuned limit"]
    rows = [header]
    for name in names:
        row = [name]
        for label in RUNS:
            slowest = runs[label].get("problems", {}).get(name, {}).get("slowest", {})
            row.append(seconds(slowest.get("seconds")))
        limit = runs["tuned"].get("problems", {}).get(name, {}).get("time_limit_s")
        row.append("-" if limit is None else f"{limit:.1f}s")
        rows.append(row)
    widths = [max(len(row[i]) for row in rows) for i in range(len(header))]
    for row in rows:
        print("  ".join(cell.ljust(width) for cell, width in zip(row, widths)))
    for label in RUNS:
        r = runs[label]
        if "skipped" in r:
            print(f"\n{label}: skipped")
        elif r["exit_status"] != 0:
            errors = sum(len(p["errors"]) for p in r["problems"].values())
            print(f"\n{label}: bt exited with {r['exit_status']} ({errors} errors, see the log)")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("cpu-state")
    b = sub.add_parser("build")
    b.add_argument("--state", type=Path, required=True)
    b.add_argument("--contest", type=Path, required=True)
    b.add_argument("--problemset-rev", required=True)
    b.add_argument("--jobs", type=int, required=True)
    s = sub.add_parser("summary")
    s.add_argument("report", type=Path)
    args = parser.parse_args()

    if args.command == "cpu-state":
        json.dump(cpu_state(), sys.stdout)
    elif args.command == "build":
        build(args)
    else:
        summary(args)


if __name__ == "__main__":
    main()
