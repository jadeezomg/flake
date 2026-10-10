// GNOME-style type-to-search for the niri overview (Mod+Space).
// A see-through layer takes keyboard focus while the overview is open.
// The first typed text opens Vicinae with that text. Navigation keys
// go to niri. The layer quits when the overview closes.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    // Quit when the overview closes (window click, hot corner, Mod+Space).
    Process {
        running: true
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                const ev = JSON.parse(line).OverviewOpenedOrClosed;
                if (ev && !ev.is_open)
                    Qt.quit();
            }
        }
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "overview-catcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        TextInput {
            focus: true
            color: "transparent"
            onTextChanged: {
                // Close the overview once Vicinae closes (launch or Escape).
                Quickshell.execDetached(["sh", "-c", `
                    vicinae open -q "$1"; sleep 0.3
                    while vicinae state open && niri msg -j overview-state | grep -q '"is_open":true'; do sleep 0.15; done
                    vicinae close; niri msg action close-overview`, "sh", text]);
                Qt.quit();
            }
            Keys.onPressed: event => {
                const action = {
                    [Qt.Key_Left]: "focus-column-left",
                    [Qt.Key_Right]: "focus-column-right",
                    [Qt.Key_Up]: "focus-window-or-workspace-up",
                    [Qt.Key_Down]: "focus-window-or-workspace-down",
                    [Qt.Key_Return]: "close-overview",
                    [Qt.Key_Enter]: "close-overview",
                    [Qt.Key_Escape]: "close-overview"
                }[event.key];
                if (action) {
                    Quickshell.execDetached(["niri", "msg", "action", action]);
                    event.accepted = true;
                }
            }
        }
    }
}
