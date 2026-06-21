import Foundation

/// Holiday greetings for the footer message.
enum Celebrations {

    private static let fixedHolidays: [String: String] = [
        "01-01": "Happy New Year! Fresh main, fresh start.",
        "10-31": "Happy Halloween!",
        "12-25": "Merry Christmas!",
        "12-31": "Last commit of the year?",
    ]

    private static let datedHolidays: [String: String] = [
        "2026-11-08": "Happy Diwali! Wishing you light and clean diffs.",
        "2027-10-29": "Happy Diwali! Wishing you light and clean diffs.",
        "2026-03-04": "Happy Holi!",
        "2027-03-22": "Happy Holi!",
    ]

    static func holidayGreeting(_ date: Date = Date()) -> String? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        let full = f.string(from: date)
        if let h = datedHolidays[full] { return h }
        return fixedHolidays[String(full.suffix(5))]
    }
}
