import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.active = false,
    this.size = 26,
    this.fallback = Icons.circle_outlined,
  });
  final String? name;
  final bool active;
  final double size;
  final IconData fallback;
  @override
  Widget build(BuildContext context) {
    if (name == null)
      return Icon(
        fallback,
        size: size,
        color: active ? AppColors.primary : AppColors.muted,
      );
    final fileName = switch (name) {
      'edit' ||
      'delete' ||
      'padlock' ||
      'menu' ||
      'eye_hide' ||
      'eye_view' => '$name.png',
      'exit' => 'exit_${active ? 'white' : 'red'}.png',
      _ => '${name}_${active ? 'active' : 'noactive'}.png',
    };
    return Image.asset(
      'assets/icons/$fileName',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}
