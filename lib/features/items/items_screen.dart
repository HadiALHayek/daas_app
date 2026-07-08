import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/item.dart';
import '../../services/services.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  List<CatalogItem>? _items;
  bool _loading = true;
  String? _error;

  final _priceFormat = NumberFormat('#,##0.##', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(itemsServiceProvider).getItems();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = StringsAr.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(CatalogItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(StringsAr.confirmDelete, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('حذف "${item.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(StringsAr.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(StringsAr.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(itemsServiceProvider).deleteItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الصنف')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: StringsAr.manageItems,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/items/new');
          _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(StringsAr.add),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _loading
          ? const AppLoading(key: ValueKey('loading'), message: StringsAr.loading)
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: _error!,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                )
              : _items == null || _items!.isEmpty
                  ? EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: StringsAr.noData,
                      subtitle: 'أضف أصناف الأثاث لاستخدامها في الفواتير',
                      action: FilledButton.icon(
                        onPressed: () async {
                          await context.push('/items/new');
                          _load();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text(StringsAr.add),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items![index];
                          return ListItemCard(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.chair_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            title: item.name,
                            subtitle:
                                '${StringsAr.sellPrice}: ${_priceFormat.format(item.sellPrice)}',
                            trailing: CurrencyBadge(currency: item.currency),
                            onEdit: () async {
                              await context.push('/items/${item.id}/edit');
                              _load();
                            },
                            onDelete: () => _deleteItem(item),
                          );
                        },
                      ),
                    ),
            ),
      ),
    );
  }
}
