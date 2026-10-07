import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/api/data_changes.dart';
import 'core/api/token_store.dart';
import 'core/auth/profile.dart';
import 'core/auth/session.dart';
import 'core/theme/app_theme.dart';
import 'core/update/app_update.dart';
import 'features/company/company.dart';
import 'features/customers/customer.dart';
import 'features/quotes/quote.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient(TokenStore());
  final session = Session(api)..init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider<DataChanges>.value(value: api.changes),
        Provider(create: (_) => QuotesRepository(api)),
        Provider(create: (_) => CustomersRepository(api)),
        Provider(create: (_) => CompanyRepository(api)),
        Provider(create: (_) => StampRepository(api)),
        Provider(create: (_) => DashboardRepository(api)),
      ],
      child: DevisApp(api: api, router: buildRouter(session)),
    ),
  );
}

class DevisApp extends StatelessWidget {
  const DevisApp({super.key, required this.api, required this.router});

  final ApiClient api;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    // Le thème suit la charte de l'entreprise (dernière connue), sinon les couleurs par défaut
    final branding = context.select<Session, Branding>((s) => s.branding);

    return MaterialApp.router(
      title: 'SN Devis',
      // Web/PWA : couleur de la barre d'état du téléphone, assortie à l'en-tête
      color: branding.secondary,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(branding),
      routerConfig: router,
      builder: (context, child) => UpdateGate(api: api, navigatorKey: router.routerDelegate.navigatorKey, child: child!),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
