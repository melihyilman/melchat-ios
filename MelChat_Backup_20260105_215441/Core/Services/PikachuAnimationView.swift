import SwiftUI

import SwiftUI

// MARK: - Helper Structs

struct SparkleParticle: Identifiable {
    let id = UUID()
    var offsetX: CGFloat
    var offsetY: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}

// MARK: - Pikachu Animation View
/// Clean, modern empty state animation - no complex shapes!
struct PikachuAnimationView: View {
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var sparkleOpacity: Double = 0
    
    let size: CGFloat
    let showMessage: Bool
    let message: String
    
    init(size: CGFloat = 120, showMessage: Bool = true, message: String = "No chats yet!") {
        self.size = size
        self.showMessage = showMessage
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: size * 0.3) {
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.15), .purple.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 1.2
                        )
                    )
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(pulseScale)
                
                // Floating chat bubbles stack (same as AnimatedCharacters.swift)
                ZStack {
                    // Back bubble (purple)
                    SimpleChatBubble(color: .purple.opacity(0.6))
                        .frame(width: size * 0.58, height: size * 0.42)
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        .offset(x: -size * 0.33, y: size * 0.25)
                        .rotationEffect(.degrees(-15))
                        .offset(y: floatOffset * 0.5)
                    
                    // Middle bubble (cyan)
                    SimpleChatBubble(color: .cyan.opacity(0.7))
                        .frame(width: size * 0.71, height: size * 0.5)
                        .shadow(color: .cyan.opacity(0.4), radius: 12, x: 0, y: 5)
                        .offset(x: size * 0.29, y: -size * 0.08)
                        .rotationEffect(.degrees(10))
                        .offset(y: floatOffset * 0.8)
                    
                    // Front bubble (main - blue) with dots
                    ZStack {
                        SimpleChatBubble(color: .blue)
                            .frame(width: size * 0.83, height: size * 0.58)
                            .shadow(color: .blue.opacity(0.5), radius: 15, x: 0, y: 8)
                        
                        // Animated typing dots
                        HStack(spacing: size * 0.067) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(.white)
                                    .frame(width: size * 0.083, height: size * 0.083)
                                    .scaleEffect(sparkleOpacity > 0 ? 1.0 : 0.4)
                                    .opacity(sparkleOpacity > 0 ? 1 : 0.4)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.15),
                                        value: sparkleOpacity
                                    )
                            }
                        }
                    }
                    .offset(y: floatOffset)
                    
                    // Sparkle particles
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(.yellow.opacity(0.6))
                            .frame(width: size * 0.067, height: size * 0.067)
                            .offset(
                                x: cos(Double(index) * .pi / 2 + .pi / 4) * size * 0.67,
                                y: sin(Double(index) * .pi / 2 + .pi / 4) * size * 0.67
                            )
                            .scaleEffect(sparkleOpacity > 0 ? 1.0 : 0.3)
                            .opacity(sparkleOpacity)
                            .animation(
                                .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: sparkleOpacity
                            )
                    }
                }
            }
            .frame(height: size * 1.5)
            
            // Message
            if showMessage {
                Text(message)
                    .font(.system(size: size * 0.16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            // Floating animation
            withAnimation(
                .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                floatOffset = -size * 0.083
            }
            
            // Pulse animation
            withAnimation(
                .easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.2
            }
            
            // Sparkle fade in
            withAnimation(.easeIn(duration: 0.5)) {
                sparkleOpacity = 0.8
            }
        }
    }
}

// MARK: - Simple Chat Bubble (Using Rounded Rectangle - Clean!)
struct SimpleChatBubble: View {
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Main rounded rectangle
                RoundedRectangle(cornerRadius: geometry.size.height * 0.3)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Small tail (simple circle cutout effect)
                Circle()
                    .fill(color)
                    .frame(width: geometry.size.width * 0.15, height: geometry.size.height * 0.15)
                    .offset(x: geometry.size.width * 0.08, y: geometry.size.height * 0.05)
            }
        }
    }
}

// MARK: - Pikachu Celebration (for message sent)
struct PikachuCelebrationView: View {
    @State private var scale: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    @State private var sparkles: [SparkleParticle] = []
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Pikachu face
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 4) {
                    // Happy eyes
                    HStack(spacing: 15) {
                        Text("^")
                            .font(.system(size: 20, weight: .bold))
                        Text("^")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .offset(y: -5)
                    
                    // Big smile
                    Text("⚡️")
                        .font(.system(size: 25))
                        .offset(y: 5)
                }
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            
            // Sparkle particles
            ForEach(sparkles) { sparkle in
                Image(systemName: "star.fill")
                    .font(.system(size: sparkle.size))
                    .foregroundStyle(sparkle.color)
                    .offset(x: sparkle.offsetX, y: sparkle.offsetY)
                    .opacity(sparkle.opacity)
            }
        }
        .onAppear {
            startCelebration()
        }
    }
    
    private func startCelebration() {
        // Pop in animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.2
        }
        
        // Rotate
        withAnimation(.easeInOut(duration: 0.5)) {
            rotation = 360
        }
        
        // Generate sparkles
        for i in 0..<12 {
            let angle = Double(i) * 30 * .pi / 180
            let distance: CGFloat = 40
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                let sparkle = SparkleParticle(
                    offsetX: cos(angle) * distance,
                    offsetY: sin(angle) * distance,
                    size: CGFloat.random(in: 15...25),
                    color: [Color.yellow, Color.orange, Color.red].randomElement()!,
                    opacity: 1.0
                )
                sparkles.append(sparkle)
                
                // Fade out sparkle
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    if let index = sparkles.firstIndex(where: { $0.id == sparkle.id }) {
                        sparkles[index].opacity = 0
                    }
                }
            }
        }
        
        // Scale down and fade out
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            scale = 0.8
            opacity = 0
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onComplete()
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        PikachuAnimationView(size: 120)
        
        PikachuAnimationView(size: 80, showMessage: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
}
