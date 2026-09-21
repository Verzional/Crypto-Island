# CryptoIsland 🏝️

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Binance API](https://img.shields.io/badge/Binance-WebSocket%20Live-F0B90B.svg?style=flat-square&logo=binance)](https://binance.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

A high-performance, native macOS Dynamic Island application that floats above full-screen spaces (including YouTube, Netflix, games, and presentation desktops) to deliver real-time cryptocurrency market intelligence directly from Binance.

Designed specifically for Apple Silicon MacBooks with camera notches, with automatic fallback for non-notch displays and external monitors.

---

## Key Features

### 🏝️ Native Hardware & Notch Integration
- **Zero-Bezel Geometry Matching:** Seamlessly hugs your MacBook's physical camera notch using `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` screen metrics.
- **Continuous Curvature:** Custom "U" shape notch rendering with exact corner radii and hairline border accents blending directly into the bezel.
- **Transparent Cursor Pass-Through:** Utilizes coordinate-aware hit-testing to allow clicks, text selections, and gestures beneath the collapsed island to pass straight through to underlying applications.
- **Fluid Spring Physics:** Custom interactive spring animations (`response: 0.32`, `dampingFraction: 0.82`) for natural expansion and collapse on cursor hover.

### ⚡ Institutional Real-Time Intelligence
- **Sub-Second Streaming:** Direct WebSocket streams (`@ticker`, `@kline_5m`, `@kline_15m`) with automatic reconnection and fallback routing.
- **Dynamic Price Action & Ticks:** Real-time green/red tick flash animations and inline percentage change badges.
- **Institutional Benchmarks (VWAP):** Real-time Volume-Weighted Average Price benchmark to evaluate fair value against current price.
- **Order Flow & Momentum:**
  - **15m & 5m Quote Volume:** Rapid detection of sudden volume surges.
  - **5m Taker Buy Pressure Ratio (`5m Buy %`):** Measures aggressive taker aggression (green $\ge 52\%$, red $\le 48\%$) to gauge market dominance in real time.

### 💎 Micro-Cap & Meme Coin Precision
- **Smart Adaptive Decimal Formatting:** Automatically formats prices based on magnitude:
  - $\ge \$1{,}000$: 2 decimals (`$65,432.10`)
  - $\$1$ to $\$1{,}000$: 2–4 decimals (`$145.20`)
  - $\$0.01$ to $\$1$: up to 6 decimals (`$0.2277`)
  - $< \$0.01$: **Full 8-decimal precision** for micro-cap tokens (e.g. PEPE, SHIB at `$0.00000852`) across price, 24h High, 24h Low, and VWAP.

### 🔍 Minimalist Search & Favorites Hub
- **Dark Glassmorphic Popover:** Frosted-glass search interface built with native macOS materials.
- **User-Curated Favorites (Max 9):** Star any coin directly from the expanded island (`★`) to pin it to your quick-switch favorites grid.
- **Keyboard-First Navigation:** Auto-focused input bar; type any symbol (e.g. `SOL`, `NEAR`, `PEPE`) and press `Return (↵)` to switch pairs instantly.
- **Smart Symbol Parsing:** Automatically appends `USDT` if omitted.

### 🖥️ Full-Screen Video & App Overlay
- **Floats Over Full-Screen Media:** Runs as a non-activating `NSPanel` at the `.screenSaver` window level with `[.canJoinAllSpaces, .fullScreenAuxiliary]` collection behavior.
- **Non-Intrusive:** Never steals key window focus or interrupts full-screen video playback.
- **Menu Bar Companion:** Lightweight status bar item displaying the current ticker and price with quick access to settings.
- **Global Hotkey:** Press `Control + Option + C` from anywhere to toggle the island.

---

## Layout Overview

### Collapsed Notch View
```
+---------------+------------------------+---------------+
|   ARB         |     [ Camera Notch ]   |     $0.2432   |
+---------------+------------------------+---------------+
```

### Expanded Intelligence View
```
+--------------------------------------------------------+
|  ARB / USDT ★        [ Camera Notch ]        [🔍 Search] |
|--------------------------------------------------------|
|  $0.2432   [↗ +14.77%]                                 |
|                                                        |
|  +--------------------------------------------------+  |
|  |  24h High      |  24h Low       |  VWAP          |  |
|  |  $0.2450       |  $0.1962       |  $0.2277       |  |
|  |----------------+----------------+----------------|  |
|  |  15m Vol       |  5m Vol        |  5m Buy %      |  |
|  |  $1.57M        |  $107.9K       |  59% (Takers)  |  |
|  +--------------------------------------------------+  |
+--------------------------------------------------------+
```

---

## Technical Stack & Architecture

| Component | Technology | Description |
| :--- | :--- | :--- |
| **UI Framework** | SwiftUI & AppKit | Declarative view hierarchy hosted in `NSHostingView` |
| **Window Subsystem** | `NSPanel` | Borderless, non-activating floating panel with custom hit-testing |
| **Networking** | `URLSessionWebSocketTask` | Low-latency Binance WebSocket & REST fallback pipeline |
| **State Management** | Combine & `@Published` | Reactive data flow connecting services to UI |
| **Persistence** | `UserDefaults` | Persistent storage for user favorites, active symbol, and settings |

---

## Getting Started

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later / Swift 5.9 toolchain

### Building with Swift Package Manager
```bash
git clone https://github.com/username/CryptoIsland.git
cd CryptoIsland
swift build -c release
.build/release/CryptoIsland
```

### Running with Xcode
```bash
open CryptoIsland.xcodeproj
```
Select the **CryptoIsland** scheme and press `Cmd + R` to build and run.

---

## Controls & Shortcuts

| Action | Shortcut / Trigger |
| :--- | :--- |
| **Expand / Collapse** | Hover cursor over notch, click collapsed island, or press `Control + Option + C` |
| **Open Search** | Click `[🔍 Search]` in the top-right ear of the expanded island |
| **Favorite / Unfavorite Coin** | Click the `★` / `☆` icon beside the coin title in the top-left ear |
| **Switch Pair** | Type symbol in search bar and press `Return (↵)`, or click any Favorite chip |
| **Dismiss Popover** | Press `Esc` or click outside the search popover |

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
