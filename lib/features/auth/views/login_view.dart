import 'package:flutter/material.dart';

import '../../portfolio/views/daily_portfolio_view.dart';
import '../viewmodels/login_view_model.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final LoginViewModel _viewModel;

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
    _viewModel = LoginViewModel()..addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _submit() {
    if (!_viewModel.submit()) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DailyPortfolioView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _outlineVariant.withValues(alpha: 0.3),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 30,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/images/los_andes_logo.png',
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Portal Oficial de Cr\u00E9dito',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _onSurface,
                          fontSize: 24,
                          height: 32 / 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Acceso exclusivo para colaboradores de Banco Los Andes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _onSurfaceVariant,
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
                      ),
                      const SizedBox(height: 16),
                      _LoginTextField(
                        label: 'Contrase\u00F1a',
                        hintText: '********',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        onChanged: _viewModel.updatePassword,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _viewModel.updateRememberDevice(
                              !_viewModel.rememberDevice,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _viewModel.rememberDevice,
                                    activeColor: _primary,
                                    checkColor: _onPrimaryFixed,
                                    side: const BorderSide(
                                      color: _outlineVariant,
                                    ),
                                    onChanged: (value) => _viewModel
                                        .updateRememberDevice(value ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recordar en este equipo',
                                  style: TextStyle(
                                    color: _onSurfaceVariant,
                                    fontSize: 12,
                                    height: 18 / 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: _primary,
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '\u00BFOlvid\u00F3 su contrase\u00F1a?',
                              style: TextStyle(
                                fontSize: 11,
                                height: 14 / 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _viewModel.canSubmit ? _submit : null,
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Ingresar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryContainer,
                          foregroundColor: _onPrimaryFixed,
                          disabledBackgroundColor: _surfaceContainerHighest
                              .withValues(alpha: 0.7),
                          disabledForegroundColor: _onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Divider(
                        height: 1,
                        color: _outlineVariant.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: _outline,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Sistema de acceso seguro',
                            style: TextStyle(
                              color: _outline,
                              fontSize: 12,
                              height: 18 / 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
  });

  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  static const _surface = _LoginViewState._surface;
  static const _onSurface = _LoginViewState._onSurface;
  static const _onSurfaceVariant = _LoginViewState._onSurfaceVariant;
  static const _outline = _LoginViewState._outline;
  static const _outlineVariant = _LoginViewState._outlineVariant;
  static const _primary = _LoginViewState._primary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _onSurfaceVariant,
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
          style: const TextStyle(
            color: _onSurface,
            fontSize: 14,
            height: 20 / 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: _outline),
            prefixIcon: Icon(icon, color: _outline),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _primary),
            ),
          ),
        ),
      ],
    );
  }
}
