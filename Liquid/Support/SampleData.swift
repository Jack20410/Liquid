//
//  SampleData.swift
//  Liquid
//
//  DEBUG-only seed data. This is compiled out of release builds entirely, so a
//  real-device release build always starts empty and never mixes demo data with
//  the user's real data (confirmed design decision).
//
//  It models a realistic part-time-working student, July 2026 → today:
//    • Paychecks land on the 2nd and 4th Tuesday of each month ($480–700). Each
//      one funds *half* of every fixed commitment, so after both paychecks the
//      month's bills are covered and get paid late in the month.
//    • Fixed bills: Gym, Internet, Claude, YouTube Music, Mobile. A $100/mo Invest
//      goal. Day-to-day spending: coffee, weekday lunches, groceries, eating out,
//      gas, occasional clothes, a monthly friends hangout.
//    • Wells Fargo checking is the debit hub; a Discover IT Student card carries
//      only gas + eating out and is paid off in full two days after each charge,
//      so it barely revolves. Savings and Cash round out the accounts.
//
//  Amounts and paycheck sizes come from a small seeded generator so the demo is
//  reproducible across reseeds.
//

#if DEBUG
import Foundation
import SwiftData
import SwiftUI

/// Tiny deterministic generator (a linear-congruential sequence). A class so its
/// methods need no `inout`, which keeps the seed helpers below readable.
private final class SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    private func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    /// A double in `range`.
    func double(_ range: ClosedRange<Double>) -> Double {
        let frac = Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)   // 53-bit
        return range.lowerBound + frac * (range.upperBound - range.lowerBound)
    }

    /// A whole-cent Decimal amount in `range`, so balances stay tidy.
    func money(_ range: ClosedRange<Double>) -> Decimal {
        Decimal((double(range) * 100).rounded()) / 100
    }
}

enum SampleData {
    /// Seed a fresh store with example accounts, envelopes, rules, and ~3 months of
    /// transactions modelled on a real spending pattern. No-op if any accounts exist.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        guard existing == 0 else { return }

        let rng = SeededRNG(seed: 20_260_912)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let start = cal.date(from: DateComponents(year: 2026, month: 7, day: 1)) else { return }

        // MARK: Accounts

        let wells = Institution(name: "Wells Fargo")
        let discoverBank = Institution(name: "Discover")
        context.insert(wells)
        context.insert(discoverBank)

        let checking = Account(name: "Checking", type: .checking, institution: wells)
        let savings = Account(name: "Savings", type: .savings, institution: wells)
        let cash = Account(name: "Cash", type: .cash)
        let discover = Account(name: "Discover IT Student", type: .creditCard,
                               creditLimit: 1500, institution: discoverBank)
        for account in [checking, savings, cash, discover] { context.insert(account) }

        // MARK: Envelopes

        /// A palette color by index, in the form envelopes store it.
        func hex(_ index: Int) -> String {
            let palette = Color.categoryPaletteHexStrings
            return palette[index % palette.count]
        }

        // Bills — full monthly amount as the allocation rule; funded in halves.
        let gym = Envelope(name: "Gym", kind: .bill, symbol: "figure.run", colorHex: hex(4), rule: AllocationRule(strategy: .fixed(27), priority: 0))
        let internet = Envelope(name: "Internet", kind: .bill, symbol: "wifi", colorHex: hex(3), rule: AllocationRule(strategy: .fixed(40), priority: 1))
        let claude = Envelope(name: "Claude", kind: .bill, symbol: "sparkles", colorHex: hex(6), rule: AllocationRule(strategy: .fixed(20), priority: 2))
        let ytMusic = Envelope(name: "YouTube Music", kind: .bill, symbol: "music.note", colorHex: hex(7), rule: AllocationRule(strategy: .fixed(10), priority: 3))
        let mobile = Envelope(name: "Mobile", kind: .bill, symbol: "iphone", colorHex: hex(0), rule: AllocationRule(strategy: .fixed(55), priority: 4))

        // Day-to-day spending — monthly budgets set above expected spend so the
        // envelopes stay positive (a healthy "safe to spend").
        let coffee = Envelope(name: "Coffee", kind: .spending, symbol: "cup.and.saucer", colorHex: hex(1), rule: AllocationRule(strategy: .fixed(110), priority: 5))
        let lunch = Envelope(name: "Lunch", kind: .spending, symbol: "fork.knife", colorHex: hex(2), rule: AllocationRule(strategy: .fixed(110), priority: 6))
        let groceries = Envelope(name: "Groceries", kind: .spending, symbol: "cart", colorHex: hex(0), rule: AllocationRule(strategy: .fixed(120), priority: 7))
        let eatingOut = Envelope(name: "Eating Out", kind: .spending, symbol: "takeoutbag.and.cup.and.straw", colorHex: hex(5), rule: AllocationRule(strategy: .fixed(90), priority: 8))
        let gas = Envelope(name: "Gas", kind: .spending, symbol: "fuelpump", colorHex: hex(3), rule: AllocationRule(strategy: .fixed(120), priority: 9))
        let clothes = Envelope(name: "Clothes", kind: .spending, symbol: "tshirt", colorHex: hex(1), rule: AllocationRule(strategy: .fixed(60), priority: 10))
        let friends = Envelope(name: "Friends", kind: .spending, symbol: "person.2", colorHex: hex(4), rule: AllocationRule(strategy: .fixed(160), priority: 11))

        // Savings goal.
        let invest = Envelope(name: "Invest", target: 2000, kind: .goal,
                              symbol: "banknote", colorHex: hex(2),
                              rule: AllocationRule(strategy: .fixed(100), priority: 12))

        let bills = [gym, internet, claude, ytMusic, mobile]
        let spending = [coffee, lunch, groceries, eatingOut, gas, clothes, friends]
        for envelope in bills + spending + [invest] { context.insert(envelope) }

        // MARK: Helpers

        func expense(_ envelope: Envelope, _ amount: Decimal, on date: Date,
                     account: Account = checking, note: String) {
            context.insert(Transaction(date: date, amount: amount, type: .expense,
                                       note: note, account: account, envelope: envelope))
        }

        func allocate(_ envelope: Envelope, _ amount: Decimal, on date: Date) {
            context.insert(Transaction(date: date, amount: amount, type: .allocation,
                                       note: "Paycheck allocation", account: checking, envelope: envelope))
        }

        /// A card charge (gas / eating out) plus its payoff two days later, so the
        /// Discover balance returns to ~$0.
        func cardCharge(_ envelope: Envelope, _ amount: Decimal, on date: Date, note: String) {
            context.insert(Transaction(date: date, amount: amount, type: .expense,
                                       note: note, account: discover, envelope: envelope))
            if let payDay = cal.date(byAdding: .day, value: 2, to: date), payDay <= today {
                context.insert(Transaction(date: payDay, amount: amount, type: .transfer,
                                           note: "Card payment", account: checking, toAccount: discover))
            }
        }

        func dayOf(_ year: Int, _ month: Int, _ day: Int) -> Date? {
            cal.date(from: DateComponents(year: year, month: month, day: day)).map { cal.startOfDay(for: $0) }
        }

        /// The `n`-th Tuesday of a month (weekday 3, 1 = Sunday).
        func nthTuesday(_ n: Int, month: Int) -> Date? {
            var c = DateComponents()
            c.year = 2026; c.month = month; c.weekday = 3; c.weekdayOrdinal = n
            return cal.date(from: c).map { cal.startOfDay(for: $0) }
        }

        // MARK: Recurring day-to-day spending (debit)

        var d = start
        while d <= today {
            let weekday = cal.component(.weekday, from: d)   // 1 = Sun … 7 = Sat
            if (2...6).contains(weekday) {                   // weekday lunches
                expense(lunch, rng.money(3.5...4.75), on: d, note: "Lunch")
            }
            if [2, 4, 6].contains(weekday) {                 // coffee Mon/Wed/Fri
                expense(coffee, rng.money(5...8), on: d, note: "Coffee")
            }
            if weekday == 7 {                                // groceries on Saturday
                expense(groceries, rng.money(18...25), on: d, note: "Groceries")
            }
            if weekday == 6 {                                // dinner out on Friday (card)
                cardCharge(eatingOut, rng.money(12...19), on: d, note: "Dinner out")
            }
            d = cal.date(byAdding: .day, value: 1, to: d) ?? today.addingTimeInterval(1)
        }

        // MARK: Monthly items — gas, clothes, friends, paychecks, bills

        for month in 7...9 {
            // Gas: two fill-ups (card).
            for gasDay in [3, 17] {
                if let gd = dayOf(2026, month, gasDay), gd >= start, gd <= today {
                    cardCharge(gas, rng.money(44...52), on: gd, note: "Gas")
                }
            }
            // Clothes: occasional, around the 20th.
            if let cd = dayOf(2026, month, 20), cd <= today {
                expense(clothes, rng.money(30...48), on: cd, note: "Clothes")
            }
            // Friends: a two-day hangout mid-month (under $150 total).
            if let f1 = dayOf(2026, month, 15), f1 <= today {
                expense(friends, rng.money(60...75), on: f1, note: "Friends — day 1")
            }
            if let f2 = dayOf(2026, month, 16), f2 <= today {
                expense(friends, rng.money(55...70), on: f2, note: "Friends — day 2")
            }

            // Paychecks on the 2nd and 4th Tuesday; each funds half of everything.
            var paydaysPassed = 0
            for n in [2, 4] {
                guard let payday = nthTuesday(n, month: month), payday <= today else { continue }
                paydaysPassed += 1
                context.insert(Transaction(date: payday, amount: rng.money(480...700),
                                           type: .income, note: "Paycheck", account: checking))
                // Half of each bill.
                allocate(gym, 13.50, on: payday)
                allocate(internet, 20, on: payday)
                allocate(claude, 10, on: payday)
                allocate(ytMusic, 5, on: payday)
                allocate(mobile, 27.50, on: payday)
                // Half the invest goal.
                allocate(invest, 50, on: payday)
                // A share of each spending budget.
                allocate(coffee, 55, on: payday)
                allocate(lunch, 55, on: payday)
                allocate(groceries, 60, on: payday)
                allocate(eatingOut, 45, on: payday)
                allocate(gas, 60, on: payday)
                allocate(clothes, 30, on: payday)
                allocate(friends, 80, on: payday)
            }

            // Bills are paid only once both paychecks have funded them, on staggered
            // late-month due days. So the current month (one paycheck so far) leaves
            // its bill envelopes half-funded — the Planned tile shows that balance.
            if paydaysPassed == 2 {
                let due: [(Envelope, Int, Decimal, String)] = [
                    (mobile, 26, 55, "Mobile bill"),
                    (internet, 27, 40, "Internet bill"),
                    (gym, 28, 27, "Gym membership"),
                    (claude, 28, 20, "Claude subscription"),
                    (ytMusic, 28, 10, "YouTube Music"),
                ]
                for (envelope, dueDay, amount, note) in due {
                    if let dd = dayOf(2026, month, dueDay), dd <= today {
                        expense(envelope, amount, on: dd, note: note)
                    }
                }
            }
        }

        try? context.save()
    }
}
#endif
