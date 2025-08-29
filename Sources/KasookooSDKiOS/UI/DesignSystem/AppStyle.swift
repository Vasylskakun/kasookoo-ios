import SwiftUI

// MARK: - Modern Color Palette
enum AppColors {
    // Primary Brand Colors - Modern Teal/Purple gradient
    static let primary = Color(red: 0.22, green: 0.56, blue: 0.87)      // Vibrant blue
    static let primaryLight = Color(red: 0.35, green: 0.71, blue: 0.93) // Lighter blue
    static let primaryDark = Color(red: 0.15, green: 0.42, blue: 0.67)  // Darker blue

    // Secondary Colors - Warm accent
    static let secondary = Color(red: 0.95, green: 0.61, blue: 0.07)    // Warm orange
    static let secondaryLight = Color(red: 1.0, green: 0.75, blue: 0.27) // Light orange

    // Semantic Colors
    static let success = Color(red: 0.22, green: 0.75, blue: 0.42)      // Green success
    static let error = Color(red: 0.92, green: 0.32, blue: 0.35)        // Red error
    static let warning = Color(red: 0.95, green: 0.61, blue: 0.07)      // Orange warning

    // Neutral Colors
    static let background = Color(red: 0.98, green: 0.98, blue: 0.99)   // Off-white
    static let surface = Color.white
    static let surfaceSecondary = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.13)   // Dark gray
    static let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.57) // Medium gray
    static let textTertiary = Color(red: 0.75, green: 0.75, blue: 0.76)  // Light gray

    // Call Screen Colors - Modern dark theme
    static let callTop = Color(red: 0.08, green: 0.08, blue: 0.12)      // Deep navy
    static let callBottom = Color(red: 0.03, green: 0.03, blue: 0.06)   // Deeper navy
    static let callAccent = Color(red: 0.22, green: 0.56, blue: 0.87)   // Blue accent

    // Shadows
    static let shadowLight = Color.black.opacity(0.08)
    static let shadowMedium = Color.black.opacity(0.12)
    static let shadowHeavy = Color.black.opacity(0.16)

    // Legacy support (keeping old names for compatibility)
    static let green = primary
    static let greenDark = primaryDark
    static let greenLight = primaryLight
    static let red = error
    static let cardStroke = Color.white.opacity(0.8)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    AppColors.primaryLight.opacity(0.08),
                    AppColors.secondaryLight.opacity(0.05),
                    AppColors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle pattern overlay
            GeometryReader { geo in
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.7))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: height * 0.3),
                        control: CGPoint(x: width * 0.5, y: height * 0.8)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(AppColors.primaryLight.opacity(0.03))
            }
        }
        .ignoresSafeArea()
    }
}

struct CallBackground: View {
    var body: some View {
        ZStack {
            // Rich gradient for call screens
            LinearGradient(
                colors: [
                    AppColors.callTop,
                    AppColors.callBottom,
                    AppColors.callTop.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle accent overlay
            Circle()
                .fill(AppColors.callAccent.opacity(0.03))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(y: -100)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Modern Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: configuration.isPressed ?
                            [AppColors.primaryDark, AppColors.primaryDark.opacity(0.8)] :
                            [AppColors.primary, AppColors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Shimmer effect when pressed
                    if configuration.isPressed {
                        Color.white.opacity(0.1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(
                color: configuration.isPressed ? AppColors.shadowHeavy : AppColors.shadowMedium,
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .opacity(isLoading ? 0.7 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.surface)
                        .shadow(color: AppColors.shadowLight, radius: 2, x: 0, y: 1)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            configuration.isPressed ?
                                AppColors.primary.opacity(0.3) :
                                AppColors.textTertiary.opacity(0.2),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: configuration.isPressed ?
                        [AppColors.error.opacity(0.8), AppColors.error.opacity(0.6)] :
                        [AppColors.error, AppColors.error.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(
                color: configuration.isPressed ? AppColors.shadowHeavy : AppColors.shadowMedium,
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct CallButtonStyle: ButtonStyle {
    let style: CallButtonType

    enum CallButtonType {
        case accept, decline, end
    }

    func makeBody(configuration: Configuration) -> some View {
        let (color, iconColor) = buttonColors(for: style)

        ZStack {
            Circle()
                .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
                .frame(width: 72, height: 72)
                .shadow(
                    color: color.opacity(0.4),
                    radius: configuration.isPressed ? 8 : 12,
                    x: 0,
                    y: configuration.isPressed ? 4 : 6
                )

            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: 72, height: 72)

            configuration.label
                .foregroundColor(iconColor)
        }
        .scaleEffect(configuration.isPressed ? 0.9 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }

    private func buttonColors(for style: CallButtonType) -> (Color, Color) {
        switch style {
        case .accept:
            return (AppColors.success, .white)
        case .decline:
            return (AppColors.error, .white)
        case .end:
            return (AppColors.error, .white)
        }
    }
}

// MARK: - Modern Input & Card Styles
struct ModernInputFieldModifier: ViewModifier {
    @State private var isFocused = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.surface)
                        .shadow(
                            color: isFocused ? AppColors.primary.opacity(0.1) : AppColors.shadowLight,
                            radius: isFocused ? 8 : 4,
                            x: 0,
                            y: isFocused ? 4 : 2
                        )

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isFocused ? AppColors.primary.opacity(0.4) : AppColors.textTertiary.opacity(0.2),
                            lineWidth: isFocused ? 2 : 1
                        )
                }
            )
            .font(.system(size: 16, design: .rounded))
            .foregroundColor(AppColors.textPrimary)
            .onAppear {
                // This is a simplified approach - in a real app you'd use FocusState
            }
    }
}

struct ModernCardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppColors.surface)
                        .shadow(
                            color: AppColors.shadowLight,
                            radius: 8,
                            x: 0,
                            y: 4
                        )

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColors.textTertiary.opacity(0.1), lineWidth: 1)
                }
            )
    }
}

struct LoadingButtonModifier: ViewModifier {
    var isLoading: Bool

    func body(content: Content) -> some View {
        ZStack {
            content.opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
        }
    }
}

// Extension for easy use
extension View {
    func modernInputStyle() -> some View {
        modifier(ModernInputFieldModifier())
    }

    func modernCard(padding: CGFloat = 20) -> some View {
        modifier(ModernCardModifier(padding: padding))
    }

    func withLoadingOverlay(isLoading: Bool) -> some View {
        modifier(LoadingButtonModifier(isLoading: isLoading))
    }

    // Legacy support
    func appCard() -> some View {
        modernCard(padding: 16)
    }

    func appInputStyle() -> some View {
        modernInputStyle()
    }
}

// MARK: - Enhanced UI Components
struct ModernPulsingRings: View {
    var color: Color = .white
    var baseDiameter: CGFloat = 140
    @State private var animate = false
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            color.opacity(0.1),
                            color.opacity(0.3),
                            color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: baseDiameter * scale, height: baseDiameter * scale)
                .opacity(animate ? 0.3 : 0.8)

            // Middle ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            color.opacity(0.2),
                            color.opacity(0.5),
                            color.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: baseDiameter * 0.8 * scale, height: baseDiameter * 0.8 * scale)
                .opacity(animate ? 0.5 : 1.0)

            // Inner ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            color.opacity(0.4),
                            color.opacity(0.8),
                            color.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: baseDiameter * 0.6 * scale, height: baseDiameter * 0.6 * scale)
                .opacity(animate ? 0.8 : 1.0)
        }
        .animation(
            Animation
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true),
            value: scale
        )
        .onAppear {
            animate = true
            scale = 1.2
        }
    }
}

struct LoadingSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear { isAnimating = true }
    }
}

struct SuccessCheckmark: View {
    @State private var scale: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.success.opacity(0.2))
                .frame(width: 60, height: 60)

            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.success)
                .scaleEffect(scale)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: scale)
        }
        .onAppear { scale = 1 }
    }
}

// Legacy support
struct RoundButtonStyle: ButtonStyle {
    let diameter: CGFloat
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundColor(foreground)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct PulsingRings: View {
    var color: Color = .white
    var baseDiameter: CGFloat = 120

    var body: some View {
        ModernPulsingRings(color: color, baseDiameter: baseDiameter)
    }
}

// MARK: - Modern Action Card
struct ModernActionCard: View {
    var icon: String
    var iconColor: Color
    var title: String
    var subtitle: String
    var buttonText: String
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and text
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Action Button
            Button(action: action) {
                HStack {
                    if isLoading {
                        LoadingSpinner()
                            .frame(width: 20, height: 20)
                    }
                    Text(buttonText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
            .disabled(isLoading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.surface)
                .shadow(
                    color: AppColors.shadowLight,
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.textTertiary.opacity(0.1), lineWidth: 1)
        )
    }
}


