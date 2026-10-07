import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/session.dart';
import 'core/widgets/brand_nav_bar.dart';
import 'core/widgets/sn_brand.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/pending_approval_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/set_password_screen.dart';
import 'features/company/company_form_screen.dart';
import 'features/company/company_screen.dart';
import 'features/company/profile_screen.dart';
import 'features/company/stamp_screen.dart';
import 'features/customers/customer.dart';
import 'features/customers/customer_detail_screen.dart';
import 'features/customers/customer_form_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/quotes/quote.dart';
import 'features/quotes/quote_detail_screen.dart';
import 'features/quotes/quote_editor_screen.dart';
import 'features/quotes/quotes_screen.dart';

GoRouter buildRouter(Session session) {
  // Destination demandée pendant le chargement de la session (lien direct)
  String? pending;

  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onAuth = location.startsWith('/auth');

      switch (session.status) {
        case SessionStatus.loading:
          if (location != '/splash') {
            pending = state.uri.toString();
            return '/splash';
          }
          return null;
        case SessionStatus.signedOut:
          return onAuth ? null : '/auth/login';
        case SessionStatus.signedIn:
          if (onAuth || location == '/splash') {
            final target = pending ?? '/';
            pending = null;
            return target;
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SnSplash()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/auth/pending', builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(path: '/auth/otp', builder: (_, state) => OtpScreen(step: state.extra! as AuthStep)),
      GoRoute(path: '/auth/password', builder: (_, state) => SetPasswordScreen(step: state.extra! as AuthStep)),
      StatefulShellRoute(
        builder: (context, state, shell) => _HomeShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) => _FadingBranches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, __) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/quotes', builder: (_, state) => QuotesScreen(initialStatus: state.uri.queryParameters['status']))]),
          StatefulShellBranch(routes: [GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/company', builder: (_, __) => const CompanyScreen())]),
        ],
      ),
      GoRoute(path: '/quotes/new', builder: (_, state) => QuoteEditorScreen(customerId: int.tryParse(state.uri.queryParameters['customer'] ?? ''))),
      GoRoute(path: '/quotes/:id', builder: (_, state) => QuoteDetailScreen(id: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/quotes/:id/edit', builder: (_, state) => QuoteEditorScreen(quote: state.extra as Quote?)),
      GoRoute(path: '/customers/new', builder: (_, __) => const CustomerFormScreen()),
      GoRoute(path: '/customers/:id', builder: (_, state) => CustomerDetailScreen(id: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/customers/:id/edit', builder: (_, state) => CustomerFormScreen(customer: state.extra as Customer?)),
      GoRoute(path: '/company/edit', builder: (_, __) => const CompanyFormScreen()),
      GoRoute(path: '/company/stamp', builder: (_, __) => const StampScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    BrandNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Accueil'),
    BrandNavItem(icon: Icons.request_quote_outlined, selectedIcon: Icons.request_quote_rounded, label: 'Devis'),
    BrandNavItem(icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: 'Clients'),
    BrandNavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Entreprise'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: BrandNavBar(
        items: _items,
        selectedIndex: shell.currentIndex,
        // Toucher l'onglet actif ramène à sa page d'accueil
        onSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}

/// Onglets conservés en mémoire (comme un IndexedStack) avec un fondu enchaîné
/// et un léger glissement vers le haut à l'arrivée.
class _FadingBranches extends StatelessWidget {
  const _FadingBranches({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: AnimatedOpacity(
              opacity: i == index ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: i == index ? Offset.zero : const Offset(0, 0.015),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                // Onglets cachés : animations en pause (le fondu ci-dessus, lui, continue)
                child: TickerMode(
                  enabled: i == index,
                  child: ExcludeSemantics(excluding: i != index, child: children[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
