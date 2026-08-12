.pragma library

function normalizeBdf(bdf) {
  var text = String(bdf || "").trim().toLowerCase()
  var full = text.match(/^(?:[0-9a-f]{1,8}:)?([0-9a-f]{1,2}):([0-9a-f]{2})\.([0-9a-f])$/i)
  if (!full) return text
  function hex2(value) {
    var part = parseInt(value, 16).toString(16)
    return part.length < 2 ? "0" + part : part
  }
  return "0000:" + hex2(full[1]) + ":" + hex2(full[2]) + "." + full[3]
}

function displayGpuUsage(percent, fdinfoDerived) {
  if (percent < 0 || !isFinite(percent)) return -1
  var rounded = Math.round(percent)
  if (fdinfoDerived && rounded <= 3) return 0
  return Math.max(0, Math.min(100, rounded))
}

function gpuEngineUsagePercent(deltaNs, intervalMs) {
  if (!intervalMs || intervalMs < 500 || deltaNs < 0) return -1
  if (deltaNs === 0) return 0
  return Math.max(0, Math.min(100, deltaNs / (intervalMs * 1000000) * 100))
}

function maxGpuEngineUsage(current, previous, intervalMs) {
  if (!current || !intervalMs || intervalMs < 500) return -1
  var maxUsage = 0
  var sawEngine = false
  for (var engine in current) {
    sawEngine = true
    var delta = (Number(current[engine]) || 0) - (Number(previous && previous[engine]) || 0)
    if (delta < 0) delta = 0
    var percent = gpuEngineUsagePercent(delta, intervalMs)
    if (percent > maxUsage) maxUsage = percent
  }
  return sawEngine ? maxUsage : -1
}

function addGpuEngineTotal(map, key, engine, nanoseconds) {
  if (!map[key]) map[key] = {}
  map[key][engine] = (map[key][engine] || 0) + nanoseconds
}

function parseIntelGpuTopSample(raw) {
  var text = String(raw || "").trim()
  if (!text || text.indexOf("__INTEL_ERR__") === 0) return null
  try {
    var data = JSON.parse(text)
    return Array.isArray(data) ? (data.length ? data[data.length - 1] : null) : data
  } catch (error) {
    var lines = text.split("\n")
    for (var index = lines.length - 1; index >= 0; index--) {
      var line = String(lines[index] || "").trim()
      if (!line || line === "[" || line === "]" || line === ",") continue
      if (line.charAt(line.length - 1) === ",") line = line.slice(0, -1)
      try {
        return JSON.parse(line)
      } catch (ignored) {}
    }
  }
  return null
}

function intelGpuTopUsage(sample) {
  if (!sample || !sample.engines) return -1
  var maxBusy = 0
  for (var engine in sample.engines) {
    var entry = sample.engines[engine]
    if (!entry || entry.busy === undefined) continue
    var busy = Number(entry.busy)
    if (isFinite(busy) && busy > maxBusy) maxBusy = busy
  }
  return maxBusy
}

function networkInterfaceIsWireless(name) {
  var n = String(name || "").toLowerCase()
  return n.indexOf("wl") === 0 || n.indexOf("wlan") === 0 || n.indexOf("wifi") === 0
}

function networkInterfaceIsEthernet(name) {
  var n = String(name || "").toLowerCase()
  return n.indexOf("eth") === 0 || n.indexOf("en") === 0 || n.indexOf("em") === 0
}

function networkInterfaceKindLabel(name) {
  if (!name) return ""
  if (networkInterfaceIsWireless(name)) return "WIFI"
  if (networkInterfaceIsEthernet(name)) return "ETH"
  return ""
}
