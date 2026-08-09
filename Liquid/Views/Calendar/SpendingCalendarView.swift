//
//  SpendingCalendarView.swift
//  Liquid
//
//  A month calendar of money activity, opened from the round icon at the top-left
//  of the Dashboard. Each day cell shows that day's net (income − spending),
//  color-coded. Tapping a day reveals its totals and transactions inline below the
//  grid. Allocations are excluded — this reflects real income and spending only,
//  consistent with the Cash Flow card.
//
//  Every date is derived from a single `Calendar.current` instance (never manual
//  day arithmetic), so leap years, month lengths, the locale's first weekday, and
//  DST are correct by construction, and the day a transaction lands on always
//  matches how it is displayed.
//

import SwiftUI
import SwiftData

struct SpendingCalendarView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss

    /// Start-of-month for the month currently on screen.
    @State private var visibleMonth: Date = Calendar.current.startOfMonth(for: .now)
    /// Today is selected on open, so its detail shows immediately.
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Per-day income/spending across all transactions, keyed by start-of-day.
    private var summaries: [Date: BudgetMath.DailySummary] {
        BudgetMath.dailySummaries(transactions, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    if let selectedDay {
                        DayDetailSection(day: selectedDay,
                                         transactions: dayTransactions(on: selectedDay),
                                         summary: summaries[selectedDay])
                        .transition(.opacity)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Month header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            VStack(spacing: 2) {
                Text(visibleMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                if !calendar.isDate(visibleMonth, equalTo: .now, toGranularity: .month) {
                    Button("Today") {
                        withAnimation { visibleMonth = calendar.startOfMonth(for: .now) }
                    }
                    .font(.caption)
                }
            }
            Spacer()
            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Grid

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<leadingBlankCount, id: \.self) { _ in
                Color.clear.frame(height: 52)
            }
            ForEach(daysInMonth, id: \.self) { day in
                DayCell(
                    day: day,
                    dayNumber: calendar.component(.day, from: day),
                    net: summaries[day]?.net,
                    isToday: calendar.isDateInToday(day),
                    isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                ) {
                    withAnimation(.snappy) {
                        selectedDay = calendar.isDate(selectedDay ?? .distantPast, inSameDayAs: day) ? nil : day
                    }
                }
            }
        }
    }

    // MARK: Calendar math (see file header)

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }
        return range.compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 1, to: visibleMonth)
                .map { calendar.startOfDay(for: $0) }
        }
    }

    /// Blank cells before day 1 so it lands under the correct weekday column.
    private var leadingBlankCount: Int {
        let weekday = calendar.component(.weekday, from: visibleMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// Short weekday symbols rotated to honor the locale's first weekday.
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(start + $0) % 7] }
    }

    private func shiftMonth(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        withAnimation { visibleMonth = calendar.startOfMonth(for: next) }
    }

    private func dayTransactions(on day: Date) -> [Transaction] {
        transactions
            .filter { $0.type != .allocation && calendar.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let day: Date
    let dayNumber: Int
    let net: Decimal?
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var netColor: Color {
        guard let net, net != 0 else { return .secondary }
        return net > 0 ? .green : .red
    }

    private var netText: String? {
        guard let net, net != 0 else { return nil }
        return net.formatted(.currency(code: Formatters.currencyCode)
            .precision(.fractionLength(0))
            .sign(strategy: .never))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
                if let netText {
                    Text(netText)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(netColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(" ").font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isToday ? Color.accentColor : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let date = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if let net, net != 0 {
            let word = net > 0 ? "net income" : "net spending"
            return "\(date), \(word) \(abs(net).asCurrency)"
        }
        return "\(date), no activity"
    }
}

// MARK: - Inline day detail

private struct DayDetailSection: View {
    let day: Date
    let transactions: [Transaction]
    let summary: BudgetMath.DailySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.headline)

            HStack(spacing: 16) {
                totalPill(title: "In", value: summary?.income ?? 0, color: .green)
                totalPill(title: "Out", value: summary?.spending ?? 0, color: .red)
                totalPill(title: "Net", value: summary?.net ?? 0,
                          color: (summary?.net ?? 0) < 0 ? .red : .primary)
            }

            Divider()

            if transactions.isEmpty {
                Text("No income or spending on this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(transactions) { tx in
                    TransactionRow(transaction: tx)
                    if tx.id != transactions.last?.id { Divider() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func totalPill(title: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.asCurrency)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Calendar helper

extension Calendar {
    /// Start of the month containing `date`.
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

#Preview {
    SpendingCalendarView()
        .modelContainer(for: [Account.self, Envelope.self, Transaction.self, AllocationRule.self],
                        inMemory: true)
}
