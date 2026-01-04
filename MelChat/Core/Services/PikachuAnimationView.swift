import SwiftUI

// MARK: - Pikachu Animation View
/// A cute Pikachu animation that can be used throughout the app
struct PikachuAnimationView: View {
    @State private var isAnimating = false
    @State private var showSparkles = false
    @State private var bounce = false
    @State private var rotation: Double = 0
    
    let size: CGFloat
    let showMessage: Bool
    let message: String
    
    init(size: CGFloat = 120, showMessage: Bool = true, message: String = "No chats yet!") {
        self.size = size
        self.showMessage = showMessage
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Sparkle effects
                if showSparkles {
                    ForEach(0..<6) { index in
                        SparkleView(index: index)
                            .offset(
                                x: cos(Double(index) * .pi / 3) * (size * 0.8),
                                y: sin(Double(index) * .pi / 3) * (size * 0.8)
                            )
                    }
                }
                
                // Pikachu body
                ZStack {
                    // Shadow
                    Ellipse()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: size * 0.8, height: size * 0.3)
                        .offset(y: size * 0.5)
                        .scaleEffect(bounce ? 0.9 : 1.0)
                    
                    // Main body
                    VStack(spacing: 0) {
                        // Ears
                        HStack(spacing: size * 0.4) {
                            PikachuEar(size: size * 0.3, isLeft: true)
                                .rotationEffect(.degrees(isAnimating ? -10 : -5))
                            
                            PikachuEar(size: size * 0.3, isLeft: false)
                                .rotationEffect(.degrees(isAnimating ? 10 : 5))
                        }
                        .offset(y: size * 0.05)
                        
                        // Head
                        ZStack {
                            // Face circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.yellow.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: size, height: size)
                                .shadow(color: .orange.opacity(0.3), radius: 10, y: 5)
                            
                            // Face features
                            VStack(spacing: size * 0.15) {
                                // Eyes
                                HStack(spacing: size * 0.35) {
                                    PikachuEye(size: size * 0.15)
                                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    
                                    PikachuEye(size: size * 0.15)
                                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                                }
                                .offset(y: -size * 0.05)
                                
                                // Cheeks
                                HStack(spacing: size * 0.45) {
                                    Circle()
                                        .fill(Color.red.opacity(0.7))
                                        .frame(width: size * 0.2, height: size * 0.2)
                                    
                                    Circle()
                                        .fill(Color.red.opacity(0.7))
                                        .frame(width: size * 0.2, height: size * 0.2)
                                }
                                .offset(y: size * 0.05)
                                
                                // Mouth
                                PikachuMouth(size: size * 0.25)
                                    .offset(y: size * 0.08)
                            }
                        }
                        .offset(y: -size * 0.08)
                    }
                    .offset(y: bounce ? -10 : 0)
                }
                .rotationEffect(.degrees(rotation))
            }
            .frame(width: size * 1.8, height: size * 1.8)
            
            if showMessage {
                Text(message)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1 : 0)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Main bounce animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isAnimating = true
            bounce = true
        }
        
        // Sparkles
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.2)) {
            showSparkles = true
        }
        
        // Slight rotation wiggle
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            rotation = 3
        }
    }
}

// MARK: - Pikachu Components

struct PikachuEar: View {
    let size: CGFloat
    let isLeft: Bool
    
    var body: some View {
        ZStack(alignment: isLeft ? .bottomTrailing : .bottomLeading) {
            // Outer ear (yellow)
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(Color.yellow)
                .frame(width: size * 0.5, height: size)
                .rotationEffect(.degrees(isLeft ? 20 : -20))
            
            // Inner ear (black tip)
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(Color.black)
                .frame(width: size * 0.4, height: size * 0.35)
                .offset(x: isLeft ? -size * 0.05 : size * 0.05, y: -size * 0.35)
        }
    }
}

struct PikachuEye: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
            
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: -size * 0.15, y: -size * 0.15)
        }
    }
}

struct PikachuMouth: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Smile curve
            Path { path in
                path.addArc(
                    center: CGPoint(x: size / 2, y: 0),
                    radius: size * 0.8,
                    startAngle: .degrees(30),
                    endAngle: .degrees(150),
                    clockwise: false
                )
            }
            .stroke(Color.black, lineWidth: size * 0.15)
            
            // Small nose
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.2, height: size * 0.15)
                .offset(y: -size * 0.3)
        }
        .frame(width: size, height: size * 0.6)
    }
}

struct SparkleView: View {
    let index: Int
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 20))
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1)
                ) {
                    scale = 1.0
                    opacity = 1.0
                }
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
