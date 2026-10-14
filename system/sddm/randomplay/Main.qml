import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtMultimedia

Rectangle {
    id: root
    color: "black"
    width: Screen.width
    height: Screen.height

    readonly property string font: "JetBrains Mono"
    readonly property color vfd: "#8ef3ff"
    property string user: userModel.lastUser || firstUser
    property string firstUser: ""
    property int session: sessionModel.lastIndex
    property var sessions: []
    property bool busy: false
    property real power: 0
    property real glitch: 0
    property string flash: ""
    property real zoom: 1
    readonly property real zoomE: zoom < 0.5 ? 4 * zoom * zoom * zoom : 1 - Math.pow(-2 * zoom + 2, 3) / 2
    property bool menuOpen: false
    property int menuSel: 0
    readonly property var menu: {
        const m = []
        if (sddm.canPowerOff) m.push({ label: "POWER OFF", run: () => sddm.powerOff() })
        if (sddm.canReboot) m.push({ label: "REBOOT", run: () => sddm.reboot() })
        if (sddm.canSuspend) m.push({ label: "SUSPEND", run: () => sddm.suspend() })
        m.push({ label: "CANCEL", run: () => root.menuOpen = false })
        return m
    }

    function say(msg, ms) {
        flash = msg
        flashTimer.interval = ms || 2200
        flashTimer.restart()
    }
    function submit() {
        if (busy) return
        if (!pw.text.length) return say("INSERT PASSWORD", 1600)
        busy = true
        led.state = "busy"
        powerOff.start()
        sddm.login(user, pw.text, session)
    }
    function stepSession(d) {
        if (!sessions.length) return
        session = (session + d + sessions.length) % sessions.length
        knob.turns += d
        say("INPUT  " + sessions[session].toUpperCase(), 1800)
    }

    Timer { id: flashTimer; onTriggered: root.flash = "" }

    Instantiator {
        model: userModel
        delegate: QtObject {
            required property int index
            required property string name
            Component.onCompleted: if (index === 0) root.firstUser = name
        }
    }

    Instantiator {
        model: sessionModel
        delegate: QtObject {
            required property int index
            required property string name
            Component.onCompleted: { const s = root.sessions.slice(); s[index] = name; root.sessions = s }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            pw.text = ""
            led.state = "fail"
            powerOff.stop()
            fail.restart()
            root.say("ACCESS DENIED", 2600)
        }
        function onLoginSucceeded() {
            led.state = "ok"
        }
    }

    NumberAnimation { id: powerOn; target: root; property: "power"; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
    NumberAnimation { id: powerOff; target: root; property: "power"; to: 0; duration: 520; easing.type: Easing.InCubic }
    ParallelAnimation {
        id: fail
        NumberAnimation { target: root; property: "power"; to: 1; duration: 380; easing.type: Easing.OutCubic }
        SequentialAnimation {
            NumberAnimation { target: root; property: "glitch"; from: 1; to: 0.35; duration: 500 }
            NumberAnimation { target: root; property: "glitch"; to: 0; duration: 700; easing.type: Easing.OutQuad }
        }
    }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 350 }
        ScriptAction { script: powerOn.start() }
        PauseAnimation { duration: 1250 }
        NumberAnimation { target: root; property: "zoom"; to: 0; duration: 1700; easing.type: Easing.Linear }
    }

    MediaPlayer {
        id: player
        source: Qt.resolvedUrl("tv.mp4")
        videoOutput: vo
        loops: MediaPlayer.Infinite
        Component.onCompleted: play()
    }

    Item {
        id: cam
        anchors.fill: parent
        readonly property real k: scene.scale
        readonly property point tv: Qt.point(root.width / 2 + 0.1 * k, root.height / 2 - 33 * k)
        readonly property real full: Math.max(root.width / (689 * k), root.height / (510 * k)) * 1.06
        transform: [
            Scale { origin.x: cam.tv.x; origin.y: cam.tv.y; xScale: 1 + (cam.full - 1) * root.zoomE; yScale: 1 + (cam.full - 1) * root.zoomE },
            Translate { x: (root.width / 2 - cam.tv.x) * root.zoomE; y: (root.height / 2 - cam.tv.y) * root.zoomE }
        ]

    Item {
        id: scene
        width: 1920
        height: 1078
        anchors.centerIn: parent
        scale: Math.max(root.width / width, root.height / height)

        Image { anchors.fill: parent; source: "room.png"; smooth: true; mipmap: true; opacity: 1 - 0.94 * root.zoomE }

        VideoOutput {
            id: vo
            width: 640; height: 360
            fillMode: VideoOutput.Stretch
            visible: true
            opacity: 0
        }
        ShaderEffectSource { id: vidTex; sourceItem: vo; hideSource: true; live: true; smooth: true }

        Item {
            id: osd
            width: 640; height: 480
            visible: true
            opacity: 0

            component Osd: Text {
                color: "#f4f4f0"
                font { family: root.font; pixelSize: 30; weight: Font.ExtraBold; letterSpacing: 1 }
                style: Text.Outline
                styleColor: "#111111"
            }

            Osd {
                x: 58; y: 44
                text: (blink.on ? "▶" : " ") + " PLAY"
            }
            Osd {
                anchors.right: parent.right; anchors.rightMargin: 58; y: 44
                horizontalAlignment: Text.AlignRight
                text: Qt.formatTime(clock.now, "AP h:mm").replace(/\s+/, " ")
            }
            Osd {
                anchors.right: parent.right; anchors.rightMargin: 58; y: 82
                font.pixelSize: 22
                text: Qt.formatDate(clock.now, "MMM.dd yyyy").toUpperCase()
            }
            Osd {
                x: 58; y: 82
                font.pixelSize: 22
                visible: keyboard.capsLock
                text: "CAPS"
            }
            Osd {
                x: 58; anchors.bottom: parent.bottom; anchors.bottomMargin: 40
                font.pixelSize: 24
                text: "SP " + (() => {
                    const s = Math.floor(player.position / 1000)
                    return Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                })()
            }
            Osd {
                anchors.right: parent.right; anchors.rightMargin: 58; anchors.bottom: parent.bottom; anchors.bottomMargin: 40
                font.pixelSize: 24
                text: "CH " + root.user.toUpperCase()
            }
            Osd {
                anchors.centerIn: parent
                visible: root.flash !== "" && !root.menuOpen
                font.pixelSize: 40
                text: root.flash
            }
            Column {
                anchors.centerIn: parent
                visible: root.menuOpen
                spacing: 10
                Osd { text: "- POWER -"; font.pixelSize: 26; anchors.horizontalCenter: parent.horizontalCenter }
                Repeater {
                    model: root.menu
                    Osd {
                        required property var modelData
                        required property int index
                        font.pixelSize: 34
                        text: (index === root.menuSel ? "▶ " : "  ") + modelData.label
                    }
                }
            }
        }
        ShaderEffectSource {
            id: osdTex
            sourceItem: osd
            hideSource: true
            live: true
            smooth: false
            textureSize: Qt.size(320, 240)
        }

        ShaderEffect {
            id: crt
            x: 960.1 - 344.5; y: 506 - 255
            width: 689; height: 510
            property variant source: vidTex
            property variant osd: osdTex
            property real time: 0
            property real power: root.power
            property real glitch: root.glitch
            property real shapeN: 6.9
            property size size: Qt.size(width, height)
            property size vidScale: Qt.size((width / height) / (16 / 9), 1)
            fragmentShader: "crt.frag.qsb"
            FrameAnimation { running: true; onTriggered: crt.time += frameTime }
        }

        Item {
            x: 852; y: 927; width: 541; height: 46
            opacity: 1 - root.zoomE

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "#04090b"
                opacity: pw.activeFocus ? 0.7 : 0.45
                border.color: Qt.rgba(0.55, 0.95, 1, pw.activeFocus ? 0.18 : 0.06)
                border.width: 1
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            Item {
                id: vfdText
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.vfd
                    shadowBlur: 0.6
                    shadowOpacity: 0.85
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 16
                }

                TextInput {
                    id: pw
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    focus: true
                    echoMode: TextInput.Password
                    passwordCharacter: "■"
                    passwordMaskDelay: 0
                    color: root.vfd
                    selectionColor: "transparent"
                    cursorVisible: false
                    cursorDelegate: Item {}
                    font { family: root.font; pixelSize: 20; weight: Font.Bold; letterSpacing: 7 }
                    onAccepted: root.submit()
                    onTextChanged: if (led.state === "fail") led.state = ""
                    Keys.onPressed: e => {
                        if (root.menuOpen) {
                            e.accepted = true
                            if (e.key === Qt.Key_Up) root.menuSel = (root.menuSel - 1 + root.menu.length) % root.menu.length
                            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) root.menuSel = (root.menuSel + 1) % root.menu.length
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.menu[root.menuSel].run()
                            else if (e.key === Qt.Key_Escape) root.menuOpen = false
                        } else if (e.key === Qt.Key_Escape) {
                            pw.text = ""
                            e.accepted = true
                        } else if (e.key === Qt.Key_F1 || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ControlModifier))) {
                            root.stepSession(1)
                            e.accepted = true
                        }
                    }
                }

                Text {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !pw.text.length
                    text: "INSERT PASSWORD"
                    color: root.vfd
                    opacity: 0.32
                    font { family: root.font; pixelSize: 17; weight: Font.Bold; letterSpacing: 5 }
                }

                Rectangle {
                    x: pw.text.length ? pw.cursorRectangle.x + 3 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenterOffset: 0
                    width: 11; height: 20
                    color: root.vfd
                    visible: pw.activeFocus && blink.on && !root.busy
                }
            }
        }

        Item {
            x: 690; y: 915; width: 70; height: 50
            opacity: 1 - root.zoomE
            Rectangle {
                x: 25; y: 15; width: 20; height: 20; radius: 10
                color: "#7dff6a"
                opacity: pwrArea.containsMouse ? 0.55 : breathe.v * 0.32
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 24 }
            }
            MouseArea {
                id: pwrArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.menuOpen = !root.menuOpen; root.menuSel = 0; pw.forceActiveFocus() }
            }
        }

        Item {
            x: 1446; y: 911; width: 78; height: 78
            opacity: 1 - root.zoomE
            Rectangle {
                anchors.centerIn: parent
                width: 34; height: 34; radius: 17
                color: root.vfd
                opacity: pw.text.length ? 0.22 + breathe.v * 0.12 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 32 }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 6
                color: playArea.pressed ? "#000000" : "#ffffff"
                opacity: playArea.pressed ? 0.28 : playArea.containsMouse ? 0.05 : 0
            }
            MouseArea {
                id: playArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.submit(); pw.forceActiveFocus() }
            }
        }

        Image {
            id: knob
            opacity: 1 - root.zoomE
            x: 733; y: 1008; width: 34; height: 34
            source: "knob.png"
            smooth: true; mipmap: true
            property int turns: 0
            rotation: turns * 45
            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.stepSession(1); pw.forceActiveFocus() }
                onWheel: w => root.stepSession(w.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Rectangle {
            id: led
            x: 1322; y: 1027; width: 6; height: 6; radius: 3
            property string state: ""
            color: state === "fail" ? "#ff3b3b" : state === "ok" ? "#6dff7a" : root.vfd
            opacity: (1 - root.zoomE) * (state === "fail" ? (blink.on ? 1 : 0.15) : state === "busy" ? (blink.fast ? 1 : 0.3) : state === "ok" ? 1 : (pw.text.length ? 0.9 : 0))
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: led.color; shadowBlur: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12 }
        }

        MouseArea {
            x: crt.x; y: crt.y; width: crt.width; height: crt.height
            enabled: root.menuOpen
            onClicked: m => {
                const rows = root.menu.length
                const top = height / 2 - (rows * 44 + 36) / 2 * (height / 480) + 36 * (height / 480)
                const i = Math.floor((m.y - top) / (44 * height / 480))
                if (i >= 0 && i < rows) { root.menuSel = i; root.menu[i].run() }
                pw.forceActiveFocus()
            }
        }
    }
    }

    Rectangle {
        id: fadeIn
        anchors.fill: parent
        color: "black"
        NumberAnimation on opacity { from: 1; to: 0; duration: 300; easing.type: Easing.InOutQuad }
        onOpacityChanged: if (opacity === 0) visible = false
    }

    QtObject {
        id: clock
        property date now: new Date()
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }

    QtObject {
        id: blink
        property bool on: true
        property bool fast: true
    }
    Timer { interval: 530; running: true; repeat: true; onTriggered: blink.on = !blink.on }
    Timer { interval: 160; running: true; repeat: true; onTriggered: blink.fast = !blink.fast }

    QtObject {
        id: breathe
        property real v: 0.5
        SequentialAnimation on v {
            loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.35; duration: 1800; easing.type: Easing.InOutSine }
        }
    }

    Component.onCompleted: pw.forceActiveFocus()
}
