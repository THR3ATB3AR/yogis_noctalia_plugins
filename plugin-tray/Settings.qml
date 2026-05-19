import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Noctalia
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  function saveSettings() {
    if (pluginApi) {
      pluginApi.pluginSettings.displayMode = root.displayMode;
      
      var newVisible = [];
      for (var i = 0; i < pluginsModel.count; i++) {
         var item = pluginsModel.get(i);
         if (item.enabled) {
            newVisible.push(item.pluginId);
         }
      }
      
      pluginApi.pluginSettings.visiblePlugins = newVisible;
      pluginApi.saveSettings();
    }
  }

  property string displayMode: cfg.displayMode ?? defaults.displayMode ?? "grid"
  property var initialVisiblePlugins: cfg.visiblePlugins ?? defaults.visiblePlugins ?? []

  ListModel {
    id: pluginsModel
  }

  Component.onCompleted: {
    var allIds = PluginRegistry.getAllInstalledPluginIds();
    var idMap = {};
    for (var i = 0; i < allIds.length; i++) {
       var key = allIds[i];
       if (key === "plugin-tray") continue;
       var manifest = PluginRegistry.getPluginManifest(key);
       if (manifest && PluginRegistry.isPluginEnabled(key) && typeof(manifest.entryPoints.barWidget) !== "undefined") {
           idMap[key] = manifest.name || key;
       }
    }
    
    for (var i = 0; i < root.initialVisiblePlugins.length; i++) {
       var id = root.initialVisiblePlugins[i];
       if (idMap[id] !== undefined) {
           pluginsModel.append({
               "pluginId": id,
               "name": idMap[id],
               "enabled": true
           });
           delete idMap[id];
       }
    }
    
    for (var key in idMap) {
       pluginsModel.append({
           "pluginId": key,
           "name": idMap[key],
           "enabled": false
       });
    }
  }

  NHeader {
    label: "Display Mode"
    description: "Choose how plugins are displayed in the tray."
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    
    NButton {
      text: "Grid"
      icon: "apps"
      backgroundColor: root.displayMode === "grid" ? Color.mPrimary : Color.mSurfaceVariant
      textColor: root.displayMode === "grid" ? Color.mOnPrimary : Color.mOnSurfaceVariant
      Layout.fillWidth: true
      onClicked: {
        root.displayMode = "grid"
        root.saveSettings()
      }
    }
    
    NButton {
      text: "Vertical"
      icon: "format-list-bulleted"
      backgroundColor: root.displayMode === "vertical" ? Color.mPrimary : Color.mSurfaceVariant
      textColor: root.displayMode === "vertical" ? Color.mOnPrimary : Color.mOnSurfaceVariant
      Layout.fillWidth: true
      onClicked: {
        root.displayMode = "vertical"
        root.saveSettings()
      }
    }

    NButton {
      text: "Horizontal"
      icon: "format-align-justify"
      backgroundColor: root.displayMode === "horizontal" ? Color.mPrimary : Color.mSurfaceVariant
      textColor: root.displayMode === "horizontal" ? Color.mOnPrimary : Color.mOnSurfaceVariant
      Layout.fillWidth: true
      onClicked: {
        root.displayMode = "horizontal"
        root.saveSettings()
      }
    }
  }

  NHeader {
    label: "Visible Plugins"
    description: "Select which plugins to show in the tray. Only enabled plugins are listed."
  }

  Item {
    Layout.fillWidth: true
    implicitHeight: listView.contentHeight

    NListView {
      id: listView
      anchors.fill: parent
      spacing: Style.marginS
      interactive: false
      reserveScrollbarSpace: false
      model: pluginsModel

      delegate: Item {
        id: delegateItem
        width: listView.availableWidth
        height: contentRow.height

        required property int index
        required property string pluginId
        required property string name
        required property bool enabled

        property bool dragging: false
        property int dragStartY: 0
        property int dragStartIndex: -1
        property int dragTargetIndex: -1

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusM
          color: delegateItem.dragging ? Color.mSurfaceVariant : "transparent"
          border.color: delegateItem.dragging ? Color.mOutline : "transparent"
          border.width: Style.borderS
        }

        RowLayout {
          id: contentRow
          width: parent.width
          spacing: Style.marginM

          Rectangle {
            Layout.preferredWidth: Style.baseWidgetSize * 0.7
            Layout.preferredHeight: Style.baseWidgetSize * 0.7
            Layout.alignment: Qt.AlignVCenter
            radius: Style.radiusXS
            color: dragHandleMouseArea.containsMouse ? Color.mSurfaceVariant : "transparent"

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2
              Repeater {
                model: 3
                Rectangle {
                  Layout.preferredWidth: Style.baseWidgetSize * 0.28
                  Layout.preferredHeight: 2
                  radius: 1
                  color: Color.mOutline
                }
              }
            }

            MouseArea {
              id: dragHandleMouseArea
              anchors.fill: parent
              cursorShape: Qt.SizeVerCursor
              hoverEnabled: true
              preventStealing: false
              z: 1000

              onPressed: mouse => {
                           delegateItem.dragStartIndex = delegateItem.index;
                           delegateItem.dragTargetIndex = delegateItem.index;
                           delegateItem.dragStartY = delegateItem.y;
                           delegateItem.dragging = true;
                           delegateItem.z = 999;
                           preventStealing = true;
                         }

              onPositionChanged: mouse => {
                                   if (delegateItem.dragging) {
                                     var dy = mouse.y - height / 2;
                                     var newY = delegateItem.y + dy;
                                     newY = Math.max(0, Math.min(newY, listView.contentHeight - delegateItem.height));
                                     delegateItem.y = newY;
                                     var targetIndex = Math.floor((newY + delegateItem.height / 2) / (delegateItem.height + Style.marginS));
                                     targetIndex = Math.max(0, Math.min(targetIndex, listView.count - 1));
                                     delegateItem.dragTargetIndex = targetIndex;
                                   }
                                 }

              onReleased: {
                preventStealing = false;
                if (delegateItem.dragStartIndex !== -1 && delegateItem.dragTargetIndex !== -1 && delegateItem.dragStartIndex !== delegateItem.dragTargetIndex) {
                  pluginsModel.move(delegateItem.dragStartIndex, delegateItem.dragTargetIndex, 1);
                  root.saveSettings();
                }
                delegateItem.dragging = false;
                delegateItem.dragStartIndex = -1;
                delegateItem.dragTargetIndex = -1;
                delegateItem.z = 0;
              }

              onCanceled: {
                preventStealing = false;
                delegateItem.dragging = false;
                delegateItem.dragStartIndex = -1;
                delegateItem.dragTargetIndex = -1;
                delegateItem.z = 0;
              }
            }
          }

          NToggle {
            Layout.fillWidth: true
            label: delegateItem.name
            checked: delegateItem.enabled
            onToggled: function(checked) {
              pluginsModel.setProperty(delegateItem.index, "enabled", checked);
              root.saveSettings();
            }
          }
        }

        y: {
          if (delegateItem.dragging) {
            return delegateItem.y;
          }

          var draggedIndex = -1;
          var targetIndex = -1;
          for (var i = 0; i < listView.count; i++) {
            var item = listView.itemAtIndex(i);
            if (item && item.dragging) {
              draggedIndex = item.dragStartIndex;
              targetIndex = item.dragTargetIndex;
              break;
            }
          }

          if (draggedIndex !== -1 && targetIndex !== -1 && draggedIndex !== targetIndex) {
            var currentIndex = delegateItem.index;
            if (draggedIndex < targetIndex) {
              if (currentIndex > draggedIndex && currentIndex <= targetIndex) {
                return (currentIndex - 1) * (delegateItem.height + Style.marginS);
              }
            } else {
              if (currentIndex >= targetIndex && currentIndex < draggedIndex) {
                return (currentIndex + 1) * (delegateItem.height + Style.marginS);
              }
            }
          }

          return delegateItem.index * (delegateItem.height + Style.marginS);
        }

        Behavior on y {
          enabled: !delegateItem.dragging
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutQuad
          }
        }
      }
    }
    
    NLabel {
      visible: pluginsModel.count === 0
      label: "No other plugins enabled"
      description: "Install and enable other plugins to see them here."
      Layout.fillWidth: true
    }
  }
}

