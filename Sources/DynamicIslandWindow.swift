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

        self.isFloatingPanel = true
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
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }

    override public var canBecomeKey: Bool {
        return true
    }

    override public var canBecomeMain: Bool {
        return false
    }

    override public func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

/// Represents geometry for the display notch and Dynamic Island dimensions.
public struct NotchGeometry: Equatable {
    public let hasNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    public let notchCenter: CGFloat
    public let earWidth: CGFloat

    public init(
        hasNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        notchCenter: CGFloat,
        earWidth: CGFloat = 110
    ) {
        self.hasNotch = hasNotch
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.notchCenter = notchCenter
        self.earWidth = earWidth
    }

    public var collapsedWidth: CGFloat {
        if hasNotch {
            return notchWidth + (earWidth * 2)
        } else {
            return 240
        }
    }

    public var collapsedHeight: CGFloat {
        if hasNotch {
            return notchHeight
        } else {
            return 32
        }
    }

    public var expandedWidth: CGFloat {
        return max(collapsedWidth, 420)
    }

    public var expandedHeight: CGFloat {
        return (hasNotch ? notchHeight : 0) + 128
    }

    public static func current(for screen: NSScreen? = nil) -> NotchGeometry {
        let targetScreen = screen ?? NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = targetScreen else {
            return NotchGeometry(hasNotch: false, notchWidth: 0, notchHeight: 32, notchCenter: 756)
        }

        let frame = screen.frame
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           left.width > 0, right.width > 0 {
            let width = right.minX - left.maxX
            let height = max(left.height, screen.safeAreaInsets.top)
            let center = (left.maxX + right.minX) / 2.0
            return NotchGeometry(
                hasNotch: true,
                notchWidth: width,
                notchHeight: height,
                notchCenter: center,
                earWidth: 110
            )
        } else {
            return NotchGeometry(
                hasNotch: false,
                notchWidth: 0,
                notchHeight: 32,
                notchCenter: frame.midX,
                earWidth: 110
            )
        }
    }
}

/// Hosting view that allows mouse events outside the active Dynamic Island area to pass through to underlying windows.
final class DynamicIslandHostingView<Content: View>: NSHostingView<Content> {
    var isExpandedProvider: () -> Bool = { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let geometry = NotchGeometry.current()
        if !isExpandedProvider() {
            let collapsedWidth = geometry.collapsedWidth
            let collapsedHeight = geometry.collapsedHeight
            let minX = (bounds.width - collapsedWidth) / 2
            let collapsedY = isFlipped ? 0 : (bounds.height - collapsedHeight)
            let collapsedRect = NSRect(x: minX, y: collapsedY, width: collapsedWidth, height: collapsedHeight)
            if !collapsedRect.contains(point) {
                return nil
            }
        }
        return super.hitTest(point)
    }
}

/// Controller responsible for managing the Dynamic Island panel lifecycle,
/// positioning around the notch/screen edge, and sizing updates.
@MainActor
public final class DynamicIslandController: NSObject, ObservableObject {
    public let panel: DynamicIslandPanel
    public let binanceService: BinanceService
    public let settings: SettingsModel

    @Published public var isExpanded: Bool = false

    private var hostingView: DynamicIslandHostingView<AnyView>?
    private var screenChangeObserver: Any?

    public init(binanceService: BinanceService, settings: SettingsModel) {
        self.binanceService = binanceService
        self.settings = settings
        self.panel = DynamicIslandPanel(contentRect: .zero)

        super.init()

        setupHostingView()
        updatePanelFrame()
        panel.orderFrontRegardless()

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePanelFrame()
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

        let host = DynamicIslandHostingView(rootView: AnyView(rootView))
        host.isExpandedProvider = { [weak self] in self?.isExpanded ?? false }
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        self.hostingView = host
    }

    public func toggleExpansion() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isExpanded.toggle()
        }
    }

    /// Positions the island window centered at the top edge of the screen, hugging the notch.
    public func updatePanelFrame(animated: Bool = false) {
        guard let screen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let geometry = NotchGeometry.current(for: screen)

        let width = geometry.expandedWidth
        let height = geometry.expandedHeight

        let x = geometry.notchCenter - (width / 2)
        let y = screenFrame.maxY - height

        let targetFrame = NSRect(x: x, y: y, width: width, height: height)
        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true)
        }
    }
}
