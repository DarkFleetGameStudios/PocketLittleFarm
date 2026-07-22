import Foundation

/// Tunable care / production / economy constants (offline Tamagotchi pacing).
enum FarmBalance {
    /// Max simulated offline gap so extreme absences don't explode edge cases.
    static let maxSimDelta: TimeInterval = 30 * 24 * 60 * 60

    // Ripe crops hold, then go past-prime, then compost — as multiples of grow time.
    /// A ripe crop stays full-quality for this × its grow time before going past-prime.
    static let overRipeFactor: Double = 2
    /// A ripe crop finally composts after this × its grow time. Generous: collect, don't rush.
    static let pastPrimeToCompostFactor: Double = 4

    // Chickens
    static let feedInterval: TimeInterval = 8 * 60 * 60
    static let hungryGrace: TimeInterval = 4 * 60 * 60
    static let eggInterval: TimeInterval = 3 * 60 * 60
    static let maxPendingEggsPerHen: Int = 3

    // Economy — keep the player in the loop even after neglect
    /// Coins delivered once per calendar day (on open / sim).
    static let dailyCoins: Int = 18
    /// Free radish seeds with the morning post.
    static let dailyRadishSeeds: Int = 3
    /// Free feed pouch with the morning post.
    static let dailyFeed: Int = 1
    /// Max days of back-pay if you were offline (no infinite AFK money).
    static let maxDailyCatchUpDays: Int = 3
    /// Soft-lock rescue when broke, seedless, nothing growing.
    static let bailoutCoins: Int = 25
    static let bailoutRadishSeeds: Int = 6
    static let bailoutFeed: Int = 2
    /// Clearing a dead plant returns a little value.
    static let compostCoins: Int = 2

    // Care streak: any successful care action on a calendar day
    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }
}
