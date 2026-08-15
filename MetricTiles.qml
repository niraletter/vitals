import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "Model.js" as Model

ColumnLayout {
  id: metricTiles
  required property var root
  Layout.fillWidth: true

        GridLayout {
          id: moduleGrid
          Layout.fillWidth: true
          Layout.preferredHeight: root.displayedModuleGridHeight
          Layout.minimumHeight: root.minimumModuleGridHeight
          Layout.maximumHeight: 560
          columns: 2
          rowSpacing: Style.space(2)
          columnSpacing: Style.space(2)

          Repeater {
            model: ["cpu", "memory", "network", "disk", "gpu", "storage"]

            Rectangle {
              id: tile
              required property string modelData
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: root.moduleTileMinimumHeight(tile.modelData)
              Layout.columnSpan: 1
              radius: Style.cornerRadius
              color: Util.alpha(root.barForeground, 0.075)
              clip: true

              readonly property bool graphable: modelData === "cpu" || modelData === "memory" || modelData === "network" || modelData === "disk" || modelData === "gpu"
              readonly property bool graphVisible: tile.graphable && root.moduleGraphEnabled(tile.modelData)
              readonly property string heading: modelData === "cpu" ? "CPU"
                : modelData === "memory" ? "MEM"
                : modelData === "network" ? "NETWORK"
                : modelData === "disk" ? "DISK I/O" : modelData === "gpu" ? "GPU" : "STORAGE"
              readonly property string value: modelData === "cpu" ? Math.round(root.cpuUsage) + "%"
                : modelData === "memory" ? Math.round(root.memoryUsage) + "%"
                : modelData === "network" ? "↓ " + Model.formatRate(root.networkRxRate) + "   ↑ " + Model.formatRate(root.networkTxRate)
                : modelData === "disk" ? "R " + Model.formatRate(root.diskReadRate) + " · W " + Model.formatRate(root.diskWriteRate)
                : modelData === "gpu" ? root.gpuDisplayValue()
                : (root.primaryStorage() ? Model.mountPercent(root.primaryStorage()) + "% used" : "Storage unavailable")
              readonly property string tileLabel: root.moduleTileHeading(tile.modelData, tile.heading) + root.moduleTileSuffix(tile.modelData)
              readonly property string tileStat: root.moduleTileValue(tile.modelData, tile.value)
              readonly property string tileCombined: root.moduleTileCombinedText(tile.modelData, tile.heading, tile.value)
              readonly property string detail: modelData === "cpu" ? (root.cpuTemperature > 0 ? Math.round(root.cpuTemperature) + "°C · cores " + (root.cpuCoresExpanded ? "⌃" : "⌄") : "cores " + (root.cpuCoresExpanded ? "⌃" : "⌄"))
                : modelData === "memory" ? root.memoryDetail()
                : modelData === "network" ? root.networkTileDetail()
                : modelData === "disk" ? "Physical disks: " + root.diskDeviceLabel()
                : modelData === "gpu" ? (root.gpuName || "Detecting GPU…")
                : modelData === "storage" && root.primaryStorage() ? "Root volume · " + root.primaryStorage().mount : ""
              readonly property string secondDetail: modelData === "gpu"
                ? root.gpuDetails()
                : modelData === "storage" && root.primaryStorage() ? Model.formatBytes(root.primaryStorage().usedBytes) + " / " + Model.formatBytes(root.primaryStorage().sizeBytes)
                  + (root.otherStorageCount() > 0 ? " · +" + root.otherStorageCount() + " volume" + (root.otherStorageCount() > 1 ? "s" : "") : "") : ""
              readonly property var primaryHistory: modelData === "cpu" ? root.cpuHistory
                : modelData === "memory" ? root.memoryHistory
                : modelData === "network" ? root.rxHistory
                : modelData === "disk" ? root.readHistory
                : modelData === "gpu" ? root.gpuHistory : []
              readonly property var secondaryHistory: modelData === "network" ? root.txHistory
                : modelData === "disk" ? root.writeHistory : []
              readonly property string moduleTooltip: root.moduleTileTooltip(tile.modelData)

              Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: root.modulesDense ? Style.spacing.xxs : Style.spacing.sm
                anchors.rightMargin: root.modulesDense ? Style.spacing.xxs : Style.spacing.sm
                z: 2
                visible: text !== "" && !root.modulesDense
                text: tile.modelData === "cpu" ? root.cpuTileBadge()
                  : tile.modelData === "gpu" ? root.gpuTileBadge()
                  : ""
                color: root.mutedText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Rectangle {
                id: tileBar
                visible: !root.modulesLine && !root.modulesPico
                  && ((tile.modelData === "storage" && root.primaryStorage() !== null)
                  || (tile.modelData === "gpu" && (root.gpuVramTotalBytes > 0 || (root.gpuUsesSharedMemory && root.gpuSharedMemoryBytes >= 0 && root.totalMemoryKB > 0))))
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Style.spacing.sm
                anchors.rightMargin: Style.spacing.sm
                anchors.bottomMargin: root.modulesNano ? Style.spacing.xxs : Style.spacing.sm
                height: root.modulesNano ? 2 : root.modulesMicro ? 2 : root.modulesMinimal ? 2 : root.modulesDense ? 3 : 4
                radius: 2
                color: Util.alpha(root.barForeground, 0.2)
                z: 2
                Rectangle {
                  width: parent.width * (tile.modelData === "storage"
                    ? Model.mountPercent(root.primaryStorage())
                    : root.gpuMemoryPercent()) / 100
                  height: parent.height
                  radius: parent.radius
                  color: tile.modelData === "storage" && root.tileValueIsUrgent("storage") ? Color.urgent : Color.accent
                }
              }

              Canvas {
                id: tileGraphStrip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.moduleGraphUsesStrip ? root.moduleGraphStripHeight : undefined
                anchors.bottom: root.moduleGraphUsesStrip ? undefined
                  : (tile.modelData === "gpu" && tileBar.visible ? tileBar.top : parent.bottom)
                anchors.bottomMargin: root.moduleGraphUsesStrip ? 0
                  : (tile.modelData === "gpu" && tileBar.visible ? Style.spacing.xxs : 0)
                visible: tile.graphVisible && !root.modulesLine
                opacity: root.modulesPico ? 0.62 : root.modulesNano ? 0.64 : root.modulesMicro ? 0.66
                  : root.modulesMinimal ? 0.68 : root.modulesDense ? 0.72 : root.modulesCompact ? 0.62 : 0.58
                property var primary: tile.primaryHistory
                property var secondary: tile.secondaryHistory
                onPrimaryChanged: requestPaint()
                onSecondaryChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                  var ctx = getContext("2d")
                  root.paintTileGraph(ctx, width, height, tile.modelData, primary, secondary, "line")
                }
              }

              RowLayout {
                visible: root.modulesLine
                anchors.fill: parent
                anchors.margins: 2
                spacing: 3
                z: 2

                Text {
                  text: tile.tileCombined
                  color: tile.modelData === "cpu" || tile.modelData === "memory" || tile.modelData === "storage"
                    ? (root.tileValueIsUrgent(tile.modelData) ? Color.urgent : root.barForeground)
                    : tile.modelData === "gpu" && root.gpuUsage >= 0 && root.usageIsUrgent(root.gpuUsage)
                    ? Color.urgent
                    : root.barForeground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                  Layout.maximumWidth: parent.width * 0.42
                  Layout.alignment: Qt.AlignVCenter
                }

                Canvas {
                  visible: tile.graphVisible
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.preferredHeight: Math.max(10, parent.height - 2)
                  Layout.alignment: Qt.AlignVCenter
                  opacity: 0.58
                  property var primary: tile.primaryHistory
                  property var secondary: tile.secondaryHistory
                  onPrimaryChanged: requestPaint()
                  onSecondaryChanged: requestPaint()
                  onWidthChanged: requestPaint()
                  onHeightChanged: requestPaint()
                  onPaint: {
                    var ctx = getContext("2d")
                    root.paintTileGraph(ctx, width, height, tile.modelData, primary, secondary, "line")
                  }
                }
              }

              RowLayout {
                visible: root.modulesPico
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: Style.spacing.xxs
                anchors.rightMargin: Style.spacing.xxs
                anchors.topMargin: tile.graphVisible ? root.moduleGraphStripHeight + 1 : Style.spacing.xxs
                anchors.bottomMargin: Style.spacing.xxs
                z: 2

                Text {
                  text: tile.tileCombined
                  color: tile.modelData === "cpu" || tile.modelData === "memory" || tile.modelData === "storage"
                    ? (root.tileValueIsUrgent(tile.modelData) ? Color.urgent : root.barForeground)
                    : tile.modelData === "gpu" && root.gpuUsage >= 0 && root.usageIsUrgent(root.gpuUsage)
                    ? Color.urgent
                    : root.barForeground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                }
              }

              RowLayout {
                visible: root.modulesDense && !root.modulesPico && !root.modulesLine
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: tile.modelData === "storage" || tile.modelData === "gpu"
                  ? tileBar.top : parent.bottom
                anchors.leftMargin: root.modulesNano ? 4 : root.modulesMicro ? Style.spacing.xxs : Style.spacing.xs
                anchors.rightMargin: root.modulesNano ? Style.spacing.xxs : root.modulesMicro ? Style.spacing.xxs : Style.spacing.xs
                anchors.topMargin: tile.graphVisible
                  ? root.moduleGraphStripHeight + (root.modulesNano ? 0 : root.modulesMicro ? 1 : Style.spacing.xxs)
                  : Style.spacing.xxs
                anchors.bottomMargin: Style.spacing.xxs
                spacing: root.modulesNano ? 2 : root.modulesMicro ? Style.spacing.xxs : Style.spacing.xs
                z: 2

                Text {
                  visible: !root.modulesNano
                  text: tile.tileLabel
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                  Layout.maximumWidth: parent.width * (root.modulesMicro ? 0.38 : root.modulesMinimal ? 0.42 : 0.55)
                }

                Text {
                  visible: root.modulesNano
                  text: root.moduleTileHeading(tile.modelData, tile.heading)
                  color: root.mutedText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.Medium
                  Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: tile.tileStat
                  color: tile.modelData === "cpu" || tile.modelData === "memory" || tile.modelData === "storage"
                    ? (root.tileValueIsUrgent(tile.modelData) ? Color.urgent : root.barForeground)
                    : tile.modelData === "gpu" && root.gpuUsage >= 0 && root.usageIsUrgent(root.gpuUsage)
                    ? Color.urgent
                    : root.barForeground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideLeft
                  Layout.fillWidth: true
                }
              }

              ColumnLayout {
                visible: !root.modulesDense
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: tile.modelData === "storage" || tile.modelData === "gpu"
                  ? tileBar.top : parent.bottom
                anchors.leftMargin: root.modulesCompact ? Style.spacing.sm : Style.spacing.sm
                anchors.rightMargin: root.modulesCompact ? Style.spacing.sm : Style.spacing.sm
                anchors.topMargin: tile.graphVisible && root.moduleGraphUsesStrip
                  ? root.moduleGraphStripHeight + Style.spacing.xxs
                  : Style.spacing.sm
                anchors.bottomMargin: tile.modelData === "storage" || tile.modelData === "gpu"
                  ? Style.space(16) : Style.spacing.sm
                spacing: root.modulesCompact ? 1 : 1
                z: 2
                Text {
                  text: tile.heading + (root.barMetric === tile.modelData ? " •" : "") + " " + (root.expandedModule === tile.modelData ? "⌃" : "⌄")
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                }
                Item { visible: !root.moduleGraphUsesStrip; Layout.fillHeight: true }
                Text {
                  text: tile.value
                  color: tile.modelData === "cpu" || tile.modelData === "memory" || tile.modelData === "storage"
                    ? (root.tileValueIsUrgent(tile.modelData) ? Color.urgent : root.barForeground)
                    : tile.modelData === "gpu" && root.gpuUsage >= 0 && root.usageIsUrgent(root.gpuUsage)
                    ? Color.urgent
                    : root.barForeground
                  font.family: Style.font.family
                  font.pixelSize: root.modulesCompact
                    ? Style.font.bodySmall : Style.font.subtitle
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  visible: text !== ""
                  text: tile.detail
                  color: root.mutedText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  visible: !root.modulesCompact && text !== ""
                  text: tile.secondDetail
                  color: root.mutedText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: function(mouse) {
                  if (mouse.button === Qt.MiddleButton) root.setBarMetric(tile.modelData)
                  else if (mouse.button === Qt.RightButton && tile.graphable) root.toggleModuleGraph(tile.modelData)
                  else root.toggleModule(tile.modelData)
                }
              }

              Ui.PanelToolTip {
                visible: tile.moduleTooltip !== "" && tileMouse.containsMouse
                text: tile.moduleTooltip
                fontFamily: root.processTreeFontFamily
                fontSize: Style.font.caption
              }
            }
          }
        }

        Rectangle {
          visible: root.cpuCoresExpanded
          Layout.fillWidth: true
          implicitHeight: coreContent.implicitHeight + Style.spacing.md * 2
          radius: Style.cornerRadius
          color: Util.alpha(root.barForeground, 0.075)

          ColumnLayout {
            id: coreContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.sm

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.sm

              Text {
                text: "PER-CORE LOAD"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }

              Item { Layout.fillWidth: true }

              Text {
                text: root.cpuCoreViewLabel(root.cpuCoreViewMode) + " · right click"
                color: root.mutedText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            GridLayout {
              id: coreGrid
              Layout.fillWidth: true
              columns: 4
              rowSpacing: Style.spacing.xs
              columnSpacing: Style.spacing.xs

              Repeater {
                model: root.cpuCores

                Rectangle {
                  id: coreTile
                  required property var modelData
                  readonly property real coreUsage: Number(modelData.usage) || 0
                  readonly property var coreHistory: root.cpuCoreHistory(modelData.id)
                  readonly property real coreTemp: root.cpuCoreTemperature(modelData.id)
                  readonly property color coreColor: root.usageIsUrgent(coreUsage) ? Color.urgent : Color.accent
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.cpuCoreViewMode === "spark" ? Style.space(40) : Style.space(34)
                  radius: Style.cornerRadius
                  color: Util.alpha(root.barForeground, 0.06)
                  clip: true

                  MouseArea {
                    id: coreMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    hoverEnabled: true
                    onClicked: function(mouse) {
                      if (mouse.button === Qt.RightButton) root.cycleCpuCoreViewMode()
                    }
                  }

                  Ui.PanelToolTip {
                    visible: coreMouse.containsMouse
                    text: "Right click · switch core view\n" + root.cpuCoreViewLabel(root.cpuCoreViewMode)
                      + (coreTile.coreTemp >= 0 ? "\n" + Math.round(coreTile.coreTemp) + "°C" : "")
                    fontSize: Style.font.caption
                  }

                  Rectangle {
                    visible: root.cpuCoreViewMode === "fill"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * coreUsage / 100
                    color: Util.alpha(coreColor, 0.62)
                  }

                  Rectangle {
                    visible: root.cpuCoreViewMode === "bar"
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width * coreUsage / 100
                    height: 3
                    color: coreColor
                  }

                  Canvas {
                    id: coreSpark
                    visible: root.cpuCoreViewMode === "spark"
                    anchors.fill: parent
                    opacity: 0.88
                    property var values: coreHistory
                    onValuesChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.reset()
                      ctx.clearRect(0, 0, width, height)
                      if (!values || values.length < 2) return
                      var start = Math.max(0, root.historySize - values.length)
                      ctx.beginPath()
                      for (var index = 0; index < values.length; index++) {
                        var x = width * (start + index) / Math.max(1, root.historySize - 1)
                        var y = height - Math.min(1, values[index] / 100) * height * 0.92
                        if (index === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                      }
                      ctx.strokeStyle = Util.alpha(coreColor, 0.92)
                      ctx.lineWidth = 1.4
                      ctx.stroke()
                      ctx.lineTo(width, height)
                      ctx.lineTo(0, height)
                      ctx.closePath()
                      ctx.fillStyle = Util.alpha(coreColor, 0.14)
                      ctx.fill()
                    }
                  }

                  RowLayout {
                    visible: root.cpuCoreViewMode === "bar"
                    anchors.fill: parent
                    anchors.leftMargin: Style.spacing.sm
                    anchors.rightMargin: Style.spacing.sm
                    z: 1
                    Text {
                      text: "C" + (Number(coreTile.modelData.id) + 1) + root.cpuCoreTemperatureLabel(coreTile.modelData.id)
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                      text: Math.round(coreUsage) + "%"
                      color: coreColor
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.weight: Font.DemiBold
                    }
                  }

                  Column {
                    visible: root.cpuCoreViewMode === "fill" || root.cpuCoreViewMode === "spark"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.spacing.xxs
                    spacing: 0
                    z: 1

                    Text {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: "C" + (Number(coreTile.modelData.id) + 1) + root.cpuCoreTemperatureLabel(coreTile.modelData.id)
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    Text {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: Math.round(coreUsage) + "%"
                      color: coreColor
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.weight: Font.DemiBold
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          visible: root.expandedModule !== "" && root.expandedModule !== "cpu"
          Layout.fillWidth: true
          implicitHeight: detailContent.implicitHeight + Style.spacing.md * 2
          radius: Style.cornerRadius
          color: Util.alpha(root.barForeground, 0.075)

          ColumnLayout {
            id: detailContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.xs

            Text {
              text: root.expandedTitle()
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
            }

            Repeater {
              model: root.expandedRows()

              ColumnLayout {
                id: detailEntry
                required property var modelData
                Layout.fillWidth: true
                spacing: 0

                Item {
                  Layout.fillWidth: true
                  implicitHeight: detailRow.implicitHeight

                  RowLayout {
                    id: detailRow
                    anchors.fill: parent
                    spacing: Style.spacing.sm
                    Text {
                      text: detailEntry.modelData.label
                      color: detailEntry.modelData.highlighted ? Color.accent : root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                    Text {
                      text: detailEntry.modelData.value
                      color: detailEntry.modelData.urgent ? Color.urgent : root.barForeground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                      elide: Text.ElideLeft
                      Layout.maximumWidth: Style.space(310)
                    }
                  }

                  MouseArea {
                    id: detailRowMouse
                    anchors.fill: parent
                    visible: detailEntry.modelData.action === "networkPrimary"
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setPrimaryNetworkInterface(detailEntry.modelData.actionData)
                  }

                  Ui.PanelToolTip {
                    visible: detailEntry.modelData.action === "networkPrimary" && detailRowMouse.containsMouse
                    text: "Left click · pin interface to bar totals"
                    fontSize: Style.font.caption
                  }
                }
              }
            }

            ColumnLayout {
              visible: root.expandedModule === "gpu"
              Layout.fillWidth: true
              Layout.topMargin: Style.spacing.sm
              spacing: Style.spacing.xxs

              Text {
                text: "GPU PROCESSES"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing.sm

                Text {
                  text: "NAME"
                  color: root.mutedText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  Layout.fillWidth: true
                }
                Text {
                  text: "GPU"
                  color: root.mutedText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  horizontalAlignment: Text.AlignRight
                  Layout.preferredWidth: root.processColumnCpuWidth
                }
                Text {
                  text: "MEM"
                  color: root.mutedText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  horizontalAlignment: Text.AlignRight
                  Layout.preferredWidth: root.processColumnMemWidth
                }
                Text {
                  text: "PID"
                  color: root.mutedText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  horizontalAlignment: Text.AlignRight
                  Layout.preferredWidth: root.processColumnPidWidth
                }
              }

              Repeater {
                model: root.gpuProcessRows()

                Rectangle {
                  id: gpuProcessTile
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: gpuProcessRow.implicitHeight + Style.spacing.xxs * 2
                  radius: Style.cornerRadius
                  color: gpuProcessMouse.containsMouse ? Util.alpha(root.barForeground, 0.06) : "transparent"

                  RowLayout {
                    id: gpuProcessRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.spacing.xxs
                    anchors.rightMargin: Style.spacing.xxs
                    spacing: Style.spacing.sm

                    Text {
                      text: gpuProcessTile.modelData.name
                      color: root.barForeground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                    Text {
                      text: root.gpuProcessUsageText(gpuProcessTile.modelData.usage)
                      color: root.usageIsUrgent(gpuProcessTile.modelData.usage) ? Color.urgent : root.barForeground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                      Layout.preferredWidth: root.processColumnCpuWidth
                    }
                    Text {
                      text: root.gpuProcessMemoryText(gpuProcessTile.modelData.memoryBytes)
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                      Layout.preferredWidth: root.processColumnMemWidth
                    }
                    Text {
                      text: String(gpuProcessTile.modelData.pid || "")
                      color: root.mutedText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                      Layout.preferredWidth: root.processColumnPidWidth
                    }
                  }

                  MouseArea {
                    id: gpuProcessMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                  }
                }
              }

              Text {
                visible: root.gpuProcessRows().length === 0
                text: root.gpuProcessSupportMessage()
                color: root.mutedText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }
            }

            Text {
              visible: root.expandedRows().length === 0
              text: "Collecting details…"
              color: root.mutedText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
}
