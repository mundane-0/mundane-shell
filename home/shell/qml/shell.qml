// ═══════════════════════════════════════════════════════════════════════
//  Mundane Shell — interface Quickshell (barre « îlots » + widgets bureau)
//
//  Personnalisation (rechargement à chaud, pas de rebuild) :
//   • ~/.config/quickshell/config.json  → position/taille/modules/rythme
//   • ~/.config/quickshell/theme.json   → couleurs, police, opacité
//   • Glisser-déposer les widgets du bureau → positions sauvegardées
//     automatiquement dans ~/.config/quickshell/positions.json
// ═══════════════════════════════════════════════════════════════════════

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Hyprland

ShellRoot {
    id: root

    // ─── Détection du compositeur ────────────────────────────────────────
    readonly property bool isHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
    readonly property bool isNiri: Quickshell.env("NIRI_SOCKET") !== ""

    // Barre verticale ? (déduit de config.json — source unique, sûre en
    // multi-écrans car portée par le singleton root et non par la fenêtre)
    readonly property bool barVertical: cfg.barPosition === "left" || cfg.barPosition === "right"

    // ─── config.json : tout ce qui est personnalisable sans toucher au QML ─
    FileView {
        id: cfgView
        path: Quickshell.env("HOME") + "/.config/quickshell/config.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: cfg
            property string barPosition: "top" // top | bottom | left | right
            property int barHeight: 46
            property int barMargin: 10
            property int barRadius: 22
            property int pillSpacing: 8

            property bool showWorkspaces: true
            property bool showClock: true
            property bool showTray: true
            property bool showWeather: true
            property bool showCpu: true
            property bool showMusic: false
            property bool showLauncher: true

            property bool widgetClock: true
            property bool widgetWeather: true
            property bool widgetDraw: true
            property real widgetScale: 1.0

            property string weatherCity: "Paris"
            property int clockUpdateMs: 1000
            property int cpuUpdateMs: 3000
            property int weatherUpdateMs: 900000
        }
    }

    // ─── theme.json : couleurs / police ────────────────────────────────────
    FileView {
        id: themeView
        path: Quickshell.env("HOME") + "/.config/quickshell/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: theme
            property string bg: "#F4F6F9"
            property real pillOpacity: 0.92
            property string fg: "#1C1F26"
            property string fgSoft: "#5C6370"
            property string accent: "#6C8CFF"
            property string accentFg: "#FFFFFF"
            property string border: "#1C1F2614"
            property string fontFamily: "Inter"
            property int fontPixelSize: 13
        }
    }

    // ─── positions.json : mémorise le drag & drop des widgets bureau ───────
    FileView {
        id: posView
        path: Quickshell.env("HOME") + "/.config/quickshell/positions.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: pos
            property real clockX: 60
            property real clockY: 90
            property real weatherX: 60
            property real weatherY: 280
            property real drawX: 60
            property real drawY: 470
        }
    }

    // ─── Workspaces Niri via IPC (aucune dépendance de module) ────────────
    property var niriWorkspaces: []
    readonly property var niriSorted: {
        const a = (niriWorkspaces || []).slice();
        a.sort((x, y) => (x.idx ?? 0) - (y.idx ?? 0));
        return a;
    }
    function niriIsActive(w) {
        return w.active === true || w.is_active === true || w.is_focused === true;
    }

    Process {
        id: niriProc
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriWorkspaces = JSON.parse(this.text);
                } catch (e) {
                    root.niriWorkspaces = [];
                }
            }
        }
    }
    Process {
        id: niriFocusProc
        command: ["niri", "msg", "action", "focus-workspace", "1"]
    }
    function niriFocusWorkspace(idx) {
        niriFocusProc.command = ["niri", "msg", "action", "focus-workspace", String(idx)];
        niriFocusProc.running = true;
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.isNiri && cfg.showWorkspaces
        onTriggered: niriProc.running = true
    }

    // ─── Launcher / CPU / Météo / Musique (processus partagés) ────────────
    Process {
        id: launcherProc
        command: ["fuzzel"]
    }
    function openLauncher() {
        launcherProc.running = true;
    }

    property string cpuText: ""
    Process {
        id: cpuProc
        command: [
            "awk",
            "NR==FNR{load=$1; next} /MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"⚡ %.2f  ·  RAM %.0f%%\", load, 100*(t-a)/t}",
            "/proc/loadavg",
            "/proc/meminfo"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.cpuText = this.text.trim()
        }
    }
    Timer {
        interval: cfg.cpuUpdateMs
        repeat: true
        running: cfg.showCpu
        onTriggered: cpuProc.running = true
    }

    property string weatherTemp: ""
    property string weatherEmoji: ""
    function weatherEmojiFor(code) {
        if (code === 0)
            return "☀️";
        if (code <= 2)
            return "🌤️";
        if (code === 3)
            return "☁️";
        if (code <= 48)
            return "🌫️";
        if (code <= 57)
            return "🌦️";
        if (code <= 67)
            return "🌧️";
        if (code <= 77)
            return "🌨️";
        if (code <= 82)
            return "🌧️";
        if (code <= 86)
            return "🌨️";
        return "⛈️";
    }
    Process {
        id: weatherProc
        command: ["curl", "-sf", "https://wttr.in/" + cfg.weatherCity + "?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const c = j.current_condition[0];
                    root.weatherTemp = c.temp_C + "°C";
                    root.weatherEmoji = root.weatherEmojiFor(parseInt(c.weatherCode));
                } catch (e) {
                    root.weatherTemp = "";
                    root.weatherEmoji = "";
                }
            }
        }
    }
    Timer {
        interval: cfg.weatherUpdateMs
        repeat: true
        running: cfg.showWeather || cfg.widgetWeather
        onTriggered: weatherProc.running = true
    }

    property string musicText: ""
    Process {
        id: musicProc
        command: ["playerctl", "metadata", "--format", "{{artist}} — {{title}}"]
        stdout: StdioCollector {
            onStreamFinished: root.musicText = this.text.trim()
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: cfg.showMusic
        onTriggered: musicProc.running = true
    }

    // ─── Horloge (source unique partagée par la barre et le widget) ────────
    property date now: new Date()
    function two(n) {
        return n < 10 ? "0" + n : "" + n;
    }
    Timer {
        interval: cfg.clockUpdateMs
        repeat: true
        running: cfg.showClock || cfg.widgetClock
        onTriggered: root.now = new Date()
    }

    Component.onCompleted: {
        if (cfg.showCpu)
            cpuProc.running = true;
        if (cfg.showWeather || cfg.widgetWeather)
            weatherProc.running = true;
        if (cfg.showMusic)
            musicProc.running = true;
        if (root.isNiri && cfg.showWorkspaces)
            niriProc.running = true;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Composants réutilisables
    //  NB : chaque composant reste autonome (aucune référence d'id vers
    //  un autre composant) — indispensable en multi-écrans.
    // ═══════════════════════════════════════════════════════════════════

    // Une « île » : rectangle arrondi translucide (thème clair par défaut).
    component PillBase: Rectangle {
        color: theme.bg
        opacity: theme.pillOpacity
        radius: cfg.barRadius
        border.width: 1
        border.color: theme.border
        implicitHeight: cfg.barHeight - 14
    }

    // ── Workspaces (Hyprland natif, Niri via IPC) ──
    component WorkspacesPill: PillBase {
        id: wsPill
        visible: cfg.showWorkspaces && (root.isHyprland || root.isNiri)
        implicitWidth: root.barVertical ? 84 : wsRow.implicitWidth + 24
        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.isHyprland ? Hyprland.workspaces : 0
                delegate: Rectangle {
                    id: hWs
                    required property var modelData
                    readonly property bool isOn: modelData?.active ?? false
                    width: 26
                    height: 26
                    radius: 13
                    color: isOn ? theme.accent : "transparent"
                    border.width: isOn ? 0 : 1
                    border.color: theme.border
                    Text {
                        anchors.centerIn: parent
                        text: hWs.modelData?.id ?? "?"
                        color: hWs.isOn ? theme.accentFg : theme.fg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fontPixelSize - 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (hWs.modelData?.activate)
                                hWs.modelData.activate();
                        }
                    }
                }
            }

            Repeater {
                model: root.isNiri ? root.niriSorted : 0
                delegate: Rectangle {
                    id: nWs
                    required property var modelData
                    readonly property bool isOn: root.niriIsActive(modelData ?? {})
                    width: 26
                    height: 26
                    radius: 13
                    color: isOn ? theme.accent : "transparent"
                    border.width: isOn ? 0 : 1
                    border.color: theme.border
                    Text {
                        anchors.centerIn: parent
                        text: nWs.modelData?.idx ?? "?"
                        color: nWs.isOn ? theme.accentFg : theme.fg
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fontPixelSize - 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.niriFocusWorkspace(nWs.modelData?.idx ?? 1)
                    }
                }
            }
        }
    }

    // ── Horloge (pill) ──
    component ClockPill: PillBase {
        visible: cfg.showClock
        implicitWidth: root.barVertical ? 84 : clockRow.implicitWidth + 24
        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.two(root.now.getHours()) + ":" + root.two(root.now.getMinutes())
                color: theme.fg
                font.family: theme.fontFamily
                font.pixelSize: theme.fontPixelSize + 2
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.now.toLocaleDateString(Qt.locale("fr_FR"), "d MMM")
                color: theme.fgSoft
                font.family: theme.fontFamily
                font.pixelSize: theme.fontPixelSize - 1
            }
        }
    }

    // ── Météo (pill) ──
    component WeatherPill: PillBase {
        visible: cfg.showWeather && root.weatherTemp !== ""
        implicitWidth: root.barVertical ? 84 : weatherRow.implicitWidth + 24
        Row {
            id: weatherRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.weatherEmoji
                font.pixelSize: theme.fontPixelSize + 3
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.weatherTemp
                color: theme.fg
                font.family: theme.fontFamily
                font.pixelSize: theme.fontPixelSize
            }
        }
    }

    // ── Statut : launcher + CPU/RAM + musique + zone de notification ──
    component StatusPill: PillBase {
        id: statusPill
        visible: cfg.showTray || cfg.showCpu || cfg.showLauncher || (cfg.showMusic && root.musicText !== "")
        implicitWidth: root.barVertical ? 84 : statusRow.implicitWidth + 24
        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 12

            Rectangle {
                visible: cfg.showLauncher
                width: 24
                height: 24
                radius: 12
                color: launcherMa.containsMouse ? theme.accent : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: "✦"
                    color: launcherMa.containsMouse ? theme.accentFg : theme.fg
                    font.pixelSize: 14
                }
                MouseArea {
                    id: launcherMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openLauncher()
                }
            }

            Text {
                visible: cfg.showCpu && root.cpuText !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.cpuText
                color: theme.fgSoft
                font.family: theme.fontFamily
                font.pixelSize: theme.fontPixelSize
            }

            Text {
                visible: cfg.showMusic && root.musicText !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: "🎵 " + root.musicText
                color: theme.fg
                font.family: theme.fontFamily
                font.pixelSize: theme.fontPixelSize
            }

            Item {
                visible: cfg.showTray
                width: trayRow.implicitWidth
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: trayRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Repeater {
                        model: cfg.showTray ? SystemTray.items : 0
                        delegate: Item {
                            id: trayEntry
                            required property var modelData
                            width: 22
                            height: 22
                            IconImage {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: trayEntry.modelData?.icon ?? ""
                                asynchronous: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    try {
                                        trayEntry.modelData.activate();
                                    } catch (e) {}
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── La barre : rangée horizontale ou colonne verticale selon config ──
    component Bar: PanelWindow {
        id: barWin
        property var modelData
        screen: modelData
        color: "transparent"

        anchors {
            top: cfg.barPosition === "top"
            bottom: cfg.barPosition === "bottom"
            left: cfg.barPosition === "left"
            right: cfg.barPosition === "right"
            leftMargin: cfg.barMargin
            rightMargin: cfg.barMargin
            topMargin: cfg.barMargin
            bottomMargin: cfg.barMargin
        }

        implicitWidth: root.barVertical ? 96 : cfg.barHeight
        implicitHeight: cfg.barHeight

        Loader {
            anchors.fill: parent
            active: !root.barVertical
            sourceComponent: BarContentRow
        }
        Loader {
            anchors.fill: parent
            active: root.barVertical
            sourceComponent: BarContentColumn
        }
    }

    component BarContentRow: Item {
        anchors.fill: parent
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: cfg.pillSpacing
            WorkspacesPill {}
        }
        Row {
            anchors.centerIn: parent
            spacing: cfg.pillSpacing
            ClockPill {}
            WeatherPill {}
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: cfg.pillSpacing
            StatusPill {}
        }
    }

    component BarContentColumn: Item {
        anchors.fill: parent
        Column {
            anchors.centerIn: parent
            spacing: cfg.pillSpacing
            WorkspacesPill {}
            ClockPill {}
            WeatherPill {}
            StatusPill {}
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Widgets de bureau (glisser-déposer)
    // ═══════════════════════════════════════════════════════════════════

    component WidgetBase: Rectangle {
        radius: 20
        color: theme.bg
        opacity: theme.pillOpacity
        border.width: 1
        border.color: theme.border
        scale: cfg.widgetScale
    }

    // ── Horloge bureau ──
    component ClockWidget: WidgetBase {
        id: clockWidget
        x: pos.clockX
        y: pos.clockY
        implicitWidth: 220
        implicitHeight: 110
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.two(root.now.getHours()) + ":" + root.two(root.now.getMinutes())
                color: theme.fg
                font.family: theme.fontFamily
                font.pixelSize: 40
                font.weight: Font.Light
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM")
                color: theme.fgSoft
                font.family: theme.fontFamily
                font.pixelSize: 13
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            drag.target: clockWidget
            onReleased: {
                pos.clockX = clockWidget.x;
                pos.clockY = clockWidget.y;
            }
        }
    }

    // ── Météo bureau ──
    component WeatherWidget: WidgetBase {
        id: weatherWidget
        x: pos.weatherX
        y: pos.weatherY
        implicitWidth: 220
        implicitHeight: 110
        visible: cfg.widgetWeather && root.weatherEmoji !== ""
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.weatherEmoji
                font.pixelSize: 38
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.weatherTemp + "  ·  " + cfg.weatherCity
                color: theme.fg
                font.family: theme.fontFamily
                font.pixelSize: 14
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            drag.target: weatherWidget
            onReleased: {
                pos.weatherX = weatherWidget.x;
                pos.weatherY = weatherWidget.y;
            }
        }
    }

    // ── Mini-app de dessin ──
    component DrawWidget: WidgetBase {
        id: drawWidget
        x: pos.drawX
        y: pos.drawY
        implicitWidth: 264
        implicitHeight: 268

        property string brushColor: "#6C8CFF"
        property var strokes: []

        Canvas {
            id: canvas
            x: 12
            y: 12
            width: 240
            height: 196
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                for (let s = 0; s < drawWidget.strokes.length; s++) {
                    const st = drawWidget.strokes[s];
                    if (st.points.length < 2)
                        continue;
                    ctx.strokeStyle = st.color;
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(st.points[0][0], st.points[0][1]);
                    for (let p = 1; p < st.points.length; p++)
                        ctx.lineTo(st.points[p][0], st.points[p][1]);
                    ctx.stroke();
                }
            }
        }

        MouseArea {
            id: paintArea
            x: 12
            y: 12
            width: 240
            height: 196
            cursorShape: Qt.CrossCursor
            property bool moving: false
            onPressed: function (mouse) {
                moving = true;
                drawWidget.strokes.push({
                    color: drawWidget.brushColor,
                    points: [[mouse.x, mouse.y]]
                });
                canvas.requestPaint();
            }
            onPositionChanged: function (mouse) {
                if (!moving)
                    return;
                const st = drawWidget.strokes[drawWidget.strokes.length - 1];
                st.points.push([mouse.x, mouse.y]);
                canvas.requestPaint();
            }
            onReleased: moving = false
        }

        Row {
            x: 12
            y: 220
            spacing: 8
            Repeater {
                model: ["#6C8CFF", "#CC4444", "#3C8056", "#B0811E", "#1C1F26"]
                delegate: Rectangle {
                    id: swatch
                    required property var modelData
                    width: 22
                    height: 22
                    radius: 11
                    color: modelData
                    border.width: drawWidget.brushColor === modelData ? 2 : 0
                    border.color: theme.fg
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawWidget.brushColor = swatch.modelData
                    }
                }
            }
            Item {
                width: 6
                height: 22
            }
            Rectangle {
                width: 62
                height: 22
                radius: 11
                color: theme.border
                Text {
                    anchors.centerIn: parent
                    text: "effacer"
                    color: theme.fg
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        drawWidget.strokes = [];
                        canvas.requestPaint();
                    }
                }
            }
        }

        MouseArea {
            // Drag par les marges du widget (le canvas et la palette prennent
            // leurs propres événements) ; z négatif = passe derrière tout.
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            z: -1
            drag.target: drawWidget
            onReleased: {
                pos.drawX = drawWidget.x;
                pos.drawY = drawWidget.y;
            }
        }
    }

    // ── Le bureau : layer « bottom » transparent sous les fenêtres ──
    component DesktopLayer: PanelWindow {
        property var modelData
        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            anchors.fill: parent
            ClockWidget {}
            WeatherWidget {}
            DrawWidget {}
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Instanciation par écran
    // ═══════════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {}
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            DesktopLayer {}
        }
    }
}
