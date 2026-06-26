import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/strings_ar.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(itemsServiceProvider).getItems();
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = StringsAr.error);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(CatalogItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StringsAr.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(StringsAr.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(StringsAr.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ref.read(itemsServiceProvider).deleteItem(item.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringsAr.manageItems)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/items/new');
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items == null || _items!.isEmpty
                  ? const Center(child: Text(StringsAr.noData))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items![index];
                          final currency =
                              item.currency == 'SYP' ? StringsAr.syp : StringsAr.usd;
                          return Card(
                            child: ListTile(
                              title: Text(item.name),
                              subtitle: Text(
                                '${StringsAr.cost}: ${item.cost} $currency | '
                                '${StringsAr.sellPrice}: ${item.sellPrice} $currency',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await context.push('/items/${item.id}/edit');
                                    _load();
                                  } else if (value == 'delete') {
                                    await _deleteItem(item);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text(StringsAr.edit),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(StringsAr.delete),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
