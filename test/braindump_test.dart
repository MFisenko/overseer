import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:overseer/data/local_repository.dart';
import 'package:overseer/models/quest.dart';
import 'package:overseer/models/upkeep.dart';
import 'package:overseer/services/braindump.dart';
import 'package:overseer/state/game_state.dart';

/// The braindump is the fastest way into the app, so a line that lands in the
/// wrong place is worse than one that is refused — a misfiled cost quietly
/// breaks the upkeep ledger, and a chore on the wishlist is just wrong.
void main() {
  const p = BraindumpParser();

  DumpItem one(String line) => p.parse(line).single;

  group('costs are recognised without a currency symbol', () {
    test('rent with a bare figure is a cost, not a habit', () {
      final i = one('rent is 850 a month');
      expect(i.kind, DumpKind.obligation);
      expect(i.amountEuro, 850);
      expect(i.obligationCadence, ObligationCadence.monthly);
    });

    test('a weekly cost keeps its cadence', () {
      final i = one('transport 40 a week');
      expect(i.kind, DumpKind.obligation);
      expect(i.obligationCadence, ObligationCadence.weekly);
      expect(i.amountEuro, 40);
    });

    test('a symbol still works', () {
      expect(one('internet €35 monthly').amountEuro, 35);
    });

    test('paying a bill is a completed task, not a new standing cost', () {
      expect(one('paid the rent').kind, DumpKind.done);
    });
  });

  group('chores never reach the wishlist', () {
    test('buying groceries is an errand', () {
      expect(one('buy groceries').kind, DumpKind.task);
    });

    test('a recurring chore is a habit', () {
      final i = one('dishes every day');
      expect(i.kind, DumpKind.habit);
      expect(i.cadence, Cadence.daily);
    });

    test('a counted chore keeps its target', () {
      expect(one('tidy the flat 3 times a week').targetCount, 3);
    });
  });

  group('wants are wants', () {
    test('"want" marks a wish', () {
      expect(one('want a field recorder').kind, DumpKind.wish);
    });

    test('"buy a <thing>" is a wish, unlike "buy groceries"', () {
      expect(one('buy a new synth').kind, DumpKind.wish);
    });
  });

  test('a repeat count is not mistaken for money', () {
    // "gym 3 times a week" must not become a €3 obligation.
    final i = one('gym 3 times a week');
    expect(i.kind, DumpKind.habit);
    expect(i.amountEuro, isNull);
    expect(i.targetCount, 3);
  });

  test('a multi-line dump splits into one item per line', () {
    final items = p.parse('''rent is 850 a month
dishes every day
want a field recorder
finished the invoices
call the dentist''');
    expect(items.length, 5);
    expect(items.map((i) => i.kind), [
      DumpKind.obligation,
      DumpKind.habit,
      DumpKind.wish,
      DumpKind.done,
      DumpKind.task,
    ]);
  });

  test('filing a dump actually creates everything it promised', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameState(LocalRepository(namespace: 'dump'));
    await game.load();

    // Mirrors what the screen does, minus the AI pass.
    final items = p.parse('''rent is 850 a month
dishes every day
call the dentist
finished the invoices''');

    for (final item in items) {
      switch (item.kind) {
        case DumpKind.task:
        case DumpKind.habit:
          await game.addQuest(
              title: item.text,
              xpValue: item.xp,
              cadence: item.cadence,
              targetCount: item.targetCount);
        case DumpKind.done:
          final q = await game.addQuest(
              title: item.text, xpValue: item.xp, cadence: Cadence.once);
          await game.completeQuest(q.id);
          await game.collectQuest(q.id);
        case DumpKind.obligation:
          await game.addObligation(
              name: item.text,
              amountEuro: item.amountEuro ?? 0,
              cadence: item.obligationCadence);
        case DumpKind.wish:
          break;
      }
    }
    await game.rewardBraindump(items.length);

    // The cost reached the upkeep ledger and is being burned daily.
    expect(game.obligations.length, 1);
    expect(game.obligations.single.amountEuro, 850);
    expect(game.dailyBurnCredits, greaterThan(0));

    // The habit recurs, the errand does not.
    expect(game.questsOf(Cadence.daily).length, 1);
    expect(game.questsOf(Cadence.once).length, 1);

    // The already-done line was banked rather than left hanging.
    expect(game.profile.questsCollected, 1);
    expect(game.wallet.totalXp, greaterThan(0));
  });
}
