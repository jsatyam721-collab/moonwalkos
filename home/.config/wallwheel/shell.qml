import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property var themes: []
    property int ti: 0
    property string curTheme: ""
    property string curWall: ""
    property int sel: 0
    readonly property var walls: themes.length ? themes[ti].walls : []
    readonly property string themeName: themes.length ? themes[ti].name : ""
    readonly property int count: walls.length
    readonly property color selAccent: count ? walls[wrap(sel)].acc : "#e6e6ea"
    readonly property string moonwalkShell: Quickshell.env("HOME") + "/.local/bin/moonwalk-shell"

    function wrap(i) { return ((i % count) + count) % count }
    function accent(list) {
        const cs = (list || "").split(",").filter(x => x.length === 6).map(x => Qt.rgba(parseInt(x.slice(0, 2), 16) / 255, parseInt(x.slice(2, 4), 16) / 255, parseInt(x.slice(4, 6), 16) / 255, 1))
        let best = null
        for (const c of cs) if (!best || c.hslSaturation > best.hslSaturation) best = c
        if (!best || best.hslSaturation < 0.12) return "#e6e6ea"
        return Qt.hsla(best.hslHue, Math.max(best.hslSaturation, 0.65), Math.min(Math.max(best.hslLightness, 0.62), 0.74), 1)
    }
    function stem(p) { return p.split("/").pop().replace(/\.[^.]+$/, "") }
    function switchTheme(step) {
        if (!themes.length) return
        ti = (ti + step + themes.length) % themes.length
        sel = Math.max(0, walls.findIndex(w => w.path === curWall))
    }
    function apply() {
        if (!count || closing) return
        const f = walls[wrap(sel)].path
        const t = themeName === curTheme ? "" : themeName
        if (f === curWall && !t) return root.close()
        if (oldWall.status !== Image.Ready) {
            Quickshell.execDetached(["sh", "-c", 'export WALLPAPER_AWWW_TRANSITION_DEFAULT=none WALLPAPER_AWWW_TRANSITION_NEXT=none WALLPAPER_AWWW_TRANSITION_PREV=none; if [ -n "$2" ]; then ln -sfn "$1" "$HOME/.config/moonwalk/themes/$2/wall.set"; "$0" theme.switch.sh -s "$2"; else "$0" wallpaper.sh -s "$1" --global; fi; "$0" color.set.sh "$1"', moonwalkShell, f, t])
            return root.close()
        }
        newWall = f
        newTheme = t
        applyTime = Date.now()
        burnStage = 1
        setter.running = true
        burnGuard.start()
        root.close()
    }

    property string newWall: ""
    property string newTheme: ""
    property real applyTime: 0
    Timer {
        id: ignite
        onTriggered: {
            burnAnim.start()
            barTint.start()
        }
    }
    Timer {
        id: barTint
        interval: 800
        onTriggered: Quickshell.execDetached(["python3", "-I", Quickshell.shellPath("recolor.py"), root.newWall])
    }
    property int burnStage: 0
    property real burn: 0
    property bool moonwalkStarted: false
    function startMoonwalk() {
        if (moonwalkStarted) return
        moonwalkStarted = true
        Quickshell.execDetached(["sh", "-c", 'export WALLPAPER_AWWW_TRANSITION_DEFAULT=none WALLPAPER_AWWW_TRANSITION_NEXT=none WALLPAPER_AWWW_TRANSITION_PREV=none; if [ -n "$2" ]; then "$0" theme.switch.sh -s "$2"; else "$0" wallpaper.sh -s "$1" --global; fi; "$0" color.set.sh "$1"', moonwalkShell, newWall, newTheme])
    }
    function finishBurn() {
        if (burnStage === 3) return
        burnStage = 3
        startMoonwalk()
        Qt.quit()
    }
    Process {
        id: setter
        command: ["sh", "-c", `
            [ -n "$2" ] && ln -sfn "$1" "$HOME/.config/moonwalk/themes/$2/wall.set"
            awww img "$1" --transition-type none
            for i in $(seq 100); do awww query 2>/dev/null | grep -qF "$1" && break; sleep 0.03; done
            sleep 0.05
            echo ready`, root.moonwalkShell, root.newWall, root.newTheme]
        stdout: SplitParser {
            onRead: line => {
                if (line === "ready" && root.burnStage === 1) {
                    root.burnStage = 2
                    root.startMoonwalk()
                    ignite.interval = Math.max(1, 470 - (Date.now() - root.applyTime))
                    ignite.start()
                }
            }
        }
    }
    NumberAnimation {
        id: burnAnim
        target: root; property: "burn"
        from: 0; to: 1
        duration: 1900
        easing.type: Easing.InOutSine
        onFinished: root.finishBurn()
    }
    Timer {
        id: burnGuard
        interval: 9000
        onTriggered: root.finishBurn()
    }

    property bool closing: false
    property real absorb: 0
    function close() {
        if (closing) return
        closing = true
        absorbAnim.start()
    }
    NumberAnimation {
        id: absorbAnim
        target: root; property: "absorb"
        from: 0; to: 1
        duration: 560
        easing.type: Easing.InCubic
        onFinished: if (root.burnStage === 0) Qt.quit()
    }

    Process {
        running: true
        command: ["python3", "-I", Quickshell.shellPath("index.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const cur = lines[0]
                const by = {}
                for (const l of lines.slice(1)) {
                    const [name, path, thumb, acc] = l.split("\t")
                    ;(by[name] = by[name] || []).push({ path, thumb, acc: root.accent(acc) })
                }
                const list = Object.keys(by).sort().map(name => ({ name, walls: by[name] }))
                root.curWall = cur
                root.curTheme = (list.find(t => t.walls.some(w => w.path === cur)) || { name: "" }).name
                root.themes = list
                root.ti = Math.max(0, list.findIndex(t => t.name === root.curTheme))
                root.sel = Math.max(0, root.walls.findIndex(w => w.path === cur))
            }
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: root.burnStage < 3
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "wallwheel-burn"
        mask: Region {}

        Image {
            id: oldWall
            anchors.fill: parent
            source: root.curWall ? "file://" + root.curWall : ""
            sourceSize: Qt.size(2560, 1440)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.burnStage < 2 && status === Image.Ready
        }
        ShaderEffect {
            anchors.fill: parent
            visible: root.burnStage >= 2
            property variant source: oldWall
            property real progress: root.burn
            property real aspect: width / height
            property point origin: Qt.point(0, 1)
            fragmentShader: "burn.frag.qsb"
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        visible: root.absorb < 1
        color: Qt.rgba(0, 0, 0, 0.6 * (1 - root.absorb))
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "wallwheel"

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Item {
            id: mover
            anchors.fill: parent
            readonly property real swirl: Math.sin(Math.PI * root.absorb) * 110
            transform: Translate {
                x: -mover.width / 2 * root.absorb - mover.swirl
                y: mover.height / 2 * root.absorb - mover.swirl
            }

        Item {
            id: disc
            width: 620; height: 620
            anchors.centerIn: parent
            property real pop: root.themes.length ? 1 : 0.86
            Behavior on pop { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
            scale: Math.min(1, (parent.height - 90) / 690) * pop * (1 - 0.97 * root.absorb)
            opacity: (root.themes.length ? 1 : 0) * (1 - Math.max(0, root.absorb - 0.8) / 0.2)
            rotation: -540 * root.absorb * root.absorb
            enabled: !root.closing
            Behavior on opacity { NumberAnimation { duration: 160 } }
            focus: true

            readonly property real ringR: 205
            readonly property real slotD: 150

            Keys.onPressed: e => {
                if (root.closing) return
                if (e.key === Qt.Key_Escape) root.close()
                else if (e.key === Qt.Key_Tab || e.key === Qt.Key_BracketRight || e.key === Qt.Key_E) root.switchTheme(1)
                else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_BracketLeft || e.key === Qt.Key_Q) root.switchTheme(-1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.apply()
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_L || e.key === Qt.Key_J) root.sel++
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_H || e.key === Qt.Key_K) root.sel--
            }

            MouseArea {
                anchors.fill: parent
                onWheel: w => w.angleDelta.y < 0 ? root.sel++ : root.sel--
            }


            Item {
                id: ring
                anchors.fill: parent
                rotation: -root.sel * 60
                Behavior on rotation { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                component Lobes: Repeater {
                    property real r
                    property color fill: "white"
                    model: 6
                    Rectangle {
                        required property int index
                        readonly property real a: index * Math.PI / 3
                        width: 2 * r; height: width; radius: width / 2
                        color: fill
                        x: disc.width / 2 + disc.ringR * Math.sin(a) - width / 2
                        y: disc.height / 2 - disc.ringR * Math.cos(a) - height / 2
                    }
                }

                Item {
                    id: housing
                    anchors.fill: parent
                    readonly property real coreR: 236
                    readonly property real lobeR: disc.slotD / 2 + 21

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "black"
                            shadowOpacity: 0.85
                            shadowBlur: 1
                            blurMax: 48
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 2 * (housing.coreR + 4); height: width; radius: width / 2
                            color: "#08080a"
                        }
                        Lobes { r: housing.lobeR + 4; fill: "#08080a" }
                    }

                    Item {
                        id: hmask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.centerIn: parent
                            width: 2 * housing.coreR; height: width; radius: width / 2
                        }
                        Lobes { r: housing.lobeR }
                    }
                    Image {
                        id: htex
                        anchors.fill: parent
                        source: "housing.png"
                        smooth: true; mipmap: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: htex
                        maskEnabled: true
                        maskSource: hmask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    Repeater {
                        model: 6
                        Item {
                            id: gap
                            required property int index
                            anchors.fill: parent
                            rotation: index * 60 + 30

                            Rectangle {
                                id: screw
                                width: 11; height: 11; radius: 5.5
                                x: parent.width / 2 - width / 2
                                y: parent.height / 2 - 226 - height / 2
                                border.color: "#050506"; border.width: 1
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "#9a9aa2" }
                                    GradientStop { position: 0.55; color: "#4a4a50" }
                                    GradientStop { position: 1; color: "#2a2a2e" }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 7; height: 1.6; radius: 0.8
                                    color: "#16161a"
                                    rotation: gap.index * 47 + 15
                                }
                            }

                            Repeater {
                                model: [-5, 5]
                                Item {
                                    required property real modelData
                                    x: parent.width / 2 + modelData - 1.5
                                    y: parent.height / 2 - 195
                                    width: 3; height: 32
                                    Rectangle { anchors.fill: parent; radius: 1.5; color: "#050506" }
                                    Rectangle {
                                        anchors.left: parent.right
                                        width: 1; height: parent.height; radius: 0.5
                                        color: "#34343a"
                                    }
                                }
                            }

                            Item {
                                x: parent.width / 2 - 6
                                y: parent.height / 2 - 134 - 6
                                width: 12; height: 12
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 7; height: 7; radius: 3.5
                                    color: "#050506"
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: root.selAccent
                                    opacity: 0.22
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 4.5; height: 4.5; radius: 2.25
                                    color: Qt.lighter(root.selAccent, 1.25)
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: 6
                    delegate: Item {
                        id: slot
                        required property int index
                        readonly property int offset: { let d = ((index - root.sel) % 6 + 6) % 6; return d > 3 ? d - 6 : d }
                        readonly property int item: root.count ? root.wrap(root.sel + offset) : 0
                        readonly property bool active: offset === 0
                        readonly property real a: index * Math.PI / 3

                        width: disc.slotD; height: disc.slotD
                        x: disc.width / 2 + disc.ringR * Math.sin(a) - width / 2
                        y: disc.height / 2 - disc.ringR * Math.cos(a) - height / 2
                        z: active ? 2 : 1

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 26; height: width; radius: width / 2
                            color: "#151517"
                            border.color: "#2e2e33"; border.width: 3
                        }

                        Item {
                            anchors.fill: parent
                            rotation: -ring.rotation
                            scale: hover.containsMouse ? (slot.active ? 1.16 : 1.12) : (slot.active ? 1.08 : 1)
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }

                            readonly property color acc: (root.walls[slot.item] || { acc: "#e6e6ea" }).acc
                            readonly property real lit: slot.active ? 1 : hover.containsMouse ? 0.85 : 0

                            Image {
                                id: bezel
                                anchors.centerIn: parent
                                width: parent.width + 22; height: width
                                source: "bezel.png"
                                smooth: true; mipmap: true
                                opacity: parent.lit
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }

                            Image {
                                id: img
                                anchors.fill: parent
                                source: root.walls[slot.item] ? "file://" + root.walls[slot.item].thumb : ""
                                sourceSize: Qt.size(300, 300)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: false
                            }
                            Rectangle { id: mask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                            MultiEffect {
                                anchors.fill: parent
                                source: img
                                maskEnabled: true
                                maskSource: mask
                                brightness: slot.active || hover.containsMouse ? 0 : -0.25
                                Behavior on brightness { NumberAnimation { duration: 200 } }
                                opacity: img.status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 3; height: width; radius: width / 2
                                color: "transparent"
                                border.color: "#e6000000"; border.width: 2.5
                                opacity: bezel.opacity
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 23; height: width; radius: width / 2
                                color: "transparent"
                                border.color: parent.acc; border.width: 1.5
                                opacity: bezel.opacity * 0.9
                                Behavior on border.color { ColorAnimation { duration: 300 } }
                            }

                            Item {
                                id: deco
                                anchors.centerIn: parent
                                width: parent.width + 62; height: width
                                opacity: slot.active ? 1 : 0
                                scale: slot.active ? 1 : 0.82
                                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                readonly property color acc: parent.acc

                                Canvas {
                                    id: dial
                                    anchors.fill: parent
                                    antialiasing: true
                                    onPaint: {
                                        const c = getContext("2d")
                                        c.reset()
                                        const m = width / 2, R = m - 3
                                        c.lineCap = "round"
                                        for (let i = 0; i < 72; i++) {
                                            const major = i % 6 === 0
                                            const a = i * Math.PI / 36
                                            const r0 = R - (major ? 8 : 3.5)
                                            c.strokeStyle = major ? "rgba(235,235,240,0.8)" : "rgba(235,235,240,0.3)"
                                            c.lineWidth = major ? 2 : 1.2
                                            c.beginPath()
                                            c.moveTo(m + r0 * Math.sin(a), m - r0 * Math.cos(a))
                                            c.lineTo(m + R * Math.sin(a), m - R * Math.cos(a))
                                            c.stroke()
                                        }
                                    }
                                    RotationAnimator on rotation { from: 0; to: 360; duration: 48000; loops: Animation.Infinite; running: slot.active }
                                }

                                Item {
                                    anchors.fill: parent
                                    RotationAnimator on rotation { from: 360; to: 0; duration: 16000; loops: Animation.Infinite; running: slot.active }

                                    Shape {
                                        id: arcs
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true
                                        layer.samples: 4
                                        preferredRendererType: Shape.CurveRenderer
                                        component Arc: ShapePath {
                                            property real start
                                            property real sweep
                                            property real r
                                            property real w: 3
                                            strokeColor: deco.acc
                                            strokeWidth: w
                                            fillColor: "transparent"
                                            capStyle: ShapePath.RoundCap
                                            PathAngleArc { centerX: arcs.width / 2; centerY: arcs.height / 2; radiusX: r; radiusY: r; startAngle: start; sweepAngle: sweep }
                                        }
                                        Arc { start: -160; sweep: 110; r: 92 }
                                        Arc { start: 20; sweep: 110; r: 92 }
                                        Arc { start: -38; sweep: 8; r: 92; w: 2 }
                                        Arc { start: 142; sweep: 8; r: 92; w: 2 }
                                    }
                                    MultiEffect {
                                        anchors.fill: arcs
                                        source: arcs
                                        shadowEnabled: true
                                        shadowColor: deco.acc
                                        shadowBlur: 0.9
                                        shadowOpacity: 0.95
                                        shadowHorizontalOffset: 0
                                        shadowVerticalOffset: 0
                                        blurMax: 32
                                    }
                                }

                                Shape {
                                    id: pointer
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: -15
                                    width: 18; height: 11
                                    visible: false
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        fillColor: deco.acc
                                        strokeColor: "transparent"
                                        startX: 0; startY: 0
                                        PathLine { x: 18; y: 0 }
                                        PathLine { x: 9; y: 11 }
                                        PathLine { x: 0; y: 0 }
                                    }
                                }
                                MultiEffect {
                                    anchors.fill: pointer
                                    source: pointer
                                    shadowEnabled: true
                                    shadowColor: deco.acc
                                    shadowBlur: 0.7
                                    shadowHorizontalOffset: 0
                                    shadowVerticalOffset: 0
                                    blurMax: 20
                                }
                            }
                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: slot.active ? root.apply() : root.sel += slot.offset
                            }
                        }
                    }
                }
            }

            Image {
                anchors.centerIn: parent
                width: 230; height: 230
                source: "bezel.png"
                smooth: true; mipmap: true

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 34; height: width; radius: width / 2
                    color: "transparent"
                    border.color: "#141414"; border.width: 4

                    Image { anchors.fill: parent; z: -1; source: "face.png"; smooth: true; mipmap: true }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 9
                        radius: width / 2
                        color: "transparent"
                        border.color: root.selAccent; border.width: 1
                        opacity: 0.45
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 24
                        text: root.themes.length ? "THEME " + (root.ti + 1) + "/" + root.themes.length : ""
                        color: "#6e6e74"
                        font { family: "JetBrains Mono"; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 }
                    }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 30
                        spacing: 4
                        z: 1
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: root.count ? root.stem(root.walls[root.wrap(root.sel)].path).replace(/[_-]+/g, " ").toUpperCase() : "…"
                            color: "white"
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 12
                            font { family: "JetBrains Mono"; pixelSize: 26; weight: Font.ExtraBold }
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: "‹ " + root.themeName.toUpperCase() + " ›"
                            color: themeHover.containsMouse ? Qt.lighter(root.selAccent, 1.3) : root.selAccent
                            Behavior on color { ColorAnimation { duration: 300 } }
                            font { family: "JetBrains Mono"; pixelSize: 11; weight: Font.Bold; letterSpacing: 2 }
                            MouseArea {
                                id: themeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: m => root.switchTheme(m.x < width / 2 ? -1 : 1)
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 20
                        text: root.count ? (root.wrap(root.sel) + 1) + " / " + root.count : ""
                        color: "#8a8a90"
                        font { family: "JetBrains Mono"; pixelSize: 11 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.apply() }
                }
            }
        }
        }
    }
}
