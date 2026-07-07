import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/bill.dart';
import '../../services/pdf_service.dart';
import '../../services/services.dart';
import 'edit_bill_dialog.dart';
import 'add_bill_payment_dialog.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({
    super.key,
    required this.billId,
    this.shouldPrint = false,
  });

  final String billId;
  final bool shouldPrint;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  Bill? _bill;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final bill = await ref.read(billsServiceProvider).getBill(widget.billId);
      if (!mounted) return;
      setState(() => _bill = bill);

      if (widget.shouldPrint && bill != null) {
        // Delay slightly to ensure screen transition finishes and UI is rendered
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('جاري تجهيز الفاتورة للطباعة...'),
                duration: Duration(seconds: 2),
              ),
            );
            pdfService.printBill(bill).catchError((e) {
              debugPrint('Auto-print error: $e');
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editBill() async {
    final bill = _bill;
    if (bill == null) return;

    final data = await showEditBillDialog(context: context, bill: bill);
    if (data == null) return;

    try {
      await ref.read(billsServiceProvider).updateBill(
            billId: bill.id,
            discount: data.discount,
            items: data.items,
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الفاتورة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  Future<void> _deleteBill() async {
    final bill = _bill;
    if (bill == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          StringsAr.confirmDelete,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('حذف الفاتورة رقم #${bill.billNumber}؟ لا يمكن التراجع عن هذا الإجراء.'),
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
      await ref.read(billsServiceProvider).deleteBill(bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفاتورة بنجاح')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  bool _isProcessing = false;

  Future<void> _addPayment() async {
    if (_isProcessing) return;
    final bill = _bill;
    if (bill == null || bill.isFullyPaid) return;

    setState(() => _isProcessing = true);
    try {
      final data = await showBillPaymentDialog(
        context: context,
        maxAmount: bill.amountRemaining,
        currencyLabel: bill.currencyLabel,
      );
      if (data == null) return;

      final updatedBill = await ref.read(billsServiceProvider).addBillPayment(
            billId: bill.id,
            amount: data.amount,
            notes: data.notes,
            currentBill: bill,
          );
      if (!mounted) return;
      setState(() => _bill = updatedBill);

      try {
        await pdfService.printBill(updatedBill);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is Exception
                    ? 'تم تسجيل الدفعة. فشلت الطباعة: ${e.toString().replaceFirst('Exception: ', '')}'
                    : 'تم تسجيل الدفعة لكن فشلت الطباعة',
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الدفعة وطباعة الفاتورة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm', 'ar');
    final priceFormat = NumberFormat('#,##0.##', 'ar');

    return AppScaffold(
      title: StringsAr.billDetails,
      actions: [
        if (_bill != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: StringsAr.delete,
            onPressed: _deleteBill,
          ),
      ],
      body: _loading
          ? const AppLoading()
          : _bill == null
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: StringsAr.noData,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${_bill!.billNumber}',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_bill!.isFullyPaid)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'مدفوعة بالكامل',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (_bill!.customerId == null)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.info,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'بيع مباشر',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                CurrencyBadge(currency: _bill!.currency),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(
                              icon: Icons.calendar_today_rounded,
                              label: StringsAr.date,
                              value: dateFormat.format(_bill!.createdAt),
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: StringsAr.customerName,
                              value: _bill!.customerName ?? '—',
                            ),
                            if (_bill!.customerPhone?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              _InfoRow(
                                icon: Icons.phone_outlined,
                                label: StringsAr.phone,
                                value: _bill!.customerPhone!,
                              ),
                            ],
                            if (_bill!.customerAddress?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              _InfoRow(
                                icon: Icons.location_on_outlined,
                                label: StringsAr.address,
                                value: _bill!.customerAddress!,
                              ),
                            ],
                            const Divider(height: 28),
                            if (_bill!.discount > 0) ...[
                              _AmountRow(
                                label: StringsAr.subtotal,
                                value:
                                    '${priceFormat.format(_bill!.subtotal)} ${_bill!.currencyLabel}',
                              ),
                              const SizedBox(height: 8),
                              _AmountRow(
                                label: StringsAr.discount,
                                value:
                                    '- ${priceFormat.format(_bill!.discount)} ${_bill!.currencyLabel}',
                                color: AppColors.success,
                              ),
                              const SizedBox(height: 8),
                            ],
                            _AmountRow(
                              label: StringsAr.total,
                              value:
                                  '${priceFormat.format(_bill!.total)} ${_bill!.currencyLabel}',
                              emphasized: true,
                            ),
                            const SizedBox(height: 8),
                            _AmountRow(
                              label: StringsAr.amountPaid,
                              value:
                                  '${priceFormat.format(_bill!.amountPaid)} ${_bill!.currencyLabel}',
                              color: AppColors.success,
                            ),
                            const SizedBox(height: 8),
                            _AmountRow(
                              label: StringsAr.amountRemaining,
                              value:
                                  '${priceFormat.format(_bill!.amountRemaining)} ${_bill!.currencyLabel}',
                              color: _bill!.isFullyPaid
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              StringsAr.billPayments,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!_bill!.isFullyPaid)
                            FilledButton.tonalIcon(
                              onPressed: _addPayment,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(StringsAr.addPayment),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_bill!.payments.isEmpty)
                        const SectionCard(
                          child: Text('لا توجد دفعات مسجّلة بعد'),
                        )
                      else
                        ..._bill!.payments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ListItemCard(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.success.withValues(alpha: 0.12),
                                foregroundColor: AppColors.success,
                                child: const Icon(Icons.payments_rounded, size: 20),
                              ),
                              title:
                                  '${priceFormat.format(payment.amount)} ${_bill!.currencyLabel}',
                              subtitle: payment.notes?.isNotEmpty == true
                                  ? payment.notes!
                                  : dateFormat.format(payment.paymentDate),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'الأصناف',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._bill!.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListItemCard(
                            title: item.itemName,
                            subtitle:
                                '${StringsAr.quantity}: ${item.quantity}  •  '
                                '${StringsAr.unitPrice}: ${priceFormat.format(item.unitSellPrice)}',
                            trailing: Text(
                              '${priceFormat.format(item.totalSell)} ${_bill!.currencyLabel}',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _editBill,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text(StringsAr.editBill),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => pdfService.printBill(_bill!),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text(StringsAr.reprint),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => pdfService.shareBill(_bill!),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text(StringsAr.share),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: emphasized ? 16 : 14,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: emphasized ? 22 : 15,
            fontWeight: FontWeight.w800,
            color: color ?? (emphasized ? AppColors.primary : null),
          ),
        ),
      ],
    );
  }
}
