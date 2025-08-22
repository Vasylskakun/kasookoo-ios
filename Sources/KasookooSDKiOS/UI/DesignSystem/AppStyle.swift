import SwiftUI

// MARK: - Colors & Gradients
enum AppColors {
    // Green theme to match the provided design
    static let green = Color(red: 0.45, green: 0.73, blue: 0.60)     // button fill
    static let greenDark = Color(red: 0.24, green: 0.55, blue: 0.46) // header/gradient end
    static let greenLight = Color(red: 0.78, green: 0.91, blue: 0.85) // subtle accents if needed
    static let red = Color(red: 0.90, green: 0.23, blue: 0.31)
    static let cardStroke = Color.white.opacity(1.0)
    // Deep navy gradient for call screens
    static let callTop = Color(red: 0.07, green: 0.12, blue: 0.22)
    static let callBottom = Color(red: 0.02, green: 0.06, blue: 0.12)
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [AppColors.greenLight.opacity(0.35), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct CallBackground: View {
    var body: some View {
        LinearGradient(colors: [AppColors.callTop, AppColors.callBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [AppColors.green, AppColors.greenDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .shadow(color: AppColors.green.opacity(0.35), radius: 8, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardStroke, lineWidth: 1)
                    .background(Color.white.opacity(0.10).cornerRadius(14))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [AppColors.red, AppColors.red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .shadow(color: AppColors.red.opacity(0.35), radius: 8, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Input Style
struct InputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.cardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColors.cardStroke.opacity(0.7), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)
    }
    func appInputStyle() -> some View { modifier(InputFieldModifier()) }
}

// MARK: - Circular Buttons & Ring
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
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 3)
                .frame(width: baseDiameter * (animate ? 1.35 : 1.0), height: baseDiameter * (animate ? 1.35 : 1.0))
                .opacity(animate ? 0 : 1)
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 3)
                .frame(width: baseDiameter * (animate ? 1.2 : 1.0), height: baseDiameter * (animate ? 1.2 : 1.0))
                .opacity(animate ? 0 : 1)
        }
        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animate)
        .onAppear { animate = true }
    }
}


