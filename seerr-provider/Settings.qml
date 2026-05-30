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

  spacing: Style.marginL

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NTextInput {
      Layout.fillWidth: true
      label: "Server URL"
      description: "URL to your Seerr server (e.g. http://192.168.1.100:5055)"
      placeholderText: "http://localhost:5055"
      text: root.valueServerUrl
      onTextChanged: root.valueServerUrl = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "API Key"
      description: "API key generated in your Seerr Settings > General"
      placeholderText: "Enter API Key"
      text: root.valueApiKey
      onTextChanged: root.valueApiKey = text
    }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.pluginSettings.serverUrl = root.valueServerUrl;
    pluginApi.pluginSettings.apiKey = root.valueApiKey;
    pluginApi.saveSettings();
  }
}
