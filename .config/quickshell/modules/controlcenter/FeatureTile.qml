import QtQuick
import QtQuick.Layouts
import "../.." as Root

// FeatureTile — reusable toggle tile for quick settings grid
// active: primaryContainer bg with light text
// inactive: surfaceContainerHigh bg with dim text
// hasDetail: splits tap zone — left 72% = toggle, right 28% = drill-in (chevron)
Rectangle {
    id: tile

    property bool active: false
    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool hasDetail: false

    signal clicked()
    signal detailClicked()

    implicitWidth: 160
    implicitHeight: Root.Theme.tileHeight

    radius: Root.Theme.tileRadius
    color: active ? Root.Theme.tileActive : Root.Theme.tileInactive

    Behavior on color {
        ColorAnimation { duration: Root.Theme.animDurationFast }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Root.Theme.spacingMedium
        anchors.rightMargin: hasDetail ? 0 : Root.Theme.spacingMedium
        spacing: Root.Theme.spacingSmall

        // Icon
        Text {
            text: tile.icon
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeLarge
            color: tile.active ? Root.Theme.tileActiveText : Root.Theme.tileInactiveText
            Layout.alignment: Qt.AlignVCenter
        }

        // Label + subtitle
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: tile.label
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                font.weight: Font.Medium
                color: tile.active ? Root.Theme.tileActiveText : Root.Theme.tileInactiveText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: tile.subtitle !== ""
                text: tile.subtitle
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeXS
                color: tile.active
                    ? Qt.rgba(Root.Theme.tileActiveText.r, Root.Theme.tileActiveText.g, Root.Theme.tileActiveText.b, 0.75)
                    : Qt.rgba(Root.Theme.tileInactiveText.r, Root.Theme.tileInactiveText.g, Root.Theme.tileInactiveText.b, 0.65)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Divider before chevron
        Rectangle {
            visible: hasDetail
            width: 1
            height: 32
            color: tile.active
                ? Qt.rgba(Root.Theme.tileActiveText.r, Root.Theme.tileActiveText.g, Root.Theme.tileActiveText.b, 0.2)
                : Qt.rgba(Root.Theme.tileInactiveText.r, Root.Theme.tileInactiveText.g, Root.Theme.tileInactiveText.b, 0.2)
            Layout.alignment: Qt.AlignVCenter
        }

        // Chevron icon
        Text {
            visible: hasDetail
            text: "󰅂"
            font.family: Root.Theme.fontFamily
            font.pixelSize: 12
            color: tile.active
                ? Qt.rgba(Root.Theme.tileActiveText.r, Root.Theme.tileActiveText.g, Root.Theme.tileActiveText.b, 0.6)
                : Qt.rgba(Root.Theme.tileInactiveText.r, Root.Theme.tileInactiveText.g, Root.Theme.tileInactiveText.b, 0.45)
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Root.Theme.spacingMedium
        }
    }

    // Toggle click zone (full tile if !hasDetail, left 72% if hasDetail)
    MouseArea {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: hasDetail ? parent.width * 0.72 : parent.width
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }

    // Detail click zone (right 28%, chevron area)
    MouseArea {
        visible: hasDetail
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: parent.width * 0.28
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.detailClicked()
    }
}
