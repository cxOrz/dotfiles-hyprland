import QtQuick
import QtQuick.Layouts
import "../.." as Root

Rectangle {
    id: button

    required property string icon
    required property string label
    property bool selected: false

    signal clicked()

    width: 112
    height: 124
    radius: 16

    // ChromeOS translucent surface — matches waybar rgba(255,255,255,0.06/0.12) pattern
    color: (mouseArea.containsMouse || selected)
           ? Qt.rgba(1, 1, 1, 0.13)
           : Qt.rgba(1, 1, 1, 0.06)

    border.color: selected
                  ? "#8ab4f8"
                  : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08))
    border.width: selected ? 1.5 : 1

    Behavior on color        { ColorAnimation { duration: Root.Theme.animDurationFast } }
    Behavior on border.color { ColorAnimation { duration: Root.Theme.animDurationFast } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: button.icon
            font.family: Root.Theme.fontFamily
            font.pixelSize: 36
            // Selected → blue accent; hover → pure white; default → near-white
            color: button.selected
                   ? "#8ab4f8"
                   : (mouseArea.containsMouse ? "#ffffff" : "#e2e3e1")

            Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }
         }

         Text {
             Layout.alignment: Qt.AlignHCenter
             text: button.label
             font.family: Root.Theme.fontFamily
             font.pixelSize: Root.Theme.fontSizeNormal
             color: button.selected
                    ? "#8ab4f8"
                    : (mouseArea.containsMouse ? "#e2e3e1" : Qt.rgba(0.886, 0.890, 0.882, 0.65))

             Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }
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
