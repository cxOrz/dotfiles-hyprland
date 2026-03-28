import QtQuick
import "../.." as Root

// ChromeOS-style app icon: white circle background + icon + label
// Hover state: white semi-transparent rounded rect behind the whole cell
Item {
    id: appIcon
    width: 120
    height: 116

    required property string appName
    required property string iconSource

    signal clicked()

    // ── Hover / selected background (white translucent rounded rect) ─
    Rectangle {
        id: hoverRect
        anchors.fill: parent
        anchors.margins: 8
        radius: 16
        color: mouseArea.pressed
            ? Qt.rgba(1, 1, 1, 0.15)
            : mouseArea.containsMouse
                ? Qt.rgba(1, 1, 1, 0.08)
                : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    // ── White circle icon background ─────────────────────────────
    Rectangle {
        id: circleBackground
        width: 56
        height: 56
        radius: 28
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        color: Qt.rgba(1, 1, 1, 0.9)
        clip: true

        scale: mouseArea.pressed ? 0.93 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        // ── App icon (inscribed square: corners touch the circle) ─
        Image {
            id: iconImage
            property real side: circleBackground.width / Math.sqrt(2)
            anchors.centerIn: parent
            width: side
            height: side
            source: appIcon.iconSource
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: status === Image.Ready
        }

        // Fallback: first letter
        Text {
            anchors.centerIn: parent
            text: appIcon.appName.length > 0 ? appIcon.appName.charAt(0).toUpperCase() : "?"
            font.pixelSize: 20
            font.family: Root.Theme.fontFamily
            font.weight: Font.Medium
            color: "#555555"
            visible: iconImage.status !== Image.Ready
        }
    }

    // ── App name label ───────────────────────────────────────────
    Text {
        anchors.top: circleBackground.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 6
        text: appIcon.appName
        font.pixelSize: 12
        font.family: Root.Theme.fontFamily
        color: Root.Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    // ── Click area ───────────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: appIcon.clicked()
    }
}
