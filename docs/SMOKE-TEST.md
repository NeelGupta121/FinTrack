# FinTrack — Device Smoke-Test Checklist

Run this after installing a fresh release APK (from the CI **Build Release APK**
artifact) on a real Android device. It confirms the runtime behaviors that
`flutter analyze` / unit tests / a release build cannot prove — plugins
(file_picker, read_pdf_text, image_picker, workmanager, MLKit) and live network
calls (Gemini, Alpha Vantage, mfapi.in).

## Prerequisites / config
- **`GEMINI_API_KEY`** built into the APK (CI secret) → enables AI chat, PDF
  parsing, and insights.
- **`ALPHA_VANTAGE_KEY`** (optional) → enables stock/ETF price refresh. Without
  it, stock rows stay at avg price; **mutual funds work without any key**.
- Indian stock tickers need a suffix, e.g. `RELIANCE.BSE` / `RELIANCE.NSE`.
- Mutual-fund holdings must use the **AMFI scheme code** as the symbol (e.g. `120503`).

---

## A. Core / regression
- [ ] App launches to onboarding (**3 pages**, no SMS page) or dashboard.
- [ ] Bottom nav: Home / Expenses / Investments / Insights / Settings all open.
- [ ] Dark/light toggle in Settings persists across a relaunch.

## B. Add Expense + save-button fix
- [ ] Add Expense → enter amount, **do not** pick a category → tap Save →
      snackbar **"Please select a category first"** (button is not dead).
- [ ] Pick a category → Save → **"Expense added ✅"**, row appears in the list.

## C. Screenshot / receipt import
- [ ] Add Expense → **"Scan Receipt / Screenshot"** → *Pick a screenshot / image*
      → OCR fills amount → review → save.
- [ ] Same via *Take a photo* (camera).

## D. Investments / live P&L
- [ ] Add a **mutual fund** holding, symbol = AMFI scheme code (e.g. `120503`) →
      tap ↻ (or pull-to-refresh) → NAV updates, P&L ≠ ₹0.
- [ ] Add a **stock** (e.g. `RELIANCE.BSE`) → refresh → price updates **only if**
      `ALPHA_VANTAGE_KEY` is set; otherwise the snackbar reports it was skipped.
- [ ] Reopen the Investments tab after ~12h (or after clearing app data) →
      auto-sync fires once on open.

## E. AI + model switch
- [ ] Dashboard AI chat → ask a question → get a response (needs `GEMINI_API_KEY`).
- [ ] Settings → AI → **AI Model** → switch model → confirmation snackbar;
      the next chat uses the newly-selected model.

## F. PDF statement import  ⚠️ least-tested path
- [ ] Expenses → PDF icon (top-right) → choose a **text-based** bank/CC PDF.
- [ ] Extracted transactions list appears → toggle rows, set categories →
      **Import N selected** → they appear in Expenses.
- [ ] Try a **password-protected** PDF → expect a clear "remove the password"
      message (no crash).
- [ ] After import, switch the Expenses **type chip → Income** → imported credits
      show in green with an **"Imported"** badge.

---

## Known limitations (expected, not bugs)
- Password-protected or scanned/image-only PDFs are not supported yet.
- Stock/ETF prices require `ALPHA_VANTAGE_KEY` (free tier: 25 calls/day).
- WorkManager daily background sync is best-effort on Android (Doze) and limited on iOS.
- The monthly **budget** summary is expense-only by design (income excluded).

Report any step's actual-vs-expected result to close the runtime-verification gap.
