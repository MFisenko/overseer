import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:overseer/core/economy.dart';
import 'package:overseer/core/horizon.dart';
import 'package:overseer/data/local_repository.dart';
import 'package:overseer/models/quest.dart';
import 'package:overseer/models/reward.dart';
import 'package:overseer/models/upkeep.dart';
import 'package:overseer/models/appearance.dart';
import 'package:overseer/screens/companion/overseer_screen.dart';
import 'package:overseer/screens/home/home_screen.dart';
import 'package:overseer/screens/pass/pass_screen.dart';
import 'package:overseer/screens/quests/quest_log_screen.dart';
import 'package:overseer/screens/reward/reward_detail_screen.dart';
import 'package:overseer/screens/settings/settings_screen.dart';
import 'package:overseer/screens/store/store_screen.dart';
import 'package:overseer/screens/vault/vault_screen.dart';
import 'package:overseer/state/game_state.dart';
import 'package:overseer/models/companion.dart';
import 'package:overseer/theme/app_theme.dart';
import 'package:overseer/widgets/primitives.dart' show euro;
import 'package:overseer/widgets/companion/overseer_eye.dart';

/// Renders every screen at several viewport sizes, in both themes, with both
/// an empty account and a populated one, and fails on any layout overflow.
///
/// This exists because a `RenderFlex overflowed` is the single most likely way
/// this interface breaks — the type is large, the labels are wide-tracked, and
/// the credit figures grow without bound. Catching it here is far cheaper than
/// catching it by looking.
void main() {
  setUpAll(() {
    // Tests have no network; without this google_fonts throws rather than
    // falling back.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Phone, small phone, and tablet. The small one is where things break.
  const viewports = <(String, Size)>[
    ('phone', Size(390, 844)),
    ('small phone', Size(320, 640)),
    ('tablet', Size(1024, 768)),
  ];

  Future<GameState> buildState({bool populated = false}) async {
    final game = GameState(LocalRepository(namespace: 'test'));
    await game.load();
    if (populated) {
      await game.addQuest(
        title: 'One focused work session on the thing that pays',
        xpValue: Economy.xpSession,
        coinValue: 25,
        cadence: Cadence.daily,
      );
      await game.addQuest(
        title: 'Tidy the flat',
        xpValue: Economy.xpSmall,
        cadence: Cadence.weekly,
        targetCount: 3,
      );
      // A finished directive so the collect state renders too.
      final q = await game.addQuest(
          title: 'Wash the dishes', xpValue: Economy.xpTrivial, cadence: Cadence.daily);
      await game.completeQuest(q.id);

      final bucket = await game.ensureBucket('TRAVEL');
      await game.addReward(Reward(
        id: 'r1',
        name: 'A week in the Dolomites, hut to hut',
        description: 'Late summer, boots already owned.',
        bucketId: bucket.id,
        bucketName: bucket.name,
        tier: MoneyTier.ultimate,
        priceEuro: 1200,
        coinCost: Economy.euroToCoins(1200),
        createdAt: DateTime.now(),
      ));

      // A goal far past one season, so the vault renders with real content.
      await game.addReward(Reward(
        id: 'r2',
        name: 'Deposit on a small flat',
        bucketId: bucket.id,
        bucketName: bucket.name,
        tier: MoneyTier.ultimate,
        priceEuro: 42000,
        coinCost: Economy.euroToCoins(42000),
        earmarkPercent: 40,
        savedEuro: 1250,
        createdAt: DateTime.now(),
      ));
      await game.setExpectedIncome(2000);

      await game.addObligation(
          name: 'Rent', amountEuro: 850, cadence: ObligationCadence.monthly);
      await game.logIncome(amountEuro: 2400, source: 'Client work', xp: 0);
      await game.grantDemoXp(9000);
    }
    return game;
  }

  /// Runs [body] and returns a readable report of every framework error it
  /// raised.
  ///
  /// `tester.takeException()` throws away everything except the summary line,
  /// which turns "a RenderFlex overflowed" into a scavenger hunt. Capturing
  /// `onError` directly keeps the widget chain and the source location, which
  /// is the only part that actually tells you what to fix.
  Future<String?> collectErrors(Future<void> Function() body) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await body();
    } finally {
      FlutterError.onError = previous;
    }
    if (errors.isEmpty) return null;
    return errors.map((e) {
      final where = e.library ?? '';
      final context = e.context?.toDescription() ?? '';
      return '${e.exceptionAsString()}\n  in: $context ($where)\n'
          '${e.toDiagnosticsNode().toStringDeep(minLevel: DiagnosticLevel.info)}';
    }).join('\n---\n');
  }

  Widget wrap(GameState game, Widget child, {required bool dark}) =>
      ChangeNotifierProvider<GameState>.value(
        value: game,
        child: MaterialApp(
          theme: dark ? darkTheme : lightTheme,
          home: child,
        ),
      );

  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'pass': () => const PassScreen(),
    'store': () => const StoreScreen(),
    'log': () => const QuestLogScreen(),
    'settings': () => const SettingsScreen(),
    'overseer': () => const OverseerScreen(),
    'vault': () => const VaultScreen(),
  };

  for (final populated in [false, true]) {
    final label = populated ? 'populated' : 'empty';
    for (final (vpName, size) in viewports) {
      for (final dark in [false, true]) {
        final mode = dark ? 'dark' : 'light';

        for (final entry in screens.entries) {
          testWidgets('${entry.key} lays out on $vpName in $mode when $label',
              (tester) async {
            tester.view
              ..physicalSize = size
              ..devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final game = await buildState(populated: populated);
            final report = await collectErrors(() async {
              await tester.pumpWidget(wrap(game, entry.value(), dark: dark));
              // Settle animations; the app is full of implicit tweens.
              await tester.pump(const Duration(seconds: 1));
            });

            expect(report, isNull,
                reason: '${entry.key} on $vpName/$mode/$label:\n$report');
          });
        }
      }
    }
  }

  testWidgets('reward detail lays out and shows its price', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = await buildState(populated: true);
    await tester.pumpWidget(
        wrap(game, const RewardDetailScreen(rewardId: 'r1'), dark: false));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('A week in the Dolomites, hut to hut'), findsOneWidget);
    // €1,200 at the peg is 120,000 credits.
    expect(find.text('120,000'), findsWidgets);
  });

  testWidgets('a missing reward degrades instead of crashing', (tester) async {
    final game = await buildState();
    await tester.pumpWidget(
        wrap(game, const RewardDetailScreen(rewardId: 'nope'), dark: false));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('No longer on the manifest.'), findsOneWidget);
  });

  testWidgets('the vault dates a long goal and shows its own pot',
      (tester) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = await buildState(populated: true);

    // €42,000 at €2,000/month and 10% set aside is 17.5 years of the whole
    // reserve — far past the ten-year horizon, so it belongs in the vault and
    // must never be pinned to a season ladder.
    final flat = game.rewardById('r2')!;
    expect(game.horizonOf(flat), Horizon.beyondHorizon);
    expect(game.horizonOf(flat).eligibleForSeason, isFalse);
    expect(game.longRangeGoals.map((r) => r.id), contains('r2'));
    expect(game.storeStock.map((r) => r.id), isNot(contains('r2')));

    await tester.pumpWidget(wrap(game, const VaultScreen(), dark: false));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Deposit on a small flat'), findsOneWidget);

    // Its own pot, not the shared reserve — and larger than it was seeded
    // with, because the earmark took its share of the logged income.
    final saved = game.rewardById('r2')!.savedEuro;
    expect(saved, greaterThan(1250));
    expect(find.textContaining(euro(saved)), findsWidgets);

    // Money in the pot is money the general reserve does not hold.
    expect(game.fund.balanceEuro, lessThan(240));
  });

  test('a raise pulls a long goal back inside the horizon', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameState(LocalRepository(namespace: 'promo'));
    await game.load();

    final bucket = await game.ensureBucket('TRANSPORT');
    await game.addReward(Reward(
      id: 'car',
      name: 'A used estate car',
      bucketId: bucket.id,
      bucketName: bucket.name,
      tier: MoneyTier.ultimate,
      priceEuro: 9500,
      coinCost: Economy.euroToCoins(9500),
      createdAt: DateTime.now(),
    ));

    // On €1,200 a month, 10% set aside is €1,440 a year — €9,500 is nearly
    // seven years out, so the car lives in the vault and never touches the
    // ladder.
    await game.setExpectedIncome(1200);
    expect(game.horizonOf(game.rewardById('car')!), Horizon.longRange);
    expect(game.longRangeGoals.map((r) => r.id), contains('car'));
    expect(game.storeStock.map((r) => r.id), isNot(contains('car')));

    // A large raise: €10,800 a year reaching the reserve puts it under a year
    // out. Out of the vault, onto the shelf, but still not a single season.
    await game.setExpectedIncome(9000);
    expect(game.horizonOf(game.rewardById('car')!), Horizon.onDeck);
    expect(game.longRangeGoals.map((r) => r.id), isNot(contains('car')));
    expect(game.storeStock.map((r) => r.id), contains('car'));

    // Enough that a season covers it, and the ladder may now pin it.
    await game.setExpectedIncome(40000);
    expect(game.horizonOf(game.rewardById('car')!).eligibleForSeason, isTrue);
  });

  test('earmarks route income into a goal\'s own pot', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameState(LocalRepository(namespace: 'earmark'));
    await game.load();

    final bucket = await game.ensureBucket('HOME');
    await game.addReward(Reward(
      id: 'deposit',
      name: 'Deposit',
      bucketId: bucket.id,
      bucketName: bucket.name,
      tier: MoneyTier.ultimate,
      priceEuro: 40000,
      coinCost: Economy.euroToCoins(40000),
      createdAt: DateTime.now(),
    ));
    await game.setEarmark('deposit', 50);

    // €1,000 in, 10% set aside = €100 to the reserve. Half is earmarked.
    await game.logIncome(amountEuro: 1000, xp: 0);

    expect(game.rewardById('deposit')!.savedEuro, closeTo(50, 0.01));
    expect(game.fund.balanceEuro, closeTo(50, 0.01));
  });

  test('earmarks can never allocate more of the reserve than exists', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameState(LocalRepository(namespace: 'cap'));
    await game.load();

    final bucket = await game.ensureBucket('HOME');
    for (final id in ['a', 'b']) {
      await game.addReward(Reward(
        id: id,
        name: id,
        bucketId: bucket.id,
        bucketName: bucket.name,
        tier: MoneyTier.ultimate,
        priceEuro: 30000,
        coinCost: Economy.euroToCoins(30000),
        createdAt: DateTime.now(),
      ));
    }
    await game.setEarmark('a', 80);
    await game.setEarmark('b', 80); // only 20 left

    expect(game.rewardById('b')!.earmarkPercent, 20);
    expect(game.earmarkedPercent, lessThanOrEqualTo(100));
  });

  testWidgets('every overseer shape and finish renders', (tester) async {
    // The silhouettes are built from a rounded-polygon routine that has to
    // cope with acute star tips and concave vertices; a bad path throws at
    // paint time, which no amount of looking at one shape would catch.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final shape in OverseerShape.values) {
      for (final finish in OverseerFinish.values) {
        await tester.pumpWidget(MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Center(
              child: OverseerEye(
                mood: CompanionMood.idle,
                appearance:
                    Appearance(shape: shape, finish: finish, paintId: 'paint.gilt'),
                size: 120,
                flat: true,
              ),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: '${shape.name} in ${finish.name} failed to paint');
      }
    }
  });

  test('the catalogue offers well over a hundred looks', () {
    expect(Appearance.lookCount, greaterThan(100));
  });

  testWidgets('the ladder builds all 150 rungs without overflow',
      (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = await buildState(populated: true);
    await tester.pumpWidget(wrap(game, const PassScreen(), dark: true));
    await tester.pump(const Duration(seconds: 1));

    // Scroll the whole ladder; a feature card near the end is as likely to
    // break as one near the start.
    final list = find.byType(Scrollable).last;
    for (var i = 0; i < 12; i++) {
      await tester.drag(list, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull, reason: 'overflow while scrolling');
    }
  });
}
