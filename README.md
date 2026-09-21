# CryptoIsland 🏝️📈

A native macOS Dynamic Island application that floats above full-screen applications (including YouTube videos, Netflix, games, and presentation spaces) to display live cryptocurrency prices from Binance.

## Features

- **Full-Screen Video Overlay**:
  - Uses `NSPanel` with `.screenSaver` window level and `[.canJoinAllSpaces, .fullScreenAuxiliary]` collection behavior.
  - Does not steal key focus or interrupt/pause video playback.
- **Dynamic Island Aesthetic**:
  - **Collapsed Mode**: Compact pill snug against your MacBook's notch (or screen top-center). Shows current coin and live price with pulsing status indicator.
  - **Expanded Mode**: Expands into a card with real-time price, green/red tick animations, 24h change %, 24h high/low, and 24h volume.
  - **Stealth Mode**: Hides the collapsed pill completely until you move your cursor to the top edge / notch.
  - **Pin Mode**: Keep the island expanded while working or watching videos.
- **Real-Time Binance Streaming**:
  - Direct WebSocket streaming (`@ticker` / `@miniTicker`) for instant price updates.
  - Initial REST API fetch for instant data load without delay.
  - Automatic reconnection handling and fallback routing.
- **Quick Coin Switcher**:
  - One-click presets: BTC, ETH, SOL, BNB, DOGE, XRP, SUI, ADA, PEPE.
  - Custom search to track any Binance trading pair (e.g. AVAX, NEAR, RENDER).
- **macOS Menu Bar Companion**:
  - Menu bar icon showing live price and quick options (switch coins, pin, toggle stealth, quit).
- **Keyboard Shortcut**:
  - Press `Control + Option + C` to toggle/trigger the island from anywhere.

## How to Run

### Option 1: Using Xcode
Double-click `CryptoIsland.xcodeproj` or run:
```bash
open CryptoIsland.xcodeproj
```
Select the **CryptoIsland** scheme and press `Cmd + R` to run.

### Option 2: Using Swift Package Manager
```bash
cd /Users/verzional/Home/Xcode/CryptoIsland
swift run
```
