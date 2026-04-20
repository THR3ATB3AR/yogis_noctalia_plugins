import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var accounts: pluginApi?.pluginSettings?.accounts || []

  spacing: Style.marginL

  property string newName: ""
  property string newSecret: ""

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NText {
        text: "Add New Account"
        font.weight: Font.Bold
    }

    NTextInput {
      Layout.fillWidth: true
      placeholderText: "Account Name (e.g., GitHub)"
      text: root.newName
      onTextChanged: root.newName = text
    }

    NTextInput {
      Layout.fillWidth: true
      placeholderText: "TOTP Secret (Base32)"
      text: root.newSecret
      onTextChanged: root.newSecret = text
    }

    NButton {
        text: "Add Account"
        enabled: root.newName.length > 0 && root.newSecret.length > 0
        onClicked: {
            Quickshell.execDetached(["python3", pluginApi.pluginDir + "/totp.py", "store", root.newName, root.newSecret]);
            
            let accs = [];
            for (let i = 0; i < root.accounts.length; i++) accs.push(root.accounts[i]);
            if (accs.indexOf(root.newName) === -1) {
                accs.push(root.newName);
                root.accounts = accs;
                saveSettings();
            }
            root.newName = "";
            root.newSecret = "";
        }
    }
  }

  Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Color.mSurfaceVariant
  }

  ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        text: "Configured Accounts"
        font.weight: Font.Bold
        Layout.bottomMargin: Style.marginM
      }

      Repeater {
          model: root.accounts
          delegate: RowLayout {
              Layout.fillWidth: true
              NText {
                  text: modelData
                  Layout.fillWidth: true
              }
              NButton {
                  text: "Remove"
                  icon: "trash"
                  onClicked: {
                      Quickshell.execDetached(["python3", pluginApi.pluginDir + "/totp.py", "delete", modelData]);
                      let accs = [];
                      for (let i = 0; i < root.accounts.length; i++) {
                          if (root.accounts[i] !== modelData) accs.push(root.accounts[i]);
                      }
                      root.accounts = accs;
                      saveSettings();
                  }
              }
          }
      }
      NText {
          visible: root.accounts.length === 0
          text: "No accounts added yet."
          color: Color.mOnSurfaceVariant
      }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.pluginSettings.accounts = root.accounts;
    pluginApi.saveSettings();
  }
}
