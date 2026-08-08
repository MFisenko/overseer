import 'dart:async';

import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import 'credit_mark.dart';
import 'primitives.dart';

/// One directive.
///
/// Two states that matter: open, where the move is DONE, and done, where the
/// move is COLLECT. Keeping those as two deliberate taps is lifted straight
/// from games — earning and claiming are separate, the second tap is what makes
/// claiming feel active, and the expiry on top of it is what makes it urgent.
class QuestTile extends StatefulWidget {
  const QuestTile({
    super.key,
    required this.quest,
    required this.onComplete,
    required this.onCollect,
    this.onLongPress,
  });

  final Quest quest;
  final VoidCallback onComplete;
  final VoidCallback onCollect;
  final VoidCallback? onLongPress;

  @override
  State<QuestTile> createState() => _QuestTileState();
}

class _QuestTileState extends State<QuestTile> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Countdowns are the pressure. They have to actually move.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final q = widget.quest;
    final left = q.timeLeft;
    final urgent = q.isUrgent;
    final collectable = q.isCollectable;

    // A finished directive waiting on a tap is the most valuable thing on the
    // screen, so it gets the accent border and the filled button.
    final borderColor = collectable
        ? tk.cool
        : urgent
            ? tk.alert.withValues(alpha: 0.55)
            : tk.hairline;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(Gap.md, 14, 12, 14),
          decoration: BoxDecoration(
            color: collectable ? tk.coolSoft : tk.surface,
            borderRadius: Radii.brMd,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(color: tk.shadow, blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.title,
                      style: Kind.title(context, size: 14.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Wraps rather than overflows: a repeating, paid, expiring
                    // directive carries five pieces of metadata, which is more
                    // than a narrow screen fits on one line.
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // XP is the point of a directive, so it leads.
                        Text('+${q.xpValue} XP',
                            style: Kind.figure(context,
                                size: 11.5,
                                color: tk.accent,
                                w: FontWeight.w700)),
                        if (q.coinValue > 0)
                          CreditAmount(q.coinValue,
                              size: 11,
                              color: tk.inkDim,
                              weight: FontWeight.w600,
                              markGap: 3),
                        if (q.isRepeating)
                          Text('${q.progressCount}/${q.targetCount}',
                              style: Kind.figure(context,
                                  size: 11, color: tk.inkMid)),
                        if (left != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 11,
                                  color: urgent ? tk.alert : tk.inkDim),
                              const SizedBox(width: 3),
                              Text(countdown(left),
                                  style: Kind.figure(context,
                                      size: 10.5,
                                      color: urgent ? tk.alert : tk.inkDim)),
                            ],
                          ),
                        if (q.earnsIncome)
                          Text('PAID',
                              style: Kind.label(
                                  context, size: 8.5, color: tk.cool)),
                      ],
                    ),
                    if (q.isRepeating) ...[
                      const SizedBox(height: 9),
                      ProgressBar(
                        progress: q.progressCount / q.targetCount,
                        height: 3,
                        color: tk.accent,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              if (collectable)
                SoftButton(
                  label: 'COLLECT',
                  primary: true,
                  dense: true,
                  onTap: widget.onCollect,
                )
              else
                SoftButton(
                  label: q.isRepeating ? '+1' : 'DONE',
                  dense: true,
                  onTap: widget.onComplete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
