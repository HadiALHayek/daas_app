import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/strings_ar.dart';
import '../../services/services.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringsAr.dashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: StringsAr.logout,
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _DashboardCard(
              icon: Icons.inventory_2_outlined,
              label: StringsAr.manageItems,
              onTap: () => context.push('/items'),
            ),
            _DashboardCard(
              icon: Icons.currency_exchange,
              label: StringsAr.exchangeRate,
              onTap: () => context.push('/exchange-rate'),
            ),
            _DashboardCard(
              icon: Icons.people_outline,
              label: StringsAr.customers,
              onTap: () => context.push('/customers'),
            ),
            _DashboardCard(
              icon: Icons.receipt_long_outlined,
              label: StringsAr.newBill,
              onTap: () => context.push('/bills/new'),
            ),
            _DashboardCard(
              icon: Icons.bar_chart_outlined,
              label: StringsAr.profits,
              onTap: () => context.push('/profits'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
