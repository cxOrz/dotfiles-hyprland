pragma Singleton
import QtQuick

QtObject {
    // ── Active theme name ──────────────────────────────────────────
    property string currentTheme: "material-ocean"

    // ── Theme definitions ──────────────────────────────────────────
    readonly property var _themes: ({
        "material-ocean": {
            name: "Material Ocean",
            panelBg: "#1A1B20", panelBorder: "#2A2C31", surface: "#1E1F25",
            surfaceContainer: "#282A2F", surfaceContainerHigh: "#33353A", surfaceBright: "#3E4046",
            primary: "#8AB4F8", primaryContainer: "#2D4F7F", onPrimaryContainer: "#D1E4FF",
            tileActive: "#8AB4F8", tileActiveText: "#062E6F",
            tileInactive: "#33353A", tileInactiveText: "#C4C6CF",
            sliderTrack: "#33353A", sliderActiveTrack: "#8AB4F8", sliderThumb: "#8AB4F8",
            textPrimary: "#E3E3E8", textSecondary: "#8E9099",
            toggleOff: "#5A5D65", connected: "#81C995", error: "#F28B82",
            secondaryContainer: "#2D4F7F", textOnSecondaryContainer: "#D1E4FF",
            shelfBg: "#1A1B20"
        },
        "catppuccin-mocha": {
            name: "Catppuccin Mocha",
            panelBg: "#1E1E2E", panelBorder: "#313244", surface: "#181825",
            surfaceContainer: "#313244", surfaceContainerHigh: "#45475A", surfaceBright: "#585B70",
            primary: "#89B4FA", primaryContainer: "#2B3D5B", onPrimaryContainer: "#CDD6F4",
            tileActive: "#89B4FA", tileActiveText: "#1E1E2E",
            tileInactive: "#313244", tileInactiveText: "#BAC2DE",
            sliderTrack: "#45475A", sliderActiveTrack: "#89B4FA", sliderThumb: "#89B4FA",
            textPrimary: "#CDD6F4", textSecondary: "#A6ADC8",
            toggleOff: "#585B70", connected: "#A6E3A1", error: "#F38BA8",
            secondaryContainer: "#2B3D5B", textOnSecondaryContainer: "#CDD6F4",
            shelfBg: "#1E1E2E"
        },
        "rose-pine-moon": {
            name: "Rosé Pine Moon",
            panelBg: "#232136", panelBorder: "#393552", surface: "#2A273F",
            surfaceContainer: "#393552", surfaceContainerHigh: "#44415A", surfaceBright: "#56526E",
            primary: "#C4A7E7", primaryContainer: "#3E3564", onPrimaryContainer: "#E0DEF4",
            tileActive: "#C4A7E7", tileActiveText: "#232136",
            tileInactive: "#393552", tileInactiveText: "#E0DEF4",
            sliderTrack: "#44415A", sliderActiveTrack: "#C4A7E7", sliderThumb: "#C4A7E7",
            textPrimary: "#E0DEF4", textSecondary: "#908CAA",
            toggleOff: "#56526E", connected: "#9CCFD8", error: "#EB6F92",
            secondaryContainer: "#3E3564", textOnSecondaryContainer: "#E0DEF4",
            shelfBg: "#232136"
        }
    })

    // ── Active theme reference ─────────────────────────────────────
    readonly property var _t: _themes[currentTheme] || _themes["material-ocean"]

    // ── Themed color properties ────────────────────────────────────
    // Surface colors
    readonly property color panelBg: _t.panelBg
    readonly property color panelBorder: _t.panelBorder
    readonly property color surface: _t.surface
    readonly property color surfaceContainer: _t.surfaceContainer
    readonly property color surfaceContainerHigh: _t.surfaceContainerHigh
    readonly property color surfaceBright: _t.surfaceBright

    // Primary colors
    readonly property color primary: _t.primary
    readonly property color primaryContainer: _t.primaryContainer
    readonly property color textOnPrimaryContainer: _t.onPrimaryContainer

    // Secondary colors
    readonly property color secondaryContainer: _t.secondaryContainer
    readonly property color textOnSecondaryContainer: _t.textOnSecondaryContainer

    // Tile states
    readonly property color tileActive: _t.tileActive
    readonly property color tileActiveText: _t.tileActiveText
    readonly property color tileInactive: _t.tileInactive
    readonly property color tileInactiveText: _t.tileInactiveText

    // Slider colors
    readonly property color sliderTrack: _t.sliderTrack
    readonly property color sliderActiveTrack: _t.sliderActiveTrack
    readonly property color sliderThumb: _t.sliderThumb

    // Text colors
    readonly property color textPrimary: _t.textPrimary
    readonly property color textSecondary: _t.textSecondary

    // Semantic colors
    readonly property color connected: _t.connected
    readonly property color error: _t.error
    readonly property color toggleOff: _t.toggleOff

    // Shelf
    readonly property color _shelfBgColor: _t.shelfBg
    readonly property color shelfBg: Qt.rgba(_shelfBgColor.r, _shelfBgColor.g, _shelfBgColor.b, 0.85)

    // ── Backward-compatible aliases ────────────────────────────────
    // Used by notifications, powermenu, and other modules
    readonly property color bg: panelBg
    readonly property color bgSecondary: surfaceContainer
    readonly property color bgTertiary: surfaceContainerHigh
    readonly property color accent: primary
    readonly property color border: surfaceContainerHigh
    readonly property color surfaceHigh: surfaceBright
    readonly property color hoverOverlay: Qt.rgba(1, 1, 1, 0.08)
    readonly property color textDisabled: Qt.rgba(textSecondary.r, textSecondary.g, textSecondary.b, 0.35)

    // ── Font properties ────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSizeNormal: 12
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeXL: 24
    readonly property int fontSizeSmall: 10
    readonly property int fontSizeXS: 9

    // ── Spacing ────────────────────────────────────────────────────
    readonly property int radiusSmall: 8
    readonly property int radiusLarge: 14
    readonly property int paddingNormal: 12
    readonly property int paddingLarge: 20
    readonly property int padding: 16
    readonly property int paddingSmall: 8

    // ── Shelf-specific ─────────────────────────────────────────────
    readonly property int shelfHeight: 48

    // ── Layout constants ───────────────────────────────────────────
    readonly property int panelWidth: 360
    readonly property int panelRadius: 24
    readonly property int tileRadius: 20
    readonly property int tileHeight: 64
    readonly property int sliderHeight: 44

    // ── Spacing scale ──────────────────────────────────────────────
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16

     // ── Animation durations (ms) ───────────────────────────────────
    readonly property int animDuration: 250
    readonly property int animDurationFast: 150

    // ── Theme metadata access ──────────────────────────────────────
    readonly property string themeName: _t.name
    readonly property var themeKeys: Object.keys(_themes)
}
