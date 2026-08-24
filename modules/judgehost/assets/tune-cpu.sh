cpudir=/sys/devices/system/cpu
efficiency_cores=/sys/devices/cpu_atom/cpus
record=/run/judgehost/offlined-cpus

offlined=()

expand_list() {
  local part lo hi
  local -a parts
  IFS=',' read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    case $part in
    "") ;;
    *-*)
      lo=${part%%-*}
      hi=${part##*-}
      seq "$lo" "$hi"
      ;;
    *) printf '%s\n' "$part" ;;
    esac
  done
}

cpu_numbers() {
  local dir
  for dir in "$cpudir"/cpu[0-9]*; do
    printf '%s\n' "${dir##*/cpu}"
  done | sort -n
}

is_online() {
  if [ -r "$cpudir/cpu$1/online" ]; then
    cat "$cpudir/cpu$1/online"
  else
    printf '1\n'
  fi
}

take_offline() {
  if [ "$(is_online "$1")" = 1 ] && [ -w "$cpudir/cpu$1/online" ]; then
    printf '0\n' >"$cpudir/cpu$1/online"
    offlined+=("$1")
  fi
}

if [ -r "$efficiency_cores" ]; then
  while read -r cpu; do
    take_offline "$cpu"
  done < <(expand_list "$(cat "$efficiency_cores")")
fi

declare -A seen_core=()
while read -r cpu; do
  if [ "$(is_online "$cpu")" != 1 ]; then
    continue
  fi
  topology=$cpudir/cpu$cpu/topology
  if [ ! -r "$topology/core_id" ]; then
    continue
  fi
  key="$(cat "$topology/physical_package_id")-$(cat "$topology/core_id")"
  if [ -n "${seen_core[$key]:-}" ]; then
    take_offline "$cpu"
  else
    seen_core[$key]=$cpu
  fi
done < <(cpu_numbers)

while read -r cpu; do
  if [ "$(is_online "$cpu")" != 1 ]; then
    continue
  fi
  cpufreq=$cpudir/cpu$cpu/cpufreq
  if [ -w "$cpufreq/scaling_governor" ]; then
    printf 'performance\n' >"$cpufreq/scaling_governor"
    chmod a-w "$cpufreq/scaling_governor"
  fi
  if [ -w "$cpufreq/scaling_min_freq" ] && [ -r "$cpufreq/scaling_max_freq" ]; then
    cat "$cpufreq/scaling_max_freq" >"$cpufreq/scaling_min_freq"
    chmod a-w "$cpufreq/scaling_min_freq" "$cpufreq/scaling_max_freq"
  fi
done < <(cpu_numbers)

if [ -d "$cpudir/intel_pstate" ]; then
  printf '1' >"$cpudir/intel_pstate/no_turbo" || true
  if [ "$(cat "$cpudir/intel_pstate/no_turbo")" != 1 ]; then
    echo "judgehost: Intel turbo boost is still enabled" >&2
    exit 1
  fi
  printf '100\n' >"$cpudir/intel_pstate/min_perf_pct"
  printf '100\n' >"$cpudir/intel_pstate/max_perf_pct"
elif [ -f "$cpudir/cpufreq/boost" ]; then
  printf '0' >"$cpudir/cpufreq/boost" || true
  if [ "$(cat "$cpudir/cpufreq/boost")" != 0 ]; then
    echo "judgehost: CPU boost is still enabled" >&2
    exit 1
  fi
fi

read -ra judging_cores <<<"$JUDGEHOST_CORES"
for cpu in "${judging_cores[@]}"; do
  if [ "$(is_online "$cpu")" != 1 ]; then
    echo "judgehost: judging core $cpu is offline" >&2
    exit 1
  fi
  if [ ! -e "$cpudir/cpu$cpu/node0" ]; then
    echo "judgehost: judging core $cpu is not on NUMA node 0, but runguard pins cpuset.mems=0" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "$record")"
if [ "${#offlined[@]}" -gt 0 ]; then
  printf '%s\n' "${offlined[@]}" >"$record"
else
  : >"$record"
fi
