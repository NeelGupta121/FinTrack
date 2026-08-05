# FinTrack UI patterns (2026 design system)

The token layer lives in `lib/presentation/common/theme/app_tokens.dart` and the
theme in `app_theme.dart` (which re-exports the tokens). This document is the
contract every screen must follow so the app reads as one system.

Derived from a study of Linear, Mercury, Stripe, Copilot Money, Monzo and Ramp.
Three governing rules:

1. **ONE accent.** The indigo is for primary actions and interactive state only.
   Everything else is a neutral step. Two saturated accents is the clearest
   "dashboard template" tell.
2. **Depth by luminance on dark, hairline + one soft shadow on light.** Never a
   drop shadow on a dark card.
3. **Weight down, not up.** Large type gets lighter. Bold display type is the
   2022 look.

---

## Imports

```dart
import '../common/theme/app_theme.dart';       // tokens + AppText (re-exports app_tokens)
import '../common/theme/app_animations.dart';  // FadeSlideIn, PressableScale, AnimatedCount, AmbientGlow
```

Then, first line of every `build`:

```dart
final t = context.tokens;
```

## Colour tokens — never use a literal

| Token | Use |
|---|---|
| `t.canvas` | Scaffold background |
| `t.panel` | Recessed fill: icon plates, input fills, progress tracks |
| `t.card` | Card / row-group surface |
| `t.hover` | Hover / pressed surface |
| `t.textPrimary` | Titles, values |
| `t.textSecondary` | Body, supporting copy |
| `t.textTertiary` | Captions, metadata, eyebrows, muted icons |
| `t.textDisabled` | Disabled only |
| `t.borderSubtle` | Dividers inside a group |
| `t.borderStandard` | Card / group outer border |
| `t.borderStrong` | Outlined-button border, emphasis |
| `t.accent` | Primary CTA, active nav, links |
| `t.accentSubtle` | Selected-state tint, icon-plate tint |
| `t.success` / `t.warning` / `t.error` | Semantics ONLY (see below) |
| `t.cardShadow` | Cards. Empty on dark by design — always spread it |
| `t.floatShadow` | Floating/overlay surfaces |

`Colors.white` is permitted **only** as foreground on a filled accent surface.
`Colors.transparent` is permitted. Everything else: use a token.

### Semantic colour discipline

- `t.success` = a **real gain or income** only. Not "a positive number".
- `t.error` = a genuine problem (over budget, loss, money owed, destructive).
- `t.warning` = a middling band.
- A neutral figure (a balance, a budget remainder, 0.0%) uses `t.textPrimary`.

This mattered in review: a large green safe-to-spend numeral out-shouted the
single accent, and `+0.0%` returns rendered green implied a gain that did not
exist. Both were corrected to neutral.

## Type — always `AppText`

| Helper | Role |
|---|---|
| `AppText.hero(color, size: 44)` | Hero numeral. w300, tabular |
| `AppText.money(color, size: 16)` | **Every** currency value. Tabular |
| `AppText.section(color, size: 24)` | Screen / section heading |
| `AppText.cardTitle(color)` | Card heading, section label (17/w500) |
| `AppText.bodyText(color, weight:)` | Body, row titles (15) |
| `AppText.caption(color, weight:)` | Metadata, secondary rows (13) |
| `AppText.micro(color)` | UPPERCASE eyebrow above a value (11) |

**Every ₹ amount goes through `AppText.money`** so digits are tabular and
columns align. This is free (an OpenType feature). Never set `fontWeight.w700`
on display type, and never ask Space Grotesk for `w800` — its axis caps at 700
and Flutter silently clamps.

## Spacing + radius — no magic numbers

`Space.xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · huge 48`
plus `Space.gutter 20` (screen edge), `Space.bento 10` (grid gap),
`Space.section 28` (between major sections).

`Radii.brXs 4 · brSm 8 · brMd 12 · brLg 16 · brXl 24 · brPill`

- Cards and row groups: `Radii.brMd`.
- Buttons and inputs: `Radii.brSm` (8). **Not pill** — full-pill primaries read
  as 2022.
- `Radii.brPill` is for chips, filter pills and status badges ONLY.

## Motion

`Motion.tap 110 · fast 180 · entrance 260 · route 340 · count 620 · chart 700`
Curves: `Motion.decelerate` (entrance), `Motion.smooth`, `Motion.standard`.

Wrap each major block in `FadeSlideIn(index: n)` with sequential `n` so the
screen staggers in at 40ms per item. Wrap tappable cards in `PressableScale`.
No bounce or elastic curves on anything monetary.

---

## Component patterns

### Grouped rows (replaces stacked `ListTile`s)

The single most dated block in the old UI was four raw `ListTile`s in a `Card`.
Use this instead — squircle icon plate, inset hairline divider, muted chevron:

```dart
Container(
  decoration: BoxDecoration(
    color: t.card,
    borderRadius: Radii.brMd,
    border: Border.all(color: t.borderStandard),
    boxShadow: t.cardShadow,
  ),
  child: Column(children: [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) Padding(
        padding: const EdgeInsets.only(left: 60),   // inset past the plate
        child: Divider(height: 1, color: t.borderSubtle),
      ),
      InkWell(
        onTap: ...,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.lg, vertical: Space.md + 2),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: t.panel, borderRadius: Radii.brSm),
              child: Icon(icon, size: 17, color: t.textSecondary),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label,
                style: AppText.bodyText(t.textPrimary, weight: FontWeight.w500))),
            Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
          ]),
        ),
      ),
    ],
  ]),
)
```

### Card shell

```dart
Container(
  padding: const EdgeInsets.all(Space.lg),
  decoration: BoxDecoration(
    color: t.card,
    borderRadius: Radii.brMd,
    border: Border.all(color: t.borderStandard),
    boxShadow: t.cardShadow,
  ),
  child: ...,
)
```

### Eyebrow + value

```dart
Text('SAFE TO SPEND', style: AppText.micro(t.textTertiary)),
const SizedBox(height: Space.md),
Text('₹${fmt.format(v)}', style: AppText.money(t.textPrimary, size: 26)),
```

### Empty state

Use the shared `EmptyState` widget (`common/widgets/empty_state.dart`) — it
takes `icon`, `message`, optional `detail`, `actionLabel`, `onAction`. Do not
hand-roll a centred `Column`, and do not use a bare `Text('Nothing here')`.

### Status badge

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 3),
  decoration: BoxDecoration(
    color: c.withOpacity(t.isDark ? 0.14 : 0.10),
    borderRadius: Radii.brPill,
  ),
  child: Text(label, style: AppText.caption(c, weight: FontWeight.w600)),
)
```

### Charts (`fl_chart`)

`gridData: FlGridData(show: false)`, `borderData: FlBorderData(show: false)`,
2px stroke with `isStrokeCapRound: true`, area fill as a gradient from
`colour.withOpacity(0.26)` to `.withOpacity(0)`, bars 12px wide with a 4px
rounded top. Colours come from `AppTokens.chartRamp` (two hues, stepped) —
never a multi-hue categorical palette, which reads as an unstyled default
charting library.

---

## Layout rules

- **Screens inside the nav shell** (`/`, `/expenses`, `/investments`,
  `/insights`, and the `add` routes nested under them) render beneath a
  floating pill nav. Their scrollable content needs
  `padding: EdgeInsets.only(bottom: 136)` or the last item is hidden behind the
  pill and the chat FAB.
- **Pushed routes** (`/settings`, `/accounts`, `/bills`, `/goals`, `/reports`,
  `/chat`) have no nav pill. Normal bottom padding (`Space.xxl`) is enough.
- Horizontal screen padding is `Space.gutter` (20).
- `AppBarTheme` is already themed, so a plain `AppBar(title: Text(...))` picks
  up the right surface and type. Prefer a collapsing `SliverAppBar` only where
  the screen benefits from a large title.

## Hard constraints

1. **Do not edit** `app_theme.dart`, `app_tokens.dart`, `app_animations.dart`,
   `pubspec.yaml`, anything under `test/`, or any file not explicitly assigned.
2. **Preserve every user-visible string exactly.** Widget tests assert on
   literal text (`'Add Expense'`, `'Save changes'`, `'Accounts & Debts'`,
   `'No transactions yet'`, …). Renaming a label breaks the suite.
3. **Preserve all behaviour**: routes, providers, callbacks, validation,
   `Dismissible` keys, undo snackbars, confirm dialogs.
4. Zero `Color(0x…)` and zero `Colors.*` literals (bar the two exceptions above).
5. Leave a brief comment where a non-obvious layout constraint is required
   (e.g. `IntrinsicHeight` for a stretched Row inside a sliver).

## Known trap

A `Row` with `CrossAxisAlignment.stretch` inside a `SliverList` child has
**unbounded height** and throws `RenderBox was not laid out`. In a *release*
build Flutter shows no red error box — it silently blanks every widget below.
Wrap it in `IntrinsicHeight`. Analyze and the unit suite both stay green while
the screen is visibly broken, so this class of bug is only caught by rendering.
