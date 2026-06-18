import SwiftUI
import Charts
import AppKit

/// Une statistique sélectionnable (pour le graphique et les cartes).
enum Metric: String, CaseIterable, Identifiable {
    case left, right, other, keys, scrolls, distance
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .left: return "cursorarrow.click"
        case .right: return "cursorarrow.click.2"
        case .other: return "computermouse"
        case .keys: return "keyboard"
        case .scrolls: return "arrow.up.arrow.down"
        case .distance: return "ruler"
        }
    }

    var title: String {
        switch self {
        case .left: return "Clic gauche"
        case .right: return "Clic droit"
        case .other: return "Clic molette"
        case .keys: return "Touches"
        case .scrolls: return "Scrolls"
        case .distance: return "Distance"
        }
    }

    var tint: Color {
        switch self {
        case .left: return .blue
        case .right: return .indigo
        case .other: return .teal
        case .keys: return .orange
        case .scrolls: return .green
        case .distance: return .pink
        }
    }

    var isDistance: Bool { self == .distance }

    /// Valeur numérique pour le graphique (mètres pour la distance, sinon un entier).
    func chartValue(_ r: DayRecord, _ store: StatsStore) -> Double {
        switch self {
        case .left: return Double(r.left)
        case .right: return Double(r.right)
        case .other: return Double(r.other)
        case .keys: return Double(r.keys)
        case .scrolls: return Double(r.scrolls)
        case .distance: return store.meters(fromPoints: r.distancePoints)
        }
    }
}

struct DayPoint: Identifiable {
    let id: Date
    let date: Date
    let value: Double
}

struct FunFact: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

struct StatsView: View {
    @ObservedObject var store: StatsStore
    @State private var showAllTime = false
    @State private var selectedMetric: Metric = .left
    @State private var rangeDays = 14
    @State private var trusted = EventMonitor.shared.keyboardTrusted

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !trusted { permissionBanner }

                Picker("", selection: $showAllTime) {
                    Text("Aujourd'hui").tag(false)
                    Text("Depuis le début").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                statsGrid
                historySection
                funFacts
                footer
            }
            .padding(16)
        }
        .frame(width: 360)
        .frame(maxHeight: 680)
        .onReceive(timer) { _ in
            trusted = EventMonitor.shared.keyboardTrusted
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Mousy").font(.title3.bold())
                Text("\(fmt(store.totals.clicks)) clics au total")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "keyboard.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 5) {
                Text("Touches non comptées").font(.caption.bold())
                Text("Active Mousy dans Réglages → Confidentialité et sécurité → Surveillance des saisies, puis relance l'app.")
                    .font(.caption2).foregroundStyle(.secondary)
                Button("Ouvrir les Réglages") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Cartes

    private var statsGrid: some View {
        let r = showAllTime ? store.totals : store.today
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Metric.allCases) { m in
                StatCard(
                    metric: m,
                    value: cardValue(m, r),
                    selected: selectedMetric == m,
                    action: { selectedMetric = m }
                )
            }
        }
    }

    private func cardValue(_ m: Metric, _ r: DayRecord) -> String {
        if m.isDistance {
            return distanceString(store.meters(fromPoints: r.distancePoints))
        }
        return fmt(Int(m.chartValue(r, store)))
    }

    // MARK: - Historique / graphique

    private var historySection: some View {
        let points = store.lastDays(rangeDays).map {
            DayPoint(id: $0.date, date: $0.date, value: selectedMetric.chartValue($0.record, store))
        }
        let total = points.reduce(0.0) { $0 + $1.value }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(selectedMetric.title).font(.subheadline.bold())
                } icon: {
                    Image(systemName: selectedMetric.icon).foregroundStyle(selectedMetric.tint)
                }
                Spacer()
                Picker("", selection: $rangeDays) {
                    Text("7 j").tag(7)
                    Text("14 j").tag(14)
                    Text("30 j").tag(30)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
            }

            Chart(points) { p in
                BarMark(
                    x: .value("Jour", p.date, unit: .day),
                    y: .value(selectedMetric.title, p.value)
                )
                .foregroundStyle(selectedMetric.tint.gradient)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: rangeDays > 14 ? 7 : 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                }
            }
            .frame(height: 140)

            Text("Total sur \(rangeDays) jours : \(selectedMetric.isDistance ? distanceString(total) : fmt(Int(total)))")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Le saviez-vous

    private var funFacts: some View {
        let r = showAllTime ? store.totals : store.today
        let meters = store.meters(fromPoints: r.distancePoints)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(funLines(meters: meters, keys: r.keys, clicks: r.clicks)) { fact in
                HStack(spacing: 8) {
                    Image(systemName: fact.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(fact.text).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Text("Depuis le \(dateString(store.stats.since))")
                .font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Menu {
                Button(role: .destructive) { store.resetAll() } label: {
                    Label("Réinitialiser les stats", systemImage: "trash")
                }
                Button { store.save(); NSApp.terminate(nil) } label: {
                    Label("Quitter Mousy", systemImage: "power")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Helpers

    private func funLines(meters: Double, keys: Int, clicks: Int) -> [FunFact] {
        var lines: [FunFact] = []
        if meters >= 1 {
            let fields = meters / 105.0
            if fields >= 0.1 {
                lines.append(FunFact(icon: "soccerball", text: "\(fmtD(fields, 1)) terrain(s) de foot parcouru(s)"))
            }
        }
        if keys > 0 {
            let pages = Double(keys) / 1800.0
            if pages >= 0.1 {
                lines.append(FunFact(icon: "doc.text", text: "\(fmtD(pages, 1)) page(s) de texte tapée(s)"))
            }
        }
        if clicks > 0 {
            let perDay = Double(clicks)
            lines.append(FunFact(icon: "hand.tap", text: "\(fmt(clicks)) clics — soit \(fmtD(perDay / 60.0, 0)) par minute si tu cliquais une heure d'affilée"))
        }
        if lines.isEmpty {
            lines.append(FunFact(icon: "sparkles", text: "Continue à cliquer, les stats arrivent !"))
        }
        return lines
    }

    private func distanceString(_ meters: Double) -> String {
        if meters >= 1000 { return "\(fmtD(meters / 1000.0, 2)) km" }
        if meters >= 1 { return "\(fmtD(meters, 1)) m" }
        return "\(fmtD(meters * 100, 0)) cm"
    }

    private func fmt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func fmtD(_ n: Double, _ decimals: Int) -> String { String(format: "%.\(decimals)f", n) }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: date)
    }
}

struct StatCard: View {
    let metric: Metric
    let value: String
    var selected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: metric.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? metric.tint : .secondary)
                    .frame(height: 18)
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(metric.title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                selected ? metric.tint.opacity(0.14) : Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(selected ? metric.tint.opacity(0.7) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
