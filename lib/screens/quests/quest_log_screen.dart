import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quest.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/primitives.dart';
import '../../widgets/quest_tile.dart';
import '../home/add_quest_sheet.dart';

/// Every directive, grouped by cadence, with its expiry countdown visible.
class QuestLogScreen extends StatelessWidget {
  const QuestLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final groups = <Cadence, List<Quest>>{
      for (final c in Cadence.values) c: game.questsOf(c),
    }..removeWhere((_, v) => v.isEmpty);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Gap.huge),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('The Log', style: Kind.display(context, size: 32)),
                        const SizedBox(height: 6),
                        Text(
                          '${game.activeQuests.length} active · '
                          '${game.collectable.length} awaiting collection',
                          style: Kind.body(context, size: 13),
                        ),
                      ],
                    ),
                  ),
                  SoftButton(
                    label: '+ NEW',
                    dense: true,
                    onTap: () => showAddQuestSheet(context),
                  ),
                ],
              ),
            ),
            if (groups.isEmpty)
              VoidState(
                line: 'The log is empty.',
                sub: 'Nothing is being tracked. That is not the same as nothing '
                    'needing doing.',
                action: SoftButton(
                  label: 'ISSUE A DIRECTIVE',
                  primary: true,
                  onTap: () => showAddQuestSheet(context),
                ),
              ),
            for (final entry in groups.entries)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHead(
                      entry.key.label,
                      trailing: Lbl('${entry.value.length}', color: tk.inkDim),
                    ),
                    const SizedBox(height: Gap.md),
                    for (final q in entry.value)
                      QuestTile(
                        quest: q,
                        onComplete: () => game.completeQuest(q.id),
                        onCollect: () => game.collectQuest(q.id),
                        onLongPress: () =>
                            showAddQuestSheet(context, existing: q),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
