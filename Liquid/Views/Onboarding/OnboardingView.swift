//
//  OnboardingView.swift
//  Liquid
//
//  A first-run guide that also gets the user set up. A short paged carousel: some
//  steps explain (Welcome, Transactions, Distribute, Ready), and two are hands-on —
//  the Accounts and Envelopes steps let the user create real accounts and spending
//  categories right here, so they finish with a configured app instead of an empty
//  one. Shown once on first launch (see RootTabView), re-openable from Settings.
//

import SwiftUI

struct OnboardingView: View {
    /// Called when the user finishes or skips.
    var onFinish: () -> Void

    @State private var index = 0

    private let steps: [Step] = [
        .welcome, .accounts, .envelopes, .transactions, .distribute, .ready,
    ]

    private var isLastPage: Bool { index == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            skipBar
            TabView(selection: $index) {
                ForEach(steps.indices, id: \.self) { i in
                    stepView(steps[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            pageDots
            primaryButton
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func stepView(_ step: Step) -> some View {
        switch step {
        case .accounts:
            OnboardingAccountsStep()
        case .envelopes:
            OnboardingEnvelopesStep()
        default:
            VStack {
                Spacer()
                OnboardingHeader(icon: step.icon, title: step.title, message: step.body)
                    .padding(.horizontal, 32)
                Spacer()
                Spacer()
            }
        }
    }

    private var skipBar: some View {
        HStack {
            Spacer()
            Button("Skip", action: onFinish)
                .font(.subheadline)
                .tint(.secondary)
                .opacity(isLastPage ? 0 : 1)
                .disabled(isLastPage)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(i == index ? 1.15 : 1)
                    .animation(.spring(duration: 0.3), value: index)
            }
        }
        .padding(.bottom, 20)
    }

    private var primaryButton: some View {
        Button {
            if isLastPage {
                onFinish()
            } else {
                withAnimation { index += 1 }
            }
        } label: {
            Text(isLastPage ? "Get Started" : "Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    enum Step {
        case welcome, accounts, envelopes, transactions, distribute, ready

        var icon: String {
            switch self {
            case .welcome: "drop.fill"
            case .accounts: "building.columns.fill"
            case .envelopes: "tray.full.fill"
            case .transactions: "list.bullet.rectangle.fill"
            case .distribute: "arrow.branch"
            case .ready: "checkmark.seal.fill"
            }
        }

        var title: String {
            switch self {
            case .welcome: "Welcome to Liquid"
            case .accounts: "Add your accounts"
            case .envelopes: "What do you spend on?"
            case .transactions: "Record what happens"
            case .distribute: "Distribute your paycheck"
            case .ready: "You're ready"
            }
        }

        var body: String {
            switch self {
            case .welcome:
                "A private, on-device budget where every dollar gets a job. "
                    + "Track where your money is — and what it's for."
            case .accounts:
                "Add the accounts and cards you actually use — checking, savings, "
                    + "cash, or a credit card."
            case .envelopes:
                "Pick your spending categories — you can change these anytime."
            case .transactions:
                "On Transactions, tap + to log an expense, income, or a transfer "
                    + "between accounts. Enter the amount as a positive number — Liquid "
                    + "works out the sign."
            case .distribute:
                "New income lands as “To Be Budgeted.” Tap Distribute to sweep it into "
                    + "your envelopes by their rules — until every dollar has a job."
            case .ready:
                "That's the whole idea. You can reopen this guide anytime from Settings."
            }
        }
    }
}

/// Shared header for every onboarding step: a water-themed icon over a title and body.
struct OnboardingHeader: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.aqua.opacity(0.28), Color.deepTeal.opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                Image(systemName: icon)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(spacing: 10) {
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview {
    OnboardingView(onFinish: {})
}
#endif
