import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/events/app_event.dart';
import '../../core/ids.dart';
import '../today/today_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  static const _maxLength = 500;

  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving) return;
    final message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Please write a few words first.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref
          .read(eventRepositoryProvider)
          .append(
            AppEvent(
              id: newUuid(),
              type: EventType.feedbackSubmitted,
              payload: {'message': message},
              occurredAt: ref.read(clockProvider)().toUtc(),
            ),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'That did not save. Please try again.';
        _saving = false;
      });
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Thank you. Your idea was saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Share your ideas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'What would you like to see added or changed?',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Please do not include personal or health details.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 8,
            maxLength: _maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Your idea',
              alignLabelWithHint: true,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: _saving ? null : _send,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
