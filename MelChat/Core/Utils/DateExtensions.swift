import Foundation

extension Date {
    /// Returns a human-readable relative time string
    /// Examples: "Just now", "5m ago", "2h ago", "Yesterday", "Dec 20"
    var relativeTime: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)

        if let minutes = components.minute {
            if minutes < 1 {
                return "Just now"
            } else if minutes < 60 {
                return "\(minutes)m ago"
            }
        }

        if let hours = components.hour {
            if hours < 24 {
                return "\(hours)h ago"
            }
        }

        if let days = components.day {
            if days == 1 {
                return "Yesterday"
            } else if days < 7 {
                return "\(days)d ago"
            }
        }

        // More than a week - show date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    /// Returns a short time string for chat list
    /// Examples: "12:30 PM", "Yesterday", "Dec 20"
    var chatListTime: String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: self, to: now).day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}
