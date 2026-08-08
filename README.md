# OVERSEER

Real life as a battle pass, watched over by a floating AI overseer.

Doing things grants XP. XP pushes a 150-tier seasonal ladder. Crossing a tier
pays **credits**, which buy real rewards from your own wishlist — gated by a
real-money reserve, so nothing can be won that your actual finances cannot
cover.

## The idea

Built for a brain that struggles with follow-through: the instant, visible
feedback of a video game applied to real life. You do something real, a bar
moves *now*, and a presence on the screen acknowledges it.

## How the economy stays honest

Credits are minted by effort but denominated in money, so without a link the
two drift apart. The fix: a season's entire credit issuance is derived from
your real income.

```
season credit budget = expected monthly income × 3 × reserve %
```

Clearing the whole pass pays out exactly what your reserve accumulates. Two
people at tier 50 have earned different amounts, because they earn different
amounts.

- **Difficulty** scales the XP required, never the payouts.
- **Streaks** are the real difficulty knob: ×1.0 cold, ×2.0 at thirty days.
- **Shards** are a second currency for in-app cosmetics, deliberately off the
  money peg — the one thing earning more cannot buy.
- **The vault** holds goals beyond one season, each with its own pot and a date
  derived from what you actually save.

## Running it

```bash
flutter pub get
flutter run -d chrome
```

Tests, including a layout sweep across three viewports in both themes:

```bash
flutter test
```

## Stack

Flutter · Firebase Auth · Cloud Firestore · Firebase AI Logic (Gemini)
