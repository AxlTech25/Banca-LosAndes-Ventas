import 'package:flutter/material.dart';

import '../../core/theme/web_theme.dart';
import '../../features/auth/models/auth_session.dart';

class WebUserChip extends StatelessWidget {
  const WebUserChip({
    super.key,
    required this.session,
    this.compact = false,
  });

  final AuthSession session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(session.displayName);

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: WebTheme.brandCyanLight.withValues(alpha: 0.35),
            child: Text(
              initials,
              style: const TextStyle(
                color: WebTheme.brandCyanDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            session.displayName,
            style: const TextStyle(
              color: WebTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: WebTheme.brandCyanLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WebTheme.brandCyan.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: WebTheme.brandCyanDark,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.displayName,
                style: const TextStyle(
                  color: WebTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                '${session.role.label} · ${session.employeeCode}',
                style: const TextStyle(
                  color: WebTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
