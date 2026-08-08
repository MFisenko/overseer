import '../models/cosmetic.dart';

/// The free side of the reward economy.
///
/// These cost nothing real and can only be achieved. Their job is to give a
/// steady drip of earned wins on the many ordinary days when no real purchase
/// is anywhere in reach — which is most days, and is exactly when a motivation
/// app either holds someone or loses them.
///
/// Unlock conditions are evaluated against live state, so nothing here is ever
/// granted by hand. The catalogue is fixed content, not user data, and it
/// presumes nothing about who the user is.
List<Cosmetic> buildCosmeticCatalog() => const [
      // ------------------------------------------------------------- titles
      Cosmetic(
        id: 'title.subject',
        name: 'SUBJECT',
        type: CosmeticType.title,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 1,
        unlockDescription: 'Exist.',
        unlocked: true,
        equipped: true,
      ),
      Cosmetic(
        id: 'title.compliant',
        name: 'COMPLIANT',
        type: CosmeticType.title,
        unlockKind: UnlockKind.questsCollected,
        unlockThreshold: 10,
        unlockDescription: 'Collect 10 directives.',
      ),
      Cosmetic(
        id: 'title.productive-asset',
        name: 'PRODUCTIVE ASSET',
        type: CosmeticType.title,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 10,
        unlockDescription: 'Reach tier 10.',
      ),
      Cosmetic(
        id: 'title.unbroken',
        name: 'UNBROKEN',
        type: CosmeticType.title,
        unlockKind: UnlockKind.streak,
        unlockThreshold: 14,
        unlockDescription: 'Hold a 14-day streak.',
      ),
      Cosmetic(
        id: 'title.practitioner',
        name: 'PRACTITIONER',
        type: CosmeticType.title,
        unlockKind: UnlockKind.masteryHours,
        unlockThreshold: 50,
        unlockDescription: 'Log 50 hours on one track.',
      ),
      Cosmetic(
        id: 'title.exemplary',
        name: 'EXEMPLARY',
        type: CosmeticType.title,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 30,
        unlockDescription: 'Reach tier 30.',
      ),
      Cosmetic(
        id: 'title.irreplaceable',
        name: 'IRREPLACEABLE',
        type: CosmeticType.title,
        unlockKind: UnlockKind.lifetimeXp,
        unlockThreshold: 50000,
        unlockDescription: 'Bank 50,000 lifetime XP.',
      ),

      // ------------------------------------------------------------ badges
      Cosmetic(
        id: 'badge.first-blood',
        name: 'FIRST MOVE',
        type: CosmeticType.badge,
        unlockKind: UnlockKind.questsCollected,
        unlockThreshold: 1,
        unlockDescription: 'Collect a single directive.',
        glyph: '▪',
      ),
      Cosmetic(
        id: 'badge.week-one',
        name: 'SEVEN DAYS',
        type: CosmeticType.badge,
        unlockKind: UnlockKind.streak,
        unlockThreshold: 7,
        unlockDescription: 'Hold a 7-day streak.',
        glyph: '▰',
      ),
      Cosmetic(
        id: 'badge.thirty',
        name: 'THIRTY DAYS',
        type: CosmeticType.badge,
        unlockKind: UnlockKind.streak,
        unlockThreshold: 30,
        unlockDescription: 'Hold a 30-day streak.',
        glyph: '◆',
      ),
      Cosmetic(
        id: 'badge.first-claim',
        name: 'CONVERTED',
        type: CosmeticType.badge,
        unlockKind: UnlockKind.rewardsClaimed,
        unlockThreshold: 1,
        unlockDescription: 'Claim your first real reward.',
        glyph: '◈',
      ),
      Cosmetic(
        id: 'badge.collector',
        name: 'COLLECTOR',
        type: CosmeticType.badge,
        unlockKind: UnlockKind.rewardsClaimed,
        unlockThreshold: 10,
        unlockDescription: 'Claim 10 real rewards.',
        glyph: '◉',
      ),
      Cosmetic(
        id: 'badge.centurion',
        name: 'CENTURION',
        type: CosmeticType.badge,
        unlockKind: UnlockKind.questsCollected,
        unlockThreshold: 100,
        unlockDescription: 'Collect 100 directives.',
        glyph: '⬢',
      ),
      Cosmetic(
        id: 'badge.deep-hours',
        name: 'DEEP HOURS',
        type: CosmeticType.badge,
        unlockKind: UnlockKind.masteryHours,
        unlockThreshold: 100,
        unlockDescription: 'Log 100 hours on one track.',
        glyph: '⬣',
      ),

      // ----------------------------------------------------------- avatars
      Cosmetic(
        id: 'avatar.null',
        name: 'NULL',
        type: CosmeticType.avatar,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 1,
        unlockDescription: 'Issued on intake.',
        unlocked: true,
        equipped: true,
        glyph: '◻',
      ),
      Cosmetic(
        id: 'avatar.mono',
        name: 'MONOLITH',
        type: CosmeticType.avatar,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 5,
        unlockDescription: 'Reach tier 5.',
        glyph: '▮',
      ),
      Cosmetic(
        id: 'avatar.lattice',
        name: 'LATTICE',
        type: CosmeticType.avatar,
        unlockKind: UnlockKind.masteryLevel,
        unlockThreshold: 5,
        unlockDescription: 'Reach mastery level 5 on any track.',
        glyph: '▩',
      ),
      Cosmetic(
        id: 'avatar.aperture',
        name: 'APERTURE',
        type: CosmeticType.avatar,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 25,
        unlockDescription: 'Reach tier 25.',
        glyph: '◎',
      ),

      // ------------------------------------------------ dashboard skins
      Cosmetic(
        id: 'skin.baseline',
        name: 'BASELINE',
        type: CosmeticType.skin,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 1,
        unlockDescription: 'Default issue.',
        unlocked: true,
        equipped: true,
      ),
      Cosmetic(
        id: 'skin.phosphor',
        name: 'PHOSPHOR',
        type: CosmeticType.skin,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 15,
        unlockDescription: 'Reach tier 15.',
      ),
      Cosmetic(
        id: 'skin.bone',
        name: 'BONE',
        type: CosmeticType.skin,
        unlockKind: UnlockKind.streak,
        unlockThreshold: 21,
        unlockDescription: 'Hold a 21-day streak.',
      ),
      Cosmetic(
        id: 'skin.redline',
        name: 'REDLINE',
        type: CosmeticType.skin,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 40,
        unlockDescription: 'Reach tier 40.',
      ),

      // ------------------------------------------- the overseer's own skins
      // The watcher visibly evolves as the user does. This is the most
      // motivating cosmetic slot in the app, because it changes the thing that
      // is on screen at all times.
      Cosmetic(
        id: 'companion.origin',
        name: 'ORIGIN',
        type: CosmeticType.companionSkin,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 1,
        unlockDescription: 'Default issue.',
        unlocked: true,
        equipped: true,
      ),
      Cosmetic(
        id: 'companion.wire',
        name: 'WIREFRAME',
        type: CosmeticType.companionSkin,
        unlockKind: UnlockKind.questsCollected,
        unlockThreshold: 25,
        unlockDescription: 'Collect 25 directives.',
      ),
      Cosmetic(
        id: 'companion.gold',
        name: 'GILT',
        type: CosmeticType.companionSkin,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 20,
        unlockDescription: 'Reach tier 20.',
      ),
      Cosmetic(
        id: 'companion.void',
        name: 'VOID',
        type: CosmeticType.companionSkin,
        unlockKind: UnlockKind.streak,
        unlockThreshold: 60,
        unlockDescription: 'Hold a 60-day streak.',
      ),
      Cosmetic(
        id: 'companion.crimson',
        name: 'CRIMSON',
        type: CosmeticType.companionSkin,
        unlockKind: UnlockKind.masteryHours,
        unlockThreshold: 250,
        unlockDescription: 'Log 250 hours on one track.',
      ),
      Cosmetic(
        id: 'companion.apex',
        name: 'APEX',
        type: CosmeticType.companionSkin,
        unlockKind: UnlockKind.tier,
        unlockThreshold: 50,
        unlockDescription: 'Clear the season.',
      ),
    ];
