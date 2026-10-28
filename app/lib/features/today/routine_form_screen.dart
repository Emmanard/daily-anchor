import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routine.dart';
import 'routines_provider.dart';

class RoutineFormScreen extends ConsumerStatefulWidget {
  const RoutineFormScreen({
    super.key,
    this.routine,
    this.initialTitle,
    this.iconKey = Routine.defaultIconKey,
  });

  /// The routine being edited, or null when adding a new one.
  final Routine? routine;

  /// Name and icon to start a new routine with, from an example.
  final String? initialTitle;
  final String iconKey;

  @override
  ConsumerState<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _RoutineFormScreenState extends ConsumerState<RoutineFormScreen> {
  static const _maxLength = 60;

  late final _controller = TextEditingController(
    text: widget.routine?.title ?? widget.initialTitle,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    final notifier = ref.read(routinesProvider.notifier);
    final existing = widget.routine;
    final saved = existing == null
        ? await notifier.add(title, iconKey: widget.iconKey)
        : await notifier.rename(existing.id, title);

    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = 'That did not save. Please try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.routine != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit routine' : 'Add routine')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autofocus: !editing,
            maxLength: _maxLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Routine name',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
