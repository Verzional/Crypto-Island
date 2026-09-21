import SwiftUI

/// The SwiftUI view representing the macOS Dynamic Island for crypto prices.
public struct DynamicIslandView: View {
    @ObservedObject var binanceService: BinanceService
    @ObservedObject var settings: SettingsModel
    @Binding var isExpanded: Bool

    @State private var showingCustomInput: Bool = false
    @State private var customSymbolText: String = ""
    @State private var isHovered: Bool = false

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
        ZStack {
            if isExpanded {
                expandedView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                    ))
            } else {
                collapsedView
                    .transition(.opacity)
            }
        }
        .frame(
            width: isExpanded ? 400 : (settings.stealthMode && !isHovered ? 140 : 230),
            height: isExpanded ? 180 : (settings.stealthMode && !isHovered ? 16 : 38)
        )
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: isExpanded ? 30 : 19, style: .continuous)
                    .fill(Color.black.opacity(settings.stealthMode && !isHovered && !isExpanded ? 0.25 : 0.92))
                
                RoundedRectangle(cornerRadius: isExpanded ? 30 : 19, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isExpanded ? 0.22 : 0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 30 : 19, style: .continuous))
        .shadow(color: Color.black.opacity(isExpanded ? 0.5 : 0.3), radius: isExpanded ? 20 : 10, x: 0, y: 8)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                if !isExpanded {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                        isExpanded = true
                    }
                }
            } else {
                if !settings.isPinned {
                    DispatchQueue.main.asyncAfter(deadline: .now() + settings.autoCollapseDelay) {
                        if !isHovered && !settings.isPinned && !showingCustomInput {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                                isExpanded = false
                            }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isExpanded)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: binanceService.flashDirection)
    }

    // MARK: - Collapsed View
    private var collapsedView: some View {
        HStack(spacing: 8) {
            if settings.stealthMode && !isHovered {
                // Sleek minimal indicator in stealth mode
                Circle()
                    .fill(liveColor)
                    .frame(width: 6, height: 6)
                Text(binanceService.currentSymbol.baseAsset)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                // Regular compact island
                Image(systemName: binanceService.currentSymbol.iconSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(liveColor)

                Text(binanceService.currentSymbol.baseAsset)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer(minLength: 4)

                if let ticker = binanceService.ticker {
                    Text(ticker.formattedPrice)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(flashColor(for: ticker))

                    Circle()
                        .fill(liveColor)
                        .frame(width: 6, height: 6)
                } else {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Expanded View
    private var expandedView: some View {
        VStack(spacing: 10) {
            // Header Row
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: binanceService.currentSymbol.iconSymbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(liveColor)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(binanceService.currentSymbol.baseAsset)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ " + binanceService.currentSymbol.quoteAsset)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    Text(binanceService.currentSymbol.name)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Live status dot
                HStack(spacing: 4) {
                    Circle()
                        .fill(binanceService.isConnected ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(binanceService.isConnected ? "BINANCE LIVE" : "CONNECTING")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(binanceService.isConnected ? .green.opacity(0.9) : .orange.opacity(0.9))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                // Pin toggle button
                Button {
                    settings.isPinned.toggle()
                } label: {
                    Image(systemName: settings.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(settings.isPinned ? .yellow : .white.opacity(0.6))
                        .padding(5)
                        .background(Color.white.opacity(settings.isPinned ? 0.15 : 0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(settings.isPinned ? "Unpin (auto-collapse when mouse leaves)" : "Pin Island open")

                // Stealth mode toggle
                Button {
                    settings.stealthMode.toggle()
                } label: {
                    Image(systemName: settings.stealthMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(settings.stealthMode ? .cyan : .white.opacity(0.6))
                        .padding(5)
                        .background(Color.white.opacity(settings.stealthMode ? 0.15 : 0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Stealth mode: hides collapsed pill until hovered")

                // Collapse button
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(5)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Price & 24h Change Row
            if let ticker = binanceService.ticker {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(ticker.formattedPrice)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(flashColor(for: ticker))
                        .animation(.easeInOut(duration: 0.25), value: binanceService.flashDirection)

                    Spacer()

                    // Change Badge
                    HStack(spacing: 3) {
                        Image(systemName: ticker.priceChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(ticker.formattedChangePercent)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (ticker.priceChangePercent >= 0 ? Color.green : Color.red).opacity(0.2)
                    )
                    .foregroundColor(ticker.priceChangePercent >= 0 ? .green : .red)
                    .clipShape(Capsule())
                }

                // 24h Stats Row
                HStack(spacing: 12) {
                    statColumn(title: "24h High", value: ticker.formattedHigh)
                    Divider().frame(height: 18).background(Color.white.opacity(0.15))
                    statColumn(title: "24h Low", value: ticker.formattedLow)
                    Divider().frame(height: 18).background(Color.white.opacity(0.15))
                    statColumn(title: "24h Vol", value: ticker.formattedQuoteVolume)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Fetching Binance data...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }

            // Quick Coin Switcher Pills
            HStack(spacing: 6) {
                ForEach(CryptoSymbol.presets.prefix(5)) { symbol in
                    Button {
                        binanceService.selectSymbol(symbol)
                    } label: {
                        Text(symbol.baseAsset)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                binanceService.currentSymbol.symbol == symbol.symbol
                                    ? Color.white.opacity(0.25)
                                    : Color.white.opacity(0.06)
                            )
                            .foregroundColor(
                                binanceService.currentSymbol.symbol == symbol.symbol
                                    ? .white
                                    : .white.opacity(0.7)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Add / Custom symbol button
                Button {
                    showingCustomInput.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.8))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingCustomInput) {
                    customSymbolInputView
                }
            }
        }
        .padding(14)
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Custom Symbol Input View
    private var customSymbolInputView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Binance Pair")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)

            HStack {
                TextField("e.g. SOL, PEPE, SUI", text: $customSymbolText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        commitCustomSymbol()
                    }

                Button("Go") {
                    commitCustomSymbol()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Automatically appends USDT if omitted")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 220)
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
