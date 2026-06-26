import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/bill.dart';
import '../../models/customer.dart';
import '../../models/item.dart';
import '../../services/pdf_service.dart';
import '../../services/services.dart';

class _DraftLine {
  _DraftLine({required this.catalogItem, required this.quantity});
  final CatalogItem catalogItem;
  double quantity;
}

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  List<Customer>? _customers;
  List<CatalogItem>? _catalog;
  Customer? _selectedCustomer;
  String _currency = 'SYP';
  final List<_DraftLine> _lines = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  final _priceFormat = NumberFormat('#,##0.##', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final customers = await ref.read(customersServiceProvider).getCustomers();
      final catalog = await ref.read(itemsServiceProvider).getItems();
      setState(() {
        _customers = customers;
        _catalog = catalog;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = StringsAr.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addLine() {
    if (_catalog == null || _catalog!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف أصنافاً أولاً من إدارة الأصناف')),
      );
      return;
    }

    CatalogItem? selected = _catalog!.first;
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(StringsAr.selectItem),
              content: DropdownButtonFormField<CatalogItem>(
                initialValue: selected,
                items: _catalog!
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selected = v),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(StringsAr.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (selected != null) {
                      setState(() {
                        _lines.add(_DraftLine(
                          catalogItem: selected!,
                          quantity: 1,
                        ));
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(StringsAr.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double get _subtotal => _lines.fold(
        0,
        (sum, line) => sum + line.catalogItem.sellPrice * line.quantity,
      );

  Future<void> _saveAndPrint() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.selectCustomer)),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final items = _lines
          .map(
            (line) => BillItem(
              itemId: line.catalogItem.id,
              itemName: line.catalogItem.name,
              quantity: line.quantity,
              unitSellPrice: line.catalogItem.sellPrice,
              totalSell: line.catalogItem.sellPrice * line.quantity,
            ),
          )
          .toList();

      final bill = await ref.read(billsServiceProvider).createBill(
            customerId: _selectedCustomer!.id,
            currency: _currency,
            items: items,
          );

      if (!mounted) return;

      try {
        await pdfService.printBill(bill);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is Exception
                    ? 'تم حفظ الفاتورة. فشلت الطباعة: ${e.toString().replaceFirst('Exception: ', '')}'
                    : 'تم حفظ الفاتورة لكن فشلت الطباعة',
              ),
            ),
          );
        }
      }

      if (mounted) context.pushReplacement('/bills/${bill.id}');
    } catch (e) {
      if (mounted) {
        final message = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : StringsAr.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: StringsAr.newBill,
      body: _loading
          ? const AppLoading()
          : _loadError != null
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: _loadError!,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        child: Column(
                          children: [
                            _buildCustomerDropdown(),
                            const SizedBox(height: 16),
                            _buildCurrencyDropdown(),
                          ],
                        ),
                      ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'أصناف الفاتورة',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _addLine,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(StringsAr.addItem),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_lines.isEmpty)
                    const EmptyState(
                      compact: true,
                      icon: Icons.shopping_cart_outlined,
                      title: 'لا توجد أصناف',
                      subtitle: 'اضغط إضافة صنف لبدء الفاتورة',
                    )
                  else
                    ..._lines.asMap().entries.map((entry) {
                      final index = entry.key;
                      final line = entry.value;
                      final lineTotal =
                          line.catalogItem.sellPrice * line.quantity;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        line.catalogItem.name,
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () =>
                                          setState(() => _lines.removeAt(index)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _QtyButton(
                                      icon: Icons.remove_rounded,
                                      onPressed: line.quantity > 1
                                          ? () => setState(() => line.quantity--)
                                          : null,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        line.quantity.toStringAsFixed(0),
                                        style: GoogleFonts.cairo(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    _QtyButton(
                                      icon: Icons.add_rounded,
                                      onPressed: () =>
                                          setState(() => line.quantity++),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_priceFormat.format(lineTotal)} '
                                      '${line.catalogItem.currency == 'SYP' ? StringsAr.syp : StringsAr.usd}',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  if (_lines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SectionCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            StringsAr.subtotal,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _priceFormat.format(_subtotal),
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveAndPrint,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.receipt_long_rounded),
                      label: Text(
                        _saving ? StringsAr.loading : StringsAr.createBill,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomerDropdown() {
    final customers = _customers ?? [];
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: StringsAr.selectCustomer,
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Customer>(
          value: _selectedCustomer,
          isExpanded: true,
          hint: Text(
            customers.isEmpty
                ? 'لا يوجد عملاء — أضف من شاشة العملاء'
                : StringsAr.selectCustomer,
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          items: customers
              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
              .toList(),
          onChanged: customers.isEmpty
              ? null
              : (v) => setState(() => _selectedCustomer = v),
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: StringsAr.currency,
        prefixIcon: Icon(Icons.payments_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currency,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'SYP', child: Text(StringsAr.syp)),
            DropdownMenuItem(value: 'USD', child: Text(StringsAr.usd)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _currency = v);
          },
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}
