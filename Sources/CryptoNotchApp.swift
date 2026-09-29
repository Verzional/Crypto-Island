import SwiftUI
import AppKit

@main
struct CryptoNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var islandController: DynamicIslandController?
    public var statusBarController: StatusBarController?
    public var hotKeyManager: HotKeyManager?
    public var binanceService: BinanceService?
    public var settings: SettingsModel?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory app (floating notch/island + menu bar item, without Dock clutter)
        NSApp.setActivationPolicy(.accessory)

        let settings = SettingsModel()
        let binanceService = BinanceService()
        let islandController = DynamicIslandController(
            binanceService: binanceService,
            settings: settings
        )
        let statusBarController = StatusBarController(
            islandController: islandController,
            binanceService: binanceService,
            settings: settings
        )
        let hotKeyManager = HotKeyManager(islandController: islandController)

        self.settings = settings
        self.binanceService = binanceService
        self.islandController = islandController
        self.statusBarController = statusBarController
        self.hotKeyManager = hotKeyManager
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
