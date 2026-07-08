import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showBack = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/app_logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        leading: showBack && canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.pop(),
              )
            : null,
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  /// Use inside scroll views / columns to avoid unbounded height layout errors.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.all(compact ? 16 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 80,
            height: compact ? 56 : 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 28 : 40, color: AppColors.primary),
          ),
          SizedBox(height: compact ? 12 : 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppColors.textSecondary,
                fontSize: compact ? 13 : 14,
              ),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: compact ? 16 : 24),
            action!,
          ],
        ],
      ),
    );

    if (compact) return content;
    return Center(child: content);
  }
}

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: padding, child: child));
  }
}

class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge({super.key, required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final isSyp = currency == 'SYP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSyp ? AppColors.successSoft : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isSyp ? 'ل.س' : r'$',
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isSyp ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}

class StatMetricCard extends StatelessWidget {
  const StatMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.secondaryValue,
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.onTap,
  });

  final String title;
  final String value;
  final String? secondaryValue;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor ?? color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (secondaryValue != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      secondaryValue!,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: color, size: 27),
                    ),
                    const Spacer(),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 12,
                        color: color.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ListItemCard extends StatelessWidget {
  const ListItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    if (onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
