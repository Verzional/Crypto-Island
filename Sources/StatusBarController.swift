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

        // Toggle Island
        let toggleItem = NSMenuItem(
            title: islandController.isExpanded ? "Collapse Island" : "Expand Island",
            action: #selector(toggleIsland),
            keyEquivalent: "i"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Coins Submenu
        let coinsMenu = NSMenu()
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

        // Pin Option
        let pinItem = NSMenuItem(
            title: "Pin Island Open",
            action: #selector(togglePin),
            keyEquivalent: "p"
        )
        pinItem.target = self
        pinItem.state = settings.isPinned ? .on : .off
        menu.addItem(pinItem)

        // Stealth Mode Option
        let stealthItem = NSMenuItem(
            title: "Stealth Mode (Show Only on Hover)",
            action: #selector(toggleStealth),
            keyEquivalent: "s"
        )
        stealthItem.target = self
        stealthItem.state = settings.stealthMode ? .on : .off
        menu.addItem(stealthItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit CryptoIsland",
            action: #selector(quitApp),
            keyEquivalent: "q"
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
    }

    @objc private func toggleStealth() {
        settings.stealthMode.toggle()
        islandController.updatePanelFrame(animated: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
