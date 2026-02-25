import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "tz-list.js" as TzList

PluginComponent {
    id: root

    // ── Persisted settings ──────────────────────────────────────────
    property var timezones: []        // [{timezone: "Europe/Berlin", label: "Berlin"}, ...]
    property bool showAll: true       // true = all at once, false = cycle one at a time
    property int cycleInterval: 15    // seconds between cycling (when showAll == false)
    property bool use24h: true        // 24-hour format

    // ── Runtime state ───────────────────────────────────────────────
    property int currentIndex: 0
    property bool isLoading: true
    property var timeMap: ({})        // {"Europe/Budapest": "14:30", ...}

    // ── Clock source (drives the refresh) ───────────────────────────
    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
        onDateChanged: root.refreshTimes()
    }

    // ── Load settings from plugin data ──────────────────────────────
    function loadSettings() {
        if (!pluginService || !pluginService.loadPluginData) return;

        var saved = pluginService.loadPluginData(pluginId, "timezones", []);
        timezones = (saved && Array.isArray(saved)) ? saved : [];

        showAll = pluginService.loadPluginData(pluginId, "showAll", true) !== false;
        cycleInterval = pluginService.loadPluginData(pluginId, "cycleInterval", 15) || 15;
        use24h = pluginService.loadPluginData(pluginId, "use24h", true) !== false;

        // Restore which clock we were showing
        var savedIdx = pluginService.loadPluginState(pluginId, "currentIndex", 0);
        currentIndex = (savedIdx >= 0 && savedIdx < timezones.length) ? savedIdx : 0;

        isLoading = false;
    }

    Component.onCompleted: loadSettings()

    // Re-read settings periodically so the bar picks up changes from
    // the settings UI without a full restart.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: loadSettings()
    }

    // ── Fetch times via shell ───────────────────────────────────────
    // Builds a single command like:
    //   echo "Europe/Budapest=$(TZ=Europe/Budapest date +%H:%M)"; echo ...
    // and parses the output into timeMap.

    property string _pendingOutput: ""

    function refreshTimes() {
        if (timezones.length === 0) return;
        var fmt = use24h ? "%H:%M" : "%I:%M %p";
        var parts = [];
        for (var i = 0; i < timezones.length; i++) {
            var tz = timezones[i].timezone;
            parts.push("echo \"" + tz + "=$(TZ='" + tz + "' date +'"+fmt+"')\"");
        }
        timeProc.command = ["bash", "-c", parts.join("; ")];
        _pendingOutput = "";
        timeProc.running = true;
    }

    Process {
        id: timeProc
        running: false
        stdout: SplitParser {
            onRead: data => {
                root._pendingOutput += data + "\n";
            }
        }
        onExited: {
            var newMap = {};
            var lines = root._pendingOutput.trim().split("\n");
            for (var i = 0; i < lines.length; i++) {
                var eq = lines[i].indexOf("=");
                if (eq > 0) {
                    newMap[lines[i].substring(0, eq)] = lines[i].substring(eq + 1);
                }
            }
            root.timeMap = newMap;
        }
    }

    // ── Cycle timer (only active in single-clock mode) ──────────────
    Timer {
        id: cycleTimer
        interval: root.cycleInterval * 1000
        running: !root.showAll && root.timezones.length > 1
        repeat: true
        onTriggered: {
            root.currentIndex = (root.currentIndex + 1) % root.timezones.length;
            if (pluginService && pluginService.savePluginState) {
                pluginService.savePluginState(pluginId, "currentIndex", root.currentIndex);
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────
    function formatTime(tz) {
        return root.timeMap[tz] || "...";
    }

    function labelFor(entry) {
        return (entry && entry.label) ? entry.label : TzList.cityFromTz(entry.timezone);
    }

    function entryText(entry) {
        return labelFor(entry) + " " + formatTime(entry.timezone);
    }

    // ── Model for the bar: either all timezones or just the current one
    function visibleModel() {
        if (timezones.length === 0) return [];
        if (showAll) return timezones;
        var idx = Math.min(currentIndex, timezones.length - 1);
        return [timezones[idx]];
    }

    // ── Horizontal bar pill ─────────────────────────────────────────
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            Repeater {
                model: root.visibleModel()

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    // Separator dot between entries (not before the first)
                    StyledText {
                        text: "\u00B7"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.withAlpha(Theme.surfaceText, 0.4)
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root.entryText(modelData)
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Fallback when nothing is configured
            StyledText {
                text: "World Clock"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isLoading && root.timezones.length === 0
            }
        }
    }

    // ── Vertical bar pill ───────────────────────────────────────────
    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            Repeater {
                model: root.visibleModel()

                Column {
                    spacing: 1
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: root.labelFor(modelData)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: root.formatTime(modelData.timezone)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // ── Popout panel (click to expand) ──────────────────────────────
    popoutContent: Component {
        Column {
            spacing: Theme.spacingL

            StyledText {
                text: "World Clock"
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            // Display mode indicator
            StyledText {
                text: root.showAll
                    ? "Showing all clocks"
                    : "Cycling every " + root.cycleInterval + "s"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: root.timezones

                    StyledRect {
                        width: parent.width
                        height: 64
                        radius: Theme.cornerRadius
                        color: (root.currentIndex === index && !root.showAll)
                            ? Theme.withAlpha(Theme.primary, 0.15)
                            : Theme.surfaceContainerHigh

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingL
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: root.labelFor(modelData)
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: modelData.timezone
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        StyledText {
                            text: root.formatTime(modelData.timezone)
                            color: Theme.primary
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Font.Bold
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingL
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Empty state
                StyledText {
                    text: "No timezones configured.\nAdd some in plugin settings."
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    visible: !root.isLoading && root.timezones.length === 0
                }
            }
        }
    }

    popoutWidth: 380
    popoutHeight: 420
}
