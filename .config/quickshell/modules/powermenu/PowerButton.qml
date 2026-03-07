import QtQuick
import QtQuick.Layouts
import "../.." as Root

Rectangle {
    id: button

    required property string icon
    required property string label

    signal clicked()

    width: 120
    height: 140
    radius: Root.Theme.radiusLarge
    color: mouseArea.containsMouse ? Root.Theme.accent : Root.Theme.bgSecondary
    border.color: mouseArea.containsMouse ? Root.Theme.accent : Root.Theme.border
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: button.icon
            font.family: Root.Theme.fontFamily
            font.pixelSize: 40
            color: mouseArea.containsMouse ? Root.Theme.bg : Root.Theme.textPrimary

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: button.label
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeNormal
            color: mouseArea.containsMouse ? Root.Theme.bg : Root.Theme.textSecondary

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
