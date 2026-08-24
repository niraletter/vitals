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
  readonly property real openPanelIndicatorWidth: button.labelWidth

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

  // Width of one space in the label font, used as the gap between fields.
  TextMetrics {
    id: spaceMetrics
    font.family: button.fontFamily
    font.pixelSize: button.fontSize
    text: " "
  }

  // Each pinned metric is painted as its own field, so reserving width for the
  // ones that churn (percentages) does not pad the rest of the label.
  Row {
    id: fields
    anchors.centerIn: parent
    spacing: spaceMetrics.advanceWidth
    visible: !(root.bar && root.bar.vertical)

    Repeater {
      model: panelLoader.item ? panelLoader.item.barFields : []

      Item {
        required property var modelData
        height: fieldText.implicitHeight
        // Sized to the reserved text when the metric asks for a stable slot,
        // and to its own content otherwise.
        width: Math.max(fieldText.implicitWidth, reserveMetrics.advanceWidth)

        TextMetrics {
          id: reserveMetrics
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          text: modelData.reserve
        }

        Text {
          id: fieldText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.text
          color: button.foreground
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          renderType: Text.NativeRendering
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: panelLoader.item ? panelLoader.item.barTooltip : "Vitals"
    // Horizontal bars paint the label through the Row above; the text is kept
    // so vertical bars, which the Row does not handle, still render normally.
    text: panelLoader.item ? panelLoader.item.barLabel : " …"
    labelVisible: root.bar && root.bar.vertical
    active: root.opened
    useActiveColor: false
    // The default padding suits the single-glyph widgets either side of us; on
    // a label this wide it reads as a gap rather than as breathing room.
    horizontalMargin: 3
    fixedWidth: (root.bar && root.bar.vertical)
      ? -1
      : Math.max(12, fields.implicitWidth + scaledHorizontalMargin * 2)

    onPressed: function(mouseButton) {
      if (!panelLoader.item) return
      if (mouseButton === Qt.MiddleButton) panelLoader.item.refreshNow()
      else panelLoader.item.toggle()
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
