cpudir=/sys/devices/system/cpu

printf 'kernel cmdline : %s\n' "$(cat /proc/cmdline)"
printf 'online cpus    : %s\n' "$(cat "$cpudir/online")"
printf 'offlined by us : %s\n' "$(tr '\n' ' ' </run/judgehost/offlined-cpus 2>/dev/null || printf 'unknown')"
printf 'root cgroup    : %s\n' "$(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || printf 'unreadable')"

if [ -f "$cpudir/intel_pstate/no_turbo" ]; then
  printf 'intel_pstate   : no_turbo=%s min_perf_pct=%s max_perf_pct=%s\n' \
    "$(cat "$cpudir/intel_pstate/no_turbo")" \
    "$(cat "$cpudir/intel_pstate/min_perf_pct")" \
    "$(cat "$cpudir/intel_pstate/max_perf_pct")"
elif [ -f "$cpudir/cpufreq/boost" ]; then
  printf 'cpufreq        : boost=%s\n' "$(cat "$cpudir/cpufreq/boost")"
else
  printf 'cpufreq        : no turbo/boost control found\n'
fi

read -ra judging_cores <<<"$JUDGEHOST_CORES"
for cpu in "${judging_cores[@]}"; do
  cpufreq=$cpudir/cpu$cpu/cpufreq
  online=1
  if [ -r "$cpudir/cpu$cpu/online" ]; then
    online=$(cat "$cpudir/cpu$cpu/online")
  fi
  numa=absent
  if [ -e "$cpudir/cpu$cpu/node0" ]; then
    numa=node0
  fi
  printf 'core %-3s      : online=%s numa=%s governor=%s min=%s max=%s\n' \
    "$cpu" "$online" "$numa" \
    "$(cat "$cpufreq/scaling_governor" 2>/dev/null || printf 'n/a')" \
    "$(cat "$cpufreq/scaling_min_freq" 2>/dev/null || printf 'n/a')" \
    "$(cat "$cpufreq/scaling_max_freq" 2>/dev/null || printf 'n/a')"
done
