import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "vitals"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    var panel = panelLoader.item
    if (!panel) return
    panel.bar = root.bar
    panel.settings = root.settings
    panel.anchorItem = button
    panel.hostWidget = root
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function refresh() {
    if (panelLoader.item) panelLoader.item.refreshNow()
  }

  function syncBarTooltip() {
    if (!button.tooltipHovered || !root.bar || !panelLoader.item) return
    var text = panelLoader.item.barTooltip
    if (root.bar.tooltipTarget === button) {
      root.bar.tooltipText = text
      return
    }
    if (root.bar.pendingTooltipTarget === button)
      root.bar.pendingTooltipText = text
    else
      root.bar.showTooltip(button, text)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: metricsWidth

  readonly property var barMetricList: panelLoader.item ? panelLoader.item.barMetrics : []
  readonly property real slotGap: Style.spaceReal(root.vertical ? 2 : 8)
  readonly property real metricsWidth: {
    void fontMetrics.font.family
    void fontMetrics.font.pixelSize
    var metrics = barMetricList
    var n = metrics && metrics.length ? metrics.length : 0
    var total = 0
    for (var i = 0; i < n; i++) {
      if (i) total += slotGap
      total += slotWidth(metrics[i])
    }
    return total
  }
  readonly property real metricsHeight: {
    void fontMetrics.font.family
    void fontMetrics.font.pixelSize
    var n = barMetricList && barMetricList.length ? barMetricList.length : 1
    if (root.vertical) return n * fontMetrics.height + (n - 1) * slotGap
    return fontMetrics.height
  }

  FontMetrics {
    id: fontMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }

  function slotSample(metric) {
    var icon = panelLoader.item ? panelLoader.item.barIcon(metric) : ""
    if (metric === "network") return icon + " ↓ 1023.0 KiB/s"
    if (metric === "disk") return icon + " R 1023.0 KiB/s"
    if (metric === "gpu" && panelLoader.item && panelLoader.item.gpuBarMode === "hotspot")
      return icon + " 100°C"
    return icon + " 100%"
  }

  function slotWidth(metric) {
    var w = fontMetrics.advanceWidth(slotSample(metric))
    if (!(w > 0)) w = slotSample(metric).length * Math.max(1, fontMetrics.averageCharacterWidth)
    return Math.ceil(w)
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    z: 1
    anchors.fill: parent
    bar: root.bar
    tooltipText: panelLoader.item ? panelLoader.item.barTooltip : "Vitals"
    text: " "
    labelVisible: false
    keepSpace: true
    fixedWidth: root.vertical ? -1 : root.metricsWidth + Style.spaceReal(8.5) * 2
    fixedHeight: root.vertical ? root.metricsHeight + Style.spaceReal(6) * 2 : -1
    active: root.opened
    useActiveColor: false

    onPressed: function(mouseButton) {
      if (!panelLoader.item) return
      if (mouseButton === Qt.MiddleButton) panelLoader.item.refreshNow()
      else panelLoader.item.toggle()
    }
  }

  Grid {
    id: metricsGrid
    z: 0
    anchors.centerIn: parent
    rows: root.vertical ? Math.max(1, metricsRepeater.count) : 1
    columns: root.vertical ? 1 : Math.max(1, metricsRepeater.count)
    columnSpacing: root.slotGap
    rowSpacing: root.slotGap

    Repeater {
      id: metricsRepeater
      model: root.barMetricList

      Item {
        id: slot
        required property var modelData
        width: root.slotWidth(modelData)
        height: fontMetrics.height
        implicitWidth: width
        implicitHeight: height
        clip: true

        Text {
          anchors.fill: parent
          text: {
            void (panelLoader.item ? panelLoader.item.barMetricDisplayText : "")
            if (!panelLoader.item) return ""
            return panelLoader.item.barIcon(slot.modelData) + " " + panelLoader.item.barMetricValueFromSnapshot(slot.modelData)
          }
          color: root.bar ? root.bar.barForeground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          renderType: Text.NativeRendering
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideNone
        }
      }
    }
  }

  Connections {
    target: panelLoader.item
    function onBarTooltipChanged() { root.syncBarTooltip() }
    function onTooltipEpochChanged() { root.syncBarTooltip() }
  }

  Connections {
    target: button
    function onTooltipHoveredChanged() {
      if (!button.tooltipHovered || !panelLoader.item) return
      root.syncBarTooltip()
    }
  }
}
