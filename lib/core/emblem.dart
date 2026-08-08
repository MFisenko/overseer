/// Which insignia a reward or tier wears.
///
/// Original geometry — concentric rings, chevrons, radial spokes — in the
/// register of a faction crest without borrowing any specific one. They exist
/// so a reward reads as *ranked* at a glance, before any text is read.
///
/// The enum lives in core rather than beside its painter so models can classify
/// themselves without reaching up into the widget layer.
enum Emblem {
  /// Small tier. A single ring, one mark.
  mark,

  /// Mid tier. Ring, chevron, spokes.
  crest,

  /// Ultimate tier. Radial burst inside a double ring.
  apex,

  /// In-app unlocks, as opposed to real-world things.
  cipher,

  /// Locked long-term goals.
  sealed_,
}
