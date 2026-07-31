# FinTrack — UX + Reliability Upgrade Plan

Synthesized from a 3-way competitor/reliability teardown (India-market apps, global
best-in-class + open-source, and Flutter offline-first reliability practices).
Ordered so trust/reliability gaps are closed **before** new features are added.

Effort legend: **S** = <1 day · **M** = 2–4 days · **L** = 1 week+

---

## Current state (baseline)

FinTrack is an India-first, offline/local Flutter app (Android-primary; also builds web).
All data lives in on-device Hive; there is **no backend account/login**. Existing features:
manual expenses + categories + monthly budget; receipt/screenshot OCR (MLKit); PDF
statement import via Gemini with review-then-import; investments (stocks/ETF/MF) with live
prices (mfapi.in AMFI NAV keyless; Alpha Vantage for stocks, needs key); portfolio
P&L + day-change + sparkline; foreground + WorkManager daily price sync; Gemini AI
assistant with in-app model switcher; spending-anomaly Insights.

Verified working (headless-browser run, this session): app boots, all tabs render,
navigation works, **0 runtime errors on web**.

Known gaps driving the plan: local-only data (no backup → phone loss = total loss),
API keys compiled into the APK (extractable), debug-signed APK (no safe update path),
no global error screen (a crash = white screen), no data export.

---

## Tier 0 — Reliability & Trust (do first)

| Fix | Problem it kills | Impact | Effort | Status |
|-----|------------------|--------|--------|--------|
| JSON/CSV export + import | Local-only Hive → phone loss/uninstall wipes everything; no recovery | High | S | Batch 1 |
| Global error screen (`runZonedGuarded` + `ErrorWidget.builder`) | Unhandled exception = silent white screen (the "nothing works" symptom) | High | S | Batch 1 |
| Real release signing (keystore via `key.properties`) | Debug-signed APK: can't update without uninstall (data wipe); scary install warnings | High | S | Batch 1 |
| Hive open-box guard + schema version | Corrupt box or model change → app fails to launch for everyone | High | M | Batch 1 |
| BYO API key entry (`flutter_secure_storage`), prefer over compiled key | Keys extractable from a distributed APK (`strings libapp.so`) → quota theft | High | S | Batch 2 |
| Crash observability (Sentry / Crashlytics free tier) | No visibility into field crashes | Med | S | Batch 2 |

> Security note: never ship extractable secrets in a distributed APK. For a personal,
> single-user build baking your own key is lower-risk, but the GitHub CI artifact is
> publicly downloadable — prefer BYO-key or a server proxy for anything public.

## Tier 1 — High-value UX quick wins (all use existing local data)

| Feature | Source | Why | Effort |
|---------|--------|-----|--------|
| "In My Pocket" safe-to-spend number | PocketGuard | One-glance "how much can I spend today" | S |
| Budget alerts / overspend nudge (local notifications @ 80%/100%) | Jupiter/Realbyte | High engagement, offline-friendly | S |
| XIRR / true return for investments | INDmoney | Plain P&L misleads for SIPs; XIRR is correct | S |
| Net-worth trend line | Monarch | Assets−liabilities over time (portfolio data already exists) | S |
| Financial Health Score | Jupiter Wellness | Single retention number from savings/budget/diversification | S |
| 80C / tax-saver tracker | ET Money | Uniquely Indian; ELSS/PPF/NPS toward ₹1.5L | S |
| Animated donut + month-over-month bars | Copilot | Chart polish (fl_chart already a dep) | M |

## Tier 2 — Bigger bets (decide later)

| Idea | Source | Note | Effort |
|------|--------|------|--------|
| Envelope / zero-based budget mode | YNAB | Turns tracker → planner (biggest product leap) | M |
| Recurring detection + cash-flow projection | Copilot/Wallet | Extend existing Bills & Subscriptions to projection | M |
| Category auto-tagging (merchant map/ML) | Jupiter/CRED | Powers pie charts + anomaly Insights | M |
| Domain-layer separation (Hive→Domain→ViewState) | Ivy Wallet (OSS) | Safe migrations + testability | L |
| SMS auto-capture (lean, read-only, on-device) | Axio/Walnut | Biggest UX lift — but was deliberately removed; re-add is opt-in | M |
| Credit score (CIBIL) | CRED | Needs API partnership / Account Aggregator — likely out of scope | L |

---

## The one honest tension

Both the India research and Axio's whole model rank **SMS auto-capture as the #1 UX
lift** — the exact feature removed earlier this session. Re-adding a *lean, read-only,
on-device* SMS parser (no cloud) is the highest-impact single feature, but it is
deliberately opt-in, not a default.

## Recommended sequence

1. Tier-0 reliability (Batch 1: export/backup + error screen + signing + Hive guard;
   Batch 2: BYO-key + crash reporting).
2. Tier-1 quick wins (one batch).
3. Tier-2 as deliberate product bets.

Nothing reaches the phone until a correctly-signed build is installed; the Tier-0
signing fix is part of that path.

## Appendix — source teardowns

- India-market competitor teardown: subagent 841a640a
- Global best-in-class + open-source teardown: `fintrack-global-teardown.md`
- Reliability & quality hardening: subagent c759094d
