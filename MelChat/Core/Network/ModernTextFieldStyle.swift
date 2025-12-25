import SwiftUI

// MARK: - Modern TextField Style (Dark Mode Optimized)

struct ModernTextFieldStyle: ViewModifier {
    let icon: String
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isFocused ? .blue : .secondary)
                .frame(width: 24)
            
            content
                .textFieldStyle(.plain)
        }
        .padding()
        .background(
            ZStack {
                // Dark mode: Slightly elevated background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                
                // Light mode: White with shadow
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    .blendMode(.normal)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isFocused ? 
                        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isFocused ? 2 : 1
                )
        )
    }
}

extension View {
    func modernTextField(icon: String, isFocused: Bool) -> some View {
        modifier(ModernTextFieldStyle(icon: icon, isFocused: isFocused))
    }
}

// MARK: - Modern Button Style

struct ModernButtonStyle: ButtonStyle {
    let color: Color
    let isDisabled: Bool
    
    init(color: Color, isDisabled: Bool = false) {
        self.color = color
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isDisabled {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.3))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
            }
            .foregroundStyle(.white)
            .font(.headline)
            .shadow(
                color: isDisabled ? .clear : color.opacity(0.4),
                radius: 12,
                y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Section Header Style

struct ModernSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(1)
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
            
            Text(message)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.red)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Glassmorphic Card

struct GlassmorphicCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        Color(.secondarySystemBackground)
                            .opacity(0.8)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }
}
