import 'package:flutter/material.dart';
import '../core/app_icon.dart';
import '../core/app_theme.dart';

class RegistrationRolePicker extends StatefulWidget {
  const RegistrationRolePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String>? onChanged;
  @override
  State<RegistrationRolePicker> createState() => _RegistrationRolePickerState();
}

class _RegistrationRolePickerState extends State<RegistrationRolePicker> {
  bool open = false;
  void close() {
    if (open && mounted) setState(() => open = false);
  }

  @override
  void didUpdateWidget(covariant RegistrationRolePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null) open = false;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TapRegion(
      onTapOutside: (_) => close(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kim sifatida ro‘yxatdan o‘tasiz?',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF293344) : AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: open ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Semantics(
                    expanded: open,
                    button: true,
                    child: InkWell(
                      key: const ValueKey('role-selector'),
                      onTap: widget.onChanged == null
                          ? null
                          : () => setState(() => open = !open),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            AppIcon(
                              widget.value == 'teacher'
                                  ? 'teachers'
                                  : 'students',
                              active: true,
                              size: 23,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: Align(
                                  key: ValueKey(widget.value),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.value == 'teacher'
                                        ? 'Ustoz'
                                        : 'O‘quvchi',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: open ? .5 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    onEnd: () {
                      if (open && mounted) {
                        Scrollable.ensureVisible(
                          context,
                          alignment: 1,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: open
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Column(
                              children: [
                                for (final role in ['student', 'teacher'])
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Semantics(
                                      selected: widget.value == role,
                                      child: Material(
                                        color: widget.value == role
                                            ? AppColors.primary.withValues(
                                                alpha: .12,
                                              )
                                            : Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () {
                                            widget.onChanged?.call(role);
                                            close();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                AppIcon(
                                                  role == 'teacher'
                                                      ? 'teachers'
                                                      : 'students',
                                                  active: widget.value == role,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    role == 'teacher'
                                                        ? 'Ustoz'
                                                        : 'O‘quvchi',
                                                  ),
                                                ),
                                                if (widget.value == role)
                                                  const Icon(
                                                    Icons.check_rounded,
                                                    color: AppColors.primary,
                                                    size: 20,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
