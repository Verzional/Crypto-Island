import AppKit
import Combine

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemTitle()
        rebuildMenu()
    }

    private func observeData() {
        binanceService.$ticker
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        binanceService.$currentSymbol
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
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

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        let symbol = binanceService.currentSymbol.baseAsset
        if let ticker = binanceService.ticker {
            button.title = "\(symbol) \(ticker.formattedPrice)"
        } else {
            button.title = "\(symbol) --"
        }
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

        menu.addItem(NSMenuItem.separator())

        // 5. Quit
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

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
