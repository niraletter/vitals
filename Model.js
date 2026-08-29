function append(history, value, limit) {
  var next = (history || []).slice()
  next.push(Number(value) || 0)
  while (next.length > limit) next.shift()
  return next
}

function formatBytes(bytes) {
  var value = Number(bytes) || 0
  var units = ["B", "KiB", "MiB", "GiB", "TiB"]
  var index = 0
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024
    index++
  }
  return (index === 0 ? Math.round(value) : value.toFixed(value >= 10 ? 0 : 1)) + " " + units[index]
}

function formatRate(bytes) {
  return formatBytes(bytes) + "/s"
}

function formatBarPercent(value) {
  if (value === undefined || value === null || !isFinite(Number(value)) || Number(value) < 0)
    return "  …%"
  var n = Math.round(Number(value))
  if (n < 0) n = 0
  if (n > 999) n = 999
  return String(n).padStart(3, " ") + "%"
}

function formatBarRate(bytes) {
  var value = Math.max(0, Number(bytes) || 0)
  var units = ["B", "K", "M", "G", "T"]
  var index = 0
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024
    index++
  }
  var num = (index === 0 || value >= 100)
    ? String(Math.round(value)).padStart(4, " ")
    : value.toFixed(1).padStart(4, " ")
  return num + units[index]
}

function formatMemory(kibibytes) {
  return formatBytes((Number(kibibytes) || 0) * 1024)
}

function mountPercent(mount) {
  if (!mount) return 0
  var raw = String(mount.percent || "").replace("%", "")
  var value = Number(raw)
  return isFinite(value) ? Math.max(0, Math.min(100, value)) : 0
}
