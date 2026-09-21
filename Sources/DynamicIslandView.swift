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

/// The SwiftUI view representing the macOS Dynamic Island for crypto prices.
public struct DynamicIslandView: View {
    @ObservedObject var binanceService: BinanceService
    @ObservedObject var settings: SettingsModel
    @Binding var isExpanded: Bool

    @State private var showingCustomInput: Bool = false
    @State private var customSymbolText: String = ""
    @State private var isHovered: Bool = false
    @State private var isSearchHovered: Bool = false
    @FocusState private var isSearchFocused: Bool
    @State private var isCollapsing: Bool = false
    @State private var expandWorkItem: DispatchWorkItem?
    @State private var collapseWorkItem: DispatchWorkItem?

    private var geometry: NotchGeometry {
        NotchGeometry.current()
    }

    public init(
        binanceService: BinanceService,
        settings: SettingsModel,
        isExpanded: Binding<Bool>
    ) {
        self.binanceService = binanceService
        self.settings = settings
        self._isExpanded = isExpanded
    }

    public var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if isExpanded {
                    expandedView
                        .transition(.opacity)
                } else {
                    collapsedView
                        .transition(.opacity)
                }
            }
            .frame(
                width: isExpanded ? geometry.expandedWidth : geometry.collapsedWidth,
                height: isExpanded ? geometry.expandedHeight : geometry.collapsedHeight,
                alignment: .top
            )
            .background(
                ZStack {
                    if geometry.hasNotch {
                        NotchShape(bottomRadius: isExpanded ? 20 : 10)
                            .fill(Color.black)
                    } else {
                        RoundedRectangle(cornerRadius: isExpanded ? 20 : 17, style: .continuous)
                            .fill(Color.black)
                    }
                }
            )
            .overlay(
                ZStack {
                    if geometry.hasNotch {
                        NotchOutline(bottomRadius: isExpanded ? 20 : 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: isExpanded ? 20 : 17, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
            )
            .clipShape(
                geometry.hasNotch
                    ? AnyShape(NotchShape(bottomRadius: isExpanded ? 20 : 10))
                    : AnyShape(RoundedRectangle(cornerRadius: isExpanded ? 20 : 17, style: .continuous))
            )
            .shadow(color: Color.black.opacity(isExpanded ? 0.35 : 0.0), radius: isExpanded ? 12 : 0, x: 0, y: isExpanded ? 6 : 0)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    collapseWorkItem?.cancel()
                    collapseWorkItem = nil

                    if !isExpanded {
                        expandWorkItem?.cancel()
                        let work = DispatchWorkItem {
                            guard isHovered && !isExpanded else { return }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                isExpanded = true
                            }
                        }
                        expandWorkItem = work
                        let delay: Double = isCollapsing ? 0.35 : 0.08
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
                    }
                } else {
                    expandWorkItem?.cancel()
                    expandWorkItem = nil

                    guard isExpanded else { return }

                    collapseWorkItem?.cancel()
                    let work = DispatchWorkItem {
                        guard !isHovered && !showingCustomInput && isExpanded else { return }
                        isCollapsing = true
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            isExpanded = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            isCollapsing = false
                        }
                    }
                    collapseWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: binanceService.flashDirection)
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

            // Right Ear: Price (no green dot)
            HStack(spacing: 6) {
                if let ticker = binanceService.ticker {
                    Text(ticker.formattedPrice)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(flashColor(for: ticker))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                } else {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }
            }
            .frame(width: geometry.earWidth, alignment: .center)
        }
        .frame(height: geometry.collapsedHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
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
                        favoriteStarButton
                    }
                    .padding(.leading, 14)
                    .frame(width: (geometry.expandedWidth - geometry.notchWidth) / 2, height: 22, alignment: .leading)
                    .offset(y: 2)

                    // Center: Gap matching physical camera notch
                    Color.clear
                        .frame(width: geometry.notchWidth, height: geometry.collapsedHeight)

                    // Right Ear: Search Button (aligned with 14pt right margin)
                    HStack {
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
                        favoriteStarButton
                    }
                    .padding(.leading, 14)
                    .offset(y: 2)

                    Spacer()

                    searchButton
                        .padding(.trailing, 14)
                }
                .frame(height: geometry.collapsedHeight)
            }
        }
    }

    private var favoriteStarButton: some View {
        let isFav = settings.isFavorite(binanceService.currentSymbol.symbol)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                settings.toggleFavorite(binanceService.currentSymbol.symbol)
            }
        } label: {
            Image(systemName: isFav ? "star.fill" : "star")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(isFav ? .yellow : .white.opacity(0.35))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isFav ? "Remove from Favorites" : "Add to Favorites (Max 9)")
    }

    private var searchButton: some View {
        Button {
            showingCustomInput.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white.opacity(isSearchHovered || showingCustomInput ? 1.0 : 0.8))
                Text("Search")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(isSearchHovered || showingCustomInput ? 1.0 : 0.85))
            }
            .frame(width: 68, height: 22)
            .background(
                LinearGradient(
                    colors: showingCustomInput
                        ? [Color.white.opacity(0.24), Color.white.opacity(0.15)]
                        : isSearchHovered
                            ? [Color.white.opacity(0.18), Color.white.opacity(0.10)]
                            : [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        showingCustomInput
                            ? Color.white.opacity(0.35)
                            : isSearchHovered
                                ? Color.white.opacity(0.25)
                                : Color.white.opacity(0.15),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isSearchHovered = hovering
        }
        .popover(isPresented: $showingCustomInput, arrowEdge: .bottom) {
            customSymbolInputView
        }
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            expandedTopBar

            // Content below notch
            VStack(spacing: 8) {
                // Price & 24h Change Row (grouped together on the left)
                if let ticker = binanceService.ticker {
                    HStack(alignment: .center, spacing: 8) {
                        Text(ticker.formattedPrice)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(flashColor(for: ticker))
                            .animation(.easeInOut(duration: 0.2), value: binanceService.flashDirection)

                        // Change Badge (Inline with price)
                        HStack(spacing: 3) {
                            Image(systemName: ticker.priceChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(ticker.formattedChangePercent)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(
                            (ticker.priceChangePercent >= 0 ? Color.green : Color.red).opacity(0.2)
                        )
                        .foregroundColor(ticker.priceChangePercent >= 0 ? .green : .red)
                        .clipShape(Capsule())

                        Spacer()
                    }
                    .frame(height: 22)

                    // 2-Row Stats Grid: Key Levels & Flow/Momentum
                    VStack(spacing: 5) {
                        // Row 1: Key Levels & Institutional Benchmark
                        HStack(spacing: 8) {
                            statColumn(title: "24h High", value: ticker.formattedHigh)
                            Divider().frame(height: 18).background(Color.white.opacity(0.12))
                            statColumn(title: "24h Low", value: ticker.formattedLow)
                            Divider().frame(height: 18).background(Color.white.opacity(0.12))
                            statColumn(title: "VWAP", value: ticker.formattedVWAP)
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Row 2: Real-time Flow & Taker Buy Pressure
                        HStack(spacing: 8) {
                            statColumn(title: "15m Vol", value: ticker.formattedQuoteVolume15m)
                            Divider().frame(height: 18).background(Color.white.opacity(0.12))
                            statColumn(title: "5m Vol", value: ticker.formattedQuoteVolume5m)
                            Divider().frame(height: 18).background(Color.white.opacity(0.12))
                            statColumn(
                                title: "5m Buy %",
                                value: ticker.formattedTakerBuyRatio5m,
                                valueColor: buyRatioColor(ticker.takerBuyRatio5m)
                            )
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
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Fetching Binance data...")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    private func statColumn(title: String, value: String, valueColor: Color = .white.opacity(0.92)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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

            // Favorites Grid (Dynamic user favorites, max 9)
            VStack(alignment: .leading, spacing: 6) {
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
                    Text("Star coins in the island (★) to save them here")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(settings.favorites, id: \.self) { favString in
                            let preset = CryptoSymbol.from(rawInput: favString)
                            let isCurrent = preset.symbol == binanceService.currentSymbol.symbol
                            Button {
                                binanceService.selectSymbol(preset)
                                customSymbolText = ""
                                showingCustomInput = false
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

            // Helper text (clean, no bullet dot)
            Text("Auto-appends USDT if omitted")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        showingCustomInput = false
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
