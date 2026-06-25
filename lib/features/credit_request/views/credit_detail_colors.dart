import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/web_theme.dart';

/// Colores del detalle de solicitud adaptados a web (claro) o móvil (oscuro).
abstract final class CreditDetailColors {
  static bool get _isWeb => kIsWeb;

  static Color get scaffoldBg =>
      _isWeb ? WebTheme.pageBackground : AppColors.background;

  static Color get cardBg => _isWeb ? Colors.white : AppColors.surfaceContainer;

  static Color get cardBgLow =>
      _isWeb ? WebTheme.pageBackground : AppColors.surfaceContainerLow;

  static Color get cardBgHighest => _isWeb
      ? WebTheme.brandCyanLight.withValues(alpha: 0.12)
      : AppColors.surfaceContainerHighest;

  static Color get textPrimary =>
      _isWeb ? WebTheme.textPrimary : AppColors.onSurface;

  static Color get textSecondary =>
      _isWeb ? WebTheme.textSecondary : AppColors.onSurfaceVariant;

  static Color get border => _isWeb
      ? Colors.black.withValues(alpha: 0.08)
      : AppColors.outlineVariant;

  static Color get accent => _isWeb ? WebTheme.brandCyanDark : AppColors.primary;

  static Color get accentContainer =>
      _isWeb ? WebTheme.brandCyan : AppColors.primaryContainer;

  static Color get onAccentContainer =>
      _isWeb ? Colors.white : AppColors.onPrimaryFixed;

  static TextStyle get sectionTitle => TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      );

  static TextStyle get sectionSubtitle => TextStyle(
        color: textSecondary,
        fontSize: 13,
      );

  static TextStyle get bodyText => TextStyle(color: textPrimary);

  static TextStyle get mutedText => TextStyle(color: textSecondary);

  static TextStyle get labelText => TextStyle(
        color: textSecondary,
        fontSize: 12,
      );

  static TextStyle get valueText => TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      );

  static BoxDecoration cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? border),
      boxShadow: _isWeb
          ? [
              BoxShadow(
                color: WebTheme.brandCyanDark.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }
}
