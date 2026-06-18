import Foundation
import Combine
import AppKit

/// Statistiques d'une seule journée.
struct DayRecord: Codable {
    var left: Int = 0
    var right: Int = 0
    var other: Int = 0
    var keys: Int = 0
    var scrolls: Int = 0
    var distancePoints: Double = 0

    var clicks: Int { left + right + other }
}

/// Modèle persisté : date de départ + historique jour par jour.
struct Stats: Codable {
    var since: Date = Date()
    var days: [String: DayRecord] = [:]   // clé "yyyy-MM-dd"
}

/// Ancien format (v1) pour migration sans perte.
private struct LegacyStats: Codable {
    var leftClicks = 0
    var rightClicks = 0
    var otherClicks = 0
    var keyPresses = 0
    var scrolls = 0
    var distancePoints: Double = 0
    var since = Date()
    var dayKey = ""
    var todayLeft = 0
    var todayRight = 0
    var todayOther = 0
    var todayKeys = 0
    var todayScrolls = 0
    var todayDistancePoints: Double = 0
}

final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var stats: Stats

    private let fileURL: URL
    private var saveTimer: Timer?
    private var dirty = false

    private init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mousy", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("stats.json")

        if let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? JSONDecoder().decode(Stats.self, from: data) {
                stats = decoded
            } else if let legacy = try? JSONDecoder().decode(LegacyStats.self, from: data) {
                stats = StatsStore.migrate(legacy)
            } else {
                stats = Stats()
            }
        } else {
            stats = Stats()
        }

        saveTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.saveIfDirty()
        }
    }

    // MARK: - Migration v1 -> v2

    private static func migrate(_ old: LegacyStats) -> Stats {
        var stats = Stats()
        stats.since = old.since

        let todayKey = old.dayKey.isEmpty ? dayKeyStatic(for: Date()) : old.dayKey
        // La journée en cours détaillée.
        stats.days[todayKey] = DayRecord(
            left: old.todayLeft, right: old.todayRight, other: old.todayOther,
            keys: old.todayKeys, scrolls: old.todayScrolls, distancePoints: old.todayDistancePoints
        )

        // Le reste (jours passés sans détail) est regroupé au jour de départ.
        let remLeft = old.leftClicks - old.todayLeft
        let remRight = old.rightClicks - old.todayRight
        let remOther = old.otherClicks - old.todayOther
        let remKeys = old.keyPresses - old.todayKeys
        let remScrolls = old.scrolls - old.todayScrolls
        let remDist = old.distancePoints - old.todayDistancePoints

        let sinceKey = dayKeyStatic(for: old.since)
        let hasRemainder = remLeft > 0 || remRight > 0 || remOther > 0 || remKeys > 0 || remScrolls > 0 || remDist > 1
        if hasRemainder && sinceKey != todayKey {
            stats.days[sinceKey] = DayRecord(
                left: max(0, remLeft), right: max(0, remRight), other: max(0, remOther),
                keys: max(0, remKeys), scrolls: max(0, remScrolls), distancePoints: max(0, remDist)
            )
        }
        return stats
    }

    // MARK: - Clés de jour

    private static func dayKeyStatic(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    func dayKey(for date: Date) -> String { StatsStore.dayKeyStatic(for: date) }
    var currentDayKey: String { StatsStore.dayKeyStatic(for: Date()) }

    // MARK: - Accès agrégé

    /// Cumul de toutes les journées (depuis le début).
    var totals: DayRecord {
        var t = DayRecord()
        for r in stats.days.values {
            t.left += r.left; t.right += r.right; t.other += r.other
            t.keys += r.keys; t.scrolls += r.scrolls; t.distancePoints += r.distancePoints
        }
        return t
    }

    /// Journée en cours.
    var today: DayRecord { stats.days[currentDayKey] ?? DayRecord() }

    /// Les `n` derniers jours calendaires (inclut les jours vides).
    func lastDays(_ n: Int) -> [(date: Date, record: DayRecord)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        var out: [(Date, DayRecord)] = []
        for i in stride(from: n - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: start) {
                out.append((d, stats.days[dayKey(for: d)] ?? DayRecord()))
            }
        }
        return out
    }

    // MARK: - Enregistrement (thread principal)

    private func mutateToday(_ block: (inout DayRecord) -> Void) {
        let key = currentDayKey
        var rec = stats.days[key] ?? DayRecord()
        block(&rec)
        stats.days[key] = rec
        dirty = true
    }

    func recordLeftClick()  { mutateToday { $0.left += 1 } }
    func recordRightClick() { mutateToday { $0.right += 1 } }
    func recordOtherClick() { mutateToday { $0.other += 1 } }
    func recordKey()        { mutateToday { $0.keys += 1 } }
    func recordScroll()     { mutateToday { $0.scrolls += 1 } }

    func recordMovement(dx: CGFloat, dy: CGFloat) {
        let d = Double((dx * dx + dy * dy).squareRoot())
        guard d > 0, d < 5000 else { return }
        mutateToday { $0.distancePoints += d }
    }

    // MARK: - Conversion distance -> mètres

    func meters(fromPoints points: Double) -> Double {
        guard let screen = NSScreen.main else { return points * 0.000264583 }
        let scale = screen.backingScaleFactor
        let pixels = points * scale
        let displayID = CGMainDisplayID()
        let sizeMM = CGDisplayScreenSize(displayID)
        let pixelWidth = screen.frame.width * scale
        guard sizeMM.width > 0, pixelWidth > 0 else { return points * 0.000264583 }
        let pxPerMM = pixelWidth / sizeMM.width
        return (pixels / pxPerMM) / 1000.0
    }

    var totalMeters: Double { meters(fromPoints: totals.distancePoints) }
    var todayMeters: Double { meters(fromPoints: today.distancePoints) }

    // MARK: - Persistance

    func save() {
        if let data = try? JSONEncoder().encode(stats) {
            try? data.write(to: fileURL, options: .atomic)
        }
        dirty = false
    }

    private func saveIfDirty() {
        guard dirty else { return }
        save()
    }

    func resetAll() {
        stats = Stats()
        dirty = true
        save()
    }
}
