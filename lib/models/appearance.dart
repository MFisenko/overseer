import 'dart:ui';

/// The overseer's silhouette.
///
/// Shape, finish, paint and persona are four independent axes that combine, so
/// the catalogue is multiplicative rather than a fixed list of skins: sixteen
/// shapes against twelve finishes against sixteen paints is well past two
/// thousand distinct looks, before personality is chosen at all.
enum OverseerShape {
  triangle,
  invertedTriangle,
  diamond,
  square,
  pentagon,
  hexagon,
  heptagon,
  octagon,
  chevron,
  shield,
  teardrop,
  orb,
  blade,
  monolith,
  starFour,
  starSix,
}

extension OverseerShapeInfo on OverseerShape {
  String get label => switch (this) {
        OverseerShape.triangle => 'DELTA',
        OverseerShape.invertedTriangle => 'NADIR',
        OverseerShape.diamond => 'RHOMB',
        OverseerShape.square => 'BLOCK',
        OverseerShape.pentagon => 'PENTAD',
        OverseerShape.hexagon => 'HEXCELL',
        OverseerShape.heptagon => 'SEPTAD',
        OverseerShape.octagon => 'OCTGATE',
        OverseerShape.chevron => 'CHEVRON',
        OverseerShape.shield => 'AEGIS',
        OverseerShape.teardrop => 'DROPLET',
        OverseerShape.orb => 'ORB',
        OverseerShape.blade => 'BLADE',
        OverseerShape.monolith => 'MONOLITH',
        OverseerShape.starFour => 'QUASAR',
        OverseerShape.starSix => 'SEXTANT',
      };

  /// How much the corners round, as a share of the widget's size.
  double get cornerFactor => switch (this) {
        OverseerShape.orb => 0,
        OverseerShape.monolith => 0.22,
        OverseerShape.starFour || OverseerShape.starSix => 0.05,
        OverseerShape.blade => 0.06,
        _ => 0.10,
      };
}

/// How the surface is made. Drives translucency, sheen and edge treatment —
/// never colour, which is the paint's job.
enum OverseerFinish {
  glass,
  frosted,
  obsidian,
  chrome,
  brushed,
  matte,
  ceramic,
  carbon,
  pearl,
  liquid,
  neon,
  wire,
}

extension OverseerFinishInfo on OverseerFinish {
  String get label => switch (this) {
        OverseerFinish.glass => 'GLASS',
        OverseerFinish.frosted => 'FROSTED',
        OverseerFinish.obsidian => 'OBSIDIAN',
        OverseerFinish.chrome => 'CHROME',
        OverseerFinish.brushed => 'BRUSHED',
        OverseerFinish.matte => 'MATTE',
        OverseerFinish.ceramic => 'CERAMIC',
        OverseerFinish.carbon => 'CARBON',
        OverseerFinish.pearl => 'PEARL',
        OverseerFinish.liquid => 'LIQUID',
        OverseerFinish.neon => 'NEON',
        OverseerFinish.wire => 'WIREFRAME',
      };

  /// How much of the page shows through. 0 is opaque.
  double get transparency => switch (this) {
        OverseerFinish.glass => 0.72,
        OverseerFinish.frosted => 0.55,
        OverseerFinish.wire => 0.92,
        OverseerFinish.liquid => 0.5,
        OverseerFinish.pearl => 0.3,
        OverseerFinish.neon => 0.4,
        OverseerFinish.obsidian => 0.08,
        OverseerFinish.chrome => 0.12,
        _ => 0.18,
      };

  /// Strength of the specular streak across the face.
  double get sheen => switch (this) {
        OverseerFinish.chrome => 1.0,
        OverseerFinish.liquid => 0.9,
        OverseerFinish.glass => 0.7,
        OverseerFinish.pearl => 0.65,
        OverseerFinish.ceramic => 0.5,
        OverseerFinish.obsidian => 0.45,
        OverseerFinish.frosted => 0.3,
        OverseerFinish.brushed => 0.28,
        OverseerFinish.neon => 0.25,
        OverseerFinish.wire => 0.15,
        OverseerFinish.carbon => 0.12,
        OverseerFinish.matte => 0.05,
      };

  /// Whether the page behind is blurred through the body.
  bool get blurs => switch (this) {
        OverseerFinish.glass ||
        OverseerFinish.frosted ||
        OverseerFinish.liquid ||
        OverseerFinish.pearl =>
          true,
        _ => false,
      };

  double get blurSigma => this == OverseerFinish.frosted ? 16 : 9;

  /// Outline weight. Wireframe is nothing but outline.
  double get edgeWidth => switch (this) {
        OverseerFinish.wire => 2.0,
        OverseerFinish.neon => 2.4,
        OverseerFinish.chrome => 1.6,
        _ => 1.3,
      };

  /// Extra bloom cast onto the page.
  double get glowScale => switch (this) {
        OverseerFinish.neon => 2.2,
        OverseerFinish.liquid => 1.5,
        OverseerFinish.pearl => 1.3,
        OverseerFinish.matte || OverseerFinish.carbon => 0.4,
        _ => 1.0,
      };
}

/// The colourway. Paint is separate from finish so a matte crimson and a
/// chrome crimson are both reachable.
class OverseerPaint {
  final String id;
  final String name;

  /// Tint suspended in the body.
  final Color body;

  /// The lit edge.
  final Color edge;

  /// The eye's ring.
  final Color iris;

  /// The pupil. Usually near-black; inverted on pale paints.
  final Color pupil;

  const OverseerPaint({
    required this.id,
    required this.name,
    required this.body,
    required this.edge,
    required this.iris,
    required this.pupil,
  });

  static const catalogue = <OverseerPaint>[
    OverseerPaint(
      id: 'paint.origin',
      name: 'ORIGIN',
      body: Color(0xFF151210),
      edge: Color(0xFFFFFFFF),
      iris: Color(0xFFFDFBF6),
      pupil: Color(0xFF12100C),
    ),
    OverseerPaint(
      id: 'paint.gilt',
      name: 'GILT',
      body: Color(0xFFC9A227),
      edge: Color(0xFFF0D98A),
      iris: Color(0xFFFFF3D2),
      pupil: Color(0xFF251A02),
    ),
    OverseerPaint(
      id: 'paint.crimson',
      name: 'CRIMSON',
      body: Color(0xFFB23A26),
      edge: Color(0xFFE9927C),
      iris: Color(0xFFFFDCD2),
      pupil: Color(0xFF2A0904),
    ),
    OverseerPaint(
      id: 'paint.jade',
      name: 'JADE',
      body: Color(0xFF0C7F73),
      edge: Color(0xFF6FE3D0),
      iris: Color(0xFFDFFFF8),
      pupil: Color(0xFF02201C),
    ),
    OverseerPaint(
      id: 'paint.cobalt',
      name: 'COBALT',
      body: Color(0xFF1F3F8F),
      edge: Color(0xFF7FA6F0),
      iris: Color(0xFFE2ECFF),
      pupil: Color(0xFF050D24),
    ),
    OverseerPaint(
      id: 'paint.amethyst',
      name: 'AMETHYST',
      body: Color(0xFF5B2E8C),
      edge: Color(0xFFC49BF0),
      iris: Color(0xFFF1E4FF),
      pupil: Color(0xFF1A0A28),
    ),
    OverseerPaint(
      id: 'paint.ember',
      name: 'EMBER',
      body: Color(0xFFD2621A),
      edge: Color(0xFFFFB26B),
      iris: Color(0xFFFFE8D2),
      pupil: Color(0xFF2B1002),
    ),
    OverseerPaint(
      id: 'paint.bone',
      name: 'BONE',
      body: Color(0xFFEDE6D8),
      edge: Color(0xFFFFFFFF),
      iris: Color(0xFF2A241B),
      pupil: Color(0xFFEDE6D8),
    ),
    OverseerPaint(
      id: 'paint.void',
      name: 'VOID',
      body: Color(0xFF000000),
      edge: Color(0xFF3A3A3A),
      iris: Color(0xFFFFFFFF),
      pupil: Color(0xFF000000),
    ),
    OverseerPaint(
      id: 'paint.sage',
      name: 'SAGE',
      body: Color(0xFF6F8465),
      edge: Color(0xFFB9CDA9),
      iris: Color(0xFFF0F6E9),
      pupil: Color(0xFF171E12),
    ),
    OverseerPaint(
      id: 'paint.rose',
      name: 'ROSE',
      body: Color(0xFFB5566F),
      edge: Color(0xFFF3A6BA),
      iris: Color(0xFFFFE6EC),
      pupil: Color(0xFF2A0912),
    ),
    OverseerPaint(
      id: 'paint.ink',
      name: 'INK',
      body: Color(0xFF1B2430),
      edge: Color(0xFF6E8095),
      iris: Color(0xFFDCE6F2),
      pupil: Color(0xFF070B10),
    ),
    OverseerPaint(
      id: 'paint.copper',
      name: 'COPPER',
      body: Color(0xFF8C4B2A),
      edge: Color(0xFFD98F5F),
      iris: Color(0xFFFFE0C8),
      pupil: Color(0xFF200E05),
    ),
    OverseerPaint(
      id: 'paint.arctic',
      name: 'ARCTIC',
      body: Color(0xFFB8D8E8),
      edge: Color(0xFFFFFFFF),
      iris: Color(0xFF12242E),
      pupil: Color(0xFFDDF1FA),
    ),
    OverseerPaint(
      id: 'paint.sulphur',
      name: 'SULPHUR',
      body: Color(0xFFC9B429),
      edge: Color(0xFFF2E27A),
      iris: Color(0xFF2A2604),
      pupil: Color(0xFFF7EFA8),
    ),
    OverseerPaint(
      id: 'paint.oxide',
      name: 'OXIDE',
      body: Color(0xFF5C4033),
      edge: Color(0xFFA9836B),
      iris: Color(0xFFF0E0D2),
      pupil: Color(0xFF160D07),
    ),
  ];

  static OverseerPaint byId(String? id) {
    if (id == null) return catalogue.first;
    for (final p in catalogue) {
      if (p.id == id) return p;
    }
    return catalogue.first;
  }
}

/// How the overseer talks.
///
/// Personality only ever changes *register*, never intent. Every persona is
/// steering the user toward something they chose, and none of them are
/// permitted to actually demean the person reading — a user who feels mocked
/// closes the app, and a closed app motivates nobody.
enum OverseerPersona {
  overseer,
  archivist,
  handler,
  oracle,
  drill,
  concierge,
  ghost,
  auditor,
}

extension OverseerPersonaInfo on OverseerPersona {
  String get label => switch (this) {
        OverseerPersona.overseer => 'OVERSEER',
        OverseerPersona.archivist => 'ARCHIVIST',
        OverseerPersona.handler => 'HANDLER',
        OverseerPersona.oracle => 'ORACLE',
        OverseerPersona.drill => 'DRILL',
        OverseerPersona.concierge => 'CONCIERGE',
        OverseerPersona.ghost => 'GHOST',
        OverseerPersona.auditor => 'AUDITOR',
      };

  String get blurb => switch (this) {
        OverseerPersona.overseer => 'Clipped, dry, faintly ominous. The default.',
        OverseerPersona.archivist => 'Speaks only in records and dates.',
        OverseerPersona.handler => 'Terse operational briefings. You are an asset.',
        OverseerPersona.oracle => 'Oblique, patient, slightly too knowing.',
        OverseerPersona.drill => 'Loud, blunt, relentless. Never cruel.',
        OverseerPersona.concierge => 'Immaculately polite. Faintly disappointed.',
        OverseerPersona.ghost => 'Barely there. Two or three words at a time.',
        OverseerPersona.auditor => 'Everything as a figure. Nothing as a feeling.',
      };

  /// Folded into the model's system prompt.
  String get voiceDirective => switch (this) {
        OverseerPersona.overseer =>
          'Clipped, dry, faintly ominous. Understatement over emphasis.',
        OverseerPersona.archivist =>
          'Speak as a records clerk. Reference dates, counts and entries. '
              'Never speculate; only state what is filed.',
        OverseerPersona.handler =>
          'Speak as an operations handler briefing a field asset. Terse, '
              'tactical, second person. Objectives, not feelings.',
        OverseerPersona.oracle =>
          'Speak obliquely, as something that has already seen the outcome. '
              'Patient, unhurried, never smug.',
        OverseerPersona.drill =>
          'Blunt and loud, all imperatives. Push hard but never insult, '
              'demean or question their worth.',
        OverseerPersona.concierge =>
          'Impeccably polite and formal, with a trace of disappointment held '
              'firmly in check. Never sarcastic.',
        OverseerPersona.ghost =>
          'Say almost nothing. Two to five words. Fragments, never sentences.',
        OverseerPersona.auditor =>
          'Speak only in figures and variances. Report the numbers and their '
              'direction. No adjectives.',
      };
}

/// The eye itself. The single most expressive part — it is what makes the
/// thing read as watching rather than decorating.
enum OverseerEyeKind {
  round,
  slit,
  compound,
  cross,
  ring,
  triad,
  void_,
  scanner,
}

extension OverseerEyeInfo on OverseerEyeKind {
  String get label => switch (this) {
        OverseerEyeKind.round => 'ROUND',
        OverseerEyeKind.slit => 'SLIT',
        OverseerEyeKind.compound => 'COMPOUND',
        OverseerEyeKind.cross => 'CROSS',
        OverseerEyeKind.ring => 'RING',
        OverseerEyeKind.triad => 'TRIAD',
        OverseerEyeKind.void_ => 'VOID',
        OverseerEyeKind.scanner => 'SCANNER',
      };
}

/// Worn over the body. Optional — [none] is a first-class choice, not an empty
/// slot, because the bare silhouette is the best-looking option and should
/// never feel like a placeholder.
enum OverseerAccessory {
  none,
  halo,
  crown,
  antenna,
  visor,
  wings,
  shackle,
  laurel,
  spike,
  orbit,
}

extension OverseerAccessoryInfo on OverseerAccessory {
  String get label => switch (this) {
        OverseerAccessory.none => 'BARE',
        OverseerAccessory.halo => 'HALO',
        OverseerAccessory.crown => 'CROWN',
        OverseerAccessory.antenna => 'ANTENNA',
        OverseerAccessory.visor => 'VISOR',
        OverseerAccessory.wings => 'WINGS',
        OverseerAccessory.shackle => 'SHACKLE',
        OverseerAccessory.laurel => 'LAUREL',
        OverseerAccessory.spike => 'SPIKE',
        OverseerAccessory.orbit => 'ORBIT',
      };
}

/// What the overseer currently looks and sounds like.
class Appearance {
  final OverseerShape shape;
  final OverseerFinish finish;
  final String paintId;
  final OverseerPersona persona;
  final OverseerEyeKind eye;
  final OverseerAccessory accessory;

  const Appearance({
    this.shape = OverseerShape.triangle,
    this.finish = OverseerFinish.glass,
    this.paintId = 'paint.origin',
    this.persona = OverseerPersona.overseer,
    this.eye = OverseerEyeKind.round,
    this.accessory = OverseerAccessory.none,
  });

  OverseerPaint get paint => OverseerPaint.byId(paintId);

  /// How many distinct looks the catalogue can produce.
  static int get lookCount =>
      OverseerShape.values.length *
      OverseerFinish.values.length *
      OverseerPaint.catalogue.length *
      OverseerEyeKind.values.length *
      OverseerAccessory.values.length;

  Appearance copyWith({
    OverseerShape? shape,
    OverseerFinish? finish,
    String? paintId,
    OverseerPersona? persona,
    OverseerEyeKind? eye,
    OverseerAccessory? accessory,
  }) =>
      Appearance(
        shape: shape ?? this.shape,
        finish: finish ?? this.finish,
        paintId: paintId ?? this.paintId,
        persona: persona ?? this.persona,
        eye: eye ?? this.eye,
        accessory: accessory ?? this.accessory,
      );

  Map<String, dynamic> toJson() => {
        'shape': shape.name,
        'finish': finish.name,
        'paint_id': paintId,
        'persona': persona.name,
        'eye': eye.name,
        'accessory': accessory.name,
      };

  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
        shape: OverseerShape.values.byName(json['shape'] as String? ?? 'triangle'),
        finish: OverseerFinish.values.byName(json['finish'] as String? ?? 'glass'),
        paintId: json['paint_id'] as String? ?? 'paint.origin',
        persona:
            OverseerPersona.values.byName(json['persona'] as String? ?? 'overseer'),
        eye: OverseerEyeKind.values.byName(json['eye'] as String? ?? 'round'),
        accessory: OverseerAccessory.values
            .byName(json['accessory'] as String? ?? 'none'),
      );
}
