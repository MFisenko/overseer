import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/companion.dart';
import '../../services/companion_voice.dart';
import '../../state/game_event.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../primitives.dart';
import '../../screens/companion/overseer_screen.dart';
import 'overseer_eye.dart';
import '../../models/appearance.dart';

/// The overseer, floating above every screen.
///
/// Draggable, always present, and never in the way — it sits on top of the
/// interface rather than inside it, which is what makes it read as a presence
/// watching the app rather than a component of it.
class CompanionLayer extends StatefulWidget {
  const CompanionLayer({super.key, required this.child, this.eyeSize = 66});

  final Widget child;
  final double eyeSize;

  @override
  State<CompanionLayer> createState() => _CompanionLayerState();
}

class _CompanionLayerState extends State<CompanionLayer> {
  static const _uuid = Uuid();
  final _voice = CompanionVoice();

  Offset? _pos; // absolute, in layer space
  bool _dragging = false;

  /// How far this gesture has travelled. A pan recognizer and a tap recognizer
  /// on the same widget fight in the gesture arena, and the pan usually wins —
  /// so rather than registering a separate tap, a drag that never actually
  /// moved is treated as one.
  double _dragDistance = 0;

  CompanionMessage? _showing;
  Timer? _hideTimer;
  Timer? _idleTimer;
  StreamSubscription<GameEvent>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.read<GameState>().events.listen(_onEvent);
    _idleTimer ??=
        Timer.periodic(const Duration(minutes: 4), (_) => _speakUnprompted());
    // One line on arrival, once the first frame has state to talk about.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showing == null) _speak(MessageKind.greeting);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    switch (e) {
      case TierCrossed():
        _speak(MessageKind.levelUp);
      case QuestCollected():
        _speak(MessageKind.collect);
      case StreakChanged():
        _speak(MessageKind.streak);
      case UpkeepAccrued(:final enteredArrears):
        if (enteredArrears) _speak(MessageKind.suggestion);
      default:
        break;
    }
  }

  void _speakUnprompted() {
    if (!mounted || _dragging) return;
    final game = context.read<GameState>();
    final ctx = CompanionContext.of(game);
    _speak(_voice.chooseKind(ctx));
  }

  /// Composes a line, updates the mood so the eye matches the tone, and shows
  /// the bubble. Phase 11 swaps the body of this for a Gemini call with the
  /// same context object and keeps the bank as the fallback.
  void _speak(MessageKind kind) {
    if (!mounted) return;
    final game = context.read<GameState>();
    final ctx = CompanionContext.of(game);
    final mood = _voice.moodFor(ctx);
    final msg = CompanionMessage(
      id: _uuid.v4(),
      text: _voice.line(kind, ctx),
      kind: kind,
      mood: mood,
      createdAt: DateTime.now(),
    );

    setState(() => _showing = msg);
    unawaited(game.pushCompanionMessage(msg));

    _hideTimer?.cancel();
    // Long enough to read twice, short enough that it never nags.
    _hideTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => _showing = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final appearance = game.companion.appearance;
    final mood = game.companion.mood;

    return LayoutBuilder(
      builder: (context, box) {
        final size = widget.eyeSize;
        // Restore the last dragged position, clamped into the current viewport
        // so a phone-sized position never strands the eye off a tablet screen.
        final pos = _pos ??
            Offset(
              (game.companion.x * box.maxWidth).clamp(0.0, box.maxWidth - size),
              (game.companion.y * box.maxHeight)
                  .clamp(0.0, box.maxHeight - size),
            );

        // The bubble flips to whichever side has room, and only grows *upward*
        // when the overseer is parked low enough that it rises into the scroll
        // view's bottom padding. Anywhere else it grows downward, because
        // upward from the middle of the screen means covering the credit
        // balance and the tier bar — the two things that must always be
        // readable.
        final onRight = pos.dx > box.maxWidth / 2;
        final growUp = pos.dy > box.maxHeight * 0.62;

        // The overseer floats above the Scaffold, which means it has no
        // Material ancestor of its own. Without one, Flutter falls its text
        // back to the yellow double-underline debug style.
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              widget.child,
              if (_showing != null)
                Positioned(
                  left: onRight ? Gap.md : pos.dx + size + Gap.sm,
                  right: onRight ? box.maxWidth - pos.dx + Gap.sm : Gap.md,
                  top: growUp ? null : pos.dy + size + Gap.sm,
                  bottom: growUp
                      ? (box.maxHeight - pos.dy - size)
                          .clamp(Gap.sm, box.maxHeight - 120)
                      : null,
                  child: _Bubble(
                    message: _showing!,
                    alignRight: onRight,
                    onTap: () => setState(() => _showing = null),
                  ),
                ),
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Tap opens its page; a long press asks it for a line
                  // without leaving the screen you are on.
                  onTap: () =>
                      Navigator.of(context).push(OverseerScreen.route()),
                  onLongPress: _speakUnprompted,
                  onPanStart: (_) => setState(() {
                    _dragging = true;
                    _dragDistance = 0;
                  }),
                  onPanUpdate: (d) {
                    setState(() {
                      _dragDistance += d.delta.distance;
                      _pos = Offset(
                        (pos.dx + d.delta.dx).clamp(0.0, box.maxWidth - size),
                        (pos.dy + d.delta.dy).clamp(0.0, box.maxHeight - size),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    setState(() => _dragging = false);
                    // A drag that never actually moved is a tap that the pan
                    // recognizer stole from the arena; treat it as one.
                    if (_dragDistance < 6) {
                      Navigator.of(context).push(OverseerScreen.route());
                      return;
                    }
                    final p = _pos;
                    if (p != null) {
                      unawaited(context.read<GameState>().setCompanionPosition(
                            p.dx / box.maxWidth,
                            p.dy / box.maxHeight,
                          ));
                    }
                  },
                  child: OverseerEye(
                    mood: mood,
                    appearance: appearance,
                    size: size,
                    streakDays: game.currentStreak,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The overseer's voice on screen: a terse terminal slab, no tail, no bounce.
class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.message, required this.alignRight, required this.onTap});

  final CompanionMessage message;
  final bool alignRight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final urgent = message.mood == CompanionMood.alert;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(message.id),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child:
              Transform.translate(offset: Offset(0, (1 - t) * 6), child: child),
        ),
        child: GlassPanel(
          radius: Radii.brMd,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          blur: 24,
          child: Column(
            crossAxisAlignment:
                alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: urgent ? tk.alert : tk.cool,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message.mood.label,
                    style: Kind.label(context,
                        size: 8.5, color: urgent ? tk.alert : tk.inkDim),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                message.text,
                // Always ragged-right. Mono text set flush right reads as a
                // stack trace, not as speech.
                textAlign: TextAlign.left,
                style: Kind.machine(context, size: 12.5, color: tk.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
