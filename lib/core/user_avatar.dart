import 'package:flutter/material.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import 'app_theme.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.store,
    required this.user,
    this.radius = 24,
  });
  final CrmStore store;
  final AppUser user;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final url = store.avatarUrls[user.avatarPath];
    final bytes = store.avatarImages[user.avatarPath];
    final fallback = ColoredBox(
      color: AppColors.primary,
      child: Center(
        child: Text(
          user.name.characters.firstOrNull?.toUpperCase() ?? '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
