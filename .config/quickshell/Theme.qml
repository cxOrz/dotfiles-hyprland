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
}
