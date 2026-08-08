import '../core/rarity.dart';
import 'appearance.dart';

/// Which axis of the overseer an unlockable changes.
enum UnlockSlot { shape, finish, paint, eye, accessory, persona }

extension UnlockSlotLabel on UnlockSlot {
  String get label => switch (this) {
        UnlockSlot.shape => 'SHAPE',
        UnlockSlot.finish => 'MATERIAL',
        UnlockSlot.paint => 'PAINT',
        UnlockSlot.eye => 'EYE',
        UnlockSlot.accessory => 'ACCESSORY',
        UnlockSlot.persona => 'PERSONALITY',
      };
}

/// One purchasable or earnable piece of the overseer's look.
///
/// The catalogue is generated rather than hand-written: every value of every
/// appearance enum becomes exactly one of these, so adding a new shape to the
/// enum automatically gives it a price, a rarity and a place in the store.
/// Nothing can be added to the game and then silently be unobtainable.
class Unlockable {
  final String id;
  final UnlockSlot slot;
  final String name;
  final Rarity rarity;

  /// Free from the start. Every slot has at least one, so a new account is
  /// never staring at a fully locked wardrobe.
  final bool freeByDefault;

  /// In the monthly rotation rather than always on sale. Only one rotating
  /// item is buyable in any given month.
  final bool rotating;

  /// Only obtainable from a lootbox. The rarest things cannot simply be bought,
  /// which is what stops shards from being a straight price list.


  const Unlockable({
    required this.id,
    required this.slot,
    required this.name,
    required this.rarity,
    this.freeByDefault = false,
    this.rotating = false,
  });

  int get shardPrice => rarity.shardPrice;
}

/// Everything the overseer can wear, priced and ranked.
///
/// Rarity is assigned by position within each axis: the first option of a slot
/// is free, the next few are cheap, and the tail is where the interesting ones
/// live. That keeps the mapping mechanical — no bespoke table to fall out of
/// sync with the enums.
class UnlockCatalogue {
  const UnlockCatalogue._();

  static Rarity _rarityAt(int index, int total) {
    if (index == 0) return Rarity.common;
    final position = index / (total - 1);
    if (position < 0.30) return Rarity.common;
    if (position < 0.58) return Rarity.uncommon;
    if (position < 0.80) return Rarity.rare;
    if (position < 0.94) return Rarity.epic;
    return Rarity.legendary;
  }

  /// Roughly a third of everything past the free tier rotates monthly, spread
  /// across slots so no single month is all paint.
  static bool _rotates(int index, Rarity r) =>
      index > 0 && r != Rarity.common && index % 3 == 0;

  static List<Unlockable> _forSlot<T>(
    UnlockSlot slot,
    List<T> values,
    String Function(T) id,
    String Function(T) name,
  ) {
    final out = <Unlockable>[];
    for (var i = 0; i < values.length; i++) {
      final r = _rarityAt(i, values.length);
      out.add(Unlockable(
        id: '${slot.name}.${id(values[i])}',
        slot: slot,
        name: name(values[i]),
        rarity: r,
        freeByDefault: i == 0,
        rotating: _rotates(i, r),
      ));
    }
    return out;
  }

  static final List<Unlockable> all = [
    ..._forSlot<OverseerShape>(
        UnlockSlot.shape, OverseerShape.values, (v) => v.name, (v) => v.label),
    ..._forSlot<OverseerFinish>(
        UnlockSlot.finish, OverseerFinish.values, (v) => v.name, (v) => v.label),
    ..._forSlot<OverseerPaint>(UnlockSlot.paint, OverseerPaint.catalogue,
        (v) => v.id.split('.').last, (v) => v.name),
    ..._forSlot<OverseerEyeKind>(
        UnlockSlot.eye, OverseerEyeKind.values, (v) => v.name, (v) => v.label),
    ..._forSlot<OverseerAccessory>(UnlockSlot.accessory,
        OverseerAccessory.values, (v) => v.name, (v) => v.label),
    ..._forSlot<OverseerPersona>(UnlockSlot.persona, OverseerPersona.values,
        (v) => v.name, (v) => v.label),
  ];

  static Unlockable? byId(String id) {
    for (final u in all) {
      if (u.id == id) return u;
    }
    return null;
  }

  static List<Unlockable> inSlot(UnlockSlot slot) =>
      all.where((u) => u.slot == slot).toList();

  /// Ids every account starts with.
  static Set<String> get freeIds =>
      all.where((u) => u.freeByDefault).map((u) => u.id).toSet();

  /// The one rotating item buyable this month.
  ///
  /// Deterministic from the year and month, so it is the same for a given month
  /// however often the app is opened, and cannot be re-rolled by reloading.
  static Unlockable? rotationFor(DateTime when) {
    final pool = all.where((u) => u.rotating).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (pool.isEmpty) return null;
    final index = (when.year * 12 + when.month) % pool.length;
    return pool[index];
  }

  /// What a lootbox can contain: everything not free and not this month's
  /// rotation — the box is a route to things you could not otherwise buy today.
  static List<Unlockable> boxPool(DateTime when) {
    final rotation = rotationFor(when);
    return all
        .where((u) => !u.freeByDefault && u.id != rotation?.id)
        .toList();
  }

  /// Whether an item can be bought outright right now.
  ///
  /// Rotating items are locked except in their month; everything else non-free
  /// is always on the shelf.
  static bool isBuyable(Unlockable u, DateTime when) {
    if (u.freeByDefault) return false;
    if (!u.rotating) return true;
    return rotationFor(when)?.id == u.id;
  }
}
