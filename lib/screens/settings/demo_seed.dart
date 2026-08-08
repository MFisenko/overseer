import 'package:uuid/uuid.dart';

import '../../core/economy.dart';
import '../../models/quest.dart';
import '../../models/reward.dart';
import '../../models/upkeep.dart';
import '../../state/game_state.dart';

/// Fills a fresh account with plausible content so the interface can actually
/// be looked at.
///
/// Debug builds only, and never wired into any user-facing path — an empty
/// account is the correct first-run experience, and this exists purely so the
/// layout can be judged against real content instead of against empty states.
Future<void> seedDemoData(GameState game) async {
  const uuid = Uuid();

  // ------------------------------------------------------------- directives
  const directives = <(String, int, Cadence, int, int)>[
    ('Wash the dishes', Economy.xpTrivial, Cadence.daily, 5, 1),
    ('Walk for 30 minutes', Economy.xpTrivial, Cadence.daily, 5, 1),
    ('One focused work session', Economy.xpSession, Cadence.daily, 25, 1),
    ('Tidy the flat', Economy.xpSmall, Cadence.weekly, 10, 3),
    ('Practice set for the weekend', Economy.xpSession, Cadence.weekly, 25, 2),
    ('Invoice the month\'s clients', Economy.xpBigWin, Cadence.monthly, 60, 1),
  ];
  for (final (title, xp, cadence, coins, target) in directives) {
    await game.addQuest(
      title: title,
      xpValue: xp,
      coinValue: coins,
      cadence: cadence,
      targetCount: target,
    );
  }

  // ----------------------------------------------------------------- wishes
  // Spread across all three money tiers so the ladder and store both have
  // something to show at every price point. Images come from a CORS-permissive
  // placeholder service; real entries get real product photography.
  const wishes = <(String, String, String, double)>[
    ('Field recorder', 'GEAR',
        'A compact stereo recorder for capturing room tone and found sound.', 249),
    ('Espresso grinder', 'HOME',
        'Flat burrs, stepless adjustment. The thing that actually decides whether the coffee is good.', 420),
    ('Weekend in Lisbon', 'TRAVEL',
        'Three nights, flights included, off-season.', 380),
    ('Studio monitors', 'MUSIC',
        'A matched pair, five-inch, for mixing at honest volume.', 690),
    ('Merino overshirt', 'CLOTHING',
        'One good layer that works for eight months of the year.', 180),
    ('Analogue synth', 'MUSIC',
        'Monophonic, two oscillators, no menus.', 1450),
    ('Good chef\'s knife', 'HOME',
        'Carbon steel, 210mm. Sharpened properly it lasts decades.', 145),
    ('Noise-cancelling headphones', 'GEAR',
        'For trains, planes and open-plan rooms.', 320),
    ('A week in the Dolomites', 'TRAVEL',
        'Hut to hut, late summer, boots already owned.', 1200),
    ('Modular home deposit', 'HOME',
        'The long one. Prefabricated, off-grid capable, sited on rented land.', 42000),
    ('A used estate car', 'TRANSPORT',
        'Nothing exciting. Reliable, cheap to run, big enough for the gear.', 9500),
    ('A year of runway', 'FREEDOM',
        'Twelve months of covered obligations, so a bad quarter is not a crisis.',
        14000),
  ];

  for (final (name, bucket, description, price) in wishes) {
    final b = await game.ensureBucket(bucket);
    final id = uuid.v4();
    await game.addReward(Reward(
      id: id,
      name: name,
      description: description,
      bucketId: b.id,
      bucketName: b.name,
      tier: MoneyTierInfo.fromEuro(price),
      priceEuro: price,
      coinCost: Economy.euroToCoins(price),
      searchTerm: name,
      imageUrl: 'https://picsum.photos/seed/${Uri.encodeComponent(name)}/900/700',
      origin: RewardOrigin.manual,
      createdAt: DateTime.now(),
    ));
  }

  // ------------------------------------------------------------ obligations
  await game.addObligation(
      name: 'Rent', amountEuro: 850, cadence: ObligationCadence.monthly);
  await game.addObligation(
      name: 'Food', amountEuro: 95, cadence: ObligationCadence.weekly);
  await game.addObligation(
      name: 'Transport & subscriptions',
      amountEuro: 140,
      cadence: ObligationCadence.monthly);

  // ------------------------------------------------------------ the ladder
  // Calibrate before granting XP, so the season's payouts are built from a
  // real income rather than the conservative fallback.
  await game.setExpectedIncome(2400);

  // ---------------------------------------------------------------- history
  // Enough logged income to part-fund the reserve, and enough XP to sit a
  // meaningful way up the ladder rather than at tier one.
  await game.logIncome(amountEuro: 2400, source: 'Client work', xp: 0);
  await game.logIncome(amountEuro: 780, source: 'A gig', xp: 0);
  await game.grantDemoXp(9000);

  // Two long goals actually being saved toward, so the vault shows pots
  // filling rather than a list of things standing still.
  for (final r in game.rewards) {
    if (r.name == 'A used estate car') await game.setEarmark(r.id, 30);
    if (r.name == 'Modular home deposit') await game.setEarmark(r.id, 20);
  }
  // A few months of income so those pots are visibly non-zero.
  for (var i = 0; i < 4; i++) {
    await game.logIncome(amountEuro: 2400, source: 'Client work', xp: 0);
  }
}
