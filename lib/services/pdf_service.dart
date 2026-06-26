import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/constants/strings_ar.dart';
import '../models/bill.dart';

class PdfService {
  Future<void> printBill(Bill bill) async {
    final doc = await _buildDocument(bill);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> shareBill(Bill bill) async {
    final doc = await _buildDocument(bill);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'bill_${bill.billNumber}.pdf',
    );
  }

  Future<pw.Document> _buildDocument(Bill bill) async {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final numberFormat = NumberFormat('#,##0.##', 'ar');

    Uint8List? signatureBytes;
    try {
      final raw = bill.sellerSignature;
      if (raw.startsWith('data:image')) {
        final base64Str = raw.split(',').last;
        signatureBytes = base64Decode(base64Str);
      } else if (raw.isNotEmpty) {
        signatureBytes = base64Decode(raw);
      }
    } catch (_) {
      signatureBytes = null;
    }

    final currency = bill.currencyLabel;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  StringsAr.factoryName,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${StringsAr.billNumber}: #${bill.billNumber}'),
                  pw.Text(
                    '${StringsAr.date}: ${dateFormat.format(bill.createdAt)}',
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${StringsAr.customerName}: ${bill.customerName ?? ''}',
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  StringsAr.itemName,
                  StringsAr.quantity,
                  StringsAr.unitCost,
                  StringsAr.total,
                ],
                data: bill.items
                    .map(
                      (item) => [
                        item.itemName,
                        numberFormat.format(item.quantity),
                        '${numberFormat.format(item.unitSellPrice)} $currency',
                        '${numberFormat.format(item.totalSell)} $currency',
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerRight,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 30,
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  '${StringsAr.total}: ${numberFormat.format(bill.total)} $currency',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Text(StringsAr.sellerSignature),
              pw.SizedBox(height: 8),
              if (signatureBytes != null)
                pw.Image(
                  pw.MemoryImage(signatureBytes),
                  width: 200,
                  height: 80,
                )
              else
                pw.Container(
                  width: 200,
                  height: 80,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return doc;
  }
}

final pdfService = PdfService();
