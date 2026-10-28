import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recall/recall_screen.dart';
import '../settings/settings_screen.dart';
import 'routine.dart';
import 'routine_form_screen.dart';
import 'routines_provider.dart';
import 'today_provider.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    final today = ref.watch(todayProvider);
    final routineList = routines.value;
    final completed = today.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: routines.hasError || today.hasError
          ? _LoadError(
              onRetry: () {
                ref.invalidate(routinesProvider);
                ref.invalidate(todayProvider);
              },
            )
          : routineList == null || completed == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (routineList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('No routines yet. Add your first one below.'),
                  ),
                for (final routine in routineList) ...[
                  _RoutineCard(
                    routine: routine,
                    done: completed.contains(routine.id),
                    onToggle: () => _toggle(context, ref, routine),
                    onEdit: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RoutineFormScreen(routine: routine),
                      ),
                    ),
                    onDelete: () => _confirmDelete(context, ref, routine),
                  ),
                  const SizedBox(height: 16),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RoutineFormScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a routine'),
                ),
                const SizedBox(height: 16),
                const _RecallCard(),
              ],
            ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref.read(todayProvider.notifier).toggle(routine.id);
    if (!saved) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That did not save. Please try again.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${routine.title}"?'),
        content: const Text('Your past completions are kept.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await ref
        .read(routinesProvider.notifier)
        .remove(routine.id);
    if (!removed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That did not delete. Please try again.')),
      );
    }
  }
}

enum _RoutineAction { edit, delete }

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.done,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Routine routine;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const buttonSize = Size.fromHeight(56);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MergeSemantics(
                      child: Row(
                        children: [
                          ExcludeSemantics(child: Icon(routine.icon, size: 40)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  routine.title,
                                  style: textTheme.titleLarge,
                                ),
                                Row(
                                  children: [
                                    ExcludeSemantics(
                                      child: Icon(
                                        done
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        done ? 'Done' : 'Not done yet',
                                        style: textTheme.bodyLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<_RoutineAction>(
                  tooltip: 'More options for ${routine.title}',
                  onSelected: (action) => switch (action) {
                    _RoutineAction.edit => onEdit(),
                    _RoutineAction.delete => onDelete(),
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _RoutineAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: _RoutineAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: done
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                      onPressed: onToggle,
                      child: Text(
                        'Undo',
                        semanticsLabel: 'Undo ${routine.title}',
                      ),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(minimumSize: buttonSize),
                      onPressed: onToggle,
                      child: Text(
                        'Mark done',
                        semanticsLabel: 'Mark ${routine.title} as done',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecallCard extends StatelessWidget {
  const _RecallCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                children: [
                  const ExcludeSemantics(
                    child: Icon(Icons.lightbulb_outline, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Word recall', style: textTheme.titleLarge),
                        Text(
                          'A short word exercise, about a minute.',
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RecallScreen()),
              ),
              child: const Text(
                'Start exercise',
                semanticsLabel: 'Start word recall exercise',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your routines could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
