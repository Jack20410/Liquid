# Liquid — Documentation

**Liquid** is a private, on-device personal budgeting app for iOS, built with
Swift, SwiftUI, and SwiftData. It uses **envelope (zero-based) budgeting**: money
is tracked two ways at once — *where it is* (an Account) and *what it is for* (an
Envelope) — and every dollar of income is given a job.

This folder documents what was built in the current version. It is written to be
read top-to-bottom by someone new to the codebase, or dipped into by section.

## Contents

| Document | What it covers |
|----------|----------------|
| [Overview](Overview.md) | What the app does, the mental model, feature list, current status |
| [Architecture](Architecture.md) | Layered MVVM + repository design, folder structure, conventions |
| [Data Model](DataModel.md) | Entities, relationships, delete rules, the sign convention |
| [Distribution Engine](DistributionEngine.md) | The paycheck-distribution algorithm and its worked example |
| [Screens](Screens.md) | Every screen, what the user can do, and how it maps to requirements |
| [Testing](Testing.md) | Test coverage and how to run the tests |
| [Build & Run](BuildAndRun.md) | Toolchain notes, how to build/test/run on this machine |
| [Changelog](Changelog.md) | What was built in this version, in order |

## At a glance

- **Platform:** iPhone, iOS 26.5+ (leans into the Liquid Glass design language)
- **Persistence:** SwiftData, fully on-device — no account, no network, no third parties
- **Source:** ~2,300 lines of Swift across 23 source files + 2 test files
- **Tests:** 12 unit tests passing (distribution engine + balance math)
- **Status:** v1 core complete. The only remaining core screen is
  **Distribute Paycheck** (its engine is already built and tested; the screen UI
  is pending).

## The reference spec

The product requirements and design this implementation follows live in
`Liquid_Requirements_and_Design.md` (v1.0). Throughout these docs, references like
"spec §7.2" or "FR-10" point back to that document.
