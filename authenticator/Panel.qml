import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 400 * Style.uiScaleRatio
  property real contentPreferredHeight: 400 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  property var accounts: pluginApi?.pluginSettings?.accounts || []
  property var otpData: []
  property int timeRemaining: 30

  anchors.fill: parent

  Process {
    id: pythonProcess
    command: []
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (exitCode) => {
        if (exitCode === 0) {
            try {
                let data = JSON.parse(pythonProcess.stdout.text);
                root.timeRemaining = data.remaining;
                root.otpData = data.codes;
            } catch (e) {
                Logger.e("Authenticator", "Error parsing output: " + pythonProcess.stdout.text, e);
            }
        } else {
            Logger.e("Authenticator", "Python script exited with code " + exitCode + ". Stderr: " + pythonProcess.stderr.text);
        }
    }
  }

  Timer {
    id: refreshTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
        if (!pluginApi || pythonProcess.running) return;
        pythonProcess.command = ["python3", pluginApi.pluginDir + "/totp.py", "get", JSON.stringify(root.accounts)];
        pythonProcess.running = true;
    }
  }

  Component.onCompleted: {
      // Small delay to ensure pluginApi is injected
      Qt.callLater(function() {
          refreshTimer.triggered();
      });
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true
            NIcon { icon: "shield-lock"; pointSize: Style.fontSizeL }
            NText {
              text: "Authenticator"
              font.pointSize: Style.fontSizeL
              font.weight: Font.Bold
              Layout.fillWidth: true
            }
            NText {
              text: root.timeRemaining + "s"
              font.pointSize: Style.fontSizeS
              color: root.timeRemaining <= 5 ? Color.mError : Color.mPrimary
            }
          }

          Rectangle {
              Layout.fillWidth: true
              height: 4
              color: Color.mSurface
              radius: 2
              Rectangle {
                  height: parent.height
                  width: parent.width * (root.timeRemaining / 30.0)
                  color: root.timeRemaining <= 5 ? Color.mError : Color.mPrimary
                  radius: 2
              }
          }

          ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: scrollView.width
                spacing: Style.marginS

                Repeater {
                    model: root.otpData
                    delegate: Rectangle {
                        width: parent.width
                        height: 60
                        color: hoverHandler.hovered ? Color.mSurface : "transparent"
                        radius: Style.radiusM

                        HoverHandler { id: hoverHandler }
                        TapHandler {
                            onTapped: {
                                Quickshell.execDetached(["wl-copy", modelData.code]);
                                ToastService.showNotice("Copied code for " + modelData.name);
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            NText {
                                text: modelData.name
                                font.pointSize: Style.fontSizeM
                                color: Color.mOnSurfaceVariant
                                Layout.fillWidth: true
                            }
                            NText {
                                text: modelData.code
                                font.pointSize: Style.fontSizeL
                                font.weight: Font.Bold
                                font.family: Settings.data.ui.fontFixed
                                color: Color.mOnSurface
                            }
                        }
                    }
                }
                
                NText {
                    visible: root.otpData.length === 0
                    text: "No accounts configured.\nRight click the bar icon and open Settings."
                    color: Color.mOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.topMargin: Style.marginL
                }
            }
          }
        }
      }
    }
  }
}
