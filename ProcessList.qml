import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui as Ui
import "Model.js" as Model

ColumnLayout {
  id: processListSection
  required property var root
  property alias searchInput: processSearchInput
  property alias listView: processList
  Layout.fillWidth: true

        Rectangle {
          id: splitHandle
          z: 20
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(12)
          Layout.minimumHeight: Style.space(12)
          Layout.maximumHeight: Style.space(12)
          color: "transparent"

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Util.alpha(root.barForeground, 0.24)
          }

          Ui.PanelToolTip {
            visible: splitMouse.containsMouse
            text: "Left click + drag · resize\nMiddle click · reset"
            fontSize: Style.font.caption
          }

          Text {
            anchors.centerIn: parent
            visible: splitMouse.containsMouse || splitMouse.pressed
            text: "↕"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: splitMouse
            z: 31
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            acceptedButtons: Qt.MiddleButton
            cursorShape: Qt.SizeVerCursor
            onClicked: root.resetLayout()
          }

          DragHandler {
            id: splitDrag
            target: null
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeVerCursor
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesCancellation
            property int dragStartModules: 0
            property int dragStartProcesses: 0
            property bool canceled: false
            onActiveChanged: {
              if (active) {
                canceled = false
                dragStartModules = root.moduleGridHeight
                dragStartProcesses = root.processListHeight
                root.splitterDelta = 0
                return
              }
              if (canceled) {
                canceled = false
                root.splitterDelta = 0
                return
              }
              root.moduleGridHeight = Math.max(root.minimumModuleGridHeight, Math.min(560, dragStartModules + root.splitterDelta))
              root.processListHeight = Math.max(120, dragStartProcesses - root.splitterDelta)
              root.splitterDelta = 0
              root.persistSplit()
            }
            onActiveTranslationChanged: if (active) {
              root.splitterDelta = root.clampSplitterDelta(
                Math.round(activeTranslation.y), dragStartModules, dragStartProcesses)
            }
            onCanceled: {
              canceled = true
              root.splitterDelta = 0
            }
          }

        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs
          Text {
            text: root.processCountLabel
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
          }
          Item { Layout.fillWidth: true }
          Repeater {
            model: [["All", "all"], ["User", "user"], ["System", "system"]]
            Ui.Button {
              required property var modelData
              text: modelData[0]
              fontSize: Style.font.caption
              selected: root.processFilter === modelData[1]
              onClicked: root.processFilter = modelData[1]
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs
          Ui.TextField {
            id: processSearchInput
            Layout.fillWidth: true
            Layout.preferredHeight: root.processRowHeight
            horizontalPadding: root.processControlPadX
            verticalPadding: root.processControlPadY
            placeholderText: "Search name, command, or PID"
            text: root.processSearch
            onTextChanged: root.processSearch = text
          }
          Ui.Button {
            visible: processSearchInput.text.length > 0
            iconText: "󰅖"
            iconSize: Style.font.body
            tooltipText: "Clear process search"
            onClicked: {
              processSearchInput.text = ""
              processSearchInput.forceActiveFocus()
            }
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.processRowHeight
          z: 2

          RowLayout {
            anchors.fill: parent
            anchors.rightMargin: root.processListScrollGutter
            spacing: Style.spacing.sm

            Item {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              Layout.fillHeight: true
              Ui.Button {
                width: parent.width
                height: parent.height
                text: root.sortLabel("NAME", "name")
                fontSize: Style.font.caption
                horizontalPadding: root.processHeaderPadX
                verticalPadding: root.processHeaderPadY
                selected: root.processSort === "name"
                tooltipText: "Sort processes by name · Right-click row for process tree"
                leftAlign: true
                onClicked: root.toggleProcessSort("name")
              }
            }

            Item {
              Layout.preferredWidth: root.processColumnCpuWidth
              Layout.maximumWidth: root.processColumnCpuWidth
              Layout.fillHeight: true
              Ui.Button {
                width: parent.width
                height: parent.height
                text: root.sortLabel("CPU", "cpu")
                fontSize: Style.font.caption
                horizontalPadding: root.processHeaderPadX
                verticalPadding: root.processHeaderPadY
                selected: root.processSort === "cpu"
                tooltipText: "Sort processes by cpu"
                onClicked: root.toggleProcessSort("cpu")
              }
            }

            Item {
              Layout.preferredWidth: root.processColumnMemWidth
              Layout.maximumWidth: root.processColumnMemWidth
              Layout.fillHeight: true
              Ui.Button {
                width: parent.width
                height: parent.height
                text: root.sortLabel(root.processMemoryMode === "rss" ? "RSS" : "PSS", "memory")
                fontSize: Style.font.caption
                horizontalPadding: root.processHeaderPadX
                verticalPadding: root.processHeaderPadY
                selected: root.processSort === "memory"
                tooltipText: "Left click: sort · Right click: RSS/PSS"
                onClicked: root.toggleProcessSort("memory")
                onRightClicked: root.cycleProcessMemoryMode()
              }
            }

            Item {
              Layout.preferredWidth: root.processColumnPidWidth
              Layout.maximumWidth: root.processColumnPidWidth
              Layout.fillHeight: true
              Ui.Button {
                width: parent.width
                height: parent.height
                text: root.sortLabel("PID", "pid")
                fontSize: Style.font.caption
                horizontalPadding: root.processHeaderPadX
                verticalPadding: root.processHeaderPadY
                selected: root.processSort === "pid"
                tooltipText: "Sort processes by pid"
                onClicked: root.toggleProcessSort("pid")
              }
            }
          }
        }

        Item {
          id: processListFrame
          Layout.fillWidth: true
          Layout.preferredHeight: root.displayedProcessListHeight
          Layout.minimumHeight: 120

          ListView {
            id: processList
            anchors.fill: parent
            clip: true
            spacing: Style.spacing.xs
            model: ScriptModel {
              objectProp: "pid"
              values: root.filteredProcesses
            }
            reuseItems: true
            cacheBuffer: Style.space(160)
            displaced: null
            add: null
            remove: null
            onMovementStarted: root.captureProcessScroll(true)
            onMovementEnded: root.captureProcessScroll(true)
            onContentYChanged: {
              if (root.processListRestoringScroll) return
              root.captureProcessScroll(false)
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

          delegate: Rectangle {
            id: processRow
            required property var modelData
            required property int index
            width: processList.width - Style.spacing.xs
            readonly property bool expanded: root.expandedPid === String(modelData.pid || "")
            readonly property bool manageable: root.processCanBeManaged(modelData)
            implicitHeight: rowHeader.implicitHeight
              + (expanded ? details.implicitHeight + Style.spacing.xs : 0)
              + (root.processTreePid === String(modelData.pid || "") ? treeDetails.implicitHeight + Style.spacing.xs : 0)
            radius: Style.cornerRadius
            color: rowMouse.containsMouse ? Util.alpha(root.barForeground, 0.08) : "transparent"
            border.width: rowMouse.containsMouse ? 1 : 0
            border.color: Util.alpha(Color.accent, 0.4)
            clip: true

            ColumnLayout {
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: 0
              Item {
                id: rowHeader
                Layout.fillWidth: true
                implicitHeight: Style.space(38)
                RowLayout {
                  anchors.fill: parent
                  anchors.rightMargin: root.processListScrollGutter
                  spacing: Style.spacing.sm

                  Text {
                    text: processRow.expanded ? "⌄" : "›"
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    Layout.fillWidth: true
                    text: root.processDisplayName(processRow.modelData)
                    color: root.barForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                  Text {
                    text: root.processCpuLabel(processRow.modelData)
                    color: root.usageIsUrgent(root.processCpuPercent(processRow.modelData)) ? Color.urgent : root.barForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: root.processColumnCpuWidth
                  }
                  Text {
                    text: Model.formatMemory(root.processMemoryKB(processRow.modelData))
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: root.processColumnMemWidth
                  }
                  Text {
                    text: String(processRow.modelData.pid || "")
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: root.processColumnPidWidth
                  }
                }
                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    var pid = String(processRow.modelData.pid || "")
                    root.captureProcessScroll(true)
                    if (mouse.button === Qt.RightButton) root.toggleProcessTree(pid)
                    else root.expandedPid = processRow.expanded ? "" : pid
                  }
                }
              }

              ColumnLayout {
                id: details
                visible: processRow.expanded
                Layout.fillWidth: true
                Layout.leftMargin: Style.spacing.lg
                Layout.rightMargin: Style.spacing.lg
                Layout.bottomMargin: Style.spacing.sm
                spacing: Style.spacing.xs
                Text {
                  Layout.fillWidth: true
                  text: processRow.modelData.fullCommand || processRow.modelData.command || ""
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WrapAnywhere
                  maximumLineCount: 4
                  elide: Text.ElideRight
                }
                Text {
                  visible: text !== ""
                  Layout.fillWidth: true
                  text: root.processGpuDetails(processRow.modelData.pid)
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: "PID " + String(processRow.modelData.pid || "--") + " · PPID " + String(processRow.modelData.ppid || "--") + " · " + root.processMemoryLabel(processRow.modelData)
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                  Item { Layout.fillWidth: true }
                  Ui.Button {
                    visible: processRow.manageable
                    text: "Terminate"
                    fontSize: Style.font.caption
                    foreground: Color.urgent
                    bordered: true
                    onClicked: root.requestProcessAction(processRow.modelData, false)
                  }
                  Ui.Button {
                    visible: processRow.manageable
                    text: "Force kill"
                    fontSize: Style.font.caption
                    foreground: Color.urgent
                    bordered: true
                    onClicked: root.requestProcessAction(processRow.modelData, true)
                  }
                }
              }

              ColumnLayout {
                id: treeDetails
                visible: root.processTreePid === String(processRow.modelData.pid || "")
                Layout.fillWidth: true
                Layout.leftMargin: Style.spacing.lg
                Layout.rightMargin: Style.spacing.lg
                Layout.bottomMargin: Style.spacing.sm
                spacing: Style.spacing.xxs

                Text {
                  text: "PROCESS TREE"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                }
                Text {
                  Layout.fillWidth: true
                  visible: root.processTreeRows(processRow.modelData.pid).length > 0
                  text: root.processTreeBlockText(processRow.modelData.pid)
                  color: root.barForeground
                  font.family: root.processTreeFontFamily
                  font.pixelSize: Style.font.caption
                  lineHeight: 1
                  lineHeightMode: Text.ProportionalHeight
                  topPadding: 0
                  bottomPadding: 0
                  wrapMode: Text.NoWrap
                }
                Text {
                  visible: root.processTreeRows(processRow.modelData.pid).length === 0
                  text: "No parent or child processes in the current snapshot"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
          }

          Text {
            anchors.centerIn: parent
            visible: processList.count === 0
            text: root.processSearch ? "No matching processes" : "Collecting process data…"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Ui.Button {
            id: processJumpUp
            readonly property bool canScroll: processList.contentHeight > processList.height + Style.space(1)
            readonly property bool atTop: processList.contentY <= processList.originY + Style.space(1)
            visible: canScroll && root.processListHasScrolled && !atTop
            z: 3
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: root.processJumpInset
            anchors.topMargin: root.processJumpInset
            iconText: "↑"
            iconSize: Style.font.body
            tooltipText: "Scroll to first process"
            onClicked: root.scrollProcessListToTop()
          }

          Ui.Button {
            id: processJumpDown
            readonly property bool canScroll: processList.contentHeight > processList.height + Style.space(1)
            readonly property bool atTop: processList.contentY <= processList.originY + Style.space(1)
            visible: canScroll && root.processListHasScrolled && !atTop
            z: 3
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: root.processJumpInset
            anchors.bottomMargin: root.processJumpInset
            iconText: "↓"
            iconSize: Style.font.body
            tooltipText: "Scroll to last process"
            onClicked: root.scrollProcessListToBottom()
          }
        }

        Text {
          visible: root.actionMessage !== ""
          Layout.fillWidth: true
          text: root.actionMessage
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
}
