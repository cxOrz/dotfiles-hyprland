import QtQuick
import QtQuick.Layouts
import "../.." as Root

// NotificationPopup — Material You placeholder
// Future: display individual toast notifications here
// Not wired to IPC or NotificationService yet — placeholder only
Rectangle {
    id: root

    property int notifId: 0
    property string appName: ""
    property string summary: ""
    property string body: ""
    property int urgency: 1
    property var timestamp: null

    implicitWidth: 360
    implicitHeight: contentRow.implicitHeight + Root.Theme.spacingLarge * 2
    radius: Root.Theme.tileRadius
    color: Root.Theme.surfaceContainer

    RowLayout {
        id: contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Root.Theme.spacingLarge
        anchors.rightMargin: Root.Theme.spacingLarge
        spacing: Root.Theme.spacingMedium

        Rectangle {
            width: 36; height: 36; radius: 18
            color: Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.15)
            Text {
                anchors.centerIn: parent
                text: "󰂚"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeLarge
                color: Root.Theme.primary
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: root.appName !== "" ? root.appName : "Notification"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                font.weight: Font.Medium
                color: Root.Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: root.summary !== ""
                text: root.summary
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeSmall
                color: Root.Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
