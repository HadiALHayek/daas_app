import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_scope.dart';
import '../core/constants/strings_ar.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_screen.dart';
import '../features/bills/bill_detail_screen.dart';
import '../features/bills/create_bill_screen.dart';
import '../features/customers/customer_bills_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/items/item_form_screen.dart';
import '../features/items/items_screen.dart';
import '../features/reports/profits_screen.dart';
import '../features/settings/exchange_rate_screen.dart';
import '../services/services.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final sessionRefresh = ref.watch(sessionRefreshProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: sessionRefresh,
    initialLocation: '/login',
    redirect: (context, state) async {
      final isLoggedIn = await ref.read(authServiceProvider).isLoggedIn();
      final isLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'items',
            builder: (context, state) => const ItemsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ItemFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) => ItemFormScreen(
                  itemId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'exchange-rate',
            builder: (context, state) => const ExchangeRateScreen(),
          ),
          GoRoute(
            path: 'customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: ':id/bills',
                builder: (context, state) => CustomerBillsScreen(
                  customerId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'bills/new',
            builder: (context, state) => const CreateBillScreen(),
          ),
          GoRoute(
            path: 'bills/:id',
            builder: (context, state) => BillDetailScreen(
              billId: state.pathParameters['id']!,
              shouldPrint: state.uri.queryParameters['print'] == 'true',
            ),
          ),
          GoRoute(
            path: 'expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: 'profits',
            builder: (context, state) => const ProfitsScreen(),
          ),
        ],
      ),
    ],
  );
});

class DaasApp extends ConsumerWidget {
  const DaasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return SessionScope(
      router: router,
      child: MaterialApp.router(
        title: StringsAr.appTitle,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        routerConfig: router,
      ),
    );
  }
}
