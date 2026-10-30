import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import 'day_progress.dart';
import 'progress_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: progress.when(
        loading: () => const _Loading(),
        error: (error, stackTrace) =>
            _LoadError(onRetry: () => ref.invalidate(progressProvider)),
        data: (view) =>
            _ProgressList(view: view, now: ref.read(clockProvider)()),
      ),
    );
  }
}

class _ProgressList extends StatelessWidget {
  const _ProgressList({required this.view, required this.now});

  final ProgressView view;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final newestFirst = view.days.reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active on ${view.activeDays} of the last ${view.days.length} days',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A day counts when you finish at least one routine.',
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  view.fromServer
                      ? Icons.cloud_done_outlined
                      : Icons.phone_android,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  view.fromServer
                      ? 'Totals checked with the server.'
                      : 'Showing what is saved on this phone. It has not been '
                            'checked with the server.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (view.isEmpty)
          Text(
            'Nothing recorded yet this week. Finish a routine and it will show '
            'here.',
            style: textTheme.titleMedium,
          )
        else
          for (final day in newestFirst) ...[
            _DayRow(day: day, now: now),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.now});

  final DayProgress day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The tick and the words below say the same thing, so the state
              // never depends on the icon or a color.
              ExcludeSemantics(
                child: Icon(
                  day.active
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel(day.date, now),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Routines done: ${day.routinesCompleted}',
                      style: textTheme.bodyLarge,
                    ),
                    Text(
                      'Word exercises: ${day.recallAttempts}',
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading your week',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
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
              'Your progress could not be loaded.',
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
