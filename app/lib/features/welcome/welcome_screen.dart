import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/anchor_mark.dart';
import '../settings/settings_provider.dart';

class _Slide {
  const _Slide({required this.title, required this.body, this.icon});

  /// Null means the anchor mark is shown instead of an icon.
  final IconData? icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    title: 'Welcome to Daily Anchor',
    body: 'A calm place for the small things you want to do each day.',
  ),
  _Slide(
    icon: Icons.checklist,
    title: 'Your routines, your way',
    body:
        'Add the things you want to remember. Tap Mark done when you finish, '
        'and Undo if you change your mind.',
  ),
  _Slide(
    icon: Icons.lightbulb_outline,
    title: 'A short word exercise',
    body:
        'Try a one-minute word exercise whenever you like. There is no pass '
        'or fail.',
  ),
  _Slide(
    icon: Icons.phone_android,
    title: 'Works without internet',
    body:
        'Your routines are saved on your phone and work without a connection.',
  ),
];

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimer());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showDisclaimer() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Before you start'),
          content: const Text(
            'Daily Anchor is a learning project. It is not a medical product '
            'and does not give health advice. Please do not enter personal or '
            'health details.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('I understand'),
            ),
          ],
        ),
      ),
    );
  }

  void _goTo(int page) {
    // animateToPage rejects a zero duration, so reduced motion jumps instead.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
      return;
    }
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() =>
      ref.read(settingsProvider.notifier).markWelcomeSeen();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: _isLast
                    ? const SizedBox(height: 48)
                    : TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, 48),
                        ),
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  for (final slide in _slides)
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (slide.icon == null)
                              const AnchorMark(size: 140)
                            else
                              _IconBadge(icon: slide.icon!),
                            const SizedBox(height: 32),
                            Semantics(
                              header: true,
                              child: Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.body,
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Text(
                    'Step ${_page + 1} of ${_slides.length}',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          Container(
                            width: i == _page ? 28 : 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? scheme.primary
                                  : scheme.outline.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: _isLast ? _finish : () => _goTo(_page + 1),
                    child: Text(_isLast ? 'Get started' : 'Next'),
                  ),
                  if (_page > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _goTo(_page - 1),
                      child: const Text('Back'),
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 72, color: scheme.onPrimary),
      ),
    );
  }
}
