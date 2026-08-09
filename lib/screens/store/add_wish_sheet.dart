import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../core/economy.dart';
import '../../core/emblem.dart';
import '../../models/reward.dart';
import '../../services/ai/overseer_ai.dart';
import '../../services/ai/wish_draft.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/primitives.dart';
import '../../widgets/reward_image.dart';
import '../../widgets/sheet.dart';

Future<void> showAddWishSheet(BuildContext context) =>
    showOverseerSheet(context, child: const AddWishSheet());

/// Say what you want. That is the whole interaction.
///
/// The earlier version made you confirm a draft, correct a price and pick a
/// category before anything was saved. That is three decisions standing between
/// a fleeting thought and a recorded one, and the thought is the fragile part —
/// so it files immediately and lets you correct afterwards, from the item's own
/// page, if you ever care to.
///
/// The only time it asks anything is when the model cannot reach the network
/// and genuinely does not know what the thing costs.
class AddWishSheet extends StatefulWidget {
  const AddWishSheet({super.key});

  @override
  State<AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends State<AddWishSheet> {
  static const _uuid = Uuid();

  final _text = TextEditingController();
  final _price = TextEditingController();
  final _speech = SpeechToText();
  final _ai = OverseerAI();

  bool _listening = false;
  bool _working = false;

  /// Set only when pricing failed and a figure is genuinely needed.
  bool _needsPrice = false;
  String? _error;

  /// Candidates to choose between. Picking a picture is one visual decision;
  /// editing a name, a price and a category is three text ones.
  List<WishDraft> _options = const [];

  /// What was just filed, so the sheet can confirm before closing itself.
  final _filed = <String>[];

  @override
  void dispose() {
    _text.dispose();
    _price.dispose();
    // Stopping a recognizer that was never initialised dereferences null on
    // web. Only stop what was actually started.
    if (_listening) unawaited(_speech.stop());
    super.dispose();
  }

  // ------------------------------------------------------------------ voice
  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _listening = false;
            _error = 'Dictation is not available here. Type it instead.';
          });
        }
      },
    );
    if (!ok) {
      setState(() => _error = 'Dictation is not available here. Type it instead.');
      return;
    }
    setState(() {
      _listening = true;
      _error = null;
    });
    await _speech.listen(
      onResult: (r) => setState(() => _text.text = r.recognizedWords),
      listenFor: const Duration(seconds: 30),
    );
  }

  // ------------------------------------------------------------------ submit
  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;

    // A price was asked for and given: file it and stop.
    if (_needsPrice) {
      final euros = double.tryParse(_price.text.trim().replaceAll(',', '.'));
      if (euros == null || euros <= 0) {
        setState(() => _error = 'A rough figure is fine — it can be corrected later.');
        return;
      }
      await _file([
        WishDraft(
          name: text,
          priceEuro: euros,
          searchTerm: text,
          priceIsEstimate: true,
        )
      ]);
      return;
    }

    if (!_ai.isAvailable) {
      setState(() {
        _needsPrice = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    // Ask for options first. A single auto-picked answer is wrong often enough
    // to be irritating — "a good field recorder" has several right answers.
    final options = await _ai.findWishOptions(text);
    if (!mounted) return;

    if (options.length > 1) {
      setState(() {
        _working = false;
        _options = options;
      });
      return;
    }
    if (options.length == 1) {
      await _file(options);
      return;
    }

    // Nothing found as options; fall back to a single priced draft.
    final draft = await _ai.priceWish(text);
    if (!mounted) return;
    if (draft == null) {
      // Could not price it. Ask for the one thing that cannot be guessed
      // rather than throwing the thought away.
      setState(() {
        _working = false;
        _needsPrice = true;
        _error = 'Could not find a price. Roughly what does it cost?';
      });
      return;
    }
    await _file([draft]);
  }

  // ------------------------------------------------------------------ image
  Future<void> _fromImage() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (picked == null) return;
      setState(() {
        _working = true;
        _error = null;
      });
      final bytes = await picked.readAsBytes();
      final drafts = await _ai.extractFromImage(
        bytes,
        mimeType: picked.mimeType ?? 'image/jpeg',
        hint: _text.text.trim(),
      );
      if (!mounted) return;
      if (drafts.isEmpty) {
        setState(() {
          _working = false;
          _error = _ai.isAvailable
              ? 'Nothing purchasable in that picture.'
              : 'Reading pictures needs a connection. Type it instead.';
        });
        return;
      }
      // Everything found goes in. Removing one afterwards is a single tap from
      // the store; re-finding a thing you skipped is not.
      await _file(drafts);
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = 'Could not read that picture.';
        });
      }
    }
  }

  Future<void> _file(List<WishDraft> drafts) async {
    final game = context.read<GameState>();
    for (final d in drafts) {
      final bucket = await game.ensureBucket(d.bucket);
      await game.addReward(Reward(
        id: _uuid.v4(),
        name: d.name,
        description: d.description.isEmpty ? null : d.description,
        bucketId: bucket.id,
        bucketName: bucket.name,
        tier: d.tier,
        priceEuro: d.priceEuro,
        coinCost: d.coinCost,
        searchTerm: d.searchTerm.isEmpty ? d.name : d.searchTerm,
        imageUrl: d.imageUrl,
        sourceUrl: d.sourceUrl,
        kind: d.kind,
        origin: RewardOrigin.manual,
        createdAt: DateTime.now(),
        priceCheckedAt: d.priceIsEstimate ? null : DateTime.now(),
      ));
    }
    if (!mounted) return;

    setState(() {
      _working = false;
      _needsPrice = false;
      _error = null;
      _filed.addAll(drafts.map((d) => d.name));
      _text.clear();
      _price.clear();
    });

    // Close on its own, so adding several in a row is: type, enter, type,
    // enter. Long enough to read what it did.
    Timer(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;

    if (_filed.isNotEmpty) return _Filed(names: _filed);
    if (_options.isNotEmpty) {
      return _OptionPicker(
        options: _options,
        onPick: (d) => _file([d]),
        onBack: () => setState(() => _options = const []),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('What do you want?', style: Kind.display(context, size: 26)),
        const SizedBox(height: Gap.sm),
        Text(
          _needsPrice
              ? 'Give it a rough price and it goes straight on the manifest.'
              : 'Say it plainly. It gets identified, priced and filed — you do '
                  'not have to sort anything.',
          style: Kind.body(context, size: 13),
        ),

        const SizedBox(height: Gap.lg),
        TextField(
          controller: _text,
          autofocus: true,
          enabled: !_working,
          style: Kind.title(context, size: 17),
          cursorColor: tk.accent,
          decoration: InputDecoration(
            hintText: 'a good field recorder',
            suffixIcon: IconButton(
              tooltip: 'Dictate',
              onPressed: _working ? null : _toggleDictation,
              icon: Icon(
                _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _listening ? tk.alert : tk.inkDim,
                size: 20,
              ),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),

        if (_needsPrice) ...[
          const SizedBox(height: Gap.sm),
          TextField(
            controller: _price,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Kind.figure(context, size: 17),
            cursorColor: tk.accent,
            decoration: const InputDecoration(hintText: '0', prefixText: '€ '),
            onSubmitted: (_) => _submit(),
          ),
        ],

        if (_listening) ...[
          const SizedBox(height: Gap.sm),
          Row(children: [
            Tag('LISTENING', color: tk.alert, filled: true),
            const SizedBox(width: Gap.sm),
            Text('Tap the mic to stop.', style: Kind.body(context, size: 12)),
          ]),
        ],

        if (_error != null) ...[
          const SizedBox(height: Gap.md),
          Text(_error!, style: Kind.body(context, size: 12.5, color: tk.alert)),
        ],

        const SizedBox(height: Gap.lg),
        if (_working)
          Row(children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: tk.accent),
            ),
            const SizedBox(width: Gap.md),
            Text('Looking for it', style: Kind.body(context, size: 13)),
          ])
        else
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: 'ADD IT',
                  primary: true,
                  expand: true,
                  onTap: _submit,
                ),
              ),
              if (!_needsPrice) ...[
                const SizedBox(width: Gap.sm),
                SoftButton(
                  label: 'PICTURE',
                  onTap: _fromImage,
                  icon: Icon(Icons.image_outlined, size: 15, color: tk.ink),
                ),
              ],
            ],
          ),

        const SizedBox(height: Gap.sm),
        Text(
          'Prices convert at ${Economy.coinsPerEuro} credits to the euro. '
          'Anything wrong can be fixed from the item later.',
          style: Kind.body(context, size: 11.5, color: tk.inkDim),
        ),
      ],
    );
  }
}

/// The confirmation. Names what landed, then gets out of the way.
class _Filed extends StatelessWidget {
  const _Filed({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.check_rounded, size: 20, color: tk.cool),
            const SizedBox(width: Gap.sm),
            Text(
              names.length == 1 ? 'On the manifest' : '${names.length} on the manifest',
              style: Kind.display(context, size: 24),
            ),
          ]),
          const SizedBox(height: Gap.md),
          for (final n in names.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('— $n', style: Kind.body(context, size: 13.5)),
            ),
          if (names.length > 6)
            Text('— and ${names.length - 6} more',
                style: Kind.body(context, size: 13.5, color: tk.inkDim)),
        ],
      ),
    );
  }
}


/// Candidates, shown as pictures with a price. Tap the one you meant.
///
/// This is the only place the flow asks for a decision, and it is deliberately
/// a visual one — recognising the right object is instant, whereas reading four
/// product names and comparing them is work.
class _OptionPicker extends StatelessWidget {
  const _OptionPicker({
    required this.options,
    required this.onPick,
    required this.onBack,
  });

  final List<WishDraft> options;
  final ValueChanged<WishDraft> onPick;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Which one?', style: Kind.display(context, size: 26)),
        const SizedBox(height: Gap.sm),
        Text('Tap it and it goes on the manifest.',
            style: Kind.body(context, size: 13)),
        const SizedBox(height: Gap.lg),
        for (final d in options)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: GestureDetector(
              onTap: () => onPick(d),
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: Radii.brLg,
                  border: Border.all(color: tk.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: RewardImage(
                        imageUrl: d.imageUrl,
                        emblem: Emblem.mark,
                        seed: d.name,
                        radius: BorderRadius.zero,
                        wash: false,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(d.name,
                                style: Kind.serif(context, size: 15),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            if (d.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(d.description,
                                  style: Kind.body(context, size: 11.5),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CreditAmount(d.coinCost,
                                    size: 12, weight: FontWeight.w700),
                                const SizedBox(width: Gap.sm),
                                Text(euro(d.priceEuro),
                                    style: Kind.body(context,
                                        size: 11, color: tk.inkDim)),
                                if (d.priceIsEstimate) ...[
                                  const SizedBox(width: Gap.sm),
                                  Tag('EST', color: tk.inkDim),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: Gap.sm),
        SoftButton(
            label: 'NONE OF THESE', dense: true, expand: true, onTap: onBack),
      ],
    );
  }
}
