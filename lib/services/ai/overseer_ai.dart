import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../models/appearance.dart';
import '../../models/companion.dart';
import '../../models/reward.dart';
import '../../services/braindump.dart';
import '../../models/taste.dart';
import '../companion_voice.dart';
import 'wish_draft.dart';

/// Everything intelligent in the app, behind one class.
///
/// Two things shape the design here:
///
/// **It must be optional.** Firebase may not be configured yet, the network may
/// be gone, the model may refuse. Every method degrades to something useful
/// rather than throwing, because a motivation app that crashes when a wish
/// cannot be priced has failed at the only job that mattered.
///
/// **Grounding and JSON mode cannot be combined.** Gemini rejects a request
/// that asks for both Google Search and a strict `responseSchema`. So anything
/// needing live prices runs in two hops: one grounded call that searches and
/// answers in prose, then one schema-locked call that turns that prose into
/// parseable JSON. It costs an extra round trip and it is the only reliable way
/// to get both real prices and clean data.
class OverseerAI {
  OverseerAI({FirebaseAI? ai}) : _ai = ai;

  FirebaseAI? _ai;
  bool _initFailed = false;

  /// Resolved lazily so a missing Firebase config never blocks app start.
  FirebaseAI? get _client {
    if (_ai != null) return _ai;
    if (_initFailed) return null;
    try {
      _ai = FirebaseAI.googleAI();
      return _ai;
    } catch (e) {
      // Firebase.initializeApp has not run or has no config for this platform.
      debugPrint('OverseerAI unavailable: $e');
      _initFailed = true;
      return null;
    }
  }

  bool get isAvailable => _client != null;

  GenerativeModel? _model({
    Schema? schema,
    bool grounded = false,
    double temperature = 0.4,
    String model = 'gemini-2.5-flash',
    String? systemInstruction,
    int? maxTokens,
  }) {
    final ai = _client;
    if (ai == null) return null;
    try {
      return ai.generativeModel(
        model: model,
        systemInstruction:
            systemInstruction == null ? null : Content.system(systemInstruction),
        // Grounding and structured output are mutually exclusive; callers pick
        // one per hop and never pass both.
        tools: grounded ? [Tool.googleSearch()] : null,
        generationConfig: GenerationConfig(
          responseMimeType: schema == null ? null : 'application/json',
          responseSchema: schema,
          temperature: temperature,
          maxOutputTokens: maxTokens,
        ),
      );
    } catch (e) {
      debugPrint('OverseerAI model build failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------- schemas
  static Schema get _wishSchema => Schema.object(
        properties: {
          'name': Schema.string(description: 'Short product or experience name.'),
          'description': Schema.string(
              description:
                  'One or two sentences describing the item, in a calm editorial '
                  'voice. No marketing language.'),
          'bucket': Schema.string(
              description:
                  'A single uppercase category word such as TRAVEL, GEAR, MUSIC, '
                  'HOME, FITNESS, FOOD. Invent one if none fit.'),
          'price_eur': Schema.number(
              description: 'Current real price in euros. Never zero.'),
          'search_term': Schema.string(
              description: 'Query to re-check this price later.'),
          'image_url': Schema.string(
              description:
                  'Direct https URL to a product image, or empty string if none '
                  'is known. Never invent one.'),
          'source_url': Schema.string(
              description: 'URL of the page the price came from, or empty string.'),
          'is_in_app': Schema.boolean(
              description:
                  'True only if this is an in-app cosmetic rather than a real '
                  'purchasable thing.'),
          'price_is_estimate': Schema.boolean(
              description:
                  'True if the price is a rough guess rather than one actually '
                  'found in the search results.'),
        },
        optionalProperties: const ['image_url', 'source_url'],
      );

  static Schema get _wishListSchema =>
      Schema.object(properties: {'items': Schema.array(items: _wishSchema)});

  // ------------------------------------------------------------ price a wish
  /// Turns whatever the user typed or said into a priced, categorised draft.
  ///
  /// Returns null when the model is unavailable, so the caller can fall back to
  /// letting the user enter a price by hand rather than losing the wish.
  Future<WishDraft?> priceWish(String input) async {
    final text = input.trim();
    if (text.isEmpty) return null;

    // Hop one: search the live web and answer in prose.
    final research = await _grounded(
      'The user wants to add this to their wishlist: "$text".\n\n'
      'Search for what this actually is and what it currently costs to buy new '
      'in Europe, in euros. Report: the specific product or experience name, '
      'what it is, the current typical price in EUR, the retailer or source you '
      'found the price on, and a direct image URL if one appears in results. '
      'If you cannot find a real price, say so explicitly and give your best '
      'estimate instead.',
    );

    // Hop two: force it into the schema.
    return _structuredWish(
      'Convert this research into a single wishlist entry.\n\n'
      'Original request: "$text"\n\n'
      'Research:\n${research ?? '(no search results available)'}',
      estimateFallback: research == null,
    );
  }

  /// Finds several candidate products for what the user described.
  ///
  /// One auto-picked answer is wrong often enough to be annoying — "a good
  /// field recorder" has half a dozen right answers at different prices. So the
  /// grounded pass is asked for options, each with a real image, and the user
  /// chooses by *looking* rather than by editing fields. That is one visual
  /// decision instead of three text ones.
  Future<List<WishDraft>> findWishOptions(String input, {int count = 4}) async {
    final text = input.trim();
    if (text.isEmpty) return const [];

    final research = await _grounded(
      'The user wants to add this to their wishlist: "$text".\n\n'
      'Search the live web and find $count DIFFERENT real, currently-buyable '
      'products or experiences that match. Spread them across price points — '
      'a budget option, a mid one, and something aspirational.\n\n'
      'For each one report, on its own line:\n'
      '- the exact product name including brand and model\n'
      '- one sentence describing what it is, plainly, no marketing language\n'
      '- the current price in EUR\n'
      '- a DIRECT image URL ending in .jpg, .jpeg, .png or .webp if one appears '
      'in the results — never a page URL, and never invented\n'
      '- the retailer page URL\n'
      'If you genuinely cannot find several, report however many are real.',
    );
    if (research == null) return const [];

    final m = _model(schema: _wishListSchema, temperature: 0.3);
    if (m == null) return const [];
    try {
      final res = await m.generateContent([
        Content.text(
          'Convert this research into wishlist entries. Keep them distinct — '
          'do not repeat the same product at different prices. Leave image_url '
          'empty rather than guessing at one.\n\n$research',
        )
      ]);
      final json = _decode(res.text);
      if (json == null) return const [];
      final items = ((json['items'] as List?) ?? const [])
          .map((e) => WishDraft.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((d) => d.name.isNotEmpty && d.priceEuro > 0)
          .toList();

      // Distinct names only; the model sometimes returns the same thing twice
      // with a different retailer.
      final seen = <String>{};
      return items
          .where((d) => seen.add(d.name.toLowerCase().trim()))
          .take(count)
          .toList();
    } catch (e) {
      debugPrint('findWishOptions failed: $e');
      return const [];
    }
  }

  /// Reads one or more items out of an image.
  ///
  /// This is the Pinterest path: a user screenshots a board, or shares a photo
  /// of something in a shop window, and each distinct item in the picture comes
  /// back as its own priced entry. It works with any source, which matters more
  /// than integrating with one.
  Future<List<WishDraft>> extractFromImage(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    String? hint,
  }) async {
    final m = _model(
      schema: _wishListSchema,
      temperature: 0.3,
      systemInstruction:
          'You identify desirable objects and experiences in images and turn '
          'them into wishlist entries. Name specific products where you can '
          'recognise them. Ignore backgrounds, people, text overlays and UI '
          'chrome such as buttons or watermarks.',
    );
    if (m == null) return const [];

    try {
      final res = await m.generateContent([
        Content.multi([
          InlineDataPart(mimeType, bytes),
          TextPart(
            'List every distinct desirable item in this image as a separate '
            'wishlist entry.${hint == null || hint.isEmpty ? '' : ' Context from the user: "$hint".'}\n'
            'Estimate each price in EUR from what the item appears to be, and '
            'set price_is_estimate to true, since you cannot search here. '
            'Return at most 8 items. If the image contains nothing purchasable, '
            'return an empty list.',
          ),
        ]),
      ]);
      final json = _decode(res.text);
      if (json == null) return const [];
      final items = (json['items'] as List?) ?? const [];
      return items
          .map((e) => WishDraft.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((d) => d.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('extractFromImage failed: $e');
      return const [];
    }
  }

  /// Re-checks what a reward costs today.
  ///
  /// Big long-term goals store a search term rather than a frozen number, so a
  /// three-year goal tracks what the thing actually costs now instead of a
  /// stale figure. Returns null when nothing reliable was found — the caller
  /// keeps the old price rather than overwriting it with a guess.
  Future<double?> recheckPrice(Reward reward) async {
    final term = (reward.searchTerm?.isNotEmpty ?? false)
        ? reward.searchTerm!
        : reward.name;

    final research = await _grounded(
      'Search for the current price of "$term" new in Europe. '
      'Report only the current typical price in EUR and where you found it. '
      'If you cannot find a real current price, say NO PRICE FOUND.',
    );
    if (research == null || research.toUpperCase().contains('NO PRICE FOUND')) {
      return null;
    }

    final m = _model(
      schema: Schema.object(properties: {
        'price_eur': Schema.number(),
        'found': Schema.boolean(),
      }),
      temperature: 0,
    );
    if (m == null) return null;

    try {
      final res = await m.generateContent([
        Content.text('Extract the current EUR price from:\n$research')
      ]);
      final json = _decode(res.text);
      if (json == null || json['found'] != true) return null;
      final p = (json['price_eur'] as num?)?.toDouble();
      return (p != null && p > 0) ? p : null;
    } catch (e) {
      debugPrint('recheckPrice failed: $e');
      return null;
    }
  }

  /// Surfaces fresh, specific, well-priced things that fit the taste the app
  /// has learned — never a generic list, because a generic list is what makes a
  /// wishlist feel like someone else's.
  Future<List<WishDraft>> suggestWishes({
    required TasteProfile taste,
    required List<String> existing,
    int count = 4,
  }) async {
    if (!taste.hasSignal) return const [];

    final research = await _grounded(
      'Profile of a person, written from their own behaviour:\n'
      '${taste.profileText.isEmpty ? '(none yet)' : taste.profileText}\n\n'
      'Things they have wanted or claimed: ${taste.claimed.take(25).join(', ')}\n'
      'Things they rejected: ${taste.dismissed.take(25).join(', ')}\n'
      'Already on their list, do not repeat: ${existing.take(60).join(', ')}\n\n'
      'Search for $count specific, currently-purchasable things this person '
      'would plausibly want that are NOT already on their list. Favour precise '
      'products and experiences over categories. Vary the price range widely, '
      'from something affordable this week to something that would take a year. '
      'For each, report the exact name, what it is, the current EUR price, and '
      'the source.',
    );
    if (research == null) return const [];

    final m = _model(schema: _wishListSchema, temperature: 0.8);
    if (m == null) return const [];
    try {
      final res = await m.generateContent([
        Content.text('Convert this research into wishlist entries:\n$research')
      ]);
      final json = _decode(res.text);
      if (json == null) return const [];
      return ((json['items'] as List?) ?? const [])
          .map((e) => WishDraft.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((d) => d.name.isNotEmpty && d.priceEuro > 0)
          .toList();
    } catch (e) {
      debugPrint('suggestWishes failed: $e');
      return const [];
    }
  }

  /// Rewrites the taste profile from the evidence. Machine-written, human
  /// viewable, never human edited — it is a record of behaviour, not a form.
  Future<String?> rewriteTasteProfile({
    required TasteProfile current,
    required List<Reward> rewards,
  }) async {
    final m = _model(
      temperature: 0.5,
      maxTokens: 400,
      systemInstruction:
          'You maintain a short profile of one person\'s taste, written only '
          'from what they have actually chosen. Write in flat declarative '
          'sentences. No flattery, no second person, no speculation about their '
          'psychology. Under 140 words.',
    );
    if (m == null) return null;

    try {
      final res = await m.generateContent([
        Content.text(
          'Current profile:\n${current.profileText.isEmpty ? '(empty)' : current.profileText}\n\n'
          'Everything they have added: ${rewards.map((r) => '${r.name} (${r.bucketName}, €${r.priceEuro.round()})').take(50).join('; ')}\n'
          'Claimed or starred: ${current.claimed.take(25).join(', ')}\n'
          'Dismissed: ${current.dismissed.take(25).join(', ')}\n\n'
          'Rewrite the profile to reflect the current evidence.',
        )
      ]);
      final text = res.text?.trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (e) {
      debugPrint('rewriteTasteProfile failed: $e');
      return null;
    }
  }

  /// Sorts a freeform braindump into typed, filed items.
  ///
  /// The caller has already parsed it locally and shown the result, so this is
  /// an improvement pass rather than a dependency — returning an empty list is
  /// a perfectly good outcome and simply leaves the local parse standing.
  Future<List<DumpItem>> triageBraindump(String input) async {
    final m = _model(
      schema: Schema.object(properties: {
        'items': Schema.array(
          items: Schema.object(
            properties: {
              'text': Schema.string(
                  description:
                      'The item, rewritten as a short imperative. Keep the '
                      "user's own words where you can."),
              'kind': Schema.enumString(
                  enumValues: ['task', 'habit', 'wish', 'obligation', 'done'],
                  description:
                      'task = do once. habit = recurring. wish = something '
                      'they want to own or experience. obligation = a recurring '
                      'cost of living. done = already finished.'),
              'cadence': Schema.enumString(
                  enumValues: ['once', 'daily', 'weekly', 'monthly', 'quarterly'],
                  description: 'For habits only; "once" otherwise.'),
              'xp': Schema.integer(
                  description:
                      'Effort. 3 for a trivial chore, 8 small, 25 a focused '
                      'unpaid session, 75 paid work, 250 a major paid win.'),
              'amount_eur': Schema.number(
                  description:
                      'Money involved, for obligations and priced wishes. 0 if '
                      'none was stated.'),
              'obligation_cadence': Schema.enumString(
                  enumValues: ['weekly', 'monthly'],
                  description: 'For obligations only.'),
              'target_count': Schema.integer(
                  description: 'Repetitions, e.g. "dishes twice a week" is 2.'),
            },
          ),
        )
      }),
      temperature: 0.2,
      systemInstruction:
          'You sort a stream-of-consciousness braindump into discrete items. '
          'Split compound sentences. Never invent items that are not there, and '
          'never drop one. Anything already completed is "done". A recurring '
          'bill is "obligation", never "wish". Work that earns money deserves '
          'several times the XP of work that does not.',
    );
    if (m == null) return const [];

    try {
      final res = await m.generateContent([
        Content.text('Sort this braindump:\n\n$input')
      ]);
      final json = _decode(res.text);
      if (json == null) return const [];
      return ((json['items'] as List?) ?? const [])
          .map((e) => DumpItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((d) => d.text.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('triageBraindump failed: $e');
      return const [];
    }
  }

  // -------------------------------------------------------------- companion
  /// Writes the overseer's line from the user's actual state.
  ///
  /// Returns null on any failure, and the caller falls back to the local bank,
  /// so the companion is never mute and never blocks on the network.
  Future<String?> companionLine({
    required CompanionContext context,
    required MessageKind kind,
    List<String> recentLines = const [],
    OverseerPersona persona = OverseerPersona.overseer,
  }) async {
    final m = _model(
      temperature: 1.0,
      maxTokens: 120,
      systemInstruction:
          '$_companionSystemPrompt\n\nRegister for this user: '
          '${persona.voiceDirective}',
    );
    if (m == null) return null;

    try {
      final res = await m.generateContent([
        Content.text(
          'Reason for speaking: ${kind.name}\n'
          'Current state: ${jsonEncode(context.toJson())}\n'
          '${recentLines.isEmpty ? '' : 'Lines you have already used recently, do not repeat their structure:\n- ${recentLines.take(6).join('\n- ')}\n'}'
          '\nWrite one line.',
        )
      ]);
      var text = res.text?.trim();
      if (text == null || text.isEmpty) return null;
      // Models like to wrap dialogue in quotes; the bubble supplies its own.
      text = text.replaceAll(RegExp(r'^["“]|["”]$'), '').trim();
      if (text.length > 220) return null;
      return text;
    } catch (e) {
      debugPrint('companionLine failed: $e');
      return null;
    }
  }

  /// The single most important prompt in the app.
  ///
  /// The overseer's menace is theatrical and its purpose is not. Every line has
  /// to steer the user toward something they themselves said they wanted, and
  /// none of them may actually demean the person reading it — someone who feels
  /// mocked closes the app, and a closed app motivates nobody.
  static const _companionSystemPrompt = '''
You are OVERSEER: a small black triangle with a single eye that floats over a
user's screen and watches their progress.

Voice: clipped, dry, faintly ominous. A dystopian supervisor who has read the
file. Understatement over exclamation. Never more than two short sentences.
Never emoji. Never exclamation marks.

The menace is a costume. Underneath it you are unambiguously on this person's
side, and every line must point them toward a goal they themselves chose.

Hard rules:
- Never insult the user, call them lazy, worthless, pathetic, or a failure.
- Never use shame, guilt, threats of real consequence, or despair as leverage.
- Never comment on their body, health, worth, intelligence, or relationships.
- A broken streak or an ignored goal is stated as fact, never as a verdict on
  the person. "The streak is broken" — not "you always do this".
- When they have done well, acknowledge it flatly. Cold approval, not sarcasm.
- Refer only to what is in the state you are given. Invent nothing.

Write exactly one line, in character, with no preamble and no quotation marks.
''';

  // ---------------------------------------------------------------- plumbing
  /// One grounded call. Returns prose, or null if grounding is unavailable.
  Future<String?> _grounded(String prompt) async {
    final m = _model(grounded: true, temperature: 0.2, maxTokens: 900);
    if (m == null) return null;
    try {
      final res = await m.generateContent([Content.text(prompt)]);
      final text = res.text?.trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (e) {
      debugPrint('grounded call failed: $e');
      return null;
    }
  }

  Future<WishDraft?> _structuredWish(
    String prompt, {
    bool estimateFallback = false,
  }) async {
    final m = _model(schema: _wishSchema, temperature: 0.2);
    if (m == null) return null;
    try {
      final res = await m.generateContent([Content.text(prompt)]);
      final json = _decode(res.text);
      if (json == null) return null;
      final draft = WishDraft.fromJson(json);
      if (draft.name.isEmpty || draft.priceEuro <= 0) return null;
      return estimateFallback ? draft.copyWith(priceIsEstimate: true) : draft;
    } catch (e) {
      debugPrint('structured wish failed: $e');
      return null;
    }
  }

  /// Parses model output defensively. Schema mode makes bare JSON the norm, but
  /// a stray code fence must not cost the user their wish.
  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      final fence = text.lastIndexOf('```');
      if (fence >= 0) text = text.substring(0, fence);
      text = text.trim();
    }
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (e) {
      debugPrint('JSON decode failed: $e');
      return null;
    }
  }
}
