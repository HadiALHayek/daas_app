import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/arabic_text_field.dart';
import '../../models/bill.dart';
import '../../models/customer.dart';
import '../../models/item.dart';
import '../../services/pdf_service.dart';
import '../../services/services.dart';

class _DraftLine {
  _DraftLine({
    required this.catalogItem,
    required this.quantity,
    required this.unitPrice,
  });

  final CatalogItem catalogItem;
  double quantity;
  double unitPrice;
  bool priceEdited = false;
}

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  List<Customer>? _customers;
  List<CatalogItem>? _catalog;
  
  // Customer selection state
  bool _isManualCustomer = false;
  Customer? _selectedCustomer;
  double _customerOldDebtUsd = 0;
  double _customerOldDebtSyp = 0;
  final _manualNameController = TextEditingController();
  final _manualPhoneController = TextEditingController();
  final _oldDebtPaymentController = TextEditingController(text: '0');

  double _exchangeRate = 15000;
  String _currency = 'SYP';
  final List<_DraftLine> _lines = [];
  final _discountController = TextEditingController(text: '0');
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  final _priceFormat = NumberFormat('#,##0.##', 'ar');

  @override
  void initState() {
    super.initState();
    _discountController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _manualNameController.dispose();
    _manualPhoneController.dispose();
    _oldDebtPaymentController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerDebt(String customerId) async {
    try {
      final bills =
          await ref.read(customersServiceProvider).getCustomerBills(customerId);
      double usdDebt = 0;
      double sypDebt = 0;
      for (final b in bills) {
        usdDebt += b.currency == 'USD' ? b.amountRemaining : 0;
        sypDebt += b.currency == 'SYP' ? b.amountRemaining : 0;
      }
      if (mounted) {
        setState(() {
          _customerOldDebtUsd = usdDebt;
          _customerOldDebtSyp = sypDebt;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final customers = await ref.read(customersServiceProvider).getCustomers();
      final catalog = await ref.read(itemsServiceProvider).getItems();
      final rate = await ref.read(exchangeRateServiceProvider).getRate();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _catalog = catalog;
        _exchangeRate = rate;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = StringsAr.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _currencyLabel => _currency == 'SYP' ? StringsAr.syp : StringsAr.usd;

  double _convertPrice(double amount, String fromCurrency) {
    if (fromCurrency == _currency) return amount;
    if (fromCurrency == 'USD' && _currency == 'SYP') {
      return amount * _exchangeRate;
    }
    if (fromCurrency == 'SYP' && _currency == 'USD') {
      return amount / _exchangeRate;
    }
    return amount;
  }

  void _addLines() {
    if (_catalog == null || _catalog!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف أصنافاً أولاً من إدارة الأصناف')),
      );
      return;
    }

    final selected = <CatalogItem>{};

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('اختر أصنافاً (يمكن اختيار أكثر من واحد)'),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: ListView(
                  children: _catalog!.map((item) {
                    return CheckboxListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${_priceFormat.format(item.sellPrice)} '
                        '${item.currency == 'SYP' ? StringsAr.syp : StringsAr.usd}',
                      ),
                      value: selected.contains(item),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selected.add(item);
                          } else {
                            selected.remove(item);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(StringsAr.cancel),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          setState(() {
                            for (final item in selected) {
                              final alreadyAdded = _lines.any(
                                (line) => line.catalogItem.id == item.id,
                              );
                              if (!alreadyAdded) {
                                final convertedPrice = _convertPrice(
                                  item.sellPrice,
                                  item.currency,
                                );
                                _lines.add(
                                  _DraftLine(
                                    catalogItem: item,
                                    quantity: 1,
                                    unitPrice: convertedPrice,
                                  )..priceEdited = item.currency != _currency,
                                );
                              }
                            }
                          });
                          Navigator.pop(context);
                        },
                  child: Text('${StringsAr.add} (${selected.length})'),
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
        (sum, line) => sum + line.unitPrice * line.quantity,
      );

  double get _discount {
    final value = double.tryParse(_discountController.text) ?? 0;
    return value < 0 ? 0 : value;
  }

  double get _total =>
      double.parse(((_subtotal - _discount).clamp(0, double.infinity))
          .toStringAsFixed(2));

  Future<void> _saveBill({required bool payImmediately}) async {
    if (!_isManualCustomer && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.selectCustomer)),
      );
      return;
    }
    if (_isManualCustomer && _manualNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم العميل')),
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
              unitSellPrice: line.unitPrice,
              totalSell: line.unitPrice * line.quantity,
              priceOverride: line.priceEdited,
            ),
          )
          .toList();

      final bill = await ref.read(billsServiceProvider).createBill(
            customerId: _isManualCustomer ? null : _selectedCustomer!.id,
            manualCustomerName: _isManualCustomer ? _manualNameController.text.trim() : null,
            manualCustomerPhone: _isManualCustomer ? _manualPhoneController.text.trim() : null,
            currency: _currency,
            items: items,
            discount: _discount,
            initialPayment: payImmediately ? _total : null,
            oldDebtPayment: double.tryParse(_oldDebtPaymentController.text) ?? 0,
          );

      if (!mounted) return;

      final billId = bill.id;
      if (payImmediately) {
        context.pushReplacement('/bills/$billId/print');
      } else {
        context.pushReplacement('/bills/$billId');
      }
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

  Future<void> _editLinePrice(int index) async {
    final line = _lines[index];
    
    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) => _EditPriceDialog(
        itemName: line.catalogItem.name,
        initialPrice: line.unitPrice,
      ),
    );

    if (newPrice == null || !mounted) return;

    setState(() {
      line.unitPrice = newPrice;
      line.priceEdited = true;
    });
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
                            _buildCustomerSelector(),
                            const SizedBox(height: 16),
                            _buildCurrencyDropdown(),
                            if (_currency == 'SYP') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'سعر الصرف المعتمد: 1 \$ = ${_priceFormat.format(_exchangeRate)} ل.س',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                            onPressed: _addLines,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                          final lineTotal = line.unitPrice * line.quantity;
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
                                            Icons.edit_outlined,
                                            color: AppColors.primary,
                                          ),
                                          tooltip: 'تعديل السعر',
                                          onPressed: () =>
                                              _editLinePrice(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppColors.error,
                                          ),
                                          onPressed: () => setState(
                                            () => _lines.removeAt(index),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${StringsAr.unitPrice}: '
                                      '${_priceFormat.format(line.unitPrice)} $_currencyLabel',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _QtyButton(
                                          icon: Icons.remove_rounded,
                                          onPressed: line.quantity > 1
                                              ? () => setState(
                                                    () => line.quantity--,
                                                  )
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
                                          '${_priceFormat.format(lineTotal)} $_currencyLabel',
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
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    StringsAr.subtotal,
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${_priceFormat.format(_subtotal)} $_currencyLabel',
                                    style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              NumberTextField(
                                controller: _discountController,
                                label: StringsAr.discount,
                              ),
                              if (!_isManualCustomer && (_customerOldDebtUsd > 0.01 || _customerOldDebtSyp > 0.01)) ...[
                                const SizedBox(height: 12),
                                NumberTextField(
                                  controller: _oldDebtPaymentController,
                                  label: 'تحصيل من ديون سابقة',
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    StringsAr.total,
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${_priceFormat.format(_total)} $_currencyLabel',
                                    style: GoogleFonts.cairo(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _saveBill(payImmediately: false),
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _saving || _lines.isEmpty
                              ? null
                              : () => _saveBill(payImmediately: true),
                          icon: const Icon(Icons.payments_rounded),
                          label: const Text(StringsAr.payCashNow),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCustomerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('عميل مسجل'),
                    icon: Icon(Icons.person_outline, size: 18),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('بيع مباشر'),
                    icon: Icon(Icons.person_add_outlined, size: 18),
                  ),
                ],
                selected: {_isManualCustomer},
                onSelectionChanged: (values) {
                  setState(() {
                    _isManualCustomer = values.first;
                    _selectedCustomer = null;
                    _customerOldDebtUsd = 0;
                    _customerOldDebtSyp = 0;
                    _oldDebtPaymentController.text = '0';
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_isManualCustomer)
          _buildCustomerDropdown()
        else
          Column(
            children: [
              ArabicTextField(
                controller: _manualNameController,
                label: 'اسم العميل المباشر',
              ),
              const SizedBox(height: 12),
              NumberTextField(
                controller: _manualPhoneController,
                label: 'رقم الهاتف (اختياري)',
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCustomerDropdown() {
    final customers = _customers ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
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
                  : (v) {
                      setState(() {
                        _selectedCustomer = v;
                        _customerOldDebtUsd = 0;
                        _customerOldDebtSyp = 0;
                        _oldDebtPaymentController.text = '0';
                      });
                      if (v != null) _fetchCustomerDebt(v.id);
                    },
            ),
          ),
        ),
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedCustomer!.phone ?? "بدون هاتف"}  •  ${_selectedCustomer!.address ?? "بدون عنوان"}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_customerOldDebtUsd > 0.01 || _customerOldDebtSyp > 0.01) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ديون سابقة: '
                    '${_customerOldDebtUsd > 0 ? "\$${_priceFormat.format(_customerOldDebtUsd)}  " : ""}'
                    '${_customerOldDebtSyp > 0 ? "${_priceFormat.format(_customerOldDebtSyp)} ل.س" : ""}',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
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
            if (v != null && v != _currency) {
              final oldCurrency = _currency;
              setState(() {
                _currency = v;
                // Convert existing lines to the new currency
                for (final line in _lines) {
                  if (v == 'SYP' && oldCurrency == 'USD') {
                    line.unitPrice *= _exchangeRate;
                  } else if (v == 'USD' && oldCurrency == 'SYP') {
                    line.unitPrice /= _exchangeRate;
                  }
                  // When switching currency, we mark as edited so the converted price is sent to the API
                  line.priceEdited = true;
                }
              });
            }
          },
        ),
      ),
    );
  }
}

class _EditPriceDialog extends StatefulWidget {
  const _EditPriceDialog({
    required this.itemName,
    required this.initialPrice,
  });

  final String itemName;
  final double initialPrice;

  @override
  State<_EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<_EditPriceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrice.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('تعديل سعر: ${widget.itemName}'),
      content: NumberTextField(
        controller: _controller,
        label: StringsAr.unitPrice,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(StringsAr.cancel),
        ),
        FilledButton(
          onPressed: () {
            final price = double.tryParse(_controller.text);
            if (price == null || price < 0) return;
            Navigator.pop(context, price);
          },
          child: const Text(StringsAr.save),
        ),
      ],
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
