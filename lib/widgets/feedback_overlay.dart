import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/lexicon.dart';
import '../models/cosmetic.dart';
import '../state/game_event.dart';
import '../state/game_state.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import 'credit_mark.dart';
import 'emblem.dart';
import 'primitives.dart';

/// The instant, visible acknowledgement that something real just happened.
///
/// This is most of the reason the app works at all: the bar moving is good, but
/// a `+50 XP` rising off the screen the moment a thumb leaves the button is
/// what makes the feedback feel immediate rather than reported.
class FeedbackOverlay extends StatefulWidget {
  const FeedbackOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<FeedbackOverlay> {
  StreamSubscription<GameEvent>? _sub;
  final _marks = <_Mark>[];
  _Ceremony? _ceremony;
  Timer? _ceremonyTimer;
  var _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.read<GameState>().events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ceremonyTimer?.cancel();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    final tk = context.tk;
    switch (e) {
      case XpGained(:final xp):
        if (xp > 0) _push('+$xp XP', tk.accent);
      case QuestCollected(:final credits):
        if (credits > 0) _push('+$credits', tk.cool, credit: true);
      case CreditsSpent(:final credits):
        _push('−$credits', tk.alert, credit: true);
      case TierCrossed(:final result, :final garnished):
        _showCeremony(_Ceremony(
          kicker: Lex.tier,
          headline: result.endLevel.toString().padLeft(3, '0'),
          detail: '+${fmt(result.coinsAwarded - garnished)} ${Lex.currency}',
          footnote: garnished > 0
              ? '${fmt(garnished)} withheld against ${Lex.arrears.toLowerCase()}'
              : null,
        ));
      case MasteryLevelUp(:final trackName, :final level):
        _showCeremony(_Ceremony(
          kicker: Lex.mastery,
          headline: trackName,
          detail: 'LEVEL $level',
        ));
      case CosmeticUnlocked(:final cosmetic):
        _showCeremony(_Ceremony(
          kicker: 'UNLOCKED',
          headline: cosmetic.name,
          detail: cosmetic.type.label,
          emblem: Emblem.cipher,
        ));
      case GameNotice(:final message):
        _push(message, tk.alert, wide: true);
      case IncomeLogged(:final toFund):
        _push('${Lex.fund} +${euro(toFund)}', tk.cool, wide: true);
      case UpkeepAccrued(:final burned, :final days):
        if (burned > 0) {
          _push('−${fmt(burned.round())} ${Lex.upkeep}${days > 1 ? ' ×$days' : ''}',
              tk.alert,
              wide: true);
        }
      default:
        break;
    }
  }

  void _push(String text, Color color, {bool wide = false, bool credit = false}) {
    final id = _seq++;
    setState(() {
      // A burst of completions should read as a burst, not as one mark being
      // overwritten — so they stack and drift apart.
      _marks.add(_Mark(
        id: id,
        text: text,
        color: color,
        wide: wide,
        credit: credit,
        lane: _marks.length % 3,
      ));
    });
    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _marks.removeWhere((m) => m.id == id));
    });
  }

  void _showCeremony(_Ceremony c) {
    _ceremonyTimer?.cancel();
    setState(() => _ceremony = c);
    _ceremonyTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _ceremony = null);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          widget.child,
          // Marks are decoration; they must never eat a tap.
          IgnorePointer(
            // This layer sits *above* the Scaffold, so it has no Material
            // ancestor of its own. Without one, every Text here falls back to
            // Flutter's yellow double-underline debug style.
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  for (final m in _marks)
                    _RisingMark(key: ValueKey(m.id), mark: m),
                  if (_ceremony != null) _CeremonyLayer(ceremony: _ceremony!),
                ],
              ),
            ),
          ),
        ],
      );
}

class _Mark {
  final int id;
  final String text;
  final Color color;
  final bool wide;
  final bool credit;
  final int lane;
  const _Mark({
    required this.id,
    required this.text,
    required this.color,
    required this.wide,
    required this.credit,
    required this.lane,
  });
}

class _RisingMark extends StatelessWidget {
  const _RisingMark({super.key, required this.mark});
  final _Mark mark;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final drift = (mark.lane - 1) * 48.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        final opacity = t < 0.12 ? t / 0.12 : (1 - ((t - 0.12) / 0.88)).clamp(0.0, 1.0);
        return Positioned(
          left: 0,
          right: 0,
          top: size.height * 0.34 - (t * 130) + drift,
          child: Opacity(
            opacity: opacity,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: context.tk.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: mark.color.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: mark.color.withValues(alpha: 0.22),
                      blurRadius: 26,
                    ),
                  ],
                ),
                child: mark.credit
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CreditMark(size: 16, color: mark.color),
                          const SizedBox(width: 6),
                          Text(mark.text,
                              style: Kind.figure(context,
                                  size: 20, color: mark.color, w: FontWeight.w600)),
                        ],
                      )
                    : Text(
                        mark.text,
                        textAlign: TextAlign.center,
                        style: mark.wide
                            ? Kind.label(context, size: 11, color: mark.color)
                            : Kind.figure(context,
                                size: 20, color: mark.color, w: FontWeight.w700),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Ceremony {
  final String kicker;
  final String headline;
  final String detail;
  final String? footnote;
  final Emblem? emblem;
  const _Ceremony({
    required this.kicker,
    required this.headline,
    required this.detail,
    this.footnote,
    this.emblem,
  });
}

/// The level-up moment. Brief and composed — no confetti, because the dopamine
/// here comes from the number, not from decoration.
class _CeremonyLayer extends StatelessWidget {
  const _CeremonyLayer({required this.ceremony});
  final _Ceremony ceremony;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2400),
        builder: (_, t, __) {
          final fade = t < 0.09
              ? t / 0.09
              : t > 0.76
                  ? (1 - (t - 0.76) / 0.24).clamp(0.0, 1.0)
                  : 1.0;
          // A single expanding ring, which is as much ceremony as this
          // interface permits itself.
          final ring = Curves.easeOutQuart.transform(math.min(1.0, t * 1.5));
          return Opacity(
            opacity: fade,
            child: Container(
              color: tk.canvas.withValues(alpha: 0.90 * fade),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120 + ring * 480,
                    height: 120 + ring * 480,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tk.accent.withValues(alpha: (1 - ring) * 0.55),
                        width: 1.4,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ceremony.emblem != null) ...[
                        EmblemMark(emblem: ceremony.emblem!, size: 52),
                        const SizedBox(height: Gap.md),
                      ],
                      Text(ceremony.kicker,
                          style: Kind.label(context, size: 11, color: tk.accent)),
                      const SizedBox(height: Gap.md),
                      Text(
                        ceremony.headline,
                        textAlign: TextAlign.center,
                        style: ceremony.headline.length > 5
                            ? Kind.display(context, size: 38)
                            : Kind.numeral(context, size: 76, w: FontWeight.w200),
                      ),
                      const SizedBox(height: Gap.md),
                      Text(ceremony.detail,
                          style: Kind.label(context, size: 11, color: tk.inkMid)),
                      if (ceremony.footnote != null) ...[
                        const SizedBox(height: Gap.sm),
                        Text(ceremony.footnote!,
                            style: Kind.body(context, size: 11.5, color: tk.alert)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
