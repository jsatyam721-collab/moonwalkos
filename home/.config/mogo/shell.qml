import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property color lantern: "#53F5A9"
    readonly property color ink: "#04120A"
    readonly property string mono: "JetBrains Mono"
    readonly property real planetFrac: 0.4159
    readonly property int maxApps: 21
    readonly property string usagePath: Quickshell.env("HOME") + "/.cache/mogo/usage.json"

    property bool shown: false
    property real spin: 0
    property real spinT: 0
    property real drift: 0
    QtObject { id: caretBlink; property bool on: true }
    Timer { interval: 520; repeat: true; running: root.shown; onTriggered: caretBlink.on = !caretBlink.on }
    Timer {
        interval: 33
        repeat: true
        running: root.shown
        onTriggered: {
            root.spin = (root.spin + 0.033 * 6.2831853 / 80) % 6.2831853
            root.drift = (root.drift + 0.033 * 6.2831853 / 5.2) % 6.2831853
        }
    }
    property real reveal: 0
    property real form: 0
    property real beam: 0
    property string query: ""
    property int sel: 0
    property var entries: []
    property var results: []
    property var usage: ({})
    property var iconCache: ({})

    function iconFor(e) {
        if (iconCache[e.id] !== undefined) return iconCache[e.id]
        var p = Quickshell.iconPath(e.icon, true) || Quickshell.iconPath("application-x-executable", true) || ""
        iconCache[e.id] = p
        return p
    }

    function loadEntries() {
        var list = [], seen = {}
        var vals = DesktopEntries.applications.values
        for (var i = 0; i < vals.length; i++) {
            var e = vals[i]
            if (!e || e.noDisplay || !e.name || seen[e.name]) continue
            seen[e.name] = true
            list.push(e)
            iconFor(e)
        }
        entries = list
        refresh()
    }

    function score(e, q) {
        var n = e.name.toLowerCase()
        if (!q) return 1
        if (n.indexOf(q) === 0) return 1000 - n.length
        var words = n.split(/[\s\-_.]+/)
        for (var i = 0; i < words.length; i++) if (words[i].indexOf(q) === 0) return 800 - n.length
        var at = n.indexOf(q)
        if (at >= 0) return 600 - at
        var hay = ((e.genericName || "") + " " + (e.keywords || "") + " " + (e.categories || "")).toLowerCase()
        if (hay.indexOf(q) >= 0) return 300
        var j = 0
        for (var c = 0; c < n.length && j < q.length; c++) if (n[c] === q[j]) j++
        return j === q.length ? 100 - n.length * 0.5 : 0
    }

    function refresh() {
        var q = query.trim().toLowerCase()
        var scored = []
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i], s = score(e, q)
            if (s <= 0) continue
            scored.push({ e: e, s: s + Math.min(usage[e.id] || 0, 40) * (q ? 6 : 50) })
        }
        scored.sort(function (a, b) { return b.s - a.s || a.e.name.localeCompare(b.e.name) })
        results = scored.slice(0, maxApps).map(function (o) { return o.e })
        sel = 0
    }

    function launch(i) {
        var e = results[i]
        if (!e) return
        usage[e.id] = (usage[e.id] || 0) + 1
        usageFile.setText(JSON.stringify(usage))
        hide()
        if (Quickshell.env("MOGO_DRYRUN") === "1") console.log("MOGO would launch:", e.id)
        else e.execute()
    }

    function show() {
        if (shown) return
        query = ""
        refresh()
        shown = true
        hideAnim.stop()
        unform.stop()
        form = 0
        beam = 0
        showAnim.restart()
        construct.restart()
        bar.ping()
        keys.forceActiveFocus()
    }
    function hide() {
        if (!shown) return
        showAnim.stop()
        construct.stop()
        unform.restart()
    }
    function toggle() { shown && reveal > 0.5 ? hide() : show() }

    NumberAnimation { id: showAnim; target: root; property: "reveal"; to: 1; duration: 190; easing.type: Easing.OutCubic }
    NumberAnimation { id: hideAnim; target: root; property: "reveal"; to: 0; duration: 120; easing.type: Easing.InQuad; onFinished: root.shown = false }
    NumberAnimation { id: construct; target: root; property: "form"; from: 0; to: 1; duration: 620; easing.type: Easing.OutSine }
    SequentialAnimation {
        id: unform
        NumberAnimation { target: root; property: "form"; to: 0; duration: 290; easing.type: Easing.InSine }
        ScriptAction { script: hideAnim.restart() }
    }

    onQueryChanged: refresh()

    IpcHandler {
        target: "mogo"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    FileView { id: usageFile; path: root.usagePath; blockLoading: true; printErrors: false }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.loadEntries() }
    }

    Component.onCompleted: {
        try { usage = JSON.parse(usageFile.text() || "{}") } catch (e) { usage = {} }
        loadEntries()
        if (Quickshell.env("MOGO_SHOW") === "1") show()
    }

    PanelWindow {
        id: win
        visible: true
        anchors { top: true; left: true; bottom: root.shown; right: root.shown }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown && Quickshell.env("MOGO_NOINPUT") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: (!root.shown || Quickshell.env("MOGO_NOINPUT") === "1") ? noRegion : null
        Region { id: noRegion }
        WlrLayershell.namespace: "mogo"

        readonly property real pd: Math.min(height * 0.86, width * 0.6)
        readonly property real pr: pd * root.planetFrac
        readonly property real pcx: width / 2
        readonly property real pcy: height * 0.46

        Rectangle {
            anchors.fill: parent
            color: "#F2020604"
            opacity: root.reveal
        }

        MouseArea { anchors.fill: parent; onClicked: root.hide() }

        Item {
            id: stage
            anchors.fill: parent
            opacity: 1
            transformOrigin: Item.Center

            Image {
                id: atmo
                opacity: Math.max(0, Math.min(1, (root.form - 0.72) / 0.28))
                source: "art/atmo.png"
                width: win.pd; height: win.pd
                x: win.pcx - width / 2
                y: win.pcy - height / 2
                smooth: true
                mipmap: true
                sourceSize: Qt.size(1000, 1000)
            }
            Image {
                id: surf
                source: "art/surface.png"
                visible: false
                smooth: true
                mipmap: true
            }
            Image {
                id: emis
                source: "art/emission.png"
                visible: false
                smooth: true
                mipmap: true
            }
            ShaderEffect {
                width: win.pd; height: win.pd
                x: win.pcx - width / 2
                y: win.pcy - height / 2
                property variant surface: surf
                property variant emission: emis
                property real rot: root.spin
                property real px: 1.5 / (win.pd * 0.4159)
                property real form: root.form
                fragmentShader: "planet.frag.qsb"
            }

            Repeater {
                model: root.results.length
                delegate: Item {
                    id: pin
                    required property int index
                    readonly property var e: root.results[index]
                    readonly property bool active: index === root.sel
                    readonly property real golden: 2.39996323
                    readonly property real rn: Math.sqrt((index + 0.5) / root.maxApps) * 0.84
                    readonly property real th: index * golden - 1.2
                    readonly property real px: rn * Math.cos(th)
                    readonly property real py: rn * Math.sin(th) * 0.96
                    readonly property real depth: Math.sqrt(Math.max(0, 1 - px * px - py * py))
                    readonly property real lean: (0.5 + 0.5 * depth)
                    width: 46; height: 46
                    readonly property real ph: index * 1.913
                    x: win.pcx + px * win.pr - width / 2 + Math.cos(root.drift + ph * 0.7) * 1.6
                    y: win.pcy + py * win.pr - height / 2 + Math.sin(root.drift + ph) * 3.2
                    z: active ? 100 : 10 + depth * 10
                    readonly property real appear: Math.max(0, Math.min(1, (root.form - 0.78 - pin.rn * 0.14) / 0.08))
                    readonly property real pop: appear >= 1 ? 1 : 1 + 2.6 * Math.pow(appear - 1, 3) + 1.6 * Math.pow(appear - 1, 2)
                    scale: (active ? 1.32 : 0.62 + 0.42 * depth) * Math.max(0, pop)
                    visible: appear > 0
                    opacity: (active ? 1 : 0.42 + 0.5 * depth) * Math.min(1, appear * 2.5)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 110 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 56; height: 56; radius: 28
                        color: pin.active ? "#CC04120A" : "transparent"
                        border.color: root.lantern
                        border.width: pin.active ? 2 : 0
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 66; height: 66; radius: 33
                        color: "transparent"
                        border.color: root.lantern
                        border.width: 1
                        opacity: pin.active ? 0.45 : 0
                    }
                    Image {
                        id: ico
                        anchors.centerIn: parent
                        width: 34; height: 34
                        sourceSize: Qt.size(128, 128)
                        source: pin.e ? root.iconFor(pin.e) : ""
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        visible: false
                    }
                    ShaderEffectSource {
                        id: icoTex
                        sourceItem: ico
                        textureSize: Qt.size(96, 96)
                        mipmap: true
                        smooth: true
                        hideSource: true
                        live: true
                        visible: false
                    }
                    Rectangle {
                        anchors.centerIn: ico
                        width: 40; height: 40; radius: 20
                        color: "#7A000000"
                        visible: !pin.active
                    }
                    ShaderEffect {
                        anchors.fill: ico
                        property variant source: icoTex
                        property color tint: root.lantern
                        property real glow: pin.active ? 0.25 : 0
                        fragmentShader: "tint.frag.qsb"
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        width: lab.implicitWidth + 10
                        height: 15
                        color: pin.active ? root.lantern : "#D004120A"
                        border.color: "#4D53F5A9"
                        border.width: pin.active ? 0 : 1
                        visible: pin.active || pin.depth > 0.62
                        Text {
                            id: lab
                            anchors.centerIn: parent
                            text: pin.e ? (pin.e.name.length > 13 ? pin.e.name.slice(0, 12) + "…" : pin.e.name) : ""
                            color: pin.active ? root.ink : "#C8F5E4"
                            font { family: root.mono; pixelSize: 9; weight: pin.active ? Font.Bold : Font.Medium }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = pin.index
                        onClicked: root.launch(pin.index)
                    }
                }
            }

            ShaderEffect {
                id: liquid
                readonly property real pad: win.pr * 0.25
                x: win.pcx - win.pr - pad
                y: win.pcy - win.pr - pad
                width: (win.pr + pad) * 2
                height: bar.y + bar.height - y
                visible: root.form > 0.001 && root.form < 0.999
                property size size: Qt.size(width, height)
                property point cen: Qt.point(win.pcx - x, win.pcy - y)
                property real rad: win.pr
                property point emb: Qt.point(bar.x + 29 - x, bar.y + bar.height / 2 - y)
                property real form: root.form
                fragmentShader: "liquid.frag.qsb"
            }
            Item {
                id: bar
                width: Math.min(520, win.width * 0.52)
                height: 52
                x: win.pcx - width / 2
                y: win.pcy + win.pd * 0.5 + 4
                property real pulse: 0
                property real sweep: -1
                function ping() { pulseAnim.restart(); sweepAnim.restart() }
                NumberAnimation { id: pulseAnim; target: bar; property: "pulse"; from: 1; to: 0; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { id: sweepAnim; target: bar; property: "sweep"; from: -0.25; to: 1.25; duration: 380; easing.type: Easing.OutQuad }

                Rectangle {
                    id: halo
                    anchors.fill: shell
                    anchors.margins: -6
                    radius: height / 2
                    color: "transparent"
                    border.color: root.lantern
                    border.width: 6
                    opacity: 0.10 + 0.25 * bar.pulse + (keys.text.length ? 0.08 : 0)
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 24 }
                }

                Rectangle {
                    id: shell
                    anchors.fill: parent
                    radius: height / 2
                    clip: true
                    border.color: Qt.rgba(0.33, 0.96, 0.66, 0.55 + 0.45 * bar.pulse)
                    border.width: 1.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#E6103222" }
                        GradientStop { position: 0.5; color: "#F0061810" }
                        GradientStop { position: 1.0; color: "#F2030C08" }
                    }

                    Rectangle {
                        x: parent.radius; y: 2
                        width: parent.width - parent.radius * 2
                        height: 1
                        color: "#5553F5A9"
                    }

                    Rectangle {
                        width: parent.width * 0.35
                        height: parent.height * 2
                        y: -parent.height / 2
                        x: bar.sweep * parent.width - width / 2
                        rotation: 18
                        visible: bar.sweep > -0.2 && bar.sweep < 1.2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#0053F5A9" }
                            GradientStop { position: 0.5; color: "#3353F5A9" }
                            GradientStop { position: 1.0; color: "#0053F5A9" }
                        }
                    }

                    Repeater {
                        model: 26
                        Rectangle {
                            required property int index
                            x: 64 + index * ((shell.width - 150) / 26)
                            y: shell.height - 7
                            width: 2; height: 2; radius: 1
                            color: root.lantern
                            opacity: index < Math.min(26, keys.text.length * 3) ? 0.85 : 0.14
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }
                }

                Rectangle {
                    x: emblem.x + emblem.width / 2 - width / 2
                    y: emblem.y + emblem.height / 2 - height / 2
                    width: 30 + 22 * (1 - bar.pulse); height: width; radius: width / 2
                    color: "transparent"
                    border.color: root.lantern
                    border.width: 1
                    opacity: bar.pulse * 0.7
                }
                Item {
                    id: emblem
                    width: 30; height: 30
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    scale: 1 + 0.28 * bar.pulse
                    Rectangle { anchors.centerIn: parent; width: 18; height: 18; radius: 9; color: "transparent"; border.color: root.lantern; border.width: 3.2 }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 4.5; width: 22; height: 3.2; color: root.lantern }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 22.3; width: 22; height: 3.2; color: root.lantern }
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.lantern; shadowBlur: 0.6; shadowOpacity: 0.6 + 0.4 * bar.pulse; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 16 }
                }

                Rectangle {
                    x: 54
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 22
                    color: "#4053F5A9"
                }

                TextInput {
                    id: keys
                    anchors.verticalCenter: parent.verticalCenter
                    x: 68
                    width: parent.width - 68 - 110
                    color: "#E6FFF5"
                    selectionColor: "#5553F5A9"
                    font { family: root.mono; pixelSize: 15; letterSpacing: 1.2 }
                    clip: true
                    focus: true
                    cursorDelegate: Rectangle {
                        width: 9; height: 18
                        color: root.lantern
                        opacity: keys.activeFocus && caretBlink.on ? 0.9 : 0
                        y: (parent ? 0 : 0)
                    }
                    text: root.query
                    onTextEdited: { root.query = text; bar.ping() }
                    Keys.onPressed: ev => {
                        if (ev.key === Qt.Key_Escape) { root.hide(); ev.accepted = true }
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { bar.ping(); root.launch(root.sel); ev.accepted = true }
                        else if (ev.key === Qt.Key_Right || ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab) { if (root.results.length) root.sel = (root.sel + 1) % root.results.length; ev.accepted = true }
                        else if (ev.key === Qt.Key_Left || ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) { if (root.results.length) root.sel = (root.sel - 1 + root.results.length) % root.results.length; ev.accepted = true }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 68
                    visible: !keys.text.length
                    text: "\u201CMogo doesn't socialize.\u201D"
                    color: "#5E9A82"
                    font { family: root.mono; pixelSize: 14; italic: true; letterSpacing: 0.6 }
                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        anchors.right: parent.right
                        text: root.results.length
                        color: root.lantern
                        font { family: root.mono; pixelSize: 16; weight: Font.Bold }
                    }
                    Text {
                        anchors.right: parent.right
                        text: "IN ORBIT"
                        color: "#6E9C88"
                        font { family: root.mono; pixelSize: 8; letterSpacing: 1.6 }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 26
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 6
                    text: "SECTOR 2814 · MOGO"
                    color: "#5553F5A9"
                    font { family: root.mono; pixelSize: 8; letterSpacing: 2.4 }
                }
            }
        }
    }
}
