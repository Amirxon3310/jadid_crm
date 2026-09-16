import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The filter controls, in one place so every list in the app filters the
/// same way: a heading above each control, a rounded field, and a row
/// underneath naming what is currently filtering the list.

/// The heading above a filter control.
class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

/// Borders a filter control: grey at rest, primary once it is narrowing the
/// list, so the active ones are obvious at a glance.
InputBorder _border(BuildContext context, {required bool active}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: active
            ? AppColors.primary
            : Theme.of(context).brightness == Brightness.dark
            ? AppColors.muted.withValues(alpha: .45)
            : AppColors.border,
        width: active ? 1.6 : 1.2,
      ),
    );

/// A labelled dropdown filter.
class FilterField<T> extends StatelessWidget {
  const FilterField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.active = false,
    this.width = 240,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  /// Whether this filter is currently narrowing the list.
  final bool active;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterLabel(icon, label),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: _border(context, active: active),
            enabledBorder: _border(context, active: active),
            focusedBorder: _border(context, active: true),
          ),
          items: items,
          // A nullable filter accepts the "all" entry; a non-nullable one
          // never reports null in the first place.
          onChanged: (next) {
            if (next is T) onChanged(next);
          },
        ),
      ],
    ),
  );
}

/// A labelled on/off filter, such as "only the late ones".
class FilterToggle extends StatelessWidget {
  const FilterToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _FilterLabel(icon, label),
      SizedBox(
        height: 52,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ),
    ],
  );
}

/// The search field above a list.
class FilterSearch extends StatelessWidget {
  const FilterSearch({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 8, right: 4),
        child: Icon(Icons.search_rounded, color: AppColors.muted),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: _border(context, active: false),
      enabledBorder: _border(context, active: false),
      focusedBorder: _border(context, active: true),
    ),
  );
}

/// What is filtering the list right now: one chip per filter, each removable,
/// with a way to clear the lot.
class ActiveFilters extends StatelessWidget {
  const ActiveFilters({
    super.key,
    required this.filters,
    required this.onClearAll,
  });

  final List<({IconData icon, String label, String value, VoidCallback remove})>
  filters;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Active filtrlar:',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          for (final filter in filters)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              decoration: BoxDecoration(
                color: AppColors.softBlue(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(filter.icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text(
                    '${filter.label}: ',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    filter.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Olib tashlash',
                    onPressed: filter.remove,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    icon: const Icon(
                      Icons.cancel_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: onClearAll,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            label: const Text(
              'Hammasini tozalash',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tozalash" with the number of filters it would clear.
class ClearFiltersButton extends StatelessWidget {
  const ClearFiltersButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      icon: const Icon(Icons.cancel_rounded, size: 20, color: AppColors.muted),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tozalash', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.softBlue(context),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
