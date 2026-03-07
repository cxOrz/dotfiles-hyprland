import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Single notification card component
// Used by NotificationCenter's ListView
Item {
    id: notifItem

    // Properties set by the ListView delegate
    property int notifId: 0
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string urgency: "NORMAL"
    property int timestamp: 0
    property string timeAgo: ""

    // Signal when dismiss button is clicked
    signal dismissed(int notifId)

    width: parent ? parent.width : 350
    height: card.height + 6  // 6 = bottomMargin below

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Root.Theme.paddingNormal
        anchors.rightMargin: Root.Theme.paddingNormal
        height: cardContent.implicitHeight + 20  // 10 top + 10 bottom padding
        color: Root.Theme.bgSecondary
        radius: Root.Theme.radiusSmall
        border.width: 1
        border.color: Root.Theme.border

        // Urgency indicator — left colored border strip
        Rectangle {
            id: urgencyStrip
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: urgency === "CRITICAL" ? 4 : 0
            color: urgency === "CRITICAL" ? Root.Theme.accent : "transparent"
            radius: Root.Theme.radiusSmall
            visible: urgency === "CRITICAL"
        }

        ColumnLayout {
            id: cardContent
            anchors.left: urgencyStrip.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Root.Theme.paddingNormal
            anchors.rightMargin: Root.Theme.paddingNormal
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 4

            // Header row: app name + time + dismiss button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // App name
                Text {
                    text: appName
                    color: Root.Theme.textSecondary
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Relative timestamp
                Text {
                    text: timeAgo
                    color: Root.Theme.textSecondary
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: 10
                    visible: timeAgo !== ""
                }

                // Dismiss button
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: dismissArea.containsMouse ? Root.Theme.bgTertiary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"  // nf-md-close
                        color: dismissArea.containsMouse ? Root.Theme.textPrimary : Root.Theme.textSecondary
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: dismissArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifItem.dismissed(notifItem.notifId)
                    }
                }
            }

            // Summary (title)
            Text {
                text: summary
                color: Root.Theme.textPrimary
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: summary !== ""
            }

            // Body text (3-line clamp)
            Text {
                text: body
                color: Root.Theme.textSecondary
                font.family: Root.Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: body !== ""
            }

            // Bottom padding spacer
            Item {
                height: 4
                Layout.fillWidth: true
            }
        }

        // Hover highlight
        Rectangle {
            anchors.fill: parent
            color: "white"
            opacity: cardHover.containsMouse ? 0.03 : 0
            radius: parent.radius

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
}
