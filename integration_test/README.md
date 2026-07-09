# FinTrack UAT (integration_test)

`app_test.dart` drives the **real app** as a user would (widget finders + tap/enterText),
asserting observable behavior. This is the acceptance-test vehicle for features
that can't be exercised by unit tests or by headless-browser automation of the
Flutter canvas.

## Run

Needs an emulator/device (the app uses Hive → `path_provider`):

```bash
# Android emulator or connected device
flutter test integration_test/app_test.dart -d <deviceId>

# Or in Chrome (web-reachable groups only)
flutter test integration_test/app_test.dart -d chrome
```

List targets with `flutter devices` / `flutter emulators`.

## Coverage matrix

| # | Test case | Group | Runs where |
|---|-----------|-------|-----------|
| TC-01 | Boots to onboarding/dashboard | Onboarding & Nav | any target |
| TC-02 | Skip onboarding → empty dashboard | Onboarding & Nav | any target |
| TC-03 | Bottom nav visits all 4 tabs | Onboarding & Nav | any target |
| TC-04 | Create goal → add funds → progress advances | Goals | any target |
| TC-05 | Set monthly budget in Settings (persists) | Budget | any target |
| TC-06 | Dark-mode toggle flips | Budget | any target |
| TC-07 | Add manual expense → success | Expenses | any target |
| TC-08 | Add manual holding → success | Investments | any target |
| TC-09 | SMS scan → result/permission message | Device | **device** (`skip:`) |
| TC-10 | Receipt OCR / camera Scan | Device | **device** (`skip:`) |
| TC-11 | Bill reminder / milestone / budget notifications | Device | **device** (`skip:`) |
| TC-12 | AI chat returns a response | Device/AI | **device + key** (`skip:`) |

TC-01…TC-08 run on any target. TC-09…TC-12 are `skip:`-marked because they need
real plugin permissions (SMS/camera/notifications) or credentials (Gemini key /
Supabase proxy). Remove the `skip:` and grant permissions / pass
`--dart-define=GEMINI_API_KEY=…` to run them on a physical device.

## Gotchas encoded in the suite

- **No `pumpAndSettle`**: the dashboard hero uses a *repeating* shimmer
  animation, so `pumpAndSettle()` never settles (times out). The suite uses
  fixed `pump(Duration)` via `settle()` instead.
- **Onboarding persists**: once completed, `onboarding_complete` is stored in
  SharedPreferences, so later boots go straight to the dashboard. Every test
  calls `skipOnboardingIfPresent()` so it works either way.
- **State persists across tests** (Hive is on-device): goals/expenses created in
  one test remain for later tests — expected for a UAT session.
