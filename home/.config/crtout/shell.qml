import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root
    readonly property bool dryRun: Quickshell.env("CRT_DRYRUN") === "1"
    property real power: 1

    function finish() {
        if (dryRun) Qt.callLater(Qt.quit)
        else Quickshell.execDetached(["moonwalk-shell", "logout"])
    }

    NumberAnimation {
        id: off
        target: root; property: "power"
        from: 1; to: 0
        duration: 900
        easing.type: Easing.InQuad
        onFinished: root.finish()
    }
    Timer { interval: 6000; running: true; onTriggered: Qt.quit() }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "black"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "crtout"

        Image {
            id: shot
            anchors.fill: parent
            source: "file://" + Quickshell.env("XDG_RUNTIME_DIR") + "/crt-out.png"
            cache: false
            visible: false
            onStatusChanged: if (status === Image.Ready) off.start()
                             else if (status === Image.Error) root.finish()
        }
        ShaderEffect {
            anchors.fill: parent
            property variant source: shot
            property real power: root.power
            property size size: Qt.size(width, height)
            fragmentShader: "poweroff.frag.qsb"
        }
    }
}
