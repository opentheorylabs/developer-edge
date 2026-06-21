import Foundation
import Defaults

enum FooterMessage {
    private static let motivational: [String] = [
        "Shipped code beats perfect code.",
        "One PR at a time.",
        "Make it work, make it right, make it fast.",
        "The build is green. Keep it that way.",
        "Debugging is detective work in a worse outfit.",
        "You're not blocked. You're just thinking.",
        "Small commits, big impact.",
        "Every deploy is a small act of courage.",
        "Code is read more than it's written.",
        "Standup's quick. You shipped yesterday.",
    ]

    private static let signature: [String] = [
        "Powered by too much coffee",
        "Open source, one commit at a time.",
        "Made with care, shipped with intent.",
    ]

    private static func morning(_ name: String?) -> [String] {
        let n = name.map { ", \($0)" } ?? ""
        return [
            "Good morning\(n). Let's ship today.",
            "Morning\(n). Coffee, then PRs.",
            "Rise and grind. Sprint's waiting.",
        ]
    }

    private static func afternoon(_ name: String?) -> [String] {
        let n = name.map { " \($0)" } ?? ""
        return [
            "Did you have lunch\(n)?",
            "Hope you had a good lunch\(n).",
            "Lunch first. Bugs can wait.",
            "Fed and focused?",
            "Don't skip lunch for that PR.",
        ]
    }

    private static func lateNight(_ name: String?) -> [String] {
        let n = name.map { ", \($0)" } ?? ""
        return [
            "Burning the midnight oil\(n) 🔥",
            "Late-night shipping. Respect.",
            "The quiet hours are the productive ones.",
            "Still here\(n)? That's commitment.",
            "Night-owl mode. Make it count.",
        ]
    }

    private static func weekend(_ name: String?) -> [String] {
        let n = name.map { ", \($0)" } ?? ""
        return [
            "Weekend warrior\(n) 💪",
            "Shipping on a weekend? Dedication.",
            "Quiet weekend, clean diffs.",
            "Going the extra mile this weekend.",
        ]
    }

    static func current(name: String? = nil, fullName: String? = nil) -> String {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)   // 1 = Sun, 7 = Sat
        let today = calendar.startOfDay(for: now)

        if let h = Celebrations.holidayGreeting(now) { return h }

        // Working late (midnight to 5am) · encouraging, not "go home".
        if hour < 5 { return lateNight(name).randomElement()! }

        // Weekend · encouraging.
        if weekday == 1 || weekday == 7 { return weekend(name).randomElement()! }

        // Morning greeting · once per day, between 5am and 12pm
        if hour >= 5 && hour < 12 {
            let lastGreetDate = Defaults[.footerLastMorningGreetDate]
            let alreadyGreeted = lastGreetDate.map { calendar.isDate($0, inSameDayAs: today) } ?? false
            if !alreadyGreeted {
                Defaults[.footerLastMorningGreetDate] = now
                return morning(name).randomElement()!
            }
        }

        // Lunch-time nudge · shown whenever opened between 2pm and 4pm
        if hour >= 14 && hour < 16 {
            return afternoon(name).randomElement()!
        }

        // Every ~5th launch show a signature message
        let launchCount = Defaults[.footerLaunchCount] + 1
        Defaults[.footerLaunchCount] = launchCount
        if launchCount % 5 == 0 {
            return signature.randomElement()!
        }

        return motivational.randomElement()!
    }
}
