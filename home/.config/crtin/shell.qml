import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property real power: 0

    Process {
        running: true
        command: ["sh", "-c", `
            for i in $(seq 40); do
                case "$(hyprctl layers -j 2>/dev/null)" in *awww*) break ;; esac
                sleep 0.08
            done
            sleep 0.12
            echo go`]
        stdout: SplitParser { onRead: line => { if (line === "go") on.start() } }
    }

    NumberAnimation {
        id: on
        target: root; property: "power"
        from: 0; to: 1
        duration: 1150
        easing.type: Easing.OutQuad
        onFinished: Qt.callLater(Qt.quit)
    }
    Timer { interval: 9000; running: true; onTriggered: Qt.quit() }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "crtin"
        mask: Region {}

        ShaderEffect {
            anchors.fill: parent
            property real power: root.power
            property size size: Qt.size(width, height)
            fragmentShader: "poweron.frag.qsb"
        }
    }
}
