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
            expandedHeight: 190,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
              title: Text(
                StringsAr.dashboard,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.primaryLight,
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -40,
                      top: -30,
                      child: Icon(
                        Icons.chair_alt_rounded,
                        size: 180,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 44),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.asset(
                                'assets/app_logo.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    StringsAr.factoryName,
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    StringsAr.appTitle,
                                    style: GoogleFonts.cairo(
                                      color: AppColors.accentSoft
                                          .withValues(alpha: 0.9),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle_outlined),
                tooltip: StringsAr.account,
                onSelected: (value) async {
                  if (value == 'change-password') {
                    context.push('/change-password');
                  } else if (value == 'logout') {
                    await ref.read(authServiceProvider).logout();
                    if (context.mounted) context.go('/login');
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'change-password',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.lock_outline_rounded),
                      title: Text(StringsAr.changePassword),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout_rounded, color: AppColors.error),
                      title: Text(StringsAr.logout),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'الوحدات',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
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
                DashboardTile(
                  icon: Icons.groups_rounded,
                  label: StringsAr.employees,
                  subtitle: 'الدوام والرواتب',
                  color: AppColors.dashboardTiles[0],
                  onTap: () => context.push('/employees'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
