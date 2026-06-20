import Foundation

/// Holiday + personal (birthday / work-anniversary) greetings for the footer.
enum Celebrations {

    // MARK: - Holidays

    /// Fixed-date holidays, keyed by MM-DD.
    private static let fixedHolidays: [String: String] = [
        "01-01": "🎉 Happy New Year! Fresh main, fresh start.",
        "01-26": "🇮🇳 Happy Republic Day!",
        "08-15": "🇮🇳 Happy Independence Day!",
        "10-31": "🎃 Happy Halloween!",
        "12-25": "🎄 Merry Christmas!",
        "12-31": "🥂 Last commit of the year?",
    ]

    /// Lunar / movable holidays, keyed by full YYYY-MM-DD.
    private static let datedHolidays: [String: String] = [
        // Diwali
        "2025-10-21": "🪔 Happy Diwali! Wishing you light and clean diffs.",
        "2026-11-08": "🪔 Happy Diwali! Wishing you light and clean diffs.",
        "2027-10-29": "🪔 Happy Diwali! Wishing you light and clean diffs.",
        // Holi
        "2026-03-04": "🎨 Happy Holi!",
        "2027-03-22": "🎨 Happy Holi!",
    ]

    static func holidayGreeting(_ date: Date = Date()) -> String? {
        let full = ymd(date)
        if let h = datedHolidays[full] { return h }
        return fixedHolidays[String(full.suffix(5))]
    }

    // MARK: - Personal (birthday / anniversary)

    private struct Person: Decodable {
        let name: String
        let birthday: String?   // MM-DD
        let joined: String?     // YYYY-MM-DD
    }
    private struct Roster: Decodable { let people: [Person] }

    private static let people: [Person] = {
        guard let url = Bundle.main.url(forResource: "celebrations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let roster = try? JSONDecoder().decode(Roster.self, from: data) else { return [] }
        return roster.people
    }()

    /// Returns a birthday or work-anniversary greeting for the given user, if today is the day.
    static func personalGreeting(for userName: String, date: Date = Date()) -> String? {
        guard !userName.isEmpty,
              let p = people.first(where: { $0.name.caseInsensitiveCompare(userName) == .orderedSame })
        else { return nil }

        let mmdd = String(ymd(date).suffix(5))
        let first = userName.split(separator: " ").first.map(String.init) ?? userName

        if p.birthday == mmdd { return "🎂 Happy birthday, \(first)!" }

        if let joined = p.joined, joined.count == 10, String(joined.suffix(5)) == mmdd {
            let joinYear = Int(joined.prefix(4)) ?? 0
            let years = Calendar.current.component(.year, from: date) - joinYear
            if years > 0 {
                return "🎊 \(years) \(years == 1 ? "year" : "years") at Zuperior today, \(first)!"
            }
        }
        return nil
    }

    // MARK: - Helper

    private static func ymd(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
