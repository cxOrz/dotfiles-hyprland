pragma Singleton
import QtQuick

QtObject {
    // ── Active theme name ──────────────────────────────────────────
    property string currentTheme: "md3-cobalt-night"

    // ── Theme definitions ──────────────────────────────────────────
    readonly property var _themes: ({
        "md3-cobalt-night": {
            name: "Cobalt Night",
            panelBg: "#0F1117", panelBorder: "#252740", surface: "#1A1C28",
            surfaceContainer: "#252740", surfaceContainerHigh: "#2E3148", surfaceBright: "#3A3E60",
            primary: "#9BBDE8", primaryContainer: "#1E3058", onPrimaryContainer: "#C8D8F5",
            tileActive: "#9BBDE8", tileActiveText: "#0F1117",
            tileInactive: "#2E3148", tileInactiveText: "#E0E2F0",
            sliderTrack: "#2E3148", sliderActiveTrack: "#9BBDE8", sliderThumb: "#9BBDE8",
            textPrimary: "#E0E2F0", textSecondary: "#8E90A8",
            toggleOff: "#404460", connected: "#86D5A0", error: "#F2A8B8",
            secondaryContainer: "#1E3058", textOnSecondaryContainer: "#C8D8F5",
            shelfBg: "#0F1117"
        },
        "md3-sage-forest": {
            name: "Sage Forest",
            panelBg: "#0D1410", panelBorder: "#203028", surface: "#172219",
            surfaceContainer: "#203028", surfaceContainerHigh: "#2A3D2D", surfaceBright: "#385045",
            primary: "#7EC996", primaryContainer: "#1A4028", onPrimaryContainer: "#B8E8C8",
            tileActive: "#7EC996", tileActiveText: "#0D1410",
            tileInactive: "#2A3D2D", tileInactiveText: "#DCF0E2",
            sliderTrack: "#2A3D2D", sliderActiveTrack: "#7EC996", sliderThumb: "#7EC996",
            textPrimary: "#DCF0E2", textSecondary: "#8AAE92",
            toggleOff: "#3A5040", connected: "#72CAD0", error: "#F2A8A8",
            secondaryContainer: "#1A4028", textOnSecondaryContainer: "#B8E8C8",
            shelfBg: "#0D1410"
        },
        "md3-rose-quartz": {
            name: "Rose Quartz",
            panelBg: "#170E12", panelBorder: "#381C2C", surface: "#281520",
            surfaceContainer: "#381C2C", surfaceContainerHigh: "#4A2838", surfaceBright: "#603050",
            primary: "#EEA8C0", primaryContainer: "#4A1C30", onPrimaryContainer: "#F5D0E0",
            tileActive: "#EEA8C0", tileActiveText: "#170E12",
            tileInactive: "#4A2838", tileInactiveText: "#F0DEE5",
            sliderTrack: "#4A2838", sliderActiveTrack: "#EEA8C0", sliderThumb: "#EEA8C0",
            textPrimary: "#F0DEE5", textSecondary: "#A88090",
            toggleOff: "#603048", connected: "#A0C8F0", error: "#F5A0A8",
            secondaryContainer: "#4A1C30", textOnSecondaryContainer: "#F5D0E0",
            shelfBg: "#170E12"
        },
        "md3-amethyst": {
            name: "Amethyst",
            panelBg: "#110E18", panelBorder: "#2C2440", surface: "#1E1A2C",
            surfaceContainer: "#2C2440", surfaceContainerHigh: "#3A3050", surfaceBright: "#504068",
            primary: "#C8B0F0", primaryContainer: "#3A2870", onPrimaryContainer: "#E8D8FF",
            tileActive: "#C8B0F0", tileActiveText: "#110E18",
            tileInactive: "#3A3050", tileInactiveText: "#E8E0F5",
            sliderTrack: "#3A3050", sliderActiveTrack: "#C8B0F0", sliderThumb: "#C8B0F0",
            textPrimary: "#E8E0F5", textSecondary: "#9A90B8",
            toggleOff: "#504068", connected: "#86D0C0", error: "#F5A0A8",
            secondaryContainer: "#3A2870", textOnSecondaryContainer: "#E8D8FF",
            shelfBg: "#110E18"
        },
        "md3-amber-dusk": {
            name: "Amber Dusk",
            panelBg: "#18120A", panelBorder: "#382818", surface: "#281E10",
            surfaceContainer: "#382818", surfaceContainerHigh: "#483220", surfaceBright: "#604030",
            primary: "#F0B87A", primaryContainer: "#503018", onPrimaryContainer: "#F8DEB8",
            tileActive: "#F0B87A", tileActiveText: "#18120A",
            tileInactive: "#483220", tileInactiveText: "#F0E8D5",
            sliderTrack: "#483220", sliderActiveTrack: "#F0B87A", sliderThumb: "#F0B87A",
            textPrimary: "#F0E8D5", textSecondary: "#A88860",
            toggleOff: "#604030", connected: "#90C890", error: "#F0907A",
            secondaryContainer: "#503018", textOnSecondaryContainer: "#F8DEB8",
            shelfBg: "#18120A"
        },
        "md3-arctic-mist": {
            name: "Arctic Mist",
            panelBg: "#080F14", panelBorder: "#162838", surface: "#101C26",
            surfaceContainer: "#162838", surfaceContainerHigh: "#1E3848", surfaceBright: "#2A4A60",
            primary: "#7ECCE8", primaryContainer: "#103858", onPrimaryContainer: "#C0E4F5",
            tileActive: "#7ECCE8", tileActiveText: "#080F14",
            tileInactive: "#1E3848", tileInactiveText: "#D8EEF5",
            sliderTrack: "#1E3848", sliderActiveTrack: "#7ECCE8", sliderThumb: "#7ECCE8",
            textPrimary: "#D8EEF5", textSecondary: "#7A9AA8",
            toggleOff: "#2A4A60", connected: "#90D4A8", error: "#F2A8A8",
            secondaryContainer: "#103858", textOnSecondaryContainer: "#C0E4F5",
            shelfBg: "#080F14"
        }
    })

    // ── Active theme reference ─────────────────────────────────────
    readonly property var _t: _themes[currentTheme] || _themes["md3-cobalt-night"]

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
    readonly property int animDuration: 200
    readonly property int animDurationFast: 200

    // ── Theme metadata access ──────────────────────────────────────
    readonly property string themeName: _t.name
    readonly property var themeKeys: Object.keys(_themes)
}
