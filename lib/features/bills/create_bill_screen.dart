import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../services/services.dart';
import 'add_bill_payment_dialog.dart';

class _DraftLine {
  _DraftLine({
    this.catalogItem,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
  });

  /// The catalog item this line is based on, or null for a manual one-off item.
  final CatalogItem? catalogItem;
  final String itemName;
  double quantity;
  double unitPrice;

  /// Cost per unit in the bill's currency (only tracked for manual items).
  double? unitCost;
  bool priceEdited = false;

  String? get itemId => catalogItem?.id;
  bool get isManual => catalogItem == null;
}

class _PendingOldBillPayment {
  const _PendingOldBillPayment({
    required this.billId,
    required this.billNumber,
    required this.billCurrency,
    required this.paymentCurrency,
    required this.amount,
    required this.amountInBillCurrency,
    this.notes,
  });

  final String billId;
  final int billNumber;

  /// The old bill's own currency.
  final String billCurrency;

  /// Currency the admin entered this payment in.
  final String paymentCurrency;

  /// Amount as entered, in [paymentCurrency].
  final double amount;

  /// Amount converted into the old bill's currency (for remaining math).
  final double amountInBillCurrency;
  final String? notes;
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
  final _manualNameController = TextEditingController();
  final _manualPhoneController = TextEditingController();

  double _exchangeRate = 15000;
  String _currency = 'SYP';
  final List<_DraftLine> _lines = [];
  final _discountController = TextEditingController(text: '0');
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  List<OutstandingBill>? _outstandingBills;
  bool _loadingOutstanding = false;
  final List<_PendingOldBillPayment> _pendingOldBillPayments = [];

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
    super.dispose();
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

  Future<void> _loadOutstandingBills(String customerId) async {
    if (!mounted) return;
    setState(() {
      _loadingOutstanding = true;
      _outstandingBills = null;
    });
    try {
      final outstanding = await ref
          .read(customersServiceProvider)
          .getCustomerOutstandingBills(customerId);
      if (!mounted) return;
      setState(() => _outstandingBills = outstanding);
    } catch (_) {
      if (!mounted) return;
      setState(() => _outstandingBills = const []);
    } finally {
      if (mounted) setState(() => _loadingOutstanding = false);
    }
  }

  void _onCustomerSelected(Customer? customer) {
    setState(() {
      _selectedCustomer = customer;
      _pendingOldBillPayments.clear();
    });
    if (customer != null) {
      _loadOutstandingBills(customer.id);
    } else {
      setState(() => _outstandingBills = null);
    }
  }

  double _effectiveRemaining(OutstandingBill ob) {
    final pending = _pendingOldBillPayments
        .where((p) => p.billId == ob.id)
        .fold<double>(0, (sum, p) => sum + p.amountInBillCurrency);
    return (ob.amountRemaining - pending).clamp(0, double.infinity);
  }

  double _pendingAmountForBill(String billId) {
    return _pendingOldBillPayments
        .where((p) => p.billId == billId)
        .fold<double>(0, (sum, p) => sum + p.amountInBillCurrency);
  }

  /// Convert [amount] from [fromCurrency] into [toCurrency] at the current rate.
  double _convertBetween(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;
    if (fromCurrency == 'USD' && toCurrency == 'SYP') {
      return amount * _exchangeRate;
    }
    if (fromCurrency == 'SYP' && toCurrency == 'USD') {
      return amount / _exchangeRate;
    }
    return amount;
  }

  /// Format [amountInBillCurrency] converted into the opposite currency,
  /// e.g. "≈ 33.33 $" for a SYP bill or "≈ 500,000 ل.س" for a USD bill.
  String _convertedLabel(double amountInBillCurrency) =>
      _oppositeCurrencyLabel(amountInBillCurrency, _currency);

  /// Convert [amount] (given in [currency]) into the other currency and format
  /// it, e.g. "≈ 33.33 $" or "≈ 500,000 ل.س", using today's exchange rate.
  String _oppositeCurrencyLabel(double amount, String currency) {
    final other = currency == 'SYP' ? 'USD' : 'SYP';
    final converted = _convertBetween(amount, currency, other);
    final label = other == 'SYP' ? StringsAr.syp : StringsAr.usd;
    return '≈ ${_priceFormat.format(converted)} $label';
  }

  Future<void> _addPaymentToOldBill(OutstandingBill ob) async {
    final remaining = _effectiveRemaining(ob);
    if (remaining <= 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الفاتورة مسددة بالكامل')),
      );
      return;
    }

    final data = await showBillPaymentDialog(
      context: context,
      maxAmount: remaining,
      billCurrency: ob.currency,
      exchangeRate: _exchangeRate,
      title: '${StringsAr.payOnPreviousBill} #${ob.billNumber}',
    );
    if (data == null || !mounted) return;

    setState(() {
      _pendingOldBillPayments.add(
        _PendingOldBillPayment(
          billId: ob.id,
          billNumber: ob.billNumber,
          billCurrency: ob.currency,
          paymentCurrency: data.currency,
          amount: data.amount,
          amountInBillCurrency: _convertBetween(
            data.amount,
            data.currency,
            ob.currency,
          ),
          notes: data.notes,
        ),
      );
    });
  }

  void _removePendingPayment(_PendingOldBillPayment payment) {
    setState(() => _pendingOldBillPayments.remove(payment));
  }

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
                                (line) => line.itemId == item.id,
                              );
                              if (!alreadyAdded) {
                                final convertedPrice = _convertPrice(
                                  item.sellPrice,
                                  item.currency,
                                );
                                _lines.add(
                                  _DraftLine(
                                    catalogItem: item,
                                    itemName: item.name,
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

  Future<void> _addManualLine() async {
    final result = await showDialog<_ManualItemResult>(
      context: context,
      builder: (context) => _ManualItemDialog(currencyLabel: _currencyLabel),
    );
    if (result == null || !mounted) return;

    setState(() {
      _lines.add(
        _DraftLine(
          catalogItem: null,
          itemName: result.name,
          quantity: result.quantity,
          unitPrice: result.sellPrice,
          unitCost: result.cost,
        )..priceEdited = true,
      );
    });
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

    HapticFeedback.selectionClick();

    setState(() => _saving = true);

    try {
      final items = _lines
          .map(
            (line) => BillItem(
              itemId: line.itemId,
              itemName: line.itemName,
              quantity: line.quantity,
              unitSellPrice: line.unitPrice,
              totalSell: line.unitPrice * line.quantity,
              priceOverride: line.priceEdited || line.isManual,
              unitItemCost: line.isManual ? (line.unitCost ?? 0) : null,
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
          );

      if (!mounted) return;

      final crossPayments = <CrossBillPayment>[];
      for (final pending in _pendingOldBillPayments) {
        try {
          await ref.read(billsServiceProvider).addBillPayment(
                billId: pending.billId,
                amount: pending.amount,
                currency: pending.paymentCurrency,
                notes: pending.notes ??
                    'دفع مع فاتورة #${bill.billNumber}',
              );
          crossPayments.add(
            CrossBillPayment(
              billNumber: pending.billNumber,
              amount: pending.amount,
              currency: pending.paymentCurrency,
              notes: pending.notes,
            ),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'فشل تسجيل دفعة فاتورة #${pending.billNumber}: '
                  '${e is Exception ? e.toString().replaceFirst('Exception: ', '') : StringsAr.error}',
                ),
              ),
            );
          }
        }
      }

      var billForPrint = bill;
      try {
        billForPrint = (await ref.read(billsServiceProvider).getBill(bill.id))
            .withCrossBillPayments(crossPayments);
      } catch (_) {
        billForPrint = bill.withCrossBillPayments(crossPayments);
      }

      if (!mounted) return;

      final billId = bill.id;
      if (payImmediately) {
        if (!context.mounted) return;
        context.pushReplacement('/bills/$billId/print', extra: billForPrint);
      } else {
        context.pushReplacement('/bills/$billId', extra: billForPrint);
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
        itemName: line.itemName,
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
                      if (!_isManualCustomer &&
                          _selectedCustomer != null) ...[
                        const SizedBox(height: 16),
                        _buildOutstandingBillsSection(),
                      ],
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
                          OutlinedButton.icon(
                            onPressed: _addManualLine,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            label: const Text(StringsAr.addManualItem),
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
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                line.itemName,
                                                style: GoogleFonts.cairo(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (line.isManual)
                                                Text(
                                                  '${StringsAr.addManualItem}'
                                                  '${line.unitCost != null && line.unitCost! > 0 ? ' • ${StringsAr.unitCost}: ${_priceFormat.format(line.unitCost)} $_currencyLabel' : ''}',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                            ],
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
                                    if (_currency != 'USD')
                                      Text(
                                        '${StringsAr.unitPrice} (\$): '
                                        '${_priceFormat.format(_convertBetween(line.unitPrice, _currency, 'USD'))} \$',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
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
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${_priceFormat.format(lineTotal)} $_currencyLabel',
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            Text(
                                              _convertedLabel(lineTotal),
                                              style: GoogleFonts.cairo(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
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
                    if (_isManualCustomer) {
                      _selectedCustomer = null;
                      _outstandingBills = null;
                      _pendingOldBillPayments.clear();
                    }
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
                  : _onCustomerSelected,
            ),
          ),
        ),
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_selectedCustomer!.phone ?? "بدون هاتف"}  •  ${_selectedCustomer!.address ?? "بدون عنوان"}',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOutstandingBillsSection() {
    if (_loadingOutstanding) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      );
    }

    final outstanding = _outstandingBills ?? const <OutstandingBill>[];
    if (outstanding.isEmpty) {
      return SectionCard(
        child: Text(
          'لا توجد مبالغ مستحقة من فواتير سابقة',
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'مبالغ مستحقة من فواتير سابقة',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 10),
        ...outstanding.map(
          (ob) {
            final pending = _pendingAmountForBill(ob.id);
            final remaining = _effectiveRemaining(ob);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListItemCard(
                leading: CircleAvatar(
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  foregroundColor: AppColors.error,
                  child: const Icon(Icons.history_rounded, size: 20),
                ),
                title: 'فاتورة #${ob.billNumber}',
                subtitle: pending > 0
                    ? 'الإجمالي: ${_priceFormat.format(ob.total)} ${ob.currencyLabel} '
                      '(${_oppositeCurrencyLabel(ob.total, ob.currency)})\n'
                      'دفعة جديدة: ${_priceFormat.format(pending)} ${ob.currencyLabel}'
                    : 'الإجمالي: ${_priceFormat.format(ob.total)} ${ob.currencyLabel} '
                      '(${_oppositeCurrencyLabel(ob.total, ob.currency)})',
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_priceFormat.format(remaining)} ${ob.currencyLabel}',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        color: remaining <= 0.001
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    if (remaining > 0.001)
                      Text(
                        _oppositeCurrencyLabel(remaining, ob.currency),
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (remaining > 0.001)
                      TextButton.icon(
                        onPressed: () => _addPaymentToOldBill(ob),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text(StringsAr.addPayment),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_pendingOldBillPayments.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StringsAr.paymentsOnPreviousBills,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                ..._pendingOldBillPayments.map(
                  (p) {
                    OutstandingBill? ob;
                    for (final o
                        in (_outstandingBills ?? const <OutstandingBill>[])) {
                      if (o.id == p.billId) {
                        ob = o;
                        break;
                      }
                    }
                    final remaining =
                        ob != null ? _effectiveRemaining(ob) : null;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('فاتورة #${p.billNumber}'),
                      subtitle: Text(
                        [
                          '${StringsAr.addPayment}: '
                              '${_priceFormat.format(p.amount)} '
                              '${p.paymentCurrency == 'SYP' ? StringsAr.syp : StringsAr.usd}',
                          '${StringsAr.rate}: '
                              '1\$ = ${_priceFormat.format(_exchangeRate)} ل.س',
                          if (remaining != null)
                            '${StringsAr.amountRemaining}: '
                                '${_priceFormat.format(remaining)} ${ob!.currencyLabel} '
                                '(${_oppositeCurrencyLabel(remaining, ob.currency)})',
                        ].join('\n'),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => _removePendingPayment(p),
                      ),
                    );
                  },
                ),
                Text(
                  'ستُسجّل هذه الدفعات عند إنشاء الفاتورة وتظهر في الطباعة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
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
                    if (line.unitCost != null) line.unitCost = line.unitCost! * _exchangeRate;
                  } else if (v == 'USD' && oldCurrency == 'SYP') {
                    line.unitPrice /= _exchangeRate;
                    if (line.unitCost != null) line.unitCost = line.unitCost! / _exchangeRate;
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

class _ManualItemResult {
  const _ManualItemResult({
    required this.name,
    required this.quantity,
    required this.sellPrice,
    required this.cost,
  });

  final String name;
  final double quantity;
  final double sellPrice;
  final double cost;
}

class _ManualItemDialog extends StatefulWidget {
  const _ManualItemDialog({required this.currencyLabel});

  final String currencyLabel;

  @override
  State<_ManualItemDialog> createState() => _ManualItemDialogState();
}

class _ManualItemDialogState extends State<_ManualItemDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _sellPriceController = TextEditingController();
  final _costController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _sellPriceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final sellPrice = double.tryParse(_sellPriceController.text.trim());
    final cost = double.tryParse(_costController.text.trim()) ?? 0;

    if (name.isEmpty) {
      setState(() => _error = 'يرجى إدخال اسم الصنف');
      return;
    }
    if (sellPrice == null || sellPrice < 0) {
      setState(() => _error = 'يرجى إدخال سعر بيع صحيح');
      return;
    }
    if (quantity <= 0) {
      setState(() => _error = 'يرجى إدخال كمية صحيحة');
      return;
    }

    Navigator.pop(
      context,
      _ManualItemResult(
        name: name,
        quantity: quantity,
        sellPrice: sellPrice,
        cost: cost < 0 ? 0 : cost,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(StringsAr.addManualItem),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArabicTextField(
              controller: _nameController,
              label: StringsAr.itemName,
            ),
            const SizedBox(height: 12),
            NumberTextField(
              controller: _quantityController,
              label: StringsAr.quantity,
            ),
            const SizedBox(height: 12),
            NumberTextField(
              controller: _sellPriceController,
              label: '${StringsAr.sellPrice} (${widget.currencyLabel})',
            ),
            const SizedBox(height: 12),
            NumberTextField(
              controller: _costController,
              label: '${StringsAr.cost} (${widget.currencyLabel})',
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.cairo(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(StringsAr.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(StringsAr.add),
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
