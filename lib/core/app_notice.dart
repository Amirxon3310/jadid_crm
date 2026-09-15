import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';

final _activeNotices = Expando<OverlayEntry>();

void showAppNotice(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final previous = _activeNotices[overlay];
  if (previous != null) {
    previous.remove();
    previous.dispose();
  }
  late final OverlayEntry entry;
  void close() {
    if (_activeNotices[overlay] != entry) return;
    _activeNotices[overlay] = null;
    entry.remove();
    entry.dispose();
  }

  final theme = Theme.of(context);
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: Theme(
              data: theme,
              child: _Notice(
                message: message,
                isError: isError,
                onClose: close,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _activeNotices[overlay] = entry;
  overlay.insert(entry);
}

class _Notice extends StatefulWidget {
  const _Notice({
    required this.message,
    required this.isError,
    required this.onClose,
  });
  final String message;
  final bool isError;
  final VoidCallback onClose;
  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(seconds: 5), widget.onClose);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError ? AppColors.danger : AppColors.success;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, -18 * (1 - value)),
          child: child,
        ),
      ),
      child: Semantics(
        liveRegion: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: .25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yopish',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
