# OVERSEER — where we stopped

Paused 2026-08-07. `flutter analyze` clean (0 errors), `flutter test` **147/147 green**.

The redesign has now been **run and looked at** in both themes, at three
viewport widths, with real content. Screenshots below describe what works.

## Run it

```bash
cd /Users/max/Documents/claude/overseer && flutter run -d chrome
```

For an iterated web session with hot reload driven from a script:

```bash
mkfifo /tmp/overseer.fifo && (sleep 100000 > /tmp/overseer.fifo &) && flutter run -d web-server --web-port 5599 --web-hostname 127.0.0.1 < /tmp/overseer.fifo
```

Then `echo r > /tmp/overseer.fifo` recompiles — but note **Flutter web hot
reload needs a browser page refresh to take effect**. Recompile, then reload.

In debug builds, **SYSTEM → SEED DEMO DATA** fills the account with directives,
ten priced wishes, obligations and ~tier 52 of progress. An empty account tells
you nothing about the layout.

## What the app is

Real life as a battle pass. Doing things grants XP; XP pushes a 150-tier
seasonal ladder; crossing a tier pays **credits**. Credits buy real rewards from
your own wishlist, gated by a real-money reserve so nothing can be won that your
actual finances can't cover. A glass triangle with one eye watches and comments.

## Decisions locked in

| Thing | Decision |
|---|---|
| Name | OVERSEER |
| Currency | CREDITS, own drawn mark, never a euro sign |
| Backend | **Firebase** — project `overseer-454d8`. Supabase dropped. |
| Look | Luxury editorial, light *and* dark, warm bone / warm near-black, brass + jade |
| Reward images | Real photo via grounded search, generated duotone plate as fallback |
| Pinterest | Paste/share images → Gemini vision. No OAuth integration |
| Ladder | 150 tiers, **calibrated to real income** (see below) |
| Difficulty | basic / challenging / extreme / hell — scales XP only, never payouts. Default `challenging` = ×2 |
| Currency name | CREDITS |
| Arrears | 0.005%/day levy + 25% garnish of tier payouts |

## How credits stay tied to real money

The problem: credits are minted by *effort* but denominated in *money*, so
without a link the two drift and the reserve gate becomes a wall.

The fix, in `LadderPlan.from`:

```
season credit budget = expected monthly income × 3 × fund %
```

That budget is distributed across the 150 rungs, so **clearing the whole pass
pays out exactly what the reserve will have accumulated**. Consequences:

- The pass is genuinely personal — two people at tier 50 have earned different
  amounts because they earn different amounts.
- Difficulty scales XP required, never payouts. Hell mode is more work for the
  same money.
- ~80 of 150 rungs pay nothing at all. With a fixed budget, paying on fewer
  rungs makes each payout an event. Rhythm: `%25` major (real reward + big
  payout), `%10` real reward, `%5` cosmetic, `%3` small credits, rest nothing.
- `GameState.unbackedCredits` reports when issuance has outrun the reserve, and
  settings says so plainly rather than hiding it until the claim gate.
- A bank statement just replaces *declared* income with *measured* income and
  re-calibrates. `GameState.addStatement` is the seam; no credential is ever
  handled in-app.

## Goals bigger than a season

A car or a deposit will never fit a thirteen-week ladder, so goals are banded
by **time at the user's actual saving rate**, not by price (`core/horizon.dart`):

| Band | Meaning | Where it lives |
|---|---|---|
| `inReach` | reserve already covers it | store |
| `thisSeason` | ≤ 3 months | store, and the ladder may pin it |
| `onDeck` | ≤ 1 year | store, not pinned |
| `longRange` | 1–10 years | **vault** |
| `beyondHorizon` | > 10 years | **vault**, stated plainly |

Long goals never reach the ladder — a rung that cannot be cleared inside the
season is worse than an empty one.

**Earmarks.** A vault goal can take a share of every reserve deposit into its
own pot (`Reward.earmarkPercent` / `savedEuro`). Without this a ten-year goal
never moves, because any small purchase drains the shared reserve. The setter
caps total earmarks at 100% — a plan allocating 140% of your savings is not a
plan.

**Cashflow changes re-band everything.** `setExpectedIncome` /
`setFundPercent` / `addStatement` all re-plan the ladder *and* re-band the
manifest, emitting `GoalsPromoted` for anything that has just come into reach.
A raise visibly pulls distant things closer instead of leaving the user to
work it out.

**Nothing is softened.** Past ten years the app says so, then says what monthly
income would make it five (`incomeNeededFor`) — which turns a discouraging
figure into an actionable one.

## Backend — live

Firebase project **`overseer-454d8`**, all three services confirmed working:

- **Auth** — email/password, already enabled. `services/auth_service.dart`.
- **Firestore** — one document per user at `users/{uid}` holding the whole
  snapshot. Rules deployed: an account can read and write only its own row,
  everything else denied explicitly. `data/firestore_repository.dart`.
- **AI Logic** — enabled. The console no longer logs "OverseerAI unavailable",
  which is the tell that `FirebaseAI.googleAI()` constructs successfully.

`_AuthGate` in `app.dart` swaps the repository on sign-in and flushes the old
one first, so an anonymous session's last few actions are not lost. Signing in
changes exactly one thing — where the data lives.

**Offline is first-class.** `FirestoreRepository` mirrors every write to a
uid-namespaced `LocalRepository` and reads the mirror before the network, so
the app is fully playable with no connection and reconciles on the next push.

**Images are links, never uploads.** `Reward.imageUrl` is a URL rendered by
`Image.network`; nothing touches Firebase Storage, so web and mobile behave
identically and a dead link degrades to the generated plate. The add-wish sheet
takes a pasted link that overrides whatever search found.

## Two currencies, on purpose

**Credits** are real money (1 EUR = 100) and buy real rewards, gated by the
reserve. **Shards** buy everything inside the app and are deliberately off the
money peg — they are the one thing earning more cannot reach.

Shards come from collecting directives (1), milestone tiers (6/15/40) and
streak milestones (5 → 1,500). A whole season of tier milestones pays less than
one legendary, which is pinned by test.

## Cosmetics

`models/unlockable.dart` **generates** the catalogue from the appearance enums,
so a value added to `OverseerShape` automatically gets a rarity, a price and a
place in the store. Nothing can be added and be silently unobtainable — there is
a test for exactly that.

Six axes: shape · material · paint · eye · accessory · personality. First option
of each is free, so a new account never faces a fully locked wardrobe.

- **Locked options are shown, not hidden** — greyed at 45% with their price. A
  locked thing you can see is a goal.
- **Monthly rotation** — exactly one rotating item is buyable per month,
  derived from year×12+month so it is stable within a month and cannot be
  re-rolled by reloading.
- **Lootboxes** cost 250 shards, roll a weighted rarity table
  (58/27/11/3.4/0.6), and never contain that month's offer. A duplicate always
  refunds dust — a repeat pull worth nothing makes the mechanic feel like a
  swindle.

## Economy rules that must not drift

Pinned in `test/economy_test.dart`:

1. **Tasks grant XP only.** XP never mints credits directly.
2. **Credits are paid only on crossing a tier.** That is the burst.
3. **1 EUR = 100 credits**, always.
4. **A reward can never be claimed unless the real reserve covers it.**
5. **Mastery fills from hours, never euros.**

Base curve `60 + 3(t-1) + 0.045(t-1)²`, multiplied by difficulty. At the
default ×2 a committed season (~350 XP/day) lands around tier 62; BASIC lands
~90; HELL ~28. All tunable in `lib/core/economy.dart`.

Work that earns nothing is deliberately worth little but never zero —
`xpTrivial` 3, `xpSmall` 8, `xpSession` 25 — against `xpPaidSession` 75 and
`xpBigWin` 250. The floor matters: a person who gets no acknowledgement for the
dishes stops logging the dishes, then stops opening the app.

## Verified working

- **Core loop.** Tap DONE → XP rises, bar advances, tier counter updates, the
  row flips to COLLECT. Tap COLLECT → streak starts, lifetime XP rises, credit
  trickle paid. The overseer reacts to both, in character.
- **150-tier ladder** scrolls smoothly and auto-opens at your current tier. Rail
  nodes read jade/brass/hollow for passed/current/ahead.
- **Reward detail** is a full magazine spread: full-bleed photography, serif
  headline over it, cost, funding bar, description, record, actions.
- **Both themes** are genuinely equal. Dark is warm near-black, not grey.
- **Layout** holds at 320 / 390 / 1024pt in both themes, empty and populated —
  enforced by `test/screens_smoke_test.dart` (63 layout cases).

## Built

- **Design system** — `theme/tokens.dart` (ThemeExtension, light + dark),
  `theme/type.dart` (Fraunces / Inter / JetBrains Mono), `theme/app_theme.dart`
- **Credit mark** — `widgets/credit_mark.dart`, drawn not typeset
- **Emblems** — `widgets/emblem.dart`, 5 original insignia
- **Economy + models** — wallet, quest, reward, season, mastery, cosmetic,
  upkeep/obligations, profile, taste, companion
- **GameState** — every rule, one `ChangeNotifier`, event stream for animations
- **Repository seam** — `data/repository.dart` + `LocalRepository`
- **Screens** — home, 150-tier pass, store, reward detail, quest log, settings,
  tier detail sheet, add-quest sheet, add-wish sheet, log-income, obligations
- **Companion** — 16 shapes × 12 finishes × 16 paints × 8 personas, all
  combinatorial (`models/appearance.dart`, `widgets/companion/shapes.dart`).
  Every shape × finish pair is render-tested.
- **Overseer page** — the triangle large and centred, with a braindump field
  that triages free text into tasks / habits / wishes / obligations / already-
  done and files each one. Local heuristic parser runs first so something
  appears instantly; Gemini refines it when available.
- **AI** — `services/ai/overseer_ai.dart`: wish pricing, image extraction,
  price re-check, suggestions, taste rewrite, companion lines

## Not built yet

- **Supabase** — schema, RLS policies, auth screens, `SupabaseRepository`.
  Local storage only, single anonymous user.
- **Firebase** — no `firebase_options.dart`. `OverseerAI` degrades gracefully
  and the app runs fully without it; add-a-wish falls back to a manual price
  field, and the companion uses its local bank.
- Mastery screen, trophy case, tablet dashboard route
- Vault goals are not yet re-priced on a schedule; the grounded price re-check
  exists (`OverseerAI.recheckPrice`) but nothing calls it periodically, which
  matters most for exactly these multi-year goals
- Monthly consistency challenge (Phase L) — not started
- Cosmetic *unlocking* of appearance options: every shape/finish/paint is
  currently available immediately rather than earned
- Companion not yet wired to Gemini — the plumbing and persona prompts exist,
  nothing calls `companionLine` yet
- Imagen fallback — currently the deterministic duotone plate, which is free
  and consistent; real generation is a seam, not a feature

## Unverified

- **Desktop rendering by eye.** `Readable` caps content at 620pt and the DOM
  confirms `flutter-view` fills the viewport correctly, but this session's
  browser pane captures Flutter canvases at a stale scale, so no screenshot
  proves it. The smoke suite covers 1024pt for every screen.

- **Tapping the floating overseer to open its page.** The handler is wired
  (tap, plus a zero-movement-drag fallback), and the page itself is render-
  tested at every viewport — but the browser pane stopped delivering clicks to
  the Flutter canvas partway through the session, so the gesture was never
  confirmed end to end. There is now also a permanent OVERSEER tab in the
  bottom nav, so the braindump does not depend on hitting a small draggable
  target. Check the gesture on a real device.

## Traps worth knowing

- **Flutter web hot reload does not apply until the page is refreshed.** Two
  separate bugs looked unfixed for a while because of this.
- **Overlays above the `Scaffold` have no `Material` ancestor**, so their text
  renders with Flutter's yellow double-underline debug style. `FeedbackOverlay`
  and `CompanionLayer` each wrap their stack in a transparent `Material` for
  exactly this reason — don't remove it.
- **`NumericFlow` counts up from zero on first load.** The balance is briefly
  wrong-looking on a fresh page; that is the animation, not a persistence bug.
  Cross-check against a non-animated figure like "N TO GO".
- **Wide-tracked caps overflow narrow screens easily.** Use `SpreadRow` for any
  label-left / value-right pair rather than `Row` + `Spacer`.
- **Never schedule animation with a bare `Future.delayed`.** The overseer's
  blink did, which leaked a timer and failed every widget test at teardown with
  `!timersPending`. Hold a `Timer` and cancel it in `dispose`.
- **Structural model changes reject hot reload** ("const class cannot remove
  fields"). Restart the dev server rather than reloading.
- `speech_to_text` and `image_picker` need iOS/Android permission strings in
  `Info.plist` / `AndroidManifest.xml`. Not added — they'll fail on device.
- Web CORS blocks some product image URLs from grounded search. `RewardImage`'s
  `errorBuilder` falls through to the plate.
- Grounding and JSON mode can't be combined in one Gemini call, so pricing is
  deliberately two hops. Documented in `overseer_ai.dart`.

## Next up

1. Confirm the overseer tap gesture on a device or a fresh browser session.
2. Supabase schema + RLS + auth + `SupabaseRepository` (the big one — makes it
   multi-user and real).
3. Firebase project + `firebase_options.dart`, which switches on every AI path
   at once: wish pricing, image ingestion, braindump triage and the companion's
   live voice.
4. Monthly consistency challenge; earning appearance options rather than having
   them all from the start.
5. Mastery screen, trophy case, tablet dashboard.
