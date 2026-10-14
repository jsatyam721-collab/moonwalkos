import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property bool dryRun: Quickshell.env("POWER_DRYRUN") === "1"
    readonly property bool noInput: Quickshell.env("POWER_NOINPUT") === "1"
    readonly property var items: [
        { key: "l", label: "Lock", icon: "lock", cmd: "moonwalk-shell lockscreen.sh" },
        { key: "e", label: "Logout", icon: "logout", cmd: root.home + "/.local/bin/crt-logout" },
        { key: "u", label: "Suspend", icon: "suspend", cmd: "moonwalk-shell lockscreen.sh & sleep 1; systemctl suspend" },
        { key: "r", label: "Reboot", icon: "reboot", cmd: "systemctl reboot" },
        { key: "s", label: "Shutdown", icon: "shutdown", cmd: "systemctl poweroff" }
    ]

    property bool shown: false
    property real reveal: 0
    property int sel: 0
    property int fired: -1
    property string pending: ""
    signal opened()

    function show() {
        if (shown) return
        sel = 0
        fired = -1
        pending = ""
        shown = true
        closeAnim.stop()
        openAnim.restart()
    }

    function hide() {
        if (!shown || closeAnim.running) return
        openAnim.stop()
        closeAnim.restart()
    }

    function toggle() { shown ? hide() : show() }

    function activate(i) {
        if (!shown || fired >= 0 || closeAnim.running) return
        sel = i
        fired = i
        pending = items[i].cmd
        flash.restart()
    }

    function step(d) { sel = (sel + d + items.length) % items.length }

    SequentialAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "reveal"; to: 1; duration: 460 }
        ScriptAction { script: root.opened() }
    }

    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "reveal"; to: 0; duration: 220; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                root.shown = false
                if (root.pending !== "") runTimer.restart()
            }
        }
    }

    SequentialAnimation {
        id: flash
        PauseAnimation { duration: 170 }
        ScriptAction { script: root.hide() }
    }

    Timer {
        id: runTimer
        interval: 90
        onTriggered: {
            var cmd = root.pending
            root.pending = ""
            if (root.dryRun) console.log("POWER would run:", cmd)
            else Quickshell.execDetached(["sh", "-c", cmd])
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function press(i: int): void { root.activate(i) }
        function select(i: int): void { root.sel = i }
    }

    Component.onCompleted: if (Quickshell.env("POWER_SHOW") === "1") show()

    PanelWindow {
        id: win
        visible: true
        anchors { top: true; left: true; bottom: root.shown; right: root.shown }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "moonwalk-power"
        WlrLayershell.keyboardFocus: root.shown && !root.noInput ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: (!root.shown || root.noInput) ? noRegion : null
        Region { id: noRegion }

        readonly property real hh: height
        readonly property real ts: hh * 0.222
        readonly property real gap: hh * 0.031
        readonly property real rowW: ts * 5 + gap * 4
        readonly property real rowX: (width - rowW) / 2
        readonly property real rowY: hh * 0.553

        Item {
            id: stage
            anchors.fill: parent
            visible: root.shown
            focus: root.shown

            Keys.onPressed: function (e) {
                var t = e.text.toLowerCase()
                for (var i = 0; i < root.items.length; i++)
                    if (t === root.items[i].key) { root.activate(i); e.accepted = true; return }
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Q) root.hide()
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab || e.key === Qt.Key_Down) root.step(1)
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab || e.key === Qt.Key_Up) root.step(-1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.activate(root.sel)
                else return
                e.accepted = true
            }

            Image {
                id: backdrop
                anchors.fill: parent
                source: "art/backdrop.png"
                fillMode: Image.PreserveAspectCrop
                opacity: Math.min(1, root.reveal * 2.2)
                smooth: true
                asynchronous: false
            }

            Item {
                id: fogLayer
                x: 0
                y: win.hh * 0.36
                width: parent.width
                height: win.hh * 0.42
                clip: true
                opacity: 0.55 * backdrop.opacity
                property real drift: 0
                NumberAnimation on drift {
                    from: 0; to: 1; duration: 70000; loops: Animation.Infinite
                    running: root.shown
                }
                Row {
                    x: -fogLayer.drift * fogLayer.width
                    Repeater {
                        model: 2
                        Image {
                            source: "art/fog.png"
                            width: fogLayer.width
                            height: fogLayer.height
                            smooth: true
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            Repeater {
                model: root.items

                Item {
                    id: tile
                    required property int index
                    required property var modelData
                    readonly property bool lit: root.sel === index
                    readonly property string kind: modelData.icon
                    readonly property real appear: {
                        var t = Math.max(0, Math.min(1, (root.reveal * 460 - 120 - index * 45) / 230))
                        return 1 - Math.pow(1 - t, 3)
                    }
                    property real glow: lit ? 1 : 0
                    property real lift: lit ? 1 : 0
                    property real burst: root.fired === index ? 1 : 0
                    property real press: 0
                    property real breath: 1
                    Behavior on glow { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on lift { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on burst { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    x: win.rowX + index * (win.ts + win.gap)
                    y: win.rowY + (1 - appear) * win.hh * 0.06
                    width: win.ts
                    height: win.ts
                    opacity: appear
                    z: lit ? 2 : 1

                    function play() {
                        ripple.restart()
                        sweep.restart()
                        if (kind === "lock") tipHat.restart()
                        else if (kind === "logout") glide.restart()
                        else if (kind === "suspend") rock.restart()
                        else if (kind === "reboot") spin.restart()
                        else if (kind === "shutdown") wave.restart()
                    }

                    onLitChanged: if (lit && root.shown && root.reveal > 0.5) play()
                    Connections {
                        target: root
                        function onOpened() { if (tile.lit) tile.play() }
                        function onFiredChanged() { if (root.fired === tile.index) pressAnim.restart() }
                    }

                    SequentialAnimation on breath {
                        running: tile.lit && root.shown
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.78; duration: 1300; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1300; easing.type: Easing.InOutSine }
                    }

                    SequentialAnimation {
                        id: pressAnim
                        NumberAnimation { target: tile; property: "press"; to: 1; duration: 70; easing.type: Easing.OutCubic }
                        NumberAnimation { target: tile; property: "press"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    }

                    Image {
                        id: rippleImg
                        source: "art/glow.png"
                        anchors.centerIn: parent
                        width: win.ts
                        height: width
                        opacity: 0
                        smooth: true
                        ParallelAnimation {
                            id: ripple
                            NumberAnimation { target: rippleImg; property: "width"; from: win.ts * 1.1; to: win.ts * 4.2; duration: 700; easing.type: Easing.OutCubic }
                            NumberAnimation { target: rippleImg; property: "opacity"; from: 0.7; to: 0; duration: 700; easing.type: Easing.OutQuad }
                        }
                    }

                    Image {
                        source: "art/glow.png"
                        width: win.ts * (3.0 + tile.burst * 0.8)
                        height: width
                        anchors.centerIn: parent
                        opacity: tile.glow * 0.85 * tile.breath + tile.burst * 0.15
                        smooth: true
                    }

                    Item {
                        id: face
                        width: parent.width
                        height: parent.height
                        y: -tile.lift * win.ts * 0.05 + tile.press * win.ts * 0.03
                        scale: 1 + tile.lift * 0.045 - tile.press * 0.07

                        Item {
                            id: glass
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: tileMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }
                            Image {
                                source: "art/glass.png"
                                x: -tile.x
                                y: -win.rowY
                                width: win.width
                                height: win.hh
                                smooth: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#3cffffff" }
                                    GradientStop { position: 1.0; color: "#1affffff" }
                                }
                            }
                        }

                        Rectangle {
                            id: tileMask
                            anchors.fill: parent
                            radius: win.ts * 0.045
                            visible: false
                            layer.enabled: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: win.ts * 0.045
                            color: Qt.rgba(0.98, 0.945, 0.865, 1)
                            opacity: Math.min(1, tile.glow + tile.burst)
                        }

                        Item {
                            anchors.fill: parent
                            clip: true
                            Rectangle {
                                id: glint
                                width: win.ts * 0.32
                                height: win.ts * 2.2
                                y: -win.ts * 0.6
                                x: -win.ts
                                rotation: 24
                                opacity: 0
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#00ffffff" }
                                    GradientStop { position: 0.5; color: "#f0ffffff" }
                                    GradientStop { position: 1.0; color: "#00ffffff" }
                                }
                                SequentialAnimation {
                                    id: sweep
                                    PropertyAction { target: glint; property: "opacity"; value: 1 }
                                    NumberAnimation { target: glint; property: "x"; from: -win.ts * 0.7; to: win.ts * 1.3; duration: 560; easing.type: Easing.InOutCubic }
                                    PropertyAction { target: glint; property: "opacity"; value: 0 }
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: win.ts * 0.045
                            color: "transparent"
                            border.width: Math.max(1, win.ts * 0.012)
                            border.color: tile.lit ? "#fffaf0" : "#70ffffff"
                        }

                        Item {
                            id: iconBox
                            width: win.ts * 0.74
                            height: width
                            property real dx: 0
                            property real dy: 0
                            x: (parent.width - width) / 2 + dx
                            y: (parent.height - height) / 2 + dy
                            transformOrigin: (tile.kind === "lock" || tile.kind === "shutdown") ? Item.Bottom : Item.Center

                            Image {
                                anchors.fill: parent
                                source: "icons/" + tile.modelData.icon + ".png"
                                smooth: true
                                mipmap: true
                                opacity: tile.lit ? 1 : 0.88
                            }

                            SequentialAnimation {
                                id: tipHat
                                ParallelAnimation {
                                    NumberAnimation { target: iconBox; property: "rotation"; to: -14; duration: 190; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: iconBox; property: "dy"; to: -win.ts * 0.05; duration: 190; easing.type: Easing.OutCubic }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: iconBox; property: "rotation"; to: 4; duration: 220; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: iconBox; property: "dy"; to: 0; duration: 380; easing.type: Easing.OutCubic }
                                }
                                NumberAnimation { target: iconBox; property: "rotation"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                            }

                            SequentialAnimation {
                                id: glide
                                NumberAnimation { target: iconBox; property: "dx"; to: -win.ts * 0.08; duration: 420; easing.type: Easing.InOutSine }
                                NumberAnimation { target: iconBox; property: "dx"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                            }

                            SequentialAnimation {
                                id: rock
                                ParallelAnimation {
                                    NumberAnimation { target: iconBox; property: "rotation"; to: -16; duration: 320; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: iconBox; property: "scale"; to: 1.07; duration: 320; easing.type: Easing.InOutSine }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: iconBox; property: "rotation"; to: 6; duration: 320; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: iconBox; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.InOutSine }
                                }
                                NumberAnimation { target: iconBox; property: "rotation"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                            }

                            SequentialAnimation {
                                id: spin
                                NumberAnimation { target: iconBox; property: "rotation"; from: 0; to: 360; duration: 720; easing.type: Easing.OutCubic }
                                PropertyAction { target: iconBox; property: "rotation"; value: 0 }
                            }

                            SequentialAnimation {
                                id: wave
                                NumberAnimation { target: iconBox; property: "rotation"; to: -12; duration: 150; easing.type: Easing.OutSine }
                                NumberAnimation { target: iconBox; property: "rotation"; to: 10; duration: 170; easing.type: Easing.InOutSine }
                                NumberAnimation { target: iconBox; property: "rotation"; to: -6; duration: 150; easing.type: Easing.InOutSine }
                                NumberAnimation { target: iconBox; property: "rotation"; to: 0; duration: 170; easing.type: Easing.OutSine }
                            }
                        }
                    }

                    Text {
                        text: tile.modelData.label
                        anchors.top: parent.bottom
                        anchors.topMargin: win.hh * 0.03
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: tile.lit ? "#fffaf0" : "#e6e0d6"
                        font.family: "Noto Serif"
                        font.weight: Font.Bold
                        font.pixelSize: win.hh * 0.043
                        style: Text.Raised
                        styleColor: "#66000000"
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = tile.index
                        onClicked: root.activate(tile.index)
                    }
                }
            }
        }
    }
}
