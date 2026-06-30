import SwiftUI

// MARK: - Price flash

/// Briefly flashes the background green or red with a soft emerald-tinted
/// edge glow when the bound value changes, giving a live price-flash effect.
/// The fill uses the semantic positive/negative colors; the edge glow is a
/// subtle emerald-tinted halo so the flash feels alive without being garish.
struct PriceFlashModifier: ViewModifier {
    let value: Double?
    @State private var oldValue: Double?
    @State private var flashColor: Color = .clear
    @State private var flashOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(flashColor)
                    .opacity(flashOpacity)
                    .allowsHitTesting(false)
            )
            // Emerald-tinted edge glow on flash — a soft colored shadow that
            // reads as "this just ticked" beyond the flat background fill.
            .shadow(color: flashColor.opacity(flashOpacity * 0.7),
                    radius: 6, x: 0, y: 0)
            .onChange(of: value) { _, newValue in
                guard let newValue, let oldValue, oldValue != newValue else { return }
                flashColor = newValue > oldValue ? Theme.Colors.positive : Theme.Colors.negative
                withAnimation(.easeOut(duration: 0.15)) {
                    flashOpacity = 0.22
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                    flashOpacity = 0
                }
                self.oldValue = newValue
            }
            .onAppear { oldValue = value }
    }
}

extension View {
    func priceFlash(_ value: Double?) -> some View {
        modifier(PriceFlashModifier(value: value))
    }
}

// MARK: - Shimmer loading modifier

/// Shimmer effect for skeleton loading states. Monochrome white sweep.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // Reduced motion: a static dimmed overlay instead of a sweep.
            content
                .overlay(Theme.Colors.textPrimary.opacity(0.06).allowsHitTesting(false))
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                Theme.Colors.textPrimary.opacity(0.12),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                        .blur(radius: 6)
                    }
                    .allowsHitTesting(false)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Appear animation modifier

/// Choreography variety for `appearAnimation`.
enum AppearVariety {
    case fade
    case slide
    case rise
    case scale
    case blur
}

private struct FadeModifier: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0)
            .onAppear {
                if reduceMotion { appeared = true }
                else { withAnimation(Theme.Animation.gentle) { appeared = true } }
            }
    }
}
private struct SlideModifier: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0).offset(x: appeared ? 0 : (reduceMotion ? 0 : 24))
            .onAppear {
                if reduceMotion { appeared = true }
                else { withAnimation(Theme.Animation.gentle) { appeared = true } }
            }
    }
}
private struct RiseModifier: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : (reduceMotion ? 0 : 18))
            .onAppear {
                if reduceMotion { appeared = true }
                else { withAnimation(Theme.Animation.gentle.delay(Double(index) * 0.05)) { appeared = true } }
            }
    }
}
private struct ScaleModifier: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0).scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.94))
            .onAppear {
                if reduceMotion { appeared = true }
                else { withAnimation(Theme.Animation.lively) { appeared = true } }
            }
    }
}
private struct BlurModifier: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0).blur(radius: appeared ? 0 : (reduceMotion ? 0 : 6))
            .onAppear {
                if reduceMotion { appeared = true }
                else { withAnimation(Theme.Animation.gentle) { appeared = true } }
            }
    }
}

/// Slides/fades content in on appear. Variety selects choreography;
/// `index` staggers sibling items (default 0.05s apart).
struct AppearAnimationModifier: ViewModifier {
    let variety: AppearVariety
    let index: Int

    func body(content: Content) -> some View {
        switch variety {
        case .fade:
            content.modifier(FadeModifier())
        case .slide:
            content.modifier(SlideModifier())
        case .rise:
            content.modifier(RiseModifier(index: index))
        case .scale:
            content.modifier(ScaleModifier())
        case .blur:
            content.modifier(BlurModifier())
        }
    }
}

extension View {
    /// Rise-and-fade in (the default, preserves existing call-site behavior).
    func appearAnimation(_ index: Int = 0) -> some View {
        modifier(AppearAnimationModifier(variety: .rise, index: index))
    }

    /// Appear with a chosen choreography. Stagger via `index`.
    func appearAnimation(_ variety: AppearVariety, index: Int = 0) -> some View {
        modifier(AppearAnimationModifier(variety: variety, index: index))
    }
}

// MARK: - Staggered appear (for list sections)

/// Staggered appear for sequential list/grid items. Items reveal
/// themselves in order as they enter the scroll viewport, producing a
/// choreographed cascade without hard-coded delays piling up.
struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let start: Double
    let delay: Double
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (reduceMotion ? 0 : 14))
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(
                        Theme.Animation.gentle.delay(start + Double(index) * delay)
                    ) { appeared = true }
                }
            }
    }
}

extension View {
    /// Staggered reveal. Items animate in with a small per-item delay.
    func staggeredAppear(index: Int = 0, start: Double = 0.05, delay: Double = 0.04) -> some View {
        modifier(StaggeredAppearModifier(index: index, start: start, delay: delay))
    }
}

// MARK: - Glow modifier

/// Adds a soft glow behind the view. Used only for red/green semantic emphasis.
struct GlowModifier: ViewModifier {
    let color: Color
    var radius: CGFloat = 12
    var opacity: Double = 0.4

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 12, opacity: Double = 0.4) -> some View {
        modifier(GlowModifier(color: color, radius: radius, opacity: opacity))
    }
}

// MARK: - Press scale modifier

/// Scale down slightly on press — for tappable cards/rows. Includes light haptic
/// plus a subtle shadow lift for a sense of depth.
struct PressScaleModifier: ViewModifier {
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // Reduced motion: keep the haptic, drop the scale animation.
            content
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed { Haptics.light() }
                            isPressed = true
                        }
                        .onEnded { _ in isPressed = false }
                )
        } else {
            content
                .scaleEffect(isPressed ? 0.97 : 1.0)
                .animation(Theme.Animation.snappy, value: isPressed)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed { Haptics.light() }
                            isPressed = true
                        }
                        .onEnded { _ in isPressed = false }
                )
        }
    }
}

extension View {
    func pressScale() -> some View {
        modifier(PressScaleModifier())
    }
}

// MARK: - Interactive card modifier

/// Convenience that bundles press-reactive scale + an opt-in scroll-transition
/// tilt/scale so cards living in a scroll view feel physically connected.
struct InteractiveCardModifier: ViewModifier {
    var tiltOnScroll: Bool = false

    func body(content: Content) -> some View {
        if tiltOnScroll {
            content
                .modifier(PressScaleModifier())
                .scrollTransition { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        .opacity(phase.isIdentity ? 1 : 0.85)
                }
        } else {
            content.modifier(PressScaleModifier())
        }
    }
}

extension View {
    /// Interactive card: press-scale + optional scroll-linked scale/opacity.
    func interactiveCard(tiltOnScroll: Bool = false) -> some View {
        modifier(InteractiveCardModifier(tiltOnScroll: tiltOnScroll))
    }
}