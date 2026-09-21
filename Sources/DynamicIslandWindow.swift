import AppKit
import SwiftUI

/// Custom NSPanel configured to float above full-screen windows (e.g. YouTube in full-screen)
/// and anchor to the macOS camera notch or top bezel.
public final class DynamicIslandPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Ensure the island floats over native full-screen apps and video players
        self.level = .screenSaver
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }

    override public var canBecomeKey: Bool {
        return true
    }

    override public var canBecomeMain: Bool {
        return false
    }
}

/// Controller responsible for managing the Dynamic Island panel lifecycle,
/// positioning around the notch/screen edge, and sizing updates.
@MainActor
public final class DynamicIslandController: NSObject, ObservableObject {
    public let panel: DynamicIslandPanel
    public let binanceService: BinanceService
    public let settings: SettingsModel

    @Published public var isExpanded: Bool = false {
        didSet {
            updatePanelFrame(animated: true)
        }
    }

    private var hostingView: NSHostingView<AnyView>?
    private var screenChangeObserver: Any?

    public init(binanceService: BinanceService, settings: SettingsModel) {
        self.binanceService = binanceService
        self.settings = settings
        self.panel = DynamicIslandPanel(contentRect: .zero)

        super.init()

        setupHostingView()
        updatePanelFrame(animated: false)
        panel.orderFrontRegardless()

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePanelFrame(animated: false)
            }
        }
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupHostingView() {
        let binding = Binding<Bool>(
            get: { [weak self] in self?.isExpanded ?? false },
            set: { [weak self] in self?.isExpanded = $0 }
        )

        let rootView = DynamicIslandView(
            binanceService: binanceService,
            settings: settings,
            isExpanded: binding
        )

        let host = NSHostingView(rootView: AnyView(rootView))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        self.hostingView = host
    }

    public func toggleExpansion() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            isExpanded.toggle()
        }
    }

    /// Positions the island centered at the top edge of the screen, hugging the notch if present.
    public func updatePanelFrame(animated: Bool) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let width: CGFloat = isExpanded ? 400 : (settings.stealthMode ? 140 : 230)
        let height: CGFloat = isExpanded ? 180 : (settings.stealthMode ? 16 : 38)

        // Center horizontally
        let x = screenFrame.midX - (width / 2)
        
        // Align to top edge of screen (where notch resides)
        let y = screenFrame.maxY - height

        let newFrame = NSRect(x: x, y: y, width: width, height: height)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }
}
