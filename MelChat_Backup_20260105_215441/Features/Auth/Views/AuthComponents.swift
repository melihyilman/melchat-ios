import SwiftUI

// MARK: - Feature Pill
struct FeaturePill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.15))
        )
        .foregroundStyle(.blue)
    }
}

// MARK: - Dynamic Auth ScrollView
/// Reusable scroll view that adapts when keyboard appears
/// - Shrinks logo/header when keyboard is visible
/// - Hides optional content to maximize input visibility
struct DynamicAuthScrollView<Content: View>: View {
    @Binding var isFocused: Bool
    let content: Content
    
    init(isFocused: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isFocused = isFocused
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    content
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Animated Auth Header
/// Reusable header with logo, title, and optional elements
/// - Automatically shrinks when keyboard appears
/// - Hides optional elements (subtitle, pills, character)
struct AnimatedAuthHeader: View {
    let title: String
    let subtitle: String?
    let logoIcon: String
    let showPills: Bool
    let showCharacter: Bool
    @Binding var isFocused: Bool
    @Binding var showContent: Bool
    @Binding var isLogoAnimating: Bool
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                Spacer()
                    .frame(height: isFocused ? geometry.size.height * 0.02 : geometry.size.height * 0.08)
                    .animation(.spring(response: 0.4), value: isFocused)
                
                // Animated Logo
                ZStack {
                    // Pulsing outer circle
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: isFocused ? 60 : 90, height: isFocused ? 60 : 90)
                        .scaleEffect(isLogoAnimating ? 1.2 : 1.0)
                        .opacity(isLogoAnimating ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: false),
                            value: isLogoAnimating
                        )
                    
                    // Main logo circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7), Color.cyan.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isFocused ? 50 : 70, height: isFocused ? 50 : 70)
                        .shadow(color: .blue.opacity(0.4), radius: 15, y: 8)
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .opacity(showContent ? 1.0 : 0)
                    
                    // Lock icon
                    Image(systemName: logoIcon)
                        .font(.system(size: isFocused ? 25 : 35))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(showContent ? 0 : -180))
                        .opacity(showContent ? 1.0 : 0)
                }
                .animation(.spring(response: 0.4), value: isFocused)

                // Title
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: isFocused ? 24 : 32, weight: .bold, design: .rounded))
                        .offset(y: showContent ? 0 : 15)
                        .opacity(showContent ? 1.0 : 0)
                        .animation(.spring(response: 0.4), value: isFocused)

                    if let subtitle = subtitle, !isFocused {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .offset(y: showContent ? 0 : 15)
                            .opacity(showContent ? 1.0 : 0)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                
                // Feature pills - hide on keyboard
                if showPills && !isFocused {
                    HStack(spacing: 8) {
                        FeaturePill(icon: "lock.fill", text: "E2E")
                        FeaturePill(icon: "eye.slash.fill", text: "Private")
                        FeaturePill(icon: "bolt.fill", text: "Fast")
                    }
                    .opacity(showContent ? 1.0 : 0)
                    .offset(y: showContent ? 0 : 15)
                    .transition(.opacity.combined(with: .scale))
                }
                
                // Welcome character - hide on keyboard
                if showCharacter && !isFocused {
                    WelcomeCharacter()
                        .scaleEffect(0.6)
                        .opacity(showContent ? 1.0 : 0)
                        .frame(height: 70)
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }
}

// MARK: - Auth Footer
/// Reusable footer with security badges
struct AuthFooter: View {
    @Binding var showContent: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("End-to-end encrypted")
                    .font(.caption.weight(.medium))
            }
            
            HStack(spacing: 4) {
                Image(systemName: "eye.slash.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("Your privacy is our priority")
                    .font(.caption.weight(.medium))
            }
        }
        .foregroundStyle(.secondary)
        .opacity(showContent ? 1.0 : 0)
    }
}
