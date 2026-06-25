import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/web_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/models/auth_session.dart';
import 'features/auth/views/login_view.dart';
import 'features/collection/services/collection_commitment_notification_service.dart';
import 'features/portfolio/services/portfolio_nightly_sync_service.dart';
import 'shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  const dartDefineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const dartDefineSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final supabaseUrl = dartDefineSupabaseUrl.isNotEmpty
      ? dartDefineSupabaseUrl
      : dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dartDefineSupabaseAnonKey.isNotEmpty
      ? dartDefineSupabaseAnonKey
      : dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  final isSupabaseConfigured =
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  if (isSupabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  await CollectionCommitmentNotificationService.initialize();
  if (!kIsWeb) {
    await PortfolioNightlySyncService.initialize();
  }

  runApp(MainApp(isSupabaseConfigured: isSupabaseConfigured));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.isSupabaseConfigured});

  final bool isSupabaseConfigured;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AuthRepository _authRepository;
  late final Future<AuthSession?> _initialSession;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository(
      isSupabaseConfigured: widget.isSupabaseConfigured,
      client: widget.isSupabaseConfigured ? Supabase.instance.client : null,
    );
    _initialSession = _authRepository.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banco Los Andes Ventas',
      debugShowCheckedModeBanner: false,
      theme: kIsWeb
          ? WebTheme.lightTheme
          : ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00C1F9),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              fontFamily: 'Inter',
            ),
      home: FutureBuilder<AuthSession?>(
        future: _initialSession,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SplashView();
          }

          final session = snapshot.data;
          if (session == null) {
            return LoginView(authRepository: _authRepository);
          }

          return AppShell(
            authRepository: _authRepository,
            session: session,
          );
        },
      ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF051424),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
