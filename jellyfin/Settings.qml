import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueServerUrl: cfg.serverUrl ?? defaults.serverUrl
  property string valueApiKey: cfg.apiKey ?? defaults.apiKey
  property string valueUserId: cfg.userId ?? defaults.userId

  spacing: Style.marginL

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NTextInput {
      Layout.fillWidth: true
      label: "Server URL"
      description: "URL to your Jellyfin server (e.g. http://192.168.1.100:8096)"
      placeholderText: "http://localhost:8096"
      text: root.valueServerUrl
      onTextChanged: root.valueServerUrl = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "API Key"
      description: "API key generated in your Jellyfin Dashboard > Advanced > API Keys"
      placeholderText: "Enter API Key"
      text: root.valueApiKey
      onTextChanged: root.valueApiKey = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "User ID"
      description: "User ID to search libraries for. Optional: If empty, the plugin will try to guess your ID."
      placeholderText: "Optional User ID"
      text: root.valueUserId
      onTextChanged: root.valueUserId = text
    }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.pluginSettings.serverUrl = root.valueServerUrl;
    pluginApi.pluginSettings.apiKey = root.valueApiKey;
    pluginApi.pluginSettings.userId = root.valueUserId;
    pluginApi.saveSettings();
  }
}
