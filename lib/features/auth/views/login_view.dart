import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../models/auth_session.dart';
import '../../../core/theme/web_theme.dart';
import '../../../shared/widgets/banco_los_andes_logo.dart';
import '../../../shell/app_shell.dart';
import '../viewmodels/login_view_model.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final LoginViewModel _viewModel;
  Timer? _lockTimer;

  static const _background = Color(0xFF051424);
  static const _surface = Color(0xFF051424);
  static const _surfaceContainerHigh = Color(0xFF1C2B3C);
  static const _surfaceContainerHighest = Color(0xFF273647);
  static const _onSurface = Color(0xFFD4E4FA);
  static const _onSurfaceVariant = Color(0xFFBCC8D0);
  static const _outline = Color(0xFF86929A);
  static const _outlineVariant = Color(0xFF3D484F);
  static const _primary = Color(0xFF89D9FF);
  static const _primaryContainer = Color(0xFF00C1F9);
  static const _onPrimaryFixed = Color(0xFF001F2A);

  @override
  void initState() {
    super.initState();
    _viewModel = LoginViewModel(authRepository: widget.authRepository)
      ..addListener(_onViewModelChanged);
    _viewModel.loadLockState();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_viewModel.isBlocked && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final session = await _viewModel.submit();
    if (session == null || !mounted) {
      return;
    }

    _openPortfolio(session);
  }

  void _openPortfolio(AuthSession session) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AppShell(
          authRepository: widget.authRepository,
          session: session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    if (isWeb) {
      return Scaffold(
        backgroundColor: WebTheme.pageBackground,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: WebTheme.headerGradient),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const BancoLosAndesLogo(height: 72),
                    const SizedBox(height: 12),
                    Text(
                      'Fuerza de Ventas',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: _buildLoginCard(isWeb: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: _buildLoginCard(isWeb: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard({required bool isWeb}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isWeb ? Colors.white : _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWeb
              ? Colors.black.withValues(alpha: 0.08)
              : _outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: isWeb
                ? WebTheme.brandCyanDark.withValues(alpha: 0.08)
                : const Color(0x66000000),
            blurRadius: isWeb ? 16 : 30,
            offset: Offset(0, isWeb ? 4 : 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isWeb)
              Image.asset(
                'assets/images/los_andes_logo.png',
                height: 96,
                fit: BoxFit.contain,
              ),
            if (!isWeb) const SizedBox(height: 24),
            Text(
              'Portal Oficial de Cr\u00E9dito',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isWeb ? WebTheme.textPrimary : _onSurface,
                fontSize: 24,
                height: 32 / 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Acceso exclusivo para colaboradores de Banco Los Andes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isWeb ? WebTheme.textSecondary : _onSurfaceVariant,
                fontSize: 12,
                height: 18 / 12,
              ),
            ),
            const SizedBox(height: 32),
            _LoginTextField(
              label: 'C\u00F3digo de empleado',
              hintText: 'Ej. 104592',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              onChanged: _viewModel.updateEmployeeCode,
              isWeb: isWeb,
            ),
            const SizedBox(height: 16),
            _LoginTextField(
              label: 'Contrase\u00F1a',
              hintText: '********',
              icon: Icons.lock_outline,
              obscureText: !_viewModel.isPasswordVisible,
              suffixIcon: IconButton(
                tooltip: _viewModel.isPasswordVisible
                    ? 'Ocultar contrasena'
                    : 'Mostrar contrasena',
                onPressed: _viewModel.togglePasswordVisibility,
                icon: Icon(
                  _viewModel.isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              onChanged: _viewModel.updatePassword,
              onSubmitted: (_) => _submit(),
              isWeb: isWeb,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_clock_outlined,
                      color: isWeb ? WebTheme.textSecondary : _outline,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sesion persistente',
                      style: TextStyle(
                        color: isWeb ? WebTheme.textSecondary : _onSurfaceVariant,
                        fontSize: 12,
                        height: 18 / 12,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isWeb ? WebTheme.brandCyanDark : _primary,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Problemas para ingresar',
                    style: TextStyle(
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              _LoginMessage(
                icon: Icons.error_outline,
                text: _viewModel.errorMessage!,
                isWeb: isWeb,
              ),
            ],
            if (_viewModel.isBlocked) ...[
              const SizedBox(height: 12),
              _LoginMessage(
                icon: Icons.timer_outlined,
                text: 'Intenta nuevamente en ${_formatRemainingLock()}',
                isWeb: isWeb,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _viewModel.canSubmit ? _submit : null,
              icon: _viewModel.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login, size: 18),
              label: Text(
                _viewModel.isBlocked ? 'Bloqueado' : 'Ingresar',
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isWeb ? WebTheme.brandCyanDark : _primaryContainer,
                foregroundColor: isWeb ? Colors.white : _onPrimaryFixed,
                disabledBackgroundColor: isWeb
                    ? WebTheme.brandCyanLight.withValues(alpha: 0.4)
                    : _surfaceContainerHighest.withValues(alpha: 0.7),
                disabledForegroundColor: isWeb
                    ? WebTheme.textSecondary.withValues(alpha: 0.6)
                    : _onSurfaceVariant.withValues(alpha: 0.6),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Divider(
              height: 1,
              color: isWeb
                  ? Colors.black.withValues(alpha: 0.08)
                  : _outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: isWeb ? WebTheme.textSecondary : _outline,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'Sistema de acceso seguro',
                  style: TextStyle(
                    color: isWeb ? WebTheme.textSecondary : _outline,
                    fontSize: 12,
                    height: 18 / 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemainingLock() {
    final remaining = _viewModel.remainingLockTime;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.isWeb = false,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool isWeb;

  static const _surface = _LoginViewState._surface;
  static const _onSurface = _LoginViewState._onSurface;
  static const _onSurfaceVariant = _LoginViewState._onSurfaceVariant;
  static const _outline = _LoginViewState._outline;
  static const _outlineVariant = _LoginViewState._outlineVariant;
  static const _primary = _LoginViewState._primary;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        isWeb ? WebTheme.textSecondary : _onSurfaceVariant;
    final textColor = isWeb ? WebTheme.textPrimary : _onSurface;
    final hintColor = isWeb ? WebTheme.textSecondary : _outline;
    final iconColor = isWeb ? WebTheme.textSecondary : _outline;
    final fillColor = isWeb ? Colors.white : _surface;
    final borderColor = isWeb
        ? Colors.black.withValues(alpha: 0.12)
        : _outlineVariant;
    final focusColor = isWeb ? WebTheme.brandCyan : _primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 20 / 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: Icon(icon, color: iconColor),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 4),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 4),
              borderSide: BorderSide(color: focusColor, width: isWeb ? 2 : 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginMessage extends StatelessWidget {
  const _LoginMessage({
    required this.icon,
    required this.text,
    this.isWeb = false,
  });

  final IconData icon;
  final String text;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWeb
            ? WebTheme.brandCyanLight.withValues(alpha: 0.15)
            : _LoginViewState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWeb
              ? WebTheme.brandCyan.withValues(alpha: 0.3)
              : _LoginViewState._outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isWeb ? WebTheme.brandCyanDark : _LoginViewState._primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isWeb
                    ? WebTheme.textPrimary
                    : _LoginViewState._onSurfaceVariant,
                fontSize: 12,
                height: 18 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
