import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../.." as Root

Scope {
    id: shelf

    PanelWindow {
        id: panelWindow

        anchors {
            left: true
            right: true
            bottom: true
        }

        implicitHeight: Root.Theme.shelfHeight
        exclusiveZone: Root.Theme.shelfHeight
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:shelf"

        Rectangle {
            id: shelfBackground
            anchors.fill: parent
            color: Root.Theme.shelfBg
            radius: Root.Theme.radiusLarge

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Root.Theme.radiusLarge
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Root.Theme.padding
                anchors.rightMargin: Root.Theme.padding
                spacing: Root.Theme.paddingSmall

                WorkspaceIndicator {
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    SearchButton { }
                }

                Item { Layout.fillWidth: true }

                StatusArea {
                    Layout.alignment: Qt.AlignVCenter
                }

                Row {
                    spacing: Root.Theme.paddingSmall
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            required property SystemTrayItem modelData
                            width: 20; height: 20

                            Image {
                                anchors.fill: parent
                                source: modelData.icon
                                sourceSize.width: 20
                                sourceSize.height: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton)
                                        modelData.activate()
                                    else
                                        modelData.display(panelWindow, mouse.x, mouse.y)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
