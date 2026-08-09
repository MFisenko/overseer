import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/economy.dart';
import '../../models/appearance.dart';
import '../../models/companion.dart';
import '../../models/quest.dart';
import '../../models/upkeep.dart';
import '../../models/reward.dart';
import '../../services/ai/overseer_ai.dart';
import '../../services/braindump.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/companion/overseer_eye.dart';
import '../../widgets/primitives.dart';
import 'appearance_sheet.dart';

/// The overseer, given its own page.
///
/// The point of this screen is that it is the one place you *talk* to it rather
/// than being talked at. Everything you might otherwise have to file in four
/// different places — a task, a habit, something you want, a bill, something
/// you already did — can be typed here in one go, and it sorts them.
class OverseerScreen extends StatefulWidget {
  const OverseerScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        builder: (_) => const OverseerScreen(),
      );

  @override
  State<OverseerScreen> createState() => _OverseerScreenState();
}

class _OverseerScreenState extends State<OverseerScreen> {
  static const _uuid = Uuid();

  final _input = TextEditingController();
  final _parser = const BraindumpParser();
  final _ai = OverseerAI();

  List<DumpItem>? _pending;
  final _dropped = <int>{};
  bool _working = false;

  /// Filing runs a grounded price lookup per wish, so a dump with three wishes
  /// takes real seconds. Showing which one is in flight is the difference
  /// between "working" and "frozen".
  bool _filing = false;
  String? _filingWhat;

  /// What the last dump produced, kept so the screen confirms rather than
  /// silently emptying itself.
  String? _receipt;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _triage() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    // Parse locally first so something appears immediately, then let the model
    // improve on it. A slow network must never mean a lost thought.
    final local = _parser.parse(text);
    setState(() {
      _pending = local;
      _dropped.clear();
      _receipt = null;
      _working = _ai.isAvailable;
    });

    if (!_ai.isAvailable) return;
    final refined = await _ai.triageBraindump(text);
    if (!mounted) return;
    setState(() {
      if (refined.isNotEmpty) _pending = refined;
      _working = false;
    });
  }

  Future<void> _commit() async {
    final items = <DumpItem>[
      for (var i = 0; i < _pending!.length; i++)
        if (!_dropped.contains(i)) _pending![i],
    ];
    if (items.isEmpty) return;
    final game = context.read<GameState>();

    setState(() => _filing = true);
    final counts = <DumpKind, int>{};

    for (final item in items) {
      if (mounted) setState(() => _filingWhat = item.text);
      counts[item.kind] = (counts[item.kind] ?? 0) + 1;
      switch (item.kind) {
        case DumpKind.task:
          await game.addQuest(
            title: item.text,
            xpValue: item.xp,
            cadence: Cadence.once,
            targetCount: item.targetCount,
          );
        case DumpKind.habit:
          await game.addQuest(
            title: item.text,
            xpValue: item.xp,
            cadence: item.cadence,
            targetCount: item.targetCount,
          );
        case DumpKind.done:
          // Already finished: issue it and immediately bank it, so the bar
          // moves for work that happened before the app was opened.
          final q = await game.addQuest(
            title: item.text,
            xpValue: item.xp,
            cadence: Cadence.once,
          );
          await game.completeQuest(q.id);
          await game.collectQuest(q.id);
        case DumpKind.obligation:
          await game.addObligation(
            name: item.text,
            amountEuro: item.amountEuro ?? 0,
            cadence: item.obligationCadence,
          );
        case DumpKind.wish:
          await _fileWish(game, item);
      }
    }

    // Emptying your head is itself worth acknowledging — small, and not
    // multiplied by the streak, so it can never beat doing the work.
    await game.rewardBraindump(items.length);

    if (!mounted) return;
    setState(() {
      _pending = null;
      _dropped.clear();
      _input.clear();
      _filing = false;
      _filingWhat = null;
      _receipt = _describe(counts);
    });
  }

  /// "2 directives, 1 habit, 1 cost" — names what happened rather than saying
  /// "done", so a misfiled line is noticed immediately.
  static String _describe(Map<DumpKind, int> counts) {
    String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final parts = <String>[];
    for (final e in counts.entries) {
      parts.add(switch (e.key) {
        DumpKind.task => plural(e.value, 'directive', 'directives'),
        DumpKind.habit => plural(e.value, 'habit', 'habits'),
        DumpKind.wish => plural(e.value, 'wish', 'wishes'),
        DumpKind.obligation => plural(e.value, 'cost', 'costs'),
        DumpKind.done => '${e.value} already done',
      });
    }
    return parts.join(' · ');
  }

  /// Wishes go through pricing where possible; an unpriced one still lands on
  /// the manifest so it can be costed later rather than being dropped.
  Future<void> _fileWish(GameState game, DumpItem item) async {
    final draft = _ai.isAvailable ? await _ai.priceWish(item.text) : null;
    final price = draft?.priceEuro ?? item.amountEuro ?? 0;
    final bucket = await game.ensureBucket(draft?.bucket ?? 'UNSORTED');

    await game.addReward(Reward(
      id: _uuid.v4(),
      name: draft?.name ?? item.text,
      description: draft?.description,
      bucketId: bucket.id,
      bucketName: bucket.name,
      tier: MoneyTierInfo.fromEuro(price),
      priceEuro: price,
      coinCost: Economy.euroToCoins(price),
      searchTerm: draft?.searchTerm ?? item.text,
      imageUrl: draft?.imageUrl,
      sourceUrl: draft?.sourceUrl,
      createdAt: DateTime.now(),
      priceCheckedAt: draft != null && !draft.priceIsEstimate ? DateTime.now() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final companion = game.companion;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => showAppearanceSheet(context),
            child: Lbl('CUSTOMISE', color: tk.accent),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.huge),
        children: [
          // ------------------------------------------------------ the thing
          Center(
            child: Column(
              children: [
                OverseerEye(
                  mood: companion.mood,
                  appearance: companion.appearance,
                  size: 168,
                  streakDays: game.currentStreak,
                  // On a flat page there is nothing behind it worth blurring,
                  // and the blur pass is not free.
                  flat: true,
                ),
                const SizedBox(height: Gap.lg),
                Text(companion.appearance.persona.label,
                    style: Kind.display(context, size: 26)),
                const SizedBox(height: 6),
                Text(
                  '${companion.appearance.shape.label} · '
                  '${companion.appearance.finish.label} · '
                  '${companion.appearance.paint.name}',
                  style: Kind.label(context, size: 9.5),
                ),
                const SizedBox(height: Gap.md),
                Tag(companion.mood.label,
                    color: companion.mood == CompanionMood.alert
                        ? tk.alert
                        : tk.cool,
                    filled: true),
              ],
            ),
          ),

          if (companion.latest != null) ...[
            const SizedBox(height: Gap.xl),
            Panel(
              color: tk.surfaceAlt,
              elevated: false,
              child: Text(companion.latest!.text,
                  style: Kind.machine(context, size: 13)),
            ),
          ],

          // -------------------------------------------------- the braindump
          const SizedBox(height: Gap.xl),
          const SectionHead('TELL IT EVERYTHING'),
          const SizedBox(height: Gap.md),
          Text(
            'Tasks, habits, things you want, bills, things you already did. '
            'One per line, however you think of them. It sorts them.',
            style: Kind.body(context, size: 13),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _input,
            maxLines: 7,
            minLines: 4,
            style: Kind.body(context, size: 14, color: tk.ink),
            cursorColor: tk.accent,
            decoration: const InputDecoration(
              hintText: 'rent is 850 a month\n'
                  'dishes every day\n'
                  'want a field recorder\n'
                  'finished the invoices',
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: 'HAND IT OVER',
                  primary: true,
                  expand: true,
                  onTap: _triage,
                ),
              ),
              if (_pending != null) ...[
                const SizedBox(width: Gap.sm),
                SoftButton(
                  label: 'CLEAR',
                  onTap: () => setState(() {
                    _pending = null;
                    _dropped.clear();
                  }),
                ),
              ],
            ],
          ),

          if (_receipt != null) ...[
            const SizedBox(height: Gap.md),
            Panel(
              color: tk.coolSoft,
              elevated: false,
              borderColor: tk.cool.withValues(alpha: 0.4),
              child: Row(children: [
                Icon(Icons.check_rounded, size: 18, color: tk.cool),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text('Filed — $_receipt',
                      style: Kind.body(context, size: 13, color: tk.ink)),
                ),
              ]),
            ),
          ],

          if (_filing) ...[
            const SizedBox(height: Gap.md),
            Row(children: [
              SizedBox(
                width: 12,
                height: 12,
                child:
                    CircularProgressIndicator(strokeWidth: 1.5, color: tk.accent),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  _filingWhat == null ? 'Filing' : 'Filing — $_filingWhat',
                  style: Kind.body(context, size: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],

          if (_working) ...[
            const SizedBox(height: Gap.md),
            Row(children: [
              SizedBox(
                width: 12,
                height: 12,
                child:
                    CircularProgressIndicator(strokeWidth: 1.5, color: tk.accent),
              ),
              const SizedBox(width: Gap.sm),
              Text('Sorting', style: Kind.body(context, size: 12)),
            ]),
          ],

          if (_pending != null) ...[
            const SizedBox(height: Gap.xl),
            SectionHead('${_pending!.length - _dropped.length} TO FILE'),
            const SizedBox(height: Gap.md),
            for (var i = 0; i < _pending!.length; i++)
              _DumpRow(
                item: _pending![i],
                dropped: _dropped.contains(i),
                onToggle: () => setState(() {
                  _dropped.contains(i) ? _dropped.remove(i) : _dropped.add(i);
                }),
                onKind: (k) => setState(() => _pending![i] = _pending![i].copyWith(kind: k)),
              ),
            const SizedBox(height: Gap.md),
            SoftButton(
              label: _filing ? 'FILING' : 'FILE THEM',
              primary: true,
              expand: true,
              onTap: (_filing || _dropped.length == _pending!.length)
                  ? null
                  : _commit,
            ),
          ],
        ],
      ),
    );
  }
}

/// One triaged line. The kind is a row of chips rather than a dropdown because
/// correcting a misfiled item has to be a single tap.
class _DumpRow extends StatelessWidget {
  const _DumpRow({
    required this.item,
    required this.dropped,
    required this.onToggle,
    required this.onKind,
  });

  final DumpItem item;
  final bool dropped;
  final VoidCallback onToggle;
  final ValueChanged<DumpKind> onKind;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Opacity(
      opacity: dropped ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Panel(
          color: tk.surfaceAlt,
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.text,
                        style: Kind.title(context, size: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      dropped ? Icons.circle_outlined : Icons.check_circle_rounded,
                      size: 20,
                      color: dropped ? tk.inkDim : tk.cool,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in DumpKind.values)
                    GestureDetector(
                      onTap: () => onKind(k),
                      behavior: HitTestBehavior.opaque,
                      child: Tag(
                        k.label,
                        color: item.kind == k ? tk.accent : tk.inkDim,
                        filled: item.kind == k,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                switch (item.kind) {
                  DumpKind.task => '+${item.xp} XP when done',
                  DumpKind.habit =>
                    '${item.cadence.label} · +${item.xp} XP'
                        '${item.targetCount > 1 ? ' · ${item.targetCount}×' : ''}',
                  DumpKind.done => 'Banked immediately · +${item.xp} XP',
                  DumpKind.obligation =>
                    '${euro(item.amountEuro ?? 0)} ${item.obligationCadence.label.toLowerCase()}',
                  DumpKind.wish => item.amountEuro == null
                      ? 'Will be priced'
                      : euro(item.amountEuro!),
                },
                style: Kind.body(context, size: 11.5, color: tk.inkDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
