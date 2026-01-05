import SwiftUI
import Combine

/// Animated typing indicator shown when other user is typing
struct TypingIndicatorView: View {
    @State private var animatingDots = 0

    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Typing indicator bubble
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray.opacity(animatingDots == index ? 1.0 : 0.4))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.4), value: animatingDots)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray5))
            )

            Spacer(minLength: 60)
        }
        .onReceive(timer) { _ in
            animatingDots = (animatingDots + 1) % 3
        }
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
}
