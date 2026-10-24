# Currency FX Widget for Omarchy Linux

A native status bar widget and interactive dashboard for [Omarchy Linux](https://omarchy.org/) (Hyprland + Quickshell) providing live currency exchange rates, historical trend charts, currency pair cycling, and a quick converter.

Optimized for keyboard-driven workflows and **MacBook Pro** setups where physical right-click or middle-click buttons are absent: **100% of the widget's capabilities are fully controllable from the keyboard**.

---

## Features

- **Live Status Bar Pill**: Displays current currency pair, live exchange rate, and directional trend arrow (`▲` / `▼`) with color cues.
- **Interactive Historical Chart**: Smooth Bezier curve visualization for 7-day, 1-month, 3-month, and 1-year windows.
- **Scrubbing Tooltip**: Scrub through historical dates and rates step-by-step using keyboard arrow keys (<kbd>←</kbd> / <kbd>→</kbd>) or mouse hover.
- **Metrics Dashboard**: Instant statistical breakdown showing period Low, High, Average, and Range.
- **Quick Converter**: Built-in currency calculator. Press <kbd>C</kbd> to type any value and get real-time converted results.
- **30+ Currencies Supported**: Includes major and global currencies (USD, EUR, GBP, JPY, CHF, CAD, AUD, CNY, INR, SEK, NOK, and more).
- **Zero API Keys Required**: Uses the free, open European Central Bank reference data via the Frankfurter API (`api.frankfurter.dev`). No API key, token, registration, or credit card required.

---

## 1. Installation

### Method A: Using Omarchy Plugin CLI (Recommended)

Omarchy Linux includes built-in support for git-managed shell plugins:

```bash
omarchy plugin add https://github.com/<your-username>/fx-rates.git --enable
```

This will automatically:
1. Clone the repository into `~/.config/omarchy/plugins/fx-rates`.
2. Validate the plugin manifest schema.
3. Register and enable the widget in your Omarchy shell bar.

### Method B: Manual Git Clone

Clone directly into your user plugin directory:

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/fx-rates.git ~/.config/omarchy/plugins/fx-rates

# 2. Validate the plugin manifest
omarchy plugin validate ~/.config/omarchy/plugins/fx-rates

# 3. Rescan plugins in the active shell
omarchy-shell shell rescanPlugins

# 4. Enable the widget on your bar (e.g. center section)
omarchy plugin enable fx-rates --section center
```

---

## 2. Configuration & Keybindings

### Global Desktop Keybinding (Hyprland)

To summon or dismiss the FX dashboard from anywhere with a keyboard shortcut, add the following to `~/.config/hypr/bindings.lua`:

```lua
-- Currency FX Rates widget toggle
o.bind("SUPER + ALT + X", "Currency FX rates", "omarchy-shell fx-rates toggle")
```
*(On macOS keyboards, `SUPER + ALT + X` corresponds to <kbd>Cmd</kbd> + <kbd>Option</kbd> + <kbd>X</kbd>).*

Hyprland will reload the binding automatically upon saving.

### Status Bar Layout (`~/.config/omarchy/shell.json`)

The widget configuration resides in `~/.config/omarchy/shell.json`. You can place it in `bar.layout.center`, `left`, or `right`:

```json
{
  "id": "fx-rates",
  "base": "USD",
  "quote": "EUR",
  "timeframe": "1M"
}
```

You can also move or configure it directly via the Omarchy CLI:

```bash
# Move widget position
omarchy bar move fx-rates --section center --after omarchy.weather

# Set base and quote currencies
omarchy bar set fx-rates base USD
omarchy bar set fx-rates quote EUR

# Set default timeframe (7D, 1M, 3M, 1Y)
omarchy bar set fx-rates timeframe 1M
```

---

## 3. Keyboard Controls & Shortcuts

### Global Desktop Controls
| Shortcut | Action | Description |
|---|---|---|
| <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>X</kbd><br>*(Mac: <kbd>Cmd</kbd> + <kbd>Option</kbd> + <kbd>X</kbd>)* | **Toggle FX Panel** | Opens or closes the historical dashboard from anywhere |
| **Trackpad Tap / Left Click** | **Toggle FX Panel** | Click the widget pill on the status bar |

### Inside the FX Dashboard
| Key | Action | Description |
|---|---|---|
| <kbd>←</kbd> / <kbd>→</kbd> *(or <kbd>h</kbd> / <kbd>l</kbd>)* | **Scrub Historical Chart** | Move crosshair step-by-step through historical days, live-updating rate and date |
| <kbd>s</kbd> | **Swap Currencies** | Invert base and quote currencies (e.g. `USD/EUR` ⇄ `EUR/USD`) |
| <kbd>r</kbd> *(or <kbd>F5</kbd>)* | **Refresh Rates** | Force immediate live re-fetch from the ECB Frankfurter API |
| <kbd>1</kbd> | **7-Day View** | Switch chart timeframe to 7 Days |
| <kbd>2</kbd> | **1-Month View** | Switch chart timeframe to 1 Month (30 days) |
| <kbd>3</kbd> | **3-Month View** | Switch chart timeframe to 3 Months (90 days) |
| <kbd>4</kbd> | **1-Year View** | Switch chart timeframe to 1 Year (365 days) |
| <kbd>n</kbd> | **Next Pair** | Cycle forward to the next popular currency pair |
| <kbd>p</kbd> | **Previous Pair** | Cycle backward to the previous popular currency pair |
| <kbd>c</kbd> | **Quick Converter** | Focus converter input; type an amount, then press <kbd>Enter</kbd> or <kbd>Esc</kbd> to return |
| <kbd>a</kbd> | **Toggle All Currencies** | Show/hide the full 30-currency dropdown selector |
| <kbd>↑</kbd> / <kbd>↓</kbd> *(or <kbd>j</kbd> / <kbd>k</kbd>)* | **Scroll Dashboard** | Smoothly scroll the panel content vertically |
| <kbd>Esc</kbd> / <kbd>q</kbd> | **Close Dashboard** | Dismiss the dashboard and return focus to your active window |

---

## 4. CLI & IPC Control

Control the widget directly from scripts, shell prompts, or external keybinds:

```bash
# Toggle dashboard open/closed
omarchy-shell fx-rates toggle

# Trigger immediate exchange rate re-fetch
omarchy-shell fx-rates refresh

# Invert current currency pair
omarchy-shell fx-rates swap

# Open or close explicitly
omarchy-shell fx-rates open
omarchy-shell fx-rates close
```

---

## 5. Security & Privacy

- **No API Keys or Authentication Required**: Fetches open data directly from the official European Central Bank reference feed provided by `https://api.frankfurter.dev`.
- **No Private Credentials**: This plugin requires zero API tokens, passwords, or personal keys.
- **Local Settings Only**: Pair and timeframe preferences are stored locally in `~/.config/omarchy/shell.json`.

---

## 6. Plugin Structure

```
~/.config/omarchy/plugins/fx-rates/
├── manifest.json   # Plugin manifest (id, version, kind, barWidget entry)
├── BarWidget.qml   # Quickshell bar widget pill, timers, and IPC handlers
├── Panel.qml       # Keyboard-driven dashboard, Canvas bezier chart, converter
├── Model.js        # Currency definitions, math utils, and API response parsing
├── README.md       # Plugin documentation
└── .gitignore      # Git exclusion rules ensuring no secrets or temp files
```

---

## License

MIT License. Free and open source for the Omarchy Linux community.
