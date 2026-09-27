import SwiftUI

/// "U" notch shape: flat top against bezel, rounded bottom corners.
public struct NotchShape: Shape {
    public var bottomRadius: CGFloat

    public var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    public init(bottomRadius: CGFloat) {
        self.bottomRadius = bottomRadius
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

    public init(bottomRadius: CGFloat) {
        self.bottomRadius = bottomRadius
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

    public init() {}

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
