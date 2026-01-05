import SwiftUI

// MARK: - Message Animations

extension View {
    /// Slide in from bottom with fade
    func messageEnterAnimation(delay: Double = 0) -> some View {
        self
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                removal: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay), value: UUID())
    }
    
    /// Swipe action gesture
    func swipeActions(onReply: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeActionsModifier(onReply: onReply, onDelete: onDelete))
    }
}

// MARK: - Swipe Actions Modifier

struct SwipeActionsModifier: ViewModifier {
    let onReply: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showingActions = false
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Background actions
            if showingActions {
                HStack(spacing: 12) {
                    // Reply button
                    Button {
                        HapticManager.shared.light()
                        onReply()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                            showingActions = false
                        }
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    
                    // Delete button
                    Button {
                        HapticManager.shared.medium()
                        onDelete()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                            showingActions = false
                        }
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing, 16)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            // Content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 && value.translation.width > -120 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if value.translation.width < -60 {
                                    offset = -120
                                    showingActions = true
                                    HapticManager.shared.light()
                                } else {
                                    offset = 0
                                    showingActions = false
                                }
                            }
                        }
                )
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorBubble: View {
    @State private var dotPhase: [Bool] = [false, false, false]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
            
            // Typing bubble
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotPhase[index] ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: dotPhase[index]
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            dotPhase = [true, true, true]
        }
    }
}

// MARK: - Pull to Refresh

struct PullToRefreshView: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    
    @State private var pullProgress: CGFloat = 0
    @State private var isPulling = false
    
    var body: some View {
        GeometryReader { geometry in
            if isPulling || isRefreshing {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        if isRefreshing {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Image(systemName: "arrow.down")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(pullProgress > 60 ? 180 : 0))
                                .animation(.spring(response: 0.3), value: pullProgress)
                        }
                        
                        Text(isRefreshing ? "Refreshing..." : pullProgress > 60 ? "Release to refresh" : "Pull to refresh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(min(pullProgress / 60, 1.0))
                    
                    Spacer()
                }
                .frame(height: 60)
                .offset(y: -60 + min(pullProgress, 60))
            }
        }
        .frame(height: 0)
    }
}

// MARK: - Bounce Animation

struct BounceEffect: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isAnimating = false
                    }
                }
            }
    }
}

extension View {
    func bounceEffect() -> some View {
        modifier(BounceEffect())
    }
}

// MARK: - Shake Animation (for errors)

struct ShakeEffect: GeometryEffect {
    var shakeNumber: Int
    
    var animatableData: Int {
        get { shakeNumber }
        set { shakeNumber = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 10 * sin(CGFloat(shakeNumber) * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

extension View {
    func shake(times: Int) -> some View {
        modifier(ShakeEffect(shakeNumber: times))
    }
}

// MARK: - Success Checkmark Animation

struct SuccessCheckmark: View {
    @State private var trimEnd: CGFloat = 0
    @State private var scale: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.gradient)
                .frame(width: 80, height: 80)
                .scaleEffect(scale)
            
            Path { path in
                path.move(to: CGPoint(x: 25, y: 40))
                path.addLine(to: CGPoint(x: 35, y: 50))
                path.addLine(to: CGPoint(x: 55, y: 30))
            }
            .trim(from: 0, to: trimEnd)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 80, height: 80)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.4).delay(0.2)) {
                trimEnd = 1.0
            }
        }
    }
}

// MARK: - Slide In Notification

struct SlideInNotification: View {
    let message: String
    let icon: String
    let color: Color
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            HapticManager.shared.light()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Typing Indicator") {
    VStack {
        Spacer()
        TypingIndicatorBubble()
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Success Checkmark") {
    SuccessCheckmark()
}

#Preview("Slide In Notification") {
    VStack {
        SlideInNotification(
            message: "Message sent",
            icon: "checkmark.circle.fill",
            color: .green,
            isShowing: .constant(true)
        )
        Spacer()
    }
}
