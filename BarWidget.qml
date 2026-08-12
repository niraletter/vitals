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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: panelLoader.item ? panelLoader.item.barTooltip : "Vitals"
    text: panelLoader.item ? panelLoader.item.barLabel : " …"
    active: root.opened
    useActiveColor: false

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
