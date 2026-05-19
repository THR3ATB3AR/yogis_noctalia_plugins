import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Services.Noctalia
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  icon: "apps"
  tooltipText: pluginApi?.manifest?.name || "Plugin Tray"
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: Color.resolveColorKey("primary")

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    if (pluginApi) {
      pluginApi.openPanel(root.screen, this);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Settings",
        "action": "settings",
        "icon": "settings"
      },
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
