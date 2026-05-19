import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.Noctalia
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string displayMode: cfg.displayMode ?? defaults.displayMode ?? "grid"
  property var visiblePlugins: cfg.visiblePlugins ?? defaults.visiblePlugins ?? []

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: layoutContent.implicitWidth + Style.marginL
  property real contentPreferredHeight: layoutContent.implicitHeight + Style.marginL
  
  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
    radius: Style.radiusL

    GridLayout {
      id: layoutContent
      anchors.centerIn: parent
      columnSpacing: Style.marginM
      rowSpacing: Style.marginM

      columns: {
        if (root.displayMode === "vertical") return 1;
        if (root.displayMode === "horizontal") return Math.max(1, root.visiblePlugins.length);
        return Math.max(1, Math.ceil(Math.sqrt(root.visiblePlugins.length)));
      }

      Repeater {
        model: root.visiblePlugins
        delegate: Loader {
          property var pluginApi: PluginService.getPluginAPI(modelData)
          property var comp: BarWidgetRegistry.getWidget("plugin:" + modelData)
          
          active: comp !== null && pluginApi !== null
          Layout.alignment: Qt.AlignCenter
          
          onLoaded: {
            if (item) {
              if (item.hasOwnProperty("baseSize")) {
                item.baseSize = 32 * Style.uiScaleRatio
              }
              item.screen = Qt.binding(function() { return root.pluginApi ? root.pluginApi.panelOpenScreen : null; });
            }
          }

          Component.onCompleted: {
            if (comp && pluginApi) {
              setSource(comp.url, {
                "pluginApi": pluginApi,
                "widgetId": "plugin:" + modelData
              });
            }
          }
        }
      }

      NLabel {
        visible: root.visiblePlugins.length === 0
        label: "No plugins in tray"
        description: "Right-click the tray icon and go to Settings to add plugins."
        Layout.columnSpan: layoutContent.columns
        Layout.alignment: Qt.AlignCenter
      }
    }
  }
}
