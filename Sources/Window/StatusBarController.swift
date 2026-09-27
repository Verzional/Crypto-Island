import AppKit
import Combine
import ServiceManagement

/// Manages the macOS menu bar status item companion.
@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let islandController: DynamicIslandController
    private let binanceService: BinanceService
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    public init(
        islandController: DynamicIslandController,
        binanceService: BinanceService,
        settings: SettingsModel
    ) {
        self.islandController = islandController
        self.binanceService = binanceService
        self.settings = settings
        super.init()

        setupStatusItem()
        observeData()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusItemIcon()
        rebuildMenu()
    }

    private func observeData() {
        binanceService.$currentSymbol
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        settings.$isPinned
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        settings.$stealthMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        settings.$favorites
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        islandController.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func configureStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let symbol = NSImage(systemSymbolName: "bitcoinsign.circle", accessibilityDescription: "CryptoIsland")?.withSymbolConfiguration(config) {
            // SF Symbols carry a font baseline that causes NSStatusBarButton to offset the circle 0.5pt (1px) too high.
            // Drawing the symbol inside an exact canvas normalizes alignment to achieve a 1:1 pixel match with the Play icon.
            let icon = NSImage(size: symbol.size, flipped: false) { rect in
                var drawRect = rect
                drawRect.origin.y += 0.5
                symbol.draw(in: drawRect)
                return true
            }
            icon.isTemplate = true
            button.image = icon
            button.imagePosition = .imageOnly
        }
        button.title = ""
        button.toolTip = nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // 1. Select Coin Submenu at the very top
        let coinsMenu = NSMenu()

        // User Favorites first (if any)
        if !settings.favorites.isEmpty {
            let favHeader = NSMenuItem(title: "Favorites", action: nil, keyEquivalent: "")
            favHeader.isEnabled = false
            coinsMenu.addItem(favHeader)

            for fav in settings.favorites {
                let sym = CryptoSymbol.from(rawInput: fav)
                let item = NSMenuItem(
                    title: "\(sym.baseAsset) / \(sym.quoteAsset)",
                    action: #selector(selectCoin(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = sym
                item.state = (sym.symbol == binanceService.currentSymbol.symbol) ? .on : .off
                coinsMenu.addItem(item)
            }
            coinsMenu.addItem(NSMenuItem.separator())
        }

        // Popular Presets
        let popularHeader = NSMenuItem(title: "Popular Pairs", action: nil, keyEquivalent: "")
        popularHeader.isEnabled = false
        coinsMenu.addItem(popularHeader)

        for preset in CryptoSymbol.presets {
            let item = NSMenuItem(
                title: "\(preset.baseAsset) - \(preset.name)",
                action: #selector(selectCoin(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset
            item.state = (preset.symbol == binanceService.currentSymbol.symbol) ? .on : .off
            coinsMenu.addItem(item)
        }

        let coinsMenuItem = NSMenuItem(title: "Select Coin", action: nil, keyEquivalent: "")
        coinsMenuItem.submenu = coinsMenu
        menu.addItem(coinsMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Toggle Island
        let toggleItem = NSMenuItem(
            title: islandController.isExpanded ? "Collapse Island" : "Expand Island",
            action: #selector(toggleIsland),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        // 3. Pin Option
        let pinItem = NSMenuItem(
            title: "Pin Island Open",
            action: #selector(togglePin),
            keyEquivalent: ""
        )
        pinItem.target = self
        pinItem.state = settings.isPinned ? .on : .off
        menu.addItem(pinItem)

        // 4. Stealth Mode Option
        let stealthItem = NSMenuItem(
            title: "Stealth Mode (Show Only on Hover)",
            action: #selector(toggleStealth),
            keyEquivalent: ""
        )
        stealthItem.target = self
        stealthItem.state = settings.stealthMode ? .on : .off
        menu.addItem(stealthItem)

        // 5. Launch at Login
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Quit
        let quitItem = NSMenuItem(
            title: "Quit CryptoIsland",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleIsland() {
        islandController.toggleExpansion()
        rebuildMenu()
    }

    @objc private func selectCoin(_ sender: NSMenuItem) {
        if let symbol = sender.representedObject as? CryptoSymbol {
            binanceService.selectSymbol(symbol)
        }
    }

    @objc private func togglePin() {
        settings.isPinned.toggle()
        if settings.isPinned && !islandController.isExpanded {
            islandController.toggleExpansion()
        }
        rebuildMenu()
    }

    @objc private func toggleStealth() {
        settings.stealthMode.toggle()
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle Launch at Login: \(error)")
        }
        rebuildMenu()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
