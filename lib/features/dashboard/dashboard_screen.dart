import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../services/services.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
              title: Text(
                StringsAr.dashboard,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -30,
                      top: -20,
                      child: Icon(
                        Icons.chair_alt_rounded,
                        size: 140,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      bottom: 56,
                      left: 20,
                      child: Text(
                        'مرحباً بك في لوحة التحكم',
                        style: GoogleFonts.cairo(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: StringsAr.logout,
                onPressed: () async {
                  await ref.read(authServiceProvider).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildListDelegate([
                DashboardTile(
                  icon: Icons.inventory_2_rounded,
                  label: StringsAr.manageItems,
                  subtitle: 'الكتالوج والأسعار',
                  color: AppColors.dashboardTiles[0],
                  onTap: () => context.push('/items'),
                ),
                DashboardTile(
                  icon: Icons.currency_exchange_rounded,
                  label: StringsAr.exchangeRate,
                  subtitle: 'دولار / ليرة',
                  color: AppColors.dashboardTiles[1],
                  onTap: () => context.push('/exchange-rate'),
                ),
                DashboardTile(
                  icon: Icons.people_alt_rounded,
                  label: StringsAr.customers,
                  subtitle: 'دفاتر الفواتير',
                  color: AppColors.dashboardTiles[2],
                  onTap: () => context.push('/customers'),
                ),
                DashboardTile(
                  icon: Icons.receipt_long_rounded,
                  label: StringsAr.newBill,
                  subtitle: 'إنشاء وطباعة',
                  color: AppColors.dashboardTiles[3],
                  onTap: () => context.push('/bills/new'),
                ),
                DashboardTile(
                  icon: Icons.payments_rounded,
                  label: StringsAr.expenses,
                  subtitle: 'مواد، نقل، أجور',
                  color: AppColors.dashboardTiles[5],
                  onTap: () => context.push('/expenses'),
                ),
                DashboardTile(
                  icon: Icons.insights_rounded,
                  label: StringsAr.profits,
                  subtitle: 'تقارير الأرباح',
                  color: AppColors.dashboardTiles[4],
                  onTap: () => context.push('/profits'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
