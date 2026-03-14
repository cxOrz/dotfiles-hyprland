import QtQuick
import QtQuick.Layouts
import "../.." as Root

Item {
    id: root

    property int    notifId:  0
    property string appName:  ""
    property string summary:  ""
    property string body:     ""
    property string urgency:  "NORMAL"

    signal dismissed(int notifId)

    width:  parent ? parent.width : 360
    height: card.height + 8

    property real _slideY:  -16
    property real _opacity: 0

    Component.onCompleted: appearAnim.start()

    ParallelAnimation {
        id: appearAnim
        NumberAnimation {
            target: root; property: "_slideY"
            to: 0; duration: 280; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "_opacity"
            to: 1; duration: 200; easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        y:       root._slideY
        opacity: root._opacity
        height:  cardContent.implicitHeight + 24
        radius:  16
        color:   root.urgency === "CRITICAL" ? Root.Theme.error : Root.Theme.primary

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.topMargin: -1
            anchors.bottomMargin: -1
            radius: parent.radius
            color:  Root.Theme.surfaceContainer
        }

        ColumnLayout {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 3 + 16
            anchors.rightMargin: 16
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    visible: root.urgency === "CRITICAL"
                    width: 6; height: 6; radius: 3
                    color: Root.Theme.error
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.appName !== "" ? root.appName : "Notification"
                    color: Root.Theme.textSecondary
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeXS
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: dismissArea.containsMouse
                        ? Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.15)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: dismissArea.containsMouse ? Root.Theme.textPrimary : Root.Theme.textSecondary
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: dismissArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissed(root.notifId)
                    }
                }
            }

            Text {
                text: root.summary
                color: Root.Theme.textPrimary
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: root.summary !== ""
            }

            Text {
                text: root.body
                color: Root.Theme.textSecondary
                font.family: Root.Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: root.body !== ""
                lineHeight: 1.3
            }

            Item {
                height: 2
                Layout.fillWidth: true
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Root.Theme.textPrimary
            opacity: cardHover.containsMouse ? 0.04 : 0
            radius: parent.radius
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
}
