import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_controller.dart';

/// A calm one-line note on whether everything is saved on the server. Words and
/// an icon carry the meaning; it is never shown as a warning.
class SyncStatusLine extends ConsumerWidget {
  const SyncStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final (icon, text) = switch (sync.status) {
      SyncStatus.off => (
        Icons.cloud_off_outlined,
        'Saved on this phone. Sync is off.',
      ),
      SyncStatus.synced => (Icons.cloud_done_outlined, 'All saved'),
      SyncStatus.syncing => (Icons.sync, 'Syncing'),
      SyncStatus.waiting => (
        Icons.cloud_upload_outlined,
        sync.pending == 1
            ? 'Waiting to sync (1 item)'
            : 'Waiting to sync (${sync.pending} items)',
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: MergeSemantics(
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
