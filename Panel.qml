import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "Model.js" as Model
import "GpuLogic.js" as GpuLogic
import "ProcessLogic.js" as ProcessLogic

Ui.Panel {
  id: root
  moduleName: "vitals"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property string currentUser: Quickshell.env("USER")

  // While closed, the bar polls only the pinned metric. Full reads run when
  // the dashboard is open on the configured poll interval.
  property real cpuUsage: 0
  property real memoryUsage: 0
  property real cpuTemperature: 0
  property real cpuFanRpm: -1
  property var cpuCores: []
  property var cpuCoreHistories: ({})
  property var cpuCoreTemperatures: ({})
  property string expandedModule: ""
  readonly property bool cpuCoresExpanded: expandedModule === "cpu"
  property int usedMemoryKB: 0
  property int totalMemoryKB: 0
  property int usedSwapKB: 0
  property int totalSwapKB: 0
  property string cpuModel: ""
  property string uptime: ""
  property var availableGpus: []
  property int selectedGpuIndex: 0
  property string gpuName: ""
  property real gpuUsage: -1
  property real gpuTemperature: -1
  property double gpuVramUsedBytes: -1
  property double gpuVramTotalBytes: -1
  property double gpuSharedMemoryBytes: -1
  property bool gpuUsesSharedMemory: false
  property real networkRxRate: 0
  property real networkTxRate: 0
  property string networkInterface: ""
  property string localIpAddress: ""
  property var networkInterfaces: []
  property var networkInterfaceStats: []
  property string networkActiveInterface: ""
  property var networkProcesses: []
  property var cpuCorePhysicalIds: ({})
  property var previousNetworkByPid: ({})
  property var previousNetworkByInterface: ({})
  property var pressureStats: ({})
  property real diskReadRate: 0
  property real diskWriteRate: 0
  property var processes: []
  property var processRecordsByPid: ({})
  property var mounts: []
  property string selectedGpuBdf: ""
  property string intelGpuTopBdf: ""
  property string intelGpuTopState: "" // missing, denied, ok
  property bool intelGpuSetupPending: false
  property var gpuMetricsByBdf: ({})
  property var processGpuMetricsByPid: ({})
  property var previousProcessCpu: ({})
  property double previousProcessSystemCpuTimes: 0
  property var previousCpu: null
  property var previousCpuCores: ({})
  property var previousGpuEnginesByPid: ({})
  property double previousGpuSampleEndMs: 0
  property double lastIntelGpuTopAt: 0
  property double lastSensorsAt: 0
  property double lastNetworkProcessAt: 0
  property double lastMetricsUpdatedAt: 0
  property int dashboardPollTick: 0
  property int gpuFdInfoPollTick: 0
  property bool processCpuWarmupPending: false
  readonly property int processProcTimeoutSec: 12
  readonly property int gpuFdInfoTimeoutSec: 8
  readonly property int intelGpuTopTimeoutSec: 10
  readonly property string lastMetricsUpdatedLabel: {
    if (!lastMetricsUpdatedAt) return ""
    var ageSec = Math.max(0, Math.round((Date.now() - lastMetricsUpdatedAt) / 1000))
    return "Updated " + ageSec + "s ago"
  }
  property bool cpuInfoLoaded: false
  property bool cpuTopologyLoaded: false
  property var previousNetwork: null
  property var previousDisk: null
  property var previousDiskDevices: ({})
  property var diskDevices: []
  property var diskIoDetails: []
  property var memoryStats: ({})
  property var cpuHistory: []
  property var memoryHistory: []
  property var rxHistory: []
  property var txHistory: []
  property var readHistory: []
  property var writeHistory: []
  property var gpuHistory: []
  property int gpuHistorySampleAt: 0
  readonly property int historySize: 60

  // Client-side filtering/sorting lets users pivot instantly without another
  // process scan.
  property string processSearch: ""
  property string processFilter: "all" // all, user, system
  property string processSort: "memory" // name, cpu, memory, pid
  property string processMemoryMode: "rss" // rss, pss
  property bool processSortAscending: false
  property var filteredProcesses: []
  property int processMetricsEpoch: 0
  property bool processListScrollLocked: false
  property real processScrollContentY: 0
  property string processScrollAnchorPid: ""
  property bool processListRestoringScroll: false
  readonly property int processScrollTopThreshold: 2
  readonly property int processScrollUnlockThreshold: 8
  property string expandedPid: ""
  property string processTreePid: ""

  property var pendingProcess: null
  property bool pendingForceKill: false
  property string actionMessage: ""
  property string processCountLabel: "PROCESSES (0/0)"

  // The handle between the metric grid and process list keeps both regions
  // useful at different sizes. Values are persisted with the widget settings.
  readonly property int minimumModuleGridHeight: 54
  property int moduleGridHeight: {
    var configured = Number(setting("moduleGridHeight", 300))
    return isFinite(configured) ? Math.max(minimumModuleGridHeight, Math.min(560, Math.round(configured))) : 300
  }
  property int processListHeight: {
    var configured = Number(setting("processListHeight", defaultProcessListHeight))
    return isFinite(configured) ? Math.max(120, Math.round(configured)) : defaultProcessListHeight
  }
  readonly property int defaultModuleGridHeight: 300
  readonly property int processRowStride: Style.space(38) + Style.spacing.xs
  readonly property int defaultProcessListHeight: processRowStride * 5 - Style.spacing.xs
  readonly property int processColumnCpuWidth: Style.space(50)
  readonly property int processColumnMemWidth: Style.space(64)
  readonly property int processColumnPidWidth: Style.space(44)
  readonly property int processListScrollGutter: Style.space(14)
  readonly property int processControlPadX: Style.spacing.controlPaddingX
  readonly property int processControlPadY: Style.spacing.inputPaddingY
  readonly property int processHeaderPadX: Style.spacing.xs
  readonly property int processHeaderPadY: Style.spacing.xxs
  readonly property int processRowHeight: Style.space(38)
  readonly property int processJumpInset: Style.space(1)
  readonly property string processTreeFontFamily: "Liberation Mono"
  readonly property bool processListHasScrolled: processListScrollLocked
  property int splitterDelta: 0
  readonly property int displayedModuleGridHeight: Math.max(minimumModuleGridHeight, Math.min(560, moduleGridHeight + splitterDelta))
  readonly property int displayedProcessListHeight: Math.max(120, processListHeight - splitterDelta)
  // Eight tile densities. The last tier keeps label, stat, and graph inline per tile.
  readonly property int moduleDensity: displayedModuleGridHeight >= 260 ? 0
    : displayedModuleGridHeight >= 210 ? 1
    : displayedModuleGridHeight >= 170 ? 2
    : displayedModuleGridHeight >= 140 ? 3
    : displayedModuleGridHeight >= 110 ? 4
    : displayedModuleGridHeight >= 88 ? 5
    : displayedModuleGridHeight >= 66 ? 6 : 7
  readonly property bool modulesCompact: moduleDensity >= 1
  readonly property bool modulesDense: moduleDensity >= 2
  readonly property bool modulesMinimal: moduleDensity >= 3
  readonly property bool modulesMicro: moduleDensity >= 4
  readonly property bool modulesNano: moduleDensity >= 5
  readonly property bool modulesPico: moduleDensity >= 6
  readonly property bool modulesLine: moduleDensity >= 7
  readonly property int moduleGraphStripHeight: moduleDensity >= 7 ? 0
    : moduleDensity >= 6 ? 3
    : moduleDensity >= 5 ? 4
    : moduleDensity >= 4 ? 8
    : moduleDensity >= 3 ? 12
    : moduleDensity >= 2 ? 16
    : moduleDensity >= 1 ? 24 : 0
  readonly property bool moduleGraphUsesStrip: moduleGraphStripHeight > 0
  readonly property real usageUrgentThreshold: 90

  function markMetricsUpdated() {
    lastMetricsUpdatedAt = Date.now()
  }

  function warnParseFailure(kind, detail) {
    console.warn("Vitals:", kind, detail || "")
  }

  function runTimedCommand(proc, timeoutSec, command) {
    if (!proc || proc.running) return false
    proc.command = ["timeout", String(timeoutSec)].concat(command)
    proc.running = true
    return true
  }

  function usageIsUrgent(value) {
    return Number(value) > usageUrgentThreshold
  }

  function tileMetricPercent(moduleName) {
    if (moduleName === "cpu") return cpuUsage
    if (moduleName === "memory") return memoryUsage
    if (moduleName === "storage") {
      var storage = primaryStorage()
      return storage ? Model.mountPercent(storage) : -1
    }
    return -1
  }

  function tileValueIsUrgent(moduleName) {
    var value = tileMetricPercent(moduleName)
    return value >= 0 && usageIsUrgent(value)
  }

  function moduleRateCompact(bytes) {
    return Model.formatRate(bytes).replace(/ /g, "")
  }

  function moduleDiskCompactValue(both) {
    if (both)
      return "R " + moduleRateCompact(diskReadRate) + " W " + moduleRateCompact(diskWriteRate)
    var read = diskReadRate || 0
    var write = diskWriteRate || 0
    if (read >= write) return "R " + moduleRateCompact(read)
    return "W " + moduleRateCompact(write)
  }

  function moduleTileHeading(moduleName, heading) {
    if (moduleDensity >= 5) {
      if (moduleName === "cpu") return "C"
      if (moduleName === "memory") return "M"
      if (moduleName === "network") return "N"
      if (moduleName === "disk") return "D"
      if (moduleName === "gpu") return "G"
      if (moduleName === "storage") return "S"
      return String(heading || "?").charAt(0)
    }
    if (moduleDensity >= 4) {
      if (moduleName === "network") return "N"
      if (moduleName === "disk") return "D"
      if (moduleName === "storage") return "S"
      return heading
    }
    if (moduleDensity >= 3) {
      if (moduleName === "network") return "NET"
      if (moduleName === "disk") return "DISK"
      if (moduleName === "storage") return "STOR"
      return heading
    }
    return heading
  }

  function moduleTileSuffix(moduleName) {
    if (moduleDensity >= 4) return ""
    var suffix = ""
    if (barMetric === moduleName) suffix += " •"
    var expanded = moduleName === "cpu" ? cpuCoresExpanded : expandedModule === moduleName
    suffix += " " + (expanded ? "⌃" : "⌄")
    return suffix
  }

  function moduleTileValue(moduleName, fallbackValue) {
    if (moduleDensity >= 5) {
      if (moduleName === "cpu") return Math.round(cpuUsage) + "%"
      if (moduleName === "memory") return Math.round(memoryUsage) + "%"
      if (moduleName === "storage") {
        var nanoStorage = primaryStorage()
        return nanoStorage ? Model.mountPercent(nanoStorage) + "%" : "…"
      }
      if (moduleName === "gpu") {
        if (gpuUsage >= 0) return Math.round(gpuUsage) + "%"
        return gpuDisplayValue()
      }
      if (moduleName === "network") {
        var rx = networkRxRate || 0
        var tx = networkTxRate || 0
        return (rx >= tx ? "↓" : "↑") + moduleRateCompact(rx >= tx ? rx : tx)
      }
      if (moduleName === "disk")
        return moduleDiskCompactValue(false)
      return fallbackValue
    }
    if (moduleDensity >= 4) {
      if (moduleName === "network")
        return "↓" + moduleRateCompact(networkRxRate) + " ↑" + moduleRateCompact(networkTxRate)
      if (moduleName === "disk")
        return moduleDiskCompactValue(true)
      if (moduleName === "storage") {
        var microStorage = primaryStorage()
        return microStorage ? Model.mountPercent(microStorage) + "%" : fallbackValue
      }
      if (moduleName === "gpu" && gpuUsage >= 0) return Math.round(gpuUsage) + "%"
      return fallbackValue
    }
    if (moduleDensity >= 3) {
      if (moduleName === "network")
        return "↓" + moduleRateCompact(networkRxRate) + " ↑" + moduleRateCompact(networkTxRate)
      if (moduleName === "disk")
        return moduleDiskCompactValue(true)
      if (moduleName === "storage") {
        var miniStorage = primaryStorage()
        return miniStorage ? Model.mountPercent(miniStorage) + "%" : fallbackValue
      }
      return fallbackValue
    }
    return fallbackValue
  }

  function moduleTileCombinedText(moduleName, heading, fallbackValue) {
    return moduleTileHeading(moduleName, heading) + " " + moduleTileValue(moduleName, fallbackValue)
  }

  function moduleTileMinimumHeight(moduleName) {
    if (moduleDensity >= 7) return Style.space(16)
    if (moduleDensity >= 6) return Style.space(20)
    if (moduleDensity >= 5) return Style.space(22)
    if (moduleDensity >= 4) return Style.space(26)
    if (moduleDensity >= 3) return Style.space(32)
    if (moduleDensity >= 2) return Style.space(42)
    if (moduleDensity >= 1) return Style.space(58)
    return moduleName === "gpu" || moduleName === "storage" ? Style.space(108) : Style.space(94)
  }

  function graphStrokeColor(moduleName, values, opacity) {
    var color = Color.accent
    if (moduleName === "cpu" || moduleName === "memory" || moduleName === "gpu") {
      var latest = values && values.length ? values[values.length - 1] : 0
      if (usageIsUrgent(latest)) color = Color.urgent
    }
    return Util.alpha(color, opacity)
  }

  function paintTileGraph(ctx, width, height, moduleName, primary, secondary, mode) {
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    if (!primary || primary.length < 2) return
    var maximum = 100
    if (moduleName === "network" || moduleName === "disk") {
      maximum = 1
      if (primary) for (var i = 0; i < primary.length; i++) maximum = Math.max(maximum, primary[i])
      if (secondary) for (var j = 0; j < secondary.length; j++) maximum = Math.max(maximum, secondary[j])
    }

    function yFor(value) {
      return height - Math.min(1, value / maximum) * height * 0.86
    }

    function drawLineSeries(values, opacity, filled) {
      if (!values || values.length < 2) return
      var start = Math.max(0, root.historySize - values.length)
      ctx.beginPath()
      for (var k = 0; k < values.length; k++) {
        var x = width * (start + k) / Math.max(1, root.historySize - 1)
        var y = yFor(values[k])
        if (k === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }
      if (filled) {
        ctx.lineTo(width, height)
        ctx.lineTo(width * start / Math.max(1, root.historySize - 1), height)
        ctx.closePath()
        ctx.fillStyle = root.graphStrokeColor(moduleName, values, opacity * 0.2)
        ctx.fill()
        ctx.beginPath()
        for (var f = 0; f < values.length; f++) {
          var fx = width * (start + f) / Math.max(1, root.historySize - 1)
          var fy = yFor(values[f])
          if (f === 0) ctx.moveTo(fx, fy)
          else ctx.lineTo(fx, fy)
        }
      }
      ctx.strokeStyle = root.graphStrokeColor(moduleName, values, opacity)
      ctx.lineWidth = 1.4
      ctx.stroke()
    }

    function drawBarSeries(values, opacity) {
      if (!values || !values.length) return
      var count = Math.min(values.length, 24)
      var slice = values.slice(values.length - count)
      var barWidth = width / count
      ctx.fillStyle = root.graphStrokeColor(moduleName, values, opacity)
      for (var b = 0; b < slice.length; b++) {
        var barHeight = height * 0.86 * Math.min(1, slice[b] / maximum)
        var x = b * barWidth + 1
        ctx.fillRect(x, height - barHeight, Math.max(1, barWidth - 2), barHeight)
      }
    }

    if (mode === "bar") {
      drawBarSeries(secondary, 0.34)
      drawBarSeries(primary, 0.82)
      return
    }

    var filled = mode === "fill"
    drawLineSeries(secondary, 0.34, filled)
    drawLineSeries(primary, 0.82, filled)
  }

  // The selected tile supplies the compact main-bar metric. It is persisted
  // in this widget's inline shell.json settings by setBarMetric().
  readonly property string barMetric: String(setting("barMetric", "memory"))
  property var barMetricSnapshot: null
  property bool barSyncPending: false
  property string barMetricDisplayText: "…"
  readonly property string barLabel: barMetric === "network"
    ? barMetricDisplayText
    : barIcon(barMetric) + " " + barMetricDisplayText
  readonly property string barTooltip: {
    void tooltipEpoch
    void cpuUsage
    void cpuTemperature
    void cpuCores
    void memoryUsage
    void usedMemoryKB
    void totalMemoryKB
    void memoryStats
    void totalSwapKB
    void usedSwapKB
    void networkRxRate
    void networkTxRate
    void networkProcesses
    void diskReadRate
    void diskWriteRate
    void gpuUsage
    void gpuTemperature
    void gpuName
    void gpuVramUsedBytes
    void gpuVramTotalBytes
    void gpuSharedMemoryBytes
    void mounts
    return barMetricTooltip(barMetric, tooltipEpoch)
  }
  property int tooltipEpoch: 0

  function notifyTooltipRefresh() {
    tooltipEpoch += 1
  }
  readonly property string primaryNetworkInterface: String(setting("primaryNetworkInterface", ""))
  readonly property string defaultProcessSort: {
    var sort = String(setting("processSort", "memory"))
    return sort === "name" || sort === "cpu" || sort === "memory" || sort === "pid" ? sort : "memory"
  }
  readonly property int pollInterval: {
    var configured = Number(setting("pollIntervalMs", 3000))
    if (!isFinite(configured)) configured = 3000
    return Math.max(500, Math.min(15000, Math.round(configured / 500) * 500))
  }
  readonly property int backgroundPollInterval: {
    var configured = Number(setting("backgroundPollIntervalMs", 5000))
    if (!isFinite(configured) || configured <= 0) return pollInterval
    return Math.max(500, Math.min(15000, Math.round(configured / 500) * 500))
  }

  property bool cpuIncludeCores: true

  function trackMetricHistory() {
    return opened
  }

  function open() {
    controller.show()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function refreshNow() {
    if (opened) {
      refreshGpuDiscovery(true)
      refreshFull()
    } else {
      barSyncPending = true
      refreshSummary(true)
    }
  }

  function refreshSummary(includeBarDetail) {
    if (opened) return
    var detail = includeBarDetail === true
    switch (barMetric) {
    case "cpu":
      refreshCpu(detail)
      break
    case "memory":
      refreshMemory()
      break
    case "network":
      refreshNetworkRates()
      if (detail) refreshNetworkDetails()
      break
    case "disk":
      refreshDisk()
      break
    case "gpu":
      if (!availableGpus.length) refreshGpuDiscovery()
      else refreshSelectedGpuMetrics()
      break
    case "storage":
      refreshMounts()
      break
    default:
      refreshMemory()
      break
    }
    if (detail) tooltipEpoch += 1
  }

  readonly property var cpuCoreViewModes: ["bar", "fill", "spark"]
  readonly property string cpuCoreViewMode: {
    var mode = String(setting("cpuCoreViewMode", "bar"))
    return cpuCoreViewModes.indexOf(mode) >= 0 ? mode : "bar"
  }

  function cpuCoreHistory(coreId) {
    return cpuCoreHistories[String(Number(coreId))] || []
  }

  function cpuCoreViewLabel(mode) {
    if (mode === "bar") return "Bars"
    if (mode === "fill") return "Fill"
    if (mode === "spark") return "Graph"
    return "Bars"
  }

  function cycleCpuCoreViewMode() {
    var modes = cpuCoreViewModes
    var index = modes.indexOf(cpuCoreViewMode)
    var nextMode = modes[(index + 1) % modes.length]
    persistSettings({ cpuCoreViewMode: nextMode })
  }

  readonly property bool gpuGraphEnabled: setting("gpuGraphEnabled", true) !== false

  function toggleGpuGraph() {
    persistSettings({ gpuGraphEnabled: !gpuGraphEnabled })
  }

  function moduleGraphSettings() {
    var raw = setting("moduleGraphEnabled", null)
    return raw && typeof raw === "object" ? raw : ({})
  }

  function moduleGraphEnabled(moduleName) {
    if (moduleName === "gpu") return gpuGraphEnabled
    if (moduleName !== "cpu" && moduleName !== "memory" && moduleName !== "network" && moduleName !== "disk") return true
    return moduleGraphSettings()[moduleName] !== false
  }

  function toggleModuleGraph(moduleName) {
    if (moduleName === "gpu") {
      toggleGpuGraph()
      return
    }
    if (moduleName !== "cpu" && moduleName !== "memory" && moduleName !== "network" && moduleName !== "disk") return
    var stored = Object.assign({}, moduleGraphSettings())
    stored[moduleName] = !moduleGraphEnabled(moduleName)
    persistSettings({ moduleGraphEnabled: stored })
  }

  function sampleGpuHistory() {
    if (gpuUsage < 0) return
    var now = Date.now()
    if (now - gpuHistorySampleAt < pollInterval * 0.4) return
    gpuHistorySampleAt = now
    gpuHistory = Model.append(gpuHistory, gpuUsage, historySize)
  }

  function persistSettings(patch) {
    var next = Object.assign({}, root.settings, patch)
    root.settings = next
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = next
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  function persistSplit() {
    var next = Object.assign({}, root.settings, {
      moduleGridHeight: moduleGridHeight,
      processListHeight: processListHeight
    })
    root.settings = next
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = next
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  function resetLayout() {
    moduleGridHeight = defaultModuleGridHeight
    processListHeight = defaultProcessListHeight
    splitterDelta = 0
    persistSplit()
  }

  function clampSplitterDelta(delta, baseModules, baseProcesses) {
    var modules = baseModules === undefined ? moduleGridHeight : Number(baseModules)
    var processes = baseProcesses === undefined ? processListHeight : Number(baseProcesses)
    var minimumDelta = minimumModuleGridHeight - modules
    var maximumDelta = Math.min(560 - modules, processes - 120)
    return Math.max(minimumDelta, Math.min(maximumDelta, Number(delta) || 0))
  }

  function refreshFull() {
    if (!opened) return
    refreshDashboardMetrics()
    refreshProcesses()
    deferredGpuPollTimer.restart()
  }

  function refreshDashboardMetrics() {
    if (!opened) return
    dashboardPollTick += 1
    refreshCpu()
    refreshMemory()
    refreshSystem()
    refreshNetwork()
    refreshDisk()
    refreshMounts()
    refreshPressure()
    refreshCpuTemperature(false)
    if (!cpuTopologyLoaded) refreshCpuTopology()
    refreshGpuHwmonBatch()
    if (availableGpus.length) refreshSelectedGpuMetrics()
  }

  function refreshCpu(includeCores) {
    // Keep per-core samples flowing when CPU is pinned so the bar tooltip stays current.
    cpuIncludeCores = (includeCores !== false) || barMetric === "cpu"
    if (cpuProc.running) return
    cpuProc.command = ["cat", "/proc/stat"]
    cpuProc.running = true
  }

  function refreshMemory() {
    if (memInfoProc.running) return
    memInfoProc.command = ["cat", "/proc/meminfo"]
    memInfoProc.running = true
  }

  function refreshSystem() {
    if (!uptimeProc.running) {
      uptimeProc.command = ["cat", "/proc/uptime"]
      uptimeProc.running = true
    }
    if (!cpuInfoLoaded && !cpuInfoProc.running) {
      cpuInfoProc.command = ["lscpu", "-J"]
      cpuInfoProc.running = true
    }
  }

  function refreshCpuTemperature(force) {
    if (cpuTemperatureProc.running) return
    var now = Date.now()
    if (!force && now - lastSensorsAt < 10000 && !cpuCoresExpanded) return
    lastSensorsAt = now
    cpuTemperatureProc.command = ["sensors", "-j"]
    cpuTemperatureProc.running = true
  }

  function refreshGpuHwmonBatch() {
    if (gpuHwmonBatchProc.running) return
    var bdfs = gpuBdfList()
    if (!bdfs.length) return
    var script = "for bdf in " + bdfs.join(" ") + "; do "
      + "[ -d \"/sys/bus/pci/devices/$bdf\" ] || continue; "
      + "best_fan=0; "
      + "for fan in /sys/bus/pci/devices/$bdf/hwmon/hwmon*/fan*_input; do "
      + "[ -f \"$fan\" ] || continue; "
      + "v=$(cat \"$fan\" 2>/dev/null) || continue; "
      + "[ \"${v%%.*}\" -gt 0 ] 2>/dev/null || continue; "
      + "[ \"$v\" -gt \"$best_fan\" ] 2>/dev/null && best_fan=$v; "
      + "done; "
      + "[ \"$best_fan\" -gt 0 ] 2>/dev/null && echo \"$bdf fan $best_fan\"; "
      + "done"
    gpuHwmonBatchProc.command = ["bash", "-c", script]
    gpuHwmonBatchProc.running = true
  }

  function refreshNetworkRates() {
    if (networkProc.running) return
    networkProc.command = ["cat", "/proc/net/dev"]
    networkProc.running = true
  }

  function refreshNetworkDetails() {
    if (!networkInfoProc.running) {
      networkInfoProc.command = ["ip", "-j", "addr", "show", "up", "scope", "global"]
      networkInfoProc.running = true
    }
    var now = Date.now()
    if (expandedModule === "network" || barMetric === "network" || now - lastNetworkProcessAt >= 15000)
      refreshNetworkProcesses()
  }

  function refreshNetwork() {
    refreshNetworkRates()
    refreshNetworkDetails()
  }

  function refreshNetworkProcesses() {
    if (networkProcessProc.running) return
    lastNetworkProcessAt = Date.now()
    networkProcessProc.command = ["bash", "-c", "ss -H -tanpi 2>/dev/null"]
    networkProcessProc.running = true
  }

  function refreshCpuTopology() {
    if (cpuTopologyLoaded || cpuTopologyProc.running) return
    cpuTopologyProc.command = ["bash", "-c",
      "for d in /sys/devices/system/cpu/cpu[0-9]*; do "
      + "n=${d##*cpu}; c=$(cat \"$d/topology/core_id\" 2>/dev/null) || continue; "
      + "[ -n \"$c\" ] && echo \"$n $c\"; done"]
    cpuTopologyProc.running = true
  }

  function refreshDisk() {
    if (diskProc.running) return
    diskProc.command = ["cat", "/proc/diskstats"]
    diskProc.running = true
  }

  function refreshMounts() {
    if (mountProc.running) return
    mountProc.command = ["df", "-B1", "--output=source,target,used,size,pcent"]
    mountProc.running = true
  }

  function refreshPressure() {
    if (pressureProc.running) return
    pressureProc.command = ["bash", "-c",
      "for kind in cpu memory io; do "
      + "f=/proc/pressure/$kind; [ -f \"$f\" ] || continue; "
      + "line=$(head -1 \"$f\" 2>/dev/null) || continue; "
      + "echo \"$kind $line\"; done"]
    pressureProc.running = true
  }

  function setPrimaryNetworkInterface(name) {
    persistSettings({ primaryNetworkInterface: String(name || "") })
    refreshNetwork()
  }

  function formatNetworkAddresses(entry) {
    if (!entry) return ""
    var parts = []
    if (entry.ipv4) parts.push(entry.ipv4)
    if (entry.ipv6) parts.push(entry.ipv6)
    return parts.join(" · ")
  }

  function networkInterfaceAddress(name) {
    for (var index = 0; index < networkInterfaces.length; index++) {
      if (networkInterfaces[index].name === name)
        return formatNetworkAddresses(networkInterfaces[index])
    }
    return ""
  }

  function networkInterfaceIsWireless(name) {
    return GpuLogic.networkInterfaceIsWireless(name)
  }

  function networkInterfaceIsEthernet(name) {
    return GpuLogic.networkInterfaceIsEthernet(name)
  }

  function networkInterfaceKindLabel(name) {
    return GpuLogic.networkInterfaceKindLabel(name)
  }

  function networkUsedInterface() {
    if (networkActiveInterface) return networkActiveInterface
    if (primaryNetworkInterface) return primaryNetworkInterface
    return networkInterface || ""
  }

  function networkUsedInterfaceLabel() {
    var iface = networkUsedInterface()
    return networkInterfaceKindLabel(iface) || iface
  }

  function mergeNetworkInterfaceInfo() {
    if (!networkInterfaceStats.length) return
    var next = networkInterfaceStats.slice()
    for (var index = 0; index < next.length; index++)
      next[index] = Object.assign({}, next[index], { address: networkInterfaceAddress(next[index].name) })
    networkInterfaceStats = next
  }

  function memoryPressureLabel() {
    var memory = pressureStats.memory
    if (!memory || memory.avg10 === undefined) return "Unavailable"
    var value = Number(memory.avg10)
    if (!isFinite(value)) return "Unavailable"
    if (value >= 25) return "High (" + value.toFixed(1) + ")"
    if (value >= 5) return "Medium (" + value.toFixed(1) + ")"
    return "Low (" + value.toFixed(1) + ")"
  }

  function gpuProcessRows() {
    var rows = []
    for (var pid in processGpuMetricsByPid) {
      var metric = processGpuMetricsByPid[pid]
      if (!metric) continue
      var memoryBytes = metric.vramUsedBytes > 0 ? metric.vramUsedBytes : metric.sharedMemoryBytes
      var usage = metricOrUnknown(metric.usage)
      if ((!memoryBytes || memoryBytes <= 0) && usage < 0) continue
      var proc = processByPid(pid)
      rows.push({
        pid: pid,
        name: proc ? processDisplayName(proc) : ("PID " + pid),
        usage: usage,
        memoryBytes: Math.max(0, Number(memoryBytes) || 0)
      })
    }
    rows.sort(function(left, right) {
      var memoryDelta = (Number(right.memoryBytes) || 0) - (Number(left.memoryBytes) || 0)
      if (memoryDelta !== 0) return memoryDelta
      return (Number(right.usage) || 0) - (Number(left.usage) || 0)
    })
    return rows.slice(0, 12)
  }

  function gpuProcessUsageText(usage) {
    var value = Number(usage)
    if (!isFinite(value) || value < 0) return "—"
    return Math.round(value) + "%"
  }

  function gpuProcessMemoryText(bytes) {
    var value = Number(bytes)
    if (!isFinite(value) || value <= 0) return "—"
    return Model.formatBytes(value)
  }

  function gpuProcessSupportMessage() {
    if (!availableGpus.length) return "No GPU detected"
    if (gpuProcessRows().length) return ""
    var selected = availableGpus[selectedGpuIndex]
    if (!selected) return "GPU process metrics unavailable"
    if (String(selected.vendor) === "NVIDIA") return "No GPU compute clients reported by nvidia-smi"
    if (String(selected.vendor) === "Intel") return "Per-process GPU usage appears when desktop apps use DRM fdinfo"
    if (String(selected.vendor) === "AMD") return "GPU usage appears when apps use the DRM engine counters"
    return "Per-process GPU metrics unavailable for this GPU"
  }

  function instantProcessCpuPercent(pid, utime, stime, deltaSystem, coreCount) {
    var result = ProcessLogic.instantProcessCpuPercent(
      pid, utime, stime, deltaSystem, coreCount, previousProcessCpu)
    previousProcessCpu = result.previousProcessCpu
    return result.cpu
  }

  function refreshProcesses() {
    if (!opened) return
    if (processProc.running) return
    runTimedCommand(processProc, processProcTimeoutSec, [
      "bash", "-c", ProcessLogic.buildProcessRefreshScript()])
  }

  function refreshGpuDiscovery(force) {
    if (gpuDiscoveryProc.running) return
    if (!force && availableGpus.length) return
    gpuDiscoveryProc.command = ["lspci", "-Dnn"]
    gpuDiscoveryProc.running = true
  }

  function metricOrUnknown(value) {
    if (value === undefined || value === null || value === "") return -1
    var number = Number(value)
    return isFinite(number) ? number : -1
  }

  function normalizeBdf(bdf) {
    return GpuLogic.normalizeBdf(bdf)
  }

  function gpuBdfList() {
    var bdfs = []
    for (var index = 0; index < availableGpus.length; index++) {
      var bdf = normalizeBdf(availableGpus[index].bdf)
      if (bdf) bdfs.push(bdf)
    }
    return bdfs
  }

  function compactMemoryPair(usedKB, totalKB) {
    var used = Math.max(0, Number(usedKB) || 0) * 1024
    var total = Math.max(0, Number(totalKB) || 0) * 1024
    if (total >= 1073741824) {
      var usedGiB = used / 1073741824
      var totalGiB = total / 1073741824
      var usedText = usedGiB < 0.05 ? "0" : usedGiB.toFixed(usedGiB >= 10 ? 0 : 1)
      return usedText + "/" + totalGiB.toFixed(totalGiB >= 10 ? 0 : 1) + " GiB"
    }
    return Model.formatBytes(used) + "/" + Model.formatBytes(total)
  }

  function memoryDetail() {
    var value = compactMemoryPair(usedMemoryKB, totalMemoryKB)
    if (totalSwapKB > 0) value += " · SWP: " + compactMemoryPair(usedSwapKB, totalSwapKB)
    return value
  }

  function barIcon(metric) {
    if (metric === "cpu") return ""
    if (metric === "memory") return ""
    if (metric === "network") return "󰛳"
    if (metric === "disk") return "󰋊"
    if (metric === "gpu") return "󰢮"
    if (metric === "storage") return "󰆼"
    return ""
  }

  function syncBarMetricSnapshot() {
    var storage = primaryStorage()
    barMetricSnapshot = {
      cpuUsage: cpuUsage,
      memoryUsage: memoryUsage,
      networkRxRate: networkRxRate,
      diskReadRate: diskReadRate,
      gpuUsage: gpuUsage,
      storagePercent: storage ? Model.mountPercent(storage) : -1
    }
    barMetricDisplayText = barMetricValueFromSnapshot(barMetric)
  }

  function touchBarMetricSnapshot(source) {
    if (!barSyncPending || source !== barMetric) return
    barSyncPending = false
    syncBarMetricSnapshot()
  }

  function barMetricValueFromSnapshot(metric) {
    var snap = barMetricSnapshot
    if (!snap) return "…"
    if (metric === "cpu") return Math.round(snap.cpuUsage) + "%"
    if (metric === "memory") return Math.round(snap.memoryUsage) + "%"
    if (metric === "network") return "↓ " + Model.formatRate(snap.networkRxRate)
    if (metric === "disk") return "R " + Model.formatRate(snap.diskReadRate)
    if (metric === "gpu") {
      var usage = snap.gpuUsage
      return usage >= 0 ? Math.round(usage) + "%" : "…"
    }
    if (metric === "storage") {
      var percent = snap.storagePercent
      return percent >= 0 ? percent + "%" : "…"
    }
    return "…"
  }

  function barMetricTooltip(metric, epoch) {
    if (epoch === undefined) epoch = tooltipEpoch
    void epoch
    if (metric === "cpu") {
      var sorted = cpuCores.slice()
      sorted.sort(function(left, right) { return Number(left.id) - Number(right.id) })
      if (!sorted.length)
        return "CPU"
      var maxCoreNum = Number(sorted[sorted.length - 1].id) + 1
      var labelWidth = ("C" + maxCoreNum).length
      var coreGap = 3
      var usageWidth = 4
      var cpuLines = []
      for (var coreIndex = 0; coreIndex < sorted.length; coreIndex++) {
        var core = sorted[coreIndex]
        cpuLines.push(processTreePadRight("C" + (Number(core.id) + 1), labelWidth)
          + processTreePadRight("", coreGap)
          + processTreePadLeft(Math.round(Number(core.usage) || 0) + "%", usageWidth))
      }
      return "CPU\n" + cpuLines.join("\n")
    }
    if (metric === "memory") {
      var memoryLines = [
        "Used · " + compactMemoryPair(usedMemoryKB, totalMemoryKB) + " (" + Math.round(memoryUsage) + "%)",
        "Available · " + Model.formatMemory(memoryStats.MemAvailable || 0)
      ]
      if (totalSwapKB > 0) memoryLines.push("SWP · " + compactMemoryPair(usedSwapKB, totalSwapKB))
      return "Memory\n" + memoryLines.join("\n")
    }
    if (metric === "network") {
      var networkLines = ["↓ " + Model.formatRate(networkRxRate) + " · ↑ " + Model.formatRate(networkTxRate)]
      var ifaceLabel = networkUsedInterfaceLabel()
      var iface = networkUsedInterface()
      var address = networkInterfaceAddress(iface) || localIpAddress
      if (ifaceLabel || address) networkLines.push([ifaceLabel, address].filter(function(part) { return !!part }).join(" · "))
      var topNetwork = networkTopProcessLabel()
      if (topNetwork) networkLines.push(topNetwork)
      return "Network\n" + networkLines.join("\n")
    }
    if (metric === "disk") {
      return "Disk I/O\nR " + Model.formatRate(diskReadRate) + " · W " + Model.formatRate(diskWriteRate)
        + "\n" + diskDeviceLabel()
    }
    if (metric === "gpu") {
      var gpuLines = []
      if (gpuUsage >= 0) {
        var usageLine = Math.round(gpuUsage) + "%"
        if (gpuTemperature >= 0) usageLine += " · " + Math.round(gpuTemperature) + "°C"
        gpuLines.push(usageLine)
      }
      if (gpuVramTotalBytes > 0)
        gpuLines.push("VRAM · " + Model.formatBytes(gpuVramUsedBytes) + " / " + Model.formatBytes(gpuVramTotalBytes))
      else if (gpuUsesSharedMemory && gpuSharedMemoryBytes >= 0)
        gpuLines.push("Shared · " + Model.formatBytes(gpuSharedMemoryBytes) + " / " + Model.formatMemory(totalMemoryKB))
      return (gpuName || "GPU") + (gpuLines.length ? "\n" + gpuLines.join("\n") : "")
    }
    if (metric === "storage") {
      var storage = primaryStorage()
      if (!storage) return "Storage\nUnavailable"
      return "Storage\n" + Model.mountPercent(storage) + "% · " + Model.formatBytes(storage.usedBytes) + " / " + Model.formatBytes(storage.sizeBytes)
        + "\n" + storage.mount
    }
    return "Vitals"
  }

  function moduleTileTooltip(moduleName) {
    var expanded = moduleName === "cpu"
      ? cpuCoresExpanded
      : expandedModule === moduleName
    var hint = "Left click · " + (expanded ? "collapse" : "expand")
      + "\nMiddle click · pin to bar"
    if (barMetric === moduleName) hint += "\nPinned to bar"
    if (moduleName === "cpu" || moduleName === "memory" || moduleName === "network" || moduleName === "disk" || moduleName === "gpu")
      hint += "\nRight click · " + (moduleGraphEnabled(moduleName) ? "hide graph" : "show graph")
    return hint
  }

  function setBarMetric(metric) {
    if (!metric || barMetric === metric) return
    var next = Object.assign({}, root.settings, { barMetric: metric })
    root.settings = next
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = next
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
    if (metric === "network") refreshNetwork()
    else if (metric === "disk") refreshDisk()
    else if (metric === "storage") refreshMounts()
    else if (metric === "gpu") refreshGpuDiscovery()
    if (barMetricSnapshot) barMetricDisplayText = barMetricValueFromSnapshot(metric)
  }

  function setPollInterval(value) {
    var interval = Math.max(500, Math.min(15000, Math.round(Number(value) / 500) * 500))
    if (!isFinite(interval) || pollInterval === interval) return
    var next = Object.assign({}, root.settings, { pollIntervalMs: interval })
    root.settings = next
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = next
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  function pollIntervalLabel() {
    return String(pollInterval).replace(/\B(?=(\d{3})+(?!\d))/g, ",") + " ms"
  }

  function toggleModule(moduleName) {
    expandedModule = expandedModule === moduleName ? "" : moduleName
    if (expandedModule === "cpu") {
      refreshCpuTemperature(true)
      if (!cpuTopologyLoaded) refreshCpuTopology()
    }
    if (expandedModule === "network") refreshNetworkProcesses()
  }

  function cpuCoreTemperature(coreId) {
    var id = String(Number(coreId))
    var direct = cpuCoreTemperatures[id]
    if (direct !== undefined && direct !== null && direct >= 0) return Number(direct)

    var physicalId = cpuCorePhysicalIds[id]
    if (physicalId !== undefined && physicalId !== null) {
      var physical = cpuCoreTemperatures[String(Number(physicalId))]
      if (physical !== undefined && physical !== null && physical >= 0) return Number(physical)
    }
    return -1
  }

  function networkProcessRateLabel(proc) {
    if (!proc) return ""
    var parts = []
    if (proc.rxRate > 0) parts.push("↓ " + Model.formatRate(proc.rxRate))
    if (proc.txRate > 0) parts.push("↑ " + Model.formatRate(proc.txRate))
    return parts.join(" · ")
  }

  function networkTopProcess() {
    for (var index = 0; index < networkProcesses.length; index++) {
      var proc = networkProcesses[index]
      if ((proc.rxRate || 0) + (proc.txRate || 0) > 0) return proc
    }
    return null
  }

  function networkTopProcessLabel() {
    var top = networkTopProcess()
    if (!top) return ""
    var name = processDisplayName(processByPid(top.pid)) || top.name
    var rates = networkProcessRateLabel(top)
    return rates ? name + " · " + rates : name
  }

  function networkTileDetail() {
    var parts = []
    var label = networkUsedInterfaceLabel()
    if (label) parts.push(label)
    var iface = networkUsedInterface()
    var address = networkInterfaceAddress(iface) || localIpAddress
    if (address) parts.push(address)
    if (!parts.length) return "Local IP unavailable"
    return parts.join(" · ")
  }

  function cpuCoreTemperatureLabel(coreId) {
    var temp = cpuCoreTemperature(coreId)
    return temp >= 0 ? " · " + Math.round(temp) + "°" : ""
  }

  function expandedTitle() {
    if (expandedModule === "memory") return "MEM STATS"
    if (expandedModule === "network") return "NETWORK DETAILS"
    if (expandedModule === "disk") return "DISK I/O BY DEVICE"
    if (expandedModule === "gpu") return "GRAPHICS DETAILS"
    if (expandedModule === "storage") return "STORAGE VOLUMES"
    return ""
  }

  function expandedRows() {
    var rows = []
    if (expandedModule === "memory") {
      rows.push({ label: "Used", value: Model.formatMemory(usedMemoryKB) + " / " + Model.formatMemory(totalMemoryKB) })
      rows.push({ label: "Available", value: Model.formatMemory(memoryStats.MemAvailable || 0) })
      rows.push({ label: "Cache", value: Model.formatMemory((memoryStats.Cached || 0) + (memoryStats.SReclaimable || 0)) })
      if (totalSwapKB > 0)
        rows.push({ label: "SWP:", value: Model.formatMemory(usedSwapKB) + " / " + Model.formatMemory(totalSwapKB) })
    } else if (expandedModule === "network") {
      if (primaryNetworkInterface)
        rows.push({ label: "Primary interface", value: primaryNetworkInterface })
      else if (networkActiveInterface)
        rows.push({ label: "Most active", value: networkActiveInterface })
      for (var networkIndex = 0; networkIndex < networkInterfaceStats.length; networkIndex++) {
        var iface = networkInterfaceStats[networkIndex]
        var label = iface.name
        if (iface.name === primaryNetworkInterface) label += " · primary"
        else if (iface.name === networkActiveInterface) label += " · active"
        var value = "↓ " + Model.formatRate(iface.rxRate) + " · ↑ " + Model.formatRate(iface.txRate)
        if (iface.address) value += " · " + iface.address
        rows.push({
          label: label,
          value: value,
          action: "networkPrimary",
          actionData: iface.name,
          highlighted: iface.name === primaryNetworkInterface || iface.name === networkActiveInterface
        })
      }
      if (!networkInterfaceStats.length) {
        for (var fallbackIndex = 0; fallbackIndex < networkInterfaces.length; fallbackIndex++) {
          var network = networkInterfaces[fallbackIndex]
          rows.push({ label: network.name, value: formatNetworkAddresses(network) })
        }
      }
      if (networkProcesses.length) {
        var shown = 0
        for (var procIndex = 0; procIndex < networkProcesses.length && shown < 4; procIndex++) {
          var netProc = networkProcesses[procIndex]
          if ((netProc.rxRate || 0) + (netProc.txRate || 0) <= 0) continue
          var procName = processDisplayName(processByPid(netProc.pid)) || netProc.name
          rows.push({ label: procName, value: networkProcessRateLabel(netProc) })
          shown++
        }
        if (!shown) rows.push({ label: "Network usage", value: "No active traffic" })
      } else {
        rows.push({ label: "Network usage", value: "No active traffic" })
      }
    } else if (expandedModule === "disk") {
      for (var diskIndex = 0; diskIndex < diskIoDetails.length; diskIndex++) {
        var disk = diskIoDetails[diskIndex]
        rows.push({ label: disk.name, value: "R " + Model.formatRate(disk.readRate) + " · W " + Model.formatRate(disk.writeRate) })
      }
    } else if (expandedModule === "gpu") {
      var selectedGpu = availableGpus[selectedGpuIndex]
      var gpuMetric = selectedGpu ? gpuMetricsByBdf[normalizeBdf(selectedGpu.bdf)] || ({}) : ({})
      rows.push({ label: selectedGpu ? selectedGpu.displayName : "GPU", value: root.gpuDisplayValue() })
      if (gpuMetric.temperature >= 0) rows.push({ label: "Temperature", value: Math.round(gpuMetric.temperature) + "°C" })
      if (gpuMetric.vramTotalBytes > 0)
        rows.push({ label: "VRAM", value: Model.formatBytes(gpuMetric.vramUsedBytes) + " / " + Model.formatBytes(gpuMetric.vramTotalBytes) })
      else if (gpuMetric.sharedMemoryBytes >= 0)
        rows.push({ label: "Shared memory", value: Model.formatBytes(gpuMetric.sharedMemoryBytes) })
    } else if (expandedModule === "storage") {
      for (var mountIndex = 0; mountIndex < mounts.length; mountIndex++) {
        var mount = mounts[mountIndex]
        rows.push({ label: mount.mount === "/" ? "Root (/)" : mount.mount, value: Model.formatBytes(mount.usedBytes) + " / " + Model.formatBytes(mount.sizeBytes) + " · " + Model.mountPercent(mount) + "%" })
      }
    }
    return rows
  }

  function selectedGpuStats() {
    return selectedGpuBdf ? gpuMetricsByBdf[selectedGpuBdf] : null
  }

  function updateSelectedGpuMetrics() {
    if (!availableGpus.length) {
      gpuName = ""
      gpuUsage = -1
      gpuTemperature = -1
      gpuVramUsedBytes = -1
      gpuVramTotalBytes = -1
      gpuSharedMemoryBytes = -1
      gpuUsesSharedMemory = false
      touchBarMetricSnapshot("gpu")
      return
    }
    if (selectedGpuIndex < 0 || selectedGpuIndex >= availableGpus.length) selectedGpuIndex = 0
    var selected = availableGpus[selectedGpuIndex]
    selectedGpuBdf = normalizeBdf(selected.bdf || "")
    gpuName = String(selected.displayName || selected.name || "GPU")
    var stat = selectedGpuStats()
    gpuUsage = stat ? metricOrUnknown(stat.usage) : -1
    gpuTemperature = stat ? metricOrUnknown(stat.temperature) : -1
    gpuVramUsedBytes = stat ? metricOrUnknown(stat.vramUsedBytes) : -1
    gpuVramTotalBytes = stat ? metricOrUnknown(stat.vramTotalBytes) : -1
    gpuSharedMemoryBytes = stat ? metricOrUnknown(stat.sharedMemoryBytes) : -1
    gpuUsesSharedMemory = gpuVramTotalBytes <= 0 && String(selected.vendor || "").toLowerCase().indexOf("intel") !== -1
    sampleGpuHistory()
    notifyTooltipRefresh()
    touchBarMetricSnapshot("gpu")
  }

  function parseProcesses(raw) {
    var rows = String(raw || "").trim().split("\n")
    var systemCpuTimes = 0
    var coreCount = Math.max(1, cpuCores.length || 1)
    var startIndex = 0
    if (rows.length && rows[0].indexOf("__CPU__\t") === 0) {
      var meta = rows[0].split("\t")
      systemCpuTimes = Number(meta[1]) || 0
      coreCount = Math.max(1, Number(meta[2]) || coreCount)
      startIndex = 1
    }
    var deltaSystem = 0
    if (previousProcessSystemCpuTimes > 0 && systemCpuTimes > previousProcessSystemCpuTimes)
      deltaSystem = systemCpuTimes - previousProcessSystemCpuTimes

    var nextProcesses = []
    var seen = ({})
    for (var index = startIndex; index < rows.length; index++) {
      var fields = rows[index].split("\t")
      if (fields.length < 8) continue
      var pid = Number(fields[0]) || 0
      if (!pid) continue
      var key = String(pid)
      seen[key] = true
      var cpu = instantProcessCpuPercent(pid, fields[3], fields[4], deltaSystem, coreCount)
      var rss = Number(fields[5]) || 0
      var pss = Number(fields[6]) || 0
      var proc = processRecordsByPid[key]
      if (!proc) {
        proc = {
          pid: pid,
          ppid: Number(fields[1]) || 0,
          username: String(fields[2] || "").trim(),
          cpu: cpu,
          rssKB: rss,
          pssKB: pss,
          memoryKB: pss > 0 ? pss : rss,
          memoryCalculation: pss > 0 ? "pss" : "rss",
          command: String(fields[7] || "").trim(),
          fullCommand: fields.slice(8).join("\t").trim()
        }
        processRecordsByPid[key] = proc
      } else {
        proc.ppid = Number(fields[1]) || 0
        proc.username = String(fields[2] || "").trim()
        proc.cpu = cpu
        proc.rssKB = rss
        proc.pssKB = pss
        proc.memoryKB = pss > 0 ? pss : rss
        proc.memoryCalculation = pss > 0 ? "pss" : "rss"
        proc.command = String(fields[7] || "").trim()
        proc.fullCommand = fields.slice(8).join("\t").trim()
      }
      nextProcesses.push({
        pid: proc.pid,
        ppid: proc.ppid,
        username: proc.username,
        cpu: cpu,
        rssKB: proc.rssKB,
        pssKB: proc.pssKB,
        memoryKB: proc.memoryKB,
        memoryCalculation: proc.memoryCalculation,
        command: proc.command,
        fullCommand: proc.fullCommand
      })
    }
    for (var staleKey in processRecordsByPid) {
      if (!seen[staleKey]) delete processRecordsByPid[staleKey]
    }
    for (var staleCpuKey in previousProcessCpu) {
      if (!seen[staleCpuKey]) delete previousProcessCpu[staleCpuKey]
    }
    if (systemCpuTimes > 0) previousProcessSystemCpuTimes = systemCpuTimes
    processes.splice(0, processes.length)
    for (var pushIndex = 0; pushIndex < nextProcesses.length; pushIndex++)
      processes.push(nextProcesses[pushIndex])
    processMetricsEpoch += 1
    rebuildProcesses()
    markMetricsUpdated()
  }

  function parseMemory(raw) {
    var values = ({})
    var lines = String(raw || "").split("\n")
    for (var index = 0; index < lines.length; index++) {
      var parts = lines[index].match(/^([^:]+):\s+(\d+)/)
      if (parts) values[parts[1]] = Number(parts[2]) || 0
    }
    totalMemoryKB = values.MemTotal || 0
    usedMemoryKB = Math.max(0, totalMemoryKB - (values.MemAvailable || 0))
    totalSwapKB = values.SwapTotal || 0
    usedSwapKB = Math.max(0, totalSwapKB - (values.SwapFree || 0))
    memoryUsage = totalMemoryKB > 0 ? usedMemoryKB * 100 / totalMemoryKB : 0
    memoryStats = values
    memoryHistory = trackMetricHistory() ? Model.append(memoryHistory, memoryUsage, historySize) : memoryHistory
    notifyTooltipRefresh()
    touchBarMetricSnapshot("memory")
    markMetricsUpdated()
  }

  function parseCpu(raw) {
    var content = String(raw || "")
    var match = content.match(/^cpu\s+(.+)$/m)
    if (!match) return
    var values = match[1].trim().split(/\s+/).map(Number)
    var total = 0
    for (var index = 0; index < values.length; index++) total += values[index] || 0
    var idle = (values[3] || 0) + (values[4] || 0)
    if (previousCpu && total > previousCpu.total) {
      cpuUsage = Math.max(0, Math.min(100, 100 * (1 - (idle - previousCpu.idle) / (total - previousCpu.total))))
      if (trackMetricHistory()) cpuHistory = Model.append(cpuHistory, cpuUsage, historySize)
    }
    previousCpu = { total: total, idle: idle }

    if (!cpuIncludeCores) {
      notifyTooltipRefresh()
      touchBarMetricSnapshot("cpu")
      markMetricsUpdated()
      return
    }

    var lines = content.split("\n")
    var nextCores = []
    var nextPrevious = ({})
    var nextHistories = Object.assign({}, cpuCoreHistories)
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      var coreMatch = lines[lineIndex].match(/^cpu(\d+)\s+(.+)$/)
      if (!coreMatch) continue
      var coreValues = coreMatch[2].trim().split(/\s+/).map(Number)
      var coreTotal = 0
      for (var valueIndex = 0; valueIndex < coreValues.length; valueIndex++) coreTotal += coreValues[valueIndex] || 0
      var coreIdle = (coreValues[3] || 0) + (coreValues[4] || 0)
      var coreId = coreMatch[1]
      var previousCore = previousCpuCores[coreId]
      var coreUsage = 0
      if (previousCore && coreTotal > previousCore.total)
        coreUsage = Math.max(0, Math.min(100, 100 * (1 - (coreIdle - previousCore.idle) / (coreTotal - previousCore.total))))
      nextCores.push({ id: Number(coreId), usage: coreUsage })
      nextPrevious[coreId] = { total: coreTotal, idle: coreIdle }
      nextHistories[coreId] = trackMetricHistory()
        ? Model.append(nextHistories[coreId] || [], coreUsage, historySize)
        : (nextHistories[coreId] || [])
    }
    cpuCores = nextCores
    cpuCoreHistories = nextHistories
    previousCpuCores = nextPrevious
    notifyTooltipRefresh()
    touchBarMetricSnapshot("cpu")
    markMetricsUpdated()
  }

  function parseUptime(raw) {
    var seconds = Number(String(raw || "").trim().split(/\s+/)[0]) || 0
    var days = Math.floor(seconds / 86400)
    var hours = Math.floor((seconds % 86400) / 3600)
    var minutes = Math.floor((seconds % 3600) / 60)
    uptime = "up" + (days ? " " + days + "d" : "") + (hours ? " " + hours + "h" : "") + " " + minutes + "m"
  }

  function parseCpuInfo(raw) {
    try {
      var entries = JSON.parse(String(raw || "")).lscpu || []
      for (var index = 0; index < entries.length; index++) {
        if (String(entries[index].field || "").replace(/:$/, "") === "Model name") {
          cpuModel = String(entries[index].data || cpuModel || "System")
          cpuInfoLoaded = true
          return
        }
      }
    } catch (error) { warnParseFailure("lscpu JSON", error) }
    cpuInfoLoaded = true
  }

  function formatFanRpm(rpm) {
    var value = Math.round(Number(rpm))
    if (!isFinite(value) || value <= 0) return ""
    return value + " RPM"
  }

  function cpuTileBadge() {
    return formatFanRpm(cpuFanRpm)
  }

  function gpuTileBadge() {
    var stat = selectedGpuStats()
    return stat ? formatFanRpm(stat.fanRpm) : ""
  }

  function chipFanRpm(chip) {
    if (!chip || typeof chip !== "object") return -1
    var best = -1
    for (var label in chip) {
      var entry = chip[label]
      if (!entry || typeof entry !== "object") continue
      for (var key in entry) {
        if (key.indexOf("fan") === -1 || key.indexOf("_input") === -1) continue
        var rpm = metricOrUnknown(entry[key])
        if (rpm > 0) best = Math.max(best, rpm)
      }
    }
    return best
  }

  function sensorChipHaystack(chipName, chip) {
    var haystack = String(chipName || "").toLowerCase()
    for (var label in chip) haystack += " " + String(label || "").toLowerCase()
    return haystack
  }

  function sensorChipIsGpu(chipName, haystack) {
    var chipLower = String(chipName || "").toLowerCase()
    return chipLower.indexOf("amdgpu") !== -1
      || chipLower.indexOf("nvidia") !== -1
      || chipLower.indexOf("nouveau") !== -1
      || chipLower.indexOf("radeon") !== -1
      || chipLower.indexOf("i915") !== -1
      || chipLower.indexOf("xe") !== -1
      || haystack.indexOf("gpu") !== -1
      || haystack.indexOf("graphics") !== -1
  }

  function sensorChipIsCpu(chipName, haystack) {
    var chipLower = String(chipName || "").toLowerCase()
    if (sensorChipIsGpu(chipName, haystack)) return false
    if (chipLower.indexOf("k10temp") !== -1 || chipLower.indexOf("zenpower") !== -1) return false
    return haystack.indexOf("cpu") !== -1
      || chipLower.indexOf("asus") !== -1
      || chipLower.indexOf("nct") !== -1
      || chipLower.indexOf("it87") !== -1
      || chipLower.indexOf("dell") !== -1
      || chipLower.indexOf("thinkpad") !== -1
      || chipLower.indexOf("acpi_fan") !== -1
  }

  function sensorChipToBdf(chipName) {
    var text = String(chipName || "")
    var pciMatch = text.match(/([0-9a-f]{1,2}):([0-9a-f]{2})\.([0-9a-f])/i)
    if (pciMatch) return normalizeBdf(pciMatch[0])
    var compact = text.match(/-pci-([0-9a-f]{4})$/i)
    if (!compact) return ""
    var hex = compact[1].toLowerCase()
    function hex2(value) {
      var part = Number(value).toString(16)
      return part.length < 2 ? "0" + part : part
    }
    var bus = parseInt(hex.substring(0, 2), 16)
    var dev = parseInt(hex.substring(2, 3), 16)
    var fn = parseInt(hex.substring(3, 4), 16)
    if (!isFinite(bus) || !isFinite(dev) || !isFinite(fn)) return ""
    return "0000:" + hex2(bus) + ":" + hex2(dev) + "." + fn
  }

  function mapSensorFanToGpu(fanChipName, fanRpm) {
    var bdf = sensorChipToBdf(fanChipName)
    if (bdf) {
      updateGpuMetric(bdf, { fanRpm: fanRpm })
      return
    }
    var chipLower = String(fanChipName || "").toLowerCase()
    for (var index = 0; index < availableGpus.length; index++) {
      var gpu = availableGpus[index]
      var vendor = String(gpu.vendor || "").toLowerCase()
      if (vendor === "intel") continue
      if (chipLower.indexOf(vendor) !== -1 || (vendor === "amd" && chipLower.indexOf("amdgpu") !== -1)
        || (vendor === "nvidia" && chipLower.indexOf("nvidia") !== -1)) {
        updateGpuMetric(gpu.bdf, { fanRpm: fanRpm })
        return
      }
    }
  }

  function parseGpuHwmonBatch(raw) {
    var lines = String(raw || "").trim().split("\n")
    for (var index = 0; index < lines.length; index++) {
      var parts = lines[index].trim().split(/\s+/)
      if (parts.length < 3) continue
      var bdf = normalizeBdf(parts[0])
      if (!bdf) continue
      var kind = parts[1]
      var value = metricOrUnknown(parts[2])
      if (value <= 0) continue
      if (kind === "fan") updateGpuMetric(bdf, { fanRpm: value })
    }
  }

  function chipSensorTemperature(entry) {
    if (!entry || typeof entry !== "object") return -1
    for (var key in entry) {
      if (key.indexOf("temp") === -1 || key.indexOf("_input") === -1) continue
      var reading = metricOrUnknown(entry[key])
      if (reading >= 0) return reading
    }
    return -1
  }

  function parseCpuTemperature(raw) {
    try {
      var sensors = JSON.parse(String(raw || ""))
      var packageTemperature = -1
      var coreTemperatures = ({})
      for (var chipName in sensors) {
        var chipLower = chipName.toLowerCase()
        if (chipLower.indexOf("coretemp") === -1
          && chipLower.indexOf("k10temp") === -1
          && chipLower.indexOf("zenpower") === -1) continue
        var chip = sensors[chipName]
        for (var label in chip) {
          var entry = chip[label]
          var temp = chipSensorTemperature(entry)
          if (temp < 0) continue
          var labelLower = String(label || "").toLowerCase()
          if (labelLower.indexOf("package") !== -1 || labelLower === "tctl") {
            packageTemperature = temp
            continue
          }
          var core = label.match(/^Core\s+(\d+)$/i)
          if (core) coreTemperatures[String(Number(core[1]))] = temp
        }
      }
      if (packageTemperature >= 0) cpuTemperature = packageTemperature
      cpuCoreTemperatures = coreTemperatures

      var nextCpuFan = -1
      for (var fanChipName in sensors) {
        var fanChip = sensors[fanChipName]
        var fanRpm = chipFanRpm(fanChip)
        if (fanRpm <= 0) continue
        var haystack = sensorChipHaystack(fanChipName, fanChip)
        if (sensorChipIsGpu(fanChipName, haystack)) {
          mapSensorFanToGpu(fanChipName, fanRpm)
          continue
        }
        if (sensorChipIsCpu(fanChipName, haystack)) nextCpuFan = Math.max(nextCpuFan, fanRpm)
      }
      cpuFanRpm = nextCpuFan
      notifyTooltipRefresh()
    } catch (error) { /* lm-sensors is optional */ }
  }

  function parseCpuTopology(raw) {
    var next = ({})
    var lines = String(raw || "").trim().split("\n")
    for (var index = 0; index < lines.length; index++) {
      var parts = lines[index].trim().split(/\s+/)
      if (parts.length < 2) continue
      next[parts[0]] = Number(parts[1])
    }
    cpuCorePhysicalIds = next
    cpuTopologyLoaded = Object.keys(next).length > 0
  }

  function parseNetworkProcesses(raw) {
    var lines = String(raw || "").split("\n")
    var now = Date.now()
    var pending = null
    var txTotals = ({})
    var rxTotals = ({})
    var names = ({})
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index]
      var userMatch = line.match(/users:\(\(\"([^\"]+)\",pid=(\d+)/)
      if (userMatch) {
        pending = { pid: userMatch[2], name: userMatch[1] }
        names[pending.pid] = pending.name
      }
      if (line.indexOf("bytes_") < 0) continue
      var ackedMatch = line.match(/bytes_acked:(\d+)/)
      var sentMatch = line.match(/bytes_sent:(\d+)/)
      var receivedMatch = line.match(/bytes_received:(\d+)/)
      if (!ackedMatch && !sentMatch && !receivedMatch) continue
      var pid = pending ? pending.pid : null
      if (!pid) continue
      var txBytes = ackedMatch ? Number(ackedMatch[1]) : (sentMatch ? Number(sentMatch[1]) : 0)
      var rxBytes = receivedMatch ? Number(receivedMatch[1]) : 0
      txTotals[pid] = (txTotals[pid] || 0) + txBytes
      rxTotals[pid] = (rxTotals[pid] || 0) + rxBytes
      pending = null
    }

    var next = []
    var nextPrevious = ({})
    for (var pidKey in names) {
      var tx = txTotals[pidKey] || 0
      var rx = rxTotals[pidKey] || 0
      var previous = previousNetworkByPid[pidKey]
      var rxRate = 0
      var txRate = 0
      if (previous) {
        var seconds = Math.max(0.5, (now - previous.at) / 1000)
        rxRate = Math.max(0, (rx - previous.rx) / seconds)
        txRate = Math.max(0, (tx - previous.tx) / seconds)
      }
      nextPrevious[pidKey] = { rx: rx, tx: tx, at: now }
      if (!previous && rx + tx <= 0) continue
      next.push({ pid: pidKey, name: names[pidKey], rxRate: rxRate, txRate: txRate })
    }
    previousNetworkByPid = nextPrevious
    next.sort(function(left, right) {
      return (right.rxRate + right.txRate) - (left.rxRate + left.txRate)
    })
    networkProcesses = next
    notifyTooltipRefresh()
  }

  function parseNetwork(raw) {
    var lines = String(raw || "").split("\n")
    var now = Date.now()
    var nextStats = []
    var totalRx = 0
    var totalTx = 0
    var activeName = ""
    var activeTotal = -1
    var nextPrevious = ({})
    for (var index = 2; index < lines.length; index++) {
      var line = lines[index].trim()
      if (!line) continue
      var colon = line.indexOf(":")
      if (colon < 0) continue
      var name = line.slice(0, colon).trim()
      if (name === "lo") continue
      var parts = line.slice(colon + 1).trim().split(/\s+/)
      if (parts.length < 9) continue
      var rxBytes = Number(parts[0]) || 0
      var txBytes = Number(parts[8]) || 0
      totalRx += rxBytes
      totalTx += txBytes
      var previous = previousNetworkByInterface[name]
      var rxRate = 0
      var txRate = 0
      if (previous) {
        var seconds = Math.max(0.5, (now - previous.at) / 1000)
        rxRate = Math.max(0, (rxBytes - previous.rx) / seconds)
        txRate = Math.max(0, (txBytes - previous.tx) / seconds)
      }
      nextStats.push({
        name: name,
        rxRate: rxRate,
        txRate: txRate,
        rxBytes: rxBytes,
        txBytes: txBytes,
        address: networkInterfaceAddress(name)
      })
      nextPrevious[name] = { rx: rxBytes, tx: txBytes, at: now }
      var activity = rxRate + txRate
      if (activity > activeTotal) {
        activeTotal = activity
        activeName = name
      }
    }
    nextStats.sort(function(left, right) {
      return (right.rxRate + right.txRate) - (left.rxRate + left.txRate)
    })
    networkInterfaceStats = nextStats
    networkActiveInterface = activeName
    previousNetworkByInterface = nextPrevious
    mergeNetworkInterfaceInfo()

    var displayRx = totalRx
    var displayTx = totalTx
    if (primaryNetworkInterface) {
      displayRx = 0
      displayTx = 0
      for (var pick = 0; pick < nextStats.length; pick++) {
        if (nextStats[pick].name !== primaryNetworkInterface) continue
        displayRx = nextStats[pick].rxBytes
        displayTx = nextStats[pick].txBytes
        break
      }
    }
    updateIoRates("network", displayRx, displayTx)
  }

  function parseNetworkInfo(raw) {
    try {
      var interfaces = JSON.parse(String(raw || ""))
      var byName = ({})
      for (var index = 0; index < interfaces.length; index++) {
        var entry = interfaces[index]
        var name = String(entry.ifname || "Network")
        if (!byName[name]) byName[name] = { name: name, ipv4: "", ipv6: "" }
        var addresses = entry.addr_info || []
        for (var addressIndex = 0; addressIndex < addresses.length; addressIndex++) {
          var addr = addresses[addressIndex]
          if (!addr.local) continue
          if (addr.family === "inet" && !byName[name].ipv4)
            byName[name].ipv4 = String(addr.local)
          else if (addr.family === "inet6" && !byName[name].ipv6) {
            var local = String(addr.local)
            if (local.indexOf("fe80:") === 0) continue
            byName[name].ipv6 = local
          }
        }
      }
      var result = []
      for (var key in byName) result.push(byName[key])
      networkInterfaces = result
      var preferred = primaryNetworkInterface
      var picked = preferred ? result.filter(function(entry) { return entry.name === preferred })[0] : null
      if (!picked) picked = result.length ? result[0] : null
      networkInterface = picked ? picked.name : ""
      localIpAddress = formatNetworkAddresses(picked)
      mergeNetworkInterfaceInfo()
    } catch (error) { /* iproute2 is expected on Omarchy, keep the tile usable if it fails */ }
  }

  function parseDisk(raw) {
    var read = 0, write = 0, devices = []
    var current = ({})
    var lines = String(raw || "").split("\n")
    for (var index = 0; index < lines.length; index++) {
      var fields = lines[index].trim().split(/\s+/)
      if (fields.length < 10) continue
      var name = fields[2] || ""
      if (/^(loop|ram|zram|dm-|nvme.+p|sd.+\d+$)/.test(name)) continue
      read += (Number(fields[5]) || 0) * 512
      write += (Number(fields[9]) || 0) * 512
      devices.push(name)
      current[name] = { read: (Number(fields[5]) || 0) * 512, write: (Number(fields[9]) || 0) * 512 }
    }
    diskDevices = devices
    var now = Date.now()
    var details = []
    var nextPrevious = ({})
    for (var deviceName in current) {
      var counter = current[deviceName]
      var previous = previousDiskDevices[deviceName]
      var seconds = previous ? Math.max(0.5, (now - previous.at) / 1000) : 0
      details.push({
        name: deviceName,
        readRate: previous && seconds > 0 ? Math.max(0, (counter.read - previous.read) / seconds) : 0,
        writeRate: previous && seconds > 0 ? Math.max(0, (counter.write - previous.write) / seconds) : 0
      })
      nextPrevious[deviceName] = { read: counter.read, write: counter.write, at: now }
    }
    diskIoDetails = details
    previousDiskDevices = nextPrevious
    updateIoRates("disk", read, write)
  }

  function updateIoRates(kind, first, second) {
    var now = Date.now()
    var previous = kind === "network" ? previousNetwork : previousDisk
    var seconds = previous && previous.at > 0 ? Math.max(0.5, (now - previous.at) / 1000) : 0
    if (previous && seconds > 0) {
      var firstRate = Math.max(0, (first - previous.first) / seconds)
      var secondRate = Math.max(0, (second - previous.second) / seconds)
      if (kind === "network") {
        networkRxRate = firstRate; networkTxRate = secondRate
        if (trackMetricHistory()) {
          rxHistory = Model.append(rxHistory, firstRate, historySize)
          txHistory = Model.append(txHistory, secondRate, historySize)
        }
      } else {
        diskReadRate = firstRate; diskWriteRate = secondRate
        if (trackMetricHistory()) {
          readHistory = Model.append(readHistory, firstRate, historySize)
          writeHistory = Model.append(writeHistory, secondRate, historySize)
        }
      }
      touchBarMetricSnapshot(kind)
    }
    var next = { first: first, second: second, at: now }
    if (kind === "network") previousNetwork = next
    else previousDisk = next
    if (previous && seconds > 0) notifyTooltipRefresh()
  }

  function parseMounts(raw) {
    var result = []
    var lines = String(raw || "").trim().split("\n")
    for (var index = 1; index < lines.length; index++) {
      var fields = lines[index].trim().split(/\s+/)
      if (fields.length < 5 || fields[0].indexOf("/dev/") !== 0) continue
      result.push({
        source: fields[0],
        mount: fields[1],
        usedBytes: Number(fields[2]) || 0,
        sizeBytes: Number(fields[3]) || 0,
        percent: fields[4]
      })
    }
    mounts = result
    notifyTooltipRefresh()
    touchBarMetricSnapshot("storage")
  }

  function parsePressure(raw) {
    var next = Object.assign({}, pressureStats)
    var lines = String(raw || "").trim().split("\n")
    for (var index = 0; index < lines.length; index++) {
      var parts = lines[index].trim().split(/\s+/)
      if (parts.length < 2) continue
      var kind = parts[0]
      var values = ({})
      for (var tokenIndex = 1; tokenIndex < parts.length; tokenIndex++) {
        var pair = parts[tokenIndex].split("=")
        if (pair.length !== 2) continue
        values[pair[0]] = Number(pair[1])
      }
      next[kind] = values
    }
    pressureStats = next
  }

  function primaryStorage() {
    for (var index = 0; index < mounts.length; index++) {
      if (mounts[index].mount === "/") return mounts[index]
    }
    return mounts.length ? mounts[0] : null
  }

  function diskDeviceLabel() {
    return diskDevices.length ? diskDevices.join(", ") : "No physical disk counter"
  }

  function otherStorageCount() {
    var primary = primaryStorage()
    var sources = []
    for (var index = 0; index < mounts.length; index++) {
      var source = String(mounts[index].source || "")
      if (source && sources.indexOf(source) === -1) sources.push(source)
    }
    return primary && sources.length > 1 ? sources.length - 1 : 0
  }

  function parseGpuDiscovery(raw) {
    var result = []
    var lines = String(raw || "").split("\n")
    for (var index = 0; index < lines.length; index++) {
      var match = lines[index].match(/^([0-9a-fA-F:.]+)\s+(?:VGA compatible controller|3D controller|Display controller).*?\[([0-9a-fA-F]{4}:[0-9a-fA-F]{4})\]/)
      if (!match) continue
      var pciId = match[2].toLowerCase()
      var vendorId = pciId.split(":")[0]
      var vendor = vendorId === "10de" ? "NVIDIA" : vendorId === "1002" ? "AMD" : vendorId === "8086" ? "Intel" : "GPU"
      var marker = lines[index].indexOf("]: ")
      var name = (marker >= 0 ? lines[index].slice(marker + 3) : lines[index])
        .replace(/\s*\[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\].*$/, "")
      var shortName = name.match(/\[([^\]]+)\]/)
      if (shortName) name = shortName[1]
      result.push({ bdf: normalizeBdf(match[1]), pciId: pciId, vendor: vendor, displayName: name })
    }
    availableGpus = result
    updateSelectedGpuMetrics()
    refreshGpuHwmonBatch()
    if (opened || barMetric === "gpu") refreshSelectedGpuMetrics()
    maybeSetupIntelGpu()
  }

  function hasIntelGpu() {
    for (var index = 0; index < availableGpus.length; index++) {
      if (String(availableGpus[index].vendor) === "Intel") return true
    }
    return false
  }

  function maybeSetupIntelGpu() {
    if (!opened || !hasIntelGpu()) return
    if (intelGpuTopState === "ok") return
    if (intelGpuSetupPending || intelGpuSetupCheckProc.running || intelGpuSetupProc.running) return
    intelGpuSetupCheckProc.command = ["bash", "-c",
      "path=$(command -v intel_gpu_top 2>/dev/null) || true; "
      + "if [ -z \"$path\" ]; then printf '__INTEL_SETUP__\\tmissing\\n'; exit 0; fi; "
      + "if getcap \"$path\" 2>/dev/null | grep -q cap_perfmon; then printf '__INTEL_SETUP__\\tready\\n'; exit 0; fi; "
      + "printf '__INTEL_SETUP__\\tneeds_cap\\n'"]
    intelGpuSetupCheckProc.running = true
  }

  function parseIntelGpuSetupCheck(raw) {
    var line = String(raw || "").trim().split("\n")[0]
    if (line.indexOf("__INTEL_SETUP__\tmissing") === 0) {
      intelGpuTopState = "missing"
      startIntelGpuInstall()
      return
    }
    if (line.indexOf("__INTEL_SETUP__\tneeds_cap") === 0) {
      intelGpuTopState = "denied"
      startIntelGpuSetcap()
      return
    }
    if (line.indexOf("__INTEL_SETUP__\tready") === 0) {
      intelGpuTopState = "ok"
      intelGpuSetupPending = false
      if (actionMessage.indexOf("Intel GPU") >= 0 || actionMessage.indexOf("intel-gpu-tools") >= 0)
        actionMessage = ""
      refreshSelectedGpuMetrics()
    }
  }

  function startIntelGpuInstall() {
    if (intelGpuSetupProc.running) return
    intelGpuSetupPending = true
    actionMessage = "Install intel-gpu-tools for Intel GPU monitoring…"
    intelGpuSetupProc.command = ["bash", "-c",
      "if command -v pacman >/dev/null 2>&1; then "
      + "  exec pkexec pacman -S --needed --noconfirm intel-gpu-tools; "
      + "elif command -v apt-get >/dev/null 2>&1; then "
      + "  exec pkexec apt-get install -y intel-gpu-tools; "
      + "elif command -v dnf >/dev/null 2>&1; then "
      + "  exec pkexec dnf install -y intel-gpu-tools; "
      + "else exit 127; fi"]
    intelGpuSetupProc.running = true
  }

  function startIntelGpuSetcap() {
    if (intelGpuSetupProc.running) return
    intelGpuSetupPending = true
    actionMessage = "Setting up Intel GPU monitoring…"
    intelGpuSetupProc.command = ["bash", "-c",
      "path=$(command -v intel_gpu_top) || exit 1; exec pkexec setcap cap_perfmon=ep \"$path\""]
    intelGpuSetupProc.running = true
  }

  function finishIntelGpuSetup(exitCode) {
    intelGpuSetupPending = false
    if (exitCode === 0) {
      actionMessage = "Intel GPU monitoring ready"
      intelGpuSetupMessageTimer.restart()
      maybeSetupIntelGpu()
      afterActionRefresh.restart()
      return
    }
    if (exitCode === 127)
      actionMessage = "Install intel-gpu-tools manually for Intel GPU usage"
    else
      actionMessage = "Intel GPU setup cancelled or failed — reopen the dashboard to retry"
  }

  function gpuNeedsFdInfo() {
    for (var index = 0; index < availableGpus.length; index++) {
      var vendor = String(availableGpus[index].vendor || "")
      if (vendor === "Intel" || vendor === "AMD") return true
    }
    return false
  }

  function displayGpuUsage(percent, fdinfoDerived) {
    return GpuLogic.displayGpuUsage(percent, fdinfoDerived)
  }

  function gpuEngineUsagePercent(deltaNs, intervalMs) {
    return GpuLogic.gpuEngineUsagePercent(deltaNs, intervalMs)
  }

  function maxGpuEngineUsage(current, previous, intervalMs) {
    return GpuLogic.maxGpuEngineUsage(current, previous, intervalMs)
  }

  function addGpuEngineTotal(map, key, engine, nanoseconds) {
    GpuLogic.addGpuEngineTotal(map, key, engine, nanoseconds)
  }

  function refreshIntelGpuTopOnly() {
    if (!opened || !selectedGpuBdf || !availableGpus.length) return
    var selected = availableGpus[selectedGpuIndex]
    if (!selected || String(selected.vendor) !== "Intel" || intelGpuTopProc.running) return
    var now = Date.now()
    var gpuPollGap = opened ? pollInterval : backgroundPollInterval
    if (now - lastIntelGpuTopAt < gpuPollGap * 0.85) return
    var sampleMs = Math.min(1000, Math.max(500, Math.round(pollInterval * 0.5)))
    lastIntelGpuTopAt = now
    intelGpuTopBdf = selectedGpuBdf
    runTimedCommand(intelGpuTopProc, intelGpuTopTimeoutSec, ["bash", "-c",
      "if ! command -v intel_gpu_top >/dev/null 2>&1; then "
      + "  printf '__INTEL_ERR__\\tmissing\\n'; exit 0; "
      + "fi; "
      + "out=$(intel_gpu_top -s " + sampleMs + " -n 1 -J -d pci:slot=" + selectedGpuBdf + " 2>&1) || true; "
      + "if [ -z \"$out\" ] || echo \"$out\" | grep -qi 'permission denied\\|failed to initialize pmu'; then "
      + "  printf '__INTEL_ERR__\\tdenied\\n'; exit 0; "
      + "fi; "
      + "printf '%s' \"$out\""])
  }

  function refreshSelectedGpuMetrics() {
    if (!selectedGpuBdf) return
    var selected = availableGpus[selectedGpuIndex]
    if (!selected) return
    refreshGpuHwmonBatch()
    var wantFdInfo = gpuNeedsFdInfo()
      && (expandedModule === "gpu" || barMetric === "gpu" || gpuFdInfoPollTick % 2 === 0)
    if (wantFdInfo && !gpuFdInfoProc.running) {
      gpuFdInfoPollTick += 1
      runTimedCommand(gpuFdInfoProc, gpuFdInfoTimeoutSec, ["bash", "-c",
        "for dev in /sys/bus/pci/devices/*; do "
        + "  [ -f \"$dev/gpu_busy_percent\" ] || continue; "
        + "  val=$(cat \"$dev/gpu_busy_percent\" 2>/dev/null) || continue; "
        + "  printf '__BUSY__\\t%s\\t%s\\n' \"$(basename \"$dev\")\" \"$val\"; "
        + "done; "
        + "find /proc -maxdepth 3 -user " + currentUser + " -path '/proc/[0-9]*/fdinfo/*' -type f "
        + "-exec grep -s -H -E '^(drm-client-id:|drm-pdev:|drm-resident-system|drm-engine-)' {} + 2>/dev/null; "
        + "printf '__GPU__\\t%s\\n' \"$(date +%s%3N)\""])
    }
    if (String(selected.vendor) === "NVIDIA") {
      if (!nvidiaProc.running) {
        runTimedCommand(nvidiaProc, 6, ["nvidia-smi", "--query-gpu=pci.bus_id,utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"])
      }
      if (!nvidiaProcessProc.running) {
        runTimedCommand(nvidiaProcessProc, 6, ["nvidia-smi", "--query-compute-apps=pid,used_memory", "--format=csv,noheader,nounits"])
      }
      return
    }
    if (String(selected.vendor) === "AMD" && !gpuSensorFindProc.running) {
      gpuSensorFindProc.command = ["find", "/sys/bus/pci/devices/" + selectedGpuBdf + "/hwmon", "-type", "f", "-name", "temp*_input", "-print", "-quit"]
      gpuSensorFindProc.running = true
    }
    if (String(selected.vendor) === "AMD") {
      if (!gpuVramUsedProc.running) {
        gpuVramUsedProc.command = ["cat", "/sys/bus/pci/devices/" + selectedGpuBdf + "/mem_info_vram_used"]
        gpuVramUsedProc.running = true
      }
      if (!gpuVramTotalProc.running) {
        gpuVramTotalProc.command = ["cat", "/sys/bus/pci/devices/" + selectedGpuBdf + "/mem_info_vram_total"]
        gpuVramTotalProc.running = true
      }
    }
  }

  function updateGpuMetric(bdf, values) {
    var key = normalizeBdf(bdf)
    if (!key) return
    var next = Object.assign({}, gpuMetricsByBdf)
    next[key] = Object.assign({}, next[key] || {}, values)
    gpuMetricsByBdf = next
    updateSelectedGpuMetrics()
  }

  function parseIntelGpuTop(raw) {
    var text = String(raw || "").trim()
    var bdf = normalizeBdf(intelGpuTopBdf)
    if (text.indexOf("__INTEL_ERR__\tmissing") === 0) {
      intelGpuTopState = "missing"
      maybeSetupIntelGpu()
      return
    }
    if (text.indexOf("__INTEL_ERR__\tdenied") === 0) {
      intelGpuTopState = "denied"
      maybeSetupIntelGpu()
      return
    }
    if (!text || !bdf) return
    try {
      var sample = GpuLogic.parseIntelGpuTopSample(text)
      if (!sample) {
        warnParseFailure("intel_gpu_top", "no sample")
        return
      }
      var maxBusy = GpuLogic.intelGpuTopUsage(sample)
      if (maxBusy < 0) {
        warnParseFailure("intel_gpu_top", "no engine data")
        return
      }
      intelGpuTopState = "ok"
      updateGpuMetric(bdf, { usage: displayGpuUsage(maxBusy, false) })
      markMetricsUpdated()
    } catch (error) {
      warnParseFailure("intel_gpu_top", error)
    }
  }

  function parseNvidia(raw) {
    try {
      var lines = String(raw || "").trim().split("\n")
      for (var index = 0; index < lines.length; index++) {
        var values = lines[index].split(",")
        if (values.length < 5) continue
        var bdf = normalizeBdf(values[0].trim())
        var metric = {
          usage: displayGpuUsage(metricOrUnknown(values[1].trim()), false),
          temperature: metricOrUnknown(values[2].trim()),
          vramUsedBytes: metricOrUnknown(values[3].trim()) * 1048576,
          vramTotalBytes: metricOrUnknown(values[4].trim()) * 1048576
        }
        updateGpuMetric(bdf, metric)
      }
      markMetricsUpdated()
    } catch (error) {
      warnParseFailure("nvidia-smi", error)
    }
  }

  function parseGpuFdInfo(raw) {
    try {
      var lines = String(raw || "").split("\n")
      var intervalMs = 0
      var activeFile = ""
      var activePid = ""
      var activeBdf = ""
      var clientId = ""
      var enginesByPid = ({})
      var sharedByBdf = ({})
      var sharedByPid = ({})
      var seenMemoryClients = ({})
      var seenProcessMemory = ({})
      var seenProcessEngines = ({})

      for (var index = 0; index < lines.length; index++) {
        var line = lines[index]
        if (!line) continue
        if (line.indexOf("__GPU__\t") === 0) {
          var sample = line.split("\t")
          var sampleEndMs = Number(sample[1]) || 0
          if (previousGpuSampleEndMs > 0 && sampleEndMs > previousGpuSampleEndMs)
            intervalMs = sampleEndMs - previousGpuSampleEndMs
          if (sampleEndMs > 0) previousGpuSampleEndMs = sampleEndMs
          continue
        }
        if (line.indexOf("__BUSY__\t") === 0) {
          var busy = line.split("\t")
          var busyBdf = normalizeBdf(busy[1])
          var busyUsage = Number(busy[2])
          if (busyBdf && isFinite(busyUsage))
            updateGpuMetric(busyBdf, { usage: displayGpuUsage(busyUsage, false) })
          continue
        }

        var source = line.match(/^(\/proc\/(\d+)\/fdinfo\/[^:]+):(.*)$/)
        if (!source) continue
        if (source[1] !== activeFile) {
          activeFile = source[1]
          activePid = source[2]
          activeBdf = ""
          clientId = ""
        }
        line = source[3]
        var client = line.match(/^drm-client-id:\s+(\d+)$/)
        if (client) {
          clientId = client[1]
          activeBdf = ""
          continue
        }
        var pdev = line.match(/^drm-pdev:\s+(.+)$/)
        if (pdev) { activeBdf = normalizeBdf(pdev[1].trim()); continue }
        if (!activeBdf) continue

        var memory = line.match(/^drm-resident-system\d*:\s+([0-9.]+)(?:\s+(KiB|MiB|GiB))?$/)
        if (memory) {
          var scale = memory[2] === "GiB" ? 1073741824 : memory[2] === "MiB" ? 1048576 : memory[2] === "KiB" ? 1024 : 1
          var memoryKey = activeBdf + ":" + clientId
          if (!seenMemoryClients[memoryKey]) {
            sharedByBdf[activeBdf] = (sharedByBdf[activeBdf] || 0) + Number(memory[1]) * scale
            seenMemoryClients[memoryKey] = true
          }
          var processMemoryKey = activePid + ":" + memoryKey
          if (!seenProcessMemory[processMemoryKey]) {
            sharedByPid[activePid] = (sharedByPid[activePid] || 0) + Number(memory[1]) * scale
            seenProcessMemory[processMemoryKey] = true
          }
          continue
        }

        var engine = line.match(/^drm-engine-([^:]+):\s+(\d+)\s+ns$/)
        if (!engine) continue
        var engineName = String(engine[1])
        var engineNs = Number(engine[2]) || 0
        var engineKey = activeBdf + ":" + clientId + ":" + engineName
        var processEngineKey = activePid + ":" + engineKey
        if (!seenProcessEngines[processEngineKey]) {
          addGpuEngineTotal(enginesByPid, activePid, engineName, engineNs)
          seenProcessEngines[processEngineKey] = true
        }
      }

      for (var bdf in sharedByBdf)
        updateGpuMetric(bdf, { sharedMemoryBytes: sharedByBdf[bdf] })

      var nextPreviousPid = ({})
      var nextProcessMetrics = ({})
      var allPids = ({})
      for (var sharedPid in sharedByPid) allPids[sharedPid] = true
      for (var enginePid in enginesByPid) allPids[enginePid] = true
      for (var pid in allPids) {
        var processUsage = intervalMs >= 500
          ? maxGpuEngineUsage(enginesByPid[pid], previousGpuEnginesByPid[pid], intervalMs)
          : -1
        processUsage = displayGpuUsage(processUsage, true)
        var previousMetric = processGpuMetricsByPid[pid]
        nextProcessMetrics[pid] = ({})
        if (sharedByPid[pid] !== undefined) nextProcessMetrics[pid].sharedMemoryBytes = sharedByPid[pid]
        if (processUsage >= 0) nextProcessMetrics[pid].usage = processUsage
        else if (previousMetric && previousMetric.usage >= 0) nextProcessMetrics[pid].usage = previousMetric.usage
        nextPreviousPid[pid] = enginesByPid[pid] || ({})
      }
      processGpuMetricsByPid = nextProcessMetrics
      previousGpuEnginesByPid = nextPreviousPid
      markMetricsUpdated()
    } catch (error) {
      warnParseFailure("gpu fdinfo", error)
    }
  }

  function processGpuDetails(pid) {
    var metric = processGpuMetricsByPid[String(pid)]
    if (!metric) return ""
    var details = []
    if (metric.vramUsedBytes > 0) details.push("GPU VRAM " + Model.formatBytes(metric.vramUsedBytes))
    if (metric.sharedMemoryBytes >= 0) details.push("GPU shared " + Model.formatBytes(metric.sharedMemoryBytes))
    if (metric.usage >= 0) details.push(Math.round(metric.usage) + "% GPU active")
    return details.join(" · ")
  }

  function parseNvidiaProcesses(raw) {
    try {
      var next = Object.assign({}, processGpuMetricsByPid)
      var lines = String(raw || "").trim().split("\n")
      for (var index = 0; index < lines.length; index++) {
        var values = lines[index].split(",")
        if (values.length < 2) continue
        var pid = String(Number(values[0].trim()) || "")
        var usedMiB = Number(values[1].trim())
        if (!pid || !isFinite(usedMiB)) continue
        next[pid] = Object.assign({}, next[pid] || {}, { vramUsedBytes: usedMiB * 1048576 })
      }
      processGpuMetricsByPid = next
      markMetricsUpdated()
    } catch (error) {
      warnParseFailure("nvidia-smi processes", error)
    }
  }
  function processMemoryKB(process) {
    if (!process) return 0
    if (processMemoryMode === "rss") return Number(process.rssKB || process.memoryKB) || 0
    if (processMemoryMode === "pss") return Number(process.pssKB || process.rssKB || process.memoryKB) || 0
    return Number(process.memoryKB || process.pssKB || process.rssKB) || 0
  }

  function processMemoryLabel(process) {
    if (processMemoryMode === "rss") return "RSS"
    if (processMemoryMode === "pss") return "PSS"
    return String(process && process.memoryCalculation || "rss") === "pss" ? "PSS" : "RSS"
  }

  function processCpuPercent(process) {
    processMetricsEpoch
    return Number(process && process.cpu) || 0
  }

  function processCpuLabel(process) {
    return processCpuPercent(process).toFixed(1) + "%"
  }

  // `ps comm` is limited to 15 characters on Linux. Prefer the first token
  // of the full command so process titles such as gpu-screen-recorder remain
  // readable in the list.
  function processDisplayName(process) {
    var fullCommand = String(process && process.fullCommand || "").trim()
    if (fullCommand) {
      var name = fullCommand.split(/\s+/)[0]
      // Only strip actual filesystem paths. Kernel worker names such as
      // [kworker/R-kthrotld] contain a slash as part of their name.
      if (name.indexOf("/") === 0) {
        var slash = name.lastIndexOf("/")
        if (slash >= 0) name = name.slice(slash + 1)
      }
      if (name.length > 1 && name[0] === "[" && name[name.length - 1] === "]") {
        name = name.slice(1, -1)
      }
      if (name) return name
    }
    return String(process && process.command || "unknown")
  }

  function processTreeShortSuffix(process) {
    var cmd = String(process && process.fullCommand || process.command || "").trim()
    if (!cmd) return ""
    var token = cmd.split(/\s+/)[0]
    if (token.indexOf("/") === 0) {
      var slash = token.lastIndexOf("/")
      if (slash >= 0) token = token.slice(slash + 1)
    }
    if (token.length > 1 && token[0] === "[" && token[token.length - 1] === "]")
      token = token.slice(1, -1)
    var name = processDisplayName(process)
    if (!token || token === name) return ""
    return " (" + token + ")"
  }

  function processTreeDirectChildren(parentPid) {
    var children = []
    for (var index = 0; index < processes.length; index++) {
      if (String(processes[index].ppid || "") === String(parentPid || ""))
        children.push(processes[index])
    }
    return sortProcessArray(children)
  }

  function cycleProcessMemoryMode() {
    var modes = ["rss", "pss"]
    var index = modes.indexOf(processMemoryMode)
    processMemoryMode = modes[(index + 1) % modes.length]
  }

  function gpuDisplayValue() {
    if (gpuUsage < 0) {
      var selected = availableGpus[selectedGpuIndex]
      if (selected && String(selected.vendor) === "Intel") {
        if (intelGpuTopState === "missing") return "Install intel-gpu-tools"
        if (intelGpuTopState === "denied") return "PMU access needed"
        return "…"
      }
      return "Activity unavailable"
    }
    return Math.round(gpuUsage) + "% active"
  }

  function gpuIntelSetupHint() {
    if (intelGpuSetupPending)
      return "Approve the system prompt to finish Intel GPU setup."
    if (intelGpuTopState === "missing")
      return "intel-gpu-tools will be installed on first open (requires approval)."
    if (intelGpuTopState === "denied")
      return "PMU access is granted once via setcap and persists across reboot."
    return ""
  }

  function gpuMemoryPercent() {
    var total = gpuVramTotalBytes > 0 ? gpuVramTotalBytes
      : gpuUsesSharedMemory ? totalMemoryKB * 1024 : 0
    var used = gpuVramTotalBytes > 0 ? gpuVramUsedBytes : gpuSharedMemoryBytes
    return total > 0 && used >= 0 ? Math.max(0, Math.min(100, used * 100 / total)) : 0
  }

  function gpuDetails() {
    var values = []
    var intelHint = gpuIntelSetupHint()
    if (intelHint) values.push(intelHint)
    if (gpuTemperature >= 0) values.push(Math.round(gpuTemperature) + "°C")
    if (gpuVramTotalBytes > 0) values.push("VRAM " + Model.formatBytes(gpuVramUsedBytes) + " / " + Model.formatBytes(gpuVramTotalBytes))
    else if (gpuUsesSharedMemory) values.push(gpuSharedMemoryBytes >= 0 ? "Shared " + Model.formatBytes(gpuSharedMemoryBytes) + " / " + Model.formatMemory(totalMemoryKB) + " RAM" : "Integrated · shared system memory")
    else values.push("VRAM not reported by driver")
    return values.join(" · ")
  }

  function sortProcessArray(list) {
    var key = processSort
    var ascending = processSortAscending
    list.sort(function(left, right) {
      var a
      var b
      if (key === "name") {
        a = processDisplayName(left).toLowerCase()
        b = processDisplayName(right).toLowerCase()
        return ascending ? a.localeCompare(b) : b.localeCompare(a)
      }
      a = key === "memory" ? processMemoryKB(left) : Number(key === "pid" ? left.pid : left.cpu) || 0
      b = key === "memory" ? processMemoryKB(right) : Number(key === "pid" ? right.pid : right.cpu) || 0
      return ascending ? a - b : b - a
    })
    return list
  }

  function collectFilteredProcesses() {
    var result = []
    var source = processes || []
    var search = String(root.processSearch || "").toLowerCase()
    for (var index = 0; index < source.length; index++) {
      var process = source[index]
      if (!process) continue
      if (processFilter === "user" && process.username !== currentUser) continue
      if (processFilter === "system" && process.username === currentUser) continue
      if (search
        && root.processDisplayName(process).toLowerCase().indexOf(search) === -1
        && String(process.command || "").toLowerCase().indexOf(search) === -1
        && String(process.fullCommand || "").toLowerCase().indexOf(search) === -1
        && String(process.pid || "").indexOf(search) === -1) continue
      result.push(process)
    }
    return result
  }

  function processListView() {
    return processListSection.listView
  }

  function captureProcessScroll(fromUserMovement) {
    var list = processListView()
    if (!list || processListRestoringScroll) return
    var y = list.contentY
    var origin = list.originY
    if (y <= origin + processScrollTopThreshold) {
      if (!processListScrollLocked) return
      if (!fromUserMovement && processScrollContentY > origin + processScrollUnlockThreshold) return
      processListScrollLocked = false
      processScrollAnchorPid = ""
      processScrollContentY = 0
      return
    }
    processListScrollLocked = true
    processScrollContentY = y
    saveProcessScrollAnchor()
  }

  function scrollProcessListToTop() {
    var list = processListView()
    if (!list) return
    processListRestoringScroll = true
    list.contentY = list.originY
    processListScrollLocked = false
    processScrollAnchorPid = ""
    processScrollContentY = 0
    Qt.callLater(function() { root.processListRestoringScroll = false })
  }

  function scrollProcessListToBottom() {
    var list = processListView()
    if (!list || list.count <= 0) return
    processListRestoringScroll = true
    list.positionViewAtIndex(list.count - 1, ListView.End)
    processListScrollLocked = true
    Qt.callLater(function() {
      root.captureProcessScroll(true)
      root.processListRestoringScroll = false
    })
  }

  function saveProcessScrollAnchor() {
    var list = processListView()
    if (!list) return
    var idx = list.indexAt(2, list.contentY + 4)
    if (idx < 0) idx = 0
    if (idx < filteredProcesses.length)
      processScrollAnchorPid = String(filteredProcesses[idx].pid || "")
  }

  function scheduleProcessScrollRestore() {
    if (!processListScrollLocked) return
    Qt.callLater(function() {
      root.restoreProcessScroll()
      Qt.callLater(function() {
        if (root.processListScrollLocked) root.restoreProcessScroll()
      })
    })
  }

  function restoreProcessScroll() {
    if (!processListScrollLocked) return
    var list = processListView()
    if (!list) return
    processListRestoringScroll = true
    var restored = false
    if (processScrollAnchorPid) {
      for (var index = 0; index < filteredProcesses.length; index++) {
        if (String(filteredProcesses[index].pid || "") !== processScrollAnchorPid) continue
        list.positionViewAtIndex(index, ListView.Beginning)
        restored = true
        break
      }
    }
    if (!restored && processScrollContentY > list.originY) {
      var maximumY = Math.max(list.originY, list.contentHeight - list.height)
      list.contentY = Math.max(list.originY, Math.min(processScrollContentY, maximumY))
    }
    Qt.callLater(function() {
      var current = root.processListView()
      if (current) processScrollContentY = current.contentY
      root.processListRestoringScroll = false
    })
  }

  function processListSameOrder(current, desired) {
    if (!current || !desired || current.length !== desired.length) return false
    for (var index = 0; index < current.length; index++) {
      if (String(current[index].pid) !== String(desired[index].pid)) return false
    }
    return true
  }

  function rebuildProcesses() {
    var source = processes || []
    var filtered = collectFilteredProcesses()
    var desired = sortProcessArray(filtered.slice())

    var nextCountLabel = desired.length === source.length
      ? "PROCESSES (" + source.length + ")"
      : "PROCESSES (" + desired.length + " of " + source.length + ")"
    if (nextCountLabel !== processCountLabel) processCountLabel = nextCountLabel

    filteredProcesses = desired
  }

  function processByPid(pid) {
    var wanted = String(pid || "")
    for (var index = 0; index < processes.length; index++) {
      if (String(processes[index].pid || "") === wanted) return processes[index]
    }
    return null
  }

  function processTreeRows(pid) {
    var root = processByPid(pid)
    if (!root) return []

    function buildNode(proc) {
      var kids = processTreeDirectChildren(proc.pid)
      var nodes = []
      for (var index = 0; index < kids.length; index++)
        nodes.push(buildNode(kids[index]))
      return { entry: proc, children: nodes }
    }

    var ordered = []
    function collectPrefixes(node, isLast, header, depth) {
      var proc = node.entry
      var hasChildren = node.children.length > 0
      var branch = (isLast && !hasChildren) ? "\u2514\u2500" : "\u251C\u2500"
      ordered.push({ process: proc, prefix: header + branch })
      for (var childIndex = 0; childIndex < node.children.length; childIndex++) {
        var childHeader = depth === 0
          ? (isLast ? "" : "\u2502  ")
          : header + (isLast ? "   " : "\u2502  ")
        collectPrefixes(
          node.children[childIndex],
          childIndex === node.children.length - 1,
          childHeader,
          depth + 1)
      }
    }

    collectPrefixes(buildNode(root), true, "", 0)
    return ordered
  }

  function processTreeLine(row) {
    if (!row || !row.process) return ""
    return String(row.prefix || "")
      + String(row.process.pid || "")
      + " "
      + processDisplayName(row.process)
      + processTreeShortSuffix(row.process)
  }

  function processTreePadRight(text, width) {
    var value = String(text || "")
    while (value.length < width) value += " "
    return value
  }

  function processTreePadLeft(text, width) {
    var value = String(text || "")
    while (value.length < width) value = " " + value
    return value
  }

  function processTreeStats(proc) {
    var cpu = (Number(proc && proc.cpu) || 0).toFixed(1) + "%"
    var mem = Model.formatMemory(processMemoryKB(proc))
    return processTreePadLeft(cpu, 6) + "  " + processTreePadLeft(mem, 8)
  }

  function processTreeBlockText(pid) {
    var rows = processTreeRows(pid)
    if (!rows.length) return ""
    var labels = []
    for (var labelIndex = 0; labelIndex < rows.length; labelIndex++)
      labels.push(processTreeLine(rows[labelIndex]))
    var labelWidth = 0
    for (var widthIndex = 0; widthIndex < labels.length; widthIndex++)
      if (labels[widthIndex].length > labelWidth) labelWidth = labels[widthIndex].length
    var lines = []
    for (var index = 0; index < rows.length; index++) {
      var label = processTreePadRight(labels[index], labelWidth)
      lines.push(label + "  " + processTreeStats(rows[index].process))
    }
    return lines.join("\n")
  }

  function toggleProcessTree(pid) {
    processTreePid = processTreePid === String(pid || "") ? "" : String(pid || "")
  }

  function toggleProcessSort(key) {
    if (processSort === key) processSortAscending = !processSortAscending
    else {
      processSort = key
      processSortAscending = key === "name" || key === "pid"
    }
    rebuildProcesses()
  }

  function sortLabel(title, key) {
    return title + (processSort === key ? (processSortAscending ? " ↑" : " ↓") : "")
  }

  function processCanBeManaged(process) {
    // Match DMS: offer the action for every normal PID. The user's normal
    // process permissions still apply, and the confirmation prevents an
    // accidental terminate/force-kill.
    return !!process && Number(process.pid) > 1
  }

  function requestProcessAction(process, forceKill) {
    if (!processCanBeManaged(process)) return
    pendingProcess = process
    pendingForceKill = forceKill
    confirmDialog.opened = true
  }

  function applyProcessAction() {
    var pid = Number(pendingProcess && pendingProcess.pid)
    if (!isFinite(pid) || pid <= 1 || actionProc.running) {
      confirmDialog.opened = false
      return
    }
    actionProc.command = ["kill", pendingForceKill ? "-KILL" : "-TERM", String(pid)]
    actionProc.running = true
    actionMessage = (pendingForceKill ? "Force-killing " : "Terminating ")
      + String(pendingProcess.command || "process") + " (" + pid + ")…"
    confirmDialog.opened = false
  }

  function cycleGpu() {
    if (availableGpus.length < 2) return
    selectedGpuIndex = (selectedGpuIndex + 1) % availableGpus.length
    updateSelectedGpuMetrics()
    if (opened) refreshSelectedGpuMetrics()
  }

  onProcessSearchChanged: rebuildProcesses()
  onProcessFilterChanged: rebuildProcesses()
  onProcessMemoryModeChanged: rebuildProcesses()
  onExpandedPidChanged: if (processListScrollLocked) scheduleProcessScrollRestore()
  onProcessTreePidChanged: if (processListScrollLocked) scheduleProcessScrollRestore()
  onDisplayedProcessListHeightChanged: if (processListScrollLocked) scheduleProcessScrollRestore()
  onOpenedChanged: {
    if (opened) {
      cpuIncludeCores = true
      processMemoryMode = "rss"
      processSort = defaultProcessSort
      processSortAscending = defaultProcessSort === "name" || defaultProcessSort === "pid"
      processListScrollLocked = false
      processScrollContentY = 0
      processScrollAnchorPid = ""
      processTreePid = ""
      expandedPid = ""
      previousGpuEnginesByPid = ({})
      previousGpuSampleEndMs = 0
      processCpuWarmupPending = true
      processCpuWarmupTimer.restart()
      rebuildProcesses()
      maybeSetupIntelGpu()
      refreshGpuDiscovery()
      refreshFull()
    }
  }
  Component.onCompleted: {
    barSyncPending = true
    refreshNow()
  }

  Timer {
    id: intelGpuSetupMessageTimer
    interval: 4000
    repeat: false
    onTriggered: {
      if (root.actionMessage === "Intel GPU monitoring ready")
        root.actionMessage = ""
    }
  }

  Timer {
    interval: root.pollInterval
    running: !root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.barSyncPending = true
      root.refreshSummary(false)
    }
  }

  Timer {
    interval: root.pollInterval
    running: root.opened
    repeat: true
    triggeredOnStart: false
    onTriggered: {
      root.barSyncPending = true
      root.refreshFull()
      root.tooltipEpoch += 1
    }
  }

  Timer {
    id: afterActionRefresh
    interval: 500
    onTriggered: if (root.opened) root.refreshFull()
  }

  Timer {
    id: deferredGpuPollTimer
    interval: 150
    repeat: false
    onTriggered: root.refreshIntelGpuTopOnly()
  }

  Timer {
    id: processCpuWarmupTimer
    interval: 400
    repeat: false
    onTriggered: {
      if (root.opened && root.processCpuWarmupPending) {
        root.processCpuWarmupPending = false
        root.refreshProcesses()
      }
    }
  }

  Process {
    id: memInfoProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseMemory(text)
    }
  }

  Process {
    id: cpuProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseCpu(text)
    }
  }

  Process {
    id: processProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseProcesses(text)
    }
  }

  Process {
    id: uptimeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseUptime(text)
    }
  }

  Process {
    id: cpuInfoProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseCpuInfo(text) }
  }

  Process {
    id: cpuTemperatureProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseCpuTemperature(text) }
  }

  Process {
    id: cpuTopologyProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseCpuTopology(text) }
  }

  Process {
    id: networkProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseNetwork(text) }
  }

  Process {
    id: networkInfoProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseNetworkInfo(text) }
  }

  Process {
    id: networkProcessProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseNetworkProcesses(text) }
  }

  Process {
    id: diskProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseDisk(text) }
  }

  Process {
    id: mountProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseMounts(text) }
  }

  Process {
    id: pressureProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parsePressure(text) }
  }

  Process {
    id: gpuDiscoveryProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseGpuDiscovery(text) }
  }

  Process {
    id: nvidiaProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseNvidia(text) }
  }

  Process {
    id: nvidiaProcessProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseNvidiaProcesses(text) }
  }

  Process {
    id: gpuFdInfoProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseGpuFdInfo(text) }
  }

  Process {
    id: intelGpuTopProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseIntelGpuTop(text) }
  }

  Process {
    id: intelGpuSetupCheckProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseIntelGpuSetupCheck(text) }
  }

  Process {
    id: intelGpuSetupProc
    onExited: function(exitCode) { root.finishIntelGpuSetup(exitCode) }
  }

  Process {
    id: gpuSensorFindProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text || "").trim()
        if (!path || gpuTemperatureProc.running) return
        gpuTemperatureProc.command = ["cat", path]
        gpuTemperatureProc.running = true
      }
    }
  }

  Process {
    id: gpuHwmonBatchProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseGpuHwmonBatch(text) }
  }

  Process {
    id: gpuTemperatureProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var milliCelsius = root.metricOrUnknown(text)
        if (milliCelsius >= 0) root.updateGpuMetric(root.selectedGpuBdf, { temperature: milliCelsius / 1000 })
      }
    }
  }

  Process {
    id: gpuVramUsedProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateGpuMetric(root.selectedGpuBdf, { vramUsedBytes: root.metricOrUnknown(text) })
    }
  }

  Process {
    id: gpuVramTotalProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateGpuMetric(root.selectedGpuBdf, { vramTotalBytes: root.metricOrUnknown(text) })
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(exitCode) {
      var process = root.pendingProcess
      if (exitCode === 0)
        root.actionMessage = (root.pendingForceKill ? "Force-killed " : "Terminated ") + String(process && process.command || "process")
      else
        root.actionMessage = "Could not manage process: " + String(actionError.text || "permission denied")
      root.pendingProcess = null
      root.pendingForceKill = false
      afterActionRefresh.restart()
    }
  }

  Ui.KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.barIdentity
    open: root.opened
    focusTarget: processListSection.searchInput
    contentWidth: fittedContentWidth(Style.space(540), Style.space(600))
    // Keep the card height stable. The splitter reallocates this fixed space
    // between the module grid and the process list.
    contentHeight: cappedContentHeight(Style.space(714) + root.processRowStride)

    Flickable {
      id: dashboardScroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: dashboard.height
      clip: true
      interactive: false
      boundsBehavior: Flickable.StopAtBounds

      Item {
        id: dashboard
        width: dashboardScroll.width
        implicitHeight: dashboardColumn.implicitHeight
        height: Math.max(implicitHeight, dashboardScroll.height)

      ColumnLayout {
        id: dashboardColumn
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing.sm

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.sm

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
              Layout.fillWidth: true
              text: root.cpuModel || "Vitals"
              color: root.barForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }
            Text {
              text: root.uptime || "Collecting system data…"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: root.lastMetricsUpdatedLabel !== ""
              text: root.lastMetricsUpdatedLabel
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Ui.Button {
            visible: root.availableGpus.length > 1
            text: "GPU: " + root.gpuName
            fontSize: Style.font.caption
            tooltipText: "Switch monitored GPU"
            onClicked: root.cycleGpu()
          }
          RowLayout {
            spacing: 0
            Ui.Button {
              text: "−"
              fontSize: Style.font.body
              horizontalPadding: Style.spacing.xs
              tooltipText: "Reduce polling interval by 500 ms"
              enabled: root.pollInterval > 500
              onClicked: root.setPollInterval(root.pollInterval - 500)
            }
            Text {
              text: root.pollIntervalLabel()
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              Layout.preferredWidth: Style.space(66)
            }
            Ui.Button {
              text: "+"
              fontSize: Style.font.body
              horizontalPadding: Style.spacing.xs
              tooltipText: "Increase polling interval by 500 ms"
              enabled: root.pollInterval < 15000
              onClicked: root.setPollInterval(root.pollInterval + 500)
            }
          }
          Ui.Button {
            text: "↻"
            fontSize: Style.font.title
            tooltipText: "Refresh now"
            onClicked: root.refreshNow()
          }
        }


        MetricTiles {
          root: root
          Layout.fillWidth: true
        }

        ProcessList {
          id: processListSection
          root: root
          Layout.fillWidth: true
        }
      }

      }
    }

    Ui.ConfirmDialog {
      id: confirmDialog
      anchors.fill: parent
      message: root.pendingForceKill
        ? "Force kill " + String(root.pendingProcess && root.pendingProcess.command || "this process") + " (PID " + String(root.pendingProcess && root.pendingProcess.pid || "") + ")? Unsaved data may be lost."
        : "Terminate " + String(root.pendingProcess && root.pendingProcess.command || "this process") + " (PID " + String(root.pendingProcess && root.pendingProcess.pid || "") + ")?"
      confirmText: root.pendingForceKill ? "Force kill" : "Terminate"
      onCanceled: {
        root.pendingProcess = null
        root.pendingForceKill = false
        opened = false
      }
      onConfirmed: root.applyProcessAction()
    }
  }
}
