# Contributing to Liquid

Liquid is a private, on-device iOS budgeting app. This is the project's **git
workflow standard** — intentionally lean, but matched to a versioned App Store
release cadence.

## Branching model

Two long-lived branches; short-lived work branches off `develop`:

```
feature/*  ─┐
fix/*       ├─ PR ─►  develop  ── PR ─►  main  ── tag ─►  vX.Y.Z  (App Store)
chore/*    ─┘         (integration)      (stable / released)
```

| Branch                          | Purpose                                    | Base      | Merges into |
|---------------------------------|--------------------------------------------|-----------|-------------|
| `main`                          | Stable, released code; tagged SemVer       | —         | —           |
| `develop`                       | Active integration; target for all work    | `main`    | `main` (PR) |
| `feature/<x>`                   | New feature                                | `develop` | `develop`   |
| `fix/<x>`                       | Bug fix                                    | `develop` | `develop`   |
| `chore/<x>` `docs/<x>` `ci/<x>` | Tooling / docs / CI                        | `develop` | `develop`   |

**Everyday work happens on `develop`.** `main` changes **only** via a
`develop → main` PR (or, rarely, an urgent fix — see below).

## The rules (enforced by branch protection on `main` + `develop`)

- **No direct pushes** to `main` or `develop` — everything lands via PR (applies to admins too).
- **CI "Build & test" must pass** before a PR can merge.
- Reviews: 0 required (solo self-merge is fine); request one when a second pair of eyes helps.
- **Rebase your branch onto the latest `develop` before opening its PR** — keeps CI meaningful and avoids stale merges.
- One concern per PR; keep branches short-lived.

## Branch names

`type/short-kebab-description` — e.g. `feature/safe-to-spend`, `fix/app-support-store`,
`chore/ci-on-develop`. Types: `feature`, `fix`, `chore`, `docs`, `ci`.

## Commit messages — Conventional Commits

```
type(optional-scope): short imperative summary   (≤ 72 chars)

Body explains *why*, not just what. Reference issues/PRs.

Co-Authored-By: ...
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`, `build`, `style`.
Example: `feat(dashboard): add Safe to Spend card`.

## Pull requests

- Target **`develop`** (feature/fix/chore/docs). Fill in the PR template.
- Make sure **CI is green**, then merge.
- **Merge strategy:**
  - `feature|fix|chore|docs → develop`: **Squash and merge** (one tidy commit on `develop`).
  - `develop → main`: **Merge commit** (preserves the release point).

## Versioning & releasing

Two different things people conflate — keep them straight:

- **App version** lives in the **build settings** (baked into the binary):
  - `MARKETING_VERSION` — the user-facing version on the App Store, e.g. `1.2.0` (`CFBundleShortVersionString`).
  - `CURRENT_PROJECT_VERSION` — the build number, e.g. `7` (`CFBundleVersion`); **must increase on every upload** to App Store Connect.
- **Git tag** — a **marker in git history** pointing at the exact commit you released, e.g. `v1.2.0`. It's not part of the app; it lets you find/rebuild/branch-from that release later.

They should **match**: when you ship `MARKETING_VERSION 1.2.0`, tag that commit `v1.2.0`.

**To ship a release** (lean — no release branch):
1. `chore/version-bump`: raise `MARKETING_VERSION` (SemVer) and bump `CURRENT_PROJECT_VERSION`; PR → `develop`.
2. Open a **`develop → main` PR**; merge once CI is green.
3. **Tag `main`:** `git tag -a v1.2.0 -m "Liquid 1.2.0" && git push origin v1.2.0`, then create a GitHub Release.
4. Archive from `main` at that tag and upload to App Store Connect.

**SemVer** (`MAJOR.MINOR.PATCH`): breaking change → MAJOR, new feature → MINOR, fix → PATCH.

## Urgent production fix (rare)

No formal `hotfix/*` branch in this lean flow. If a shipped build is broken:
1. `fix/<name>` **off `main`** → PR → `main`; tag a patch (`vX.Y.(Z+1)`); ship.
2. Then **merge `main` back into `develop`** so the fix isn't lost.

## CI

`.github/workflows/ci.yml` runs **Build & test** (Swift Testing unit tests) on pushes and
PRs to `main` and `develop`. It's the required status check for merging.

## Why this model (and when to change it)

Continuously-deployed web services often use **trunk-based development** or **GitHub Flow**
(a single `main`, tiny branches, feature flags). For a **versioned mobile app** that ships
discrete, reviewed builds, the `main` (released) vs `develop` (next) split maps cleanly to
App Store reality — so we use this lean Gitflow. It can grow into `release/*` and
`hotfix/*` branches if the cadence demands, or simplify toward trunk-based later.
