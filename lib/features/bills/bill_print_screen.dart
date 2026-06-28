import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/bill.dart';
import '../../services/pdf_service.dart';
import '../../services/services.dart';

class BillPrintScreen extends ConsumerStatefulWidget {
  const BillPrintScreen({super.key, required this.billId});

  final String billId;

  @override
  ConsumerState<BillPrintScreen> createState() => _BillPrintScreenState();
}

class _BillPrintScreenState extends ConsumerState<BillPrintScreen> {
  Bill? _bill;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bill = await ref.read(billsServiceProvider).getBill(widget.billId);
      if (mounted) {
        setState(() {
          _bill = bill;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة الطباعة'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
          tooltip: 'إغلاق والعودة للرئيسية',
        ),
      ),
      body: _loading
          ? const AppLoading()
          : _bill == null
              ? const EmptyState(icon: Icons.error_outline, title: 'خطأ في تحميل البيانات')
              : PdfPreview(
                  build: (format) async {
                    final doc = await pdfService.buildDocumentForFormat(_bill!);
                    return doc.save();
                  },
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  initialPageFormat: PdfPageFormat.a4,
                  onPrinted: (context) {
                    // Optional: show a snackbar or navigate back
                  },
                ),
    );
  }
}
