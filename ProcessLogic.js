.pragma library

var PROCESS_SCAN_LIMIT = 400

function instantProcessCpuPercent(pid, utime, stime, deltaSystem, coreCount, previousProcessCpu) {
  var jiffies = (Number(utime) || 0) + (Number(stime) || 0)
  var key = String(pid)
  var previous = previousProcessCpu[key]
  if (deltaSystem > 0 && previous) {
    var deltaProc = jiffies - previous.jiffies
    var cpu = previous.cpu || 0
    if (deltaProc >= 0)
      cpu = 100 * Math.max(1, coreCount) * deltaProc / deltaSystem
    previousProcessCpu[key] = { jiffies: jiffies, cpu: cpu }
    return { cpu: Math.max(0, cpu), previousProcessCpu: previousProcessCpu }
  }
  if (!previous)
    previousProcessCpu[key] = { jiffies: jiffies, cpu: 0 }
  return {
    cpu: previous ? Math.max(0, Number(previous.cpu) || 0) : 0,
    previousProcessCpu: previousProcessCpu
  }
}

function buildProcessRefreshScript(limit) {
  var maxRows = Math.max(64, Number(limit) || PROCESS_SCAN_LIMIT)
  return ""
    + "cpu_total=$(awk '/^cpu / { s=0; for (i=2; i<=NF; i++) s+=$i; print s; exit }' /proc/stat); "
    + "core_count=$(grep -c '^cpu[0-9]' /proc/stat); "
    + "printf '__CPU__\\t%s\\t%s\\n' \"$cpu_total\" \"${core_count:-1}\"; "
    + "ps -eo pid=,ppid=,user:64=,rss=,pss=,comm=,args= --delimiter $'\\t' --no-headers --sort=-rss | head -n " + maxRows + " | "
    + "awk -F '\\t' '"
    + "function read_stat(pid) {"
    + "  f=\"/proc/\" pid \"/stat\";"
    + "  if ((getline line < f) <= 0) { close(f); return 0 }"
    + "  close(f); n=split(line, a, \" \"); if (n < 15) return 0;"
    + "  utime=a[14]; stime=a[15]; return 1"
    + "}"
    + "{"
    + "  pid=$1; if (pid == \"\") next;"
    + "  if (!read_stat(pid)) next;"
    + "  args=$8; for (i=9; i<=NF; i++) args=args \"\\t\" $i;"
    + "  printf \"%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n\", pid, $2, $3, utime, stime, $4, $5, $6, args"
    + "}'"
}

function compareProcesses(left, right, sortKey, ascending) {
  if (sortKey === "name") {
    var leftName = String(left.command || "").toLowerCase()
    var rightName = String(right.command || "").toLowerCase()
    if (leftName !== rightName) return ascending ? (leftName < rightName ? -1 : 1) : (leftName > rightName ? -1 : 1)
    return ascending ? left.pid - right.pid : right.pid - left.pid
  }
  if (sortKey === "cpu") {
    var cpuDelta = (Number(right.cpu) || 0) - (Number(left.cpu) || 0)
    if (cpuDelta !== 0) return ascending ? -cpuDelta : cpuDelta
    return (Number(right.memoryKB) || 0) - (Number(left.memoryKB) || 0)
  }
  if (sortKey === "pid") {
    if (left.pid === right.pid) return 0
    return ascending ? left.pid - right.pid : right.pid - left.pid
  }
  var memoryDelta = (Number(right.memoryKB) || 0) - (Number(left.memoryKB) || 0)
  if (memoryDelta !== 0) return ascending ? -memoryDelta : memoryDelta
  return (Number(right.cpu) || 0) - (Number(left.cpu) || 0)
}
