//
//  SampleData.swift
//  Liquid
//
//  DEBUG-only seed data. This is compiled out of release builds entirely, so a
//  real-device release build always starts empty and never mixes demo data with
//  the user's real data (confirmed design decision).
//
//  The seed sketches a realistic month: an allocated paycheck three weeks ago, a
//  fresh unallocated one a few days ago (so "To Be Budgeted" is non-zero), and
//  scattered expenses so the dashboard's cash-flow chart has something to show.
//

#if DEBUG
import Foundation
import SwiftData

enum SampleData {
    /// Seed a fresh store with example accounts, envelopes, rules, and a month of
    /// transactions. No-op if any accounts already exist.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        guard existing == 0 else { return }

        let checking = Account(name: "Checking")
        let savings = Account(name: "Savings")
        context.insert(checking)
        context.insert(savings)

        let rent = Envelope(name: "Rent", rule: AllocationRule(strategy: .fixed(800), priority: 0))
        let groceries = Envelope(name: "Groceries", rule: AllocationRule(strategy: .fixed(400), priority: 1))
        let utilities = Envelope(name: "Utilities", target: 150,
                                 rule: AllocationRule(strategy: .fillToTarget(150), priority: 2))
        let fun = Envelope(name: "Fun", rule: AllocationRule(strategy: .percentage(0.10), priority: 3))
        let savingsEnv = Envelope(name: "Savings", target: 5000,
                                  rule: AllocationRule(strategy: .remainder, priority: 4))
        for env in [rent, groceries, utilities, fun, savingsEnv] {
            context.insert(env)
        }

        func day(_ offset: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: offset,
                                  to: Calendar.current.startOfDay(for: .now)) ?? .now
        }
        func add(_ amount: Decimal, _ type: TransactionType, _ note: String,
                 on date: Date, envelope: Envelope? = nil) {
            context.insert(Transaction(date: date, amount: amount, type: type,
                                       note: note, account: checking, envelope: envelope))
        }

        // Three weeks ago: paycheck, fully distributed per the envelope rules
        // (the spec §7.2 example: 800 / 400 / 100 / 200 / 500).
        add(2000, .income, "Paycheck", on: day(-21))
        add(800, .allocation, "Paycheck allocation", on: day(-21), envelope: rent)
        add(400, .allocation, "Paycheck allocation", on: day(-21), envelope: groceries)
        add(100, .allocation, "Paycheck allocation", on: day(-21), envelope: utilities)
        add(200, .allocation, "Paycheck allocation", on: day(-21), envelope: fun)
        add(500, .allocation, "Paycheck allocation", on: day(-21), envelope: savingsEnv)

        // Spending across the month.
        add(800, .expense, "August rent", on: day(-19), envelope: rent)
        add(82.15, .expense, "Weekly shop", on: day(-17), envelope: groceries)
        add(45.30, .expense, "Cinema night", on: day(-13), envelope: fun)
        add(76.80, .expense, "Weekly shop", on: day(-10), envelope: groceries)
        add(65.20, .expense, "Electric bill", on: day(-8), envelope: utilities)
        add(58.90, .expense, "Weekly shop", on: day(-6), envelope: groceries)

        // A fresh paycheck, not yet distributed → "To Be Budgeted" is $2,000.
        add(2000, .income, "Paycheck", on: day(-3))
        add(24.99, .expense, "Streaming", on: day(-1), envelope: fun)
        add(62.40, .expense, "Weekly shop", on: day(0), envelope: groceries)

        try? context.save()
    }
}
#endif
