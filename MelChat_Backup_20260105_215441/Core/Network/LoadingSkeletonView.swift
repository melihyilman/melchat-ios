import SwiftUI

// MARK: - Loading Skeleton for Chat List

struct ChatListSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                ChatRowSkeleton()
                Divider()
                    .padding(.leading, 88)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct ChatRowSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar skeleton
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray6),
                            Color(.systemGray5)
                        ],
                        startPoint: isAnimating ? .leading : .trailing,
                        endPoint: isAnimating ? .trailing : .leading
                    )
                )
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                // Name skeleton
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemGray5),
                                Color(.systemGray6),
                                Color(.systemGray5)
                            ],
                            startPoint: isAnimating ? .leading : .trailing,
                            endPoint: isAnimating ? .trailing : .leading
                        )
                    )
                    .frame(width: 150, height: 16)
                
                // Message preview skeleton
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemGray5),
                                Color(.systemGray6),
                                Color(.systemGray5)
                            ],
                            startPoint: isAnimating ? .leading : .trailing,
                            endPoint: isAnimating ? .trailing : .leading
                        )
                    )
                    .frame(width: 220, height: 14)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Loading Skeleton for Messages

struct MessageListSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<10, id: \.self) { index in
                    MessageBubbleSkeleton(isFromCurrentUser: index % 3 == 0)
                }
            }
            .padding()
        }
    }
}

struct MessageBubbleSkeleton: View {
    let isFromCurrentUser: Bool
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }
            
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray6),
                            Color(.systemGray5)
                        ],
                        startPoint: isAnimating ? .leading : .trailing,
                        endPoint: isAnimating ? .trailing : .leading
                    )
                )
                .frame(width: CGFloat.random(in: 150...250), height: CGFloat.random(in: 40...80))
            
            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Shimmer Effect Modifier

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Previews

#Preview("Chat List Skeleton") {
    NavigationStack {
        ChatListSkeletonView()
            .navigationTitle("Chats")
    }
}

#Preview("Message List Skeleton") {
    NavigationStack {
        MessageListSkeletonView()
            .navigationTitle("Chat")
    }
}
