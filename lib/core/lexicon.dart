/// Every user-facing name for a game concept lives here, so the vocabulary can
/// be re-skinned in one edit instead of being chased through forty widgets.
class Lex {
  const Lex._();

  static const appName = 'OVERSEER';

  /// The spendable currency.
  static const currency = 'CREDITS';
  static const currencyOne = 'CREDIT';

  /// What a negative upkeep balance is called.
  static const deficit = 'DEFICIT';
  static const arrears = 'ARREARS';

  /// The recurring cost of simply being alive.
  static const upkeep = 'UPKEEP';
  static const obligation = 'OBLIGATION';
  static const obligations = 'OBLIGATIONS';

  /// The real-money pot behind the rewards.
  static const fund = 'RESERVE';

  static const xp = 'XP';
  static const level = 'LEVEL';
  static const tier = 'TIER';
  static const quest = 'DIRECTIVE';
  static const quests = 'DIRECTIVES';
  static const mastery = 'MASTERY';
  static const trophy = 'ARCHIVE';
  static const bucketList = 'MANIFEST';
}
