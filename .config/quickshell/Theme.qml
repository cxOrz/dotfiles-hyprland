pragma Singleton
import QtQuick

QtObject {
    // Background colors
    readonly property color bg: "#0d1117"
    readonly property color bgSecondary: "#161b22"
    readonly property color bgTertiary: "#21262d"
    
    // Text colors
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#93B1A6"
    
    // Accent and borders
    readonly property color accent: "#5C8374"
    readonly property color border: "#21262d"
    
    // Font properties
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSizeNormal: 12
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeXL: 24
    readonly property int fontSizeSmall: 10
    readonly property int fontSizeXS: 9
    
    // Spacing
    readonly property int radiusSmall: 8
    readonly property int radiusLarge: 14
    readonly property int paddingNormal: 12
    readonly property int paddingLarge: 20

    // Shelf-specific
    readonly property color shelfBg: Qt.rgba(0.051, 0.067, 0.090, 0.85)
    readonly property int shelfHeight: 48

    // Surface & interaction colors
    readonly property color surfaceHigh: "#2d333b"
    readonly property color hoverOverlay: Qt.rgba(1, 1, 1, 0.08)
    readonly property color textDisabled: Qt.rgba(0.576, 0.694, 0.651, 0.35)
    readonly property color error: "#f85149"

    // Animation durations (ms)
    readonly property int animFast: 150
    readonly property int animNormal: 250

    // Additional spacing
    readonly property int padding: 16
    readonly property int paddingSmall: 8
}
