import SwiftUI

// MARK: - Pikachu Image View
/// Real Pikachu character view - use PNG asset named "pikachu"
struct PikachuImageView: View {
    let size: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .opacity(isAnimating ? 0 : 0.8)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Pikachu image or fallback
            pikachuContent
                .rotationEffect(.degrees(isAnimating ? -3 : 3))
                .offset(y: isAnimating ? -5 : 5)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .shadow(color: Color.yellow.opacity(0.6), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    @ViewBuilder
    private var pikachuContent: some View {
        if UIImage(named: "pikachu") != nil {
            Image("pikachu")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback: Lightning emoji
            Text("⚡️")
                .font(.system(size: size * 0.8))
        }
    }
}

// MARK: - Animated Characters & Empty States

/// Animated Pikachu-style character for welcome screens
struct WelcomeCharacter: View {
    @State private var isWaving = false
    @State private var isJumping = false
    @State private var showSparkles = false
    
    var body: some View {
        ZStack {
            // Sparkles around character
            if showSparkles {
                ForEach(0..<6, id: \.self) { index in
                    SimpleSparkle()
                        .offset(
                            x: cos(Double(index) * .pi / 3) * 60,
                            y: sin(Double(index) * .pi / 3) * 60
                        )
                        .opacity(showSparkles ? 1 : 0)
                        .scaleEffect(showSparkles ? 1 : 0)
                        .animation(
                            .easeOut(duration: 0.5).delay(Double(index) * 0.1),
                            value: showSparkles
                        )
                }
            }
            
            VStack(spacing: 8) {
                // Character head
                ZStack {
                    // Face
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .yellow.opacity(0.5), radius: 10)
                    
                    // Eyes
                    HStack(spacing: 20) {
                        Circle()
                            .fill(.black)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(.black)
                            .frame(width: 8, height: 8)
                    }
                    .offset(y: -5)
                    
                    // Smile
                    Arc(startAngle: .degrees(10), endAngle: .degrees(170))
                        .stroke(.black, lineWidth: 2)
                        .frame(width: 30, height: 20)
                        .offset(y: 10)
                    
                    // Cheeks (blush)
                    HStack(spacing: 50) {
                        Circle()
                            .fill(.pink.opacity(0.6))
                            .frame(width: 12, height: 12)
                        Circle()
                            .fill(.pink.opacity(0.6))
                            .frame(width: 12, height: 12)
                    }
                }
                .offset(y: isJumping ? -10 : 0)
                .animation(
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: isJumping
                )
                
                // Waving hand
                Text("👋")
                    .font(.system(size: 40))
                    .rotationEffect(.degrees(isWaving ? 20 : -20))
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: isWaving
                    )
            }
        }
        .onAppear {
            withAnimation {
                isWaving = true
                isJumping = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showSparkles = true
                }
            }
        }
    }
}

/// Empty chat list state
struct EmptyChatState: View {
    @State private var isAnimating = false
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    var onNewChatTap: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 30) {
            // Animated floating chat bubbles stack
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.15), .yellow.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                // Stack of floating bubbles
                ZStack {
                    // Back bubble (purple)
                    ChatBubbleShape()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 50)
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        .offset(x: -40, y: 30)
                        .rotationEffect(.degrees(-15))
                        .scaleEffect(isAnimating ? 1.0 : 0.95)
                        .offset(y: floatOffset * 0.5)
                    
                    // Middle bubble (cyan)
                    ChatBubbleShape()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .cyan.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 85, height: 60)
                        .shadow(color: .cyan.opacity(0.4), radius: 12, x: 0, y: 5)
                        .offset(x: 35, y: -10)
                        .rotationEffect(.degrees(10))
                        .scaleEffect(isAnimating ? 1.0 : 0.92)
                        .offset(y: floatOffset * 0.8)
                    
                    // Front bubble (main - orange)
                    ZStack {
                        ChatBubbleShape()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 70)
                            .shadow(color: .orange.opacity(0.5), radius: 15, x: 0, y: 8)
                        
                        // Animated dots inside
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(.white)
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(isAnimating ? 1.0 : 0.4)
                                    .opacity(isAnimating ? 1 : 0.4)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.15),
                                        value: isAnimating
                                    )
                            }
                        }
                    }
                    .offset(y: floatOffset)
                    
                    // Sparkles
                    if isAnimating {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(.yellow.opacity(0.6))
                                .frame(width: 8, height: 8)
                                .offset(
                                    x: cos(Double(index) * .pi / 2 + .pi / 4) * 80,
                                    y: sin(Double(index) * .pi / 2 + .pi / 4) * 80
                                )
                                .scaleEffect(isAnimating ? 1.0 : 0.3)
                                .opacity(isAnimating ? 0.8 : 0)
                                .animation(
                                    .easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                }
                .offset(y: floatOffset)
            }
            
            // Text
            VStack(spacing: 12) {
                Text("No Chats Yet")
                    .font(.title2.bold())
                
                Text("Start a conversation by searching\nfor users and sending a message!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Action button
            Button {
                HapticManager.shared.light()
                onNewChatTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.bubble.fill")
                    Text("New Chat")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .orange.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
        .onAppear {
            isAnimating = true
            
            // Floating animation
            withAnimation(
                .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                floatOffset = -10
            }
            
            // Pulse animation
            withAnimation(
                .easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.2
            }
        }
    }
}

// MARK: - Chat Bubble Shape (Clean & Professional)
struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let cornerRadius = rect.height * 0.3
        let tailWidth = rect.width * 0.15
        let tailHeight = rect.height * 0.2
        
        // Start from top-left
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        
        // Top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: cornerRadius),
            control: CGPoint(x: rect.maxX, y: 0)
        )
        
        // Right side to tail start
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius - tailHeight))
        
        // Tail (bottom-right)
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius + tailWidth, y: rect.maxY - tailHeight),
            control: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius - tailHeight)
        )
        path.addLine(to: CGPoint(x: rect.maxX + tailWidth * 0.5, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - tailHeight * 0.3))
        
        // Bottom side
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.maxY - tailHeight * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - cornerRadius - tailHeight * 0.3),
            control: CGPoint(x: 0, y: rect.maxY - tailHeight * 0.3)
        )
        
        // Left side
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        
        return path
    }
}

/// Empty messages state (inside a chat)
struct EmptyMessagesState: View {
    let userName: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Lock shield animation
            ZStack {
                // Pulsing shield
                Image(systemName: "shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .green.opacity(0.3), radius: 20)
                
                // Lock overlay
                Image(systemName: "lock.fill")
                    .font(.system(size: 35))
                    .foregroundStyle(.white)
                    .offset(y: 5)
                
                // Sparkle effect
                Circle()
                    .stroke(lineWidth: 2)
                    .fill(.green.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .scaleEffect(isAnimating ? 1.05 : 0.95)
            .animation(
                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            
            VStack(spacing: 12) {
                Text("Secure Chat with \(userName)")
                    .font(.title3.bold())
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("End-to-end encrypted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Your messages are private and secure.\nOnly you and \(userName) can read them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
        .onAppear {
            isAnimating = true
        }
    }
}

/// Confetti animation for successful actions
struct ConfettiView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { index in
                ConfettiPiece()
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: isAnimating ? 600 : -50
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeIn(duration: Double.random(in: 1.0...2.0))
                            .delay(Double(index) * 0.02),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Helper Shapes

struct SimpleSparkle: View {
    var body: some View {
        // Use star.fill for compatibility (sparkle is iOS 16+)
        Image(systemName: "star.fill")
            .font(.title2)
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    var centerY: CGFloat = 0.5 // 0.0 = top, 0.5 = middle, 1.0 = bottom (as ratio)
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerYPosition = rect.minY + (rect.height * centerY)
        path.addArc(
            center: CGPoint(x: rect.midX, y: centerYPosition),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ConfettiPiece: View {
    let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
    let randomColor: Color
    let randomSize: CGFloat
    
    init() {
        randomColor = colors.randomElement() ?? .blue
        randomSize = CGFloat.random(in: 8...15)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(randomColor)
            .frame(width: randomSize, height: randomSize)
    }
}

// MARK: - Loading State Character

struct LoadingCharacter: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Spinning message icon
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .fill(.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.0).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                Image(systemName: "message.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Success Animation

struct SimpleSuccessCheckmark: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.green)
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0)
            
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(isAnimating ? 1.0 : 0.3)
                .opacity(isAnimating ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}
