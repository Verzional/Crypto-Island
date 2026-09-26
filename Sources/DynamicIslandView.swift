import SwiftUI

/// "U" notch shape: flat top against bezel, rounded bottom corners.
public struct NotchShape: Shape {
    public var bottomRadius: CGFloat

    public var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Outline for the "U" shape: strokes left, bottom, and right, leaving top open to blend into bezel.
public struct NotchOutline: Shape {
    public var bottomRadius: CGFloat

    public var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 0.5
        let r = max(1, bottomRadius - inset)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - r - inset))
        path.addArc(
            center: CGPoint(x: rect.minX + inset + r, y: rect.maxY - r - inset),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset - r, y: rect.maxY - inset))
        path.addArc(
            center: CGPoint(x: rect.maxX - inset - r, y: rect.maxY - r - inset),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        return path
    }
}

/// Subtle breathing skeleton pulse effect for loading component placeholders.
public struct SkeletonModifier: ViewModifier {
    @State private var isPulsing: Bool = false

    public func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.30 : 0.75)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    public func skeletonPulse() -> some View {
        modifier(SkeletonModifier())
    }
}

/// The SwiftUI view representing the macOS Dynamic Island for crypto prices.
public struct DynamicIslandView: View {
    @ObservedObject var controller: DynamicIslandController
    @ObservedObject var binanceService: BinanceService
    @ObservedObject var settings: SettingsModel

    @State private var customSymbolText: String = ""
    @State private var isSearchHovered: Bool = false
    @State private var isBackHovered: Bool = false
    @State private var hoveredPillSymbol: String? = nil
    @State private var isFavoritesFullAlertShowing: Bool = false
    @State private var starShake: CGFloat = 0
    @State private var starScale: CGFloat = 1.0
    @State private var isStarHovered: Bool = false
    @State private var dismissToastTask: Task<Void, Never>? = nil
    @State private var isPencilHovered: Bool = false
    @State private var selectedSlotToCustomize: Int = 0
    @State private var selectedMetricCategory: MetricCategory = .all
    @FocusState private var isSearchFocused: Bool

    private var geometry: NotchGeometry {
        NotchGeometry.current()
    }

    public init(
        controller: DynamicIslandController,
        binanceService: BinanceService,
        settings: SettingsModel
    ) {
        self.controller = controller
        self.binanceService = binanceService
        self.settings = settings
    }

    public var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if controller.isExpanded {
                    expandedView
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.94, anchor: .top))
                                    .combined(with: .offset(y: -6)),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.96, anchor: .top))
                            )
                        )
                } else {
                    collapsedView
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.95, anchor: .center)),
                                removal: .opacity
                            )
                        )
                }
            }
            .frame(
                width: controller.isExpanded ? geometry.expandedWidth : geometry.collapsedWidth,
                height: controller.isExpanded ? geometry.expandedHeight : geometry.collapsedHeight,
                alignment: .top
            )
            .background(
                ZStack {
                    if geometry.hasNotch {
                        NotchShape(bottomRadius: controller.isExpanded ? 20 : 10)
                            .fill(Color.black)
                    } else {
                        RoundedRectangle(cornerRadius: controller.isExpanded ? 20 : 17, style: .continuous)
                            .fill(Color.black)
                    }
                }
            )
            .overlay(
                ZStack {
                    if geometry.hasNotch {
                        NotchOutline(bottomRadius: controller.isExpanded ? 20 : 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: controller.isExpanded ? 20 : 17, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
            )
            .clipShape(
                geometry.hasNotch
                    ? AnyShape(NotchShape(bottomRadius: controller.isExpanded ? 20 : 10))
                    : AnyShape(RoundedRectangle(cornerRadius: controller.isExpanded ? 20 : 17, style: .continuous))
            )
            .shadow(color: Color.black.opacity(controller.isExpanded ? 0.35 : 0.0), radius: controller.isExpanded ? 12 : 0, x: 0, y: controller.isExpanded ? 6 : 0)
            .contentShape(Rectangle())
        }
        .opacity((settings.stealthMode && !controller.isExpanded && !controller.isHovered) ? 0.0 : 1.0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: binanceService.flashDirection)
        .animation(.easeInOut(duration: 0.25), value: settings.stealthMode)
        .animation(.easeInOut(duration: 0.25), value: controller.isHovered)
    }

    // MARK: - Collapsed View
    private var collapsedView: some View {
        HStack(spacing: 0) {
            // Left Ear: Symbol (no green dot)
            Text(binanceService.currentSymbol.baseAsset)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: geometry.earWidth, alignment: .center)

            // Center: Gap matching physical camera notch
            if geometry.hasNotch {
                Color.clear
                    .frame(width: geometry.notchWidth, height: geometry.collapsedHeight)
            } else {
                Spacer(minLength: 8)
            }

            // Right Ear: Price or Error State
            HStack(spacing: 4) {
                if binanceService.isInvalidSymbol {
                    Text("Not Found")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                } else if let ticker = binanceService.ticker {
                    Text(ticker.formattedPrice)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(flashColor(for: ticker))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: ticker.price)
                } else {
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 52, height: 13)
                        .skeletonPulse()
                }
            }
            .frame(width: geometry.earWidth, alignment: .center)
        }
        .frame(height: geometry.collapsedHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            controller.toggleExpansion()
        }
    }

    // MARK: - Expanded View
    private var expandedTopBar: some View {
        Group {
            if geometry.hasNotch {
                HStack(spacing: 0) {
                    // Left Ear: Coin Title + Favorite Star
                    HStack(alignment: .center, spacing: 5) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(binanceService.currentSymbol.baseAsset)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ " + binanceService.currentSymbol.quoteAsset)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        if !binanceService.isInvalidSymbol {
                            favoriteStarButton
                        }
                    }
                    .padding(.leading, 14)
                    .frame(width: (geometry.expandedWidth - geometry.notchWidth) / 2, height: 22, alignment: .leading)
                    .offset(y: 2)

                    // Center: Gap matching physical camera notch
                    Color.clear
                        .frame(width: geometry.notchWidth, height: geometry.collapsedHeight)

                    // Right Ear: Action Tools (aligned with 14pt right margin)
                    HStack(spacing: 6) {
                        customizeGridButton
                        searchButton
                    }
                    .padding(.trailing, 14)
                    .frame(width: (geometry.expandedWidth - geometry.notchWidth) / 2, height: 22, alignment: .trailing)
                }
                .frame(height: geometry.collapsedHeight)
            } else {
                HStack(alignment: .center) {
                    HStack(alignment: .center, spacing: 5) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(binanceService.currentSymbol.baseAsset)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ " + binanceService.currentSymbol.quoteAsset)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        if !binanceService.isInvalidSymbol {
                            favoriteStarButton
                        }
                    }
                    .padding(.leading, 14)
                    .offset(y: 2)

                    Spacer()

                    HStack(spacing: 6) {
                        customizeGridButton
                        searchButton
                    }
                    .padding(.trailing, 14)
                }
                .frame(height: geometry.collapsedHeight)
            }
        }
    }

    private var favoriteStarButton: some View {
        let isFav = settings.isFavorite(binanceService.currentSymbol.symbol)
        return Button {
            if isFav {
                _ = withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                    settings.toggleFavorite(binanceService.currentSymbol.symbol)
                }
                // Native Apple unfavorite settle
                withAnimation(.spring(response: 0.16, dampingFraction: 0.70)) {
                    starScale = 0.90
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.75)) {
                        starScale = 1.0
                    }
                }
            } else {
                let success = settings.toggleFavorite(binanceService.currentSymbol.symbol)
                if success {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    // Native Apple favorite pulse (1.16x axial bounce, zero rotation)
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
                        starScale = 1.16
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                            starScale = 1.0
                        }
                    }
                } else {
                    triggerFavoritesFullFeedback()
                }
            }
        } label: {
            Image(systemName: isFav ? "star.fill" : "star")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(isFav ? .white : (isStarHovered ? .white.opacity(0.70) : .white.opacity(0.35)))
                .scaleEffect(starScale)
                .offset(x: starShake)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isStarHovered = hovering
            }
        }
        .help(isFav ? "Remove from Favorites" : "Add to Favorites (Max 9)")
    }

    private func triggerFavoritesFullFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)

        // Apple-native subtle reject shake (2.5pt, 3 cycles, 140ms total)
        withAnimation(.easeInOut(duration: 0.045).repeatCount(3, autoreverses: true)) {
            starShake = 2.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            starShake = 0
        }

        dismissToastTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isFavoritesFullAlertShowing = true
        }
        dismissToastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                isFavoritesFullAlertShowing = false
            }
        }
    }

    private var customizeGridButton: some View {
        Button {
            if !controller.isCustomizingGrid {
                controller.isCustomInputShowing = false
            }
            controller.isCustomizingGrid.toggle()
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white.opacity(isPencilHovered || controller.isCustomizingGrid ? 1.0 : 0.8))
                .frame(width: 22, height: 22)
                .background(
                    LinearGradient(
                        colors: controller.isCustomizingGrid
                            ? [Color.white.opacity(0.24), Color.white.opacity(0.15)]
                            : isPencilHovered
                                ? [Color.white.opacity(0.18), Color.white.opacity(0.10)]
                                : [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            controller.isCustomizingGrid
                                ? Color.white.opacity(0.35)
                                : isPencilHovered
                                    ? Color.white.opacity(0.25)
                                    : Color.white.opacity(0.15),
                            lineWidth: 0.8
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPencilHovered = hovering
            }
        }
        .help("Customize Stats Grid")
        .popover(isPresented: $controller.isCustomizingGrid, arrowEdge: .bottom) {
            gridCustomizationPopoverView
        }
    }

    private var searchButton: some View {
        Button {
            if !controller.isCustomInputShowing {
                controller.isCustomizingGrid = false
            }
            controller.isCustomInputShowing.toggle()
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white.opacity(isSearchHovered || controller.isCustomInputShowing ? 1.0 : 0.8))
                .frame(width: 22, height: 22)
                .background(
                    LinearGradient(
                        colors: controller.isCustomInputShowing
                            ? [Color.white.opacity(0.24), Color.white.opacity(0.15)]
                            : isSearchHovered
                                ? [Color.white.opacity(0.18), Color.white.opacity(0.10)]
                                : [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            controller.isCustomInputShowing
                                ? Color.white.opacity(0.35)
                                : isSearchHovered
                                    ? Color.white.opacity(0.25)
                                    : Color.white.opacity(0.15),
                            lineWidth: 0.8
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isSearchHovered = hovering
            }
        }
        .help("Search & Switch Pair")
        .popover(isPresented: $controller.isCustomInputShowing, arrowEdge: .bottom) {
            customSymbolInputView
        }
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            expandedTopBar

            if binanceService.isInvalidSymbol {
                invalidSymbolErrorView
            } else {
                // Content below notch
                VStack(spacing: 8) {
                // Price & 24h Change Row (grouped together on the left)
                HStack(alignment: .center, spacing: 8) {
                    if let ticker = binanceService.ticker {
                        Text(ticker.formattedPrice)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(flashColor(for: ticker))
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: ticker.price)
                            .scaleEffect(binanceService.flashDirection != nil ? 1.03 : 1.0)
                            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: binanceService.flashDirection)

                        // Change Badge (Inline with price)
                        HStack(spacing: 3) {
                            Image(systemName: ticker.priceChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(ticker.formattedChangePercent)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.28, dampingFraction: 0.8), value: ticker.priceChangePercent)
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(
                            (ticker.priceChangePercent >= 0 ? Color.green : Color.red).opacity(0.2)
                        )
                        .foregroundColor(ticker.priceChangePercent >= 0 ? .green : .red)
                        .clipShape(Capsule())
                    } else {
                        // Price loading placeholder
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 88, height: 20)
                            .skeletonPulse()

                        // Change Badge loading placeholder
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 54, height: 20)
                            .skeletonPulse()
                    }

                    Spacer()
                }
                .frame(height: 22)

                // 2-Row Stats Grid: Configurable 6-Slot Grid
                VStack(spacing: 5) {
                    let slots = settings.gridSlots.count == 6 ? settings.gridSlots : StatMetric.defaultSlots
                    // Row 1
                    HStack(spacing: 8) {
                        statCell(slotIndex: 0, metric: slots[0])
                        Divider().frame(height: 18).background(Color.white.opacity(0.12))
                        statCell(slotIndex: 1, metric: slots[1])
                        Divider().frame(height: 18).background(Color.white.opacity(0.12))
                        statCell(slotIndex: 2, metric: slots[2])
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Row 2
                    HStack(spacing: 8) {
                        statCell(slotIndex: 3, metric: slots[3])
                        Divider().frame(height: 18).background(Color.white.opacity(0.12))
                        statCell(slotIndex: 4, metric: slots[4])
                        Divider().frame(height: 18).background(Color.white.opacity(0.12))
                        statCell(slotIndex: 5, metric: slots[5])
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
            }
            .padding(.top, 4)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            }
        }
        .overlay(alignment: .top) {
            if isFavoritesFullAlertShowing {
                favoritesFullToast
                    .padding(.top, geometry.collapsedHeight + 5)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    ))
            }
        }
    }

    private var favoritesFullToast: some View {
        Text("Favorites Full (9/9)")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .tracking(0.3)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(white: 0.12).opacity(0.96))
                    .shadow(color: .black.opacity(0.60), radius: 10, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
    }

    private var invalidSymbolErrorView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            // 1. Error Announcement
            VStack(spacing: 3) {
                Text("Pair Not Found")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\"\(binanceService.currentSymbol.baseAsset)/\(binanceService.currentSymbol.quoteAsset)\" is not listed on Binance Spot")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            // 2. Unified Action Shelf: [ ⤺ Back ] │ [ ARB ] [ PUMP ] [ NEAR ] ...
            HStack(spacing: 7) {
                // Back Button (Prominent recovery button)
                Button {
                    binanceService.revertToLastValidSymbol()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9, weight: .bold))
                        Text("Back")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(
                        LinearGradient(
                            colors: isBackHovered
                                ? [Color.white.opacity(0.25), Color.white.opacity(0.16)]
                                : [Color.white.opacity(0.16), Color.white.opacity(0.09)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                isBackHovered
                                    ? Color.white.opacity(0.35)
                                    : Color.white.opacity(0.18),
                                lineWidth: 0.8
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isBackHovered = hovering
                    }
                }

                // Subtle separator between "Back" and shortcut coins
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 1)

                // Favorite / Popular Coin Pills (Direct shortcuts, no redundant labels)
                ForEach(quickSwitchSymbols, id: \.self) { sym in
                    Button {
                        binanceService.selectSymbol(sym)
                    } label: {
                        Text(sym.baseAsset)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(
                                hoveredPillSymbol == sym.symbol
                                    ? Color.white.opacity(0.20)
                                    : Color.white.opacity(0.08)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        hoveredPillSymbol == sym.symbol
                                            ? Color.white.opacity(0.32)
                                            : Color.white.opacity(0.12),
                                        lineWidth: 0.8
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            hoveredPillSymbol = hovering ? sym.symbol : nil
                        }
                    }
                }
            }

            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .transition(.opacity)
    }

    private var quickSwitchSymbols: [CryptoSymbol] {
        let favs = settings.favorites.compactMap { fav in
            CryptoSymbol.presets.first(where: { $0.symbol == fav }) ?? CryptoSymbol.from(rawInput: fav)
        }.filter { $0.symbol != binanceService.currentSymbol.symbol }

        if !favs.isEmpty {
            return Array(favs.prefix(6))
        } else {
            return Array(CryptoSymbol.presets.filter { $0.symbol != binanceService.currentSymbol.symbol }.prefix(5))
        }
    }

    private func statColumn(
        title: String,
        value: String?,
        valueColor: Color = .white.opacity(0.92),
        placeholderWidth: CGFloat = 55
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)

            if let val = value, !val.isEmpty {
                Text(val)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: val)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: placeholderWidth, height: 12)
                    .skeletonPulse()
                    .padding(.vertical, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buyRatioColor(_ ratio: Double) -> Color {
        if ratio >= 52.0 {
            return .green
        } else if ratio <= 48.0 {
            return .red
        } else {
            return .white.opacity(0.92)
        }
    }

    private func statCell(slotIndex: Int, metric: StatMetric) -> some View {
        let info = displayValue(for: metric)
        return statColumn(
            title: metric.title,
            value: info.value,
            valueColor: info.color,
            placeholderWidth: info.placeholderWidth
        )
    }

    private func displayValue(for metric: StatMetric) -> (value: String?, color: Color, placeholderWidth: CGFloat) {
        guard let ticker = binanceService.ticker else {
            return (nil, .white.opacity(0.92), 52)
        }
        switch metric {
        case .high24h:
            return (ticker.formattedHigh, .white.opacity(0.92), 58)
        case .low24h:
            return (ticker.formattedLow, .white.opacity(0.92), 58)
        case .vwap:
            return (ticker.formattedVWAP, .white.opacity(0.92), 58)
        case .quoteVolume24h:
            return (ticker.formattedQuoteVolume, .white.opacity(0.92), 52)
        case .baseVolume24h:
            return (ticker.formattedBaseVolume, .white.opacity(0.92), 52)
        case .priceChange:
            let color: Color = ticker.priceChange >= 0 ? .green : .red
            return (ticker.formattedPriceChange, color, 52)
        case .openPrice:
            return (ticker.formattedOpenPrice, .white.opacity(0.92), 58)
        case .quoteVolume15m:
            let volLoaded = ticker.quoteVolume15m > 0
            return (volLoaded ? ticker.formattedQuoteVolume15m : nil, .white.opacity(0.92), 52)
        case .quoteVolume5m:
            let volLoaded = ticker.quoteVolume5m > 0
            return (volLoaded ? ticker.formattedQuoteVolume5m : nil, .white.opacity(0.92), 52)
        case .takerBuyRatio5m:
            let volLoaded = ticker.quoteVolume5m > 0
            let ratio = ticker.takerBuyRatio5m
            return (volLoaded ? ticker.formattedTakerBuyRatio5m : nil, buyRatioColor(ratio), 36)
        case .takerBuyRatio15m:
            let volLoaded = ticker.quoteVolume15m > 0
            let ratio = ticker.takerBuyRatio15m
            return (volLoaded ? ticker.formattedTakerBuyRatio15m : nil, buyRatioColor(ratio), 36)
        case .trades24h:
            let loaded = ticker.trades24h > 0
            return (loaded ? ticker.formattedTrades24h : nil, .white.opacity(0.92), 48)
        case .trades5m:
            let loaded = ticker.trades5m > 0
            return (loaded ? ticker.formattedTrades5m : nil, .white.opacity(0.92), 42)
        case .spread:
            let loaded = ticker.spread > 0
            return (loaded ? ticker.formattedSpread : nil, .white.opacity(0.92), 48)
        case .bestBid:
            let loaded = ticker.bidPrice > 0
            return (loaded ? ticker.formattedBid : nil, .green.opacity(0.92), 54)
        case .bestAsk:
            let loaded = ticker.askPrice > 0
            return (loaded ? ticker.formattedAsk : nil, .red.opacity(0.92), 54)
        case .avgTradeSize:
            let loaded = ticker.trades24h > 0 && ticker.quoteVolume > 0
            return (loaded ? ticker.formattedAvgTradeSize : nil, .white.opacity(0.92), 52)
        case .change1h:
            let color: Color = ticker.change1h >= 0 ? .green : .red
            return (ticker.formattedChange1h, color, 48)
        case .change4h:
            let color: Color = ticker.change4h >= 0 ? .green : .red
            return (ticker.formattedChange4h, color, 48)
        case .bookImbalance:
            let loaded = ticker.bidDepth20 > 0 || ticker.askDepth20 > 0
            let color: Color = ticker.bookImbalance >= 52.0 ? .green : (ticker.bookImbalance <= 48.0 ? .red : .white.opacity(0.92))
            return (loaded ? ticker.formattedBookImbalance : nil, color, 52)
        case .bidDepth20:
            let loaded = ticker.bidDepth20 > 0
            return (loaded ? ticker.formattedBidDepth20 : nil, .green.opacity(0.92), 52)
        case .askDepth20:
            let loaded = ticker.askDepth20 > 0
            return (loaded ? ticker.formattedAskDepth20 : nil, .red.opacity(0.92), 52)
        }
    }

    // MARK: - Grid Customization View
    private var gridCustomizationPopoverView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Title + Reset Button
            HStack(alignment: .center) {
                Text("Customize Stats")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    settings.resetGridSlots()
                } label: {
                    Text("Reset")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Interactive 6-slot preview layout
            VStack(alignment: .leading, spacing: 4) {
                Text("TAP A SLOT TO EDIT")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(0.5)

                let slots = settings.gridSlots.count == 6 ? settings.gridSlots : StatMetric.defaultSlots
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { idx in
                            slotPreviewButton(index: idx, metric: slots[idx])
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(3..<6, id: \.self) { idx in
                            slotPreviewButton(index: idx, metric: slots[idx])
                        }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.12))

            // Metrics picker list filtered by category (trimmed to unused metrics only)
            VStack(alignment: .leading, spacing: 6) {
                let alreadySelected = Set(settings.gridSlots)
                let availableMetrics = StatMetric.allCases.filter { metric in
                    !alreadySelected.contains(metric) && (selectedMetricCategory == .all || metric.category == selectedMetricCategory)
                }

                // Category capsules (replacing the redundant "-> Slot X" label)
                HStack(spacing: 4) {
                    ForEach(MetricCategory.allCases) { cat in
                        categoryFilterCapsule(cat)
                    }
                }

                if availableMetrics.isEmpty {
                    Text(selectedMetricCategory == .all ? "All metrics are currently assigned" : "All \(selectedMetricCategory.title) metrics are assigned")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(availableMetrics) { metric in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        settings.updateGridSlot(at: selectedSlotToCustomize, to: metric)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 5) {
                                                Text(metric.title)
                                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.90))

                                                if selectedMetricCategory == .all {
                                                    Text(metric.category.title)
                                                        .font(.system(size: 8, weight: .medium, design: .rounded))
                                                        .foregroundColor(.white.opacity(0.40))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.white.opacity(0.06))
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Text(metric.shortDescription)
                                                .font(.system(size: 9, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white.opacity(0.40))
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .padding(12)
        .frame(width: 256)
    }

    private func categoryFilterCapsule(_ cat: MetricCategory) -> some View {
        let isSelected = selectedMetricCategory == cat
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedMetricCategory = cat
            }
        } label: {
            Text(cat.title)
                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.60))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    isSelected
                        ? Color.white.opacity(0.20)
                        : Color.white.opacity(0.06)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? Color.white.opacity(0.35)
                                : Color.white.opacity(0.10),
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func slotPreviewButton(index: Int, metric: StatMetric) -> some View {
        let isSelectedSlot = selectedSlotToCustomize == index
        return Button {
            selectedSlotToCustomize = index
        } label: {
            VStack(spacing: 1.5) {
                Text("Slot \(index + 1)")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundColor(isSelectedSlot ? .white.opacity(0.9) : .gray)
                Text(metric.title)
                    .font(.system(size: 9.5, weight: isSelectedSlot ? .bold : .medium, design: .monospaced))
                    .foregroundColor(isSelectedSlot ? .white : .white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelectedSlot ? Color.white.opacity(0.20) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isSelectedSlot ? Color.white.opacity(0.45) : Color.white.opacity(0.12), lineWidth: isSelectedSlot ? 1.2 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Symbol Input View
    private var customSymbolInputView: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Header (clean, no duplicate search icon)
            HStack(alignment: .center) {
                Text("Switch Pair")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text(binanceService.currentSymbol.symbol)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white.opacity(0.75))
                    .clipShape(Capsule())
            }

            // Sleek Search Input Bar
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)

                TextField("Symbol (e.g. SOL, SUI)", text: $customSymbolText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .focused($isSearchFocused)
                    .onSubmit {
                        commitCustomSymbol()
                    }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSearchFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 0.8)
            )

            if binanceService.isInvalidSymbol {
                Text("Symbol not found on Binance")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.horizontal, 2)
                    .transition(.opacity)
            }

            // Favorites Grid (Dynamic user favorites, max 9)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FAVORITES")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(0.5)

                    Spacer()

                    Text("\(settings.favorites.count)/9")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.7))
                }

                if settings.favorites.isEmpty {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 28, height: 28)
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color.white.opacity(0.75))
                        }

                        VStack(spacing: 3) {
                            Text("No Favorites Yet")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))

                            Text("Click ★ on the island to pin coins here")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(settings.favorites, id: \.self) { favString in
                            let preset = CryptoSymbol.from(rawInput: favString)
                            let isCurrent = preset.symbol == binanceService.currentSymbol.symbol
                            Button {
                                binanceService.selectSymbol(preset)
                                customSymbolText = ""
                                controller.isCustomInputShowing = false
                            } label: {
                                Text(preset.baseAsset)
                                    .font(.system(size: 11, weight: isCurrent ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isCurrent ? .white : .white.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(
                                        isCurrent
                                            ? Color.white.opacity(0.20)
                                            : Color.white.opacity(0.07)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(
                                                isCurrent ? Color.white.opacity(0.35) : Color.white.opacity(0.1),
                                                lineWidth: 0.8
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 250)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }

    private func commitCustomSymbol() {
        guard !customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let sym = CryptoSymbol.from(rawInput: customSymbolText)
        binanceService.selectSymbol(sym)
        customSymbolText = ""
        controller.isCustomInputShowing = false
    }

    // MARK: - Colors
    private var liveColor: Color {
        guard let ticker = binanceService.ticker else { return .yellow }
        return ticker.priceChangePercent >= 0 ? .green : .red
    }

    private func flashColor(for ticker: TickerData) -> Color {
        if let direction = binanceService.flashDirection {
            return direction == .up ? Color.green : Color.red
        }
        return .white
    }
}
