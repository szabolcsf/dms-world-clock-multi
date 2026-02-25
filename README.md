# World Clock Multi — DankMaterialShell Plugin

A DankBar widget that displays up to 5 timezones / cities. Supports two display modes:

- **Show all** — all configured clocks visible simultaneously on the bar
- **Cycle** — one clock at a time, rotating at a configurable interval (default 15s)

No external dependencies — uses the system `date` command with `TZ` for timezone conversion.

## Installation

```bash
git clone https://github.com/szabolcsf/dms-world-clock-multi ~/.config/DankMaterialShell/plugins/worldClockMulti
```

Then in DMS:
1. Open **Settings → Plugins → Scan for Plugins**
2. Enable **World Clock Multi**
3. Add the `worldClockMulti` widget to your DankBar widget list
4. `dms restart`

## Configuration

Open plugin settings to:
- Add up to 5 timezones (any valid tz from `timedatectl list-timezones`)
- Give each timezone a custom short label (e.g. "NYC", "TYO")
- Toggle between show-all and cycling mode
- Set the cycle interval (3–120 seconds)
- Switch between 24h and 12h time format

## Development

Hot-reload during development:

```bash
dms ipc call plugins reload worldClockMulti
```

## Files

| File | Purpose |
|---|---|
| `plugin.json` | Plugin manifest |
| `WorldClockWidget.qml` | Bar widget, vertical pill, and popout panel |
| `WorldClockSettings.qml` | Settings UI |
| `tz-list.js` | Common timezone list and helpers |

## License

MIT
