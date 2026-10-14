import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

ShellRoot {
    id: root

    readonly property color lantern: "#6FD3FF"
    readonly property color core: "#FFFFFF"
    readonly property color text: "#EDEFE6"
    readonly property color dim: "#8A9184"
    readonly property color faint: "#2A2F27"
    readonly property color bbGreen: "#3E8E41"
    readonly property color bbDeep: "#173A1B"
    readonly property color desert: "#E3B23C"
    readonly property string mono: "JetBrains Mono"

    property bool shown: false
    property real reveal: 0
    property string page: "home"
    property string pskFor: ""
    property string now: ""

    readonly property var wifiDev: {
        var d = Networking.devices.values
        for (var i = 0; i < d.length; i++) if (d[i].type === DeviceType.Wifi) return d[i]
        return null
    }
    readonly property var wifiNets: {
        if (!wifiDev) return []
        var n = wifiDev.networks.values.slice()
        n = n.filter(function (x) { return x.name && x.name.length })
        n.sort(function (a, b) { return (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength) })
        return n.slice(0, 12)
    }
    readonly property var activeNet: {
        for (var i = 0; i < wifiNets.length; i++) if (wifiNets[i].connected) return wifiNets[i]
        return null
    }
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDevs: {
        if (!bt) return []
        var d = bt.devices.values.slice()
        d = d.filter(function (x) { return x.name && x.name.length && (x.paired || root.page === "bt") })
        d.sort(function (a, b) { return (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name) })
        return d.slice(0, 10)
    }
    readonly property var btActive: {
        for (var i = 0; i < btDevs.length; i++) if (btDevs[i].connected) return btDevs[i]
        return null
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    property bool airplane: false
    property bool night: false
    property bool dnd: false
    property real bright: 0.5
    property real rx: 0
    property real tx: 0
    property real lastRx: -1
    property real lastTx: -1

    function show() {
        if (shown) return
        page = "home"
        pskFor = ""
        shown = true
        refresh()
        closeAnim.stop()
        openAnim.restart()
        focusGrab.forceActiveFocus()
    }
    function hide() {
        if (!shown) return
        openAnim.stop()
        closeAnim.restart()
    }
    function toggle() { shown && reveal > 0.5 ? hide() : show() }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
    function refresh() { stateProc.running = true; brightProc.running = true }
    function fmtRate(b) {
        if (b < 1024) return Math.round(b) + "B"
        if (b < 1048576) return (b / 1024).toFixed(b < 10240 ? 1 : 0) + "K"
        return (b / 1048576).toFixed(1) + "M"
    }

    NumberAnimation { id: openAnim; target: root; property: "reveal"; to: 1; duration: 340; easing.type: Easing.OutQuint }
    NumberAnimation { id: closeAnim; target: root; property: "reveal"; to: 0; duration: 220; easing.type: Easing.InCubic; onFinished: root.shown = false }

    PwObjectTracker { objects: [root.sink, root.source] }
    readonly property bool noInput: Quickshell.env("PHONE_NOINPUT") === "1"
    Component.onCompleted: if (Quickshell.env("PHONE_SHOW") === "1") { show(); if (Quickshell.env("PHONE_PAGE")) page = Quickshell.env("PHONE_PAGE") }

    IpcHandler {
        target: "phone"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "rfkill list | grep -c 'Soft blocked: yes'; rfkill list | grep -c 'Soft blocked'; dunstctl is-paused; moonwalk-shell hyprsunset -r -q 2>/dev/null | grep -o '\"alt\":\"[a-z]*\"'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                root.airplane = parseInt(l[0]) > 0 && parseInt(l[0]) === parseInt(l[1])
                root.dnd = l[2] === "true"
                root.night = (l[3] || "").indexOf("\"active\"") >= 0
            }
        }
    }
    Process {
        id: brightProc
        command: ["brightnessctl", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = text.trim().split(",")
                if (f.length >= 5) root.bright = parseInt(f[2]) / Math.max(1, parseInt(f[4]))
            }
        }
    }
    Process {
        id: rateProc
        command: ["sh", "-c", "cat /sys/class/net/" + (root.wifiDev ? root.wifiDev.name : "wlan0") + "/statistics/rx_bytes /sys/class/net/" + (root.wifiDev ? root.wifiDev.name : "wlan0") + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n"), r = parseFloat(l[0]), t = parseFloat(l[1])
                if (root.lastRx >= 0) { root.rx = Math.max(0, r - root.lastRx); root.tx = Math.max(0, t - root.lastTx) }
                root.lastRx = r; root.lastTx = t
            }
        }
    }
    Timer {
        interval: 1000; repeat: true; running: root.shown; triggeredOnStart: true
        onTriggered: { rateProc.running = true; root.now = Qt.formatTime(new Date(), "hh:mm") }
    }
    Timer { interval: 4000; repeat: true; running: root.shown; onTriggered: root.refresh() }

    Binding { target: root.wifiDev; property: "scannerEnabled"; value: root.shown && root.page === "wifi"; when: root.wifiDev !== null }
    Binding { target: root.bt; property: "discovering"; value: root.shown && root.page === "bt" && root.bt.enabled; when: root.bt !== null && root.bt.enabled }

    PanelWindow {
        id: hot
        anchors { bottom: true; right: true }
        implicitWidth: 3
        implicitHeight: 3
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "phone-hotcorner"
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: dwell.restart()
            onExited: dwell.stop()
        }
        Timer { id: dwell; interval: 140; onTriggered: root.show() }
    }

    PanelWindow {
        id: win
        visible: true
        anchors { bottom: true; right: true; top: root.shown; left: root.shown }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown && !root.noInput ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "phone"
        mask: root.shown && !root.noInput ? null : noRegion
        Region { id: noRegion }

        MouseArea { anchors.fill: parent; enabled: root.shown; onClicked: root.hide() }

        Item {
            id: focusGrab
            focus: true
            Keys.onEscapePressed: root.page === "home" ? root.hide() : root.page = "home"
        }

        Item {
            id: phone
            width: 300; height: Math.min(556, win.height - 60)
            readonly property real restX: win.width - width - phone.depth - 34
            readonly property real restY: win.height - height - 18
            x: restX
            y: restY + (1 - root.reveal) * (height + 40)
            visible: root.shown

            MouseArea { anchors.fill: parent; onClicked: {} }

            readonly property real depth: 0

            Rectangle {
                x: -14; y: 26; width: parent.width + phone.depth + 10; height: parent.height + 6
                radius: 56
                color: "#000000"
                opacity: 0.6
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 56 }
            }
            Rectangle {
                x: -3; y: 7; width: parent.width + phone.depth + 2; height: parent.height + 2
                radius: 50
                color: "#000000"
                opacity: 0.75
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 0.6; blurMax: 14 }
            }

            Rectangle {
                id: wall
                x: phone.depth; y: phone.depth * 0.55
                width: parent.width; height: parent.height
                radius: 48
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#08080A" }
                    GradientStop { position: 0.80; color: "#0D0D10" }
                    GradientStop { position: 0.93; color: "#1D1D22" }
                    GradientStop { position: 0.985; color: "#34343B" }
                    GradientStop { position: 1.0; color: "#121215" }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 0.85; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#AA000000" }
                    }
                }
            }

            component SideKey: Item {
                id: key
                property bool onRight: false
                width: 6
                Rectangle {
                    anchors.fill: parent
                    radius: 2.5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: key.onRight ? "#151518" : "#2E2E34" }
                        GradientStop { position: 0.45; color: key.onRight ? "#3A3A42" : "#1C1C20" }
                        GradientStop { position: 1.0; color: key.onRight ? "#1A1A1E" : "#0E0E10" }
                    }
                }
                Rectangle { x: key.onRight ? 3.5 : 1; y: 2; width: 1; height: parent.height - 4; radius: 0.5; color: "#55555E"; opacity: 0.55 }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: "#000000"; opacity: 0.6 }
            }
            SideKey { x: -4; y: 112; height: 30 }
            SideKey { x: -4; y: 158; height: 54 }
            SideKey { x: -4; y: 222; height: 54 }
            SideKey { onRight: true; x: parent.width + phone.depth - 3; y: 184; height: 84 }

            Rectangle {
                id: rim
                anchors.fill: parent
                radius: 48
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#3C3C43" }
                    GradientStop { position: 0.12; color: "#1F1F23" }
                    GradientStop { position: 0.6; color: "#151518" }
                    GradientStop { position: 0.94; color: "#26262B" }
                    GradientStop { position: 1.0; color: "#4A4A52" }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#30FFFFFF" }
                        GradientStop { position: 0.06; color: "#00FFFFFF" }
                        GradientStop { position: 0.92; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#80000000" }
                    }
                }
            }

            Rectangle {
                id: body
                anchors.fill: parent
                anchors.margins: 2.5
                radius: 45.5
                gradient: Gradient {
                    GradientStop { position: 0; color: "#16161A" }
                    GradientStop { position: 0.5; color: "#101012" }
                    GradientStop { position: 1; color: "#0B0B0D" }
                }
                Image {
                    anchors.fill: parent
                    source: "matte.png"
                    fillMode: Image.Tile
                    opacity: 0.35
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: bodyMask }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 3; width: 56; height: 3; radius: 1.5
                    color: "#050506"
                    border.color: "#24242A"; border.width: 0.5
                }
            }
            Rectangle { id: bodyMask; anchors.fill: parent; anchors.margins: 2.5; radius: 45.5; visible: false; layer.enabled: true }

            Rectangle {
                id: screenMask
                anchors.fill: parent
                anchors.margins: 9
                radius: 40
                visible: false
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(Math.round(width * 3), Math.round(height * 3))
            }
            Item {
                id: screen
                anchors.fill: parent
                anchors.margins: 9
                layer.enabled: true
                layer.smooth: true
                layer.mipmap: true
                layer.textureSize: Qt.size(Math.round(width * 3), Math.round(height * 3))
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: screenMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Rectangle { anchors.fill: parent; color: "#060705" }
                Image {
                    anchors.fill: parent
                    source: "wallpaper.jpg"
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(846, 1614)
                    smooth: true
                    mipmap: true
                }

                Rectangle {
                    id: island
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10; width: 92; height: 26; radius: 13
                    color: "#000000"
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width - 22; width: 12; height: 12; radius: 6
                        color: "#05070C"; border.color: "#1B2230"; border.width: 1.5
                        Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: "#0E1A30"; border.color: "#24324E"; border.width: 0.8 }
                        Rectangle { x: 3.5; y: 3; width: 2; height: 2; radius: 1; color: "#9FB6E0"; opacity: 0.8 }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12; width: 5; height: 5; radius: 2.5
                        color: "#06080B"; border.color: "#141A22"; border.width: 1
                    }
                }

                Text {
                    x: 26; y: 14
                    text: root.now
                    color: root.text
                    font { family: root.mono; pixelSize: 13; weight: Font.Bold }
                }
                Column {
                    anchors.right: parent.right; anchors.rightMargin: 22; y: 11
                    Text { anchors.right: parent.right; text: "↓ " + root.fmtRate(root.rx); color: root.lantern; font { family: root.mono; pixelSize: 9; weight: Font.Bold } }
                    Text { anchors.right: parent.right; text: "↑ " + root.fmtRate(root.tx); color: root.dim; font { family: root.mono; pixelSize: 9; weight: Font.Bold } }
                }

                Item {
                    id: pages
                    anchors.fill: parent
                    anchors.topMargin: 48

                    Flickable {
                        id: home
                        anchors.fill: parent
                        contentHeight: homeCol.height + 20
                        clip: true
                        opacity: root.page === "home" ? 1 : 0
                        visible: opacity > 0
                        x: root.page === "home" ? 0 : -40
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        Column {
                            id: homeCol
                            x: 14; width: parent.width - 28
                            spacing: 12

                            Row {
                                width: parent.width
                                spacing: 10
                                Element { size: 46; sym: "S"; num: 16; on: true }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 46 - 10 - 90
                                    Text { text: (Quickshell.env("USER") || "user").slice(1); color: root.text; font { family: root.mono; pixelSize: 16; weight: Font.Black } }
                                    Text { text: "say my name."; color: root.desert; font { family: root.mono; pixelSize: 9; italic: true; letterSpacing: 0.5 } }
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    RoundBtn { glyph: "⚙"; onTap: { root.hide(); root.run("nm-connection-editor") } }
                                    RoundBtn { glyph: "⟳"; onTap: root.refresh() }
                                }
                            }

                            Grid {
                                columns: 2
                                spacing: 8
                                width: parent.width
                                Tile {
                                    glyph: "󰖩"; title: "Wi-Fi"; sym: "Wi"; num: 74
                                    sub: !Networking.wifiEnabled ? "Off" : root.activeNet ? root.activeNet.name : "On"
                                    on: Networking.wifiEnabled
                                    onToggle: Networking.wifiEnabled = !Networking.wifiEnabled
                                    onOpen: root.page = "wifi"
                                }
                                Tile {
                                    glyph: "󰂯"; title: "Bluetooth"; sym: "Bt"; num: 83
                                    sub: !root.bt || !root.bt.enabled ? "Off" : root.btActive ? root.btActive.name : "On"
                                    on: !!root.bt && root.bt.enabled
                                    onToggle: if (root.bt) root.bt.enabled = !root.bt.enabled
                                    onOpen: root.page = "bt"
                                }
                                Tile {
                                    glyph: "󰀝"; title: "Airplane"; sym: "Ap"; num: 18; sub: root.airplane ? "On" : "Off"; on: root.airplane; chevron: false
                                    onToggle: { root.airplane = !root.airplane; root.run(root.airplane ? "rfkill block all" : "rfkill unblock all") }
                                }
                                Tile {
                                    glyph: "󰖔"; title: "Night"; sym: "Nt"; num: 7; sub: root.night ? "On" : "Off"; on: root.night; chevron: false
                                    onToggle: { root.night = !root.night; root.run("moonwalk-shell hyprsunset -t -q") }
                                }
                                Tile {
                                    glyph: "󰂛"; title: "Silence"; sym: "Sl"; num: 14; sub: root.dnd ? "No pings" : "Off"; on: root.dnd; chevron: false
                                    onToggle: { root.dnd = !root.dnd; root.run("dunstctl set-paused " + (root.dnd ? "true" : "false")) }
                                }
                                Tile {
                                    glyph: "󰍬"; title: "Mic"; sym: "Mc"; num: 42
                                    sub: root.source && root.source.audio && root.source.audio.muted ? "Muted" : "Live"
                                    on: !!(root.source && root.source.audio && !root.source.audio.muted); chevron: false
                                    onToggle: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
                                }
                            }

                            Slab {
                                glyph: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"; title: "Volume"
                                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                                onMoved: v => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v } }
                                onGlyphTap: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                            }
                            Slab {
                                glyph: "󰍬"; title: "Mic"
                                value: root.source && root.source.audio ? root.source.audio.volume : 0
                                onMoved: v => { if (root.source && root.source.audio) root.source.audio.volume = v }
                            }
                            Slab {
                                glyph: "󰃟"; title: "Brightness"
                                value: root.bright
                                onMoved: v => { root.bright = Math.max(0.03, v); root.run("brightnessctl -q set " + Math.round(root.bright * 100) + "%") }
                            }
                        }
                    }

                    Item {
                        id: wifiPage
                        anchors.fill: parent
                        opacity: root.page === "wifi" ? 1 : 0
                        visible: opacity > 0
                        x: root.page === "wifi" ? 0 : 40
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        PageHead {
                            id: wifiHead
                            title: "Wi-Fi"
                            on: Networking.wifiEnabled
                            onToggle: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                        ListView {
                            anchors { top: wifiHead.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 16 }
                            clip: true
                            spacing: 6
                            model: Networking.wifiEnabled ? root.wifiNets : []
                            delegate: Rectangle {
                                id: netRow
                                required property var modelData
                                readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Unknown
                                readonly property bool asking: root.pskFor === modelData.name
                                width: ListView.view.width
                                height: asking ? 92 : 46
                                radius: 14
                                color: modelData.connected ? "#C814261A" : "#B30D0F0B"
                                border.color: modelData.connected ? root.bbGreen : root.faint
                                border.width: 1
                                Behavior on height { NumberAnimation { duration: 150 } }
                                Row {
                                    x: 12; y: 13
                                    spacing: 10
                                    Bars { strength: netRow.modelData.signalStrength; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        width: 160
                                        elide: Text.ElideRight
                                        text: netRow.modelData.name
                                        color: netRow.modelData.connected ? root.core : root.text
                                        font { family: root.mono; pixelSize: 12; weight: netRow.modelData.connected ? Font.Bold : Font.Normal }
                                    }
                                }
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 12; y: 14
                                    text: netRow.modelData.stateChanging ? "…" : netRow.modelData.connected ? "✓" : netRow.secured ? "" : ""
                                    color: netRow.modelData.connected ? root.lantern : root.dim
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                                }
                                MouseArea {
                                    width: parent.width; height: 46
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var n = netRow.modelData
                                        if (n.connected) n.disconnect()
                                        else if (n.known || !netRow.secured) n.connect()
                                        else root.pskFor = netRow.asking ? "" : n.name
                                    }
                                }
                                Rectangle {
                                    visible: netRow.asking
                                    x: 12; y: 50; width: parent.width - 24; height: 32; radius: 10
                                    color: "#040705"; border.color: root.lantern; border.width: 1
                                    TextInput {
                                        id: psk
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Password
                                        color: root.core
                                        font { family: root.mono; pixelSize: 12 }
                                        focus: netRow.asking
                                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                                        onAccepted: { netRow.modelData.connectWithPsk(text); root.pskFor = "" }
                                        Keys.onEscapePressed: root.pskFor = ""
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter; x: 10
                                        visible: !psk.text.length
                                        text: "password · enter to connect"
                                        color: root.dim
                                        font { family: root.mono; pixelSize: 10; italic: true }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: btPage
                        anchors.fill: parent
                        opacity: root.page === "bt" ? 1 : 0
                        visible: opacity > 0
                        x: root.page === "bt" ? 0 : 40
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        PageHead {
                            id: btHead
                            title: "Bluetooth"
                            on: !!root.bt && root.bt.enabled
                            onToggle: if (root.bt) root.bt.enabled = !root.bt.enabled
                        }
                        ListView {
                            anchors { top: btHead.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 16 }
                            clip: true
                            spacing: 6
                            model: root.bt && root.bt.enabled ? root.btDevs : []
                            delegate: Rectangle {
                                id: devRow
                                required property var modelData
                                width: ListView.view.width
                                height: 46
                                radius: 14
                                color: modelData.connected ? "#C814261A" : "#B30D0F0B"
                                border.color: modelData.connected ? root.bbGreen : root.faint
                                border.width: 1
                                Column {
                                    x: 14; anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        width: 180; elide: Text.ElideRight
                                        text: devRow.modelData.name
                                        color: devRow.modelData.connected ? root.core : root.text
                                        font { family: root.mono; pixelSize: 12; weight: devRow.modelData.connected ? Font.Bold : Font.Normal }
                                    }
                                    Text {
                                        text: devRow.modelData.pairing ? "pairing…" : devRow.modelData.connected ? ("connected" + (devRow.modelData.batteryAvailable ? " · " + Math.round(devRow.modelData.battery * 100) + "%" : "")) : devRow.modelData.paired ? "paired" : "new"
                                        color: root.dim
                                        font { family: root.mono; pixelSize: 9 }
                                    }
                                }
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                    text: devRow.modelData.connected ? "✓" : ""
                                    color: root.lantern
                                    font { family: root.mono; pixelSize: 13 }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var d = devRow.modelData
                                        if (d.connected) d.disconnect()
                                        else if (d.paired) d.connect()
                                        else { d.trusted = true; d.pair() }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 40
                    color: "transparent"
                    border.color: "#000000"
                    border.width: 6
                    opacity: 0.45
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 0.6; blurMax: 12 }
                }
                Item {
                    anchors.fill: parent
                    opacity: 0.9
                    Rectangle {
                        width: parent.width * 1.6; height: parent.height * 0.42
                        x: -parent.width * 0.55; y: -parent.height * 0.08
                        rotation: -32
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#00FFFFFF" }
                            GradientStop { position: 0.45; color: "#0BFFFFFF" }
                            GradientStop { position: 0.55; color: "#05FFFFFF" }
                            GradientStop { position: 1.0; color: "#00FFFFFF" }
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 2; width: parent.width - 70; height: 1
                        color: "#18FFFFFF"
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                    width: 96; height: 4; radius: 2
                    color: "#5A6A62"
                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.page === "home" ? root.hide() : root.page = "home" }
                }
            }

            Rectangle {
                anchors.fill: screen
                anchors.margins: -1
                radius: 41
                color: "transparent"
                border.color: "#050505"
                border.width: 2
            }
        }
    }

    component RoundBtn: Rectangle {
        property string glyph
        signal tap()
        width: 36; height: 36; radius: 18
        color: ma.containsMouse ? "#B814261A" : "#990D0F0B"
        border.color: ma.containsMouse ? root.bbGreen : root.faint; border.width: 1
        Text { anchors.centerIn: parent; text: parent.glyph; color: root.desert; font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 } }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.tap() }
    }

    component Tile: Rectangle {
        id: tile
        property string glyph
        property string title
        property string sub
        property bool on: false
        property bool chevron: true
        property string sym
        property int num
        signal toggle()
        signal open()
        width: (parent.width - 8) / 2
        height: 58
        radius: 18
        color: on ? "#B814261A" : "#990D0F0B"
        border.color: on ? root.bbGreen : root.faint
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Element { x: 7; anchors.verticalCenter: parent.verticalCenter; size: 28; sym: tile.sym; num: tile.num; on: tile.on }
        Column {
            x: 40; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40 - (tile.chevron ? 14 : 6)
            Row {
                width: parent.width
                spacing: 3
                Text {
                    id: tileIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.glyph
                    color: tile.on ? root.desert : root.dim
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    layer.enabled: tile.on
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.desert; shadowBlur: 0.5; shadowOpacity: 0.7; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 8 }
                }
                Text { width: parent.width - tileIcon.width - 3; elide: Text.ElideRight; text: tile.title; color: tile.on ? root.core : root.text; font { family: root.mono; pixelSize: 10; weight: Font.Bold; letterSpacing: -0.2 } }
            }
            Text { width: parent.width; elide: Text.ElideRight; text: tile.sub; color: tile.on ? root.desert : root.dim; font { family: root.mono; pixelSize: 9 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tile.toggle() }
        Text {
            visible: tile.chevron
            anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
            text: "›"; color: tile.on ? root.desert : root.dim
            font { family: root.mono; pixelSize: 18; weight: Font.Bold }
            MouseArea { anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor; onClicked: tile.open() }
        }
    }

    component Slab: Rectangle {
        id: slab
        property string glyph
        property string title
        property real value: 0
        signal moved(real v)
        signal glyphTap()
        width: parent.width
        height: 44
        radius: 16
        color: "#990A0F0C"
        border.color: root.faint; border.width: 1
        clip: true
        Rectangle {
            width: Math.max(parent.radius * 2, parent.width * Math.min(1, slab.value))
            height: parent.height
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#0E2F3D" }
                GradientStop { position: 1; color: "#1E6E8E" }
            }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 18; radius: 1.5; color: root.lantern }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function set(mx) { slab.moved(Math.max(0, Math.min(1, mx / width))) }
            onPressed: m => set(m.x)
            onPositionChanged: m => { if (pressed) set(m.x) }
            onWheel: w => slab.moved(Math.max(0, Math.min(1, slab.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
        Text {
            x: 14; anchors.verticalCenter: parent.verticalCenter
            text: slab.glyph; color: root.core
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: slab.glyphTap() }
        }
        Text { x: 40; anchors.verticalCenter: parent.verticalCenter; text: slab.title; color: root.text; font { family: root.mono; pixelSize: 11; weight: Font.Bold } }
        Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: Math.round(Math.min(1, slab.value) * 100) + "%"; color: root.lantern; font { family: root.mono; pixelSize: 10; weight: Font.Bold } }
    }

    component PageHead: Item {
        id: head
        property string title
        property bool on: false
        signal toggle()
        width: parent.width; height: 40
        Text {
            x: 16; anchors.verticalCenter: parent.verticalCenter
            text: "‹  " + head.title
            color: root.text
            font { family: root.mono; pixelSize: 14; weight: Font.Bold }
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "home" }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 24; radius: 12
            color: head.on ? root.bbGreen : "#1A1D17"
            Behavior on color { ColorAnimation { duration: 140 } }
            Rectangle {
                width: 18; height: 18; radius: 9; y: 3
                x: head.on ? parent.width - width - 3 : 3
                color: head.on ? "#FFFFFF" : root.dim
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: head.toggle() }
        }
    }

    component Element: Rectangle {
        id: el
        property real size: 30
        property string sym
        property int num
        property bool on: false
        width: size; height: size; radius: size * 0.14
        gradient: Gradient {
            GradientStop { position: 0; color: el.on ? "#4A9E4D" : "#23271F" }
            GradientStop { position: 1; color: el.on ? "#1F5A22" : "#15180F" }
        }
        border.color: el.on ? "#6CC070" : "#33382D"
        border.width: 1
        Text {
            x: el.size * 0.1; y: el.size * 0.04
            text: el.num
            color: el.on ? "#E9F5E0" : root.dim
            font { family: root.mono; pixelSize: Math.max(6, Math.round(el.size * 0.2)); weight: Font.Bold }
        }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: el.size * 0.08
            text: el.sym
            color: el.on ? "#FFFFFF" : root.text
            font { family: "DejaVu Sans"; pixelSize: Math.round(el.size * 0.46); weight: Font.Bold }
        }
    }

    component Bars: Row {
        property real strength: 0
        spacing: 2
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 3; height: 4 + index * 3
                anchors.bottom: parent.bottom
                radius: 1
                color: parent.strength >= (index + 1) / 4.5 ? root.lantern : "#2A2F27"
            }
        }
    }
}
