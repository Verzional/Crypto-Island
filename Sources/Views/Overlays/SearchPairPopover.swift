import SwiftUI

/// Popover sheet for searching coin symbols and picking from pinned favorites.
public struct SearchPairPopover: View {
    @ObservedObject var binanceService: BinanceService
    @ObservedObject var settings: SettingsModel
    @Binding var isPresented: Bool

    @State private var customSymbolText: String = ""
    @FocusState private var isSearchFocused: Bool

    public init(
        binanceService: BinanceService,
        settings: SettingsModel,
        isPresented: Binding<Bool>
    ) {
        self.binanceService = binanceService
        self.settings = settings
        self._isPresented = isPresented
    }

    public var body: some View {
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
                                isPresented = false
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
        isPresented = false
    }
}
