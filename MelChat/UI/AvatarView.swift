import SwiftUI

/// Simple avatar view with initials and random color
struct AvatarView: View {
    let name: String
    let size: CGFloat

    init(name: String, size: CGFloat = 40) {
        self.name = name
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            // First letter of first two words
            let first = words[0].prefix(1)
            let second = words[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if let first = words.first {
            // First two letters of first word
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private var backgroundColor: Color {
        // Generate consistent color from name
        let hash = abs(name.hashValue)
        let colors: [Color] = [
            .blue, .green, .purple, .orange, .pink,
            .red, .indigo, .teal, .mint, .cyan
        ]
        return colors[hash % colors.count]
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AvatarView(name: "Melih Corbaci", size: 60)
        AvatarView(name: "Test User", size: 50)
        AvatarView(name: "John", size: 40)
        AvatarView(name: "A", size: 30)
    }
    .padding()
}
