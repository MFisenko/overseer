import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../core/economy.dart';
import '../../models/reward.dart';
import '../../services/ai/overseer_ai.dart';
import '../../services/ai/wish_draft.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

Future<void> showAddWishSheet(BuildContext context) =>
    showOverseerSheet(context, child: const AddWishSheet());

/// Adding a wish has to be one frictionless action, because the whole manifest
/// depends on things being captured the moment they occur to someone.
///
/// Three ways in — typed, spoken, or a picture — and all three land in the same
/// place: a priced, categorised draft the user confirms. When the model is not
/// available the sheet degrades to a plain name-and-price form rather than
/// refusing the wish, because losing the thought is worse than losing the
/// automation.
class AddWishSheet extends StatefulWidget {
  const AddWishSheet({super.key});

  @override
  State<AddWishSheet> createState() => _AddWishSheetState();
}

enum _Stage { input, working, review }

class _AddWishSheetState extends State<AddWishSheet> {
  static const _uuid = Uuid();

  final _text = TextEditingController();
  final _price = TextEditingController();

  /// An optional picture for the wish.
  ///
  /// Deliberately a *link*, never an upload. Nothing is stored in Firebase
  /// Storage, so web and mobile behave identically, there is no storage bill,
  /// and a dead link degrades to the generated plate rather than to a gap.
  final _imageUrl = TextEditingController();
  final _speech = SpeechToText();
  final _ai = OverseerAI();

  _Stage _stage = _Stage.input;
  bool _listening = false;
  String? _error;

  /// Drafts awaiting confirmation. An image can yield several at once.
  List<WishDraft> _drafts = [];
  final _rejected = <int>{};

  @override
  void dispose() {
    _text.dispose();
    _price.dispose();
    _imageUrl.dispose();
    // Stopping a recognizer that was never initialised throws on web — the
    // plugin dereferences a null handle. Only stop what was actually started.
    if (_listening) {
      unawaited(_speech.stop());
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ voice
  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _listening = false;
            _error = 'Dictation unavailable on this device.';
          });
        }
      },
    );
    if (!ok) {
      setState(() => _error = 'Dictation unavailable on this device.');
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

  // ------------------------------------------------------------------ image
  Future<void> _fromImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() {
        _stage = _Stage.working;
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
          _stage = _Stage.input;
          _error = _ai.isAvailable
              ? 'Nothing purchasable found in that image.'
              : 'Image reading needs the model configured. Add it by hand for now.';
        });
        return;
      }
      setState(() {
        _drafts = drafts;
        _stage = _Stage.review;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.input;
          _error = 'Could not read that image.';
        });
      }
    }
  }

  // ------------------------------------------------------------------ typed
  Future<void> _submitText() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;

    if (!_ai.isAvailable) {
      // No model yet: take it by hand rather than dropping the thought.
      await _saveManual(text);
      return;
    }

    setState(() {
      _stage = _Stage.working;
      _error = null;
    });
    final draft = await _ai.priceWish(text);
    if (!mounted) return;
    if (draft == null) {
      setState(() {
        _stage = _Stage.input;
        _error = 'Could not price that. Enter it by hand below.';
      });
      return;
    }
    setState(() {
      _drafts = [draft];
      _stage = _Stage.review;
    });
  }

  Future<void> _saveManual(String name) async {
    final euros = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (euros == null || euros <= 0) {
      setState(() => _error = 'Give it a price in euros so it can be earned.');
      return;
    }
    await _commit([
      WishDraft(
        name: name,
        priceEuro: euros,
        bucket: 'UNSORTED',
        searchTerm: name,
        imageUrl: _cleanImageUrl(),
        priceIsEstimate: true,
      )
    ]);
  }

  /// Only an absolute http(s) URL is worth keeping; anything else would just
  /// render as a broken image.
  String? _cleanImageUrl() {
    final raw = _imageUrl.text.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return raw;
  }

  Future<void> _commit(List<WishDraft> drafts) async {
    final game = context.read<GameState>();
    // A pasted link wins over whatever search turned up — the user looked at
    // the picture they chose.
    final pasted = _cleanImageUrl();
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
        imageUrl: pasted ?? d.imageUrl,
        sourceUrl: d.sourceUrl,
        kind: d.kind,
        origin: RewardOrigin.manual,
        createdAt: DateTime.now(),
        priceCheckedAt: d.priceIsEstimate ? null : DateTime.now(),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
        _Stage.input => _buildInput(context),
        _Stage.working => _buildWorking(context),
        _Stage.review => _buildReview(context),
      };

  Widget _buildInput(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Add a wish', style: Kind.display(context, size: 26)),
        const SizedBox(height: Gap.sm),
        Text(
          _ai.isAvailable
              ? 'Say it, type it, or hand over a picture. It gets identified, '
                  'priced and filed.'
              : 'The model is not configured yet, so add the name and price by '
                  'hand. Everything else still works.',
          style: Kind.body(context, size: 13),
        ),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _text,
          autofocus: true,
          style: Kind.title(context, size: 16),
          cursorColor: tk.accent,
          decoration: InputDecoration(
            hintText: 'what do you want',
            suffixIcon: IconButton(
              onPressed: _toggleDictation,
              icon: Icon(
                _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _listening ? tk.alert : tk.inkDim,
                size: 20,
              ),
            ),
          ),
          onSubmitted: (_) => _submitText(),
        ),
        if (_listening) ...[
          const SizedBox(height: Gap.sm),
          Row(children: [
            Tag('LISTENING', color: tk.alert, filled: true),
            const SizedBox(width: Gap.sm),
            Text('Speak. Tap the mic to stop.',
                style: Kind.body(context, size: 12)),
          ]),
        ],
        if (!_ai.isAvailable) ...[
          const SizedBox(height: Gap.md),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Kind.figure(context, size: 15),
            cursorColor: tk.accent,
            decoration: const InputDecoration(
              hintText: 'price in euros',
              prefixText: '€ ',
            ),
          ),
        ],
        const SizedBox(height: Gap.md),
        TextField(
          controller: _imageUrl,
          keyboardType: TextInputType.url,
          style: Kind.body(context, size: 13, color: tk.ink),
          cursorColor: tk.accent,
          decoration: const InputDecoration(
            hintText: 'picture link (optional)',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A link, not an upload — paste the address of any image on the web. '
          'Leave it blank and the overseer finds one.',
          style: Kind.body(context, size: 11, color: tk.inkDim),
        ),
        if (_error != null) ...[
          const SizedBox(height: Gap.md),
          Text(_error!, style: Kind.body(context, size: 12.5, color: tk.alert)),
        ],
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: SoftButton(
                label: 'ADD',
                primary: true,
                expand: true,
                onTap: _submitText,
              ),
            ),
            const SizedBox(width: Gap.sm),
            SoftButton(
              label: 'FROM IMAGE',
              onTap: _fromImage,
              icon: Icon(Icons.image_outlined, size: 15, color: tk.ink),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorking(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: tk.accent),
              ),
              const SizedBox(width: Gap.md),
              Text('Identifying and pricing',
                  style: Kind.serif(context, size: 19)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text('Searching for what this actually costs today.',
              style: Kind.body(context, size: 13)),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final tk = context.tk;
    final keep = <WishDraft>[
      for (var i = 0; i < _drafts.length; i++)
        if (!_rejected.contains(i)) _drafts[i],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _drafts.length == 1 ? 'Confirm' : 'Found ${_drafts.length} items',
          style: Kind.display(context, size: 26),
        ),
        const SizedBox(height: Gap.lg),
        for (var i = 0; i < _drafts.length; i++)
          _DraftRow(
            draft: _drafts[i],
            rejected: _rejected.contains(i),
            onToggle: () => setState(() {
              _rejected.contains(i) ? _rejected.remove(i) : _rejected.add(i);
            }),
            onPriceChanged: (v) => setState(() => _drafts[i] = _drafts[i].copyWith(
                  priceEuro: v,
                  priceIsEstimate: false,
                )),
          ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: SoftButton(
                label: keep.isEmpty ? 'NOTHING SELECTED' : 'ADD ${keep.length}',
                primary: keep.isNotEmpty,
                expand: true,
                onTap: keep.isEmpty ? null : () => _commit(keep),
              ),
            ),
            const SizedBox(width: Gap.sm),
            SoftButton(
              label: 'BACK',
              onTap: () => setState(() {
                _stage = _Stage.input;
                _rejected.clear();
              }),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Prices convert at ${Economy.coinsPerEuro} credits to the euro. '
          'You can correct any of them now.',
          style: Kind.body(context, size: 11.5, color: tk.inkDim),
        ),
      ],
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.rejected,
    required this.onToggle,
    required this.onPriceChanged,
  });

  final WishDraft draft;
  final bool rejected;
  final VoidCallback onToggle;
  final ValueChanged<double> onPriceChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Opacity(
      opacity: rejected ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: Panel(
          elevated: false,
          color: tk.surfaceAlt,
          onTap: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(draft.name,
                        style: Kind.serif(context, size: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Icon(
                    rejected
                        ? Icons.circle_outlined
                        : Icons.check_circle_rounded,
                    size: 20,
                    color: rejected ? tk.inkDim : tk.cool,
                  ),
                ],
              ),
              if (draft.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(draft.description,
                    style: Kind.body(context, size: 12.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Tag(draft.bucket, color: tk.inkDim),
                  const SizedBox(width: Gap.sm),
                  Tag(draft.tier.label, color: tk.accent),
                  if (draft.priceIsEstimate) ...[
                    const SizedBox(width: Gap.sm),
                    Tag('ESTIMATE', color: tk.alert),
                  ],
                  const Spacer(),
                  CreditAmount(draft.coinCost, size: 13, weight: FontWeight.w600),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(euro(draft.priceEuro),
                      style: Kind.body(context, size: 11.5, color: tk.inkDim)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _editPrice(context),
                    behavior: HitTestBehavior.opaque,
                    child: Text('CORRECT PRICE',
                        style: Kind.label(context, size: 9, color: tk.accent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editPrice(BuildContext context) async {
    final controller =
        TextEditingController(text: draft.priceEuro.toStringAsFixed(2));
    final tk = context.tk;
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tk.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
        title: Text('Real price', style: Kind.serif(ctx, size: 19)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '€ '),
          style: Kind.figure(ctx, size: 16),
        ),
        actions: [
          SoftButton(label: 'CANCEL', dense: true, onTap: () => Navigator.pop(ctx)),
          SoftButton(
            label: 'SET',
            dense: true,
            primary: true,
            onTap: () => Navigator.pop(
                ctx, double.tryParse(controller.text.trim().replaceAll(',', '.'))),
          ),
        ],
      ),
    );
    if (value != null && value > 0) onPriceChanged(value);
  }
}
