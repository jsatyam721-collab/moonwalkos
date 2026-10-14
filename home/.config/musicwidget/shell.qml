import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    readonly property var players: Mpris.players.values.filter(p => !((p.dbusName ?? "") + (p.identity ?? "")).includes("playerctld"))
    readonly property var hiRes: players.filter(p => !(p.dbusName ?? "").includes("chromium"))
    readonly property MprisPlayer player: hiRes.find(p => p.isPlaying) ?? players.find(p => p.isPlaying) ?? hiRes[0] ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real len: player?.length ?? 0

    property var pal: ({})
    property color cPanel: tone(pal["bbg2-pry"], 0.55, 1, 0.26, 0.42, "#7d243c")
    property color cInk: tone(pal["bbg1-pry"], 0, 0.6, 0.03, 0.06, "#0b0607")
    property color cStrip: tone(pal["bbg1-xa7"], 0.6, 1, 0.6, 0.72, "#e69aae")
    property color cFg: tone(pal["wb-act-fg"], 0, 1, 0.88, 0.96, "#ffe0e8")
    property color cBurst: Qt.hsla((cStrip.hslHue + 1 / 6) % 1, 0.95, 0.6, 1)
    Behavior on cPanel { ColorAnimation { duration: 600 } }
    Behavior on cInk { ColorAnimation { duration: 600 } }
    Behavior on cStrip { ColorAnimation { duration: 600 } }
    Behavior on cFg { ColorAnimation { duration: 600 } }
    Behavior on cBurst { ColorAnimation { duration: 600 } }

    property real pPanel: 0
    property real pRip: 0
    property real pStrip: 0
    property real pPop: 0
    property real shake: 0
    property bool closing: false
    property real time: 0
    property real phase: 0
    property int boil: 0

    function tone(rgb, sMin, sMax, lMin, lMax, fallback) {
        const c = rgb ? Qt.rgba(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1) : Qt.color(fallback)
        const clamp = (v, a, b) => Math.min(Math.max(v, a), b)
        return Qt.hsla(Math.max(0, c.hslHue), clamp(c.hslSaturation, sMin, sMax), clamp(c.hslLightness, lMin, lMax), 1)
    }
    function rnd(n) {
        const x = Math.sin((n + boil * 17.31) * 12.9898) * 43758.5453
        return (x - Math.floor(x)) * 2 - 1
    }
    function pop(d) {
        const t = Math.min(Math.max((pPop - d) / 0.3, 0), 1) - 1
        return 1 + 2.70158 * t * t * t + 1.70158 * t * t
    }
    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    function ring(r, seed, amp) {
        const pts = []
        for (let i = 0; i <= 44; i++) {
            const a = i / 40 * 2 * Math.PI
            const rr = r + amp * rnd(seed * 97 + (i % 40)) + (i > 40 ? amp * 0.8 : 0)
            pts.push(Qt.point(Math.cos(a) * rr, Math.sin(a) * rr))
        }
        return pts
    }
    function zig(x0, x1, amp, step) {
        const y = x => {
            const t = (((x + phase) / (2 * step)) % 1 + 1) % 1
            return amp * (1 - 4 * Math.abs(t - 0.5))
        }
        const pts = [Qt.point(x0, y(x0))]
        for (let k = Math.ceil((x0 + phase) / step); k * step - phase < x1; k++)
            pts.push(Qt.point(k * step - phase, y(k * step - phase)))
        pts.push(Qt.point(x1, y(x1)))
        return x1 > x0 ? pts : []
    }
    function close() {
        if (closing) return
        closing = true
        enter.stop()
        exit.start()
    }
    function launch() {
        Quickshell.execDetached(["youtube-music"])
        close()
    }

    FontLoader { id: pixel; source: Qt.resolvedUrl("fonts/Silkscreen-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("fonts/Silkscreen-Bold.ttf") }

    FileView {
        path: Quickshell.env("HOME") + "/.config/waybar/theme.css"
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            const p = {}
            const re = /@define-color\s+([\w-]+)\s+rgba?\((\d+),\s*(\d+),\s*(\d+)/g
            let m
            while ((m = re.exec(text())) !== null)
                p[m[1]] = [+m[2], +m[3], +m[4]]
            root.pal = p
        }
    }

    IpcHandler {
        target: "music"
        function toggle(): void { root.close() }
    }

    FrameAnimation {
        running: true
        onTriggered: {
            root.time += frameTime
            if (root.playing) root.phase += frameTime * 26
        }
    }
    Timer {
        running: true
        interval: 83
        repeat: true
        onTriggered: root.boil++
    }
    Timer {
        running: root.playing
        interval: 250
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    SequentialAnimation {
        id: enter
        running: true
        NumberAnimation { target: root; property: "pPanel"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        ScriptAction { script: shakeAnim.restart() }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pRip"; to: 1; duration: 460; easing.type: Easing.InOutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 200 }
                NumberAnimation { target: root; property: "pStrip"; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
            }
            SequentialAnimation {
                PauseAnimation { duration: 240 }
                NumberAnimation { target: root; property: "pPop"; to: 1; duration: 800 }
            }
        }
    }
    SequentialAnimation {
        id: exit
        NumberAnimation { target: root; property: "pPop"; to: 0; duration: 220; easing.type: Easing.InQuad }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pStrip"; to: 0; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "pRip"; to: 0; duration: 340; easing.type: Easing.InOutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 120 }
                NumberAnimation { target: root; property: "pPanel"; to: 0; duration: 260; easing.type: Easing.InBack; easing.overshoot: 2 }
            }
        }
        ScriptAction { script: Qt.quit() }
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shake"; to: 12; duration: 35 }
        NumberAnimation { target: root; property: "shake"; to: -9; duration: 45 }
        NumberAnimation { target: root; property: "shake"; to: 6; duration: 45 }
        NumberAnimation { target: root; property: "shake"; to: -3; duration: 45 }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 45 }
    }

    component Label: Item {
        id: lbl
        property string text
        property real size
        property real seed
        width: Math.min(txt.implicitWidth + size * 2, maxWidth)
        height: size * 2.3
        property real maxWidth
        rotation: -2.5 + 0.5 * root.rnd(seed)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 4
            color: root.cInk
        }
        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Qt.darker(root.cPanel, 1.6)
            border.color: root.cStrip
            border.width: 2.5
        }
        Item {
            anchors.fill: parent
            anchors.leftMargin: lbl.size
            anchors.rightMargin: lbl.size
            clip: true
            Text {
                id: txt
                readonly property real over: Math.max(0, implicitWidth - parent.width)
                anchors.verticalCenter: parent.verticalCenter
                text: lbl.text
                color: root.cFg
                font { family: pixel.name; pixelSize: lbl.size; bold: true }
                SequentialAnimation on x {
                    running: txt.over > 0
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1400 }
                    NumberAnimation { to: -txt.over; duration: txt.over * 28 }
                    PauseAnimation { duration: 900 }
                    NumberAnimation { to: 0; duration: 300; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    component Ctrl: Item {
        id: ctl
        property bool on: true
        property real seed
        property real popScale: 1
        property real press: ma.pressed ? 0.84 : ma.containsMouse && on ? 1.08 : 1
        signal tapped
        opacity: on ? 1 : 0.3
        rotation: 1.2 * root.rnd(seed)
        scale: popScale * press
        Behavior on press { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            enabled: ctl.on
            onClicked: ctl.tapped()
        }
    }

    component Skip: Shape {
        id: sk
        property real w
        property real h
        width: w
        height: h
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.cStrip
            strokeWidth: 4
            fillColor: root.cInk
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: [Qt.point(0, 0), Qt.point(sk.w * 0.42, sk.h / 2), Qt.point(0, sk.h), Qt.point(0, 0)] }
        }
        ShapePath {
            strokeColor: root.cStrip
            strokeWidth: 4
            fillColor: root.cInk
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: [Qt.point(sk.w * 0.38, 0), Qt.point(sk.w * 0.8, sk.h / 2), Qt.point(sk.w * 0.38, sk.h), Qt.point(sk.w * 0.38, 0)] }
        }
        ShapePath {
            strokeColor: root.cStrip
            strokeWidth: 4
            fillColor: root.cInk
            PathPolyline { path: [Qt.point(sk.w * 0.85, 0), Qt.point(sk.w, 0), Qt.point(sk.w, sk.h), Qt.point(sk.w * 0.85, sk.h), Qt.point(sk.w * 0.85, 0)] }
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "musicwidget"

        Item {
            id: stage
            readonly property real sw: width
            readonly property real sh: height
            readonly property real cx: sw * 0.165
            readonly property real cy: sh * 0.45
            readonly property real r: sh * 0.2
            width: parent.width
            height: parent.height
            x: root.shake
            y: root.shake * 0.4
            focus: true

            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Q) root.close()
                else if (!root.player) return
                else if (e.key === Qt.Key_Space) root.player.togglePlaying()
                else if (e.key === Qt.Key_Left && root.player.canGoPrevious) root.player.previous()
                else if (e.key === Qt.Key_Right && root.player.canGoNext) root.player.next()
                else if (e.key === Qt.Key_Up && root.player.volumeSupported) root.player.volume = Math.min(1, root.player.volume + 0.05)
                else if (e.key === Qt.Key_Down && root.player.volumeSupported) root.player.volume = Math.max(0, root.player.volume - 0.05)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
                onWheel: e => {
                    if (root.player?.volumeSupported)
                        root.player.volume = Math.min(1, Math.max(0, root.player.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)))
                }
            }

            ShaderEffect {
                anchors.fill: parent
                property point res: Qt.point(width, height)
                property real time: root.time
                property real pPanel: root.pPanel
                property real pRip: root.pRip
                property real pStrip: root.pStrip
                property color cPanel: root.cPanel
                property color cInk: root.cInk
                property color cStrip: root.cStrip
                fragmentShader: "comic.frag.qsb"
            }

            Repeater {
                model: [
                    { ang: -78, len: 0.12, w: 0.05, d: 0 },
                    { ang: -58, len: 0.15, w: 0.06, d: 90 },
                    { ang: -38, len: 0.10, w: 0.045, d: 180 },
                    { ang: -20, len: 0.13, w: 0.055, d: 270 }
                ]
                Shape {
                    id: burst
                    required property var modelData
                    required property int index
                    property real head: 0
                    property real tail: 0
                    readonly property real a: (modelData.ang + 1.5 * root.rnd(index * 7)) * Math.PI / 180
                    x: stage.cx
                    y: stage.cy
                    opacity: root.playing ? 1 : 0
                    scale: root.pop(0.1)
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    preferredRendererType: Shape.CurveRenderer

                    function pts() {
                        if (head <= tail) return []
                        const u = Qt.point(Math.cos(a), Math.sin(a))
                        const v = Qt.point(-u.y, u.x)
                        const r0 = stage.r * 1.18
                        const L = stage.sh * modelData.len
                        const s = r0 + tail * L
                        const e = r0 + head * L + 3 * root.rnd(index * 13)
                        const ws = stage.sh * modelData.w * (1 - 0.5 * tail) / 2
                        const we = stage.sh * modelData.w * 0.18 / 2
                        const P = (d, w) => Qt.point(u.x * d + v.x * w, u.y * d + v.y * w)
                        return [P(s, ws), P(e, we), P(e, -we), P(s, -ws), P(s, ws)]
                    }

                    ShapePath {
                        fillColor: root.cBurst
                        strokeColor: root.cInk
                        strokeWidth: 3
                        joinStyle: ShapePath.MiterJoin
                        PathPolyline { path: burst.pts() }
                    }

                    SequentialAnimation {
                        id: draw
                        running: root.playing
                        loops: Animation.Infinite
                        ScriptAction { script: { burst.head = 0; burst.tail = 0 } }
                        PauseAnimation { duration: burst.modelData.d }
                        NumberAnimation { target: burst; property: "head"; to: 1; duration: 170; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 650 }
                        NumberAnimation { target: burst; property: "tail"; to: 1; duration: 150; easing.type: Easing.InCubic }
                        PauseAnimation { duration: 700 - burst.modelData.d }
                    }
                    Connections {
                        target: root.player
                        function onTrackTitleChanged() { draw.restart() }
                    }
                }
            }

            Text {
                x: stage.cx + stage.r * 1.2
                y: stage.cy - stage.r * 1.55
                text: "030"
                rotation: -18 + 3 * root.rnd(3)
                color: root.cFg
                scale: root.pop(0.3)
                font { family: pixel.name; pixelSize: stage.sh * 0.045; bold: true }
            }

            Item {
                x: stage.cx
                y: stage.cy
                scale: root.pop(0)

                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: root.cInk
                        strokeWidth: 12
                        fillColor: root.cInk
                        PathPolyline { path: root.ring(stage.r + 8, 1, 1.5) }
                    }
                    ShapePath {
                        strokeColor: Qt.lighter(root.cPanel, 1.45)
                        strokeWidth: 5
                        fillColor: "transparent"
                        PathPolyline { path: root.ring(stage.r + 17, 2, 2.5) }
                    }
                    ShapePath {
                        strokeColor: root.cInk
                        strokeWidth: 3.5
                        fillColor: "transparent"
                        PathPolyline { path: root.ring(stage.r + 25, 3, 3.5) }
                    }
                }

                ClippingRectangle {
                    id: art
                    x: -stage.r
                    y: -stage.r
                    width: stage.r * 2
                    height: stage.r * 2
                    radius: stage.r
                    color: Qt.darker(root.cPanel, 2)

                    Image {
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(art.width * 2, art.height * 2)
                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 14000
                            loops: Animation.Infinite
                            paused: !root.playing
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.player
                        text: "PLAY\nSOMETHING"
                        horizontalAlignment: Text.AlignHCenter
                        color: root.cFg
                        font { family: pixel.name; pixelSize: stage.sh * 0.03; bold: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.player ? root.player.togglePlaying() : root.launch()
                    }
                }

                Rectangle {
                    readonly property real s: stage.sh * 0.105
                    x: -stage.r * 0.78 - s / 2
                    y: -stage.r * 0.78 - s / 2
                    width: s
                    height: s
                    radius: s / 2
                    visible: !!root.player
                    color: root.cStrip
                    border.color: root.cInk
                    border.width: 4
                    rotation: 4 * root.rnd(5)
                    scale: root.pop(0.2)

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: parent.width * 0.62
                        source: Quickshell.iconPath(root.player?.desktopEntry ?? "", true) || Quickshell.iconPath((root.player?.identity ?? "").toLowerCase(), "audio-x-generic")
                    }
                }
            }

            Label {
                x: stage.cx - width / 2
                y: stage.sh * 0.79
                size: stage.sh * 0.03
                maxWidth: stage.sw * 0.24
                seed: 21
                scale: root.pop(0.35)
                text: root.player?.trackTitle || "NOTHING PLAYING"
            }
            Label {
                x: stage.cx - width / 2
                y: stage.sh * 0.885
                size: stage.sh * 0.022
                maxWidth: stage.sw * 0.2
                seed: 22
                scale: root.pop(0.42)
                text: root.player ? (root.player.trackArtist || root.player.identity) : "CLICK THE DISC"
            }

            Repeater {
                model: [
                    { x: 0.47, y: 0.30, on: "≧◡≦", off: "－ω－" },
                    { x: 0.75, y: 0.17, on: "‾ᴗ‾", off: "-_-" },
                    { x: 0.63, y: 0.05, on: "o━o", off: "o━o" },
                    { x: 0.92, y: 0.30, on: "♪", off: "z" },
                    { x: 0.44, y: 0.88, on: "♫", off: "zZ" }
                ]
                Text {
                    required property var modelData
                    required property int index
                    x: stage.sw * modelData.x
                    y: stage.sh * modelData.y + (root.playing ? 6 * Math.sin(root.time * 3 + index * 1.7) : 0)
                    text: root.playing ? modelData.on : modelData.off
                    rotation: 6 * root.rnd(40 + index) + (root.playing ? 8 * Math.sin(root.time * 2.2 + index) : 0)
                    color: root.cFg
                    opacity: root.playing ? 1 : 0.6
                    scale: root.pop(0.5 + index * 0.05)
                    font { family: "JetBrains Mono"; pixelSize: stage.sh * 0.05; bold: true }
                }
            }

            AnimatedImage {
                height: stage.sh * 0.27
                width: height * 1.01
                x: stage.sw * 0.985 - width
                y: stage.sh * 0.985 - height
                source: "stewie.webp"
                playing: root.playing
                cache: true
                smooth: true
                mipmap: true
                transformOrigin: Item.Bottom
                scale: root.pop(0.8)
            }

            Item {
                id: prog
                property bool seeking: false
                property real seekFrac: 0
                readonly property real frac: seeking ? seekFrac : root.len > 0 ? Math.min(1, (root.player?.position ?? 0) / root.len) : 0
                property real amp: root.playing ? 1 : 0.15
                Behavior on amp { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                x: stage.sw * 0.4
                y: stage.sh * 0.53
                width: stage.sw * 0.5
                scale: root.pop(0.55)

                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: root.cFg
                        strokeWidth: 3.5
                        fillColor: "transparent"
                        joinStyle: ShapePath.MiterJoin
                        PathPolyline { path: root.zig(0, prog.width * prog.frac, 9 * prog.amp, 13) }
                    }
                    ShapePath {
                        strokeColor: root.cStrip
                        strokeWidth: 2.5
                        fillColor: "transparent"
                        joinStyle: ShapePath.MiterJoin
                        PathPolyline { path: root.zig(prog.width * prog.frac, prog.width, 6 * prog.amp, 9) }
                    }
                }
                Rectangle { x: -7; y: -7; width: 14; height: 14; radius: 7; color: root.cFg }
                Rectangle { x: prog.width - 6; y: -6; width: 12; height: 12; radius: 6; color: root.cStrip }
                Rectangle {
                    x: prog.width * prog.frac - width / 2
                    y: -height / 2
                    width: 20
                    height: 20
                    radius: 10
                    color: root.cFg
                    border.color: root.cInk
                    border.width: 3
                    scale: prog.seeking ? 1.35 : 1
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                }
                Text {
                    x: 0
                    y: stage.sh * 0.035
                    text: root.fmt(prog.frac * root.len)
                    color: root.cFg
                    font { family: pixel.name; pixelSize: stage.sh * 0.022 }
                }
                Text {
                    x: prog.width - implicitWidth
                    y: stage.sh * 0.035
                    text: root.fmt(root.len)
                    color: root.cStrip
                    font { family: pixel.name; pixelSize: stage.sh * 0.022 }
                }
                MouseArea {
                    x: -10
                    y: -24
                    width: prog.width + 20
                    height: 48
                    enabled: root.player?.canSeek ?? false
                    preventStealing: true
                    function at(mx) { return Math.min(1, Math.max(0, (mx - 10) / prog.width)) }
                    onPressed: e => { prog.seekFrac = at(e.x); prog.seeking = true }
                    onPositionChanged: e => prog.seekFrac = at(e.x)
                    onReleased: {
                        root.player.position = prog.seekFrac * root.len
                        prog.seeking = false
                    }
                }
            }

            Ctrl {
                readonly property real h: stage.sh * 0.1
                x: stage.sw * 0.47 - width / 2
                y: stage.sh * 0.76 - height / 2
                width: h * 1.3
                height: h
                seed: 31
                on: root.player?.canGoPrevious ?? false
                popScale: root.pop(0.65)
                onTapped: root.player.previous()
                Skip {
                    id: prevSkip
                    w: parent.width
                    h: parent.height
                    transform: Scale { xScale: -1; origin.x: prevSkip.width / 2 }
                }
            }

            Ctrl {
                id: pp
                readonly property real h: stage.sh * 0.17
                x: stage.sw * 0.6 - width / 2
                y: stage.sh * 0.76 - height / 2
                width: h * 0.75
                height: h
                seed: 32
                popScale: root.pop(0.7)
                on: root.player?.canTogglePlaying ?? false
                onTapped: root.player.togglePlaying()

                Row {
                    anchors.centerIn: parent
                    spacing: pp.h * 0.12
                    visible: root.playing
                    Repeater {
                        model: 2
                        Rectangle {
                            width: pp.h * 0.27
                            height: pp.h
                            radius: 6
                            color: root.cFg
                            border.color: root.cStrip
                            border.width: 4
                        }
                    }
                }
                Shape {
                    visible: !root.playing
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: root.cFg
                        strokeColor: root.cStrip
                        strokeWidth: 4
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: [Qt.point(pp.width * 0.08, 0), Qt.point(pp.width, pp.h / 2), Qt.point(pp.width * 0.08, pp.h), Qt.point(pp.width * 0.08, 0)] }
                    }
                }
            }

            Ctrl {
                readonly property real h: stage.sh * 0.1
                x: stage.sw * 0.73 - width / 2
                y: stage.sh * 0.76 - height / 2
                width: h * 1.3
                height: h
                seed: 33
                popScale: root.pop(0.75)
                on: root.player?.canGoNext ?? false
                onTapped: root.player.next()
                Skip {
                    w: parent.width
                    h: parent.height
                }
            }
        }
    }
}
