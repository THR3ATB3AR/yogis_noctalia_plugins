import QtQuick
import Quickshell.Io

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:authenticator"
    function toggle() {
      // Intentionally left blank, use bar widget to open panel
    }
  }
}
